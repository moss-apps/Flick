//! Background audio decoder using symphonia.
//!
//! Decoding happens in a separate thread to avoid blocking the audio callback.
//! Decoded samples are written to a ring buffer for consumption by the audio thread.

use crate::dev_eprintln;

use crate::audio::http_source::HttpMediaSource;
use crate::audio::opus_decoder;
use crate::audio::resampler::AudioResampler;
use crate::audio::source::{AudioSource, PlaybackRange, SourceInfo, SourceProducer};
use std::collections::HashMap;
use std::fs::File;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};

use symphonia::core::audio::conv::IntoSample;
use symphonia::core::audio::{Audio, GenericAudioBufferRef};
use symphonia::core::codecs::audio::{
    well_known, AudioDecoder, AudioDecoderOptions, CODEC_ID_NULL_AUDIO,
};
use symphonia::core::codecs::CodecParameters;
use symphonia::core::errors::Error as SymphoniaError;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::units::{Time, TimeBase, Timestamp};

/// Default chunk size for decoding (in frames)
const DECODE_CHUNK_SIZE: usize = 4096;

/// Errors that can occur during decoding.
#[derive(Debug)]
pub enum DecoderError {
    IoError(std::io::Error),
    UnsupportedFormat(String),
    NoAudioTrack,
    DecodingFailed(String),
    ResamplingFailed(String),
}

impl std::fmt::Display for DecoderError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::IoError(e) => write!(f, "I/O error: {}", e),
            Self::UnsupportedFormat(s) => write!(f, "Unsupported format: {}", s),
            Self::NoAudioTrack => write!(f, "No audio track found"),
            Self::DecodingFailed(s) => write!(f, "Decoding failed: {}", s),
            Self::ResamplingFailed(s) => write!(f, "Resampling failed: {}", s),
        }
    }
}

impl std::error::Error for DecoderError {}

impl From<std::io::Error> for DecoderError {
    fn from(e: std::io::Error) -> Self {
        Self::IoError(e)
    }
}

/// Result of probing an audio file.
pub struct ProbeResult {
    pub source_info: SourceInfo,
    pub format: Box<dyn FormatReader>,
    pub decoder: Box<dyn AudioDecoder>,
    pub track_id: u32,
    pub time_base: Option<TimeBase>,
}

fn normalize_ogg_hint(ext: &str) -> &str {
    match ext {
        "ogx" | "oga" | "opus" | "ogg" => "ogg",
        "spx" => "ogg",
        other => other,
    }
}

/// Probe an audio file to get its metadata and prepare for decoding.
pub fn probe_file(path: &Path) -> Result<ProbeResult, DecoderError> {
    let raw_ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
    let lower_ext = raw_ext.to_ascii_lowercase();
    let hint_ext = normalize_ogg_hint(&lower_ext);

    let format_opts = FormatOptions::default();
    let metadata_opts = MetadataOptions::default();

    let mut hint = Hint::new();
    if !hint_ext.is_empty() {
        hint.with_extension(hint_ext);
    }

    let file1 = File::open(path)?;
    let mss1 = MediaSourceStream::new(Box::new(file1), Default::default());

    let probed = match symphonia::default::get_probe().probe(
        &hint,
        mss1,
        format_opts.clone(),
        metadata_opts,
    ) {
        Ok(probed) => probed,
        Err(first_err) => {
            // Content-based fallback: reopen and retry with no extension hint.
            let file2 = File::open(path)?;
            let mss2 = MediaSourceStream::new(Box::new(file2), Default::default());
            let no_hint = Hint::new();
            symphonia::default::get_probe()
                .probe(&no_hint, mss2, format_opts, metadata_opts)
                .map_err(|_| DecoderError::UnsupportedFormat(first_err.to_string()))?
        }
    };

    build_probe_result(probed, path.to_path_buf())
}

/// Probe a remote HTTP audio stream. Hint extension is derived from the URL
/// path (auth-bearing query string is ignored). No content-based fallback —
/// reopening an HTTP stream is wasteful and remote URLs carry reliable
/// extensions.
pub fn probe_http(url: &str, headers: HashMap<String, String>) -> Result<ProbeResult, DecoderError> {
    let hint_ext = url_hint_ext(url);
    let format_opts = FormatOptions::default();
    let metadata_opts = MetadataOptions::default();

    let mut hint = Hint::new();
    if !hint_ext.is_empty() {
        hint.with_extension(&hint_ext);
    }

    let src = HttpMediaSource::new(url.to_string(), headers.clone());
    let mss = MediaSourceStream::new(Box::new(src), Default::default());

    let probed = symphonia::default::get_probe()
        .probe(&hint, mss, format_opts, metadata_opts)
        .map_err(|e| DecoderError::UnsupportedFormat(format!("HTTP probe failed: {}", e)))?;

    let mut result = build_probe_result(probed, PathBuf::from(url_label(url)))?;
    result.source_info.http_origin = Some((url.to_string(), headers));
    Ok(result)
}

