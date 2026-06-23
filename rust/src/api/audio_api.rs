//! Flutter Rust Bridge API for audio engine control.
//!
//! This module provides the interface between Dart and the Rust audio engine.
//! Now available on all platforms including Android (using CPAL with Oboe backend).

use crate::audio::commands::{AudioEvent, PlaybackState};
use crate::audio::decoder::{probe_file, DecoderThread};
use crate::audio::decoder_handle::{detect_file_type, DecoderHandle};
#[cfg(target_os = "android")]
use crate::audio::device::current_device_profile;
use crate::audio::dsd_engine::dsd::{resolve_dsd_pcm_sample_rate, DsdOutputMode, DsdRate};
use crate::audio::dsd_engine::format::open_dsd_decoder;
use crate::audio::dsd_engine::DsdDecoderThread;
use crate::audio::manager::{AudioCapability, AudioCapabilitySnapshot, AudioEngine, EngineManager};
use crate::audio::strategy::OutputStrategy;
use crate::audio::wavpack_thread::WavpackDecoderThread;
use log::{info as log_info, warn as log_warn};
use once_cell::sync::Lazy;
use serde::Serialize;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU32, AtomicU8, Ordering};

static ENGINE_MANAGER: Lazy<EngineManager> = Lazy::new(EngineManager::new);

static DSD_OUTPUT_MODE: AtomicU8 = AtomicU8::new(0);
static CURRENT_DSD_TRACK_RATE: AtomicU32 = AtomicU32::new(0);
static PENDING_VOLUME: AtomicU32 = AtomicU32::new(0);

const PENDING_VOLUME_NONE: u32 = 0xFFFF_FFFF;

// ponytail: crossfade state survives engine recreation (sample-rate / strategy
// changes recreate the engine, wiping crossfade) via these pending atomics,
// mirroring the PENDING_VOLUME pattern. Three separate atomics because enabled/
// duration and curve are pushed through two distinct Dart calls.
static PENDING_XF_ENABLED: AtomicU8 = AtomicU8::new(u8::MAX);
static PENDING_XF_DURATION: AtomicU32 = AtomicU32::new(0xFFFF_FFFF);
static PENDING_XF_CURVE: AtomicU8 = AtomicU8::new(u8::MAX);

pub fn current_dsd_output_mode() -> DsdOutputMode {
    match DSD_OUTPUT_MODE.load(Ordering::Relaxed) {
        1 => DsdOutputMode::Dop,
        2 => DsdOutputMode::Native,
        3 => DsdOutputMode::Auto,
        _ => DsdOutputMode::PcmDecimation,
    }
}

pub fn effective_dsd_output_mode(requested: DsdOutputMode) -> DsdOutputMode {
    let dsd_rate = current_dsd_track_rate().and_then(DsdRate::from_sample_rate);
    effective_dsd_output_mode_for_rate(requested, dsd_rate)
}

pub fn effective_dsd_output_mode_for_rate(
    requested: DsdOutputMode,
    dsd_rate: Option<DsdRate>,
) -> DsdOutputMode {
    let is_dsd256_plus = dsd_rate.is_some_and(|r| matches!(r, DsdRate::Dsd256 | DsdRate::Dsd512));

    match requested {
        DsdOutputMode::PcmDecimation => return DsdOutputMode::PcmDecimation,
        DsdOutputMode::Dop => {
            if is_dsd256_plus {
                #[cfg(all(feature = "uac2", target_os = "android"))]
                {
                    if crate::uac2::is_usb_session_active() {
                        return DsdOutputMode::Dop;
                    }
                }
                log_info!(
                    "[AUDIO] DoP requested for DSD256+ but carrier rate too high; \
                     falling back to PCM decimation"
                );
                return DsdOutputMode::PcmDecimation;
            }
            return DsdOutputMode::Dop;
        }
        DsdOutputMode::Native | DsdOutputMode::Auto => {}
    }

    // Native/Auto DSD can be delivered in three ways:
    // 1. UAC2 direct USB (raw DSD bitstream via isochronous transfers)
    // 2. Android AudioTrack with ENCODING_DSD (direct to internal DAC)
    // 3. Fallback to DoP if neither is available

    #[cfg(all(feature = "uac2", target_os = "android"))]
    {
        if crate::uac2::is_usb_session_active() {
            return DsdOutputMode::Native;
        }
    }

    #[cfg(target_os = "android")]
    {
        let profile = crate::audio::device::current_device_profile();
        let is_dap = profile.as_ref().is_some_and(|p| p.is_dap());
        let supports_dsd = profile.as_ref().is_some_and(|p| p.supports_native_dsd);
        if supports_dsd || is_dap {
            log_info!(
                "[AUDIO] {:?} DSD requested; device {} ENCODING_DSD, \
                 using Android DSD AudioTrack",
                requested,
                if supports_dsd {
                    "supports"
                } else {
                    "is DAP, assuming"
                }
            );
            return DsdOutputMode::Native;
        }
    }

    // DSD256+ without UAC2: skip DoP, go straight to PCM
    if is_dsd256_plus {
        log_info!(
            "[AUDIO] DSD256+ without UAC2 native path; falling back to PCM decimation \
             (DoP carrier rate too high for internal DAC)"
        );
        return DsdOutputMode::PcmDecimation;
    }

    // For Auto on non-DSD-capable devices, try DoP before falling back to PCM
    if requested == DsdOutputMode::Auto {
        #[cfg(target_os = "android")]
        {
            let profile = crate::audio::device::current_device_profile();
            let is_dap = profile.as_ref().is_some_and(|p| p.is_dap());
            if is_dap {
                log_info!(
                    "[AUDIO] Auto DSD: device is DAP but native DSD unavailable; \
                     falling back to DoP"
                );
                return DsdOutputMode::Dop;
            }
        }

        #[cfg(all(feature = "uac2", target_os = "android"))]
        {
            if crate::uac2::is_usb_session_active() {
                return DsdOutputMode::Dop;
            }
        }

        log_info!(
            "[AUDIO] Auto DSD: no native DSD or DoP path available; \
             falling back to PCM decimation"
        );
        return DsdOutputMode::PcmDecimation;
    }

    log_info!(
        "[AUDIO] Native DSD requested but no direct DSD path available; \
         falling back to DoP (bit-perfect DSD over PCM carrier)"
    );
    DsdOutputMode::Dop
}

