use crate::audio::commands::AudioEvent;
use crate::audio::engine::audio_callback;
use crate::audio::engine::AudioCallbackData;
use crossbeam_channel::Sender;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};

const DSD_NATIVE_CHUNK_MS: u64 = 10;

pub struct DsdNativeBackend {
    stop: Arc<AtomicBool>,
    render_thread: Option<JoinHandle<()>>,
}

impl DsdNativeBackend {
    /// Opens native DSD output via direct ALSA ioctl (bypasses AudioTrack
    /// and AudioFlinger entirely).  `sample_rate` is the DSD byte rate
    /// (352 800 for DSD64, 705 600 for DSD128).
    pub fn start(
        callback_data: Arc<AudioCallbackData>,
        event_tx: Sender<AudioEvent>,
        sample_rate: u32,
        channels: usize,
    ) -> Result<Self, String> {
        log::info!(
            "[DSD-NATIVE] Opening ALSA direct DSD output: byte_rate={} Hz, ch={}",
            sample_rate,
            channels,
        );

        if !super::dsd_alsa_direct::dsd_alsa_open(sample_rate, channels) {
            return Err(format!(
                "ALSA DSD output unavailable at byte_rate={} ch={}",
                sample_rate, channels
            ));
        }

        let stop = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop);

        let handle = thread::Builder::new()
            .name("dsd-native-render".to_string())
            .spawn(move || {
                dsd_native_render_loop(callback_data, event_tx, sample_rate, channels, stop_clone);
                super::dsd_alsa_direct::dsd_alsa_close();
            })
            .map_err(|e| format!("Failed to spawn DSD render thread: {}", e))?;

        Ok(Self {
            stop,
            render_thread: Some(handle),
        })
    }

    pub fn stop(&mut self) {
        self.stop.store(true, Ordering::Release);
        if let Some(handle) = self.render_thread.take() {
            let _ = handle.join();
        }
    }

    pub fn is_alsa(&self) -> bool {
        true
    }
}

fn dsd_native_render_loop(
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    sample_rate: u32,
    channels: usize,
    stop: Arc<AtomicBool>,
) {
    let valid_byte_rates = [352_800, 705_600, 1_411_200, 2_822_400];
    if !valid_byte_rates.contains(&sample_rate) {
        log::error!(
            "[DSD-NATIVE] Unexpected byte_rate={} — expected one of {:?}",
            sample_rate,
            valid_byte_rates,
        );
    }

    let chunk_frames = (((sample_rate as u64) * DSD_NATIVE_CHUNK_MS) / 1000).max(1) as usize;
    let chunk_samples = chunk_frames * channels;
    let mut render_buffer = vec![0.0f32; chunk_samples];
    let mut dsd_bytes = vec![0u8; chunk_samples];

    log::info!(
        "[DSD-NATIVE] ALSA render loop started: byte_rate={} Hz, ch={}, chunk={} frames ({}ms)",
        sample_rate,
        channels,
        chunk_frames,
        DSD_NATIVE_CHUNK_MS
    );

    while !stop.load(Ordering::Acquire) {
        audio_callback(&mut render_buffer, &callback_data, &event_tx);

        for (i, sample) in render_buffer.iter().enumerate() {
            dsd_bytes[i] = (sample.to_bits() & 0xFF) as u8;
        }

        let written = super::dsd_alsa_direct::dsd_alsa_write(&dsd_bytes);
        if written < 0 {
            log::error!("[DSD-NATIVE] ALSA write failed, stopping render loop");
            break;
        }
    }

    log::info!("[DSD-NATIVE] ALSA render loop ended");
}