/// Build a [`ProbeResult`] from a probed format reader: locate the audio track,
/// construct the decoder, and derive [`SourceInfo`]. Shared by file + HTTP paths.
fn build_probe_result(
    mut format: Box<dyn FormatReader>,
    name_path: PathBuf,
) -> Result<ProbeResult, DecoderError> {
    // Find the first audio track
    let (track_id, codec_params, num_frames, time_base) = {
        let track = format
            .tracks()
            .iter()
            .find(|t| {
                matches!(
                    &t.codec_params,
                    Some(CodecParameters::Audio(p)) if p.codec != CODEC_ID_NULL_AUDIO
                )
            })
            .ok_or(DecoderError::NoAudioTrack)?;
        let params = match &track.codec_params {
            Some(CodecParameters::Audio(p)) => p.clone(),
            _ => return Err(DecoderError::NoAudioTrack),
        };
        (track.id, params, track.num_frames, track.time_base)
    };

    let declared_sample_rate = codec_params.sample_rate.unwrap_or(44100);
    let declared_channels = codec_params
        .channels
        .as_ref()
        .map(|c| c.count())
        .unwrap_or(2);

    let decoder_opts = AudioDecoderOptions::default();
    let is_opus = codec_params.codec == well_known::CODEC_ID_OPUS;
    let mut decoder: Box<dyn AudioDecoder> = if is_opus {
        Box::new(
            opus_decoder::OpusDecoder::try_new(&codec_params, &decoder_opts)
                .map_err(|e| DecoderError::UnsupportedFormat(e.to_string()))?,
        )
    } else {
        symphonia::default::get_codecs()
            .make_audio_decoder(&codec_params, &decoder_opts)
            .map_err(|e| DecoderError::UnsupportedFormat(e.to_string()))?
    };

    // Container headers can lie: M4A stsd entries for ALAC have been seen
    // advertising a 1 Hz sample rate. A bogus rate here propagates straight
    // into the audio engine output config, so trust one decoded packet when
    // the header looks impossible, then rewind to frame zero.
    let header_lies = implausible_layout(declared_sample_rate, declared_channels);
    let (sample_rate, channels) = if header_lies {
        match peek_decoded_layout(&mut format, decoder.as_mut(), track_id) {
            Some((rate, ch)) => {
                dev_eprintln!(
                    "[DECODER] header sr={} ch={} implausible; using decoded sr={} ch={}",
                    declared_sample_rate,
                    declared_channels,
                    rate,
                    ch
                );
                (rate, ch)
            }
            None => {
                dev_eprintln!(
                    "[DECODER] header sr={} ch={} implausible and peek failed; trusting header",
                    declared_sample_rate,
                    declared_channels
                );
                (declared_sample_rate, declared_channels)
            }
        }
    } else {
        (declared_sample_rate, declared_channels)
    };

    // Calculate duration. A lying header also carries a lying time_base
    // (derived from the fake rate), so only use it for plausible headers.
    let duration_secs = if let Some(n_frames) = num_frames {
        if header_lies || time_base.is_none() {
            n_frames as f64 / sample_rate as f64
        } else {
            time_base
                .and_then(|tb| tb.calc_time(Timestamp::new(n_frames as i64)))
                .map(|t| t.as_secs_f64())
                .unwrap_or(0.0)
        }
    } else {
        0.0
    };

    // Total samples at the source rate. The playback engine rewrites this when
    // it selects an output rate for the active stream.
    let total_samples = (duration_secs * sample_rate as f64 * channels as f64) as u64;

    dev_eprintln!(
        "[DECODER] codec={} sr={} ch={} dur={:.1}s -> {}",
        codec_params.codec,
        sample_rate,
        channels,
        duration_secs,
        if is_opus { "OpusDecoder (custom)" } else { "symphonia default" },
    );

    let source_info = SourceInfo {
        path: name_path,
        range: PlaybackRange::default(),
        original_sample_rate: sample_rate,
        output_sample_rate: sample_rate,
        channels,
        total_samples,
        duration_secs,
        http_origin: None,
    };

    Ok(ProbeResult {
        source_info,
        format,
        decoder,
        track_id,
        time_base: if header_lies { None } else { time_base },
    })
}

/// Rates outside this window cannot be real audio — they are lying container
/// headers (e.g. 1 Hz ALAC stsd) and must never reach an output stream config.
/// The ceiling clears DSD-over-PCM byte rates (DSD1024 ≈ 2.82 MHz) and 1536k
/// USB links while still rejecting nonsense.
pub(crate) const MIN_PLAUSIBLE_SAMPLE_RATE: u32 = 8_000;
pub(crate) const MAX_PLAUSIBLE_SAMPLE_RATE: u32 = 3_528_000;

/// True when the declared layout is impossible for real audio.
fn implausible_layout(sample_rate: u32, channels: usize) -> bool {
    !plausible_sample_rate(sample_rate) || !(1..=8).contains(&channels)
}

