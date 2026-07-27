//! ALAC/M4A/AIFF to WAV/PCM real-time converter
//!
//! This module provides lossless conversion of ALAC, M4A, and AIFF files to WAV/PCM format
//! while preserving the original bit depth (16/24/32-bit).
//!
//! # Architecture
//!
//! - Uses Symphonia for pure-Rust ALAC decoding (no system dependencies)
//! - Preserves bit depth without re-quantization
//! - Supports streaming conversion for memory efficiency
//! - Thread-safe session management

use anyhow::{Context, Result};
use std::io::Cursor;
use symphonia::core::audio::{AudioBufferRef, Signal};
use symphonia::core::codecs::{Decoder, DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::default::get_probe;

/// Audio format metadata
#[derive(Debug, Clone)]
pub struct AudioMetadata {
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_depth: u16,
    pub duration_samples: u64,
    pub duration_seconds: f64,
    /// true → WAV format code 3 (IEEE float); false → 1 (PCM int)
    pub is_float: bool,
}

/// Conversion session for streaming decode
pub struct ConversionSession {
    format_reader: Box<dyn FormatReader>,
    decoder: Box<dyn Decoder>,
    track_id: u32,
    metadata: AudioMetadata,
}

impl ConversionSession {
    /// Create a new conversion session from file bytes
    pub fn new(file_bytes: Vec<u8>) -> Result<Self> {
        let mut format_reader = probe_format_reader(&file_bytes)?;

        // Find the first audio track
        let track = format_reader
            .tracks()
            .iter()
            .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
            .context("No audio track found")?;

        let track_id = track.id;
        let codec_params = &track.codec_params;

        // codec_params often lies for ALAC/AAC-in-M4A: channels may be None, and
        // bits_per_sample rarely matches the decoder's actual buffer type (e.g.
        // 24-bit ALAC → S32, AAC → F32). Peek one packet for the real layout.
        let sample_rate_hint = codec_params.sample_rate.context("No sample rate")?;
        let duration_samples = codec_params.n_frames.unwrap_or(0);

        let mut decoder = symphonia::default::get_codecs()
            .make(codec_params, &DecoderOptions::default())
            .context("Failed to create decoder")?;

        // ponytail: always peek first packet for rate/channels/bit_depth/is_float, then rewind.
        let packet = format_reader
            .next_packet()
            .context("No first packet for format peek")?;
        let decoded = decoder
            .decode(&packet)
            .context("Failed to decode peek packet")?;
        let sample_rate = if decoded.spec().rate > 0 {
            decoded.spec().rate
        } else {
            sample_rate_hint
        };
        let channels = decoded.spec().channels.count() as u16;
        let (bit_depth, is_float) = sample_format_from_buffer(&decoded);
        decoder.reset();
        format_reader
            .seek(
                SeekMode::Accurate,
                SeekTo::Time {
                    time: symphonia::core::units::Time::new(0, 0.0),
                    track_id: Some(track_id),
                },
            )
            .context("Rewind after format peek failed")?;
        decoder.reset();

        let duration_seconds = if sample_rate > 0 {
            duration_samples as f64 / sample_rate as f64
        } else {
            0.0
        };

        let metadata = AudioMetadata {
            sample_rate,
            channels,
            bit_depth,
            duration_samples,
            duration_seconds,
            is_float,
        };

        Ok(Self {
            format_reader,
            decoder,
            track_id,
            metadata,
        })
    }

    /// Get audio metadata
    pub fn metadata(&self) -> &AudioMetadata {
        &self.metadata
    }

    /// Generate WAV header for the audio stream
    pub fn wav_header(&self) -> Vec<u8> {
        generate_wav_header(&self.metadata)
    }

    /// Decode the next chunk of PCM data
    ///
    /// Returns None when end of stream is reached
    pub fn decode_next_chunk(&mut self) -> Result<Option<Vec<u8>>> {
        // Get the next packet
        let packet = match self.format_reader.next_packet() {
            Ok(packet) => packet,
            Err(symphonia::core::errors::Error::IoError(e))
                if e.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                return Ok(None);
            }
            Err(e) => return Err(anyhow::anyhow!("Failed to read packet: {}", e)),
        };

        // Only decode packets for our track
        if packet.track_id() != self.track_id {
            return self.decode_next_chunk();
        }

        // Decode the packet
        let decoded = self
            .decoder
            .decode(&packet)
            .context("Failed to decode packet")?;

        // Convert to interleaved PCM bytes
        let pcm_bytes = audio_buffer_to_pcm_bytes(decoded, self.metadata.bit_depth)?;

        Ok(Some(pcm_bytes))
    }

    /// Seek to a specific time position
    pub fn seek(&mut self, time_seconds: f64) -> Result<()> {
        let sr = self.metadata.sample_rate as u64;
        let sample_pos = (time_seconds * sr as f64) as u64;
        let secs = sample_pos / sr;
        let frac = (sample_pos % sr) as f64 / sr as f64;
        let seek_to = SeekTo::Time {
            time: symphonia::core::units::Time::new(secs, frac),
            track_id: Some(self.track_id),
        };

        self.format_reader
            .seek(SeekMode::Accurate, seek_to)
            .context("Seek failed")?;

        self.decoder.reset();
        Ok(())
    }

    /// Convert entire file to WAV in memory
    pub fn convert_to_wav(&mut self) -> Result<Vec<u8>> {
        let mut wav_data = self.wav_header();

        while let Some(chunk) = self.decode_next_chunk()? {
            wav_data.extend_from_slice(&chunk);
        }

        // Update WAV header with actual data size
        update_wav_header_sizes(&mut wav_data);

        Ok(wav_data)
    }
}

