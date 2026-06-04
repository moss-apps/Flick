//! Core audio engine with cpal output and lock-free architecture.
//!
//! The engine manages the audio output stream, handles commands from Dart,
//! and coordinates decoding, resampling, and crossfading.

use crate::audio::commands::{AudioCommand, AudioEvent, PlaybackProgress, PlaybackState};
use crate::audio::crossfader::Crossfader;
use crate::audio::decoder::DecoderThread;
use crate::audio::decoder_handle::{DecoderHandle, FileType, detect_file_type};
use crate::audio::dsd_engine::DsdDecoderThread;
use crate::audio::wavpack_thread::WavpackDecoderThread;
#[cfg(target_os = "android")]
use crate::audio::device::current_device_profile;
use crate::audio::dynamics::DynamicsChain;
use crate::audio::equalizer::Equalizer;
use crate::audio::fx::SpatialFx;
use crate::audio::source::{AudioSource, SourceProvider};
use crate::audio::strategy::OutputStrategy;
#[cfg(target_os = "android")]
use crate::audio::strategy::{select_strategy_excluded, DeviceCaps, TrackInfo};
#[cfg(target_os = "android")]
use crate::audio::verifier::OutputVerification;
#[cfg(all(feature = "uac2", target_os = "android"))]
use crate::uac2::{
    android_direct_debug_state, android_direct_output_signature, create_android_usb_backend,
    validate_android_direct_request,
};

#[cfg(not(target_os = "android"))]
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
#[cfg(not(target_os = "android"))]
use cpal::{SampleRate, StreamConfig};
use crossbeam_channel::{bounded, Receiver, Sender};
#[cfg(target_os = "android")]
use oboe::{
    AudioApi, AudioDeviceDirection, AudioDeviceInfo, AudioDeviceType, AudioFormat,
    AudioOutputCallback, AudioOutputStreamSafe, AudioStream, AudioStreamAsync, AudioStreamBase,
    AudioStreamSafe, ContentType, DataCallbackResult, Output, PerformanceMode,
    SampleRateConversionQuality, SharingMode, Stereo, Usage,
};
use parking_lot::Mutex;
use serde::Serialize;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicU8, Ordering};
use std::sync::Arc;
use std::thread;

pub static XRUN_COUNT: AtomicU64 = AtomicU64::new(0);

#[derive(Debug, Clone, Serialize)]
pub struct AudioOutputRuntimeState {
    pub strategy: String,
    pub requested_sample_rate: u32,
    pub actual_sample_rate: u32,
    pub resampler_active: bool,
    pub passthrough_allowed: bool,
    pub verification_reason: Option<String>,
    pub direct_usb_active: bool,
    pub direct_usb_verified: bool,
    pub dsd_source_rate: Option<u32>,
    pub dsd_effective_mode: Option<String>,
    pub dsd_wire_rate: Option<u32>,
    pub dsd_transport: Option<String>,
}

/// Pipeline mode: set once at engine creation time, never toggled at runtime.
///
/// Like USB direct, when the engine runs in Passthrough mode the audio
/// callback skips ALL DSP (EQ, dynamics, speed, crossfade). The only
/// processing applied is gain — which is a no-op when DAC hardware
/// volume is available.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
#[repr(u8)]
pub(crate) enum PipelineMode {
    Passthrough = 0,
    Dsp = 1,
    Dop = 2,
}

/// Audio callback data shared between engine and audio thread.
///
/// This struct contains only lock-free or atomic data to ensure
/// the audio callback never blocks.
pub struct AudioCallbackData {
    /// Volume level (0.0 to 1.0)
    volume: std::sync::atomic::AtomicU32, // Using AtomicU32 for f32 bit pattern
    /// Playback speed (0.5 to 2.0)
    playback_speed: std::sync::atomic::AtomicU32, // Using AtomicU32 for f32 bit pattern
    /// Pause state
    paused: AtomicBool,
    /// Pipeline mode (Passthrough or Dsp) — immutable after creation.
    /// Stored as AtomicU8 for lock-free reads from the audio callback.
    pipeline_mode: AtomicU8,
    /// Base pipeline mode saved before Dop override. Restored when DoP track ends.
    base_pipeline_mode: AtomicU8,
    /// Output channel count
    channels: usize,
    /// Crossfader state
    crossfader: Mutex<Crossfader>,
    /// Source provider (provides samples from current/next track)
    sources: Mutex<SourceProvider>,
    /// Pre-allocated mix buffer for crossfading
    mix_buffer_a: Mutex<Vec<f32>>,
    mix_buffer_b: Mutex<Vec<f32>>,
    /// Pre-allocated speed processing buffer
    speed_buffer: Mutex<Vec<f32>>,
    /// Fractional sample position for speed interpolation
    speed_frac_pos: Mutex<f64>,
    /// Graphic EQ (10 bands). try_lock in callback to avoid blocking.
    equalizer: Mutex<Equalizer>,
    /// Creative spatial/time FX.
    fx: Mutex<SpatialFx>,
    /// Lightweight compressor + limiter chain.
    dynamics: Mutex<DynamicsChain>,
    /// Channel for sending finished tracks to command thread
    finished_tracks: Sender<AudioSource>,
}

impl AudioCallbackData {
    pub(crate) fn new(
        sample_rate: u32,
        channels: usize,
        finished_tracks: Sender<AudioSource>,
        pipeline_mode: PipelineMode,
    ) -> Self {
        // Pre-allocate mix buffers for 1 second of audio — large enough
        // for any platform's output callback (cpal can deliver up to 8k
        // frames; Oboe typically ~1k).
        let buffer_size = sample_rate as usize * channels;
        // Speed buffer needs to be larger to handle 2x speed (need 2x input for 1x output)
        let speed_buffer_size = buffer_size * 3;

        Self {
            volume: std::sync::atomic::AtomicU32::new(1.0f32.to_bits()),
            playback_speed: std::sync::atomic::AtomicU32::new(1.0f32.to_bits()),
            paused: AtomicBool::new(false),
            pipeline_mode: AtomicU8::new(pipeline_mode as u8),
            base_pipeline_mode: AtomicU8::new(pipeline_mode as u8),
            channels,
            crossfader: Mutex::new(Crossfader::disabled(sample_rate)),
            sources: Mutex::new(SourceProvider::new(sample_rate, channels)),
            mix_buffer_a: Mutex::new(vec![0.0; buffer_size]),
            mix_buffer_b: Mutex::new(vec![0.0; buffer_size]),
            speed_buffer: Mutex::new(vec![0.0; speed_buffer_size]),
            speed_frac_pos: Mutex::new(0.0),
            equalizer: Mutex::new(Equalizer::new()),
            fx: Mutex::new(SpatialFx::new(sample_rate)),
            dynamics: Mutex::new(DynamicsChain::new(sample_rate)),
            finished_tracks,
        }
    }

    #[inline]
    pub fn channels(&self) -> usize {
        self.channels
    }

    #[inline]
    pub fn get_volume(&self) -> f32 {
        f32::from_bits(self.volume.load(Ordering::Relaxed))
    }

    /// Perceptual gain from linear slider value (0-1).
    /// Maps to ≈[-60 dB, 0 dB] so 50 % slider sounds like half loudness.
    #[inline]
    pub fn get_gain(&self) -> f32 {
        volume_to_gain(self.get_volume())
    }

    #[inline]
    pub fn set_volume(&self, volume: f32) {
        debug_assert!(
            (0.0..=1.0).contains(&volume) || volume.is_nan(),
            "Volume out of range: {volume}"
        );
        self.volume.store(volume.to_bits(), Ordering::Relaxed);
    }

    #[inline]
    pub fn get_playback_speed(&self) -> f32 {
        f32::from_bits(self.playback_speed.load(Ordering::Relaxed))
    }

    #[inline]
    pub fn set_playback_speed(&self, speed: f32) {
        self.playback_speed
            .store(speed.clamp(0.5, 2.0).to_bits(), Ordering::Relaxed);
    }

    #[inline]
    pub fn is_paused(&self) -> bool {
        self.paused.load(Ordering::Relaxed)
    }

    #[inline]
    pub fn set_paused(&self, paused: bool) {
        self.paused.store(paused, Ordering::Relaxed);
    }

    #[inline]
    pub fn is_passthrough(&self) -> bool {
        self.pipeline_mode.load(Ordering::Relaxed) == PipelineMode::Passthrough as u8
    }

    #[inline]
    pub fn is_dop(&self) -> bool {
        self.pipeline_mode.load(Ordering::Relaxed) == PipelineMode::Dop as u8
    }

    #[inline]
    pub(crate) fn set_pipeline_mode(&self, mode: PipelineMode) {
        self.pipeline_mode.store(mode as u8, Ordering::Relaxed);
    }

    pub fn reconfigure_sample_rate(&self, sample_rate: u32) {
        let buffer_size = (sample_rate as usize / 10) * self.channels;
        let speed_buffer_size = buffer_size * 3;

        *self.crossfader.lock() = Crossfader::disabled(sample_rate);
        *self.sources.lock() = SourceProvider::new(sample_rate, self.channels);
        *self.mix_buffer_a.lock() = vec![0.0; buffer_size];
        *self.mix_buffer_b.lock() = vec![0.0; buffer_size];
        *self.speed_buffer.lock() = vec![0.0; speed_buffer_size];
        *self.speed_frac_pos.lock() = 0.0;
        self.fx.lock().reconfigure_sample_rate(sample_rate);
        *self.dynamics.lock() = DynamicsChain::new(sample_rate);
    }
}

/// Handle for controlling the audio engine from any thread.
///
/// This is the Send + Sync part that can be stored in a static.
pub struct AudioEngineHandle {
    /// Shared callback data
    callback_data: Arc<AudioCallbackData>,
    /// Command sender (to audio thread)
    command_tx: Sender<AudioCommand>,
    /// Event receiver (from audio processing)
    event_rx: Receiver<AudioEvent>,
    /// Current playback state
    state: Arc<AtomicU8>,
    /// Sample rate
    sample_rate: u32,
    /// Number of channels
    channels: usize,
    /// Output/backend signature used to determine when the engine must be recreated.
    output_signature: String,
    /// Runtime output state after strategy selection and verification.
    output_runtime: AudioOutputRuntimeState,
    /// Active decoder threads (kept alive for the duration of playback)
    #[allow(dead_code)]
    decoders: Arc<Mutex<Vec<DecoderHandle>>>,
    /// Shutdown flag
    shutdown: Arc<AtomicBool>,
    /// Audio thread handle, joined on shutdown to ensure the
    /// output stream is released before a new engine opens one.
    _audio_thread: parking_lot::Mutex<Option<std::thread::JoinHandle<()>>>,
}

// AudioEngineHandle is Send + Sync because it only contains Arc, channels, and atomics
unsafe impl Send for AudioEngineHandle {}
unsafe impl Sync for AudioEngineHandle {}

impl AudioEngineHandle {
    /// Send a command to the audio engine.
    pub fn send_command(&self, command: AudioCommand) -> Result<(), String> {
        self.command_tx
            .try_send(command)
            .map_err(|e| format!("Failed to send command: {}", e))
    }

    /// Play a track.
    pub fn play(&self, path: PathBuf) -> Result<(), String> {
        self.send_command(AudioCommand::Play { path })
    }

    /// Play a track using a pre-created source and decoder thread.
    pub fn play_prepared(
        &self,
        source: AudioSource,
        decoder_handle: DecoderHandle,
    ) -> Result<(), String> {
        self.send_command(AudioCommand::PlayPrepared {
            source,
            decoder_handle,
        })
    }

    /// Queue the next track for gapless playback.
    pub fn queue_next(&self, path: PathBuf) -> Result<(), String> {
        self.send_command(AudioCommand::QueueNext { path })
    }

    /// Queue the next track using a pre-created source and decoder handle.
    pub fn queue_next_prepared(
        &self,
        source: AudioSource,
        decoder_handle: DecoderHandle,
    ) -> Result<(), String> {
        self.send_command(AudioCommand::QueueNextPrepared {
            source,
            decoder_handle,
        })
    }