/// Guard against bogus track/header rates (lying container metadata) ever
/// being used as an output stream rate.
pub(crate) fn plausible_sample_rate(rate: u32) -> bool {
    (MIN_PLAUSIBLE_SAMPLE_RATE..=MAX_PLAUSIBLE_SAMPLE_RATE).contains(&rate)
}

/// Decode one packet to read the true rate/channel count, then rewind the
/// format reader to the start so playback still decodes from frame zero.
/// Returns `None` (with a best-effort rewind) when the peek cannot be trusted.
fn peek_decoded_layout(
    format: &mut Box<dyn FormatReader>,
    decoder: &mut dyn AudioDecoder,
    track_id: u32,
) -> Option<(u32, usize)> {
    let peeked = (|| -> Option<(u32, usize)> {
        let packet = format.next_packet().ok()??;
        if packet.track_id != track_id {
            return None;
        }
        let decoded = decoder.decode(&packet).ok()?;
        let spec = decoded.spec();
        if spec.rate() == 0 || spec.channels().count() == 0 {
            return None;
        }
        Some((spec.rate(), spec.channels().count()))
    })();

    decoder.reset();
    if format
        .seek(
            SeekMode::Accurate,
            SeekTo::Time {
                time: Time::ZERO,
                track_id: Some(track_id),
            },
        )
        .is_err()
    {
        dev_eprintln!("[DECODER] rewind after layout peek failed; first packet may be skipped");
    }
    decoder.reset();

    peeked
}

/// Lowercased, ogg-normalized extension hint derived from an HTTP URL's path
/// (query string stripped, so auth params never leak into the hint).
fn url_hint_ext(url: &str) -> String {
    let no_query = url.split('?').next().unwrap_or(url);
    let after_slash = no_query.rsplit('/').next().unwrap_or(no_query);
    let raw_ext = match after_slash.rfind('.') {
        Some(i) => after_slash[i + 1..].to_ascii_lowercase(),
        None => String::new(),
    };
    normalize_ogg_hint(&raw_ext).to_string()
}

/// Path-only label for an HTTP URL (query stripped) — used as a synthetic
/// SourceInfo.path for decoder thread naming. Avoids leaking auth tokens.
fn url_label(url: &str) -> String {
    let no_query = url.split('?').next().unwrap_or(url);
    match no_query.rfind('/') {
        Some(i) => {
            let name = &no_query[i + 1..];
            if name.is_empty() {
                "http-stream".to_string()
            } else {
                name.to_string()
            }
        }
        None => no_query.to_string(),
    }
}

/// Decoder thread handle.
pub struct DecoderThread {
    handle: Option<JoinHandle<Result<(), DecoderError>>>,
    stop_signal: Arc<AtomicBool>,
}

impl DecoderThread {
    /// Spawn a new decoder thread for the given file.
    ///
    /// Returns the audio source (for the audio thread) and the decoder thread handle.
    pub fn spawn(
        path: PathBuf,
        output_sample_rate: u32,
        output_channels: usize,
    ) -> Result<(AudioSource, Self), DecoderError> {
        Self::spawn_with_seek(
            path,
            output_sample_rate,
            output_channels,
            None,
            PlaybackRange::default(),
        )
    }

    /// Spawn a new decoder thread and start decoding from a specific position.
    ///
    /// `start_position_secs` is relative to the range and clamped to its duration.
    pub fn spawn_with_seek(
        path: PathBuf,
        output_sample_rate: u32,
        output_channels: usize,
        start_position_secs: Option<f64>,
        range: PlaybackRange,
    ) -> Result<(AudioSource, Self), DecoderError> {
        let probe_result = probe_file(&path)?;
        Self::spawn_from_probe_result(
            probe_result,
            output_sample_rate,
            output_channels,
            start_position_secs,
            range,
        )
    }

    /// Spawn a decoder thread for a remote HTTP audio stream. PCM only —
    /// remote DSD/WavPack is not supported over HTTP.
    pub fn spawn_from_http(
        url: String,
        headers: HashMap<String, String>,
        output_sample_rate: u32,
        output_channels: usize,
    ) -> Result<(AudioSource, Self), DecoderError> {
        let probe_result = probe_http(&url, headers)?;
        Self::spawn_from_probe_result(
            probe_result,
            output_sample_rate,
            output_channels,
            None,
            PlaybackRange::default(),
        )
    }

