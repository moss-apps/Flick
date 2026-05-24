use crate::audio::dsd_engine::dsd::{DsdOutputMode, DsdRate};
use crate::audio::dsd_engine::format::{open_dsd_decoder, DsdChannelLayout, DsdFormatDecoder};
use crate::audio::dsd_engine::output::DsdOutputRouter;
use crate::audio::source::{AudioSource, SourceInfo, SourceProducer};
use anyhow::{anyhow, Result};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};

const DSD_READ_CHUNK_SIZE: usize = 16384;

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

        let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate()).ok_or_else(|| {
            anyhow!("Unsupported DSD sample rate: {}", decoder.sample_rate())
        })?;

        let source_channels = decoder.channels() as usize;
        let duration_secs = decoder.duration_secs();
        let channel_layout = decoder.channel_layout();

        let output_sample_rate = match output_mode {
            DsdOutputMode::PcmDecimation => dsd_rate.best_pcm_target(target_rate),
            DsdOutputMode::Dop => dsd_rate.dop_carrier_rate(),
            DsdOutputMode::Native => dsd_rate.sample_rate(),
        };

        let total_output_samples = if duration_secs > 0.0 {
            (duration_secs * output_sample_rate as f64 * output_channels as f64) as u64
        } else {
            0
        };

        let source_info = SourceInfo {
            path: path.clone(),
            original_sample_rate: decoder.sample_rate(),
            output_sample_rate,
            channels: output_channels,
            total_samples: total_output_samples,
            duration_secs,
        };

        let (source, producer) = AudioSource::new(source_info);
        if let Some(pos) = start_position_secs {
            if pos > 0.0 {
                source.set_position_secs(pos);
            }
        }

        let output_router =
            DsdOutputRouter::new(output_mode, dsd_rate, output_sample_rate, source_channels);

        let stop_signal = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop_signal);

        let handle = thread::Builder::new()
            .name(format!("dsd-decoder-{}", path.display()))
            .spawn(move || {
                dsd_decode_thread(
                    decoder,
                    producer,
                    output_router,
                    source_channels,
                    output_channels,
                    stop_clone,
                    start_position_secs,
                    channel_layout,
                )
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

enum ChannelData<'a> {
    Borrowed(&'a [u8]),
    Owned(Vec<u8>),
}

impl<'a> ChannelData<'a> {
    fn as_slice(&self) -> &[u8] {
        match self {
            ChannelData::Borrowed(s) => s,
            ChannelData::Owned(v) => v,
        }
    }
}

fn dsd_decode_thread(
    mut decoder: Box<dyn DsdFormatDecoder>,
    mut producer: SourceProducer,
    mut output_router: DsdOutputRouter,
    source_channels: usize,
    _output_channels: usize,
    stop_signal: Arc<AtomicBool>,
    start_position_secs: Option<f64>,
    channel_layout: DsdChannelLayout,
) -> Result<()> {
    if let Some(pos) = start_position_secs {
        if pos > 0.0 {
            let dsd_rate = decoder.sample_rate();
            let target_sample = (pos * dsd_rate as f64) as u64;
            decoder.seek(target_sample)?;
            output_router.reset();
        }
    }

    let read_size = match &channel_layout {
        DsdChannelLayout::SequentialBlocks { block_size } => {
            let aligned = block_size * source_channels;
            let chunks = (DSD_READ_CHUNK_SIZE + aligned - 1) / aligned;
            chunks * aligned
        }
        DsdChannelLayout::Interleaved => DSD_READ_CHUNK_SIZE,
    };

    let needs_deinterleave = matches!(channel_layout, DsdChannelLayout::Interleaved);

    let mut dsd_buf = vec![0u8; read_size];
    let mut output_buf: Vec<f32> = Vec::with_capacity(DSD_READ_CHUNK_SIZE);

    log::info!(
        "[DSD-DECODER] Starting: dsd_rate={} channels={} layout={:?}",
        decoder.sample_rate(),
        source_channels,
        channel_layout,
    );

    loop {
        if stop_signal.load(Ordering::Acquire) || producer.should_stop() {
            break;
        }

        let bytes_read = decoder.read_dsd_bytes(&mut dsd_buf)?;
        if bytes_read == 0 {
            break;
        }

        let (data, offsets) = if needs_deinterleave {
            let deint = deinterleave_dsd(&dsd_buf[..bytes_read], source_channels);
            let bytes_per_ch = deint.len() / source_channels.max(1);
            let off: Vec<usize> = (0..source_channels).map(|ch| ch * bytes_per_ch).collect();
            (ChannelData::Owned(deint), off)
        } else {
            let bytes_per_ch = bytes_read / source_channels.max(1);
            let off: Vec<usize> = (0..source_channels).map(|ch| ch * bytes_per_ch).collect();
            (ChannelData::Borrowed(&dsd_buf[..bytes_read]), off)
        };

        if let Err(e) = output_router.process_dsd_bytes(data.as_slice(), &offsets, &mut output_buf)
        {
            log::error!("[DSD-DECODER] Processing error: {}", e);
            break;
        }

        write_to_ring_buffer(&output_buf, &mut producer, &stop_signal);
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

        if written == 0 && !producer.wait_for_space(chunk.len().min(1024), 100) {
            break;
        }
    }
}