    /// Pause playback.
    pub fn pause(&self) -> Result<(), String> {
        self.send_command(AudioCommand::Pause)
    }

    /// Resume playback.
    pub fn resume(&self) -> Result<(), String> {
        self.send_command(AudioCommand::Resume)
    }

    /// Stop playback.
    pub fn stop(&self) -> Result<(), String> {
        self.send_command(AudioCommand::Stop)
    }

    /// Seek to a position.
    pub fn seek(&self, position_secs: f64) -> Result<(), String> {
        self.send_command(AudioCommand::Seek { position_secs })
    }

    /// Set volume.
    pub fn set_volume(&self, volume: f32) -> Result<(), String> {
        self.send_command(AudioCommand::SetVolume { volume })
    }

    /// Configure crossfade.
    pub fn set_crossfade(&self, enabled: bool, duration_secs: f32) -> Result<(), String> {
        self.send_command(AudioCommand::SetCrossfade {
            enabled,
            duration_secs,
        })
    }

    /// Set the crossfade curve type.
    pub fn set_crossfade_curve(
        &self,
        curve: crate::audio::crossfader::CrossfadeCurve,
    ) -> Result<(), String> {
        self.send_command(AudioCommand::SetCrossfadeCurve { curve })
    }

    /// Check if the engine is currently in passthrough (bit-perfect) mode.
    pub fn is_passthrough(&self) -> bool {
        self.callback_data.is_passthrough()
    }

    /// Check if the engine is currently in DoP (DSD over PCM) mode.
    pub fn is_dop(&self) -> bool {
        self.callback_data.is_dop()
    }

    /// Skip to next track with crossfade.
    pub fn skip_to_next(&self) -> Result<(), String> {
        self.send_command(AudioCommand::SkipToNext)
    }

    /// Set playback speed (0.5 to 2.0).
    pub fn set_playback_speed(&self, speed: f32) -> Result<(), String> {
        self.send_command(AudioCommand::SetPlaybackSpeed { speed })
    }

    /// Switch pipeline mode at runtime (used when Bit-perfect (DAP Internal) is toggled).
    pub fn set_pipeline_mode_passthrough(&self, passthrough: bool) -> Result<(), String> {
        self.send_command(AudioCommand::SetPipelineMode { passthrough })
    }

    pub fn set_dop_override(&self, is_dop: bool) -> Result<(), String> {
        self.send_command(AudioCommand::SetDopOverride { is_dop })
    }

    /// Set graphic EQ: enabled and 10 band gains in dB (order matches EqualizerState.defaultGraphicFrequenciesHz).
    pub fn set_equalizer(&self, enabled: bool, gains_db: [f32; 10]) -> Result<(), String> {
        self.send_command(AudioCommand::SetEqualizer { enabled, gains_db })
    }

    /// Configure compressor settings.
    pub fn set_compressor(
        &self,
        enabled: bool,
        threshold_db: f32,
        ratio: f32,
        attack_ms: f32,
        release_ms: f32,
        makeup_gain_db: f32,
    ) -> Result<(), String> {
        self.send_command(AudioCommand::SetCompressor {
            enabled,
            threshold_db,
            ratio,
            attack_ms,
            release_ms,
            makeup_gain_db,
        })
    }

    /// Configure limiter settings.
    pub fn set_limiter(
        &self,
        enabled: bool,
        input_gain_db: f32,
        ceiling_db: f32,
        release_ms: f32,
    ) -> Result<(), String> {
        self.send_command(AudioCommand::SetLimiter {
            enabled,
            input_gain_db,
            ceiling_db,
            release_ms,
        })
    }

    /// Configure spatial/time FX settings.
    #[allow(clippy::too_many_arguments)]
    pub fn set_fx(
        &self,
        enabled: bool,
        balance: f32,
        tempo: f32,
        damp: f32,
        filter_hz: f32,
        delay_ms: f32,
        size: f32,
        mix: f32,
        feedback: f32,
        width: f32,
    ) -> Result<(), String> {
        self.send_command(AudioCommand::SetFx {
            enabled,
            balance,
            tempo,
            damp,
            filter_hz,
            delay_ms,
            size,
            mix,
            feedback,
            width,
        })
    }

    /// Get the current playback speed.
    pub fn get_playback_speed(&self) -> f32 {
        self.callback_data.get_playback_speed()
    }

    /// Get the current playback state.
    pub fn state(&self) -> PlaybackState {
        match self.state.load(Ordering::Relaxed) {
            0 => PlaybackState::Idle,
            1 => PlaybackState::Playing,
            2 => PlaybackState::Paused,
            3 => PlaybackState::Buffering,
            4 => PlaybackState::Crossfading,
            5 => PlaybackState::Stopped,
            _ => PlaybackState::Idle,
        }
    }

    /// Get current progress.
    pub fn get_progress(&self) -> Option<PlaybackProgress> {
        let sources = self.callback_data.sources.lock();
        sources.current().map(|source| PlaybackProgress {
            position_secs: source.position_secs(),
            duration_secs: Some(source.info.duration_secs),
            buffer_level: source.buffer_level(),
        })
    }

    /// Get the current track path.
    pub fn get_current_path(&self) -> Option<PathBuf> {
        let sources = self.callback_data.sources.lock();
        sources.current().map(|source| source.info.path.clone())
    }

    /// Try to receive an event (non-blocking).
    pub fn try_recv_event(&self) -> Option<AudioEvent> {
        self.event_rx.try_recv().ok()
    }

    /// Get sample rate.
    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    /// Get number of channels.
    pub fn channels(&self) -> usize {
        self.channels
    }

    /// Get the output/backend signature.
    pub fn output_signature(&self) -> &str {
        &self.output_signature
    }

    pub fn output_runtime(&self) -> &AudioOutputRuntimeState {
        &self.output_runtime
    }

    /// Shutdown the engine.
    pub fn shutdown(&self) -> Result<(), String> {
        self.shutdown.store(true, Ordering::Release);
        self.send_command(AudioCommand::Shutdown)
            .inspect_err(|e| {
                log::warn!("Failed to send Shutdown command: {}", e);
            })
            .ok();
        if let Some(handle) = self._audio_thread.lock().take() {
            let _ = handle.join();
        }
        Ok(())
    }
}

#[cfg(not(target_os = "android"))]
fn device_supports_sample_rate(device: &cpal::Device, channels: u16, sample_rate: u32) -> bool {
    let Ok(configs) = device.supported_output_configs() else {
        return false;
    };

    configs.into_iter().any(|config| {
        config.channels() == channels
            && sample_rate >= config.min_sample_rate().0
            && sample_rate <= config.max_sample_rate().0
    })
}

#[cfg(not(target_os = "android"))]
pub fn desired_output_signature(preferred_sample_rate: Option<u32>) -> String {
    format!(
        "native-shared:{}",
        preferred_sample_rate.unwrap_or_default()
    )
}

/// Initialize the audio engine and return a handle.
///
/// The actual cpal stream runs in a dedicated thread.
#[cfg(not(target_os = "android"))]
pub fn create_audio_engine(
    preferred_sample_rate: Option<u32>,
    _allow_dap_native: bool,
    _dap_bit_perfect_enabled: bool,
    _excluded_strategies: Vec<OutputStrategy>,
) -> Result<AudioEngineHandle, String> {
    // Get the default audio device
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("No default output device")?;

    // Get default config
    let default_config = device
        .default_output_config()
        .map_err(|e| format!("Failed to get default config: {}", e))?;

    let sample_rate = default_config.sample_rate().0;
    let channels = default_config.channels() as usize;
    let target_sample_rate = preferred_sample_rate
        .filter(|rate| device_supports_sample_rate(&device, channels as u16, *rate))
        .unwrap_or(sample_rate);

    eprintln!(
        "Audio engine opening output device '{}' at {} Hz (preferred: {:?})",
        device.name().unwrap_or_else(|_| "unknown".to_string()),
        target_sample_rate,
        preferred_sample_rate
    );

    let config = StreamConfig {
        channels: channels as u16,
        sample_rate: SampleRate(target_sample_rate),
        buffer_size: cpal::BufferSize::Default,
    };

    // Create finished tracks channel (from audio callback to command thread)
    let (finished_tx, finished_rx) = bounded::<AudioSource>(32);

    // Create shared data
    let callback_data = Arc::new(AudioCallbackData::new(
        target_sample_rate,
        channels,
        finished_tx,
        PipelineMode::Dsp,
    ));
    let callback_data_clone = Arc::clone(&callback_data);

    // Create event channel
    let (event_tx, event_rx) = bounded::<AudioEvent>(256);
    let event_tx_clone = event_tx.clone();

    // Create command channel
    let (command_tx, command_rx) = bounded::<AudioCommand>(64);

    // State
    let state = Arc::new(AtomicU8::new(PlaybackState::Idle as u8));
    let state_clone = Arc::clone(&state);

    // Decoders
    let decoders = Arc::new(Mutex::new(Vec::<DecoderHandle>::new()));
    let decoders_clone = Arc::clone(&decoders);

    // Shutdown flag
    let shutdown = Arc::new(AtomicBool::new(false));
    let shutdown_clone = Arc::clone(&shutdown);

    // Callback data for command thread
    let callback_data_for_thread = Arc::clone(&callback_data);

    // Spawn the audio thread (which owns the cpal stream)
    let audio_thread = thread::Builder::new()
        .name("audio-engine".to_string())
        .spawn(move || {
            // Build the stream in this thread
            let stream = match device.build_output_stream(
                &config,
                move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                    audio_callback(data, &callback_data_clone, &event_tx_clone);
                },
                |err| {
                    eprintln!("Audio stream error: {}", err);
                },
                None,
            ) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("Failed to build audio stream: {}", e);
                    return;
                }
            };

            // Start the stream
            if let Err(e) = stream.play() {
                eprintln!("Failed to start audio stream: {}", e);
                return;
            }

            // Run command processing loop
            command_processing_loop(
                command_rx,
                finished_rx,
                event_tx,
                callback_data_for_thread,
                state_clone,
                decoders_clone,
                target_sample_rate,
                shutdown_clone,
            );

            // Stream will be dropped here when the loop exits
        });

    let audio_thread = audio_thread
        .map_err(|e| format!("Failed to spawn audio thread: {}", e))?;

    Ok(AudioEngineHandle {
        callback_data,
        command_tx,
        event_rx,
        state,
        sample_rate: target_sample_rate,
        channels,
        output_signature: desired_output_signature(Some(target_sample_rate)),
        output_runtime: AudioOutputRuntimeState {
            strategy: OutputStrategy::MixerMatched.as_str().to_string(),
            requested_sample_rate: target_sample_rate,
            actual_sample_rate: target_sample_rate,
            resampler_active: false,
            passthrough_allowed: false,
            verification_reason: None,
            direct_usb_active: false,
            direct_usb_verified: false,
            dsd_source_rate: None,
            dsd_effective_mode: None,
            dsd_wire_rate: None,
            dsd_transport: None,
        },
        decoders,
        shutdown,
        _audio_thread: parking_lot::Mutex::new(Some(audio_thread)),
    })
}

#[cfg(target_os = "android")]
const ANDROID_DIRECT_CHANNELS: usize = 2;
#[cfg(target_os = "android")]
const ANDROID_DIRECT_SCRATCH_SAMPLES: usize = 32_768;