    /// Spawn a decoder thread using a probe result that has already been created.
    pub fn spawn_from_probe_result(
        probe_result: ProbeResult,
        output_sample_rate: u32,
        output_channels: usize,
        start_position_secs: Option<f64>,
        range: PlaybackRange,
    ) -> Result<(AudioSource, Self), DecoderError> {
        let range = range.validate().map_err(DecoderError::DecodingFailed)?;
        let path = probe_result.source_info.path.clone();
        let mut source_info = probe_result.source_info.clone();
        let source_rate = source_info.original_sample_rate;
        let start_frame = seconds_to_frame(range.start_secs, source_rate);
        let end_frame = range.end_secs.map(|end| seconds_to_frame(end, source_rate));
        let file_end = (source_info.duration_secs > 0.0)
            .then(|| seconds_to_frame(source_info.duration_secs, source_rate));
        let duration_end = match (end_frame, file_end) {
            (Some(end), Some(eof)) => Some(end.min(eof)),
            (end, eof) => end.or(eof),
        };
        let duration_frames = duration_end.map(|end| end.saturating_sub(start_frame));
        source_info.range = range;
        source_info.duration_secs = duration_frames
            .map(|frames| frames as f64 / source_rate as f64)
            .unwrap_or(0.0);
        source_info.output_sample_rate = output_sample_rate;
        source_info.channels = output_channels;
        source_info.total_samples = (source_info.duration_secs * output_sample_rate as f64).round()
            as u64
            * output_channels as u64;

        let mut position_secs = start_position_secs.unwrap_or(0.0).max(0.0);
        if duration_frames.is_some() {
            position_secs = position_secs.min(source_info.duration_secs);
        }
        let decode_start = start_frame.saturating_add(seconds_to_frame(position_secs, source_rate));
        // An open-ended track must really run to EOF, not truncate playback to
        // a container's duration estimate. A seek to the known end is empty.
        let decode_end = if duration_frames.is_some() && position_secs >= source_info.duration_secs
        {
            duration_end
        } else {
            end_frame
        };

        // Create the source and producer
        let (source, producer) = AudioSource::new(source_info);
        source.set_position_secs(position_secs);
        let stop_signal = Arc::new(AtomicBool::new(false));
        let stop_signal_clone = Arc::clone(&stop_signal);

        // Spawn the decoder thread
        let handle = thread::Builder::new()
            .name(format!("decoder-{}", path.display()))
            .spawn(move || {
                decode_thread(
                    probe_result,
                    producer,
                    output_sample_rate,
                    output_channels,
                    stop_signal_clone,
                    decode_start,
                    decode_end,
                )
            })
            .map_err(|e| DecoderError::IoError(e.into()))?;

        Ok((
            source,
            Self {
                handle: Some(handle),
                stop_signal,
            },
        ))
    }

    /// Signal the decoder to stop.
    pub fn stop(&self) {
        self.stop_signal.store(true, Ordering::Release);
    }

    /// Wait for the decoder thread to finish.
    pub fn join(mut self) -> Result<(), DecoderError> {
        if let Some(handle) = self.handle.take() {
            handle
                .join()
                .map_err(|_| DecoderError::DecodingFailed("Thread panicked".to_string()))?
        } else {
            Ok(())
        }
    }

    /// Check if the decoder is still running.
    pub fn is_running(&self) -> bool {
        self.handle
            .as_ref()
            .map(|h| !h.is_finished())
            .unwrap_or(false)
    }
}

impl Drop for DecoderThread {
    fn drop(&mut self) {
        self.stop();
    }
}

fn seconds_to_frame(seconds: f64, sample_rate: u32) -> u64 {
    (seconds * sample_rate as f64).round() as u64
}

fn timestamp_to_frame(ts: Timestamp, time_base: Option<TimeBase>, sample_rate: u32) -> u64 {
    let ticks = ts.get().max(0) as u128;
    match time_base {
        Some(tb) => {
            (ticks * tb.numer.get() as u128 * sample_rate as u128 / tb.denom.get() as u128) as u64
        }
        None => ticks as u64,
    }
}

