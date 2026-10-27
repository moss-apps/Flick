use crate::audio::dsd_engine::dsd::{DsdOutputMode, DsdRate};
use crate::audio::dsd_engine::format::{
    downmix_to_stereo, open_dsd_decoder, DsdBitOrder, DsdChannelConfig, DsdChannelLayout,
    DsdFormatDecoder,
};
use crate::audio::decoder::remix_interleaved_channels;
use crate::audio::dsd_engine::output::DsdOutputRouter;
use crate::audio::resampler::AudioResampler;
use crate::audio::source::{AudioSource, SourceInfo, SourceProducer};
use anyhow::{anyhow, Result};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};

/// Read granularity on the decoder side. Large reads keep FUSE/external
/// storage syscall latency out of the producer's critical path; back-pressure
/// in `write_to_ring_buffer` handles the flow.
const DSD_READ_CHUNK_SIZE: usize = 262_144;

/// Ring capacity for DSD native sources. The offload transport pulls a whole
/// 256 KiB sample chunk per write (~half of the default 480k ring), so the
/// default leaves no slack: one producer hiccup pads the rest of the chunk
/// with silence (audible tick). 1 Mi f32 = 4 MiB holds four chunks.
const DSD_WIRE_BUFFER_SIZE: usize = 1_048_576;

pub struct DsdDecoderThread {
    handle: Option<JoinHandle<Result<()>>>,
    stop_signal: Arc<AtomicBool>,
}

impl DsdDecoderThread {
    pub fn spawn(
        path: PathBuf,
        output_mode: DsdOutputMode,
        target_rate: u32,
        output_channels: usize,
    ) -> Result<(AudioSource, Self)> {
        Self::spawn_with_seek(path, output_mode, target_rate, output_channels, None)
    }

    pub fn spawn_with_seek(
        path: PathBuf,
        output_mode: DsdOutputMode,
        target_rate: u32,
        output_channels: usize,
        start_position_secs: Option<f64>,
    ) -> Result<(AudioSource, Self)> {
        let decoder = open_dsd_decoder(&path)?;

        let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate())
            .ok_or_else(|| anyhow!("Unsupported DSD sample rate: {}", decoder.sample_rate()))?;

        let source_channels = decoder.channels() as usize;
        if source_channels == 0 || output_channels == 0 {
            return Err(anyhow!("DSD channel count must be nonzero"));
        }
        let duration_secs = decoder.duration_secs();
        let channel_layout = decoder.channel_layout();
        let source_bit_order = decoder.bit_order();
        let source_config = decoder.channel_config();
        let wire_mode = matches!(output_mode, DsdOutputMode::Dop | DsdOutputMode::Native);
        if wire_mode && source_channels != output_channels {
            return Err(anyhow!(
                "DSD wire channel mismatch: source={}, output={}. Wired DSD needs a DAC alt with {} channels; choose Auto or PCM decimation for a stereo fold-down.",
                source_channels,
                output_channels,
                source_channels
            ));
        }
        if !wire_mode && source_channels > 6 {
            return Err(anyhow!(
                "DSD PCM decimation supports at most 6 source channels (file has {})",
                source_channels
            ));
        }

        // The decimator only produces 44.1 kHz-family rates. Keep that as an
        // intermediate stage and let the output chain resample to whatever
        // the engine actually negotiated (commonly 48 kHz on shared output).
        let (output_sample_rate, router_rate, pcm_chain) = match output_mode {
            DsdOutputMode::PcmDecimation | DsdOutputMode::Auto => {
                let decimation_rate = select_decimation_target(dsd_rate, target_rate);
                let engine_rate = if target_rate != 0 {
                    target_rate
                } else {
                    decimation_rate
                };
                let chain = PcmOutputChain::new(
                    decimation_rate,
                    engine_rate,
                    source_channels,
                    output_channels,
                    source_config,
                )?;
                (engine_rate, decimation_rate, chain)
            }
            DsdOutputMode::Dop => (
                dsd_rate.dop_carrier_rate(),
                dsd_rate.dop_carrier_rate(),
                None,
            ),
            DsdOutputMode::Native => (dsd_rate.byte_rate(), dsd_rate.byte_rate(), None),
        };

        // A rate mismatch without a conversion chain means the decoder would
        // stamp its samples with the wrong rate. That is a pitch bug, not a
        // recoverable condition, so fail before the thread starts.
        if output_sample_rate != router_rate && pcm_chain.is_none() {
            return Err(anyhow!(
                "DSD PCM output rate mismatch: decoded at {} Hz but engine runs at {} Hz",
                router_rate,
                output_sample_rate
            ));
        }

