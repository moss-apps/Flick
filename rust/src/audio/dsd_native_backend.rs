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
    // sample_rate is the DSD byte rate (bit_rate / 8).
    // Common byte rates: 352 800 (DSD64), 705 600 (DSD128), 1 411 200 (DSD256).
    pub fn start(
        callback_data: Arc<AudioCallbackData>,
        event_tx: Sender<AudioEvent>,
        sample_rate: u32,
        channels: usize,
    ) -> Result<Self, String> {
        let dsd_sample_rate = sample_rate * 8;

        log::info!(
            "[DSD-NATIVE] Creating AudioTrack: byte_rate={} Hz, bit_rate={} Hz, ch={}",
            sample_rate,
            dsd_sample_rate,
            channels,
        );

        super::dsd_native_jni::dsd_track_create(dsd_sample_rate, channels).then(|| ()).ok_or_else(|| {
            format!(
                "Failed to create DSD AudioTrack (bit_rate={}, byte_rate={}, ch={})",
                dsd_sample_rate, sample_rate, channels
            )
        })?;

        if !super::dsd_native_jni::dsd_track_play() {
            super::dsd_native_jni::dsd_track_stop();
            return Err("Failed to start DSD AudioTrack playback".to_string());
        }

        let stop = Arc::new(AtomicBool::new(false));
        let stop_clone = Arc::clone(&stop);

        let handle = thread::Builder::new()
            .name("dsd-native-render".to_string())
            .spawn(move || {
                dsd_native_render_loop(callback_data, event_tx, sample_rate, channels, stop_clone);
                super::dsd_native_jni::dsd_track_stop();
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
}

fn dsd_native_render_loop(
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    sample_rate: u32,
    channels: usize,
    stop: Arc<AtomicBool>,
) {
    // sample_rate must be a DSD byte rate (bit_rate / 8).
    let valid_byte_rates = [352_800, 705_600, 1_411_200, 2_822_400];
    if !valid_byte_rates.contains(&sample_rate) {
        log::error!(
            "[DSD-NATIVE] Unexpected byte_rate={} — expected one of {:?}. \
             The engine may have been created at the wrong rate.",
            sample_rate,
            valid_byte_rates,
        );
    }

    let chunk_frames = (((sample_rate as u64) * DSD_NATIVE_CHUNK_MS) / 1000).max(1) as usize;
    let chunk_samples = chunk_frames * channels;
    let mut render_buffer = vec![0.0f32; chunk_samples];
    let mut dsd_bytes = vec![0u8; chunk_samples];

    log::info!(
        "[DSD-NATIVE] Render loop started: dsd_rate={} Hz, byte_rate={} Hz, ch={}, chunk={} frames ({}ms)",
        sample_rate * 8, sample_rate, channels, chunk_frames, DSD_NATIVE_CHUNK_MS
    );

    while !stop.load(Ordering::Acquire) {
        audio_callback(&mut render_buffer, &callback_data, &event_tx);

        for (i, sample) in render_buffer.iter().enumerate() {
            dsd_bytes[i] = (sample.to_bits() & 0xFF) as u8;
        }

        let written = super::dsd_native_jni::dsd_track_write(&dsd_bytes);
        if written < 0 {
            log::error!("[DSD-NATIVE] AudioTrack write failed, stopping render loop");
            break;
        }
    }

    log::info!("[DSD-NATIVE] Render loop ended");
}