/// The main decoder loop running in a background thread.
fn decode_thread(
    probe_result: ProbeResult,
    mut producer: SourceProducer,
    output_sample_rate: u32,
    output_channels: usize,
    stop_signal: Arc<AtomicBool>,
    start_frame: u64,
    end_frame: Option<u64>,
) -> Result<(), DecoderError> {
    let ProbeResult {
        source_info,
        mut format,
        mut decoder,
        track_id,
        time_base,
    } = probe_result;

    if end_frame.is_some_and(|end| start_frame >= end) {
        producer.finish();
        return Ok(());
    }
    let mut current_frame = 0;
    if start_frame > 0 {
        let target_secs = start_frame as f64 / source_info.original_sample_rate as f64;
        let seek_to = SeekTo::Time {
            time: Time::try_from_secs_f64(target_secs).unwrap_or(Time::ZERO),
            track_id: Some(track_id),
        };

        let seeked = format
            .seek(SeekMode::Accurate, seek_to)
            .map_err(|e| DecoderError::DecodingFailed(format!("Seek failed: {}", e)))?;
        current_frame = timestamp_to_frame(
            seeked.actual_ts,
            time_base,
            source_info.original_sample_rate,
        );
        decoder.reset();
    }

    let source_channels = source_info.channels;

    // Create resampler if needed
    let needs_resampling = source_info.original_sample_rate != output_sample_rate;
    let needs_channel_remix = source_channels != output_channels;
    let mut resampler = if needs_resampling {
        Some(
            AudioResampler::new(
                source_info.original_sample_rate,
                output_sample_rate,
                output_channels,
                DECODE_CHUNK_SIZE,
            )
            .map_err(DecoderError::ResamplingFailed)?,
        )
    } else {
        None
    };

    log::info!(
        "[DECODER] decoded_file_sample_rate_hz={} decoder_output_sample_rate_hz={} source_channels={} output_channels={} resampling_active={} channel_remix_active={}",
        source_info.original_sample_rate,
        output_sample_rate,
        source_channels,
        output_channels,
        needs_resampling,
        needs_channel_remix,
    );
    if needs_resampling {
        log::warn!(
            "[DECODER] Resampling {}→{} Hz. For USB bit-perfect playback, engine + DAC should match the file rate (resampling=false).",
            source_info.original_sample_rate,
            output_sample_rate
        );
    }

    // Pre-allocated buffers (avoid allocations in the loop)
    let mut decode_buffer: Vec<f32> = Vec::with_capacity(DECODE_CHUNK_SIZE * source_channels * 2);
    let mut remix_buffer: Vec<f32> = Vec::with_capacity(DECODE_CHUNK_SIZE * output_channels * 2);
    let mut resample_buffer: Vec<f32> = Vec::with_capacity(
        (DECODE_CHUNK_SIZE as f64 * output_sample_rate as f64
            / source_info.original_sample_rate as f64
            * 1.2) as usize
            * output_channels
            + 256,
    );

    let mut logged_meaningful_f32_peak = false;

    // Decode loop
    loop {
        // Check stop signal
        if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
            break;
        }

        // Get the next packet
        let packet = match format.next_packet() {
            Ok(Some(packet)) => packet,
            Ok(None) => {
                // End of stream
                break;
            }
            Err(SymphoniaError::IoError(ref e))
                if e.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                // End of stream
                break;
            }
            Err(SymphoniaError::ResetRequired) => {
                // Reset decoder for gapless playback
                decoder.reset();
                continue;
            }
            Err(e) => {
                return Err(DecoderError::DecodingFailed(e.to_string()));
            }
        };

        // Skip packets from other tracks
        if packet.track_id != track_id {
            continue;
        }

        // Decode the packet
        let decoded = match decoder.decode(&packet) {
            Ok(decoded) => decoded,
            Err(SymphoniaError::DecodeError(e)) => {
                // Skip corrupted frames
                dev_eprintln!("Decode error (skipping frame): {}", e);
                continue;
            }
            Err(e) => {
                return Err(DecoderError::DecodingFailed(e.to_string()));
            }
        };

        // Convert to interleaved f32
        decode_buffer.clear();
        convert_to_interleaved_f32(&decoded, &mut decode_buffer);

        // Seek lands on a packet boundary. Discard preroll and stop at the
        // exclusive track end BEFORE publishing any samples or resampling.
        let frames = (decode_buffer.len() / source_channels) as u64;
        let packet_start = current_frame;
        current_frame = current_frame.saturating_add(frames);
        let first = start_frame.saturating_sub(packet_start).min(frames);
        let last = end_frame
            .map(|end| end.saturating_sub(packet_start).min(frames))
            .unwrap_or(frames);
        if last <= first {
            if end_frame.is_some_and(|end| current_frame >= end) {
                break;
            }
            continue;
        }
        let selected_samples =
            &decode_buffer[first as usize * source_channels..last as usize * source_channels];

        if !logged_meaningful_f32_peak {
            let mut peak = 0.0f32;
            for &s in decode_buffer.iter() {
                let a = s.abs();
                if a > peak {
                    peak = a;
                }
            }
            if peak >= 0.1 {
                log::info!(
                    "[DECODER] first chunk with |f32| max >= 0.1: peak={:.6} (S32→f32 via Symphonia: i32 as f64 / 2^31; quiet intros log lower)",
                    peak
                );
                logged_meaningful_f32_peak = true;
            }
        }

        let remixed_samples = if needs_channel_remix {
            remix_buffer.clear();
            remix_buffer.resize(
                (selected_samples.len() / source_channels.max(1)) * output_channels,
                0.0,
            );
            remix_interleaved_channels(
                selected_samples,
                source_channels,
                output_channels,
                &mut remix_buffer,
            );
            &remix_buffer[..]
        } else {
            selected_samples
        };

        // Resample if needed
        let output_samples = if let Some(ref mut resampler) = resampler {
            resample_buffer.clear();
            resample_buffer.resize(
                (remixed_samples.len() as f64 * output_sample_rate as f64
                    / source_info.original_sample_rate as f64
                    * 1.2) as usize
                    + 256,
                0.0,
            );

            let written = resampler
                .process_interleaved(remixed_samples, &mut resample_buffer)
                .map_err(DecoderError::ResamplingFailed)?;

            &resample_buffer[..written]
        } else {
            remixed_samples
        };

        // Write to ring buffer, waiting if necessary
        let mut offset = 0;
        while offset < output_samples.len() {
            if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
                break;
            }

            let chunk = &output_samples[offset..];
            let written = producer.write(chunk);
            offset += written;

            if written == 0 {
                producer.wait_for_space(chunk.len().min(1024), 100);
            }
        }
        if end_frame.is_some_and(|end| current_frame >= end) {
            break;
        }
    }

    // Flush any remaining resampler output
    if let Some(ref mut resampler) = resampler {
        resample_buffer.clear();
        resample_buffer.resize(
            (DECODE_CHUNK_SIZE as f64 * output_sample_rate as f64
                / source_info.original_sample_rate as f64
                * 1.2) as usize
                * output_channels
                + 256,
            0.0,
        );
        loop {
            let written = resampler
                .flush(&mut resample_buffer)
                .map_err(DecoderError::ResamplingFailed)?;
            if written == 0 {
                break;
            }
            let mut offset = 0;
            while offset < written {
                if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
                    break;
                }
                let chunk = &resample_buffer[offset..written];
                let w = producer.write(chunk);
                offset += w;
                if w == 0 {
                    producer.wait_for_space(chunk.len().min(1024), 100);
                }
            }
        }
    }

    // Mark decoding as complete
    producer.finish();

    Ok(())
}

