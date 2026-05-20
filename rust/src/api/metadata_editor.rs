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

    tagged_file
        .save_to_path(&temp_path, WriteOptions::default())
        .map_err(|e| format!("Failed to save tags to temp file: {e}"))?;

    Ok(TagWriteResult {
        success: true,
        error: None,
        temp_path: Some(temp_path.to_string_lossy().to_string()),
    })
}

fn apply_tag_fields(tagged_file: &mut lofty::file::TaggedFile, fields: &TagEditFields) -> Result<(), String> {
    let tag = tagged_file.primary_tag_mut();
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