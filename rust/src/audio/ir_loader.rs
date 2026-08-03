//! Offline impulse-response loader.
//!
//! Decodes an IR file with Symphonia, resamples it to the engine's output rate
//! with rubato (both already dependencies), caps it to `convolver::IR_TAP_CAP`
//! taps, peak-normalises it, and returns per-channel coefficient vectors ready
//! for `Convolver::load_ir`. Runs on the command thread, never the audio
//! callback — decoding and resampling allocate freely here.

use std::path::Path;

use symphonia::core::errors::Error as SymphoniaError;

use crate::audio::convolver::IR_TAP_CAP;
use crate::audio::decoder::{convert_to_interleaved_f32, probe_file};
use crate::audio::resampler::AudioResampler;

const IR_CHUNK: usize = 1024;

/// Decode, resample, cap and normalise an IR file into per-channel taps.
///
/// Returns 1 vector (mono) or 2 vectors (stereo L/R).
pub fn load_ir(path: &Path, target_rate: u32) -> Result<Vec<Vec<f32>>, String> {
    let probe = probe_file(path).map_err(|e| format!("IR probe failed: {}", e))?;
    let src_rate = probe.source_info.original_sample_rate;
    let src_channels = probe.source_info.channels.max(1);

    let mut format = probe.format;
    let mut decoder = probe.decoder;
    let track_id = probe.track_id;

    // 1. Decode to interleaved f32 at the source rate.
    let mut decoded: Vec<f32> = Vec::new();
    let mut buf = Vec::with_capacity(IR_CHUNK * src_channels);
    loop {
        let packet = match format.next_packet() {
            Ok(p) => p,
            Err(SymphoniaError::IoError(ref e))
                if e.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                break;
            }
            Err(SymphoniaError::ResetRequired) => {
                decoder.reset();
                continue;
            }
            Err(e) => return Err(format!("IR decode failed: {}", e)),
        };
        if packet.track_id() != track_id {
            continue;
        }
        let decoded_buf = match decoder.decode(&packet) {
            Ok(d) => d,
            Err(SymphoniaError::DecodeError(_)) => continue,
            Err(e) => return Err(format!("IR decode failed: {}", e)),
        };
        buf.clear();
        convert_to_interleaved_f32(&decoded_buf, &mut buf);
        decoded.extend_from_slice(&buf);
    }

    if decoded.is_empty() {
        return Err("IR file contained no audio samples".to_string());
    }

    // 2. Resample to the engine rate so the convolved spectrum isn't pitch-shifted.
    let resampled: Vec<f32> = if src_rate == target_rate {
        decoded
    } else {
        resample_interleaved(&decoded, src_rate, target_rate, src_channels)?
    };

    // 3. Deinterleave into per-channel vectors (cap at 2: mono or stereo).
    let out_channels = src_channels.min(2).max(1);
    let frames = resampled.len() / src_channels;
    let mut per_channel: Vec<Vec<f32>> = (0..out_channels).map(|_| Vec::with_capacity(frames)).collect();
    for f in 0..frames {
        for ch in 0..out_channels {
            per_channel[ch].push(resampled[f * src_channels + ch]);
        }
    }

    // 4. Cap to IR_TAP_CAP — truncate the tail, keeping the direct/early response.
    for c in &mut per_channel {
        c.truncate(IR_TAP_CAP);
    }

    // 5. Peak-normalise so a hot recording can't clip the convolver output.
    let mut peak = 0.0f32;
    for c in &per_channel {
        for &s in c.iter() {
            let a = s.abs();
            if a > peak {
                peak = a;
            }
        }
    }
    if peak > 0.0 {
        let norm = 1.0 / peak;
        for c in &mut per_channel {
            for s in c.iter_mut() {
                *s *= norm;
            }
        }
    }

    Ok(per_channel)
}

fn resample_interleaved(
    input: &[f32],
    src_rate: u32,
    dst_rate: u32,
    channels: usize,
) -> Result<Vec<f32>, String> {
    let mut resampler = AudioResampler::new(src_rate, dst_rate, channels, IR_CHUNK)?;
    let mut out: Vec<f32> = Vec::with_capacity(
        (input.len() as f64 * dst_rate as f64 / src_rate as f64 * 1.2) as usize + 256,
    );
    let mut tmp = vec![0.0f32; IR_CHUNK * channels * 2 + 256];

    let samples_per_chunk = IR_CHUNK * channels;
    let mut offset = 0;
    while offset < input.len() {
        let take = (input.len() - offset).min(samples_per_chunk);
        let written = resampler.process_interleaved(&input[offset..offset + take], &mut tmp)?;
        out.extend_from_slice(&tmp[..written]);
        offset += take;
    }

    loop {
        let written = resampler.flush(&mut tmp)?;
        if written == 0 {
            break;
        }
        out.extend_from_slice(&tmp[..written]);
    }

    Ok(out)
}
