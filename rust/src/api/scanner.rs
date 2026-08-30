use crate::frb_generated::StreamSink;
use dff_meta::DffFile;
use dsf_meta::DsfFile;
use id3::TagLike;
use lofty::config::ParseOptions;
use lofty::picture::{PictureType, APE_PICTURE_TYPES};
use lofty::prelude::*;
use lofty::probe::Probe;
use lofty::tag::Tag;
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
    /// ReplayGain loudness gain for the track (dB).
    pub replaygain_track_gain: Option<f64>,
    /// ReplayGain track peak (linear, e.g. 0.977125).
    pub replaygain_track_peak: Option<f64>,
    /// ReplayGain loudness gain for the whole album (dB).
    pub replaygain_album_gain: Option<f64>,
    /// ReplayGain album peak (linear).
    pub replaygain_album_peak: Option<f64>,
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

/// Extract metadata for a single file on demand (used by the Dart metadata
/// fallback for formats MediaMetadataRetriever cannot decode). Returns None
/// when the file cannot be read or parsed.
pub fn extract_file_metadata(path: String) -> Option<AudioFileMetadata> {
    let p = PathBuf::from(&path);
    let metadata = std::fs::metadata(&p).ok()?;
    let last_modified = metadata
        .modified()
        .ok()
        .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    extract_text_metadata_only(&FileScanEntry {
        path,
        last_modified,
        file_size: metadata.len(),
    })
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
    if let Some(picture) = tag
        .get_picture_type(PictureType::CoverFront)
        .or_else(|| tag.pictures().first())
    {
        return Some(picture.data().to_vec());
    }
    ape_cover_item(tag)
}