pub fn set_dsd_track_rate(rate: u32) {
    CURRENT_DSD_TRACK_RATE.store(rate, Ordering::Relaxed);
}

pub fn clear_dsd_track_rate() {
    CURRENT_DSD_TRACK_RATE.store(0, Ordering::Relaxed);
}

pub fn current_dsd_track_rate() -> Option<u32> {
    let rate = CURRENT_DSD_TRACK_RATE.load(Ordering::Relaxed);
    if rate > 0 {
        Some(rate)
    } else {
        None
    }
}

pub fn set_pending_volume(volume: f32) {
    PENDING_VOLUME.store(volume.to_bits(), Ordering::Relaxed);
}

pub fn take_pending_volume() -> Option<f32> {
    let bits = PENDING_VOLUME.load(Ordering::Relaxed);
    if bits == PENDING_VOLUME_NONE {
        return None;
    }
    PENDING_VOLUME.store(PENDING_VOLUME_NONE, Ordering::Relaxed);
    Some(f32::from_bits(bits))
}

pub fn set_pending_crossfade(enabled: bool, duration_secs: f32) {
    PENDING_XF_ENABLED.store(if enabled { 1 } else { 0 }, Ordering::Relaxed);
    PENDING_XF_DURATION.store(duration_secs.to_bits(), Ordering::Relaxed);
}

pub fn set_pending_crossfade_curve(curve: crate::audio::crossfader::CrossfadeCurve) {
    let raw = match curve {
        crate::audio::crossfader::CrossfadeCurve::EqualPower => 0,
        crate::audio::crossfader::CrossfadeCurve::Linear => 1,
        crate::audio::crossfader::CrossfadeCurve::SquareRoot => 2,
        crate::audio::crossfader::CrossfadeCurve::SCurve => 3,
    };
    PENDING_XF_CURVE.store(raw, Ordering::Relaxed);
}

pub fn take_pending_crossfade() -> Option<(bool, f32, crate::audio::crossfader::CrossfadeCurve)> {
    let enabled_raw = PENDING_XF_ENABLED.swap(u8::MAX, Ordering::Relaxed);
    if enabled_raw == u8::MAX {
        return None;
    }
    let enabled = enabled_raw == 1;
    let dur_bits = PENDING_XF_DURATION.swap(0xFFFF_FFFF, Ordering::Relaxed);
    let duration_secs = if dur_bits == 0xFFFF_FFFF {
        3.0
    } else {
        f32::from_bits(dur_bits)
    };
    let curve_raw = PENDING_XF_CURVE.swap(u8::MAX, Ordering::Relaxed);
    let curve = match curve_raw {
        1 => crate::audio::crossfader::CrossfadeCurve::Linear,
        2 => crate::audio::crossfader::CrossfadeCurve::SquareRoot,
        3 => crate::audio::crossfader::CrossfadeCurve::SCurve,
        _ => crate::audio::crossfader::CrossfadeCurve::EqualPower,
    };
    Some((enabled, duration_secs, curve))
}

fn with_audio_engine<T>(
    f: impl FnOnce(&crate::audio::engine::AudioEngineHandle) -> Result<T, String>,
) -> Result<T, String> {
    ENGINE_MANAGER.with_rust_handle(f)
}

fn read_audio_engine<T>(
    f: impl FnOnce(&crate::audio::engine::AudioEngineHandle) -> T,
) -> Option<T> {
    ENGINE_MANAGER.read_rust_handle(f)
}

fn ensure_audio_engine(preferred_sample_rate: Option<u32>) -> Result<(), String> {
    ENGINE_MANAGER.ensure_rust_engine(preferred_sample_rate, vec![])
}

fn ensure_audio_engine_excluded(
    preferred_sample_rate: Option<u32>,
    excluded: Vec<OutputStrategy>,
) -> Result<(), String> {
    ENGINE_MANAGER.ensure_rust_engine(preferred_sample_rate, excluded)
}

fn resolve_requested_output_sample_rate(
    preferred_sample_rate: Option<u32>,
) -> Result<Option<u32>, String> {
    #[cfg(all(feature = "uac2", target_os = "android"))]
    {
        return crate::uac2::negotiate_android_direct_output_sample_rate(preferred_sample_rate);
    }

    #[allow(unreachable_code)]
    Ok(preferred_sample_rate)
}

fn resolve_track_playback_output_sample_rate(
    preferred_sample_rate: Option<u32>,
) -> Result<Option<u32>, String> {
    #[cfg(target_os = "android")]
    {
        let route_type = ENGINE_MANAGER.capability_route_type();
        let should_preserve_existing_rate = !ENGINE_MANAGER.is_high_res_mode_enabled()
            && !ENGINE_MANAGER.get_dap_bit_perfect_enabled()
            && matches!(route_type.as_str(), "unknown" | "internal" | "wired")
            && current_device_profile().is_some_and(|profile| profile.is_dap());
        if should_preserve_existing_rate {
            if let Some(existing_rate) = read_audio_engine(|handle| handle.sample_rate()) {
                return Ok(Some(existing_rate));
            }
        }
    }

    resolve_requested_output_sample_rate(preferred_sample_rate)
}

