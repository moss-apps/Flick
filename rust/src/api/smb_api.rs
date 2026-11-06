use crate::frb_generated::StreamSink;
use std::collections::{HashSet, VecDeque};
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

/// Refuse to recurse indefinitely through junctions/DFS links that point back
/// into the share. Real music libraries are far shallower than this.
const MAX_DIRECTORY_DEPTH: usize = 64;

/// A child directory disappearing or being unreadable must not fail the whole
/// library sync. The configured root still fails loudly: that is the address
/// the user typed and the one they need to fix.
fn skippable_subdirectory_error(error: &smb2::Error) -> bool {
    use smb2::ErrorKind;
    matches!(
        error.kind(),
        ErrorKind::AccessDenied
            | ErrorKind::NotFound
            | ErrorKind::NotADirectory
            | ErrorKind::InvalidName
            | ErrorKind::Unsupported
    )
}

/// The root is the address the user typed, so its failure must propagate. Only
/// errors from directories discovered below it are safe to skip.
fn should_skip_directory_error(root_listed: bool, error: &smb2::Error) -> bool {
    root_listed && skippable_subdirectory_error(error)
}

/// Only allowlisted stage/code pairs cross the bridge. smb2 errors can contain
/// hostnames, account names and remote paths; never attach them as error sources.
fn error_code(error: &smb2::Error) -> &'static str {
    use smb2::ErrorKind;
    match error.kind() {
        ErrorKind::AuthRequired => "auth",
        ErrorKind::SigningRequired => "signing",
        ErrorKind::AccessDenied => "denied",
        ErrorKind::NotFound | ErrorKind::NotADirectory => "not_found",
        ErrorKind::TimedOut => "timeout",
        ErrorKind::ConnectionLost | ErrorKind::SessionExpired => "connection",
        ErrorKind::Io => "connection",
        _ => "protocol",
    }
}

fn failure(stage: &str, error: smb2::Error) -> anyhow::Error {
    anyhow::anyhow!("SMB stage={} code={}", stage, error_code(&error))
}

/// `smb2` takes the account name and domain separately. Users commonly type
/// `DOMAIN\user` or `user@domain` into the single username field; split those
/// forms so NTLM receives the pieces a Windows client would send. Plain local
/// accounts pass through unchanged.
fn split_account(user: &str) -> (&str, &str) {
    if let Some((domain, account)) = user.split_once('\\') {
        if !domain.is_empty() && !account.is_empty() {
            return (account, domain);
        }
    }
    if let Some((account, domain)) = user.split_once('@') {
        if !account.is_empty() && !domain.is_empty() {
            return (account, domain);
        }
    }
    (user, "")
}

/// Shared client configuration. `smb2::connect`'s shorthand is a five-second,
/// no-reconnect client; a share on a waking NAS, or a Wi-Fi roam between
/// tracks, should recover in place instead of failing the whole transfer.
fn client_config(host: &str, port: u16, user: &str, pass: &str) -> smb2::ClientConfig {
    let (account, domain) = split_account(user);
    smb2::ClientConfig {
        addr: addr(host, port),
        username: account.to_string(),
        password: pass.to_string(),
        domain: domain.to_string(),
        timeout: Duration::from_secs(15),
        auto_reconnect: true,
        ..Default::default()
    }
}

async fn connect(host: &str, port: u16, user: &str, pass: &str) -> anyhow::Result<smb2::SmbClient> {
    smb2::SmbClient::connect(client_config(host, port, user, pass))
        .await
        .map_err(|e| failure("connect", e))
}

/// Same-directory staging file. Drop cleans up on error, stream cancellation,
/// or task cancellation; the final cache path is never a partial download.
struct PendingDownload {
    path: PathBuf,
    file: Option<File>,
}

impl PendingDownload {
    fn create(dest: &Path) -> std::io::Result<Self> {
        static NEXT_ID: AtomicU64 = AtomicU64::new(0);
        loop {
            let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
            let path = dest.with_file_name(format!(
                ".{}.{}.{}.part",
                dest.file_name().unwrap_or_default().to_string_lossy(),
                std::process::id(),
                id,
            ));
            match OpenOptions::new().write(true).create_new(true).open(&path) {
                Ok(file) => {
                    return Ok(Self {
                        path,
                        file: Some(file),
                    })
                }
                Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(e) => return Err(e),
            }
        }
    }

