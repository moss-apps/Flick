use dsf_meta::DsfFile;
use lofty::config::{ParseOptions, WriteOptions};
use lofty::file::AudioFile;
use lofty::prelude::*;
use lofty::probe::Probe;
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagWriteResult {
    pub success: bool,
    pub error: Option<String>,
    pub temp_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagReadResult {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub genre: Option<String>,
    pub year: Option<u32>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub date: Option<String>,
    pub copyright: Option<String>,
    pub label: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagEditFields {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub genre: Option<String>,
    pub year: Option<u32>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
}

pub fn read_tags(path: String) -> Result<TagReadResult, String> {
    // lofty cannot parse DSD containers (.dsf/.dff), but both carry plain
    // ID3v2 tags; read those directly so DSD tracks expose the same fields.
    if let Some(tag) = read_dsd_id3_tag(&path) {
        return Ok(tag_read_result_from_id3(&tag));
    }

    let parse_options = ParseOptions::new().read_cover_art(false);
    let tagged_file = Probe::open(&path)
        .map_err(|e| format!("Failed to open file: {e}"))?
        .options(parse_options)
        .guess_file_type()
        .map_err(|e| format!("Failed to guess file type: {e}"))?
        .read()
        .map_err(|e| format!("Failed to read file: {e}"))?;

    let tag = tagged_file
        .primary_tag()
        .or_else(|| tagged_file.first_tag());

    match tag {
        Some(t) => Ok(TagReadResult {
            title: t.title().map(|s| s.to_string()),
            artist: t.artist().map(|s| s.to_string()),
            album: t.album().map(|s| s.to_string()),
            album_artist: t.get_string(&ItemKey::AlbumArtist).map(|s| s.to_string()),
            genre: t.genre().map(|s| s.to_string()),
            year: t.year(),
            track_number: t.track(),
            disc_number: t.disk(),
            date: t.get_string(&ItemKey::RecordingDate).map(|s| s.to_string()),
            copyright: t
                .get_string(&ItemKey::CopyrightMessage)
                .map(|s| s.to_string()),
            label: t.get_string(&ItemKey::Label).map(|s| s.to_string()),
        }),
        None => Ok(TagReadResult {
            title: None,
            artist: None,
            album: None,
            album_artist: None,
            genre: None,
            year: None,
            track_number: None,
            disc_number: None,
            date: None,
            copyright: None,
            label: None,
        }),
    }
}

pub fn write_tags(path: String, fields: TagEditFields) -> Result<TagWriteResult, String> {
    let parse_options = ParseOptions::new().read_cover_art(true);
    let mut tagged_file = Probe::open(&path)
        .map_err(|e| format!("Failed to open file: {e}"))?
        .options(parse_options)
        .guess_file_type()
        .map_err(|e| format!("Failed to guess file type: {e}"))?
        .read()
        .map_err(|e| format!("Failed to read file: {e}"))?;

    match apply_tag_fields(&mut tagged_file, &fields) {
        Ok(()) => {}
        Err(e) => {
            return Ok(TagWriteResult {
                success: false,
                error: Some(e),
                temp_path: None,
            })
        }
    }

    match tagged_file.save_to_path(&path, WriteOptions::default()) {
        Ok(()) => Ok(TagWriteResult {
            success: true,
            error: None,
            temp_path: None,
        }),
        Err(e) => Ok(TagWriteResult {
            success: false,
            error: Some(format!("Failed to save tags: {e}")),
            temp_path: None,
        }),
    }
}

pub fn write_tags_to_temp(
    path: String,
    fields: TagEditFields,
    temp_dir: String,
) -> Result<TagWriteResult, String> {
    let parse_options = ParseOptions::new().read_cover_art(true);
    let mut tagged_file = Probe::open(&path)
        .map_err(|e| format!("Failed to open file: {e}"))?
        .options(parse_options)
        .guess_file_type()
        .map_err(|e| format!("Failed to guess file type: {e}"))?
        .read()
        .map_err(|e| format!("Failed to read file: {e}"))?;

    match apply_tag_fields(&mut tagged_file, &fields) {
        Ok(()) => {}
        Err(e) => {
            return Ok(TagWriteResult {
                success: false,
                error: Some(e),
                temp_path: None,
            })
        }
    }

    let original_path = Path::new(&path);
    let extension = original_path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("flac");
    let file_name = original_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("temp_audio");

    let temp_path = Path::new(&temp_dir).join(format!("{}.tmp.{}", file_name, extension));

    if let Some(parent) = temp_path.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create temp directory: {e}"))?;
    }

    // lofty's save_to_path opens the destination read+write WITHOUT create, so
    // the file must already exist. Stage a byte-for-byte copy of the original
    // and rewrite its tags in place.
    std::fs::copy(&path, &temp_path)
        .map_err(|e| format!("Failed to stage temp copy: {e}"))?;

    tagged_file
        .save_to_path(&temp_path, WriteOptions::default())
        .map_err(|e| format!("Failed to save tags to temp file: {e}"))?;

    Ok(TagWriteResult {
        success: true,
        error: None,
        temp_path: Some(temp_path.to_string_lossy().to_string()),
    })
}

/// Returns the ID3v2 tag for DSD containers, which lofty cannot open.
fn read_dsd_id3_tag(path: &str) -> Option<id3::Tag> {
    let p = Path::new(path);
    let ext = p.extension()?.to_str()?.to_ascii_lowercase();
    match ext.as_str() {
        "dsf" => DsfFile::open(p).ok().and_then(|f| f.id3_tag().clone()),
        "dff" => crate::api::scanner::find_dff_id3_tag(p),
        _ => None,
    }
}

fn id3_text_frame(tag: &id3::Tag, id: &str) -> Option<String> {
    tag.frames()
        .find(|f| f.id() == id)
        .and_then(|f| f.content().text())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn tag_read_result_from_id3(tag: &id3::Tag) -> TagReadResult {
    use id3::TagLike;
    TagReadResult {
        title: tag.title().map(|s| s.to_string()),
        artist: tag.artist().map(|s| s.to_string()),
        album: tag.album().map(|s| s.to_string()),
        album_artist: tag.album_artist().map(|s| s.to_string()),
        genre: tag.genre_parsed().map(|s| s.to_string()),
        year: tag.year().filter(|y| *y > 0).map(|y| y as u32),
        track_number: tag.track().map(|u| u as u32),
        disc_number: tag.disc().map(|u| u as u32),
        date: tag.date_recorded().map(|t| t.to_string()),
        copyright: id3_text_frame(tag, "TCOP"),
        label: id3_text_frame(tag, "TPUB"),
    }
}

fn apply_tag_fields(
    tagged_file: &mut lofty::file::TaggedFile,
    fields: &TagEditFields,
) -> Result<(), String> {    let tag = tagged_file.primary_tag_mut();
    let tag = match tag {
        Some(t) => Some(t),
        None => tagged_file.first_tag_mut(),
    };

    match tag {
        Some(t) => {
            if let Some(ref v) = fields.title {
                t.set_title(v.clone());
            }
            if let Some(ref v) = fields.artist {
                t.set_artist(v.clone());
            }
            if let Some(ref v) = fields.album {
                t.set_album(v.clone());
            }
            if let Some(ref v) = fields.album_artist {
                t.insert_text(ItemKey::AlbumArtist, v.clone());
            }
            if let Some(ref v) = fields.genre {
                t.set_genre(v.clone());
            }
            if let Some(v) = fields.year {
                t.set_year(v);
            }
            if let Some(v) = fields.track_number {
                t.set_track(v);
            }
            if let Some(v) = fields.disc_number {
                t.set_disk(v);
            }
            Ok(())
        }
        None => Err("No tag found in file".to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Hand-builds a minimal FLAC: a STREAMINFO block followed by a
    /// VORBIS_COMMENT block carrying `comments` as "KEY=value" pairs.
    fn write_minimal_flac(path: &Path, comments: &[&str]) {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"fLaC");

        // STREAMINFO is 34 bytes; only the 18-byte header matters here, the
        // trailing 16-byte MD5 can stay zero.
        let mut streaminfo = vec![0u8; 34];
        streaminfo[0..2].copy_from_slice(&4096u16.to_be_bytes());
        streaminfo[2..4].copy_from_slice(&4096u16.to_be_bytes());
        let mut packed: u64 = 0;
        packed |= (44100u64 & 0xFFFFF) << 44; // sample rate
        packed |= (1u64 & 0x7) << 41; // channels - 1
        packed |= (15u64 & 0x1F) << 36; // bits per sample - 1
        streaminfo[10..18].copy_from_slice(&packed.to_be_bytes());
        bytes.push(0x00); // STREAMINFO, not last
        bytes.extend_from_slice(&34u32.to_be_bytes()[1..]);
        bytes.extend_from_slice(&streaminfo);

        let mut vorbis = Vec::new();
        let vendor = b"flick-test";
        vorbis.extend_from_slice(&(vendor.len() as u32).to_le_bytes());
        vorbis.extend_from_slice(vendor);
        vorbis.extend_from_slice(&(comments.len() as u32).to_le_bytes());
        for comment in comments {
            vorbis.extend_from_slice(&(comment.len() as u32).to_le_bytes());
            vorbis.extend_from_slice(comment.as_bytes());
        }
        bytes.push(0x80 | 0x04); // VORBIS_COMMENT, last block
        bytes.extend_from_slice(&(vorbis.len() as u32).to_be_bytes()[1..]);
        bytes.extend_from_slice(&vorbis);

        std::fs::write(path, bytes).unwrap();
    }

    #[test]
    fn read_tags_exposes_date_copyright_and_label() {
        let dir = std::env::temp_dir().join(format!("flick_meta_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("sample.flac");
        write_minimal_flac(
            &path,
            &[
                "TITLE=Test Title",
                "ARTIST=Test Artist",
                "ALBUM=Test Album",
                "ALBUMARTIST=Test Album Artist",
                "GENRE=Jazz",
                "DATE=2024-03-15",
                "COPYRIGHT=2024 Test Label",
                "LABEL=Test Label",
                "TRACKNUMBER=7",
                "DISCNUMBER=2",
            ],
        );

        let tags = read_tags(path.to_string_lossy().to_string()).unwrap();

        assert_eq!(tags.title.as_deref(), Some("Test Title"));
        assert_eq!(tags.artist.as_deref(), Some("Test Artist"));
        assert_eq!(tags.album.as_deref(), Some("Test Album"));
        assert_eq!(tags.genre.as_deref(), Some("Jazz"));
        // DATE drives the year fallback even without a YEAR tag.
        assert_eq!(tags.year, Some(2024));
        assert_eq!(tags.date.as_deref(), Some("2024-03-15"));
        assert_eq!(tags.copyright.as_deref(), Some("2024 Test Label"));
        assert_eq!(tags.label.as_deref(), Some("Test Label"));
        assert_eq!(tags.track_number, Some(7));
        assert_eq!(tags.disc_number, Some(2));

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// Minimal DSDIFF container (FRM8 + DSD + ID3 chunks) exercising the
    /// non-lofty DSD branch of read_tags.
    #[test]
    fn read_tags_parses_dff_id3_tag() {
        let mut tag = id3::Tag::new();
        use id3::TagLike;
        tag.set_title("Dsd Title");
        tag.set_artist("Dsd Artist");
        tag.set_genre("Ambient");
        tag.set_year(2021);
        tag.set_track(3);
        tag.set_disc(1);
        tag.set_date_recorded(id3::Timestamp {
            year: 2021,
            month: Some(6),
            day: Some(1),
            hour: None,
            minute: None,
            second: None,
        });
        tag.set_text("TCOP", "2021 Dsd Label");
        tag.set_text("TPUB", "Dsd Label");
        let mut id3_bytes = Vec::new();
        tag.write_to(&mut id3_bytes, id3::Version::Id3v24).unwrap();

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
        bytes.extend_from_slice(&id3_bytes);

        let dir = std::env::temp_dir().join(format!("flick_dff_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("track.dff");
        std::fs::write(&path, &bytes).unwrap();

        let tags = read_tags(path.to_string_lossy().to_string()).unwrap();

        assert_eq!(tags.title.as_deref(), Some("Dsd Title"));
        assert_eq!(tags.artist.as_deref(), Some("Dsd Artist"));
        assert_eq!(tags.genre.as_deref(), Some("Ambient"));
        assert_eq!(tags.year, Some(2021));
        assert_eq!(tags.track_number, Some(3));
        assert_eq!(tags.disc_number, Some(1));
        assert_eq!(tags.date.as_deref(), Some("2021-06-01"));
        assert_eq!(tags.copyright.as_deref(), Some("2021 Dsd Label"));
        assert_eq!(tags.label.as_deref(), Some("Dsd Label"));

        let _ = std::fs::remove_dir_all(&dir);
    }
}