fn probe_format_reader(file_bytes: &[u8]) -> Result<Box<dyn FormatReader>> {
    let format_opts = FormatOptions::default();
    let metadata_opts = MetadataOptions::default();
    let probe = get_probe();
    let mut last_error: Option<anyhow::Error> = None;

    // Try content-based probing first, then a few known extensions for
    // containers that can benefit from a stronger hint.
    for extension_hint in [None, Some("m4a"), Some("alac"), Some("aiff"), Some("aif")] {
        let cursor = Cursor::new(file_bytes.to_vec());
        let media_source = MediaSourceStream::new(Box::new(cursor), Default::default());
        let mut hint = Hint::new();
        if let Some(extension_hint) = extension_hint {
            hint.with_extension(extension_hint);
        }

        match probe.format(&hint, media_source, &format_opts, &metadata_opts) {
            Ok(probed) => return Ok(probed.format),
            Err(error) => last_error = Some(anyhow::Error::new(error)),
        }
    }

    Err(last_error.unwrap_or_else(|| anyhow::anyhow!("Failed to probe audio format")))
}

/// Bit depth + float flag matching how we pack samples into the WAV body.
fn sample_format_from_buffer(buffer: &AudioBufferRef<'_>) -> (u16, bool) {
    match buffer {
        AudioBufferRef::S8(_) | AudioBufferRef::U8(_) => (8, false),
        AudioBufferRef::S16(_) | AudioBufferRef::U16(_) => (16, false),
        AudioBufferRef::S24(_) | AudioBufferRef::U24(_) => (24, false),
        AudioBufferRef::S32(_) | AudioBufferRef::U32(_) => (32, false),
        AudioBufferRef::F32(_) => (32, true),
        AudioBufferRef::F64(_) => (64, true),
    }
}