#[cfg(target_os = "android")]
pub fn desired_output_signature(preferred_sample_rate: Option<u32>) -> String {
    #[cfg(feature = "uac2")]
    if let Some(signature) = android_direct_output_signature(preferred_sample_rate) {
        return signature;
    }

    let dsd_suffix = match crate::api::audio_api::current_dsd_track_rate()
        .and_then(crate::audio::dsd_engine::dsd::DsdRate::from_sample_rate)
    {
        Some(rate) => {
            let mode = crate::api::audio_api::effective_dsd_output_mode(
                crate::api::audio_api::current_dsd_output_mode(),
            );
            match mode {
                crate::audio::dsd_engine::dsd::DsdOutputMode::Native => {
                    format!(":dsd-native:{}", rate.byte_rate())
                }
                crate::audio::dsd_engine::dsd::DsdOutputMode::Dop => {
                    format!(":dsd-dop:{}", rate.dop_carrier_rate())
                }
                _ => String::new(),
            }
        }
        None => String::new(),
    };

    format!(
        "android-shared:requested:{}{}",
        preferred_sample_rate.unwrap_or(48_000),
        dsd_suffix,
    )
}

#[cfg(target_os = "android")]
fn parse_android_output_channels(output_signature: &str) -> Option<usize> {
    let mut parts = output_signature.split(':');
    let backend = parts.next()?;
    if backend != "android-uac2" {
        return None;
    }

    // Signature format: android-uac2:<fd>:<sample_rate>:<bit_depth>:<channels>:<device_name>
    parts.next()?;
    parts.next()?;
    parts.next()?;
    parts.next()?.parse::<usize>().ok()
}

#[cfg(target_os = "android")]
fn android_output_signature_for_strategy(
    strategy: OutputStrategy,
    requested_sample_rate: u32,
) -> String {
    match strategy {
        OutputStrategy::DapNative => {
            format!("android-shared:dap-native:{}", requested_sample_rate)
        }
        OutputStrategy::MixerBitPerfect => {
            format!("android-shared:mixer-bit-perfect:{}", requested_sample_rate)
        }
        OutputStrategy::MixerMatched => {
            format!("android-shared:mixer-matched:{}", requested_sample_rate)
        }
        OutputStrategy::UsbDirect => {
            #[cfg(feature = "uac2")]
            {
                return android_direct_output_signature(Some(requested_sample_rate))
                    .unwrap_or_else(|| {
                        format!("android-uac2:requested:{}", requested_sample_rate)
                    });
            }

            #[cfg(not(feature = "uac2"))]
            {
                format!("android-uac2:requested:{}", requested_sample_rate)
            }
        }
        OutputStrategy::ResampledFallback => {
            format!(
                "android-shared:resampled-fallback:{}",
                requested_sample_rate
            )
        }
        OutputStrategy::DsdNative => {
            format!("android-shared:dsd-native:{}", requested_sample_rate)
        }
        OutputStrategy::DsdDoP => {
            format!("android-shared:dsd-dop:{}", requested_sample_rate)
        }
        OutputStrategy::UsbDsdNative => {
            format!("android-shared:usb-dsd-native:{}", requested_sample_rate)
        }
    }
}

#[cfg(target_os = "android")]
fn build_output_runtime_state(
    strategy: OutputStrategy,
    verification: OutputVerification,
    direct_usb_active: bool,
    direct_usb_verified: bool,
) -> AudioOutputRuntimeState {
    let dsd_source_rate = crate::api::audio_api::current_dsd_track_rate();
    let dsd_effective_mode = dsd_source_rate.map(|_| {
        let mode = crate::api::audio_api::effective_dsd_output_mode(
            crate::api::audio_api::current_dsd_output_mode(),
        );
        match mode {
            crate::audio::dsd_engine::dsd::DsdOutputMode::PcmDecimation => "pcm".to_string(),
            crate::audio::dsd_engine::dsd::DsdOutputMode::Dop => "dop".to_string(),
            crate::audio::dsd_engine::dsd::DsdOutputMode::Native => "native".to_string(),
            crate::audio::dsd_engine::dsd::DsdOutputMode::Auto => "auto".to_string(),
        }
    });
    let (dsd_wire_rate, dsd_transport) = if dsd_source_rate.is_some() {
        let wire_rate = verification.actual_rate;
        let transport = match strategy {
            OutputStrategy::DsdNative => "dap-native-encoding".to_string(),
            OutputStrategy::UsbDsdNative => {
                #[cfg(feature = "uac2")]
                {
                    let debug = crate::uac2::android_direct_debug_state();
                    let subslot = debug.transport_subslot_size.unwrap_or(4);
                    format!(
                        "usb-native-dsd-u{}x{}-bit",
                        subslot, subslot * 8
                    )
                }
                #[cfg(not(feature = "uac2"))]
                "usb-native-dsd".to_string()
            }
            OutputStrategy::DsdDoP => {
                if direct_usb_active {
                    #[cfg(feature = "uac2")]
                    {
                        let debug = crate::uac2::android_direct_debug_state();
                        let bits = debug.transport_bit_resolution.unwrap_or(24);
                        format!("usb-dop-{}-bit", bits)
                    }
                    #[cfg(not(feature = "uac2"))]
                    "usb-dop".to_string()
                } else {
                    "dap-dop".to_string()
                }
            }
            OutputStrategy::UsbDirect => "usb-pcm".to_string(),
            _ => "pcm".to_string(),
        };
        (Some(wire_rate), Some(transport))
    } else {
        (None, None)
    };
    AudioOutputRuntimeState {
        strategy: verification
            .resolved_strategy(strategy)
            .as_str()
            .to_string(),
        requested_sample_rate: verification.requested_rate,
        actual_sample_rate: verification.actual_rate,
        resampler_active: verification.resampler_active,
        passthrough_allowed: verification.bit_perfect,
        verification_reason: verification.reason,
        direct_usb_active,
        direct_usb_verified,
        dsd_source_rate,
        dsd_effective_mode,
        dsd_wire_rate,
        dsd_transport,
    }
}

#[cfg(target_os = "android")]
enum AndroidManagedStreamKind {
    F32(AudioStreamAsync<Output, AndroidOutputCallbackF32>),
    I32(AudioStreamAsync<Output, AndroidOutputCallbackI32>),
}

#[cfg(target_os = "android")]
struct AndroidManagedStream {
    kind: AndroidManagedStreamKind,
    actual_sample_rate: u32,
}

#[cfg(target_os = "android")]
impl AndroidManagedStream {
    fn start(&mut self) -> Result<(), oboe::Error> {
        match &mut self.kind {
            AndroidManagedStreamKind::F32(s) => s.start(),
            AndroidManagedStreamKind::I32(s) => s.start(),
        }
    }

    fn stop(&mut self) -> Result<(), oboe::Error> {
        match &mut self.kind {
            AndroidManagedStreamKind::F32(s) => s.stop(),
            AndroidManagedStreamKind::I32(s) => s.stop(),
        }
    }
}