pub(crate) fn remix_interleaved_channels(
    input: &[f32],
    source_channels: usize,
    output_channels: usize,
    output: &mut [f32],
) {
    if source_channels == 0 || output_channels == 0 {
        return;
    }

    let frames = input.len() / source_channels;
    for frame in 0..frames {
        let input_start = frame * source_channels;
        let output_start = frame * output_channels;
        let source_frame = &input[input_start..input_start + source_channels];
        let output_frame = &mut output[output_start..output_start + output_channels];

        match (source_channels, output_channels) {
            (1, 2) => {
                output_frame[0] = source_frame[0];
                output_frame[1] = source_frame[0];
            }
            (_, 1) => {
                let sum: f32 = source_frame.iter().copied().sum();
                output_frame[0] = sum / source_channels as f32;
            }
            (2, 2) => {
                output_frame.copy_from_slice(source_frame);
            }
            _ => {
                for ch in 0..output_channels {
                    output_frame[ch] = if ch < source_channels {
                        source_frame[ch]
                    } else {
                        source_frame[source_channels - 1]
                    };
                }
            }
        }
    }
}

/// Convert an AudioBufferRef to interleaved f32 samples.
pub(crate) fn convert_to_interleaved_f32(buffer: &GenericAudioBufferRef, output: &mut Vec<f32>) {
    use std::sync::atomic::{AtomicBool, Ordering as AtomicOrdering};
    static LOGGED_VARIANT: AtomicBool = AtomicBool::new(false);
    if !LOGGED_VARIANT.swap(true, AtomicOrdering::Relaxed) {
        let variant = match buffer {
            GenericAudioBufferRef::F32(_) => "F32",
            GenericAudioBufferRef::S16(_) => "S16",
            GenericAudioBufferRef::S24(_) => "S24",
            GenericAudioBufferRef::S32(_) => "S32",
            GenericAudioBufferRef::U8(_) => "U8",
            _ => "Unknown",
        };
        log::info!("[DECODER] AudioBufferRef variant: {}", variant);
    }
    match buffer {
        GenericAudioBufferRef::F32(buf) => {
            let channels = buf.spec().channels().count();
            let frames = buf.frames();
            output.reserve(frames * channels);

            for frame in 0..frames {
                for ch in 0..channels {
                    output.push(buf.plane(ch).expect("audio plane")[frame]);
                }
            }
        }
        GenericAudioBufferRef::S16(buf) => {
            let channels = buf.spec().channels().count();
            let frames = buf.frames();
            output.reserve(frames * channels);

            for frame in 0..frames {
                for ch in 0..channels {
                    // Convert i16 to f32 (-1.0 to 1.0)
                    output.push(buf.plane(ch).expect("audio plane")[frame] as f32 / 32768.0);
                }
            }
        }
        GenericAudioBufferRef::S24(buf) => {
            let channels = buf.spec().channels().count();
            let frames = buf.frames();
            output.reserve(frames * channels);

            for frame in 0..frames {
                for ch in 0..channels {
                    // Convert i24 to f32
                    let sample = buf.plane(ch).expect("audio plane")[frame].inner();
                    output.push(sample as f32 / 8388608.0);
                }
            }
        }
        GenericAudioBufferRef::S32(buf) => {
            let channels = buf.spec().channels().count();
            let frames = buf.frames();
            output.reserve(frames * channels);

            for frame in 0..frames {
                for ch in 0..channels {
                    // Must match symphonia_core::audio::conv: (i32 as f64 / 2^31) as f32 — casting
                    // i32 to f32 before dividing quantizes large PCM values and causes audible
                    // distortion.
                    output.push(buf.plane(ch).expect("audio plane")[frame].into_sample());
                }
            }
        }
        GenericAudioBufferRef::U8(buf) => {
            let channels = buf.spec().channels().count();
            let frames = buf.frames();
            output.reserve(frames * channels);

            for frame in 0..frames {
                for ch in 0..channels {
                    // Convert u8 to f32 (-1.0 to 1.0)
                    output.push((buf.plane(ch).expect("audio plane")[frame] as f32 - 128.0) / 128.0);
                }
            }
        }
        _ => {
            // Unsupported format - output silence
            dev_eprintln!("Unsupported audio buffer format");
        }
    }
}