        log::info!(
            "[DSD-DECODER] spawn: path={}, file_rate={} Hz, dsd_rate={:?}, output_mode={:?}, target_rate={} Hz, output_rate={} Hz",
            path.display(),
            decoder.sample_rate(),
            dsd_rate,
            output_mode,
            target_rate,
            output_sample_rate,
        );

        let total_output_samples = if duration_secs > 0.0 {
            (duration_secs * output_sample_rate as f64 * output_channels as f64) as u64
        } else {
            0
        };

        let source_info = SourceInfo {
            path: path.clone(),
            range: crate::audio::source::PlaybackRange::default(),
            original_sample_rate: decoder.sample_rate(),
            output_sample_rate,
            channels: output_channels,
            total_samples: total_output_samples,
            duration_secs,
            http_origin: None,
        };

        let (source, producer) = if output_mode == DsdOutputMode::Native {
            AudioSource::new_with_capacity(source_info, DSD_WIRE_BUFFER_SIZE)
        } else {
            AudioSource::new(source_info)
        };
        if matches!(output_mode, DsdOutputMode::Native | DsdOutputMode::Dop) {
            // f32 bits carry the DSD payload in these modes; a ReplayGain
            // multiply would corrupt it.
            source.set_bit_exact(true);
        }
        if let Some(pos) = start_position_secs {
            if pos > 0.0 {
                source.set_position_secs(pos);
            }
        }

        let output_router = DsdOutputRouter::new(
            output_mode,
            dsd_rate,
            router_rate,
            source_channels,
            source_bit_order,
        );

        let stop_signal = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop_signal);

        let handle = thread::Builder::new()
            .name(format!("dsd-decoder-{}", path.display()))
            .spawn(move || {
                crate::audio::thread_priority::raise_audio_decode_priority();
                dsd_decode_thread(
                    decoder,
                    producer,
                    output_router,
                    source_channels,
                    pcm_chain,
                    stop_clone,
                    start_position_secs,
                    channel_layout,
                    source_bit_order,
                )
                .inspect_err(|error| log::error!("[DSD-DECODER] {}: {}", path.display(), error))
            })
            .map_err(|e| anyhow!("Failed to spawn DSD decoder thread: {}", e))?;

        Ok((
            source,
            Self {
                handle: Some(handle),
                stop_signal,
            },
        ))
    }

    pub fn stop(&self) {
        self.stop_signal.store(true, Ordering::Release);
    }

    pub fn join(mut self) -> Result<()> {
        if let Some(handle) = self.handle.take() {
            handle
                .join()
                .map_err(|_| anyhow!("DSD decoder thread panicked"))?
        } else {
            Ok(())
        }
    }

    pub fn is_running(&self) -> bool {
        self.handle
            .as_ref()
            .map(|h| !h.is_finished())
            .unwrap_or(false)
    }
}

impl Drop for DsdDecoderThread {
    fn drop(&mut self) {
        self.stop();
    }
}

enum ChannelData {
    Owned(Vec<u8>),
}

impl ChannelData {
    fn as_slice(&self) -> &[u8] {
        match self {
            ChannelData::Owned(v) => v,
        }
    }
}