#[cfg(target_os = "android")]
pub fn create_audio_engine(
    preferred_sample_rate: Option<u32>,
    allow_dap_native: bool,
    dap_bit_perfect_enabled: bool,
    excluded_strategies: Vec<OutputStrategy>,
) -> Result<AudioEngineHandle, String> {
    let device_profile = current_device_profile();

    #[cfg(feature = "uac2")]
    let debug_state = android_direct_debug_state();
    #[cfg(feature = "uac2")]
    let will_attempt_usb = debug_state.registered;
    #[cfg(not(feature = "uac2"))]
    let will_attempt_usb = false;

    // When a DAP device has bit-perfect disabled, force the output to
    // 48 kHz so that all DSP runs at a fixed rate. USB DACs are excluded
    // because they use their own direct path. DSD playback needs its
    // native PCM target rate (e.g., 176.4 kHz); honour explicit requests
    // above 48 kHz to avoid a rate mismatch with the DSD decoder.
    let dap_force_dsp = !dap_bit_perfect_enabled
        && device_profile.as_ref().is_some_and(|p| p.is_dap())
        && !will_attempt_usb;
    let mut requested_sample_rate = if dap_force_dsp {
        if let Some(rate) = preferred_sample_rate {
            if rate > 48_000 { rate } else { 48_000 }
        } else {
            48_000
        }
    } else {
        preferred_sample_rate.unwrap_or(48_000)
    };

    #[cfg(feature = "uac2")]
    if will_attempt_usb {
        validate_android_direct_request(Some(requested_sample_rate))?;
    }

    let selected_output_device = select_android_output_device(requested_sample_rate)
        .or_else(|_| {
            // DSD Native and DoP bypass the Oboe stream entirely, so if
            // the byte/carrier rate isn't supported by any PCM device,
            // try a standard rate just to confirm a wired output exists.
            select_android_output_device(48_000)
        })
        .ok();
    let shared_supports_requested_rate = selected_output_device
        .as_ref()
        .map(|device| android_device_supports_sample_rate(device, requested_sample_rate))
        .unwrap_or(false);
    let confirmed_dap_native = allow_dap_native
        && dap_bit_perfect_enabled
        && selected_output_device.as_ref().is_some_and(|device| {
            device_profile.as_ref().is_some_and(|profile| {
                profile.confirmed_bit_perfect
                    && android_device_supports_dap_native_strategy(device.device_type)
            })
        });

    let dsd_rate = crate::api::audio_api::current_dsd_track_rate()
        .and_then(crate::audio::dsd_engine::dsd::DsdRate::from_sample_rate)
        .or_else(|| crate::audio::dsd_engine::dsd::DsdRate::from_sample_rate(requested_sample_rate));
    let supports_native_dsd = device_profile
        .as_ref()
        .is_some_and(|p| p.supports_native_dsd);

    let desired_strategy = if will_attempt_usb {
        let track_info = if let Some(rate) = dsd_rate {
            TrackInfo::dsd(rate.sample_rate(), ANDROID_DIRECT_CHANNELS)
        } else {
            TrackInfo::pcm(requested_sample_rate, ANDROID_DIRECT_CHANNELS)
        };
        #[cfg(feature = "uac2")]
        let usb_dsd_native_available = {
            let debug = android_direct_debug_state();
            debug.available_alt_settings.iter().any(|alt| {
                alt.format_tag == "DSD"
                    && alt.subslot_size > 0
                    && dsd_rate.is_some_and(|r| {
                        r.sample_rate() / (8 * u32::from(alt.subslot_size)) <= alt.sample_rates.iter().copied().max().unwrap_or(0)
                            || alt.sample_rates.iter().any(|&sr| {
                                sr == r.sample_rate() / (8 * u32::from(alt.subslot_size))
                            })
                    })
            })
        };
        #[cfg(not(feature = "uac2"))]
        let usb_dsd_native_available = false;

        #[cfg(feature = "uac2")]
        let (usb_dop_available, usb_max_carrier) = {
            let debug = android_direct_debug_state();
            let carrier = dsd_rate.map(|r| r.dop_carrier_rate()).unwrap_or(0);
            let has_pcm_24bit = debug.available_alt_settings.iter().any(|alt| {
                alt.format_tag == "PCM"
                    && alt.bit_resolution >= 24
                    && alt.sample_rates.iter().any(|&sr| sr == carrier)
            });
            (has_pcm_24bit, if has_pcm_24bit { carrier } else { 0 })
        };
        #[cfg(not(feature = "uac2"))]
        let (usb_dop_available, usb_max_carrier) = (false, 0u32);

        select_strategy_excluded(
            &track_info,
            &DeviceCaps {
                api_level: None,
                confirmed_dap_native,
                direct_usb_available: true,
                direct_usb_verified: true,
                usb_supports_native_dsd: usb_dsd_native_available,
                supports_dop: usb_dop_available,
                max_dsd_carrier_rate: usb_max_carrier,
                ..DeviceCaps::default()
            },
            &excluded_strategies,
        )
    } else {
        let track_info = if let Some(rate) = dsd_rate {
            TrackInfo::dsd(rate.sample_rate(), ANDROID_DIRECT_CHANNELS)
        } else {
            TrackInfo::pcm(requested_sample_rate, ANDROID_DIRECT_CHANNELS)
        };
        select_strategy_excluded(
            &track_info,
            &DeviceCaps {
                api_level: None,
                confirmed_dap_native,
                supports_requested_rate: shared_supports_requested_rate,
                supports_native_dsd,
                supports_dop: supports_native_dsd,
                max_dsd_carrier_rate: if supports_native_dsd { 705_600 } else { 0 },
                ..DeviceCaps::default()
            },
            &excluded_strategies,
        )
    };

    // Override the sample rate for DSD strategies: the DSD Native
    // backend needs the byte rate (e.g. 705 600 Hz for DSD128),
    // DSD DoP needs the carrier rate (e.g. 352 800 Hz for DSD128),
    // and USB DSD Native needs the wire rate (e.g. 88 200 Hz for DSD64).
    match desired_strategy {
        OutputStrategy::DsdNative => {
            if let Some(rate) = dsd_rate {
                let byte_rate = rate.byte_rate();
                log::info!(
                    "[ENGINE] {:?}: overriding rate {} -> {} Hz (byte_rate)",
                    desired_strategy,
                    requested_sample_rate,
                    byte_rate,
                );
                requested_sample_rate = byte_rate;
            }
        }
        OutputStrategy::UsbDsdNative => {
            if let Some(rate) = dsd_rate {
                let wire_rate = rate.sample_rate() / 32; // DSD_U32 wire rate
                log::info!(
                    "[ENGINE] {:?}: overriding rate {} -> {} Hz (wire_rate, DSD_U32)",
                    desired_strategy,
                    requested_sample_rate,
                    wire_rate,
                );
                requested_sample_rate = wire_rate;
            }
        }
        OutputStrategy::DsdDoP => {
            if let Some(rate) = dsd_rate {
                let carrier = rate.dop_carrier_rate();
                log::info!(
                    "[ENGINE] DSD DoP: overriding rate {} -> {} Hz (carrier_rate)",
                    requested_sample_rate,
                    carrier,
                );
                requested_sample_rate = carrier;
            }
        }
        _ => {}
    }

    #[cfg(feature = "uac2")]
    let channels = {
        eprintln!(
            "create_audio_engine: requested_rate={} Hz, strategy={:?}, debug_state: registered={}, effective_rate={:?}, requested_rate={:?}, effective_ch={:?}, requested_ch={:?}",
            requested_sample_rate,
            desired_strategy,
            debug_state.registered,
            debug_state.playback_format_sample_rate,
            debug_state.requested_playback_sample_rate,
            debug_state.playback_format_channels,
            debug_state.requested_playback_channels,
        );

        if !will_attempt_usb {
            ANDROID_DIRECT_CHANNELS
        } else {
            let effective_matches =
                debug_state.playback_format_sample_rate == Some(requested_sample_rate);
            let requested_matches =
                debug_state.requested_playback_sample_rate == Some(requested_sample_rate);

            let channels = if effective_matches {
                debug_state
                    .playback_format_channels
                    .map(|c| c as usize)
                    .unwrap_or(ANDROID_DIRECT_CHANNELS)
            } else if requested_matches {
                debug_state
                    .requested_playback_channels
                    .map(|c| c as usize)
                    .unwrap_or(ANDROID_DIRECT_CHANNELS)
            } else {
                ANDROID_DIRECT_CHANNELS
            };

            eprintln!(
                "create_audio_engine: DAC registered, will attempt USB backend with {} channels (format_matches: effective={}, requested={})",
                channels, effective_matches, requested_matches
            );
            channels
        }
    };

    #[cfg(not(feature = "uac2"))]
    let channels = ANDROID_DIRECT_CHANNELS;

    // Create finished tracks channel (from audio callback to command thread)
    let (finished_tx, finished_rx) = bounded::<AudioSource>(32);

    // Create shared data before the output path is opened. If the platform
    // changes the actual stream rate, we reconfigure the processing state
    // before any playback commands are accepted.
    //
    // Pipeline mode is determined by desired strategy:
    // - UsbDirect / DapNative → Passthrough (verified below; downgraded on failure)
    // - All other strategies   → Dsp (full processing chain)
    let initial_pipeline_mode = match desired_strategy {
        OutputStrategy::UsbDirect | OutputStrategy::DapNative | OutputStrategy::DsdNative | OutputStrategy::UsbDsdNative => {
            PipelineMode::Passthrough
        }
        _ => PipelineMode::Dsp,
    };
    let callback_data = Arc::new(AudioCallbackData::new(
        requested_sample_rate,
        channels,
        finished_tx,
        initial_pipeline_mode,
    ));
    let callback_data_clone = Arc::clone(&callback_data);

    // Create event channel
    let (event_tx, event_rx) = bounded::<AudioEvent>(256);
    let event_tx_clone = event_tx.clone();

    // Create command channel
    let (command_tx, command_rx) = bounded::<AudioCommand>(64);

    // State
    let state = Arc::new(AtomicU8::new(PlaybackState::Idle as u8));
    let state_clone = Arc::clone(&state);

    // Decoders
    let decoders = Arc::new(Mutex::new(Vec::<DecoderHandle>::new()));
    let decoders_clone = Arc::clone(&decoders);

    // Shutdown flag
    let shutdown = Arc::new(AtomicBool::new(false));
    let shutdown_clone = Arc::clone(&shutdown);

    // Callback data for command thread
    let callback_data_for_thread = Arc::clone(&callback_data);

    #[cfg(feature = "uac2")]
    let mut direct_usb_backend = None;

    let mut dsd_native_backend = None;

    let mut final_sample_rate = requested_sample_rate;
    let mut output_runtime = build_output_runtime_state(
        desired_strategy,
        OutputVerification::verify(requested_sample_rate, requested_sample_rate, false, true),
        false,
        false,
    );
    let mut output_signature =
        android_output_signature_for_strategy(desired_strategy, requested_sample_rate);

    #[cfg(feature = "uac2")]
    if desired_strategy == OutputStrategy::UsbDirect
        || desired_strategy == OutputStrategy::UsbDsdNative
        || desired_strategy == OutputStrategy::DsdDoP
    {
        if desired_strategy == OutputStrategy::UsbDsdNative {
            if let Some(rate) = dsd_rate {
                let _ = crate::uac2::set_android_usb_dsd_native_mode(rate.sample_rate());
            }
        } else if desired_strategy == OutputStrategy::DsdDoP {
            if let Some(rate) = dsd_rate {
                let carrier = rate.dop_carrier_rate();
                let _ = crate::uac2::set_android_usb_dop_mode(true, carrier, 24);
            }
        }
        match create_android_usb_backend(
            Arc::clone(&callback_data_clone),
            event_tx_clone.clone(),
            requested_sample_rate,
        ) {
            Ok(Some(mut backend)) => {
                let debug_state = android_direct_debug_state();
                let actual_sample_rate = debug_state
                    .clock_reported_sample_rate
                    .or(debug_state.playback_format_sample_rate)
                    .or(debug_state.requested_playback_sample_rate)
                    .unwrap_or(requested_sample_rate);
                let verification = OutputVerification::verify(
                    requested_sample_rate,
                    actual_sample_rate,
                    true,
                    debug_state.clock_verification_passed,
                );

                if verification.bit_perfect {
                    final_sample_rate = actual_sample_rate;
                    callback_data.reconfigure_sample_rate(final_sample_rate);
                    if desired_strategy == OutputStrategy::UsbDsdNative
                        || desired_strategy == OutputStrategy::DsdDoP
                    {
                        callback_data.set_pipeline_mode(PipelineMode::Dop);
                    } else {
                        callback_data.set_pipeline_mode(PipelineMode::Passthrough);
                    }
                    output_runtime = build_output_runtime_state(
                        desired_strategy,
                        verification,
                        true,
                        debug_state.clock_verification_passed,
                    );
                    output_signature = android_output_signature_for_strategy(
                        desired_strategy,
                        requested_sample_rate,
                    );
                    direct_usb_backend = Some(backend);
                } else {
                    let reason = verification
                        .reason
                        .clone()
                        .unwrap_or_else(|| "USB direct verification failed".to_string());
                    log::warn!(
                        "[ENGINE] USB direct rejected after verification: {}. Falling back to Android-managed output.",
                        reason
                    );
                    let _ = backend.stop();
                    crate::uac2::force_release_usb_session();
                    output_runtime = build_output_runtime_state(
                        desired_strategy,
                        verification,
                        false,
                        debug_state.clock_verification_passed,
                    );
                    output_signature = android_output_signature_for_strategy(
                        OutputStrategy::ResampledFallback,
                        requested_sample_rate,
                    );
                }
            }
            Ok(None) => {
                log::warn!(
                    "[ENGINE] Android direct USB was selected for {} Hz but no backend was created; falling back to Android-managed output",
                    requested_sample_rate
                );
                output_runtime.verification_reason = Some(
                    "USB direct backend was unavailable; Android-managed fallback active"
                        .to_string(),
                );
                output_runtime.strategy = OutputStrategy::ResampledFallback.as_str().to_string();
                output_signature = android_output_signature_for_strategy(
                    OutputStrategy::ResampledFallback,
                    requested_sample_rate,
                );
            }
            Err(error) => {
                log::warn!(
                    "[ENGINE] Android direct USB init failed: {}. Falling back to Android-managed output.",
                    error
                );
                output_runtime.verification_reason = Some(error);
                output_runtime.strategy = OutputStrategy::ResampledFallback.as_str().to_string();
                output_signature = android_output_signature_for_strategy(
                    OutputStrategy::ResampledFallback,
                    requested_sample_rate,
                );
            }
        }
    }

    // DSD Native AudioTrack: for DAPs with ENCODING_DSD support, bypass Oboe
    // entirely and use a dedicated AudioTrack with ENCODING_DSD encoding.
    #[cfg(target_os = "android")]
    if desired_strategy == OutputStrategy::DsdNative && direct_usb_backend.is_none() {
        if supports_native_dsd {
            match crate::audio::dsd_native_backend::DsdNativeBackend::start(
                Arc::clone(&callback_data_clone),
                event_tx_clone.clone(),
                requested_sample_rate,
                channels,
            ) {
                Ok(backend) => {
                    log::info!(
                        "[ENGINE] DSD Native AudioTrack backend created at {} Hz",
                        requested_sample_rate
                    );
                    final_sample_rate = requested_sample_rate;
                    callback_data.reconfigure_sample_rate(final_sample_rate);
                    callback_data.set_pipeline_mode(PipelineMode::Dop);
                    output_runtime = build_output_runtime_state(
                        OutputStrategy::DsdNative,
                        OutputVerification::verify(requested_sample_rate, requested_sample_rate, true, true),
                        false,
                        false,
                    );
                    output_signature = android_output_signature_for_strategy(
                        OutputStrategy::DsdNative,
                        requested_sample_rate,
                    );
                    dsd_native_backend = Some(backend);
                }
                Err(error) => {
                    log::warn!(
                        "[ENGINE] DSD Native AudioTrack init failed: {}. Will fall back to DoP/PCM.",
                        error
                    );
                    return Err(format!("DSD_NATIVE_FALLBACK:{}", error));
                }
            }
        } else {
            log::warn!(
                "[ENGINE] DSD Native strategy selected but device does not support ENCODING_DSD"
            );
            return Err("DSD_NATIVE_FALLBACK:Device does not support ENCODING_DSD".to_string());
        }
    }

    let mut managed_stream = None;
    #[cfg(feature = "uac2")]
    let use_managed_fallback = direct_usb_backend.is_none() && dsd_native_backend.is_none();
    #[cfg(not(feature = "uac2"))]
    let use_managed_fallback = dsd_native_backend.is_none();

    if use_managed_fallback {
        let desired_shared_strategy = if desired_strategy == OutputStrategy::UsbDirect
            || desired_strategy == OutputStrategy::UsbDsdNative
        {
            OutputStrategy::ResampledFallback
        } else {
            desired_strategy
        };
        let prefer_exclusive = dap_bit_perfect_enabled
            && device_profile.as_ref().is_some_and(|p| p.is_dap())
            && !will_attempt_usb;
        let is_dsd_dop = dsd_rate.is_some() && matches!(
            desired_shared_strategy,
            OutputStrategy::DsdDoP
        );
        let use_integer = is_dsd_dop || desired_shared_strategy.is_dsd();
        let managed = open_android_output_stream(
            Arc::clone(&callback_data_clone),
            event_tx_clone.clone(),
            requested_sample_rate,
            prefer_exclusive,
            use_integer,
        )?;
        let verification = OutputVerification::verify(
            requested_sample_rate,
            managed.actual_sample_rate,
            desired_shared_strategy.requests_passthrough(),
            true,
        );
        let resolved_shared_strategy = verification.resolved_strategy(desired_shared_strategy);
        final_sample_rate = managed.actual_sample_rate;
        callback_data.reconfigure_sample_rate(final_sample_rate);
        if verification.bit_perfect && !dap_force_dsp {
            callback_data.set_pipeline_mode(PipelineMode::Passthrough);
        } else {
            callback_data.set_pipeline_mode(PipelineMode::Dsp);
        }
        if is_dsd_dop {
            callback_data.set_pipeline_mode(PipelineMode::Dop);
        }
        output_runtime =
            build_output_runtime_state(desired_shared_strategy, verification, false, false);
        output_signature =
            android_output_signature_for_strategy(resolved_shared_strategy, requested_sample_rate);
        managed_stream = Some(managed);
    }

    log::info!(
        "[ENGINE] requested_rate_hz={} actual_rate_hz={} strategy={} resampler_active={} passthrough_allowed={} channels={} dap_profile={:?}",
        requested_sample_rate,
        final_sample_rate,
        output_runtime.strategy,
        output_runtime.resampler_active,
        output_runtime.passthrough_allowed,
        channels,
        device_profile.as_ref().map(|profile| &profile.kind)
    );

    // Spawn the audio thread (which owns the Oboe stream)
    let audio_thread = thread::Builder::new()
        .name("audio-engine".to_string())
        .spawn(move || {
            #[cfg(feature = "uac2")]
            let mut direct_usb_backend = direct_usb_backend;
            let mut dsd_native_backend = dsd_native_backend;
            let mut managed_stream = managed_stream;

            #[cfg(feature = "uac2")]
            if direct_usb_backend.is_some() {
                command_processing_loop(
                    command_rx,
                    finished_rx,
                    event_tx,
                    callback_data_for_thread,
                    state_clone,
                    decoders_clone,
                    final_sample_rate,
                    shutdown_clone,
                );

                if let Some(mut backend) = direct_usb_backend.take() {
                    let _ = backend.stop();
                }
                return;
            }

            #[cfg(target_os = "android")]
            if dsd_native_backend.is_some() {
                command_processing_loop(
                    command_rx,
                    finished_rx,
                    event_tx,
                    callback_data_for_thread,
                    state_clone,
                    decoders_clone,
                    final_sample_rate,
                    shutdown_clone,
                );

                if let Some(mut backend) = dsd_native_backend.take() {
                    backend.stop();
                }
                return;
            }
            #[cfg(not(target_os = "android"))]
            let _ = dsd_native_backend;

            let mut stream = match managed_stream.take() {
                Some(stream) => stream,
                None => {
                    let _ = event_tx.try_send(AudioEvent::Error {
                        message: "No Android managed output stream was prepared".to_string(),
                    });
                    return;
                }
            };

            if let Err(error) = stream.start() {
                eprintln!("Failed to start Android managed output stream: {}", error);
                let _ = event_tx.try_send(AudioEvent::Error {
                    message: format!("Failed to start Android managed output stream: {}", error),
                });
                return;
            }

            command_processing_loop(
                command_rx,
                finished_rx,
                event_tx,
                callback_data_for_thread,
                state_clone,
                decoders_clone,
                final_sample_rate,
                shutdown_clone,
            );

            if let Err(error) = stream.stop() {
                eprintln!("Failed to stop Android direct output stream: {}", error);
            }
        });

    let audio_thread = audio_thread
        .map_err(|e| format!("Failed to spawn audio thread: {}", e))?;

    Ok(AudioEngineHandle {
        callback_data,
        command_tx,
        event_rx,
        state,
        sample_rate: final_sample_rate,
        channels,
        output_signature,
        output_runtime,
        decoders,
        shutdown,
        _audio_thread: parking_lot::Mutex::new(Some(audio_thread)),
    })
}