fn resolve_dsd_engine_sample_rate(
    path: &PathBuf,
    output_mode: DsdOutputMode,
) -> Result<Option<u32>, String> {
    let effective_mode = effective_dsd_output_mode(output_mode);
    if effective_mode == DsdOutputMode::Dop {
        let decoder = open_dsd_decoder(path)
            .map_err(|e| format!("Failed to probe DSD rate for {}: {}", path.display(), e))?;
        let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate())
            .ok_or_else(|| format!("Unsupported DSD sample rate: {}", decoder.sample_rate()))?;
        let carrier = dsd_rate.dop_carrier_rate();
        log_info!(
            "[AUDIO] DSD DoP: dsd_rate={} Hz -> carrier={} Hz",
            dsd_rate.sample_rate(),
            carrier
        );
        return resolve_requested_output_sample_rate(Some(carrier));
    }
    let decoder = open_dsd_decoder(path)
        .map_err(|e| format!("Failed to probe DSD rate for {}: {}", path.display(), e))?;
    let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate())
        .ok_or_else(|| format!("Unsupported DSD sample rate: {}", decoder.sample_rate()))?;
    if effective_mode == DsdOutputMode::Native {
        #[cfg(target_os = "android")]
        {
            let use_audio_track = current_device_profile()
                .as_ref()
                .is_some_and(|p| p.supports_native_dsd)
                && !{
                    #[cfg(feature = "uac2")]
                    {
                        crate::uac2::is_usb_session_active()
                    }
                    #[cfg(not(feature = "uac2"))]
                    {
                        false
                    }
                };
            let frame_rate = dsd_rate.byte_rate();
            if use_audio_track {
                log_info!(
                    "[AUDIO] DSD Native AudioTrack: dsd_rate={} Hz -> frame_rate={} Hz",
                    dsd_rate.sample_rate(),
                    frame_rate
                );
                return resolve_requested_output_sample_rate(Some(frame_rate));
            }
            #[cfg(feature = "uac2")]
            {
                if crate::uac2::is_usb_session_active() {
                    log_info!(
                        "[AUDIO] DSD Native USB: dsd_rate={} Hz -> frame_rate={} Hz",
                        dsd_rate.sample_rate(),
                        frame_rate
                    );
                    return resolve_requested_output_sample_rate(Some(frame_rate));
                }
            }
        }

        #[cfg(not(target_os = "android"))]
        {
            return resolve_requested_output_sample_rate(Some(dsd_rate.byte_rate()));
        }

        #[cfg(target_os = "android")]
        {
            return resolve_requested_output_sample_rate(Some(dsd_rate.byte_rate()));
        }
    }
    let existing_rate = read_audio_engine(|handle| handle.sample_rate()).unwrap_or(0);
    let target = resolve_dsd_pcm_sample_rate(dsd_rate, existing_rate);
    log_info!(
        "[AUDIO] DSD PCM decimation: dsd_rate={} Hz, existing_engine={} Hz -> target={} Hz",
        dsd_rate.sample_rate(),
        existing_rate,
        target
    );
    resolve_requested_output_sample_rate(Some(target))
}

fn verify_dsd_engine_rate(
    path: &PathBuf,
    mode: DsdOutputMode,
    engine_rate: u32,
) -> Result<(), String> {
    if !matches!(mode, DsdOutputMode::Native | DsdOutputMode::Dop) {
        return Ok(());
    }
    let decoder = open_dsd_decoder(path)
        .map_err(|e| format!("Failed to probe DSD rate for {}: {}", path.display(), e))?;
    let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate())
        .ok_or_else(|| format!("Unsupported DSD sample rate: {}", decoder.sample_rate()))?;
    let required_rate = match mode {
        DsdOutputMode::Native => dsd_rate.byte_rate(),
        DsdOutputMode::Dop => dsd_rate.dop_carrier_rate(),
        _ => return Ok(()),
    };
    if engine_rate != required_rate {
        return Err(format!(
            "DSD {:?} playback requires the output to run at exactly {} Hz, \
             but the engine is running at {} Hz. The current audio backend \
             does not support this DSD mode. Switch to PCM Decimation or \
             connect a DSD-capable DAC and enable direct USB mode.",
            mode, required_rate, engine_rate
        ));
    }
    Ok(())
}

fn verify_dop_passthrough(engine_rate: u32) -> Result<(), String> {
    let signature = read_audio_engine(|handle| handle.output_signature().to_string());
    let passthrough = read_audio_engine(|handle| {
        let rt = handle.output_runtime();
        rt.passthrough_allowed
    });

    let sig = signature.as_deref().unwrap_or("");
    let sig_matches_dop = sig.contains("dsd-dop:") || sig.contains("dsd-native:");
    let rate_matches = if let Some(rate_str) = sig.rsplit(':').next() {
        rate_str.parse::<u32>().ok() == Some(engine_rate)
    } else {
        false
    };

    if sig_matches_dop && rate_matches && passthrough.unwrap_or(false) {
        log::info!(
            "[AUDIO] DoP pre-flight OK: wire_rate={} signature={}",
            engine_rate,
            sig
        );
        return Ok(());
    }

    log::warn!(
        "[AUDIO] DoP pre-flight FAILED: Android may have resampled the carrier. \
         engine_rate={} signature={} passthrough={:?}. Degrading to PCM decimation.",
        engine_rate,
        sig,
        passthrough
    );

    Err(format!(
        "DoP passthrough verification failed: the output path did not confirm \
         bit-perfect DoP delivery at {} Hz (signature={}, passthrough={:?}). \
         Android likely resampled the carrier. Degrading to PCM decimation.",
        engine_rate, sig, passthrough
    ))
}

fn prepare_decoder_source(
    path: &PathBuf,
    output_sample_rate: u32,
    output_channels: usize,
) -> Result<(crate::audio::source::AudioSource, DecoderHandle), String> {
    match detect_file_type(path) {
        crate::audio::decoder_handle::FileType::Dsd => {
            let effective_mode = effective_dsd_output_mode(current_dsd_output_mode());
            verify_dsd_engine_rate(path, effective_mode, output_sample_rate)?;
            let (source, thread) = DsdDecoderThread::spawn(
                path.clone(),
                effective_mode,
                output_sample_rate,
                output_channels,
            )
            .map_err(|e| format!("Failed to decode DSD {}: {}", path.display(), e))?;
            Ok((source, DecoderHandle::Dsd(thread)))
        }
        crate::audio::decoder_handle::FileType::WavPack => {
            let (source, handle) =
                WavpackDecoderThread::spawn(path.clone(), output_sample_rate, output_channels)
                    .map_err(|e| format!("Failed to decode WavPack {}: {}", path.display(), e))?;
            Ok((source, handle))
        }
        crate::audio::decoder_handle::FileType::Standard => {
            let probe_result = probe_file(path.as_path())
                .map_err(|error| format!("Failed to probe {}: {}", path.display(), error))?;
            let file_rate = probe_result.source_info.original_sample_rate;
            if output_sample_rate != file_rate {
                log_warn!(
                    "[AUDIO] engine_sample_rate_hz={} decoded_file_sample_rate_hz={} — decoder resampling active",
                    output_sample_rate,
                    file_rate
                );
            } else {
                log_info!(
                    "[AUDIO] engine_sample_rate_hz matches decoded_file_sample_rate_hz ({} Hz); decoder resampling off",
                    file_rate
                );
            }

            let (source, thread) = DecoderThread::spawn_from_probe_result(
                probe_result,
                output_sample_rate,
                output_channels,
                None,
            )
            .map_err(|error| format!("Failed to decode {}: {}", path.display(), error))?;
            Ok((source, DecoderHandle::Symphonia(thread)))
        }
    }
}