/// Convert AudioBufferRef to interleaved PCM bytes preserving bit depth
fn audio_buffer_to_pcm_bytes(buffer: AudioBufferRef, _bit_depth: u16) -> Result<Vec<u8>> {
    match buffer {
        // 8-bit signed integer
        AudioBufferRef::S8(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count());
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.push(sample as u8);
                }
            }
            Ok(output)
        }

        // 16-bit signed integer
        AudioBufferRef::S16(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 2);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.extend_from_slice(&sample.to_le_bytes());
                }
            }
            Ok(output)
        }

        // 24-bit signed integer (stored as i32)
        AudioBufferRef::S24(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 3);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    // i24 is a 3-byte type, convert to i32 for byte extraction
                    let sample_i32 = sample.inner();
                    let bytes = sample_i32.to_le_bytes();
                    // Write only the lower 3 bytes for 24-bit
                    output.extend_from_slice(&bytes[0..3]);
                }
            }
            Ok(output)
        }

        // 32-bit signed integer
        AudioBufferRef::S32(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 4);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.extend_from_slice(&sample.to_le_bytes());
                }
            }
            Ok(output)
        }

        // 32-bit float
        AudioBufferRef::F32(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 4);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.extend_from_slice(&sample.to_le_bytes());
                }
            }
            Ok(output)
        }

        // 64-bit float
        AudioBufferRef::F64(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 8);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.extend_from_slice(&sample.to_le_bytes());
                }
            }
            Ok(output)
        }

        // Unsigned 8-bit
        AudioBufferRef::U8(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count());
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.push(sample);
                }
            }
            Ok(output)
        }

        // Unsigned 16-bit
        AudioBufferRef::U16(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 2);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.extend_from_slice(&sample.to_le_bytes());
                }
            }
            Ok(output)
        }

        // Unsigned 24-bit
        AudioBufferRef::U24(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 3);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    // u24 is a 3-byte type, convert to u32 for byte extraction
                    let sample_u32 = sample.inner();
                    let bytes = sample_u32.to_le_bytes();
                    output.extend_from_slice(&bytes[0..3]);
                }
            }
            Ok(output)
        }

        // Unsigned 32-bit
        AudioBufferRef::U32(buf) => {
            let mut output = Vec::with_capacity(buf.frames() * buf.spec().channels.count() * 4);
            let channels = buf.spec().channels.count();

            for frame_idx in 0..buf.frames() {
                for ch_idx in 0..channels {
                    let sample = buf.chan(ch_idx)[frame_idx];
                    output.extend_from_slice(&sample.to_le_bytes());
                }
            }
            Ok(output)
        }
    }
}

/// Generate WAV file header
fn generate_wav_header(metadata: &AudioMetadata) -> Vec<u8> {
    let mut header = Vec::with_capacity(44);

    let byte_rate =
        metadata.sample_rate * metadata.channels as u32 * (metadata.bit_depth / 8) as u32;
    let block_align = metadata.channels * (metadata.bit_depth / 8);
    let data_size = metadata.duration_samples * block_align as u64;
    // 1 = PCM integer, 3 = IEEE float
    let audio_format: u16 = if metadata.is_float { 3 } else { 1 };

    // RIFF header
    header.extend_from_slice(b"RIFF");
    header.extend_from_slice(&((36 + data_size) as u32).to_le_bytes()); // File size - 8
    header.extend_from_slice(b"WAVE");

    // fmt chunk
    header.extend_from_slice(b"fmt ");
    header.extend_from_slice(&16u32.to_le_bytes()); // fmt chunk size
    header.extend_from_slice(&audio_format.to_le_bytes());
    header.extend_from_slice(&metadata.channels.to_le_bytes());
    header.extend_from_slice(&metadata.sample_rate.to_le_bytes());
    header.extend_from_slice(&byte_rate.to_le_bytes());
    header.extend_from_slice(&block_align.to_le_bytes());
    header.extend_from_slice(&metadata.bit_depth.to_le_bytes());

    // data chunk header
    header.extend_from_slice(b"data");
    header.extend_from_slice(&(data_size as u32).to_le_bytes());

    header
}

/// Update WAV header with actual data size after conversion
fn update_wav_header_sizes(wav_data: &mut [u8]) {
    if wav_data.len() < 44 {
        return;
    }

    let data_size = (wav_data.len() - 44) as u32;
    let file_size = (wav_data.len() - 8) as u32;

    // Update RIFF chunk size (bytes 4-7)
    wav_data[4..8].copy_from_slice(&file_size.to_le_bytes());

    // Update data chunk size (bytes 40-43)
    wav_data[40..44].copy_from_slice(&data_size.to_le_bytes());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wav_header_generation() {
        let metadata = AudioMetadata {
            sample_rate: 44100,
            channels: 2,
            bit_depth: 16,
            duration_samples: 44100,
            duration_seconds: 1.0,
            is_float: false,
        };

        let header = generate_wav_header(&metadata);
        assert_eq!(header.len(), 44);
        assert_eq!(&header[0..4], b"RIFF");
        assert_eq!(&header[8..12], b"WAVE");
        assert_eq!(&header[12..16], b"fmt ");
    }
}