#[cfg(target_os = "android")]
struct AndroidOutputCallbackF32 {
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    scratch: Vec<f32>,
}

#[cfg(target_os = "android")]
impl AndroidOutputCallbackF32 {
    fn new(callback_data: Arc<AudioCallbackData>, event_tx: Sender<AudioEvent>) -> Self {
        Self {
            callback_data,
            event_tx,
            scratch: vec![0.0; ANDROID_DIRECT_SCRATCH_SAMPLES],
        }
    }
}

#[cfg(target_os = "android")]
impl AudioOutputCallback for AndroidOutputCallbackF32 {
    type FrameType = (f32, Stereo);

    fn on_error_before_close(
        &mut self,
        audio_stream: &mut dyn AudioOutputStreamSafe,
        error: oboe::Error,
    ) {
        eprintln!(
            "Android managed output error before close: {:?} (device_id={}, sample_rate={} Hz, sharing={:?}, api={:?})",
            error,
            audio_stream.get_device_id(),
            audio_stream.get_sample_rate(),
            audio_stream.get_sharing_mode(),
            audio_stream.get_audio_api(),
        );
    }

    fn on_error_after_close(
        &mut self,
        audio_stream: &mut dyn AudioOutputStreamSafe,
        error: oboe::Error,
    ) {
        eprintln!(
            "Android managed output error after close: {:?} (device_id={}, sample_rate={} Hz, sharing={:?}, api={:?})",
            error,
            audio_stream.get_device_id(),
            audio_stream.get_sample_rate(),
            audio_stream.get_sharing_mode(),
            audio_stream.get_audio_api(),
        );
    }

    fn on_audio_ready(
        &mut self,
        _audio_stream: &mut dyn AudioOutputStreamSafe,
        audio_data: &mut [(f32, f32)],
    ) -> DataCallbackResult {
        let required_samples = audio_data.len() * ANDROID_DIRECT_CHANNELS;

        if required_samples > self.scratch.len() {
            eprintln!(
                "[oboe] burst {} frames > scratch {} frames — growing scratch",
                audio_data.len(),
                self.scratch.len() / ANDROID_DIRECT_CHANNELS,
            );
            self.scratch.resize(required_samples, 0.0);
        }

        let scratch = &mut self.scratch[..required_samples];
        audio_callback(scratch, &self.callback_data, &self.event_tx);

        for (frame_index, frame) in audio_data.iter_mut().enumerate() {
            let sample_index = frame_index * ANDROID_DIRECT_CHANNELS;
            *frame = (scratch[sample_index], scratch[sample_index + 1]);
        }

        DataCallbackResult::Continue
    }
}

/// Integer callback for DoP / native DSD transport over AAudio I32.
/// Reads f32 samples from the decoder pipeline, extracts the raw bit
/// patterns (which carry DoP markers / DSD bytes), and writes them as
/// i32 to the AAudio HAL. No gain, format conversion, or DSP is applied.
#[cfg(target_os = "android")]
struct AndroidOutputCallbackI32 {
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    scratch: Vec<f32>,
}

#[cfg(target_os = "android")]
impl AndroidOutputCallbackI32 {
    fn new(callback_data: Arc<AudioCallbackData>, event_tx: Sender<AudioEvent>) -> Self {
        Self {
            callback_data,
            event_tx,
            scratch: vec![0.0; ANDROID_DIRECT_SCRATCH_SAMPLES],
        }
    }
}

#[cfg(target_os = "android")]
impl AudioOutputCallback for AndroidOutputCallbackI32 {
    type FrameType = (i32, Stereo);

    fn on_error_before_close(
        &mut self,
        audio_stream: &mut dyn AudioOutputStreamSafe,
        error: oboe::Error,
    ) {
        eprintln!(
            "Android managed i32 output error before close: {:?} (device_id={}, sample_rate={} Hz, sharing={:?}, api={:?})",
            error,
            audio_stream.get_device_id(),
            audio_stream.get_sample_rate(),
            audio_stream.get_sharing_mode(),
            audio_stream.get_audio_api(),
        );
    }

    fn on_error_after_close(
        &mut self,
        audio_stream: &mut dyn AudioOutputStreamSafe,
        error: oboe::Error,
    ) {
        eprintln!(
            "Android managed i32 output error after close: {:?} (device_id={}, sample_rate={} Hz, sharing={:?}, api={:?})",
            error,
            audio_stream.get_device_id(),
            audio_stream.get_sample_rate(),
            audio_stream.get_sharing_mode(),
            audio_stream.get_audio_api(),
        );
    }

    fn on_audio_ready(
        &mut self,
        _audio_stream: &mut dyn AudioOutputStreamSafe,
        audio_data: &mut [(i32, i32)],
    ) -> DataCallbackResult {
        let required_samples = audio_data.len() * ANDROID_DIRECT_CHANNELS;

        if required_samples > self.scratch.len() {
            eprintln!(
                "[oboe-i32] burst {} frames > scratch {} frames — growing scratch",
                audio_data.len(),
                self.scratch.len() / ANDROID_DIRECT_CHANNELS,
            );
            self.scratch.resize(required_samples, 0.0);
        }

        let scratch = &mut self.scratch[..required_samples];
        audio_callback(scratch, &self.callback_data, &self.event_tx);

        for (frame_index, frame) in audio_data.iter_mut().enumerate() {
            let sample_index = frame_index * ANDROID_DIRECT_CHANNELS;
            let l = scratch[sample_index].to_bits() as i32;
            let r = scratch[sample_index + 1].to_bits() as i32;
            *frame = (l, r);
        }

        DataCallbackResult::Continue
    }
}

