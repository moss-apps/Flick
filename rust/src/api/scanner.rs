use crate::frb_generated::StreamSink;
use dff_meta::DffFile;
use dsf_meta::DsfFile;
use id3::TagLike;
use lofty::config::ParseOptions;
use lofty::picture::PictureType;
use lofty::prelude::*;
use lofty::probe::Probe;
use rayon::prelude::*;
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

const SCAN_BATCH_SIZE: usize = 500;

#[derive(Debug, Clone)]
pub struct ScanOptions {
    pub filter_non_music_files_and_folders: bool,
}

#[derive(Debug, Clone)]
pub struct AudioFileMetadata {
    pub path: String,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub duration_ms: Option<u64>,
    pub format: String,
    pub last_modified: i64,
    pub bit_depth: Option<u8>,
    pub sample_rate: Option<u32>,
    pub bitrate: Option<u32>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub file_size: u64,
}

#[derive(Debug, Clone)]
pub struct ScanResult {
    pub new_or_modified: Vec<AudioFileMetadata>,
    pub deleted_paths: Vec<String>,
    pub total_files: u32,
}

#[derive(Debug, Clone)]
pub struct ScanChunk {
    pub new_or_modified: Vec<AudioFileMetadata>,
    pub deleted_paths: Vec<String>,
    pub total_files: u32,
    pub is_complete: bool,
}

#[derive(Debug, Clone)]
struct FileScanEntry {
    path: String,
    last_modified: i64,
    file_size: u64,
}

fn is_supported_audio_path(path: &Path) -> bool {
    let ext = path
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    matches!(
        ext.as_str(),
        "mp3"
            | "flac"
            | "ogg"
            | "oga"
            | "ogx"
            | "opus"
            | "m4a"
            | "wav"
            | "aif"
            | "aiff"
            | "alac"
            | "dsf"
            | "dff"
            | "wv"
    )
}

pub fn scan_root_dir(
    root_path: String,
    known_files: HashMap<String, i64>,
    scan_options: ScanOptions,
) -> ScanResult {
    let files_on_disk = collect_scan_file_entries(&root_path, &scan_options);
    let total_files = files_on_disk.len() as u32;
    let (to_process, deleted_paths, _) = classify_scan_work(files_on_disk, &known_files);

    let new_or_modified = to_process
        .par_iter()
        .filter_map(extract_text_metadata_only)
        .collect();

    ScanResult {
        new_or_modified,
        deleted_paths,
        total_files,
    }
}

pub async fn scan_music_library(
    root_path: String,
    known_files: HashMap<String, i64>,
    scan_options: ScanOptions,
    sink: StreamSink<ScanChunk>,
) -> anyhow::Result<()> {
    let files_on_disk = collect_scan_file_entries(&root_path, &scan_options);
    let total_files = files_on_disk.len() as u32;
    let (to_process, deleted_paths, _) = classify_scan_work(files_on_disk, &known_files);

    sink.add(ScanChunk {
        new_or_modified: Vec::new(),
        deleted_paths,
        total_files,
        is_complete: false,
    })
    .map_err(|err| anyhow::anyhow!(err.to_string()))?;

    for chunk in to_process.chunks(SCAN_BATCH_SIZE) {
        let new_or_modified = chunk
            .par_iter()
            .filter_map(extract_text_metadata_only)
            .collect::<Vec<_>>();

        if new_or_modified.is_empty() {
            continue;
        }

        sink.add(ScanChunk {
            new_or_modified,
            deleted_paths: Vec::new(),
            total_files,
            is_complete: false,
        })
        .map_err(|err| anyhow::anyhow!(err.to_string()))?;
    }

    sink.add(ScanChunk {
        new_or_modified: Vec::new(),
        deleted_paths: Vec::new(),
        total_files,
        is_complete: true,
    })
    .map_err(|err| anyhow::anyhow!(err.to_string()))?;

    Ok(())
}

