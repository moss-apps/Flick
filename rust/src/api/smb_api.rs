use crate::frb_generated::StreamSink;
use std::collections::VecDeque;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

// Only allowlisted stage/code pairs cross the bridge. smb2 errors can contain
// hostnames, account names and remote paths; never attach them as error sources.
fn failure(stage: &str, error: smb2::Error) -> anyhow::Error {
    use smb2::ErrorKind;
    let code = match error.kind() {
        ErrorKind::AuthRequired => "auth",
        ErrorKind::SigningRequired => "signing",
        ErrorKind::AccessDenied => "denied",
        ErrorKind::NotFound | ErrorKind::NotADirectory => "not_found",
        ErrorKind::TimedOut => "timeout",
        ErrorKind::ConnectionLost | ErrorKind::SessionExpired => "connection",
        ErrorKind::Io => "connection",
        _ => "protocol",
    };
    anyhow::anyhow!("SMB stage={} code={}", stage, code)
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
    let mut client = smb2::connect(&addr(&host, port), &user, &pass)
        .await
        .map_err(|e| failure("connect", e))?;
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
pub async fn smb_list_share(
    host: String,
    port: u16,
    share: String,
    user: String,
    pass: String,
    root_path: String,
    sink: StreamSink<SmbEntry>,
) -> anyhow::Result<()> {
    let mut client = smb2::connect(&addr(&host, port), &user, &pass)
        .await
        .map_err(|e| failure("connect", e))?;
    let mut tree = client
        .connect_share(&share)
        .await
        .map_err(|e| failure("share", e))?;

    let mut queue: VecDeque<String> = VecDeque::new();
    queue.push_back(root_path);

    while let Some(dir) = queue.pop_front() {
        let entries = client
            .list_directory(&mut tree, &dir)
            .await
            .map_err(|e| failure("root", e))?;
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
                queue.push_back(child_path);
            }
        }
    }
    Ok(())
}

/// Read a full (small) file into memory — cover art and tiny sidecars.
pub async fn smb_read_file(
    host: String,
    port: u16,
    share: String,
    path: String,
    user: String,
    pass: String,
) -> anyhow::Result<Vec<u8>> {
    let mut client = smb2::connect(&addr(&host, port), &user, &pass)
        .await
        .map_err(|e| failure("connect", e))?;
    let mut tree = client
        .connect_share(&share)
        .await
        .map_err(|e| failure("share", e))?;
    let bytes = client
        .read_file(&mut tree, &path)
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
    let mut client = smb2::connect(&addr(&host, port), &user, &pass)
        .await
        .map_err(|e| failure("connect", e))?;
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
    use super::{addr, failure, PendingDownload};
    use std::io::Write;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

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
}