#[cfg(target_os = "android")]
fn open_android_output_stream(
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    target_sample_rate: u32,
    prefer_exclusive: bool,
    use_integer_format: bool,
) -> Result<AndroidManagedStream, String> {
    let selected_device = select_android_output_device(target_sample_rate)?;
    let is_bluetooth = matches!(
        selected_device.device_type,
        AudioDeviceType::BluetoothA2DP
            | AudioDeviceType::BluetoothSCO
            | AudioDeviceType::BleBroadcast
            | AudioDeviceType::BleHeadset
            | AudioDeviceType::BleSpeaker
            | AudioDeviceType::HearingAid
    );
    let bit_perfect_route = prefer_exclusive && !is_bluetooth;
    let frames_per_callback = if is_bluetooth {
        0
    } else {
        android_frames_per_callback(target_sample_rate)
    };
    let sharing_modes: &[SharingMode] = if prefer_exclusive && !is_bluetooth {
        &[SharingMode::Exclusive, SharingMode::Shared]
    } else {
        &[SharingMode::Shared]
    };
    let attempts: &[AudioApi] = if is_bluetooth {
        &[AudioApi::Unspecified]
    } else {
        &[AudioApi::AAudio, AudioApi::Unspecified]
    };
    let performance_mode = if is_bluetooth {
        PerformanceMode::None
    } else {
        PerformanceMode::LowLatency
    };

    let mut last_error = None;
    let mut fallback_kind = None;
    let mut fallback_rate = 0u32;

    for &sharing_mode in sharing_modes {
        for &audio_api in attempts {
            let result: Result<AndroidManagedStreamKind, String> = if use_integer_format {
                let builder = oboe::AudioStreamBuilder::default()
                    .set_stereo()
                    .set_format::<i32>()
                    .set_sample_rate(target_sample_rate as i32)
                    .set_frames_per_callback(frames_per_callback)
                    .set_sharing_mode(sharing_mode)
                    .set_performance_mode(performance_mode)
                    .set_usage(Usage::Media)
                    .set_content_type(ContentType::Music)
                    .set_channel_conversion_allowed(false)
                    .set_format_conversion_allowed(false)
                    .set_sample_rate_conversion_quality(SampleRateConversionQuality::None)
                    .set_audio_api(audio_api);

                let builder = if bit_perfect_route {
                    builder.set_device_id(selected_device.id)
                } else {
                    builder
                };

                match builder
                    .set_callback(AndroidOutputCallbackI32::new(
                        Arc::clone(&callback_data),
                        event_tx.clone(),
                    ))
                    .open_stream()
                {
                    Ok(stream) => Ok(AndroidManagedStreamKind::I32(stream)),
                    Err(error) => Err(format!(
                        "{} {} open failed on '{}' (id {}, type {:?}): {}",
                        audio_api_label(audio_api),
                        sharing_label(sharing_mode),
                        selected_device.product_name,
                        selected_device.id,
                        selected_device.device_type,
                        error
                    )),
                }
            } else {
                let mut builder = oboe::AudioStreamBuilder::default()
                    .set_stereo()
                    .set_f32()
                    .set_sample_rate(target_sample_rate as i32)
                    .set_frames_per_callback(frames_per_callback)
                    .set_sharing_mode(sharing_mode)
                    .set_performance_mode(performance_mode)
                    .set_usage(Usage::Media)
                    .set_content_type(ContentType::Music)
                    .set_channel_conversion_allowed(!bit_perfect_route)
                    .set_format_conversion_allowed(!bit_perfect_route)
                    .set_sample_rate_conversion_quality(
                        if bit_perfect_route {
                            SampleRateConversionQuality::None
                        } else {
                            SampleRateConversionQuality::Medium
                        }
                    )
                    .set_audio_api(audio_api);

                if bit_perfect_route {
                    builder = builder.set_device_id(selected_device.id);
                }

                match builder
                    .set_callback(AndroidOutputCallbackF32::new(
                        Arc::clone(&callback_data),
                        event_tx.clone(),
                    ))
                    .open_stream()
                {
                    Ok(stream) => Ok(AndroidManagedStreamKind::F32(stream)),
                    Err(error) => Err(format!(
                        "{} {} open failed on '{}' (id {}, type {:?}): {}",
                        audio_api_label(audio_api),
                        sharing_label(sharing_mode),
                        selected_device.product_name,
                        selected_device.id,
                        selected_device.device_type,
                        error
                    )),
                }
            };

            match result {
                Ok(kind) => {
                    let (actual_rate, actual_api, actual_sharing, actual_format, actual_channels) =
                        match &kind {
                            AndroidManagedStreamKind::F32(s) => (
                                s.get_sample_rate(),
                                s.get_audio_api(),
                                s.get_sharing_mode(),
                                s.get_format(),
                                s.get_channel_count(),
                            ),
                            AndroidManagedStreamKind::I32(s) => (
                                s.get_sample_rate(),
                                s.get_audio_api(),
                                s.get_sharing_mode(),
                                s.get_format(),
                                s.get_channel_count(),
                            ),
                        };

                    eprintln!(
                        "Android managed output opened '{}' (id {}, type {:?}) requested {} Hz -> actual {} Hz, api {:?}, sharing {:?}, format {:?}, channels {:?}",
                        selected_device.product_name,
                        selected_device.id,
                        selected_device.device_type,
                        target_sample_rate,
                        actual_rate,
                        actual_api,
                        actual_sharing,
                        actual_format,
                        actual_channels,
                    );

                    if bit_perfect_route && actual_rate != target_sample_rate as i32 {
                        last_error = Some(format!(
                            "{} {} opened '{}' at {} Hz instead of requested {} Hz",
                            audio_api_label(audio_api),
                            sharing_label(sharing_mode),
                            selected_device.product_name,
                            actual_rate,
                            target_sample_rate,
                        ));
                        if fallback_kind.is_none() {
                            fallback_kind = Some(kind);
                            fallback_rate = actual_rate.max(1) as u32;
                        }
                        continue;
                    }

                    return Ok(AndroidManagedStream {
                        kind,
                        actual_sample_rate: actual_rate.max(1) as u32,
                    });
                }
                Err(error) => {
                    last_error = Some(error);
                    continue;
                }
            }
        }
    }

    if let Some(kind) = fallback_kind {
        return Ok(AndroidManagedStream {
            kind,
            actual_sample_rate: fallback_rate.max(1),
        });
    }

    Err(last_error.unwrap_or_else(|| {
        format!(
            "No Android managed output stream could be opened for '{}' at {} Hz",
            selected_device.product_name, target_sample_rate
        )
    }))
}

#[cfg(target_os = "android")]
fn select_android_output_device(target_sample_rate: u32) -> Result<AudioDeviceInfo, String> {
    let mut devices = AudioDeviceInfo::request(AudioDeviceDirection::Output)
        .map_err(|e| format!("Failed to enumerate Android output devices: {}", e))?;

    if devices.is_empty() {
        return Err("No Android output devices found".to_string());
    }

    devices.sort_by_key(|device| {
        (
            android_output_device_priority(device.device_type),
            !android_device_supports_sample_rate(device, target_sample_rate),
            !android_device_supports_stereo(device),
            !android_device_supports_f32(device),
            device.id,
        )
    });

    for device in &devices {
        eprintln!(
            "Android output candidate '{}' (id {}, type {:?}, sample_rates={:?}, channel_counts={:?}, formats={:?})",
            device.product_name,
            device.id,
            device.device_type,
            device.sample_rates,
            device.channel_counts,
            device.formats,
        );
    }

    Ok(devices.remove(0))
}

#[cfg(target_os = "android")]
fn android_device_supports_sample_rate(device: &AudioDeviceInfo, target_sample_rate: u32) -> bool {
    device.sample_rates.is_empty() || device.sample_rates.contains(&(target_sample_rate as i32))
}

#[cfg(target_os = "android")]
fn android_device_supports_stereo(device: &AudioDeviceInfo) -> bool {
    device.channel_counts.is_empty() || device.channel_counts.iter().any(|channels| *channels >= 2)
}

#[cfg(target_os = "android")]
fn android_device_supports_f32(device: &AudioDeviceInfo) -> bool {
    device.formats.is_empty() || device.formats.contains(&AudioFormat::F32)
}

#[cfg(target_os = "android")]
fn android_device_supports_dap_native_strategy(device_type: AudioDeviceType) -> bool {
    matches!(
        device_type,
        AudioDeviceType::WiredHeadphones
            | AudioDeviceType::WiredHeadset
            | AudioDeviceType::LineAnalog
            | AudioDeviceType::LineDigital
    )
}

#[cfg(target_os = "android")]
fn android_output_device_priority(device_type: AudioDeviceType) -> u8 {
    match device_type {
        AudioDeviceType::UsbDevice
        | AudioDeviceType::UsbHeadset
        | AudioDeviceType::UsbAccessory
        | AudioDeviceType::Dock => 0,
        AudioDeviceType::WiredHeadphones
        | AudioDeviceType::WiredHeadset
        | AudioDeviceType::LineAnalog
        | AudioDeviceType::LineDigital
        | AudioDeviceType::Hdmi
        | AudioDeviceType::HdmiArc
        | AudioDeviceType::HdmiEarc => 1,
        AudioDeviceType::BluetoothA2DP
        | AudioDeviceType::BluetoothSCO
        | AudioDeviceType::BleBroadcast
        | AudioDeviceType::BleHeadset
        | AudioDeviceType::BleSpeaker
        | AudioDeviceType::HearingAid => 2,
        AudioDeviceType::BuiltinSpeaker => 3,
        _ => 4,
        AudioDeviceType::BuiltinEarpiece => 5,
        AudioDeviceType::BuiltinSpeakerSafe => 6,
    }
}

#[cfg(target_os = "android")]
fn android_frames_per_callback(target_sample_rate: u32) -> i32 {
    ((target_sample_rate / 100).clamp(96, 1024)) as i32
}

#[cfg(target_os = "android")]
fn audio_api_label(audio_api: AudioApi) -> &'static str {
    match audio_api {
        AudioApi::AAudio => "AAudio",
        AudioApi::OpenSLES => "OpenSLES",
        AudioApi::Unspecified => "Unspecified",
    }
}

#[cfg(target_os = "android")]
fn sharing_label(sharing: SharingMode) -> &'static str {
    match sharing {
        SharingMode::Exclusive => "exclusive",
        SharingMode::Shared => "shared",
    }
}

/// Convert a linear volume slider value (0.0–1.0) to an exponential gain.
/// 1.0 → 0 dB, 0.0 → -∞ dB (silence). The slider position maps linearly to dB.
/// Exponent 2.0 gives a −40 dB range so 50 % slider → −20 dB (perceived ~¼ loudness).
#[inline]
fn volume_to_gain(volume: f32) -> f32 {
    if volume <= 0.0 {
        0.0
    } else {
        10.0_f32.powf(2.0 * (volume - 1.0))
    }
}

/// The real-time audio callback.
///
/// This function MUST NOT:
/// - Allocate memory
/// - Block on mutexes (we use try_lock where possible)
/// - Perform I/O
#[inline]
pub(crate) fn audio_callback(
    output: &mut [f32],
    data: &AudioCallbackData,
    _event_tx: &Sender<AudioEvent>,
) {
    if data.is_paused() {
        output.fill(0.0);
        return;
    }

    // Passthrough path: raw samples from decoder straight to output.
    if data.pipeline_mode.load(Ordering::Relaxed) == PipelineMode::Dop as u8 {
        let mut sources = match data.sources.try_lock() {
            Some(s) => s,
            None => {
                output.fill(0.0);
                return;
            }
        };
        let (read, old_source) = sources.read(output);
        if let Some(source) = old_source {
            eprintln!("[dop] gapless transition (old={})", source.info.path.display());
            let _ = data.finished_tracks.try_send(source);
        }
        if read < output.len() {
            output[read..].fill(0.0);
        }
        return;
    }

    // No EQ, no dynamics, no speed, no crossfade. Gain is applied for
    // volume control (a no-op when DAC hardware volume is available).
    if data.is_passthrough() {
        let gain = data.get_gain();
        let mut sources = match data.sources.try_lock() {
            Some(s) => s,
            None => {
                output.fill(0.0);
                return;
            }
        };

        let (read, old_source) = sources.read(output);
            if let Some(source) = old_source {
                eprintln!("[crossfade] gapless transition (old={})", source.info.path.display());
                let _ = data.finished_tracks.try_send(source);
            }
        if read < output.len() {
            output[read..].fill(0.0);
        }
        for sample in output[..read].iter_mut() {
            *sample *= gain;
        }
        return;
    }

    // --- DSP path: full processing chain ---

    let volume = data.get_gain();
    let speed = data.get_playback_speed();
    let channels = data.channels();

    let mut sources = match data.sources.try_lock() {
        Some(s) => s,
        None => {
            output.fill(0.0);
            return;
        }
    };

    let mut crossfader = match data.crossfader.try_lock() {
        Some(c) => c,
        None => {
            let (read, old_source) = sources.read(output);

            if let Some(source) = old_source {
                let _ = data.finished_tracks.try_send(source);
            }

            if read < output.len() {
                output[read..].fill(0.0);
            }
            if let Some(mut eq) = data.equalizer.try_lock() {
                eq.process(output, channels);
            }
            if let Some(mut fx) = data.fx.try_lock() {
                fx.process(output, channels);
            }
            if let Some(mut dynamics) = data.dynamics.try_lock() {
                dynamics.process(output, channels);
            }
            // Volume is always applied last, after all DSP processing.
            for sample in output.iter_mut() {
                *sample *= volume;
            }
            return;
        }
    };

    if crossfader.is_active() && sources.next_mut().is_some() {
        eprintln!(
            "[crossfade] callback mixing — position={}/{}",
            crossfader.position(),
            crossfader.duration_samples()
        );
        let mut buf_a = match data.mix_buffer_a.try_lock() {
            Some(b) => b,
            None => {
                output.fill(0.0);
                return;
            }
        };
        let mut buf_b = match data.mix_buffer_b.try_lock() {
            Some(b) => b,
            None => {
                output.fill(0.0);
                return;
            }
        };

        let needed = output.len();
        if buf_a.len() < needed {
            output.fill(0.0);
            return;
        }

        let read_a = sources
            .current_mut()
            .map(|s| s.read(&mut buf_a[..needed]))
            .unwrap_or(0);
        let read_b = sources
            .next_mut()
            .map(|s| s.read(&mut buf_b[..needed]))
            .unwrap_or(0);

        if read_a < needed {
            buf_a[read_a..needed].fill(0.0);
        }
        if read_b < needed {
            buf_b[read_b..needed].fill(0.0);
        }

        let _ = crossfader.mix(&buf_a[..needed], &buf_b[..needed], output, channels);

        if !crossfader.is_active() {
            eprintln!("[crossfade] DONE — advancing to next track");
            drop(crossfader);
            if let Some(source) = sources.advance_to_next() {
                let _ = data.finished_tracks.try_send(source);
            }
        }
    } else {
        if (speed - 1.0).abs() < 0.001 {
            let (read, old_source) = sources.read(output);

            if let Some(source) = old_source {
                let _ = data.finished_tracks.try_send(source);
            }

            if read < output.len() {
                output[read..].fill(0.0);
            }
        } else {
            let mut speed_buf = match data.speed_buffer.try_lock() {
                Some(b) => b,
                None => {
                    output.fill(0.0);
                    return;
                }
            };
            let mut frac_pos = match data.speed_frac_pos.try_lock() {
                Some(p) => p,
                None => {
                    output.fill(0.0);
                    return;
                }
            };

            let output_frames = output.len() / channels;
            let input_samples_needed =
                ((output_frames as f64 * speed as f64) + 2.0) as usize * channels;

            if speed_buf.len() < input_samples_needed {
                output.fill(0.0);
                return;
            }

            let (read, old_source) = sources.read(&mut speed_buf[..input_samples_needed]);

            if let Some(source) = old_source {
                let _ = data.finished_tracks.try_send(source);
            }

            if read < channels {
                output.fill(0.0);
                return;
            }

            let input_frames = read / channels;

            for out_frame in 0..output_frames {
                let in_pos = *frac_pos;
                let in_frame = in_pos as usize;
                let frac = (in_pos - in_frame as f64) as f32;

                if in_frame + 1 >= input_frames {
                    for ch in 0..channels {
                        output[out_frame * channels + ch] = 0.0;
                    }
                } else {
                    for ch in 0..channels {
                        let s0 = speed_buf[in_frame * channels + ch];
                        let s1 = speed_buf[(in_frame + 1) * channels + ch];
                        output[out_frame * channels + ch] = s0 + (s1 - s0) * frac;
                    }
                }

                *frac_pos += speed as f64;
            }

            let consumed_frames = (*frac_pos) as usize;
            *frac_pos -= consumed_frames as f64;
        }
    }

    if let Some(mut eq) = data.equalizer.try_lock() {
        eq.process(output, channels);
    }
    if let Some(mut fx) = data.fx.try_lock() {
        fx.process(output, channels);
    }
    if let Some(mut dynamics) = data.dynamics.try_lock() {
        dynamics.process(output, channels);
    }

    // Volume is always applied last, after all DSP processing.
    for sample in output.iter_mut() {
        *sample *= volume;
    }
}