pub fn discover_playlist_files(root_path: String, scan_options: ScanOptions) -> Vec<String> {
    collect_playlist_file_entries(&root_path, &scan_options)
        .into_iter()
        .map(|entry| entry.path)
        .collect()
}

pub fn check_deleted_paths(
    root_path: String,
    known_files: HashMap<String, i64>,
    scan_options: ScanOptions,
) -> Vec<String> {
    let files_on_disk = collect_scan_file_entries(&root_path, &scan_options);
    let (_, deleted_paths, _) = classify_scan_work(files_on_disk, &known_files);
    deleted_paths
}

pub fn extract_embedded_artwork(path: String) -> Option<Vec<u8>> {
    let p = PathBuf::from(&path);
    let ext = p
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    match ext.as_str() {
        "dsf" => extract_dsf_artwork(&p),
        "dff" => extract_dff_artwork(&p),
        _ => extract_lofty_artwork(&p),
    }
}

fn extract_lofty_artwork(path: &Path) -> Option<Vec<u8>> {
    let parse_options = ParseOptions::new().read_properties(false);
    let tagged_file = Probe::open(path)
        .ok()?
        .options(parse_options)
        .guess_file_type()
        .ok()?
        .read()
        .ok()?;
    let tag = tagged_file
        .primary_tag()
        .or_else(|| tagged_file.first_tag())?;
    let picture = tag
        .get_picture_type(PictureType::CoverFront)
        .or_else(|| tag.pictures().first())?;

    Some(picture.data().to_vec())
}

fn extract_dsf_artwork(path: &Path) -> Option<Vec<u8>> {
    let dsf = DsfFile::open(path).ok()?;
    let tag = dsf.id3_tag().as_ref()?;
    let cover = tag
        .pictures()
        .find(|p| p.picture_type == id3::frame::PictureType::CoverFront)
        .or_else(|| tag.pictures().next())?;
    Some(cover.data.clone())
}

fn extract_dff_artwork(path: &Path) -> Option<Vec<u8>> {
    let dff = DffFile::open(path).ok()?;
    let tag = dff.id3_tag().as_ref()?;
    let cover = tag
        .pictures()
        .find(|p| p.picture_type == id3::frame::PictureType::CoverFront)
        .or_else(|| tag.pictures().next())?;
    Some(cover.data.clone())
}

fn collect_scan_file_entries(root_path: &str, scan_options: &ScanOptions) -> Vec<FileScanEntry> {
    collect_file_entries(root_path, scan_options, |path| {
        if scan_options.filter_non_music_files_and_folders {
            is_supported_audio_path(path)
        } else {
            true
        }
    })
}

fn collect_playlist_file_entries(
    root_path: &str,
    scan_options: &ScanOptions,
) -> Vec<FileScanEntry> {
    collect_file_entries(root_path, scan_options, is_supported_playlist_path)
}

fn collect_file_entries<F>(
    root_path: &str,
    scan_options: &ScanOptions,
    should_include: F,
) -> Vec<FileScanEntry>
where
    F: Fn(&Path) -> bool,
{
    let mut nomedia_cache = HashMap::new();
    let respect_nomedia = scan_options.filter_non_music_files_and_folders;

    WalkDir::new(root_path)
        .follow_links(false)
        .max_open(64)
        .into_iter()
        .filter_map(|result| match result {
            Ok(entry) => Some(entry),
            Err(err) => {
                log::warn!("scanner: failed to read directory entry: {}", err);
                None
            }
        })
        .filter(|entry| entry.file_type().is_file())
        .filter_map(|entry| {
            let path = entry.path();
            if respect_nomedia && is_in_nomedia_subtree(path, &mut nomedia_cache) {
                return None;
            }
            if !should_include(path) {
                return None;
            }

            let metadata = match std::fs::metadata(path) {
                Ok(meta) => meta,
                Err(err) => {
                    log::warn!(
                        "scanner: failed to read metadata for {}: {}",
                        path.display(),
                        err
                    );
                    return None;
                }
            };
            let last_modified = metadata
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0);

            Some(FileScanEntry {
                path: path.to_string_lossy().to_string(),
                last_modified,
                file_size: metadata.len(),
            })
        })
        .collect()
}