fn dsd_decode_thread(
    mut decoder: Box<dyn DsdFormatDecoder>,
    mut producer: SourceProducer,
    mut output_router: DsdOutputRouter,
    source_channels: usize,
    mut pcm_chain: Option<PcmOutputChain>,
    stop_signal: Arc<AtomicBool>,
    start_position_secs: Option<f64>,
    channel_layout: DsdChannelLayout,
    _source_bit_order: DsdBitOrder,
) -> Result<()> {
    if let Some(pos) = start_position_secs {
        if pos > 0.0 {
            let dsd_rate = decoder.sample_rate();
            let target_sample = (pos * dsd_rate as f64) as u64;
            if let Err(error) = decoder.seek(target_sample) {
                producer.finish();
                return Err(error);
            }
            output_router.reset();
        }
    }

    let read_size = match &channel_layout {
        DsdChannelLayout::SequentialBlocks { block_size } => {
            let aligned = block_size.checked_mul(source_channels).filter(|&size| size > 0);
            let Some(aligned) = aligned else {
                producer.finish();
                return Err(anyhow!("Invalid DSD channel block size"));
            };
            let chunks = DSD_READ_CHUNK_SIZE.div_ceil(aligned);
            chunks * aligned
        }
        DsdChannelLayout::Interleaved =>
            (DSD_READ_CHUNK_SIZE / source_channels).max(1) * source_channels,
    };

    let mut dsd_buf = vec![0u8; read_size];
    let mut output_buf: Vec<f32> = Vec::with_capacity(read_size);

    // Offline wire-vs-reference diffing, opt-in via `set_dsd_dumps_enabled`.
    // Only the first decoder thread to claim the flag dumps, so a gapless
    // preload decoder can't interleave.
    static DUMP_CLAIMED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
    let dump_enabled =
        crate::audio::dsd_engine::dsd_dumps_enabled() && !DUMP_CLAIMED.swap(true, Ordering::AcqRel);
    let mut dump_raw: Option<std::fs::File> = None;
    let mut dump_prod: Option<std::fs::File> = None;
    let mut dump_raw_n: usize = 0;
    let mut dump_prod_n: usize = 0;
    if dump_enabled {
        use std::fs::OpenOptions;
        let dir = std::path::Path::new("/storage/6438-6261/flick_dsd_dump");
        let _ = std::fs::create_dir_all(dir);
        dump_raw = OpenOptions::new()
            .create(true).write(true).truncate(true)
            .open(dir.join("dsd_raw_full.bin")).ok();
        dump_prod = OpenOptions::new()
            .create(true).write(true).truncate(true)
            .open(dir.join("dsd_prod_full.bin")).ok();
        log::info!(
            "[DSD-DECODER] dump capture claimed (raw+prod), read_size={}",
            read_size
        );
    }

    log::info!(
        "[DSD-DECODER] Starting: dsd_rate={} channels={} layout={:?} bit_order={:?}",
        decoder.sample_rate(),
        source_channels,
        channel_layout,
        _source_bit_order,
    );

    loop {
        if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
            break;
        }

        let bytes_read = match decoder.read_dsd_bytes(&mut dsd_buf) {
            Ok(n) => n,
            Err(error) => { producer.finish(); return Err(error); }
        };
        if bytes_read == 0 {
            break;
        }
        let frame_bytes = match &channel_layout {
            DsdChannelLayout::Interleaved => source_channels,
            DsdChannelLayout::SequentialBlocks { block_size } => block_size * source_channels,
        };
        if frame_bytes == 0 || bytes_read > dsd_buf.len() || bytes_read % frame_bytes != 0 {
            producer.finish();
            return Err(anyhow!("DSD decoder returned an incomplete channel frame"));
        }

        if let Some(f) = dump_raw.as_mut() {
            if dump_raw_n < (5 << 20) {
                use std::io::Write;
                let cap = ((5 << 20) - dump_raw_n).min(bytes_read);
                let _ = f.write_all(&dsd_buf[..cap]);
                dump_raw_n += cap;
            }
        }

        let (data, offsets) = match &channel_layout {
            DsdChannelLayout::Interleaved => {
                let deint = deinterleave_dsd(&dsd_buf[..bytes_read], source_channels);
                let bytes_per_ch = deint.len() / source_channels.max(1);
                let off: Vec<usize> = (0..source_channels).map(|ch| ch * bytes_per_ch).collect();
                (ChannelData::Owned(deint), off)
            }
            DsdChannelLayout::SequentialBlocks { block_size } => {
                let deint = deinterleave_sequential_blocks(
                    &dsd_buf[..bytes_read],
                    source_channels,
                    *block_size,
                );
                let bytes_per_ch = deint.len() / source_channels.max(1);
                let off: Vec<usize> = (0..source_channels).map(|ch| ch * bytes_per_ch).collect();
                (ChannelData::Owned(deint), off)
            }
        };

        if let Err(e) = output_router.process_dsd_bytes(data.as_slice(), &offsets, &mut output_buf)
        {
            log::error!("[DSD-DECODER] Processing error: {}", e);
            producer.finish();
            return Err(e);
        }

        if let Some(f) = dump_prod.as_mut() {
            if dump_prod_n < (5 << 20) {
                use std::io::Write;
                let mut tmp: Vec<u8> = Vec::with_capacity(output_buf.len());
                for s in &output_buf {
                    tmp.push(s.to_bits() as u8);
                }
                let cap = ((5 << 20) - dump_prod_n).min(tmp.len());
                let _ = f.write_all(&tmp[..cap]);
                dump_prod_n += cap;
            }
        }

        let samples: &[f32] = match pcm_chain.as_mut() {
            Some(chain) => chain.process(&output_buf),
            None => output_buf.as_slice(),
        };
        write_to_ring_buffer(samples, &mut producer, &stop_signal);
    }

    if !stop_signal.load(Ordering::Acquire) && !producer.should_stop() {
        output_router.flush_dop(&mut output_buf);
        write_to_ring_buffer(&output_buf, &mut producer, &stop_signal);
    }
    if let Some(chain) = pcm_chain.as_mut() {
        loop {
            let tail = chain.flush();
            if tail.is_empty() {
                break;
            }
            write_to_ring_buffer(tail, &mut producer, &stop_signal);
        }
    }

    producer.finish();
    Ok(())
}