/// Command processing loop running in the audio thread.
fn command_processing_loop(
    command_rx: Receiver<AudioCommand>,
    finished_rx: Receiver<AudioSource>,
    event_tx: Sender<AudioEvent>,
    callback_data: Arc<AudioCallbackData>,
    state: Arc<AtomicU8>,
    decoders: Arc<Mutex<Vec<DecoderHandle>>>,
    sample_rate: u32,
    shutdown: Arc<AtomicBool>,
) {
    loop {
        // Check shutdown flag
        if shutdown.load(Ordering::Acquire) {
            break;
        }

        // Check for finished tracks
        while let Ok(source) = finished_rx.try_recv() {
            let path = source.info.path.to_string_lossy().to_string();
            let _ = event_tx.try_send(AudioEvent::TrackEnded { path });

            // Crossfade completed — restore Playing state. This is the
            // natural bookend: a crossfade always ends with advance_to_next()
            // pushing the old source through finished_tracks.
            if state.load(Ordering::Relaxed) == PlaybackState::Crossfading as u8 {
                state.store(PlaybackState::Playing as u8, Ordering::Relaxed);
                let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Playing));
            } else {
                // If no next source was queued for gapless transition,
                // the engine is outputting silence. Mark as stopped so
                // the Dart layer can detect the failure and fall back.
                let sources = callback_data.sources.lock();
                if sources.current().is_none() {
                    drop(sources);
                    state.store(PlaybackState::Stopped as u8, Ordering::Relaxed);
                    let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Stopped));
                }
            }
        }

        match command_rx.recv_timeout(std::time::Duration::from_millis(50)) {
            Ok(command) => {
                match command {
                    AudioCommand::Play { path } => {
                        handle_play(
                            path,
                            &callback_data,
                            &state,
                            &decoders,
                            &event_tx,
                            sample_rate,
                        );
                    }
                    AudioCommand::PlayPrepared {
                        source,
                        decoder_handle,
                    } => {
                        handle_play_prepared(
                            source,
                            decoder_handle,
                            &callback_data,
                            &state,
                            &decoders,
                            &event_tx,
                        );
                    }
                    AudioCommand::QueueNext { path } => {
                        handle_queue_next(path, &callback_data, &decoders, &event_tx, sample_rate);
                    }
                    AudioCommand::QueueNextPrepared {
                        source,
                        decoder_handle,
                    } => {
                        handle_queue_next_prepared(
                            source,
                            decoder_handle,
                            &callback_data,
                            &decoders,
                            &event_tx,
                        );
                    }
                    AudioCommand::Pause => {
                        callback_data.set_paused(true);
                        state.store(PlaybackState::Paused as u8, Ordering::Relaxed);
                        let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Paused));
                    }
                    AudioCommand::Resume => {
                        callback_data.set_paused(false);
                        state.store(PlaybackState::Playing as u8, Ordering::Relaxed);
                        let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Playing));
                    }
                    AudioCommand::Stop => {
                        callback_data.sources.lock().stop();
                        callback_data.crossfader.lock().reset();
                        state.store(PlaybackState::Stopped as u8, Ordering::Relaxed);
                        let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Stopped));
                    }
                    AudioCommand::Seek { position_secs } => {
                        handle_seek(
                            position_secs,
                            &callback_data,
                            &state,
                            &decoders,
                            &event_tx,
                            sample_rate,
                        );
                    }
                    AudioCommand::SetVolume { volume } => {
                        callback_data.set_volume(volume.clamp(0.0, 1.0));
                    }
                    AudioCommand::SetCrossfade {
                        enabled,
                        duration_secs,
                    } => {
                        let mut crossfader = callback_data.crossfader.lock();
                        crossfader.set_enabled(enabled);
                        crossfader.set_duration(duration_secs);
                    }
                    AudioCommand::SetCrossfadeCurve { curve } => {
                        callback_data.crossfader.lock().set_curve(curve);
                    }
                    AudioCommand::SetPlaybackSpeed { speed } => {
                        callback_data.set_playback_speed(speed);
                        *callback_data.speed_frac_pos.lock() = 0.0;
                    }
                    AudioCommand::SetEqualizer { enabled, gains_db } => {
                        if let Some(mut eq) = callback_data.equalizer.try_lock() {
                            eq.set(enabled, &gains_db, sample_rate);
                        }
                    }
                    AudioCommand::SetCompressor {
                        enabled,
                        threshold_db,
                        ratio,
                        attack_ms,
                        release_ms,
                        makeup_gain_db,
                    } => {
                        callback_data.dynamics.lock().set_compressor(
                            enabled,
                            threshold_db,
                            ratio,
                            attack_ms,
                            release_ms,
                            makeup_gain_db,
                        );
                    }
                    AudioCommand::SetLimiter {
                        enabled,
                        input_gain_db,
                        ceiling_db,
                        release_ms,
                    } => {
                        callback_data.dynamics.lock().set_limiter(
                            enabled,
                            input_gain_db,
                            ceiling_db,
                            release_ms,
                        );
                    }
                    AudioCommand::SetPipelineMode { passthrough } => {
                        let mode = if passthrough {
                            PipelineMode::Passthrough
                        } else {
                            PipelineMode::Dsp
                        };
                        callback_data.set_pipeline_mode(mode);
                        callback_data
                            .base_pipeline_mode
                            .store(mode as u8, Ordering::Relaxed);
                    }
                    AudioCommand::SetDopOverride { is_dop } => {
                        if is_dop {
                            callback_data
                                .pipeline_mode
                                .store(PipelineMode::Dop as u8, Ordering::Relaxed);
                        } else {
                            let base = callback_data.base_pipeline_mode.load(Ordering::Relaxed);
                            callback_data.pipeline_mode.store(base, Ordering::Relaxed);
                        }
                    }
                    AudioCommand::SetFx {
                        enabled,
                        balance,
                        tempo,
                        damp,
                        filter_hz,
                        delay_ms,
                        size,
                        mix,
                        feedback,
                        width,
                    } => {
                        callback_data.fx.lock().set(
                            enabled, balance, tempo, damp, filter_hz, delay_ms, size, mix,
                            feedback, width,
                        );
                    }
                    AudioCommand::CrossfadeToNext | AudioCommand::SkipToNext => {
                        handle_skip_to_next(&callback_data, &state, &event_tx);
                    }
                    AudioCommand::Shutdown => {
                        // Stop everything and exit
                        callback_data.sources.lock().stop();
                        for decoder in decoders.lock().drain(..) {
                            decoder.stop();
                        }
                        break;
                    }
                }
            }
            Err(crossbeam_channel::RecvTimeoutError::Timeout) => {
                // No command - continue loop
            }
            Err(crossbeam_channel::RecvTimeoutError::Disconnected) => {
                // Channel closed - exit
                break;
            }
        }

        // Auto-crossfade: start when the current track is near its end.
        // Both locks are held across the entire check+start to prevent the
        // audio callback from doing a hard gapless transition between the
        // remaining check and the crossfader.start() call.
        if !callback_data.is_passthrough() {
            let mut sources = callback_data.sources.lock();
            let mut crossfader = callback_data.crossfader.lock();
            if crossfader.is_enabled()
                && !crossfader.is_active()
                && sources.has_next()
                && crossfader.duration_secs() > 0.0
            {
                if let Some(current) = sources.current() {
                    let remaining = current.remaining_secs();
                    if remaining > 0.0 && remaining <= crossfader.duration_secs() as f64 {
                        // Only start crossfade if next track has buffered data.
                        // Require any data (≥0s) — the decoder has been running
                        // since the next track was pre-queued, so the buffer
                        // should be full by now.
                        if sources.next_has_enough_buffer(0.0) {
                            eprintln!(
                                "[crossfade] TRIGGERING! remaining={:.3}s threshold={:.1}s",
                                remaining,
                                crossfader.duration_secs()
                            );
                            crossfader.start();
                            state.store(PlaybackState::Crossfading as u8, Ordering::Relaxed);
                            let _ = event_tx
                                .try_send(AudioEvent::StateChanged(PlaybackState::Crossfading));
                            let from = sources
                                .current()
                                .map(|s| s.info.path.to_string_lossy().to_string());
                            let to = sources
                                .next_mut()
                                .map(|s| s.info.path.to_string_lossy().to_string());
                            if let (Some(from_path), Some(to_path)) = (from, to) {
                                let _ = event_tx.try_send(AudioEvent::CrossfadeStarted {
                                    from_path,
                                    to_path,
                                });
                            }
                        } else {
                            eprintln!(
                                "[crossfade] DELAYED - next buffer insufficient, waiting for more data"
                            );
                        }
                    }
                }
            } else if crossfader.is_enabled() && crossfader.duration_secs() > 0.0 {
                // Only print when we're near the crossfade window
                let remaining = sources
                    .current()
                    .map(|s| s.remaining_secs())
                    .unwrap_or(-1.0);
                let threshold = crossfader.duration_secs() as f64;
                if remaining > 0.0 && remaining <= threshold * 3.0 {
                    eprintln!(
                        "[crossfade] NEAR: active={} has_next={} has_current={} next_buffered={} remaining={:.3}s threshold={:.1}s",
                        crossfader.is_active(),
                        sources.has_next(),
                        sources.current().is_some(),
                        sources.next_has_enough_buffer(0.0),
                        remaining,
                        crossfader.duration_secs()
                    );
                }
            }
        }

        // Clean up finished decoders
        decoders.lock().retain(|d| d.is_running());
    }
}