// ============================================================================
// SHARED TYPES (available on all platforms)
// ============================================================================

/// Progress information returned to Dart.
#[derive(Debug, Clone)]
pub struct AudioProgress {
    /// Current position in seconds
    pub position_secs: f64,
    /// Total duration in seconds (if known)
    pub duration_secs: Option<f64>,
    /// Buffer fill level (0.0 to 1.0)
    pub buffer_level: f32,
}

/// Audio event types for Dart.
#[derive(Debug, Clone)]
pub enum AudioEventType {
    StateChanged {
        state: String,
    },
    Progress {
        position_secs: f64,
        duration_secs: Option<f64>,
        buffer_level: f32,
    },
    TrackEnded {
        path: String,
    },
    CrossfadeStarted {
        from_path: String,
        to_path: String,
    },
    Error {
        message: String,
    },
    NextTrackReady {
        path: String,
    },
}

/// Crossfade curve type for Dart.
#[derive(Debug, Clone, Copy)]
pub enum CrossfadeCurveType {
    EqualPower,
    Linear,
    SquareRoot,
    SCurve,
}

/// The currently available output capability classes for engine selection.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AudioCapabilityType {
    UsbDac,
    HiResInternal,
    Standard,
}

impl From<AudioCapability> for AudioCapabilityType {
    fn from(value: AudioCapability) -> Self {
        match value {
            AudioCapability::UsbDac => Self::UsbDac,
            AudioCapability::HiResInternal => Self::HiResInternal,
            AudioCapability::Standard => Self::Standard,
        }
    }
}

impl From<AudioCapabilityType> for AudioCapability {
    fn from(value: AudioCapabilityType) -> Self {
        match value {
            AudioCapabilityType::UsbDac => Self::UsbDac,
            AudioCapabilityType::HiResInternal => Self::HiResInternal,
            AudioCapabilityType::Standard => Self::Standard,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AudioCapabilityInfo {
    pub capabilities: Vec<AudioCapabilityType>,
    pub route_type: String,
    pub route_label: Option<String>,
    pub max_sample_rate: Option<u32>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AudioRuntimeDebugState {
    pub manager_engine: String,
    pub rust_initialized: bool,
    pub output_signature: Option<String>,
    pub sample_rate: Option<u32>,
    pub channels: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AudioRuntimeDebugJsonState {
    pub manager_engine: String,
    pub rust_initialized: bool,
    pub output_signature: Option<String>,
    pub sample_rate: Option<u32>,
    pub channels: Option<usize>,
    pub output_strategy: Option<String>,
    pub requested_sample_rate: Option<u32>,
    pub actual_sample_rate: Option<u32>,
    pub resampler_active: Option<bool>,
    pub passthrough_allowed: Option<bool>,
    pub verification_reason: Option<String>,
    pub direct_usb_active: Option<bool>,
    pub direct_usb_verified: Option<bool>,
    pub dsd_source_rate: Option<u32>,
    pub dsd_effective_mode: Option<String>,
    pub dsd_wire_rate: Option<u32>,
    pub dsd_transport: Option<String>,
}

impl From<AudioCapabilitySnapshot> for AudioCapabilityInfo {
    fn from(value: AudioCapabilitySnapshot) -> Self {
        Self {
            capabilities: value.capabilities.into_iter().map(Into::into).collect(),
            route_type: value.route_type,
            route_label: value.route_label,
            max_sample_rate: value.max_sample_rate,
        }
    }
}

impl From<AudioCapabilityInfo> for AudioCapabilitySnapshot {
    fn from(value: AudioCapabilityInfo) -> Self {
        AudioCapabilitySnapshot {
            capabilities: value.capabilities.into_iter().map(Into::into).collect(),
            route_type: value.route_type,
            route_label: value.route_label,
            max_sample_rate: value.max_sample_rate,
        }
        .normalize()
    }
}

// ============================================================================
// API FUNCTIONS
// ============================================================================

/// Check if native audio is available on this platform.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_is_native_available() -> bool {
    // Native audio is now available on all platforms including Android
    true
}

/// Initialize the audio engine.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_init() -> Result<(), String> {
    ENGINE_MANAGER.init();
    Ok(())
}

/// Check if the audio engine is initialized.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_is_initialized() -> bool {
    ENGINE_MANAGER.is_rust_initialized()
}

/// Enable or disable high-res mode. When enabled, the Rust engine is allowed
/// to initialize even if a DAC is not currently detected.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_high_res_mode(enabled: bool) {
    ENGINE_MANAGER.set_high_res_mode(enabled);
    #[cfg(all(feature = "uac2", target_os = "android"))]
    crate::uac2::set_android_direct_usb_enabled(!enabled);
}

/// Sync the Bit-perfect (DAP Internal) preference from Dart so the Rust engine manager
/// can factor it into engine selection and reuse decisions.
/// When toggled at runtime, the running engine's pipeline mode is switched
/// between Passthrough (bit-perfect) and Dsp (full processing) on DAP devices.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_dap_bit_perfect_enabled(enabled: bool) {
    ENGINE_MANAGER.set_dap_bit_perfect_enabled(enabled);

    #[cfg(target_os = "android")]
    {
        let is_dap = current_device_profile()
            .as_ref()
            .is_some_and(|p| p.is_dap());
        if is_dap {
            if let Err(e) =
                with_audio_engine(|handle| handle.set_pipeline_mode_passthrough(enabled))
            {
                log::warn!(
                    "audio_set_dap_bit_perfect_enabled({}): runtime pipeline switch skipped — {}",
                    enabled,
                    e
                );
            }
        }
    }
    #[cfg(not(target_os = "android"))]
    let _ = enabled;
}