fn is_supported_playlist_path(path: &Path) -> bool {
    let ext = path
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    matches!(ext.as_str(), "m3u" | "m3u8")
}

fn is_in_nomedia_subtree(path: &Path, cache: &mut HashMap<PathBuf, bool>) -> bool {
    path.parent()
        .map(|parent| directory_is_nomedia_blocked(parent, cache))
        .unwrap_or(false)
}

fn directory_is_nomedia_blocked(dir: &Path, cache: &mut HashMap<PathBuf, bool>) -> bool {
    if let Some(cached) = cache.get(dir) {
        return *cached;
    }

    let blocked = dir.join(".nomedia").is_file()
        || dir
            .parent()
            .map(|parent| directory_is_nomedia_blocked(parent, cache))
            .unwrap_or(false);

    cache.insert(dir.to_path_buf(), blocked);
    blocked
}

fn classify_scan_work(
    files_on_disk: Vec<FileScanEntry>,
    known_files: &HashMap<String, i64>,
) -> (Vec<FileScanEntry>, Vec<String>, HashSet<String>) {
    let mut found_paths = HashSet::with_capacity(files_on_disk.len());
    let mut to_process = Vec::new();

    for file in files_on_disk {
        let path = file.path.clone();
        let needs_processing = known_files.get(&path).map_or(true, |known_timestamp| {
            *known_timestamp != file.last_modified
        });

        found_paths.insert(path);

        if needs_processing {
            to_process.push(file);
        }
    }

    let deleted_paths = known_files
        .keys()
        .filter(|path| !found_paths.contains(*path))
        .cloned()
        .collect::<Vec<_>>();

    (to_process, deleted_paths, found_paths)
}

const DSD_SAMPLE_RATE_THRESHOLD: u32 = 2_822_400;

fn extract_text_metadata_only(entry: &FileScanEntry) -> Option<AudioFileMetadata> {
    let path = PathBuf::from(&entry.path);
    let format = path
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();

    match format.as_str() {
        "dsf" => extract_dsf_metadata(entry, &path, format),
        "dff" => extract_dff_metadata(entry, &path, format),
        "wv" => extract_wavpack_metadata(entry, &path, format),
        _ => extract_lofty_metadata(entry, &path, format),
    }
}

fn extract_lofty_metadata(
    entry: &FileScanEntry,
    path: &Path,
    format: String,
) -> Option<AudioFileMetadata> {
    let parse_options = ParseOptions::new().read_cover_art(false);
    let tagged_file = Probe::open(path)
        .ok()?
        .options(parse_options)
        .guess_file_type()
        .ok()?
        .read()
        .ok()?;
    let tag = tagged_file
        .primary_tag()
        .or_else(|| tagged_file.first_tag());
    let properties = tagged_file.properties();
    let duration_ms = properties.duration().as_millis().min(u128::from(u64::MAX)) as u64;

    Some(AudioFileMetadata {
        path: entry.path.clone(),
        title: tag.and_then(|t| t.title().map(|s| s.to_string())),
        artist: tag.and_then(|t| t.artist().map(|s| s.to_string())),
        album: tag.and_then(|t| t.album().map(|s| s.to_string())),
        duration_ms: Some(duration_ms),
        format,
        last_modified: entry.last_modified,
        bit_depth: properties.bit_depth(),
        sample_rate: properties.sample_rate(),
        bitrate: properties.audio_bitrate(),
        track_number: tag.and_then(|t| t.track()),
        disc_number: tag.and_then(|t| t.disk()),
        file_size: entry.file_size,
    })
}

