use crate::frb_generated::StreamSink;
use std::collections::VecDeque;
use std::fs::File;
use std::io::Write;

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

fn addr(host: &str, port: u16) -> String {
    format!("{}:{}", host, port)
}

/// Connect + open the share. Used by the ping flow; success means credentials
/// and transport are good. (smb2::connect applies a 5s timeout.)
pub async fn smb_ping(
    host: String,
    port: u16,
    share: String,
    user: String,
    pass: String,
) -> anyhow::Result<()> {
    let mut client = smb2::connect(&addr(&host, port), &user, &pass).await?;
    let _tree = client.connect_share(&share).await?;
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
    let mut client = smb2::connect(&addr(&host, port), &user, &pass).await?;
    let mut tree = client.connect_share(&share).await?;

    let mut queue: VecDeque<String> = VecDeque::new();
    queue.push_back(root_path);

    while let Some(dir) = queue.pop_front() {
        let entries = client.list_directory(&mut tree, &dir).await?;
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
            .map_err(|err| anyhow::anyhow!(err.to_string()))?;
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
    let mut client = smb2::connect(&addr(&host, port), &user, &pass).await?;
    let mut tree = client.connect_share(&share).await?;
    let bytes = client.read_file(&mut tree, &path).await?;
    Ok(bytes)
}

/// Stream a file directly to `dest_path` on disk, reporting progress per chunk.
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
    let mut client = smb2::connect(&addr(&host, port), &user, &pass).await?;
    let tree = client.connect_share(&share).await?;
    let mut download = client.download(&tree, &path).await?;
    let total = download.size();
    let mut file = File::create(&dest_path)?;
    let mut received: u64 = 0;
    while let Some(chunk) = download.next_chunk().await {
        let chunk = chunk?;
        file.write_all(&chunk)?;
        received += chunk.len() as u64;
        sink.add(SmbProgress {
            received,
            total,
            is_complete: false,
        })
        .map_err(|err| anyhow::anyhow!(err.to_string()))?;
    }
    file.flush()?;
    sink.add(SmbProgress {
        received,
        total,
        is_complete: true,
    })
    .map_err(|err| anyhow::anyhow!(err.to_string()))?;
    Ok(())
}