/// APE-tagged formats (WavPack) store cover art as binary tag items under
/// keys like "Cover Art (Front)", which never surface through
/// `Tag::pictures()`. Prefer the front cover, then any picture item.
fn ape_cover_item(tag: &Tag) -> Option<Vec<u8>> {
    for front_only in [true, false] {
        for item in tag.items() {
            let ItemKey::Unknown(key) = item.key() else {
                continue;
            };
            if !APE_PICTURE_TYPES.contains(&key.as_str()) {
                continue;
            }
            if front_only && key != "Cover Art (Front)" {
                continue;
            }
            // APE cover values are "description\0image bytes".
            let Some(bytes) = item.value().binary() else {
                continue;
            };
            if let Some(split) = bytes.iter().position(|&b| b == 0) {
                let start = split + 1;
                if start < bytes.len() {
                    return Some(bytes[start..].to_vec());
                }
            }
        }
    }
    None
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

/// Tolerant DSDIFF (DFF) chunk walker that locates the trailing "ID3 "
/// chunk. Unlike `dff_meta::DffFile`, it survives unexpected chunk ordering
/// and keeps partially parsed ID3 tags.
fn find_dff_id3_tag(path: &Path) -> Option<id3::Tag> {
    use std::io::{Read, Seek, SeekFrom};

    let mut file = std::fs::File::open(path).ok()?;
    let mut container = [0u8; 12];
    file.read_exact(&mut container).ok()?;
    if &container[..4] != b"FRM8" {
        return None;
    }
    let mut form_type = [0u8; 4];
    file.read_exact(&mut form_type).ok()?;
    if &form_type != b"DSD " {
        return None;
    }

    const MAX_ID3_CHUNK_BYTES: u64 = 64 * 1024 * 1024;
    loop {
        let mut chunk = [0u8; 12];
        if file.read_exact(&mut chunk).is_err() {
            return None;
        }
        let size = u64::from_be_bytes(chunk[4..].try_into().ok()?);
        if &chunk[..4] == b"ID3 " {
            if size > MAX_ID3_CHUNK_BYTES {
                return None;
            }
            let mut buf = vec![0u8; size as usize];
            if file.read_exact(&mut buf).is_err() {
                return None;
            }
            return match id3::Tag::read_from2(std::io::Cursor::new(buf)) {
                Ok(tag) => Some(tag),
                Err(err) => err.partial_tag,
            };
        }
        let skip = size.checked_add(size & 1)?;
        file.seek(SeekFrom::Current(skip as i64)).ok()?;
    }
}

fn extract_dff_artwork(path: &Path) -> Option<Vec<u8>> {
    // dff-meta aborts the whole open() when the trailing ID3 chunk fails to
    // parse, so read artwork through the tolerant walker instead.
    let tag = find_dff_id3_tag(path)?;
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

/// Parse a ReplayGain tag value like "-6.53 dB" (or a bare "-6.53" / "-6.53dB").
/// Returns None for anything that isn't a finite float.
fn parse_rg_db(value: Option<&str>) -> Option<f64> {
    let raw = value?.trim();
    let id3 = raw.strip_suffix("dB").or_else(|| {
        raw.strip_suffix(" dB")
    });
    let number = id3.map(str::trim).unwrap_or(raw);
    number.parse::<f64>().ok().filter(|v| v.is_finite())
}

/// Parse a ReplayGain peak value like "0.977125" (bare float).
fn parse_rg_peak(value: Option<&str>) -> Option<f64> {
    let raw = value?.trim();
    raw.parse::<f64>().ok().filter(|v| v.is_finite())
}

/// ReplayGain values from a lofty tag. Falls back to the first tag when the
/// primary has no ReplayGain frames (some taggers write them only to tag
/// versions a reader prefers incidentally).
fn lofty_replaygains(
    tag: Option<&lofty::tag::Tag>,
) -> (Option<f64>, Option<f64>, Option<f64>, Option<f64>) {
    let value = |key: ItemKey| tag.and_then(|t| t.get_string(&key));
    (
        parse_rg_db(value(ItemKey::ReplayGainTrackGain)),
        parse_rg_peak(value(ItemKey::ReplayGainTrackPeak)),
        parse_rg_db(value(ItemKey::ReplayGainAlbumGain)),
        parse_rg_peak(value(ItemKey::ReplayGainAlbumPeak)),
    )
}

/// ReplayGain values from an ID3 tag's extended text frames (used by DSD
/// files, which carry ID3 tags).
fn id3_replaygains(tag: Option<&id3::Tag>) -> (Option<f64>, Option<f64>, Option<f64>, Option<f64>) {
    let find = |description: &str| {
        tag.and_then(|t| {
            t.extended_texts()
                .find(|xt| xt.description.eq_ignore_ascii_case(description))
                .map(|xt| xt.value.as_str())
        })
    };
    (
        parse_rg_db(find("REPLAYGAIN_TRACK_GAIN")),
        parse_rg_peak(find("REPLAYGAIN_TRACK_PEAK")),
        parse_rg_db(find("REPLAYGAIN_ALBUM_GAIN")),
        parse_rg_peak(find("REPLAYGAIN_ALBUM_PEAK")),
    )
}

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
    let (rg_track_gain, rg_track_peak, rg_album_gain, rg_album_peak) =
        lofty_replaygains(tag);

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
        replaygain_track_gain: rg_track_gain,
        replaygain_track_peak: rg_track_peak,
        replaygain_album_gain: rg_album_gain,
        replaygain_album_peak: rg_album_peak,
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
            Some((entry.file_size * 8 * 1000 / ms) as u32)
        } else {
            None
        }
    });

    let tag = dsf.id3_tag().as_ref();
    let (rg_track_gain, rg_track_peak, rg_album_gain, rg_album_peak) =
        id3_replaygains(tag);
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
        replaygain_track_gain: rg_track_gain,
        replaygain_track_peak: rg_track_peak,
        replaygain_album_gain: rg_album_gain,
        replaygain_album_peak: rg_album_peak,
    })
}