/// Seek context for handling seek requests.
pub struct SeekContext {
    pub format: Box<dyn FormatReader>,
    pub decoder: Box<dyn AudioDecoder>,
    pub track_id: u32,
}

impl SeekContext {
    /// Seek to a position in seconds.
    pub fn seek(&mut self, position_secs: f64) -> Result<(), DecoderError> {
        let seek_to = SeekTo::Time {
            time: Time::try_from_secs_f64(position_secs).unwrap_or(Time::ZERO),
            track_id: Some(self.track_id),
        };

        self.format
            .seek(SeekMode::Coarse, seek_to)
            .map_err(|e| DecoderError::DecodingFailed(format!("Seek failed: {}", e)))?;

        // Reset decoder after seek
        self.decoder.reset();

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::AtomicUsize;

    static FIXTURE_ID: AtomicUsize = AtomicUsize::new(0);

    struct TestFile(PathBuf);

    impl TestFile {
        fn new(extension: &str) -> Self {
            Self(std::env::temp_dir().join(format!(
                "flick_cue_decoder_{}_{}.{}",
                std::process::id(),
                FIXTURE_ID.fetch_add(1, Ordering::Relaxed),
                extension,
            )))
        }
    }

    impl Drop for TestFile {
        fn drop(&mut self) {
            let _ = std::fs::remove_file(&self.0);
        }
    }

    fn wav_fixture(rate: u32, bits: u16) -> (TestFile, Vec<f32>) {
        let file = TestFile::new("wav");
        let mut writer = hound::WavWriter::create(
            &file.0,
            hound::WavSpec {
                channels: 2,
                sample_rate: rate,
                bits_per_sample: bits,
                sample_format: hound::SampleFormat::Int,
            },
        )
        .unwrap();
        let mut expected = Vec::new();
        for frame in 0..4096 {
            let value = if bits == 16 {
                frame * 17 % 60_000 - 30_000
            } else {
                frame * 1739 % 16_000_000 - 8_000_000
            };
            for sample in [value, -value - 1] {
                writer.write_sample(sample).unwrap();
                expected.push((sample as f64 / (1u64 << (bits - 1)) as f64) as f32);
            }
        }
        writer.finalize().unwrap();
        (file, expected)
    }

    fn flac_fixture() -> (TestFile, Vec<f32>) {
        // Synthetic 24-bit stereo ramp, 4096 frames at 44.1 kHz, encoded by
        // libFLAC 1.5.0 with 1024-frame blocks. No external encoder needed in CI.
        let hex: String = include_str!("../../test_fixtures/cue_ramp_24bit.flac.hex")
            .split_whitespace()
            .collect();
        let bytes: Vec<u8> = (0..hex.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
            .collect();
        let file = TestFile::new("flac");
        std::fs::write(&file.0, bytes).unwrap();
        let expected = (0..4096)
            .flat_map(|frame| {
                let value = frame * 17 % 100_000 - 50_000;
                [
                    value as f32 / 8_388_608.0,
                    (-value - 1) as f32 / 8_388_608.0,
                ]
            })
            .collect();
        (file, expected)
    }

    fn decode_range(
        path: &Path,
        rate: u32,
        range: PlaybackRange,
        seek: Option<f64>,
    ) -> (SourceInfo, f64, Vec<f32>) {
        let (mut source, decoder) =
            DecoderThread::spawn_with_seek(path.to_path_buf(), rate, 2, seek, range).unwrap();
        // Fixtures are smaller than the ring buffer, so joining cannot block.
        decoder.join().unwrap();
        let initial_position = source.position_secs();
        let mut samples = Vec::new();
        let mut buffer = [0.0; 512];
        while !source.is_finished() {
            let count = source.read(&mut buffer);
            assert!(
                count > 0,
                "finished decoder must not leave an empty live source"
            );
            samples.extend_from_slice(&buffer[..count]);
        }
        (source.info, initial_position, samples)
    }

    fn check_segments(file: &TestFile, expected: &[f32], rate: u32) {
        let mut combined = Vec::new();
        for (start, end) in [(0.0, Some(0.013)), (0.013, Some(0.031)), (0.031, None)] {
            let range = PlaybackRange {
                start_secs: start,
                end_secs: end,
            };
            let (info, position, samples) = decode_range(&file.0, rate, range, None);
            let first = seconds_to_frame(start, rate) as usize;
            let last = end
                .map(|end| seconds_to_frame(end, rate) as usize)
                .unwrap_or(expected.len() / 2);
            assert_eq!(
                samples,
                expected[first * 2..last * 2],
                "range {range:?} at {rate} Hz"
            );
            assert_eq!(position, 0.0);
            assert_eq!(info.range, range);
            assert_eq!(info.original_sample_rate, rate);
            assert_eq!(info.output_sample_rate, rate);
            assert_eq!(info.total_samples, samples.len() as u64);
            assert!((info.duration_secs - (last - first) as f64 / rate as f64).abs() < 1e-9);
            combined.extend(samples);
        }
        assert_eq!(
            combined, expected,
            "adjacent tracks must not duplicate or drop samples"
        );
    }

    #[test]
    fn cue_ranges_preserve_native_pcm_samples_and_cover_the_album() {
        for rate in [44_100, 96_000] {
            for bits in [16, 24] {
                let (file, expected) = wav_fixture(rate, bits);
                check_segments(&file, &expected, rate);
                let (_, _, full) = decode_range(&file.0, rate, PlaybackRange::default(), None);
                assert_eq!(full, expected, "ordinary files must remain unchanged");
            }
        }
    }

    #[test]
    fn cue_flac_ranges_trim_partial_packets_without_changing_24bit_samples() {
        let (file, expected) = flac_fixture();
        check_segments(&file, &expected, 44_100);
    }

    #[test]
    fn cue_seek_is_track_relative_and_cannot_run_past_its_end() {
        let (file, expected) = flac_fixture();
        let rate = 44_100;
        let range = PlaybackRange {
            start_secs: 0.013,
            end_secs: Some(0.061),
        };
        let seek = 0.007;
        let (info, position, samples) = decode_range(&file.0, rate, range, Some(seek));
        let first = seconds_to_frame(range.start_secs, rate) + seconds_to_frame(seek, rate);
        let last = seconds_to_frame(range.end_secs.unwrap(), rate);
        assert_eq!(samples, expected[first as usize * 2..last as usize * 2]);
        assert!((position - seek).abs() <= 1.0 / rate as f64);
        let (_, position, samples) = decode_range(&file.0, rate, range, Some(999.0));
        assert!(samples.is_empty());
        assert!((position - info.duration_secs).abs() < 1e-9);
    }

    #[test]
    fn cue_explicit_end_works_without_container_duration() {
        let (file, expected) = flac_fixture();
        let mut probe = probe_file(&file.0).unwrap();
        probe.source_info.duration_secs = 0.0;
        probe.source_info.total_samples = 0;
        let range = PlaybackRange {
            start_secs: 0.013,
            end_secs: Some(0.031),
        };
        let (mut source, decoder) =
            DecoderThread::spawn_from_probe_result(probe, 44_100, 2, None, range).unwrap();
        decoder.join().unwrap();
        let mut samples = vec![0.0; source.info.total_samples as usize];
        assert_eq!(source.read(&mut samples), samples.len());
        assert!(source.is_finished());
        assert_eq!(samples, expected[573 * 2..1367 * 2]);
    }

    #[test]
    fn invalid_cue_ranges_fail_before_starting_playback() {
        let (file, _) = wav_fixture(44_100, 16);
        for range in [
            PlaybackRange {
                start_secs: -1.0,
                end_secs: None,
            },
            PlaybackRange {
                start_secs: f64::NAN,
                end_secs: None,
            },
            PlaybackRange {
                start_secs: 1.0,
                end_secs: Some(1.0),
            },
            PlaybackRange {
                start_secs: 2.0,
                end_secs: Some(1.0),
            },
            PlaybackRange {
                start_secs: 0.0,
                end_secs: Some(f64::INFINITY),
            },
        ] {
            assert!(
                DecoderThread::spawn_with_seek(file.0.clone(), 44_100, 2, None, range).is_err()
            );
        }
    }

    #[test]
    fn bogus_container_rates_are_rejected() {
        // The Galaxy A52s ALAC-in-M4A case: stsd cookie declares 1 Hz.
        assert!(implausible_layout(1, 2));
        assert!(implausible_layout(0, 2));
        assert!(implausible_layout(7_999, 2));
        assert!(implausible_layout(3_528_001, 2));
        assert!(implausible_layout(44_100, 0));
        assert!(implausible_layout(44_100, 9));
    }

    #[test]
    fn real_layouts_pass_through() {
        for rate in [8_000u32, 44_100, 48_000, 96_000, 192_000, 768_000] {
            assert!(!implausible_layout(rate, 2), "rate {rate}");
            assert!(plausible_sample_rate(rate));
        }
        // DSD-over-PCM byte rates stay plausible.
        assert!(plausible_sample_rate(2_822_400));
    }
}