/// Toggle experimental 432 Hz tuning. When enabled the engine leaves bit-perfect
/// passthrough, runs the DSP path, and pins playback speed at 432/440.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_432hz_tuning_enabled(enabled: bool) {
    ENGINE_MANAGER.set_432hz_tuning_enabled(enabled);
}

/// Set the DSD output mode from Dart. 0 = PCM decimation, 1 = DoP, 2 = Native, 3 = Auto.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_dsd_output_mode(mode: u8) {
    DSD_OUTPUT_MODE.store(mode.min(3), Ordering::Relaxed);
}

/// Toggle DSD bit-reverse override. When on, inverts the bit-order normalization
/// so that MSB-first sources get reversed and LSB-first sources pass through.
/// Use this to diagnose white-noise from wrong bit order.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_dsd_bit_reverse_override(enabled: bool) {
    crate::audio::dsd_engine::output::set_dsd_bit_reverse_override(enabled);
}

/// Update the current platform capability snapshot used for engine selection.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_set_capability_info(info: AudioCapabilityInfo) {
    ENGINE_MANAGER.set_capability_snapshot(info.into());
}

/// Inspect the current capability snapshot after native detection and platform hints are merged.
pub fn audio_get_capability_info(
    preferred_sample_rate: Option<u32>,
) -> Result<AudioCapabilityInfo, String> {
    ENGINE_MANAGER
        .capability_snapshot(preferred_sample_rate)
        .map(Into::into)
}

/// Return the currently selected engine.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_active_engine() -> String {
    match ENGINE_MANAGER.current_engine() {
        Some(AudioEngine::Default) => "default".to_string(),
        Some(AudioEngine::Rust) => "rust".to_string(),
        None => "uninitialized".to_string(),
    }
}

pub fn audio_get_runtime_debug_state() -> AudioRuntimeDebugState {
    let manager_engine = audio_get_active_engine();
    let rust_initialized = audio_is_initialized();
    let handle_state = read_audio_engine(|handle| {
        (
            handle.output_signature().to_string(),
            handle.sample_rate(),
            handle.channels(),
        )
    });

    AudioRuntimeDebugState {
        manager_engine,
        rust_initialized,
        output_signature: handle_state
            .as_ref()
            .map(|(signature, _, _)| signature.clone()),
        sample_rate: handle_state
            .as_ref()
            .map(|(_, sample_rate, _)| *sample_rate),
        channels: handle_state.as_ref().map(|(_, _, channels)| *channels),
    }
}

pub fn audio_get_runtime_debug_json_state() -> AudioRuntimeDebugJsonState {
    let base = audio_get_runtime_debug_state();
    let output_runtime = read_audio_engine(|handle| handle.output_runtime().clone());

    AudioRuntimeDebugJsonState {
        manager_engine: base.manager_engine,
        rust_initialized: base.rust_initialized,
        output_signature: base.output_signature,
        sample_rate: base.sample_rate,
        channels: base.channels,
        output_strategy: output_runtime.as_ref().map(|state| state.strategy.clone()),
        requested_sample_rate: output_runtime
            .as_ref()
            .map(|state| state.requested_sample_rate),
        actual_sample_rate: output_runtime
            .as_ref()
            .map(|state| state.actual_sample_rate),
        resampler_active: output_runtime.as_ref().map(|state| state.resampler_active),
        passthrough_allowed: output_runtime
            .as_ref()
            .map(|state| state.passthrough_allowed),
        verification_reason: output_runtime
            .as_ref()
            .and_then(|state| state.verification_reason.clone()),
        direct_usb_active: output_runtime.as_ref().map(|state| state.direct_usb_active),
        direct_usb_verified: output_runtime
            .as_ref()
            .map(|state| state.direct_usb_verified),
        dsd_source_rate: output_runtime
            .as_ref()
            .and_then(|state| state.dsd_source_rate),
        dsd_effective_mode: output_runtime
            .as_ref()
            .and_then(|state| state.dsd_effective_mode.clone()),
        dsd_wire_rate: output_runtime
            .as_ref()
            .and_then(|state| state.dsd_wire_rate),
        dsd_transport: output_runtime
            .as_ref()
            .and_then(|state| state.dsd_transport.clone()),
    }
}

/// Detect whether a DAC is present before attempting Rust engine initialization.
pub fn audio_is_dac_available(preferred_sample_rate: Option<u32>) -> Result<bool, String> {
    ENGINE_MANAGER.is_dac_available(preferred_sample_rate)
}

/// Prepare the Rust audio engine for the requested output rate before playback starts.
pub fn audio_prepare_engine(preferred_sample_rate: Option<u32>) -> Result<(), String> {
    ensure_audio_engine(resolve_requested_output_sample_rate(preferred_sample_rate)?)
}