fn extract_dff_metadata(
    entry: &FileScanEntry,
    path: &Path,
    format: String,
) -> Option<AudioFileMetadata> {
    // dff-meta requires a strict chunk order and fails the whole open() on
    // ID3 parse errors, so tolerate an unusable file object and recover text
    // tags through the tolerant walker.
    let dff = DffFile::open(path).ok();
    let sample_rate = dff.as_ref().and_then(|d| d.get_sample_rate().ok());
    let duration_ms = sample_rate.and_then(|rate| {
        if rate == 0 {
            return None;
        }
        let dff = dff.as_ref()?;
        let num_channels = dff.get_num_channels().ok()?;
        if num_channels == 0 {
            return None;
        }
        let total_samples = dff.get_audio_length() * 8 / num_channels as u64;
        Some((total_samples * 1000 / rate as u64) as u64)
    });
    let bitrate = duration_ms.and_then(|ms| {
        if ms > 0 {
            Some((entry.file_size * 8 * 1000 / ms) as u32)
        } else {
            None
        }
    });

    let recovered_tag;
    let tag = match dff.as_ref().and_then(|d| d.id3_tag().as_ref()) {
        Some(tag) => Some(tag),
        None => {
            recovered_tag = find_dff_id3_tag(path);
            recovered_tag.as_ref()
        }
    };
    let (rg_track_gain, rg_track_peak, rg_album_gain, rg_album_peak) =
        id3_replaygains(tag);
    Some(AudioFileMetadata {
        path: entry.path.clone(),
        title: tag.and_then(|t| t.title().map(|s| s.to_string())),
        artist: tag.and_then(|t| t.artist().map(|s| s.to_string())),
        album: tag.and_then(|t| t.album().map(|s| s.to_string())),
        duration_ms,
        format,
        last_modified: entry.last_modified,
        bit_depth: Some(1),
        sample_rate,
        bitrate,
        track_number: tag.and_then(|t| t.track()),
        disc_number: tag.and_then(|t| t.disc()),
        file_size: entry.file_size,
        replaygain_track_gain: rg_track_gain,
        replaygain_track_peak: rg_track_peak,
        replaygain_album_gain: rg_album_gain,
        replaygain_album_peak: rg_album_peak,
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
    fn extract_file_metadata_missing_file_is_none() {
        assert!(extract_file_metadata("/nonexistent/track.wv".to_string()).is_none());
    }

    #[test]
    fn extract_file_metadata_reads_minimal_wav() {
        let dir = TestDir::new("single-meta");
        let path = dir.path().join("track.wav");
        // Canonical WAV header with a tiny data chunk (lofty rejects files
        // with no audio data at all).
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"RIFF");
        bytes.extend_from_slice(&40u32.to_le_bytes());
        bytes.extend_from_slice(b"WAVE");
        bytes.extend_from_slice(b"fmt ");
        bytes.extend_from_slice(&16u32.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&44100u32.to_le_bytes());
        bytes.extend_from_slice(&44100u32.to_le_bytes());
        bytes.extend_from_slice(&2u16.to_le_bytes());
        bytes.extend_from_slice(&16u16.to_le_bytes());
        bytes.extend_from_slice(b"data");
        bytes.extend_from_slice(&4u32.to_le_bytes());
        bytes.extend_from_slice(&[0u8; 4]);
        write_bytes(&path, &bytes);

        let meta = extract_file_metadata(path.to_string_lossy().to_string());

        assert!(meta.is_some());
        let meta = meta.unwrap();
        assert_eq!(meta.format, "wav");
        assert_eq!(meta.sample_rate, Some(44100));
        assert_eq!(meta.bit_depth, Some(16));
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

    /// Minimal DSDIFF container: FRM8 header, one DSD chunk, one ID3 chunk.
    /// Deliberately omits the FVER/PROP chunks dff-meta requires so the
    /// tolerant walker paths are exercised.
    fn build_dff_bytes(id3_bytes: &[u8]) -> Vec<u8> {
        let body_len = 4 + (12 + 4) + (12 + id3_bytes.len());
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"FRM8");
        bytes.extend_from_slice(&(body_len as u64).to_be_bytes());
        bytes.extend_from_slice(b"DSD ");
        bytes.extend_from_slice(b"DSD ");
        bytes.extend_from_slice(&4u64.to_be_bytes());
        bytes.extend_from_slice(&[0u8; 4]);
        bytes.extend_from_slice(b"ID3 ");
        bytes.extend_from_slice(&(id3_bytes.len() as u64).to_be_bytes());
        bytes.extend_from_slice(id3_bytes);
        bytes
    }

    #[test]
    fn extract_artwork_from_dff_id3_chunk() {
        let dir = TestDir::new("dff-art");
        let path = dir.path().join("track.dff");
        let cover_data = b"\x89PNG\r\n\x1a\nfake-cover-bytes".to_vec();
        let mut tag = id3::Tag::new();
        tag.set_title("Dff Title");
        tag.add_frame(id3::frame::Picture {
            mime_type: "image/png".to_string(),
            picture_type: id3::frame::PictureType::CoverFront,
            description: String::new(),
            data: cover_data.clone(),
        });
        let mut id3_bytes = Vec::new();
        tag.write_to(&mut id3_bytes, id3::Version::Id3v24).unwrap();
        write_bytes(&path, &build_dff_bytes(&id3_bytes));

        let artwork = extract_embedded_artwork(path.to_string_lossy().to_string());
        assert_eq!(artwork.as_deref(), Some(cover_data.as_slice()));

        // dff-meta cannot open this fixture (no FVER/PROP), so the metadata
        // result only carries tags through the recovery walker.
        let meta = extract_file_metadata(path.to_string_lossy().to_string());
        assert!(meta.is_some());
        let meta = meta.unwrap();
        assert_eq!(meta.title.as_deref(), Some("Dff Title"));
        assert_eq!(meta.sample_rate, None);
    }

    /// WavPack file with a footer-only APEv2 tag containing a binary
    /// "Cover Art (Front)" item. The wvpk prefix is padding: lofty never
    /// parses audio blocks when properties are disabled.
    fn build_wv_bytes_with_ape_cover(cover_data: &[u8]) -> Vec<u8> {
        let mut bytes = vec![0u8; 32];
        bytes[..4].copy_from_slice(b"wvpk");

        let mut value = Vec::new();
        value.extend_from_slice(b"cover\x00");
        value.extend_from_slice(cover_data);

        let mut item = Vec::new();
        item.extend_from_slice(&(value.len() as u32).to_le_bytes());
        item.extend_from_slice(&2u32.to_le_bytes());
        item.extend_from_slice(b"Cover Art (Front)\x00");
        item.extend_from_slice(&value);

        let tag_size = item.len() + 32;
        let mut footer = Vec::new();
        footer.extend_from_slice(b"APETAGEX");
        footer.extend_from_slice(&2000u32.to_le_bytes());
        footer.extend_from_slice(&(tag_size as u32).to_le_bytes());
        footer.extend_from_slice(&1u32.to_le_bytes());
        footer.extend_from_slice(&0u32.to_le_bytes());
        footer.extend_from_slice(&[0u8; 8]);

        bytes.extend_from_slice(&item);
        bytes.extend_from_slice(&footer);
        bytes
    }

    #[test]
    fn extract_artwork_from_wavpack_ape_cover_item() {
        let dir = TestDir::new("wv-art");
        let path = dir.path().join("track.wv");
        let cover_data = b"\x89PNG\r\n\x1a\nape-cover-payload".to_vec();
        write_bytes(&path, &build_wv_bytes_with_ape_cover(&cover_data));

        let artwork = extract_embedded_artwork(path.to_string_lossy().to_string());

        assert_eq!(artwork.as_deref(), Some(cover_data.as_slice()));
    }
}