    fn commit(mut self, dest: &Path, received: u64, total: u64) -> anyhow::Result<()> {
        anyhow::ensure!(received == total, "SMB stage=download code=incomplete");
        self.file
            .as_mut()
            .unwrap()
            .flush()
            .map_err(|_| anyhow::anyhow!("SMB stage=cache code=storage"))?;
        self.file
            .as_ref()
            .unwrap()
            .sync_all()
            .map_err(|_| anyhow::anyhow!("SMB stage=cache code=storage"))?;
        drop(self.file.take());
        std::fs::rename(&self.path, dest)
            .map_err(|_| anyhow::anyhow!("SMB stage=cache code=storage"))?;
        Ok(())
    }
}

impl Drop for PendingDownload {
    fn drop(&mut self) {
        drop(self.file.take());
        let _ = std::fs::remove_file(&self.path);
    }
}

#[derive(Debug, Clone)]
pub struct SmbEntry {
    pub name: String,
    pub path: String,
    pub size: u64,
    pub is_dir: bool,
}

#[derive(Debug, Clone)]
pub struct SmbProgress {
    pub received: u64,
    pub total: u64,
    pub is_complete: bool,
}

/// Format `host:port` for smb2. Bare IPv6 literals are bracketed so the
/// host/port split stays unambiguous (`fe80::1` must become `[fe80::1]:445`).
fn addr(host: &str, port: u16) -> String {
    if host.contains(':') && !host.starts_with('[') {
        format!("[{}]:{}", host, port)
    } else {
        format!("{}:{}", host, port)
    }
}

/// Connect, open the share and list the configured root once (not recursively).
/// Success does not imply permission to read every file in that directory.
pub async fn smb_ping(
    host: String,
    port: u16,
    share: String,
    user: String,
    pass: String,
    root_path: String,
) -> anyhow::Result<()> {
    let mut client = connect(&host, port, &user, &pass).await?;
    let mut tree = client
        .connect_share(&share)
        .await
        .map_err(|e| failure("share", e))?;
    client
        .list_directory(&mut tree, &root_path)
        .await
        .map_err(|e| failure("root", e))?;
    Ok(())
}

/// BFS walk of `root_path` (relative to the share) pushing one [SmbEntry] per
/// file or directory. `root_path` of "" lists the share root. One connection,
/// reused across directories.
///
/// A child directory that is unreadable or vanished during the walk is skipped
/// instead of aborting the scan; Windows shares commonly contain things like
/// `System Volume Information` that even a valid account cannot list. Failing
/// to list the configured root itself is still an error, since that is the
/// address the user needs to correct.
pub async fn smb_list_share(
    host: String,
    port: u16,
    share: String,
    user: String,
    pass: String,
    root_path: String,
    sink: StreamSink<SmbEntry>,
) -> anyhow::Result<()> {
    let mut client = connect(&host, port, &user, &pass).await?;
    let mut tree = client
        .connect_share(&share)
        .await
        .map_err(|e| failure("share", e))?;

    let mut queue: VecDeque<(String, usize)> = VecDeque::new();
    let mut visited: HashSet<String> = HashSet::new();
    visited.insert(root_path.clone());
    queue.push_back((root_path, 0));
    let mut root_listed = false;
    let mut skipped = 0_u32;

    while let Some((dir, depth)) = queue.pop_front() {
        let entries = match client.list_directory(&mut tree, &dir).await {
            Ok(entries) => entries,
            Err(e) if should_skip_directory_error(root_listed, &e) => {
                skipped += 1;
                continue;
            }
            Err(e) => {
                return Err(failure(if root_listed { "read" } else { "root" }, e));
            }
        };
        root_listed = true;
        for e in entries {
            if e.name == "." || e.name == ".." {
                continue;
            }
            let child_path = if dir.is_empty() {
                e.name.clone()
            } else {
                format!("{}/{}", dir, e.name)
            };
            sink.add(SmbEntry {
                name: e.name.clone(),
                path: child_path.clone(),
                size: e.size,
                is_dir: e.is_directory,
            })
            .map_err(|_| anyhow::anyhow!("SMB stage=root code=cancelled"))?;
            if e.is_directory {
                if depth >= MAX_DIRECTORY_DEPTH || !visited.insert(child_path.clone()) {
                    skipped += 1;
                    continue;
                }
                queue.push_back((child_path, depth + 1));
            }
        }
    }
    if skipped > 0 {
        // Numeric only: never log share, directory or file names.
        log::info!("SMB stage=root result=partial skipped={skipped}");
    }
    Ok(())
}