/// Play an audio file.
pub fn audio_play(path: String) -> Result<(), String> {
    let path = PathBuf::from(&path);
    match detect_file_type(&path) {
        crate::audio::decoder_handle::FileType::Dsd => {
            let requested_mode = current_dsd_output_mode();
            let dsd_sample_rate = {
                let decoder = open_dsd_decoder(&path)
                    .map_err(|e| format!("Failed to probe DSD rate: {}", e))?;
                decoder.sample_rate()
            };
            let dsd_rate_enum = DsdRate::from_sample_rate(dsd_sample_rate);
            set_dsd_track_rate(dsd_sample_rate);
            let mut effective_mode =
                effective_dsd_output_mode_for_rate(requested_mode, dsd_rate_enum);
            if matches!(effective_mode, DsdOutputMode::Native | DsdOutputMode::Auto) {
                crate::audio::dsd_native_jni::dsd_track_preload_class();
            }
            if let Err(e) =
                ensure_audio_engine(resolve_dsd_engine_sample_rate(&path, effective_mode)?)
            {
                if e.starts_with("DSD_NATIVE_FALLBACK:") {
                    log::info!(
                        "[AUDIO] DSD Native unavailable ({}), falling back to DoP",
                        e
                    );
                    effective_mode = DsdOutputMode::Dop;
                    ensure_audio_engine_excluded(
                        resolve_dsd_engine_sample_rate(&path, effective_mode)?,
                        vec![OutputStrategy::DsdNative],
                    )?;
                } else {
                    return Err(e);
                }
            }
            let (mut output_sample_rate, mut output_channels) =
                with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
            verify_dsd_engine_rate(&path, effective_mode, output_sample_rate)?;
            if effective_mode == DsdOutputMode::Dop {
                if let Err(dop_err) = verify_dop_passthrough(output_sample_rate) {
                    log::info!(
                        "[AUDIO] DoP pre-flight failed ({}), degrading to PCM decimation",
                        dop_err
                    );
                    effective_mode = DsdOutputMode::PcmDecimation;
                    let pcm_rate = {
                        let decoder = open_dsd_decoder(&path)
                            .map_err(|e| format!("Failed to probe DSD rate: {}", e))?;
                        let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate())
                            .ok_or_else(|| format!("Unsupported DSD rate"))?;
                        resolve_dsd_pcm_sample_rate(dsd_rate, 0)
                    };
                    ensure_audio_engine_excluded(
                        resolve_requested_output_sample_rate(Some(pcm_rate))?,
                        vec![OutputStrategy::DsdNative],
                    )?;
                    output_sample_rate = with_audio_engine(|handle| Ok(handle.sample_rate()))?;
                    output_channels = with_audio_engine(|handle| Ok(handle.channels()))?;
                }
            }
            let (source, thread) =
                DsdDecoderThread::spawn(path, effective_mode, output_sample_rate, output_channels)
                    .map_err(|e| format!("Failed to decode DSD: {}", e))?;
            let is_raw = matches!(effective_mode, DsdOutputMode::Dop | DsdOutputMode::Native);
            with_audio_engine(|handle| {
                handle.set_dop_override(is_raw)?;
                handle.play_prepared(source, DecoderHandle::Dsd(thread))
            })
        }
        crate::audio::decoder_handle::FileType::WavPack => {
            clear_dsd_track_rate();
            ensure_audio_engine(resolve_requested_output_sample_rate(None)?)?;
            let (output_sample_rate, output_channels) =
                with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
            let (source, handle) =
                WavpackDecoderThread::spawn(path, output_sample_rate, output_channels)
                    .map_err(|e| format!("Failed to decode WavPack: {}", e))?;
            with_audio_engine(|engine| {
                engine.set_dop_override(false)?;
                engine.play_prepared(source, handle)
            })
        }
        crate::audio::decoder_handle::FileType::Standard => {
            let probe_result = probe_file(path.as_path())
                .map_err(|error| format!("Failed to probe {}: {}", path.display(), error))?;
            ensure_audio_engine(resolve_track_playback_output_sample_rate(Some(
                probe_result.source_info.original_sample_rate,
            ))?)?;
            let (output_sample_rate, output_channels) =
                with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
            let file_rate = probe_result.source_info.original_sample_rate;
            if output_sample_rate != file_rate {
                log_warn!(
                    "[AUDIO] engine_sample_rate_hz={} decoded_file_sample_rate_hz={} — decoder resampling active",
                    output_sample_rate,
                    file_rate
                );
            } else {
                log_info!(
                    "[AUDIO] engine_sample_rate_hz matches decoded_file_sample_rate_hz ({} Hz); decoder resampling off",
                    file_rate
                );
            }
            let (source, decoder_thread) = DecoderThread::spawn_from_probe_result(
                probe_result,
                output_sample_rate,
                output_channels,
                None,
            )
            .map_err(|error| format!("Failed to decode {}: {}", path.display(), error))?;
            with_audio_engine(|handle| {
                handle.set_dop_override(false)?;
                handle.play_prepared(source, DecoderHandle::Symphonia(decoder_thread))
            })
        }
    }
}

