use crate::audio::decoder_handle::DecoderHandle;
use crate::audio::resampler::AudioResampler;
use crate::audio::source::{AudioSource, SourceInfo, SourceProducer};
use anyhow::{anyhow, Result};
use std::ffi::CString;
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use wavpack_sys::*;

pub fn is_wavpack_dsd(path: &std::path::Path) -> bool {
    let c_path_str = match path.to_str() {
        Some(s) => s,
        None => return false,
    };
    let c_path = match CString::new(c_path_str) {
        Ok(c) => c,
        Err(_) => return false,
    };

    let mut error_buf = [0u8; 256];
    let context = unsafe {
        WavpackOpenFileInput(c_path.as_ptr(), error_buf.as_mut_ptr() as *mut c_char, 0, 0)
    };

    if context.is_null() {
        return false;
    }

    let mode = unsafe { WavpackGetMode(context) };
    let is_dsd = (mode as u32 & 0x80000000) != 0;
    unsafe { WavpackCloseFile(context) };
    is_dsd
}

struct SendContext(*mut WavpackContext);
unsafe impl Send for SendContext {}

const CHUNK_FRAMES: u32 = 4096;

pub struct WavpackDecoderThread {
    handle: Option<JoinHandle<Result<()>>>,
    stop_signal: Arc<AtomicBool>,
}

impl WavpackDecoderThread {
    pub fn spawn(
        path: PathBuf,
        output_sample_rate: u32,
        output_channels: usize,
    ) -> Result<(AudioSource, DecoderHandle)> {
        Self::spawn_with_seek(path, output_sample_rate, output_channels, None)
    }

    pub fn spawn_with_seek(
        path: PathBuf,
        output_sample_rate: u32,
        output_channels: usize,
        start_position_secs: Option<f64>,
    ) -> Result<(AudioSource, DecoderHandle)> {
        let c_path_str = path
            .to_str()
            .ok_or_else(|| anyhow!("Invalid path encoding"))?;
        let c_path =
            CString::new(c_path_str).map_err(|_| anyhow!("Path contains null byte"))?;

        let _file = std::fs::File::open(&path)?;

        let mut error_buf = [0u8; 256];
        let context = unsafe {
            WavpackOpenFileInput(c_path.as_ptr(), error_buf.as_mut_ptr() as *mut c_char, 0, 0)
        };

        if context.is_null() {
            let error_msg = unsafe {
                std::ffi::CStr::from_ptr(error_buf.as_ptr() as *const c_char)
                    .to_string_lossy()
                    .into_owned()
            };
            return Err(anyhow!("WavPack open failed: {}", error_msg));
        }

        let mode = unsafe { WavpackGetMode(context) };
        let is_dsd = (mode as u32 & 0x80000000) != 0;

        if is_dsd {
            unsafe { WavpackCloseFile(context) };
            return Err(anyhow!(
                "WavPack DSD file should use DSD pipeline, not PCM"
            ));
        }

        let file_sample_rate = unsafe { WavpackGetSampleRate(context) };
        let file_channels = unsafe { WavpackGetNumChannels(context) } as usize;
        let total_samples_file = unsafe { WavpackGetNumSamples64(context) };
        let bytes_per_sample = unsafe { WavpackGetBytesPerSample(context) } as usize;
        let bits_per_sample = unsafe { WavpackGetBitsPerSample(context) } as usize;
        let is_float = (mode as u32 & 0x02) != 0;

        let duration_secs = if file_sample_rate > 0 {
            total_samples_file as f64 / file_sample_rate as f64
        } else {
            0.0
        };

        let source_info = SourceInfo {
            path: path.clone(),
            original_sample_rate: file_sample_rate,
            output_sample_rate,
            channels: output_channels,
            total_samples: (duration_secs * output_sample_rate as f64 * output_channels as f64)
                as u64,
            duration_secs,
        };

        let (source, producer) = AudioSource::new(source_info);
        if let Some(pos) = start_position_secs {
            if pos > 0.0 {
                source.set_position_secs(pos);
            }
        }

        let stop_signal = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop_signal);

        let seek_sample = start_position_secs
            .filter(|&p| p > 0.0)
            .map(|p| (p * file_sample_rate as f64) as i64);

        let send_ctx = SendContext(context);
        let handle = thread::Builder::new()
            .name(format!("wavpack-pcm-{}", path.display()))
            .spawn(move || {
                wavpack_pcm_decode_thread(
                    send_ctx,
                    producer,
                    file_sample_rate,
                    file_channels,
                    output_sample_rate,
                    output_channels,
                    bytes_per_sample,
                    bits_per_sample,
                    is_float,
                    stop_clone,
                    seek_sample,
                )
            })
            .map_err(|e| anyhow!("Failed to spawn WavPack PCM thread: {}", e))?;

        Ok((
            source,
            DecoderHandle::WavpackPcm(Self {
                handle: Some(handle),
                stop_signal,
            }),
        ))
    }

    pub fn stop(&self) {
        self.stop_signal.store(true, Ordering::Release);
    }

    pub fn is_running(&self) -> bool {
        self.handle
            .as_ref()
            .map(|h| !h.is_finished())
            .unwrap_or(false)
    }

    pub fn join(mut self) -> Result<()> {
        if let Some(handle) = self.handle.take() {
            handle
                .join()
                .map_err(|_| anyhow!("WavPack PCM decoder thread panicked"))?
        } else {
            Ok(())
        }
    }
}