/// Read a full (small) file into memory — cover art and tiny sidecars.
///
/// Uses the pipelined reader rather than `read_file`: the latter is a single
/// READ and fails with `FileTooLargeForSingleRead` when the file exceeds the
/// server's MaxReadSize (as small as 64 KiB on some NAS firmware). Folder art
/// routinely exceeds that, which made SMB covers fail on those servers.
pub async fn smb_read_file(
    host: String,
    port: u16,
    share: String,
    path: String,
    user: String,
    pass: String,
) -> anyhow::Result<Vec<u8>> {
    let mut client = connect(&host, port, &user, &pass).await?;
    let mut tree = client
        .connect_share(&share)
        .await
        .map_err(|e| failure("share", e))?;
    let bytes = client
        .read_file_pipelined(&mut tree, &path)
        .await
        .map_err(|e| failure("read", e))?;
    Ok(bytes)
}

/// Download to a staging file, then atomically publish only a complete file.
// ponytail: sync std::fs writes between async chunks — negligible next to
// network RTT; add tokio "fs" only if blocking ever shows on profile.
pub async fn smb_download_file(
    host: String,
    port: u16,
    share: String,
    path: String,
    user: String,
    pass: String,
    dest_path: String,
    sink: StreamSink<SmbProgress>,
) -> anyhow::Result<()> {
    let mut client = connect(&host, port, &user, &pass).await?;
    let tree = client
        .connect_share(&share)
        .await
        .map_err(|e| failure("share", e))?;
    let mut download = client
        .download(&tree, &path)
        .await
        .map_err(|e| failure("read", e))?;
    let total = download.size();
    let dest = Path::new(&dest_path);
    let mut pending = PendingDownload::create(dest)
        .map_err(|_| anyhow::anyhow!("SMB stage=cache code=storage"))?;
    let mut received: u64 = 0;
    while let Some(chunk) = download.next_chunk().await {
        let chunk = chunk.map_err(|e| failure("download", e))?;
        pending
            .file
            .as_mut()
            .unwrap()
            .write_all(&chunk)
            .map_err(|_| anyhow::anyhow!("SMB stage=cache code=storage"))?;
        received += chunk.len() as u64;
        anyhow::ensure!(received <= total, "SMB stage=download code=incomplete");
        sink.add(SmbProgress {
            received,
            total,
            is_complete: false,
        })
        .map_err(|_| anyhow::anyhow!("SMB stage=download code=cancelled"))?;
    }
    pending.commit(dest, received, total)?;
    sink.add(SmbProgress {
        received,
        total,
        is_complete: true,
    })
    .map_err(|_| anyhow::anyhow!("SMB stage=download code=cancelled"))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        addr, client_config, failure, should_skip_directory_error, skippable_subdirectory_error,
        split_account, PendingDownload,
    };
    use std::io::Write;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::Duration;

    fn test_dir() -> PathBuf {
        static ID: AtomicU64 = AtomicU64::new(0);
        let dir = std::env::temp_dir().join(format!(
            "flick_smb_{}_{}",
            std::process::id(),
            ID.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn interrupted_download_never_publishes_and_cleans_staging_file() {
        let dir = test_dir();
        let dest = dir.join("track.flac");
        let staging;
        {
            let mut pending = PendingDownload::create(&dest).unwrap();
            staging = pending.path.clone();
            pending
                .file
                .as_mut()
                .unwrap()
                .write_all(b"partial")
                .unwrap();
            assert!(!dest.exists());
        }
        assert!(!staging.exists());
        assert!(!dest.exists());
        std::fs::remove_dir(dir).unwrap();
    }

    #[test]
    fn short_download_is_rejected_then_retry_publishes_exact_bytes() {
        let dir = test_dir();
        let dest = dir.join("track.dsf");
        let mut pending = PendingDownload::create(&dest).unwrap();
        pending.file.as_mut().unwrap().write_all(b"abc").unwrap();
        assert!(pending.commit(&dest, 3, 4).is_err());
        assert!(!dest.exists());
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 0);
        let mut retry = PendingDownload::create(&dest).unwrap();
        retry.file.as_mut().unwrap().write_all(b"abcd").unwrap();
        retry.commit(&dest, 4, 4).unwrap();
        assert_eq!(std::fs::read(&dest).unwrap(), b"abcd");
        assert_eq!(std::fs::read_dir(&dir).unwrap().count(), 1);
        std::fs::remove_file(dest).unwrap();
        std::fs::remove_dir(dir).unwrap();
    }

    #[test]
    fn rename_failure_cleans_staging_and_preserves_destination() {
        let dir = test_dir();
        let dest = dir.join("directory");
        std::fs::create_dir(&dest).unwrap();
        let mut pending = PendingDownload::create(&dest).unwrap();
        let staging = pending.path.clone();
        pending.file.as_mut().unwrap().write_all(b"abc").unwrap();
        assert!(pending.commit(&dest, 3, 3).is_err());
        assert!(!staging.exists());
        assert!(dest.is_dir());
        std::fs::remove_dir(dest).unwrap();
        std::fs::remove_dir(dir).unwrap();
    }

    #[test]
    fn bridge_errors_exclude_private_native_details() {
        let error = smb2::Error::Auth {
            message: "secret-user secret-password".into(),
        };
        assert_eq!(
            failure("connect", error).to_string(),
            "SMB stage=connect code=auth"
        );
        let error = smb2::Error::InvalidData {
            message: "private-host/private-share/file".into(),
        };
        assert_eq!(
            failure("read", error).to_string(),
            "SMB stage=read code=protocol"
        );
    }

    #[test]
    fn addr_brackets_bare_ipv6_hosts() {
        assert_eq!(addr("fd00::1", 445), "[fd00::1]:445");
        assert_eq!(addr("[fd00::1]", 445), "[fd00::1]:445");
        assert_eq!(addr("192.168.1.10", 445), "192.168.1.10:445");
        assert_eq!(addr("nas.local", 1445), "nas.local:1445");
    }

    #[test]
    fn unreadable_child_directories_are_skippable_but_connection_loss_is_not() {
        use smb2::types::status::NtStatus;
        use smb2::types::Command;

        let denied = smb2::Error::Protocol {
            status: NtStatus::ACCESS_DENIED,
            command: Command::QueryDirectory,
        };
        assert!(skippable_subdirectory_error(&denied));
        assert!(!should_skip_directory_error(false, &denied));
        assert!(should_skip_directory_error(true, &denied));

        let vanished = smb2::Error::Protocol {
            status: NtStatus::OBJECT_NAME_NOT_FOUND,
            command: Command::Create,
        };
        assert!(skippable_subdirectory_error(&vanished));
        assert!(should_skip_directory_error(true, &vanished));

        assert!(!skippable_subdirectory_error(&smb2::Error::Disconnected));
        assert!(!skippable_subdirectory_error(&smb2::Error::Timeout));
        assert!(!should_skip_directory_error(
            true,
            &smb2::Error::Disconnected
        ));
    }

    #[test]
    fn client_config_keeps_credentials_and_allows_reconnect() {
        let config = client_config("nas.local", 1445, "user", "pass");
        assert_eq!(config.addr, "nas.local:1445");
        assert_eq!(config.username, "user");
        assert_eq!(config.password, "pass");
        assert_eq!(config.domain, "");
        assert!(config.auto_reconnect);
        assert_eq!(config.timeout, Duration::from_secs(15));
    }

    #[test]
    fn account_formats_split_domain_and_user() {
        assert_eq!(split_account("alice"), ("alice", ""));
        assert_eq!(split_account(r"CORP\alice"), ("alice", "CORP"));
        assert_eq!(
            split_account("alice@corp.example"),
            ("alice", "corp.example")
        );
        assert_eq!(split_account(""), ("", ""));
        assert_eq!(split_account(r"DOMAIN\"), (r"DOMAIN\", ""));
        assert_eq!(split_account(r"\alice"), (r"\alice", ""));

        let config = client_config("nas.local", 445, r"CORP\alice", "pass");
        assert_eq!(config.username, "alice");
        assert_eq!(config.domain, "CORP");
    }
}