/// Queue the next track for gapless playback.
pub fn audio_queue_next(path: String) -> Result<(), String> {
    let path = PathBuf::from(path);
    if !audio_is_initialized() {
        match detect_file_type(&path) {
            crate::audio::decoder_handle::FileType::Dsd => {
                let requested_mode = current_dsd_output_mode();
                let dsd_sample_rate = {
                    let decoder = open_dsd_decoder(&path)
                        .map_err(|e| format!("Failed to probe DSD rate: {}", e))?;
                    decoder.sample_rate()
                };
                let dsd_rate_enum = DsdRate::from_sample_rate(dsd_sample_rate);
                set_dsd_track_rate(dsd_sample_rate);
                let mut effective_mode =
                    effective_dsd_output_mode_for_rate(requested_mode, dsd_rate_enum);
                if matches!(effective_mode, DsdOutputMode::Native | DsdOutputMode::Auto) {
                    crate::audio::dsd_native_jni::dsd_track_preload_class();
                }
                if let Err(e) =
                    ensure_audio_engine(resolve_dsd_engine_sample_rate(&path, effective_mode)?)
                {
                    if e.starts_with("DSD_NATIVE_FALLBACK:") {
                        log::info!(
                            "[AUDIO] DSD Native unavailable ({}), falling back to DoP",
                            e
                        );
                        effective_mode = DsdOutputMode::Dop;
                        ensure_audio_engine_excluded(
                            resolve_dsd_engine_sample_rate(&path, effective_mode)?,
                            vec![OutputStrategy::DsdNative],
                        )?;
                    } else {
                        return Err(e);
                    }
                }
                let (mut output_sample_rate, mut output_channels) =
                    with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
                verify_dsd_engine_rate(&path, effective_mode, output_sample_rate)?;
                if effective_mode == DsdOutputMode::Dop {
                    if let Err(dop_err) = verify_dop_passthrough(output_sample_rate) {
                        log::info!(
                            "[AUDIO] DoP pre-flight failed ({}), degrading to PCM decimation",
                            dop_err
                        );
                        effective_mode = DsdOutputMode::PcmDecimation;
                        let pcm_rate = {
                            let decoder = open_dsd_decoder(&path)
                                .map_err(|e| format!("Failed to probe DSD rate: {}", e))?;
                            let dsd_rate = DsdRate::from_sample_rate(decoder.sample_rate())
                                .ok_or_else(|| format!("Unsupported DSD rate"))?;
                            resolve_dsd_pcm_sample_rate(dsd_rate, 0)
                        };
                        ensure_audio_engine_excluded(
                            resolve_requested_output_sample_rate(Some(pcm_rate))?,
                            vec![OutputStrategy::DsdNative],
                        )?;
                        output_sample_rate = with_audio_engine(|handle| Ok(handle.sample_rate()))?;
                        output_channels = with_audio_engine(|handle| Ok(handle.channels()))?;
                    }
                }
                let (source, thread) = DsdDecoderThread::spawn(
                    path,
                    effective_mode,
                    output_sample_rate,
                    output_channels,
                )
                .map_err(|e| format!("Failed to decode DSD: {}", e))?;
                let is_raw = matches!(effective_mode, DsdOutputMode::Dop | DsdOutputMode::Native);
                return with_audio_engine(|handle| {
                    handle.set_dop_override(is_raw)?;
                    handle.queue_next_prepared(source, DecoderHandle::Dsd(thread))
                });
            }
            crate::audio::decoder_handle::FileType::WavPack => {
                ensure_audio_engine(resolve_requested_output_sample_rate(None)?)?;
                let (output_sample_rate, output_channels) =
                    with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
                let (source, wh) =
                    WavpackDecoderThread::spawn(path, output_sample_rate, output_channels)
                        .map_err(|e| format!("Failed to decode WavPack: {}", e))?;
                return with_audio_engine(|engine| {
                    engine.set_dop_override(false)?;
                    engine.queue_next_prepared(source, wh)
                });
            }
            crate::audio::decoder_handle::FileType::Standard => {
                clear_dsd_track_rate();
                let probe_result = probe_file(path.as_path())
                    .map_err(|error| format!("Failed to probe {}: {}", path.display(), error))?;
                ensure_audio_engine(resolve_track_playback_output_sample_rate(Some(
                    probe_result.source_info.original_sample_rate,
                ))?)?;
                let (output_sample_rate, output_channels) =
                    with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
                let file_rate = probe_result.source_info.original_sample_rate;
                if output_sample_rate != file_rate {
                    log_warn!(
                        "[AUDIO] engine_sample_rate_hz={} decoded_file_sample_rate_hz={} — decoder resampling active",
                        output_sample_rate,
                        file_rate
                    );
                } else {
                    log_info!(
                        "[AUDIO] engine_sample_rate_hz matches decoded_file_sample_rate_hz ({} Hz); decoder resampling off",
                        file_rate
                    );
                }
                let (source, decoder_thread) = DecoderThread::spawn_from_probe_result(
                    probe_result,
                    output_sample_rate,
                    output_channels,
                    None,
                )
                .map_err(|error| format!("Failed to decode {}: {}", path.display(), error))?;
                return with_audio_engine(|handle| {
                    handle.set_dop_override(false)?;
                    handle.queue_next_prepared(source, DecoderHandle::Symphonia(decoder_thread))
                });
            }
        }
    }

    let (output_sample_rate, output_channels) =
        with_audio_engine(|handle| Ok((handle.sample_rate(), handle.channels())))?;
    let (source, handle) = prepare_decoder_source(&path, output_sample_rate, output_channels)?;
    let effective_mode = effective_dsd_output_mode(current_dsd_output_mode());
    let is_raw = matches!(effective_mode, DsdOutputMode::Dop | DsdOutputMode::Native);
    with_audio_engine(|engine| {
        engine.set_dop_override(is_raw)?;
        engine.queue_next_prepared(source, handle)
    })
}

/// Pause playback.
pub fn audio_pause() -> Result<(), String> {
    with_audio_engine(|handle| handle.pause())
}

/// Resume playback after pause.
pub fn audio_resume() -> Result<(), String> {
    with_audio_engine(|handle| handle.resume())
}

/// Stop playback completely.
pub fn audio_stop() -> Result<(), String> {
    clear_dsd_track_rate();
    with_audio_engine(|handle| handle.stop())
}

/// Seek to a position in the current track.
pub fn audio_seek(position_secs: f64) -> Result<(), String> {
    with_audio_engine(|handle| handle.seek(position_secs))
}

/// Set the playback volume.
pub fn audio_set_volume(volume: f32) -> Result<(), String> {
    let clamped = volume.clamp(0.0, 1.0);
    set_pending_volume(clamped);
    let _ = with_audio_engine(|handle| handle.set_volume(clamped));
    Ok(())
}

/// Set graphic EQ: enabled and 10 band gains in dB (order = 32,64,125,250,500,1k,2k,4k,8k,16k Hz).
pub fn audio_set_equalizer(enabled: bool, gains_db: Vec<f32>) -> Result<(), String> {
    if gains_db.len() != 10 {
        return Err("Equalizer requires exactly 10 band gains".to_string());
    }
    let mut arr = [0.0f32; 10];
    arr.copy_from_slice(&gains_db[..10]);
    with_audio_engine(|handle| handle.set_equalizer(enabled, arr))
}

/// Configure compressor settings for the native audio engine.
pub fn audio_set_compressor(
    enabled: bool,
    threshold_db: f32,
    ratio: f32,
    attack_ms: f32,
    release_ms: f32,
    makeup_gain_db: f32,
) -> Result<(), String> {
    with_audio_engine(|handle| {
        handle.set_compressor(
            enabled,
            threshold_db,
            ratio,
            attack_ms,
            release_ms,
            makeup_gain_db,
        )
    })
}

/// Configure limiter settings for the native audio engine.
pub fn audio_set_limiter(
    enabled: bool,
    input_gain_db: f32,
    ceiling_db: f32,
    release_ms: f32,
) -> Result<(), String> {
    with_audio_engine(|handle| handle.set_limiter(enabled, input_gain_db, ceiling_db, release_ms))
}

/// Configure spatial/time FX settings for the native audio engine.
#[allow(clippy::too_many_arguments)]
pub fn audio_set_fx(
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
    with_audio_engine(|handle| {
        handle.set_fx(
            enabled, balance, tempo, damp, filter_hz, delay_ms, size, mix, feedback, width,
        )
    })
}

