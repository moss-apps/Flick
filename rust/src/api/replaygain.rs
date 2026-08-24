//! ReplayGain tag read/write bridge.
//!
//! Written by the ReplayGain scanner after EBU R128 analysis (see
//! `audio_analysis.rs` / the Dart scan pass): gains in dB ("-6.53 dB"),
//! peaks as plain linear floats ("0.977125") — the conventions foobar2000
//! and the ReplayGain ecosystem use. lofty maps `ItemKey::ReplayGain*` to
//! ID3v2 TXXX frames, Vorbis comments and MP4 iTunes atoms as appropriate.

use lofty::config::{ParseOptions, WriteOptions};
use lofty::file::AudioFile;
use lofty::prelude::*;
use lofty::probe::Probe;

#[derive(Debug, Clone)]
pub struct ReplayGainTagFields {
    /// Loudness gain for the track (dB).
    pub track_gain_db: Option<f64>,
    /// Track peak (linear).
    pub track_peak: Option<f64>,
    /// Loudness gain for the whole album (dB).
    pub album_gain_db: Option<f64>,
    /// Album peak (linear).
    pub album_peak: Option<f64>,
}

/// Write ReplayGain tags to the file's primary (or first) tag.
/// `None` fields are left untouched so callers can update a subset.
pub fn write_replaygain_tags(
    path: String,
    fields: ReplayGainTagFields,
) -> Result<(), String> {
    let parse_options = ParseOptions::new().read_cover_art(false);
    let mut tagged_file = Probe::open(&path)
        .map_err(|e| format!("Failed to open file: {e}"))?
        .options(parse_options)
        .guess_file_type()
        .map_err(|e| format!("Failed to guess file type: {e}"))?
        .read()
        .map_err(|e| format!("Failed to read file: {e}"))?;

    let tag = tagged_file.primary_tag_mut();
    let tag = match tag {
        Some(t) => Some(t),
        None => tagged_file.first_tag_mut(),
    };

    let tag = tag.ok_or_else(|| "No tag found in file".to_string())?;

    if let Some(v) = fields.track_gain_db {
        tag.insert_text(ItemKey::ReplayGainTrackGain, format!("{v:.2} dB"));
    }
    if let Some(v) = fields.track_peak {
        tag.insert_text(ItemKey::ReplayGainTrackPeak, format!("{v:.5}"));
    }
    if let Some(v) = fields.album_gain_db {
        tag.insert_text(ItemKey::ReplayGainAlbumGain, format!("{v:.2} dB"));
    }
    if let Some(v) = fields.album_peak {
        tag.insert_text(ItemKey::ReplayGainAlbumPeak, format!("{v:.5}"));
    }

    tagged_file
        .save_to_path(&path, WriteOptions::default())
        .map_err(|e| format!("Failed to save tags: {e}"))
}

/// Read ReplayGain tags from a file (None when missing or unreadable).
pub fn read_replaygain_tags(path: String) -> Option<ReplayGainTagFields> {
    let parse_options = ParseOptions::new().read_cover_art(false);
    let tagged_file = Probe::open(&path)
        .ok()?
        .options(parse_options)
        .guess_file_type()
        .ok()?
        .read()
        .ok()?;

    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

    Some(ReplayGainTagFields {
        track_gain_db: tag
            .and_then(|t| t.get_string(&ItemKey::ReplayGainTrackGain))
            .and_then(parse_db),
        track_peak: tag
            .and_then(|t| t.get_string(&ItemKey::ReplayGainTrackPeak))
            .and_then(parse_peak),
        album_gain_db: tag
            .and_then(|t| t.get_string(&ItemKey::ReplayGainAlbumGain))
            .and_then(parse_db),
        album_peak: tag
            .and_then(|t| t.get_string(&ItemKey::ReplayGainAlbumPeak))
            .and_then(parse_peak),
    })
}

fn parse_db(value: &str) -> Option<f64> {
    let trimmed = value.trim();
    let without_unit = trimmed
        .strip_suffix(" dB")
        .or_else(|| trimmed.strip_suffix("dB"))
        .map(str::trim)
        .unwrap_or(trimmed);
    without_unit
        .parse::<f64>()
        .ok()
        .filter(|v| v.is_finite())
}

fn parse_peak(value: &str) -> Option<f64> {
    value
        .trim()
        .parse::<f64>()
        .ok()
        .filter(|v| v.is_finite() && *v >= 0.0)
}