fn extract_wavpack_metadata(
    entry: &FileScanEntry,
    path: &Path,
    format: String,
) -> Option<AudioFileMetadata> {
    let result = extract_lofty_metadata(entry, path, format);
    result.map(|mut meta| {
        let is_dsd = meta
            .sample_rate
            .map_or(false, |sr| sr >= DSD_SAMPLE_RATE_THRESHOLD)
            || meta.bit_depth == Some(1);
        if is_dsd {
            meta.format = "wv-dsd".to_string();
        }
        meta
    })
}

fn extract_dsf_metadata(
    entry: &FileScanEntry,
    path: &Path,
    format: String,
) -> Option<AudioFileMetadata> {
    let dsf = DsfFile::open(path).ok()?;
    let fmt = dsf.fmt_chunk();
    let sample_rate = fmt.sampling_frequency();
    let sample_count = fmt.sample_count();
    let duration_ms = if sample_rate > 0 {
        Some((sample_count * 1000 / sample_rate as u64) as u64)
    } else {
        None
    };
    let bit_depth = if fmt.bits_per_sample() == 1 {
        Some(1u8)
    } else {
        Some(fmt.bits_per_sample() as u8)
    };
    let bitrate = duration_ms.and_then(|ms| {
        if ms > 0 {
            Some((entry.file_size * 8 / 1000 / ms) as u32)
        } else {
            None
        }
    });

    let tag = dsf.id3_tag().as_ref();
    Some(AudioFileMetadata {
        path: entry.path.clone(),
        title: tag.and_then(|t| t.title().map(|s| s.to_string())),
        artist: tag.and_then(|t| t.artist().map(|s| s.to_string())),
        album: tag.and_then(|t| t.album().map(|s| s.to_string())),
        duration_ms,
        format,
        last_modified: entry.last_modified,
        bit_depth,
        sample_rate: Some(sample_rate),
        bitrate,
        track_number: tag.and_then(|t| t.track()),
        disc_number: tag.and_then(|t| t.disc()),
        file_size: entry.file_size,
    })
}