/// Configure crossfade settings.
///
/// The engine's own `is_crossfade_allowed()` trigger gate (plus the Dart-side
/// processing policy) authoritatively decide whether crossfade runs; the old
/// passthrough guard here was redundant and self-defeating — it blocked the
/// very `crossfade_forces_dsp` flip that lets crossfade escape passthrough.
pub fn audio_set_crossfade(enabled: bool, duration_secs: f32) -> Result<(), String> {
    set_pending_crossfade(enabled, duration_secs);
    with_audio_engine(|handle| handle.set_crossfade(enabled, duration_secs))
}

/// Skip to the next queued track.
pub fn audio_skip_to_next() -> Result<(), String> {
    with_audio_engine(|handle| handle.skip_to_next())
}

/// Set the playback speed.
pub fn audio_set_playback_speed(speed: f32) -> Result<(), String> {
    with_audio_engine(|handle| handle.set_playback_speed(speed))
}

/// Get the current playback speed.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_playback_speed() -> Option<f32> {
    read_audio_engine(|handle| handle.get_playback_speed())
}

/// Get the current playback state.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_state() -> String {
    let Some(handle_state) = read_audio_engine(|handle| handle.state()) else {
        return "uninitialized".to_string();
    };
    match handle_state {
        PlaybackState::Idle => "idle".to_string(),
        PlaybackState::Playing => "playing".to_string(),
        PlaybackState::Paused => "paused".to_string(),
        PlaybackState::Buffering => "buffering".to_string(),
        PlaybackState::Crossfading => "crossfading".to_string(),
        PlaybackState::Stopped => "stopped".to_string(),
    }
}

/// Get the current playback progress.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_progress() -> Option<AudioProgress> {
    read_audio_engine(|handle| handle.get_progress())
        .flatten()
        .map(|p| AudioProgress {
            position_secs: p.position_secs,
            duration_secs: p.duration_secs,
            buffer_level: p.buffer_level,
        })
}

/// Poll for audio events (non-blocking).
#[flutter_rust_bridge::frb(sync)]
pub fn audio_poll_event() -> Option<AudioEventType> {
    let event = read_audio_engine(|handle| handle.try_recv_event()).flatten()?;
    Some(match event {
        AudioEvent::StateChanged(state) => AudioEventType::StateChanged {
            state: match state {
                PlaybackState::Idle => "idle".to_string(),
                PlaybackState::Playing => "playing".to_string(),
                PlaybackState::Paused => "paused".to_string(),
                PlaybackState::Buffering => "buffering".to_string(),
                PlaybackState::Crossfading => "crossfading".to_string(),
                PlaybackState::Stopped => "stopped".to_string(),
            },
        },
        AudioEvent::Progress(p) => AudioEventType::Progress {
            position_secs: p.position_secs,
            duration_secs: p.duration_secs,
            buffer_level: p.buffer_level,
        },
        AudioEvent::TrackEnded { path } => AudioEventType::TrackEnded { path },
        AudioEvent::CrossfadeStarted { from_path, to_path } => {
            AudioEventType::CrossfadeStarted { from_path, to_path }
        }
        AudioEvent::Error { message } => AudioEventType::Error { message },
        AudioEvent::NextTrackReady { path } => AudioEventType::NextTrackReady { path },
    })
}

/// Set the crossfade curve type.
pub fn audio_set_crossfade_curve(curve: CrossfadeCurveType) -> Result<(), String> {
    let curve = match curve {
        CrossfadeCurveType::EqualPower => crate::audio::crossfader::CrossfadeCurve::EqualPower,
        CrossfadeCurveType::Linear => crate::audio::crossfader::CrossfadeCurve::Linear,
        CrossfadeCurveType::SquareRoot => crate::audio::crossfader::CrossfadeCurve::SquareRoot,
        CrossfadeCurveType::SCurve => crate::audio::crossfader::CrossfadeCurve::SCurve,
    };
    set_pending_crossfade_curve(curve);
    with_audio_engine(|handle| handle.set_crossfade_curve(curve))
}

/// Get the audio engine's sample rate.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_sample_rate() -> Option<u32> {
    read_audio_engine(|handle| handle.sample_rate())
}

/// Get the current track path.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_current_path() -> Option<String> {
    read_audio_engine(|handle| handle.get_current_path())
        .flatten()
        .map(|p| p.to_string_lossy().to_string())
}

/// Get the number of audio channels.
#[flutter_rust_bridge::frb(sync)]
pub fn audio_get_channels() -> Option<usize> {
    read_audio_engine(|handle| handle.channels())
}

/// Shutdown the audio engine.
pub fn audio_shutdown() -> Result<(), String> {
    ENGINE_MANAGER.shutdown()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio::crossfader::CrossfadeCurve;

    #[test]
    fn pending_crossfade_round_trip() {
        let _ = take_pending_crossfade();

        set_pending_crossfade(true, 5.0);
        set_pending_crossfade_curve(CrossfadeCurve::Linear);
        let (enabled, dur, curve) = take_pending_crossfade().expect("pending set");
        assert!(enabled);
        assert!((dur - 5.0).abs() < 1e-6);
        assert_eq!(curve, CrossfadeCurve::Linear);
        assert!(take_pending_crossfade().is_none(), "take must clear");

        set_pending_crossfade(false, 12.5);
        let (enabled, dur, _) = take_pending_crossfade().unwrap();
        assert!(!enabled, "disabled state must round-trip");
        assert!((dur - 12.5).abs() < 1e-6);
    }

    #[test]
    fn pending_crossfade_all_curves() {
        for (curve, expect) in [
            (CrossfadeCurve::EqualPower, CrossfadeCurve::EqualPower),
            (CrossfadeCurve::Linear, CrossfadeCurve::Linear),
            (CrossfadeCurve::SquareRoot, CrossfadeCurve::SquareRoot),
            (CrossfadeCurve::SCurve, CrossfadeCurve::SCurve),
        ] {
            let _ = take_pending_crossfade();
            set_pending_crossfade(true, 3.0);
            set_pending_crossfade_curve(curve);
            let (_, _, got) = take_pending_crossfade().unwrap();
            assert_eq!(got, expect, "curve {:?} did not round-trip", curve);
        }
    }
}