fn deinterleave_dsd(interleaved: &[u8], channels: usize) -> Vec<u8> {
    if channels <= 1 {
        return interleaved.to_vec();
    }

    let frames = interleaved.len() / channels;
    let mut output = vec![0u8; interleaved.len()];

    for ch in 0..channels {
        for frame in 0..frames {
            output[ch * frames + frame] = interleaved[frame * channels + ch];
        }
    }

    output
}

fn deinterleave_sequential_blocks(data: &[u8], channels: usize, block_size: usize) -> Vec<u8> {
    if channels <= 1 {
        return data.to_vec();
    }
    let macro_block = block_size * channels;
    let num_blocks = data.len() / macro_block;
    let bytes_per_ch = num_blocks * block_size;
    let mut out = vec![0u8; bytes_per_ch * channels];

    for ch in 0..channels {
        for block in 0..num_blocks {
            let src = block * macro_block + ch * block_size;
            let dst = ch * bytes_per_ch + block * block_size;
            out[dst..dst + block_size].copy_from_slice(&data[src..src + block_size]);
        }
    }
    out
}

fn write_to_ring_buffer(samples: &[f32], producer: &mut SourceProducer, stop_signal: &AtomicBool) {
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

/// Pick the 44.1 kHz-family rate the CIC+FIR decimator should produce.
/// Prefers an exact engine-rate match, then the highest family rate that
/// fits below the engine rate, and falls back to the smallest family rate
/// (the output chain then upsamples to the engine rate).
///
/// Rates above 176.4 kHz are capped even if the engine reports one: the
/// decimator's FIR cost doubles at 352.8 kHz and again at 705.6 kHz, and the
/// managed Android path may accept the rate without providing a reliable
/// clock. The output chain resamples from the capped rate when needed.
fn select_decimation_target(dsd_rate: DsdRate, engine_rate: u32) -> u32 {
    let targets = dsd_rate.pcm_decimation_targets();
    let ceiling = if engine_rate == 0 {
        0
    } else {
        engine_rate.min(DsdRate::MAX_PCM_TARGET)
    };
    if ceiling != 0 {
        if let Some(&exact) = targets.iter().find(|&&t| t == ceiling) {
            return exact;
        }
        if let Some(&below) = targets.iter().find(|&&t| t <= ceiling) {
            return below;
        }
    }
    targets.last().copied().unwrap_or(44_100)
}

/// Converts the decimator's 44.1 kHz-family output into what the engine's
/// callback actually consumes: the negotiated rate and channel count.
/// Only used for PCM decimation modes; DoP/native payloads stay untouched.
struct PcmOutputChain {
    source_channels: usize,
    output_channels: usize,
    source_config: Option<DsdChannelConfig>,
    resampler: Option<AudioResampler>,
    remix_buf: Vec<f32>,
    resample_buf: Vec<f32>,
}

impl PcmOutputChain {
    fn new(
        decimation_rate: u32,
        engine_rate: u32,
        source_channels: usize,
        output_channels: usize,
        source_config: Option<DsdChannelConfig>,
    ) -> Result<Option<Self>> {
        let needs_resample = decimation_rate != engine_rate;
        let needs_remix = source_channels != output_channels;
        if !needs_resample && !needs_remix {
            return Ok(None);
        }

        let resampler = if needs_resample {
            Some(
                AudioResampler::new(decimation_rate, engine_rate, output_channels.max(1), 4096)
                    .map_err(|error| {
                        anyhow!(
                            "Failed to create DSD PCM resampler {} -> {} Hz: {}",
                            decimation_rate,
                            engine_rate,
                            error
                        )
                    })?,
            )
        } else {
            None
        };

        log::info!(
            "[DSD-PCM] output chain: decimation={} Hz, engine={} Hz, channels {} -> {}, layout={}, resample={}",
            decimation_rate,
            engine_rate,
            source_channels,
            output_channels,
            source_config.map(|config| config.label()).unwrap_or("unknown"),
            needs_resample,
        );

        Ok(Some(Self {
            source_channels,
            output_channels,
            source_config,
            resampler,
            remix_buf: Vec::new(),
            resample_buf: Vec::new(),
        }))
    }

    fn process(&mut self, input: &[f32]) -> &[f32] {
        if self.source_channels != self.output_channels {
            let frames = input.len() / self.source_channels.max(1);
            self.remix_buf
                .resize(frames * self.output_channels.max(1), 0.0);
            let written = if self.output_channels == 2 && self.source_channels > 2 {
                match self.source_config {
                    Some(config) if config.channels() as usize == self.source_channels => {
                        downmix_to_stereo(input, config, &mut self.remix_buf)
                    }
                    Some(_) => {
                        log::error!(
                            "[DSD-PCM] channel layout does not match {} source channels; dropping chunk",
                            self.source_channels
                        );
                        0
                    }
                    None => {
                        log::error!(
                            "[DSD-PCM] unknown {}-channel layout; refusing to guess a downmix",
                            self.source_channels
                        );
                        0
                    }
                }
            } else {
                remix_interleaved_channels(
                    input,
                    self.source_channels,
                    self.output_channels,
                    &mut self.remix_buf,
                );
                frames * self.output_channels
            };
            self.remix_buf.truncate(written);

            if let Some(resampler) = self.resampler.as_mut() {
                self.resample_buf.resize(self.remix_buf.len() * 2 + 8192, 0.0);
                match resampler.process_interleaved(&self.remix_buf, &mut self.resample_buf) {
                    Ok(written) => self.resample_buf.truncate(written),
                    Err(e) => {
                        log::error!("[DSD-PCM] output resampler error: {}", e);
                        self.resample_buf.clear();
                    }
                }
                return &self.resample_buf;
            }

            return &self.remix_buf;
        }

        if let Some(resampler) = self.resampler.as_mut() {
            self.resample_buf.resize(input.len() * 2 + 8192, 0.0);
            match resampler.process_interleaved(input, &mut self.resample_buf) {
                Ok(written) => self.resample_buf.truncate(written),
                Err(e) => {
                    log::error!("[DSD-PCM] output resampler error: {}", e);
                    self.resample_buf.clear();
                }
            }
            return &self.resample_buf;
        }

        // A chain with neither remix nor resampler is never created.
        &[]
    }

    fn flush(&mut self) -> &[f32] {
        if let Some(resampler) = self.resampler.as_mut() {
            self.resample_buf.resize(8192, 0.0);
            match resampler.flush(&mut self.resample_buf) {
                Ok(written) => self.resample_buf.truncate(written),
                Err(e) => {
                    log::error!("[DSD-PCM] output resampler flush error: {}", e);
                    self.resample_buf.clear();
                }
            }
            &self.resample_buf
        } else {
            &[]
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::dsd_engine::dsd::DsdDecimationPipeline;
    use std::f64::consts::PI;

    fn tone_magnitude(samples: &[f32], sample_rate: u32, freq_hz: f64) -> f64 {
        let omega = 2.0 * PI * freq_hz / sample_rate as f64;
        let mut real = 0.0f64;
        let mut imag = 0.0f64;

        for (index, &sample) in samples.iter().enumerate() {
            let phase = omega * index as f64;
            real += sample as f64 * phase.cos();
            imag -= sample as f64 * phase.sin();
        }

        2.0 * real.hypot(imag) / samples.len() as f64
    }

    fn detect_tone_frequency(
        samples: &[f32],
        sample_rate: u32,
        center_hz: f64,
        radius_hz: f64,
        step_hz: f64,
    ) -> (f64, f64) {
        let mut best_freq = center_hz - radius_hz;
        let mut best_mag = f64::NEG_INFINITY;
        let steps = ((2.0 * radius_hz) / step_hz).round() as usize;

        for step in 0..=steps {
            let freq = center_hz - radius_hz + step as f64 * step_hz;
            let magnitude = tone_magnitude(samples, sample_rate, freq);
            if magnitude > best_mag {
                best_freq = freq;
                best_mag = magnitude;
            }
        }

        (best_freq, best_mag)
    }

    fn dsd_sine_bytes(freq_hz: f64, dsd_rate: u32, seconds: f64, amplitude: f64) -> Vec<u8> {
        let bits = (dsd_rate as f64 * seconds) as usize;
        let mut bytes = vec![0u8; bits / 8];
        let mut integrator = 0.0f64;
        let mut previous = 1.0f64;

        for index in 0..bits {
            let phase = 2.0 * PI * freq_hz * index as f64 / dsd_rate as f64;
            integrator += amplitude * phase.sin() - previous;
            previous = if integrator >= 0.0 { 1.0 } else { -1.0 };
            if previous > 0.0 {
                bytes[index / 8] |= 0x80 >> (index % 8);
            }
        }

        bytes
    }

    #[test]
    fn decimation_target_prefers_family_rate_below_engine_rate() {
        assert_eq!(select_decimation_target(DsdRate::Dsd64, 44_100), 44_100);
        assert_eq!(select_decimation_target(DsdRate::Dsd64, 176_400), 176_400);
        assert_eq!(select_decimation_target(DsdRate::Dsd64, 48_000), 44_100);
        assert_eq!(select_decimation_target(DsdRate::Dsd64, 96_000), 88_200);
        assert_eq!(select_decimation_target(DsdRate::Dsd64, 8_000), 44_100);
        assert_eq!(select_decimation_target(DsdRate::Dsd64, 0), 44_100);
        assert_eq!(select_decimation_target(DsdRate::Dsd128, 352_800), 176_400);
        assert_eq!(select_decimation_target(DsdRate::Dsd256, 705_600), 176_400);
        assert_eq!(select_decimation_target(DsdRate::Dsd128, 192_000), 176_400);
    }

    #[test]
    fn dsd128_pcm_chain_preserves_pitch_at_48k() {
        let tone_hz = 1_000.0;
        let dsd_bytes = dsd_sine_bytes(
            tone_hz,
            DsdRate::Dsd128.sample_rate(),
            0.25,
            0.5,
        );
        let mut pipeline = DsdDecimationPipeline::new(DsdRate::Dsd128, 176_400, 1, false);
        let mut pcm = Vec::new();
        pipeline.process_bytes(&dsd_bytes, &[0], &mut pcm);
        assert!(pcm.len() > 8_000, "decimator produced {} samples", pcm.len());

        let mut chain = PcmOutputChain::new(176_400, 48_000, 1, 1, None)
            .expect("resampler setup should succeed")
            .expect("rate change needs a chain");
        let mut output = Vec::new();
        output.extend_from_slice(chain.process(&pcm));
        loop {
            let flushed = chain.flush();
            if flushed.is_empty() {
                break;
            }
            output.extend_from_slice(flushed);
        }

        assert!(output.len() > 4_096, "resampler produced {} samples", output.len());
        let analysis = &output[2_048..];
        let (measured_hz, magnitude) =
            detect_tone_frequency(analysis, 48_000, tone_hz, 20.0, 0.5);
        assert!(
            (measured_hz - tone_hz).abs() < 1.0,
            "tone moved from {tone_hz} Hz to {measured_hz} Hz through the DSD chain"
        );
        assert!(
            magnitude > 0.2,
            "tone level collapsed through the DSD chain: {magnitude}"
        );
    }

    #[test]
    fn pcm_chain_folds_down_known_multichannel_layouts() {
        let mut chain = PcmOutputChain::new(
            176_400,
            176_400,
            6,
            2,
            Some(DsdChannelConfig::FivePointOne),
        )
        .expect("resampler setup should succeed")
        .expect("six-to-two needs a chain");
        // FL=1, FR=1, C=1, LFE=0, BL=1, BR=1; normalized to 1.0.
        let output = chain.process(&[1.0, 1.0, 1.0, 0.0, 1.0, 1.0]);
        assert_eq!(output.len(), 2);
        assert!((output[0] - 1.0).abs() < 1e-6);
        assert!((output[1] - 1.0).abs() < 1e-6);
    }

    #[test]
    fn pcm_chain_refuses_unknown_multichannel_layouts() {
        let mut chain = PcmOutputChain::new(176_400, 176_400, 8, 2, None)
            .expect("resampler setup should succeed")
            .expect("channel count change forces a chain");
        assert!(chain.process(&[0.0f32; 16]).is_empty());
    }
}