fn extract_dff_metadata(
    entry: &FileScanEntry,
    path: &Path,
    format: String,
) -> Option<AudioFileMetadata> {
    let dff = DffFile::open(path).ok()?;
    let sample_rate = dff.get_sample_rate().ok()?;
    let num_channels = dff.get_num_channels().ok()?;
    let audio_length = dff.get_audio_length();
    let duration_ms = if sample_rate > 0 && num_channels > 0 {
        let total_samples = audio_length * 8 / num_channels as u64;
        Some((total_samples * 1000 / sample_rate as u64) as u64)
    } else {
        None
    };
    let bitrate = duration_ms.and_then(|ms| {
        if ms > 0 {
            Some((entry.file_size * 8 / 1000 / ms) as u32)
        } else {
            None
        }
    });

    let tag = dff.id3_tag().as_ref();
    Some(AudioFileMetadata {
        path: entry.path.clone(),
        title: tag.and_then(|t| t.title().map(|s| s.to_string())),
        artist: tag.and_then(|t| t.artist().map(|s| s.to_string())),
        album: tag.and_then(|t| t.album().map(|s| s.to_string())),
        duration_ms,
        format,
        last_modified: entry.last_modified,
        bit_depth: Some(1),
        sample_rate: Some(sample_rate),
        bitrate,
        track_number: tag.and_then(|t| t.track()),
        disc_number: tag.and_then(|t| t.disc()),
        file_size: entry.file_size,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use lofty::file::FileType;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct TestDir {
        path: PathBuf,
    }

    impl TestDir {
        fn new(label: &str) -> Self {
            let unique_suffix = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos();
            let path = std::env::temp_dir().join(format!(
                "flick-player-scanner-{label}-{}-{unique_suffix}",
                std::process::id()
            ));
            fs::create_dir_all(&path).unwrap();
            Self { path }
        }

        fn path(&self) -> &Path {
            &self.path
        }
    }

    impl Drop for TestDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.path);
        }
    }

    fn write_bytes(path: &Path, contents: &[u8]) {
        fs::write(path, contents).unwrap();
    }

    #[test]
    fn guess_file_type_detects_vorbis_for_oga_extension() {
        let dir = TestDir::new("oga");
        let path = dir.path().join("sample.oga");
        let mut bytes = [0_u8; 36];
        bytes[..4].copy_from_slice(b"OggS");
        bytes[29..35].copy_from_slice(b"vorbis");
        write_bytes(&path, &bytes);

        let probe = Probe::open(&path).unwrap().guess_file_type().unwrap();

        assert_eq!(probe.file_type(), Some(FileType::Vorbis));
    }

    #[test]
    fn guess_file_type_detects_opus_for_ogx_extension() {
        let dir = TestDir::new("ogx");
        let path = dir.path().join("sample.ogx");
        let mut bytes = [0_u8; 36];
        bytes[..4].copy_from_slice(b"OggS");
        bytes[28..36].copy_from_slice(b"OpusHead");
        write_bytes(&path, &bytes);

        let probe = Probe::open(&path).unwrap().guess_file_type().unwrap();

        assert_eq!(probe.file_type(), Some(FileType::Opus));
    }

    fn write_dummy_mp3(path: &Path) {
        // Enough bytes for the scanner to treat this as a regular file. We use
        // the extension to decide inclusion, so content can be arbitrary.
        fs::write(path, &[0u8; 16]).unwrap();
    }

    #[test]
    fn hidden_files_and_folders_are_scanned() {
        let dir = TestDir::new("hidden");
        let hidden_dir = dir.path().join(".hidden_albums");
        fs::create_dir_all(&hidden_dir).unwrap();
        write_dummy_mp3(&hidden_dir.join("track1.mp3"));
        write_dummy_mp3(&dir.path().join(".hidden_track.mp3"));
        write_dummy_mp3(&dir.path().join("visible.mp3"));

        let entries = collect_scan_file_entries(
            dir.path().to_str().unwrap(),
            &ScanOptions {
                filter_non_music_files_and_folders: true,
            },
        );
        let paths: HashSet<_> = entries.into_iter().map(|e| e.path).collect();

        assert!(paths.contains(hidden_dir.join("track1.mp3").to_str().unwrap()));
        assert!(paths.contains(dir.path().join(".hidden_track.mp3").to_str().unwrap()));
        assert!(paths.contains(dir.path().join("visible.mp3").to_str().unwrap()));
    }

    #[test]
    fn nomedia_folder_is_skipped() {
        let dir = TestDir::new("nomedia");
        let normal = dir.path().join("normal");
        let blocked = dir.path().join("blocked");
        fs::create_dir_all(&normal).unwrap();
        fs::create_dir_all(&blocked).unwrap();
        fs::write(blocked.join(".nomedia"), "").unwrap();
        write_dummy_mp3(&normal.join("track.mp3"));
        write_dummy_mp3(&blocked.join("track.mp3"));

        let entries = collect_scan_file_entries(
            dir.path().to_str().unwrap(),
            &ScanOptions {
                filter_non_music_files_and_folders: true,
            },
        );
        let paths: Vec<_> = entries.into_iter().map(|e| e.path).collect();

        assert!(paths
            .iter()
            .any(|p| p == normal.join("track.mp3").to_str().unwrap()));
        assert!(!paths
            .iter()
            .any(|p| p == blocked.join("track.mp3").to_str().unwrap()));
    }

    #[test]
    fn deep_tree_is_collected() {
        let dir = TestDir::new("deep");
        let mut current = dir.path().to_path_buf();
        for i in 0..64 {
            current = current.join(format!("level{i:02}"));
        }
        fs::create_dir_all(&current).unwrap();
        write_dummy_mp3(&current.join("deep_track.mp3"));

        let entries = collect_scan_file_entries(
            dir.path().to_str().unwrap(),
            &ScanOptions {
                filter_non_music_files_and_folders: true,
            },
        );

        assert_eq!(entries.len(), 1);
    }
}