fn spawn_decoder(
    path: PathBuf,
    sample_rate: u32,
    channels: usize,
    seek_secs: Option<f64>,
) -> anyhow::Result<(AudioSource, DecoderHandle)> {
    let file_type = detect_file_type(&path);
    match file_type {
        FileType::Dsd => {
            let requested = crate::api::audio_api::current_dsd_output_mode();
            let output_mode = crate::api::audio_api::effective_dsd_output_mode(requested);
            let (source, thread) = if let Some(seek) = seek_secs {
                DsdDecoderThread::spawn_with_seek(
                    path, output_mode, sample_rate, channels, Some(seek),
                )
            } else {
                DsdDecoderThread::spawn(path, output_mode, sample_rate, channels)
            }?;
            Ok((source, DecoderHandle::Dsd(thread)))
        }
        FileType::WavPack => {
            let (source, handle) = if let Some(seek) = seek_secs {
                WavpackDecoderThread::spawn_with_seek(
                    path, sample_rate, channels, Some(seek),
                )
            } else {
                WavpackDecoderThread::spawn(path, sample_rate, channels)
            }?;
            Ok((source, handle))
        }
        FileType::Standard => {
            let (source, thread) = if let Some(seek) = seek_secs {
                DecoderThread::spawn_with_seek(path, sample_rate, channels, Some(seek))
            } else {
                DecoderThread::spawn(path, sample_rate, channels)
            }?;
            Ok((source, DecoderHandle::Symphonia(thread)))
        }
    }
}

fn handle_play(
    path: PathBuf,
    callback_data: &AudioCallbackData,
    state: &Arc<AtomicU8>,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
    sample_rate: u32,
) {
    state.store(PlaybackState::Buffering as u8, Ordering::Relaxed);
    let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Buffering));

    callback_data.sources.lock().stop();
    callback_data.crossfader.lock().reset();

    match spawn_decoder(path.clone(), sample_rate, callback_data.channels(), None) {
        Ok((source, handle)) => {
            start_playback_source(
                source, handle, callback_data, state, decoders, event_tx,
            );
        }
        Err(e) => {
            let _ = event_tx.try_send(AudioEvent::Error {
                message: format!("Failed to decode {}: {}", path.display(), e),
            });
            state.store(PlaybackState::Idle as u8, Ordering::Relaxed);
        }
    }
}

fn handle_play_prepared(
    source: AudioSource,
    decoder_handle: DecoderHandle,
    callback_data: &AudioCallbackData,
    state: &Arc<AtomicU8>,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
) {
    state.store(PlaybackState::Buffering as u8, Ordering::Relaxed);
    let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Buffering));

    callback_data.sources.lock().stop();
    callback_data.crossfader.lock().reset();

    start_playback_source(
        source, decoder_handle, callback_data, state, decoders, event_tx,
    );
}

fn handle_queue_next(
    path: PathBuf,
    callback_data: &AudioCallbackData,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
    sample_rate: u32,
) {
    match spawn_decoder(path.clone(), sample_rate, callback_data.channels(), None) {
        Ok((source, handle)) => {
            queue_playback_source(source, handle, callback_data, decoders, event_tx);
        }
        Err(e) => {
            let _ = event_tx.try_send(AudioEvent::Error {
                message: format!("Failed to decode next track {}: {}", path.display(), e),
            });
        }
    }
}

fn handle_queue_next_prepared(
    source: AudioSource,
    decoder_handle: DecoderHandle,
    callback_data: &AudioCallbackData,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
) {
    queue_playback_source(source, decoder_handle, callback_data, decoders, event_tx);
}

fn start_playback_source(
    mut source: AudioSource,
    decoder_handle: DecoderHandle,
    callback_data: &AudioCallbackData,
    state: &Arc<AtomicU8>,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
) {
    source.set_ready();
    source.set_playing();

    callback_data.sources.lock().set_current(source);
    callback_data.set_paused(false);
    decoders.lock().push(decoder_handle);

    state.store(PlaybackState::Playing as u8, Ordering::Relaxed);
    let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Playing));
}

fn queue_playback_source(
    mut source: AudioSource,
    decoder_handle: DecoderHandle,
    callback_data: &AudioCallbackData,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
) {
    let queued_path = source.info.path.to_string_lossy().to_string();
    source.set_ready();

    callback_data.sources.lock().queue_next(source);
    decoders.lock().push(decoder_handle);

    let _ = event_tx.try_send(AudioEvent::NextTrackReady { path: queued_path });
}

fn handle_skip_to_next(
    callback_data: &AudioCallbackData,
    state: &Arc<AtomicU8>,
    event_tx: &Sender<AudioEvent>,
) {
    let mut sources = callback_data.sources.lock();
    let mut crossfader = callback_data.crossfader.lock();

    if sources.has_next() {
        if crossfader.is_enabled() && !crossfader.is_active() {
            // Start crossfade
            let from_path = sources
                .current()
                .map(|s| s.info.path.to_string_lossy().to_string());
            let to_path = sources
                .next_mut()
                .map(|s| s.info.path.to_string_lossy().to_string());
            crossfader.start();
            state.store(PlaybackState::Crossfading as u8, Ordering::Relaxed);
            let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Crossfading));
            if let (Some(from), Some(to)) = (from_path, to_path) {
                let _ = event_tx.try_send(AudioEvent::CrossfadeStarted {
                    from_path: from,
                    to_path: to,
                });
            }
        } else {
            // Immediate transition
            sources.advance_to_next();
            state.store(PlaybackState::Playing as u8, Ordering::Relaxed);
        }
    }
}

fn handle_seek(
    position_secs: f64,
    callback_data: &AudioCallbackData,
    state: &Arc<AtomicU8>,
    decoders: &Arc<Mutex<Vec<DecoderHandle>>>,
    event_tx: &Sender<AudioEvent>,
    sample_rate: u32,
) {
    let target_secs = position_secs.max(0.0);

    let current_path = {
        let sources = callback_data.sources.lock();
        sources.current().map(|s| s.info.path.clone())
    };

    let Some(path) = current_path else {
        let _ = event_tx.try_send(AudioEvent::Error {
            message: "Seek failed: no track loaded".to_string(),
        });
        return;
    };

    let was_paused = callback_data.is_paused();

    state.store(PlaybackState::Buffering as u8, Ordering::Relaxed);
    let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Buffering));

    callback_data.sources.lock().stop();
    callback_data.crossfader.lock().reset();
    *callback_data.speed_frac_pos.lock() = 0.0;

    {
        let mut active_decoders = decoders.lock();
        for decoder in active_decoders.drain(..) {
            decoder.stop();
        }
    }

    match spawn_decoder(path.clone(), sample_rate, callback_data.channels(), Some(target_secs)) {
        Ok((mut source, handle)) => {
            source.set_ready();
            if !was_paused {
                source.set_playing();
            }

            callback_data.sources.lock().set_current(source);
            callback_data.set_paused(was_paused);
            decoders.lock().push(handle);

            let next_state = if was_paused {
                PlaybackState::Paused
            } else {
                PlaybackState::Playing
            };
            state.store(next_state as u8, Ordering::Relaxed);
            let _ = event_tx.try_send(AudioEvent::StateChanged(next_state));
        }
        Err(e) => {
            let _ = event_tx.try_send(AudioEvent::Error {
                message: format!(
                    "Seek failed for {} to {:.2}s: {}",
                    path.display(),
                    target_secs,
                    e
                ),
            });
            state.store(PlaybackState::Idle as u8, Ordering::Relaxed);
            let _ = event_tx.try_send(AudioEvent::StateChanged(PlaybackState::Idle));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::source::{AudioSource, SourceInfo};
    use crossbeam_channel::bounded;
    use std::path::PathBuf;

    fn build_source(samples: &[f32], sample_rate: u32, channels: usize) -> AudioSource {
        let duration_secs = samples.len() as f64 / channels as f64 / sample_rate as f64;
        let info = SourceInfo {
            path: PathBuf::from("test.wav"),
            original_sample_rate: sample_rate,
            output_sample_rate: sample_rate,
            channels,
            total_samples: samples.len() as u64,
            duration_secs,
        };
        let (mut source, mut producer) = AudioSource::new(info);

        assert_eq!(producer.write(samples), samples.len());
        producer.finish();
        source.set_ready();
        source.set_playing();
        source
    }

    fn build_callback_data(sample_rate: u32, channels: usize) -> AudioCallbackData {
        let (finished_tx, _finished_rx) = bounded::<AudioSource>(8);
        AudioCallbackData::new(sample_rate, channels, finished_tx, PipelineMode::Dsp)
    }

    fn build_passthrough_callback_data(sample_rate: u32, channels: usize) -> AudioCallbackData {
        let (finished_tx, _finished_rx) = bounded::<AudioSource>(8);
        AudioCallbackData::new(sample_rate, channels, finished_tx, PipelineMode::Passthrough)
    }

    fn run_callback(data: &AudioCallbackData, output_len: usize) -> Vec<f32> {
        let (event_tx, _event_rx) = bounded::<AudioEvent>(8);
        let mut output = vec![123.0; output_len];
        audio_callback(&mut output, data, &event_tx);
        output
    }

    #[test]
    fn callback_passthrough_applies_volume() {
        let data = build_passthrough_callback_data(48_000, 2);
        let input = vec![0.0, 0.25, -0.5, 0.5, -0.25, 0.0, 1.0, -1.0];

        data.set_volume(0.25);
        data.sources
            .lock()
            .set_current(build_source(&input, 48_000, 2));

        let output = run_callback(&data, input.len());

        let gain = volume_to_gain(0.25);
        let expected: Vec<f32> = input.iter().map(|s| s * gain).collect();
        assert_eq!(output, expected);
    }

    #[test]
    fn callback_passthrough_zero_fills_tail_on_underrun() {
        let data = build_passthrough_callback_data(48_000, 2);
        let input = vec![0.5, -0.5, 0.25, -0.25];

        data.sources
            .lock()
            .set_current(build_source(&input, 48_000, 2));

        let output = run_callback(&data, 8);

        assert_eq!(output, vec![0.5, -0.5, 0.25, -0.25, 0.0, 0.0, 0.0, 0.0]);
    }

    #[test]
    fn callback_zero_fills_when_no_source_available() {
        let data = build_callback_data(48_000, 2);

        let output = run_callback(&data, 8);

        assert_eq!(output, vec![0.0; 8]);
    }

    #[test]
    fn callback_passthrough_passthrough_at_volume_1() {
        let data = build_passthrough_callback_data(48_000, 2);
        let input = vec![0.0, 0.25, -0.5, 0.5, -0.25, 0.0, 1.0, -1.0];

        data.set_volume(1.0);
        data.sources
            .lock()
            .set_current(build_source(&input, 48_000, 2));

        let output = run_callback(&data, input.len());

        assert_eq!(output, input);
    }

    #[test]
    fn callback_applies_gain_when_dsp() {
        let data = build_callback_data(48_000, 2);
        let input = vec![0.5, -0.5, 0.25, -0.25];

        data.set_volume(0.5);
        data.sources
            .lock()
            .set_current(build_source(&input, 48_000, 2));

        let output = run_callback(&data, input.len());

        let gain = volume_to_gain(0.5);
        let expected: Vec<f32> = input.iter().map(|s| s * gain).collect();
        assert_eq!(output, expected);
    }
}