impl Drop for WavpackDecoderThread {
    fn drop(&mut self) {
        self.stop();
    }
}

fn wavpack_pcm_decode_thread(
    ctx: SendContext,
    mut producer: SourceProducer,
    file_sample_rate: u32,
    file_channels: usize,
    output_sample_rate: u32,
    output_channels: usize,
    bytes_per_sample: usize,
    _bits_per_sample: usize,
    is_float: bool,
    stop_signal: Arc<AtomicBool>,
    seek_sample: Option<i64>,
) -> Result<()> {
    let context = ctx.0;
    if let Some(sample) = seek_sample {
        let result = unsafe { WavpackSeekSample64(context, sample) };
        if result == 0 {
            log::warn!("[WV-PCM] Seek to sample {} failed, starting from beginning", sample);
            unsafe { WavpackSeekSample64(context, 0) };
        }
    }

    let needs_resampling = file_sample_rate != output_sample_rate;
    let needs_remix = file_channels != output_channels;

    let mut resampler = if needs_resampling {
        Some(AudioResampler::new(
            file_sample_rate,
            output_sample_rate,
            output_channels,
            CHUNK_FRAMES as usize,
        )
        .map_err(|e| anyhow!("Failed to create resampler: {}", e))?)
    } else {
        None
    };

    let samples_per_frame = file_channels;
    let buf_samples = (CHUNK_FRAMES as usize) * samples_per_frame;
    let mut int_buf = vec![0i32; buf_samples];
    let mut interleaved = Vec::with_capacity(buf_samples);
    let mut resample_out = Vec::new();

    log::info!(
        "[WV-PCM] Starting: rate={}/{} ch={}/{} bps={} float={}",
        file_sample_rate, output_sample_rate,
        file_channels, output_channels,
        bytes_per_sample, is_float,
    );

    loop {
        if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
            break;
        }

        let unpacked = unsafe {
            WavpackUnpackSamples(context, int_buf.as_mut_ptr(), CHUNK_FRAMES)
        };

        if unpacked == 0 {
            break;
        }

        let frames_read = unpacked as usize;
        let total_samples = frames_read * samples_per_frame;

        interleaved.clear();

        if is_float && bytes_per_sample == 4 {
            for &sample in &int_buf[..total_samples] {
                let f = f32::from_bits(sample as u32);
                interleaved.push(f.clamp(-1.0, 1.0));
            }
        } else {
            let scale = match bytes_per_sample {
                1 => 128.0,
                2 => 32768.0,
                3 | 4 => 2147483648.0,
                _ => 2147483648.0,
            };
            for &sample in &int_buf[..total_samples] {
                interleaved.push((sample as f64 / scale) as f32);
            }
        }

        let pcm_data = if needs_remix {
            remix_channels(&interleaved, file_channels, output_channels, frames_read)
        } else {
            interleaved.clone()
        };

        let output = if let Some(ref mut rs) = resampler {
            resample_out.resize(pcm_data.len() * 2, 0.0f32);
            let n = rs.process_interleaved(&pcm_data, &mut resample_out)
                .map_err(|e| anyhow!("Resampling error: {}", e))?;
            resample_out[..n].to_vec()
        } else {
            pcm_data
        };

        write_to_ring_buffer(&output, &mut producer, &stop_signal);
    }

    if let Some(ref mut rs) = resampler {
        resample_out.resize(8192, 0.0f32);
        let n = rs.flush(&mut resample_out)
            .map_err(|e| anyhow!("Resampler flush error: {}", e))?;
        if n > 0 {
            write_to_ring_buffer(&resample_out[..n], &mut producer, &stop_signal);
        }
    }

    unsafe { WavpackCloseFile(context) };
    producer.finish();
    Ok(())
}

fn remix_channels(
    input: &[f32],
    in_ch: usize,
    out_ch: usize,
    frames: usize,
) -> Vec<f32> {
    if in_ch == out_ch {
        return input.to_vec();
    }

    let mut output = vec![0.0f32; frames * out_ch];

    for frame in 0..frames {
        let in_start = frame * in_ch;
        let out_start = frame * out_ch;

        if out_ch == 1 && in_ch >= 2 {
            let mut sum = 0.0f32;
            for ch in 0..in_ch {
                sum += input[in_start + ch];
            }
            output[out_start] = sum / in_ch as f32;
        } else if out_ch >= 2 && in_ch == 1 {
            for ch in 0..out_ch.min(2) {
                output[out_start + ch] = input[in_start];
            }
            for ch in 2..out_ch {
                output[out_start + ch] = 0.0;
            }
        } else {
            let copy = in_ch.min(out_ch);
            for ch in 0..copy {
                output[out_start + ch] = input[in_start + ch];
            }
            for ch in copy..out_ch {
                output[out_start + ch] = 0.0;
            }
        }
    }

    output
}

fn write_to_ring_buffer(
    samples: &[f32],
    producer: &mut SourceProducer,
    stop_signal: &AtomicBool,
) {
    if samples.is_empty() {
        return;
    }

    let mut offset = 0;
    while offset < samples.len() {
        if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
            break;
        }

        let chunk = &samples[offset..];
        let written = producer.write(chunk);
        offset += written;

        if written == 0 {
            producer.wait_for_space(chunk.len().min(1024), 100);
        }
    }
}
