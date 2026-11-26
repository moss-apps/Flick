use crate::dev_eprintln;

use crate::audio::commands::AudioEvent;
use crate::audio::engine::AudioCallbackData;
use crate::uac2::endpoint::{select_explicit_feedback_endpoint, FeedbackEndpointCandidate};
use crate::uac2::iso_completion_diagnostics::{
    summarize_iso_batch, IsoCompletionDiagnostic, IsoSlotDiagnostic,
};
use crate::uac2::iso_packet_validation::{
    account_pcm_completion, iso_transfer_status_label, validate_iso_packet_descriptors,
    CompletionStats,
};
use crate::uac2::iso_transport_loss::{
    lost_frame_budget, LossLimits, LossLogGate, LossTracker, UrbLoss,
};
use crate::uac2::payload_audit_latch::PayloadAuditLatch;
use crate::uac2::volume_control::{
    normalize_volume, parse_uac2_volume_ranges, quantize_volume, read_hardware_volume_snapshot, volume_bounds,
    AudioControlProtocol, VolumeRange,
};
use crate::uac2::{
    iso_packet_scheduler::{IsoPacketScheduler, IsoQueueGeometry},
    AudioControlParser, DescriptorIter,
};
use crossbeam_channel::Sender;
use libusb1_sys::{
    constants::{
        LIBUSB_TRANSFER_CANCELLED, LIBUSB_TRANSFER_COMPLETED, LIBUSB_TRANSFER_ERROR,
        LIBUSB_TRANSFER_NO_DEVICE, LIBUSB_TRANSFER_OVERFLOW, LIBUSB_TRANSFER_STALL,
        LIBUSB_TRANSFER_TIMED_OUT,
    },
    libusb_alloc_transfer, libusb_cancel_transfer, libusb_fill_interrupt_transfer,
    libusb_fill_iso_transfer, libusb_free_transfer, libusb_iso_packet_descriptor,
    libusb_submit_transfer, libusb_transfer, libusb_transfer_cb_fn,
};
use log::{error as log_error, info as log_info, warn as log_warn};
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use rusb::{
    disable_device_discovery, ConfigDescriptor, Context, Device, DeviceHandle, Direction, Speed,
    SyncType, TransferType, UsageType, UsbContext,
};
use serde::Serialize;
use std::collections::HashSet;
use std::ffi::c_void;
use std::os::fd::RawFd;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex as StdMutex, Once};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

#[cfg(target_os = "android")]
fn set_audio_thread_priority() -> Result<(), std::io::Error> {
    crate::audio::thread_priority::raise_audio_render_priority()
}

const USB_CLASS_AUDIO: u8 = 0x01;
const USB_SUBCLASS_AUDIOCONTROL: u8 = 0x01;
const USB_SUBCLASS_AUDIOSTREAMING: u8 = 0x02;
const USB_DT_CS_INTERFACE: u8 = 0x24;
const USB_DIR_IN: u8 = 0x80;
const USB_DIR_OUT: u8 = 0x00;
const USB_TYPE_CLASS: u8 = 0x20;
const USB_RECIP_INTERFACE: u8 = 0x01;
const USB_RECIP_ENDPOINT: u8 = 0x02;
const UAC2_CLOCK_SOURCE: u8 = 0x0a;
const UAC2_AS_GENERAL: u8 = 0x01;
const UAC2_FORMAT_TYPE: u8 = 0x02;
const UAC2_FORMAT_TYPE_I: u8 = 0x01;
const UAC2_REQUEST_SET_CUR: u8 = 0x01;
const UAC2_REQUEST_GET_CUR: u8 = 0x01;
const UAC2_REQUEST_GET_RANGE: u8 = 0x02;
const UAC1_REQUEST_GET_CUR: u8 = 0x81;
const UAC2_CLOCK_SOURCE_SAM_FREQ_CONTROL: u16 = 0x0100;
const UAC2_CLOCK_SOURCE_CLOCK_VALID_CONTROL: u16 = 0x0200;
const UAC1_SAM_FREQ_CONTROL: u16 = 0x0100;
const UAC2_INPUT_TERMINAL: u8 = 0x02;
const UAC2_OUTPUT_TERMINAL: u8 = 0x03;
const UAC2_FEATURE_UNIT: u8 = 0x06;
const FORMAT_TAG_PCM: u16 = 0x0001;
const FORMAT_TAG_PCM8: u16 = 0x0002;
const FORMAT_TAG_IEEE_FLOAT: u16 = 0x0003;
const FORMAT_TAG_DSD: u16 = 0x0008;
const UAC1_REQUEST_GET_MIN: u8 = 0x82;
const UAC1_REQUEST_GET_MAX: u8 = 0x83;
const UAC1_REQUEST_GET_RES: u8 = 0x84;
const UAC2_FEATURE_UNIT_MUTE_CONTROL: u16 = 0x0100;
const UAC2_FEATURE_UNIT_VOLUME_CONTROL: u16 = 0x0200;
const ISO_TRANSFER_TIMEOUT_MS: u32 = 1000;
const ANDROID_USB_BUFFER_CAPACITY_MS: usize = 200;
const ANDROID_USB_BUFFER_TARGET_MS: usize = 100;
const ANDROID_USB_RENDER_CHUNK_MS: usize = 10;
const ANDROID_USB_RENDER_POLL_MS: u64 = 2;
// Later URBs may already be on the wire, so a lost PCM packet is never
// replayed. Bound both consecutive interrupted completions and the cumulative
// PCM deficit over the life of this stream.
const ANDROID_USB_MAX_CONSECUTIVE_LOSSY_URBS: u32 = 3;
const ANDROID_USB_MAX_LOST_AUDIO_MS: u64 = 100;
// Loss log lines: the first few immediately, then at most one per interval.
const ANDROID_USB_LOSS_LOG_BURST: u32 = 4;
const ANDROID_USB_LOSS_LOG_MIN_INTERVAL_MS: u64 = 1_000;
const ANDROID_USB_REQUIRE_VERIFIED_RATE_DEFAULT: bool = true;
const ANDROID_USB_CLOCK_SETTLE_DELAY_MS_DEFAULT: u64 = 20;
const ANDROID_USB_FEEDBACK_TIMEOUT_MS: u32 = 50;
const ANDROID_USB_FEEDBACK_POLL_WINDOW_MS: u32 = 16;
const ANDROID_USB_FEEDBACK_STALE_WARN_MS: u64 = 500;
const ANDROID_USB_PAYLOAD_FLICKER_GRACE_MS: u64 = 1500;
const ANDROID_USB_LOUD_RENDER_LOG_THRESHOLD: f32 = 0.1;
const ANDROID_USB_LOUD_TRANSFER_LOG_INTERVAL: u64 = 32;
const ANDROID_USB_TIMING_LOG_INTERVAL: u64 = 128;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum DacClockPolicy {
    AllowUnverified,
    RequireVerifiedRate,
    Force48kHzOnly,
}

struct DacQuirk {
    vendor_id: u16,
    product_id: u16,
    product_name_contains: &'static str,
    clock_policy: DacClockPolicy,
    settle_delay_ms: u64,
    prefer_padded_24bit_transport: bool,
}

/// DSD-specific quirk for UAC2 DACs where the descriptors may be
/// ambiguous or missing. Mirrors Linux `sound/usb/quirks.c` approach.
#[derive(Debug, Clone, Copy)]
struct DsdQuirk {
    vendor_id: u16,
    product_id: u16,
    product_name_contains: &'static str,
    /// Expected subslot_size for native DSD (1=U8, 2=U16, 4=U32).
    preferred_subslot: u8,
    /// Byte order on the wire for DSD_U32: true = BE (most common, XMOS-style),
    /// false = LE.
    big_endian: bool,
    /// Per-byte bit reversal (some DACs reverse bit order within each byte),
    /// independent of the DSF-LSB→MSB normalization in the decoder pipeline.
    bit_reverse: bool,
}

const KNOWN_DAC_QUIRKS: &[DacQuirk] = &[DacQuirk {
    vendor_id: 12230,
    product_id: 61546,
    product_name_contains: "MOONDROP Dawn Pro",
    clock_policy: DacClockPolicy::RequireVerifiedRate,
    settle_delay_ms: 50,
    prefer_padded_24bit_transport: true,
}];

const KNOWN_DSD_QUIRKS: &[DsdQuirk] = &[
    // MOONDROP Dawn Pro: dual CS43131, likely DSD_U32_BE (XMOS-style bridge).
    DsdQuirk {
        vendor_id: 12230,
        product_id: 61546,
        product_name_contains: "MOONDROP Dawn Pro",
        preferred_subslot: 4,
        big_endian: true,
        bit_reverse: false,
    },
];

/// Resolve a DSD quirk by merging the legacy table with the unified
/// `QUIRK_DATABASE`. Returns an owned `DsdQuirk` so callers can read every
/// field (`big_endian`, `bit_reverse`, `preferred_subslot`) in one shot.
fn resolve_dsd_quirk(
    vendor_id: u16,
    product_id: u16,
    product_name: &str,
) -> Option<DsdQuirk> {
    for quirk in KNOWN_DSD_QUIRKS {
        if quirk.vendor_id == vendor_id
            && quirk.product_id == product_id
            && product_name.contains(quirk.product_name_contains)
        {
            return Some(*quirk);
        }
    }
    use crate::uac2::quirk::UsbAudioQuirk;
    let entry = crate::uac2::quirk::QUIRK_DATABASE.lookup(vendor_id, product_id, product_name);
    let mut subslot = 4u8;
    let mut big_endian = false;
    let mut bit_reverse = false;
    let mut found = false;
    for q in &entry {
        match q {
            UsbAudioQuirk::DsdSubslotSize(n) => {
                subslot = *n;
                found = true;
            }
            UsbAudioQuirk::DsdBigEndian => {
                big_endian = true;
                found = true;
            }
            UsbAudioQuirk::DsdBitReverse => {
                bit_reverse = true;
                found = true;
            }
            _ => {}
        }
    }
    if !found {
        return None;
    }
    Some(DsdQuirk {
        vendor_id,
        product_id,
        product_name_contains: "",
        preferred_subslot: subslot,
        big_endian,
        bit_reverse,
    })
}

/// Resolve the DSD quirk for a live USB device, reading the product name from
/// the string descriptor so legacy name-contains matching still works. Used at
/// enumeration/candidate-selection where only `Device`/`DeviceHandle` are on
/// hand. A failed descriptor read yields an empty name → VID/PID-only match.
fn resolve_dsd_quirk_for_device(
    device: &Device<Context>,
    handle: &DeviceHandle<Context>,
) -> Option<DsdQuirk> {
    let descriptor = device.device_descriptor().ok()?;
    let product_name = descriptor
        .product_string_index()
        .and_then(|idx| handle.read_string_descriptor_ascii(idx).ok())
        .unwrap_or_default();
    resolve_dsd_quirk(
        descriptor.vendor_id(),
        descriptor.product_id(),
        &product_name,
    )
}

fn lookup_dac_quirk(
    vendor_id: u16,
    product_id: u16,
    product_name: &str,
) -> Option<&'static DacQuirk> {
    for quirk in KNOWN_DAC_QUIRKS {
        if quirk.vendor_id == vendor_id
            && quirk.product_id == product_id
            && product_name.contains(quirk.product_name_contains)
        {
            return Some(quirk);
        }
    }
    // Fall back to unified database (shim — converts UsbAudioQuirk into DacQuirk values).
    // Full migration planned; for now KNOWN_DAC_QUIRKS covers all entries.
    None
}

fn device_prefers_padded_24bit_transport(device: &Device<Context>) -> bool {
    let Ok(descriptor) = device.device_descriptor() else {
        return false;
    };

    // Check legacy quirk table.
    if KNOWN_DAC_QUIRKS.iter().any(|quirk| {
        quirk.prefer_padded_24bit_transport
            && quirk.vendor_id == descriptor.vendor_id()
            && quirk.product_id == descriptor.product_id()
    }) {
        return true;
    }

    // Check unified database (product name lookup requires an open handle — skip if unavailable).
    false
}

fn resolve_dac_clock_policy(device: &AndroidDirectUsbDevice) -> DacClockPolicy {
    if let Some(quirk) = lookup_dac_quirk(device.vendor_id, device.product_id, &device.product_name)
    {
        return quirk.clock_policy;
    }
    // Query unified database.
    let entry = crate::uac2::quirk::QUIRK_DATABASE.lookup(
        device.vendor_id,
        device.product_id,
        &device.product_name,
    );
    if entry.contains(&crate::uac2::quirk::UsbAudioQuirk::RequireVerifiedRate) {
        return DacClockPolicy::RequireVerifiedRate;
    }
    if entry.contains(&crate::uac2::quirk::UsbAudioQuirk::Force48kHzOnly) {
        return DacClockPolicy::Force48kHzOnly;
    }
    DacClockPolicy::AllowUnverified
}

fn resolve_dac_settle_delay_ms(device: &AndroidDirectUsbDevice) -> u64 {
    if let Some(quirk) = lookup_dac_quirk(device.vendor_id, device.product_id, &device.product_name)
    {
        return quirk.settle_delay_ms;
    }
    // Query unified database for SettleDelayMs quirk.
    let entry = crate::uac2::quirk::QUIRK_DATABASE.lookup(
        device.vendor_id,
        device.product_id,
        &device.product_name,
    );
    for q in &entry {
        if let &crate::uac2::quirk::UsbAudioQuirk::SettleDelayMs(ms) = q {
            return ms;
        }
    }
    ANDROID_USB_CLOCK_SETTLE_DELAY_MS_DEFAULT
}

fn transport_container_preference_rank(
    candidate: &AndroidIsoStreamCandidate,
    playback_format: AndroidDirectUsbPlaybackFormat,
    prefer_padded_24bit_transport: bool,
) -> u8 {
    if !prefer_padded_24bit_transport || playback_format.bit_depth != 24 {
        return 0;
    }

    match (candidate.bit_resolution, candidate.subslot_size) {
        (24, 4) => 0,
        (24, 3) => 1,
        _ => 2,
    }
}

#[derive(Debug)]
struct AndroidDirectUsbOwnedFd(RawFd);

impl Drop for AndroidDirectUsbOwnedFd {
    fn drop(&mut self) {
        if self.0 >= 0 {
            unsafe {
                libc::close(self.0);
            }
        }
    }
}

#[derive(Debug, Clone)]
pub struct AndroidDirectUsbDevice {
    pub fd: RawFd,
    _fd_owner: Arc<AndroidDirectUsbOwnedFd>,
    claimed_interfaces: Arc<[u8]>,
    pub vendor_id: u16,
    pub product_id: u16,
    pub product_name: String,
    pub device_name: Option<String>,
}

impl AndroidDirectUsbDevice {
    pub fn try_new(
        fd: RawFd,
        vendor_id: u16,
        product_id: u16,
        product_name: String,
        device_name: Option<String>,
        claimed_interfaces: Vec<u8>,
    ) -> Result<Self, String> {
        let duplicated_fd = unsafe { libc::dup(fd) };
        if duplicated_fd < 0 {
            return Err(format!(
                "Failed to duplicate Android USB file descriptor: {}",
                std::io::Error::last_os_error()
            ));
        }

        Ok(Self {
            fd: duplicated_fd,
            _fd_owner: Arc::new(AndroidDirectUsbOwnedFd(duplicated_fd)),
            claimed_interfaces: claimed_interfaces.into(),
            vendor_id,
            product_id,
            product_name,
            device_name,
        })
    }
}

trait FeatureUnitControl {
    fn feature_unit_control(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        data: &mut [u8],
    ) -> std::io::Result<usize>;
}

impl FeatureUnitControl for AndroidDirectUsbDevice {
    fn feature_unit_control(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        data: &mut [u8],
    ) -> std::io::Result<usize> {
        if !self.claimed_interfaces.contains(&(index as u8)) {
            return Err(std::io::Error::other("AudioControl interface is not claimed"));
        }
        let length = u16::try_from(data.len()).map_err(std::io::Error::other)?;
        let transfer = UsbfsControlTransfer {
            request_type,
            request,
            value,
            index,
            length,
            timeout_ms: 1000,
            data: data.as_mut_ptr().cast(),
        };
        // This synchronous ioctl does not reap URBs. A separate libusb control
        // context on the same fd could consume the output context's completions.
        let result = unsafe { libc::ioctl(self.fd, USBDEVFS_CONTROL, &transfer) };
        if result < 0 {
            return Err(std::io::Error::last_os_error());
        }
        Ok(result as usize)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DsdTransportMode {
    None,
    DoP,
    Native,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AndroidDirectUsbPlaybackFormat {
    pub sample_rate: u32,
    pub bit_depth: u8,
    pub channels: u16,
    pub is_dop: bool,
    pub dsd_transport: DsdTransportMode,
    /// DSD 1-bit sample rate (e.g. 2_822_400 for DSD64). Set only when
    /// dsd_transport == Native. The wire rate is computed as
    /// `dsd_bit_rate / (8 * subslot_size)` after the alt-setting is chosen.
    pub dsd_bit_rate: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum DacMode {
    FullControl,
    FixedClock,
    AdaptiveStreaming,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AndroidDirectUsbEngineState {
    Idle,
    UsbInit,
    UsbReady,
    Streaming,
    Error,
    Fallback,
}

#[derive(Debug, Clone)]
struct AndroidDirectUsbLifecycleState {
    engine_state: AndroidDirectUsbEngineState,
    reason: Option<String>,
}

impl Default for AndroidDirectUsbLifecycleState {
    fn default() -> Self {
        Self {
            engine_state: AndroidDirectUsbEngineState::Idle,
            reason: None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct AndroidDirectUsbDebugState {
    pub registered: bool,
    pub engine_state: Option<String>,
    pub engine_state_reason: Option<String>,
    pub requested_playback_sample_rate: Option<u32>,
    pub requested_playback_bit_depth: Option<u8>,
    pub requested_playback_channels: Option<u16>,
    pub device_name: Option<String>,
    pub product_name: Option<String>,
    pub playback_format_sample_rate: Option<u32>,
    pub playback_format_bit_depth: Option<u8>,
    pub playback_format_channels: Option<u16>,
    pub lock_requested: bool,
    pub stream_active: bool,
    pub idle_lock_held: bool,
    pub active_interface_number: Option<u8>,
    pub active_alt_setting: Option<u8>,
    pub active_endpoint_address: Option<u8>,
    pub active_endpoint_interval: Option<u8>,
    pub active_service_interval_us: Option<u32>,
    pub active_max_packet_bytes: Option<usize>,
    pub transport_format: Option<String>,
    pub transport_channels: Option<u16>,
    pub transport_subslot_size: Option<u8>,
    pub transport_bit_resolution: Option<u8>,
    pub advertised_sample_rates: Vec<u32>,
    pub active_sync_type: Option<String>,
    pub active_usage_type: Option<String>,
    pub active_refresh: Option<u8>,
    pub active_synch_address: Option<u8>,
    pub clock_interface_number: Option<u8>,
    pub clock_id: Option<u8>,
    pub clock_requested_sample_rate: Option<u32>,
    pub clock_reported_sample_rate: Option<u32>,
    pub clock_control_attempted: bool,
    pub clock_control_succeeded: bool,
    pub clock_verification_passed: bool,
    pub require_verified_rate: bool,
    pub dac_clock_policy: Option<String>,
    pub dac_mode: Option<String>,
    pub resampling_active: bool,
    pub last_error: Option<String>,
    pub direct_mode_refusal_reason: Option<String>,
    pub usb_stream_stable: bool,
    pub bit_perfect_verified: bool,
    pub pcm_payload_verified: bool,
    pub dsd_payload_verified: bool,
    pub payload_constant_for_ms: Option<u64>,
    pub software_volume_active: bool,
    pub hardware_volume_supported: bool,
    pub hardware_mute_supported: bool,
    pub hardware_volume_normalized: Option<f64>,
    pub hardware_mute_active: Option<bool>,
    pub hardware_volume_min_raw: Option<i16>,
    pub hardware_volume_max_raw: Option<i16>,
    pub hardware_volume_resolution_raw: Option<i16>,
    pub hardware_volume_error: Option<String>,
    pub hardware_volume_generation: u64,
    pub feedback_endpoint_present: bool,
    pub feedback_endpoint_address: Option<u8>,
    pub feedback_transfer_type: Option<String>,
    pub packet_schedule_frames_preview: Vec<u32>,
    pub supported_sample_rates: Vec<u32>,
    pub supported_bit_depths: Vec<u8>,
    pub supported_channels: Vec<u16>,
    pub available_alt_settings: Vec<AndroidDirectUsbAltCapability>,
    pub buffer_fill_ms: Option<u32>,
    pub buffer_capacity_ms: Option<u32>,
    pub buffer_target_ms: Option<u32>,
    pub frames_per_packet: Option<u32>,
    pub underrun_count: Option<u64>,
    pub producer_frames: Option<u64>,
    pub consumer_frames: Option<u64>,
    /// PCM frames that could not be credited as delivered this stream.
    pub lost_frames: Option<u64>,
    pub data_urb_timeouts: Option<u64>,
    pub transport_unverified: bool,
    pub drift_ms_from_target: Option<i32>,
    pub transfer_queue_depth: Option<u32>,
    pub completed_transfers: Option<u64>,
    pub last_transfer_turnaround_us: Option<u64>,
    pub max_transfer_turnaround_us: Option<u64>,
    pub last_submit_gap_us: Option<u64>,
    pub max_submit_gap_us: Option<u64>,
    pub effective_consumer_rate_milli_hz: Option<u64>,
}

#[derive(Debug, Clone)]
struct AndroidDirectUsbState {
    device: AndroidDirectUsbDevice,
    requested_playback_format: Option<AndroidDirectUsbPlaybackFormat>,
    playback_format: Option<AndroidDirectUsbPlaybackFormat>,
    lock_requested: bool,
    stream_active: bool,
    active_transport: Option<AndroidDirectUsbActiveTransport>,
    capability_model: Option<AndroidDirectUsbCapabilityModel>,
    clock_status: Option<AndroidDirectUsbClockStatus>,
    clock_control_attempted: bool,
    clock_control_succeeded: bool,
    clock_verification_passed: bool,
    require_verified_rate: bool,
    dac_clock_policy: DacClockPolicy,
    dac_mode: DacMode,
    last_error: Option<String>,
    direct_mode_refusal_reason: Option<String>,
    usb_stream_stable: bool,
    bit_perfect_verified: bool,
    software_volume_active: bool,
    hardware_volume_control: Option<AndroidDirectUsbHardwareVolumeControl>,
    hardware_volume_generation: u64,
    hardware_volume_error: Option<String>,
    hardware_volume_normalized: Option<f64>,
    hardware_mute_active: Option<bool>,
    pending_hardware_volume_restore: Option<f64>,
    packet_schedule_frames_preview: Vec<u32>,
    runtime_stats: Option<Arc<AndroidDirectUsbRuntimeStats>>,
}

#[derive(Debug, Clone)]
struct AndroidDirectUsbActiveTransport {
    interface_number: u8,
    alt_setting: u8,
    endpoint_address: u8,
    endpoint_interval: u8,
    service_interval_us: u32,
    max_packet_bytes: usize,
    format_tag: String,
    channels: u16,
    subslot_size: u8,
    bit_resolution: u8,
    sample_rates: Vec<u32>,
    sync_type: String,
    usage_type: String,
    refresh: u8,
    synch_address: u8,
    feedback_endpoint_address: Option<u8>,
    feedback_transfer_type: Option<String>,
}

#[derive(Debug, Clone)]
struct AndroidDirectUsbClockStatus {
    interface_number: u8,
    clock_id: u8,
    requested_sample_rate: u32,
    reported_sample_rate: Option<u32>,
}

#[derive(Debug, Clone)]
struct AndroidDirectUsbClockApplyOutcome {
    clock_ok: bool,
    rate_verified: bool,
    reported_sample_rate: Option<u32>,
    known_mismatch: bool,
    set_cur_succeeded: bool,
    message: Option<String>,
}

#[derive(Debug, Clone)]
struct AndroidDirectUsbHardwareVolumeControl {
    interface_number: u8,
    feature_unit_id: u8,
    protocol: AudioControlProtocol,
    volume_channels: Vec<u16>,
    ranges: Vec<VolumeRange>,
    mute_channel: Option<u16>,
    min_volume_raw: i16,
    max_volume_raw: i16,
    resolution_raw: i16,
}

#[derive(Debug, Clone, Serialize, Default)]
struct AndroidDirectUsbCapabilityModel {
    supported_sample_rates: Vec<u32>,
    supported_bit_depths: Vec<u8>,
    supported_channels: Vec<u16>,
    alt_settings: Vec<AndroidDirectUsbAltCapability>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AndroidDirectUsbAltCapability {
    pub interface_number: u8,
    pub alt_setting: u8,
    pub endpoint_address: u8,
    pub endpoint_interval: u8,
    pub service_interval_us: u32,
    pub max_packet_bytes: usize,
    pub format_tag: String,
    pub channels: u16,
    pub subslot_size: u8,
    pub bit_resolution: u8,
    pub sample_rates: Vec<u32>,
    pub sync_type: String,
    pub usage_type: String,
    pub refresh: u8,
    pub synch_address: u8,
}

#[derive(Debug)]
struct AndroidDirectUsbRuntimeStats {
    sample_rate: u32,
    channels: usize,
    buffer_capacity_samples: usize,
    buffer_target_samples: usize,
    transfer_queue_depth: AtomicUsize,
    frames_per_packet: AtomicUsize,
    buffered_samples: AtomicUsize,
    underrun_count: AtomicU64,
    producer_frames: AtomicU64,
    consumer_frames: AtomicU64,
    /// PCM frames not credited in `consumer_frames` after a short or timed-out
    /// completion whose packet metadata could be accounted for.
    lost_frames: AtomicU64,
    short_packets: AtomicU64,
    zero_packets: AtomicU64,
    /// Data-endpoint URBs libusb reported as timed out. Unrelated to the
    /// feedback endpoint's `timeouts=` in the `[USB-TIMING]` log.
    data_urb_timeouts: AtomicU64,
    /// Remains set for this stream after a loss, timeout or fatal error.
    transport_unverified: AtomicBool,
    completed_transfers: AtomicU64,
    last_transfer_turnaround_us: AtomicU64,
    max_transfer_turnaround_us: AtomicU64,
    last_submit_gap_us: AtomicU64,
    max_submit_gap_us: AtomicU64,
    effective_consumer_rate_milli_hz: AtomicU64,
    /// Peak of the last queued PCM block before master gain.
    last_push_max_abs_f32_bits: AtomicU32,
}

#[derive(Debug)]
struct AndroidDirectUsbPcmRingBuffer {
    /// Unscaled f32 bits for PCM, unchanged bitstream words for DSD/DoP.
    samples: Vec<i32>,
    capacity_samples: usize,
    channels: usize,
    read_index: usize,
    write_index: usize,
    len_samples: usize,
    dop_marker_is_fa: bool,
    flush_generation: u64,
    /// Hold wire silence until the ring can fill a transfer after a flush or
    /// a pause during priming.
    refill_pending: bool,
}

struct AndroidDirectUsbLock {
    device_fd: RawFd,
    context: Context,
    handle: DeviceHandle<Context>,
    claimed_interfaces: Arc<[u8]>,
}

struct AndroidDirectUsbClaimedHandle {
    device_fd: RawFd,
    context: Context,
    handle: DeviceHandle<Context>,
    claimed_interfaces: Arc<[u8]>,
}

// linux/usbdevice_fs.h; use libc's architecture-specific ioctl encoding.
#[repr(C)]
struct UsbfsControlTransfer {
    request_type: u8,
    request: u8,
    value: u16,
    index: u16,
    length: u16,
    timeout_ms: u32,
    data: *mut c_void,
}

#[repr(C)]
struct UsbfsSetInterface {
    interface: libc::c_uint,
    altsetting: libc::c_uint,
}

const USBDEVFS_CONTROL: libc::Ioctl = libc::_IOWR::<UsbfsControlTransfer>(b'U' as u32, 0);
const USBDEVFS_SETINTERFACE: libc::Ioctl = libc::_IOR::<UsbfsSetInterface>(b'U' as u32, 4);

#[derive(Debug)]
struct AndroidIsoStreamCandidate {
    interface_number: u8,
    alt_setting: u8,
    endpoint_address: u8,
    endpoint_interval: u8,
    service_interval_us: u32,
    usb_speed: Speed,
    max_packet_bytes: usize,
    sync_type: SyncType,
    usage_type: UsageType,
    format_tag: u16,
    channels: u16,
    subslot_size: u8,
    bit_resolution: u8,
    sample_rates: Vec<u32>,
    refresh: u8,
    synch_address: u8,
    feedback_endpoint: Option<AndroidUsbFeedbackEndpoint>,
    /// bTerminalLink from the AS_GENERAL descriptor, used to trace the
    /// UAC2 topology to the correct Clock Entity.
    terminal_link: Option<u8>,
    is_uac1: bool,
}

#[derive(Debug, Clone, Copy)]
struct AndroidUsbFeedbackEndpoint {
    address: u8,
    transfer_type: TransferType,
    interval: u8,
    service_interval_us: u32,
    max_packet_bytes: usize,
}

#[derive(Debug, Clone, Copy)]
struct AudioControlClock {
    interface_number: u8,
    clock_id: u8,
}

#[derive(Debug, Clone, Copy)]
struct SamplingFrequencySubrange {
    min: u32,
    max: u32,
    res: u32,
}

#[derive(Debug, Clone)]
struct AndroidStreamingInterfaceFormat {
    format_tag: u16,
    channels: u16,
    subslot_size: u8,
    bit_resolution: u8,
    terminal_link: Option<u8>,
    is_uac1: bool,
    sample_rate_ranges: Vec<SamplingFrequencySubrange>,
}

#[derive(Debug)]
struct IsoTransferCompletion {
    status: StdMutex<Option<i32>>,
    completed_at: StdMutex<Option<Instant>>,
    actual_length: AtomicUsize,
}

impl IsoTransferCompletion {
    fn new() -> Self {
        Self {
            status: StdMutex::new(None),
            completed_at: StdMutex::new(None),
            actual_length: AtomicUsize::new(0),
        }
    }

    fn reset(&self) {
        match self.status.lock() {
            Ok(mut guard) => *guard = None,
            Err(poisoned) => *poisoned.into_inner() = None,
        }
        match self.completed_at.lock() {
            Ok(mut guard) => *guard = None,
            Err(poisoned) => *poisoned.into_inner() = None,
        }
        self.actual_length.store(0, Ordering::Release);
    }

    fn take(&self) -> Option<(i32, Instant, usize)> {
        let status = match self.status.lock() {
            Ok(mut guard) => guard.take()?,
            Err(poisoned) => poisoned.into_inner().take()?,
        };
        let completed_at = match self.completed_at.lock() {
            Ok(mut guard) => guard.take(),
            Err(poisoned) => poisoned.into_inner().take(),
        }
        .unwrap_or_else(Instant::now);
        Some((
            status,
            completed_at,
            self.actual_length.load(Ordering::Acquire),
        ))
    }
}

#[derive(Debug)]
struct IsoTransferUserData {
    completion: Arc<IsoTransferCompletion>,
    buffer: Vec<u8>,
}

struct IsoTransferSlot {
    transfer: std::ptr::NonNull<libusb_transfer>,
    user_data: *mut IsoTransferUserData,
    slot_index: usize,
    generation: u64,
    submitted_endpoint: u8,
    submitted_bytes: usize,
    packet_sizes: Vec<usize>,
    queued_frame_count: usize,
    queued_underrun: bool,
    submitted_at: Option<Instant>,
    in_flight: bool,
}

struct IsoTransferPayload {
    packet_sizes: Vec<usize>,
    packet_samples: Vec<i32>,
    transfer_buffer: Vec<u8>,
    underrun: bool,
    frame_count: usize,
}

impl IsoTransferSlot {
    fn new(slot_index: usize, packet_count: usize, buffer_capacity: usize) -> Result<Self, String> {
        let completion = Arc::new(IsoTransferCompletion::new());
        let user_data = Box::new(IsoTransferUserData {
            completion,
            buffer: vec![0u8; buffer_capacity.max(1)],
        });
        let user_data_ptr = Box::into_raw(user_data);
        let transfer = unsafe { libusb_alloc_transfer(packet_count as i32) };

        let Some(transfer) = std::ptr::NonNull::new(transfer) else {
            unsafe {
                drop(Box::from_raw(user_data_ptr));
            }
            return Err("libusb_alloc_transfer returned null".to_string());
        };

        Ok(Self {
            transfer,
            user_data: user_data_ptr,
            slot_index,
            generation: 0,
            submitted_endpoint: 0,
            submitted_bytes: 0,
            packet_sizes: vec![0; packet_count],
            queued_frame_count: 0,
            queued_underrun: false,
            submitted_at: None,
            in_flight: false,
        })
    }

    fn submit(
        &mut self,
        handle: &DeviceHandle<Context>,
        endpoint: u8,
        payload: IsoTransferPayload,
    ) -> Result<(), String> {
        if self.in_flight {
            return Err("isochronous transfer slot already has a transfer in flight".to_string());
        }

        if payload.packet_sizes.len() != self.packet_sizes.len() {
            return Err(format!(
                "isochronous packet count mismatch: slot={}, payload={}",
                self.packet_sizes.len(),
                payload.packet_sizes.len()
            ));
        }

        unsafe {
            let user_data = &mut *self.user_data;
            if payload.transfer_buffer.len() > user_data.buffer.len() {
                return Err(format!(
                    "isochronous transfer buffer too small: capacity={}, payload={}",
                    user_data.buffer.len(),
                    payload.transfer_buffer.len()
                ));
            }
            user_data.buffer[..payload.transfer_buffer.len()]
                .copy_from_slice(&payload.transfer_buffer);
            user_data.completion.reset();

            libusb_fill_iso_transfer(
                self.transfer.as_mut(),
                handle.as_raw(),
                endpoint,
                user_data.buffer.as_mut_ptr(),
                payload.transfer_buffer.len() as i32,
                payload.packet_sizes.len() as i32,
                iso_transfer_callback,
                self.user_data as *mut c_void,
                ISO_TRANSFER_TIMEOUT_MS,
            );

            for (index, packet_size) in payload.packet_sizes.iter().enumerate() {
                *self
                    .transfer
                    .as_mut()
                    .iso_packet_desc
                    .as_mut_ptr()
                    .add(index) = libusb_iso_packet_descriptor {
                    length: *packet_size as u32,
                    actual_length: 0,
                    status: LIBUSB_TRANSFER_ERROR,
                };
            }

            let submit_result = libusb_submit_transfer(self.transfer.as_ptr());
            if submit_result != 0 {
                return Err(format!(
                    "libusb_submit_transfer failed with code {}",
                    submit_result
                ));
            }
        }

        self.generation = self.generation.saturating_add(1);
        self.submitted_endpoint = endpoint;
        self.submitted_bytes = payload.transfer_buffer.len();
        self.queued_frame_count = payload.frame_count;
        self.queued_underrun = payload.underrun;
        self.packet_sizes.copy_from_slice(&payload.packet_sizes);
        self.submitted_at = Some(Instant::now());
        self.in_flight = true;
        Ok(())
    }

    fn take_completion(&mut self) -> Option<(i32, Instant, usize)> {
        let completion = unsafe { &(*self.user_data).completion };
        completion.take()
    }

    fn diagnostic(&self, completion: Option<IsoCompletionDiagnostic>) -> IsoSlotDiagnostic {
        IsoSlotDiagnostic {
            slot_index: self.slot_index,
            generation: self.generation,
            pending_at_poll: self.in_flight && completion.is_none(),
            submitted_age_us: self.submitted_at.map(|submitted_at| {
                submitted_at
                    .elapsed()
                    .as_micros()
                    .min(u128::from(u64::MAX)) as u64
            }),
            queued_frames: self.queued_frame_count as u64,
            submitted_bytes: self.submitted_bytes,
            completion,
        }
    }

    fn turnaround_us(&self, completed_at: Instant) -> Option<u64> {
        self.submitted_at.map(|submitted_at| {
            completed_at
                .saturating_duration_since(submitted_at)
                .as_micros()
                .min(u128::from(u64::MAX)) as u64
        })
    }

    fn validate_packets(
        &self,
        pcm_frame_bytes: Option<usize>,
        timed_out: bool,
    ) -> Result<CompletionStats, String> {
        let transfer = unsafe { self.transfer.as_ref() };
        let result = if transfer.endpoint != self.submitted_endpoint
            || transfer.length as usize != self.submitted_bytes
        {
            Err("isochronous transfer endpoint or buffer length changed".to_string())
        } else {
            iso_packet_descriptors(transfer, self.packet_sizes.len()).and_then(|descriptors| {
                match pcm_frame_bytes {
                    Some(bytes_per_frame) => account_pcm_completion(
                        &self.packet_sizes,
                        descriptors,
                        bytes_per_frame,
                        timed_out,
                    ),
                    None => validate_iso_packet_descriptors(&self.packet_sizes, descriptors)
                        .map(|()| CompletionStats::default()),
                }
            })
        };
        result.map_err(|error| {
            format!(
                "{}; slot={} generation={} submitted_endpoint=0x{:02x} \
                 completed_endpoint=0x{:02x} submitted_bytes={} transfer_length={}",
                error,
                self.slot_index,
                self.generation,
                self.submitted_endpoint,
                transfer.endpoint,
                self.submitted_bytes,
                transfer.length,
            )
        })
    }

    fn mark_completed(&mut self) {
        self.queued_frame_count = 0;
        self.queued_underrun = false;
        self.submitted_at = None;
        self.in_flight = false;
    }

    fn cancel(&mut self) {
        if !self.in_flight {
            return;
        }

        let _ = unsafe { libusb_cancel_transfer(self.transfer.as_ptr()) };
    }
}

impl Drop for IsoTransferSlot {
    fn drop(&mut self) {
        if self.in_flight {
            // libusb still owns the transfer and its buffer. Freeing either
            // here risks a use-after-free inside libusb's event thread, so
            // leak them instead of crashing.
            dev_eprintln!(
                "[USB] in-flight isochronous transfer survived teardown drain; leaking slot to avoid use-after-free"
            );
            std::mem::forget(unsafe { Box::from_raw(self.user_data) });
            return;
        }

        unsafe {
            libusb_free_transfer(self.transfer.as_ptr());
            drop(Box::from_raw(self.user_data));
        }
    }
}

/// Persistent asynchronous feedback IN slot.
///
/// The previous implementation performed a blocking feedback read from the
/// single output thread. Four queued OUT transfers only cover ~16 ms at
/// 125 us service intervals, so a 50 ms feedback timeout could drain the
/// entire hardware queue even while the software ring looked full. This slot
/// is submitted once and re-armed from the same event loop after completion.
struct FeedbackTransferSlot {
    transfer: std::ptr::NonNull<libusb_transfer>,
    user_data: *mut IsoTransferUserData,
    endpoint: AndroidUsbFeedbackEndpoint,
    packet_count: usize,
    packet_bytes: usize,
    timeout_ms: u32,
    in_flight: bool,
}

impl FeedbackTransferSlot {
    fn new(endpoint: AndroidUsbFeedbackEndpoint) -> Result<Self, String> {
        let packet_bytes = endpoint.max_packet_bytes.max(4);
        let packet_count = if endpoint.transfer_type == TransferType::Isochronous {
            let window_packets = (ANDROID_USB_FEEDBACK_POLL_WINDOW_MS * 1_000)
                / endpoint.service_interval_us.max(125);
            window_packets.clamp(1, 32) as usize
        } else {
            1
        };

        let poll_window_ms = ((packet_count as u64)
            .saturating_mul(endpoint.service_interval_us as u64)
            / 1_000)
            .max(1) as u32;
        let timeout_ms =
            ANDROID_USB_FEEDBACK_TIMEOUT_MS.max(poll_window_ms.saturating_add(20));

        let completion = Arc::new(IsoTransferCompletion::new());
        let user_data = Box::new(IsoTransferUserData {
            completion,
            buffer: vec![0u8; packet_bytes.saturating_mul(packet_count).max(4)],
        });
        let user_data_ptr = Box::into_raw(user_data);
        let transfer = unsafe { libusb_alloc_transfer(packet_count as i32) };

        let Some(transfer) = std::ptr::NonNull::new(transfer) else {
            unsafe {
                drop(Box::from_raw(user_data_ptr));
            }
            return Err("libusb_alloc_transfer returned null for feedback transfer".to_string());
        };

        Ok(Self {
            transfer,
            user_data: user_data_ptr,
            endpoint,
            packet_count,
            packet_bytes,
            timeout_ms,
            in_flight: false,
        })
    }

    fn submit(&mut self, handle: &DeviceHandle<Context>) -> Result<(), String> {
        if self.in_flight {
            return Err("feedback transfer slot already in flight".to_string());
        }

        unsafe {
            let user_data = &mut *self.user_data;
            user_data.completion.reset();
            let buffer_len = self.packet_bytes.saturating_mul(self.packet_count);
            match self.endpoint.transfer_type {
                TransferType::Isochronous => {
                    libusb_fill_iso_transfer(
                        self.transfer.as_mut(),
                        handle.as_raw(),
                        self.endpoint.address,
                        user_data.buffer.as_mut_ptr(),
                        buffer_len as i32,
                        self.packet_count as i32,
                        iso_transfer_callback,
                        self.user_data as *mut c_void,
                        self.timeout_ms,
                    );
                    for index in 0..self.packet_count {
                        (*self
                            .transfer
                            .as_mut()
                            .iso_packet_desc
                            .as_mut_ptr()
                            .add(index))
                        .length = self.packet_bytes as u32;
                    }
                }
                TransferType::Interrupt => {
                    libusb_fill_interrupt_transfer(
                        self.transfer.as_mut(),
                        handle.as_raw(),
                        self.endpoint.address,
                        user_data.buffer.as_mut_ptr(),
                        self.packet_bytes as i32,
                        iso_transfer_callback,
                        self.user_data as *mut c_void,
                        self.timeout_ms,
                    );
                }
                other => {
                    return Err(format!(
                        "Unsupported feedback transfer type {}",
                        transfer_type_label(other)
                    ));
                }
            }

            let submit_result = libusb_submit_transfer(self.transfer.as_ptr());
            if submit_result != 0 {
                return Err(format!(
                    "libusb_submit_transfer failed for feedback endpoint 0x{:02x} with code {}",
                    self.endpoint.address, submit_result
                ));
            }
        }

        self.in_flight = true;
        Ok(())
    }

    fn take_completion(&self) -> Option<(i32, Instant, usize)> {
        let completion = unsafe { &(*self.user_data).completion };
        completion.take()
    }

    fn report_bytes(&self) -> Option<Vec<u8>> {
        let user_data = unsafe { &(*self.user_data) };
        let buffer = &user_data.buffer;

        // For iso feedback, packet payloads are laid out at fixed offsets based
        // on the requested packet length. Read the newest packet from its own
        // descriptor instead of assuming libusb packed a shortened actual-length
        // prefix contiguously.
        let (offset, available) = if self.endpoint.transfer_type == TransferType::Isochronous {
            let transfer = unsafe { self.transfer.as_ref() };
            (0..self.packet_count).rev().find_map(|index| {
                let descriptor = unsafe { &*transfer.iso_packet_desc.as_ptr().add(index) };
                (descriptor.status == LIBUSB_TRANSFER_COMPLETED && descriptor.actual_length > 0)
                    .then_some((
                        index * self.packet_bytes,
                        (descriptor.actual_length as usize).min(self.packet_bytes),
                    ))
            })?
        } else {
            (
                0,
                user_data
                    .completion
                    .actual_length
                    .load(Ordering::Acquire)
                    .min(buffer.len()),
            )
        };

        let available = available.min(buffer.len().saturating_sub(offset));
        let report_len = if available >= 4 {
            4
        } else if available >= 3 {
            3
        } else {
            return None;
        };
        Some(buffer[offset + available - report_len..offset + available].to_vec())
    }

    fn mark_completed(&mut self) {
        self.in_flight = false;
    }

    fn cancel(&mut self) {
        if self.in_flight {
            let _ = unsafe { libusb_cancel_transfer(self.transfer.as_ptr()) };
        }
    }
}

impl Drop for FeedbackTransferSlot {
    fn drop(&mut self) {
        if self.in_flight {
            dev_eprintln!(
                "[USB] in-flight feedback transfer survived teardown drain; leaking slot to avoid use-after-free"
            );
            std::mem::forget(unsafe { Box::from_raw(self.user_data) });
            return;
        }

        unsafe {
            libusb_free_transfer(self.transfer.as_ptr());
            drop(Box::from_raw(self.user_data));
        }
    }
}

#[derive(Default)]
struct FeedbackCounters {
    reports: u64,
    timeouts: u64,
    errors: u64,
    rejected: u64,
    last_report_at: Option<Instant>,
    last_frames_per_packet: Option<f64>,
    last_estimated_sample_rate: Option<f64>,
    announced_report: bool,
}

fn pump_feedback_transfer(
    handle: &DeviceHandle<Context>,
    slot: &mut FeedbackTransferSlot,
    scheduler: &mut IsoPacketScheduler,
    data_service_interval_us: u32,
    speed: Speed,
    counters: &mut FeedbackCounters,
    stop: &AtomicBool,
) {
    let endpoint = slot.endpoint;
    if let Some((status, completed_at, _actual_length)) = slot.take_completion() {
        slot.mark_completed();

        match status {
            LIBUSB_TRANSFER_COMPLETED => {
                if let Some(raw_bytes) = slot.report_bytes() {
                    if let Some((frames_per_packet, estimated_sample_rate)) =
                        decode_feedback_report(&raw_bytes, data_service_interval_us, speed)
                    {
                        if scheduler.update_feedback_frames_per_packet(frames_per_packet) {
                            counters.reports = counters.reports.saturating_add(1);
                            counters.last_report_at = Some(completed_at);
                            counters.last_frames_per_packet = Some(frames_per_packet);
                            counters.last_estimated_sample_rate = Some(estimated_sample_rate);
                            if !counters.announced_report || counters.reports % 128 == 0 {
                                dev_eprintln!(
                                    "[USB] Feedback endpoint 0x{:02x} {} bytes={:02x?} framesPerPacket={:.4} sampleRate≈{:.2}Hz (dataService={}us)",
                                    endpoint.address,
                                    transfer_type_label(endpoint.transfer_type),
                                    raw_bytes,
                                    frames_per_packet,
                                    estimated_sample_rate,
                                    data_service_interval_us,
                                );
                                counters.announced_report = true;
                            }
                        } else {
                            counters.rejected = counters.rejected.saturating_add(1);
                            if counters.rejected <= 4 || counters.rejected % 64 == 0 {
                                dev_eprintln!(
                                    "[USB] Feedback endpoint 0x{:02x} rejected implausible framesPerPacket={:.4} (nominal dataService={}us)",
                                    endpoint.address,
                                    frames_per_packet,
                                    data_service_interval_us,
                                );
                            }
                        }
                    } else {
                        counters.rejected = counters.rejected.saturating_add(1);
                        if counters.rejected <= 4 || counters.rejected % 64 == 0 {
                            dev_eprintln!(
                                "[USB] Feedback endpoint 0x{:02x} rejected malformed report length={}",
                                endpoint.address,
                                raw_bytes.len()
                            );
                        }
                    }
                }
            }
            LIBUSB_TRANSFER_TIMED_OUT | LIBUSB_TRANSFER_CANCELLED => {
                counters.timeouts = counters.timeouts.saturating_add(1);
            }
            LIBUSB_TRANSFER_STALL => {
                counters.errors = counters.errors.saturating_add(1);
                dev_eprintln!(
                    "[USB] Feedback endpoint 0x{:02x} stalled; keeping last feedback-derived packet rate",
                    endpoint.address
                );
            }
            LIBUSB_TRANSFER_NO_DEVICE => {
                counters.errors = counters.errors.saturating_add(1);
            }
            other => {
                counters.errors = counters.errors.saturating_add(1);
                if counters.errors <= 4 || counters.errors % 64 == 0 {
                    dev_eprintln!(
                        "[USB] Feedback endpoint 0x{:02x} transfer status {} ({})",
                        endpoint.address,
                        other,
                        iso_transfer_status_label(other)
                    );
                }
            }
        }
    }

    if !usb_stop_requested(stop) && !slot.in_flight {
        if let Err(error) = slot.submit(handle) {
            counters.errors = counters.errors.saturating_add(1);
            if counters.errors <= 4 || counters.errors % 64 == 0 {
                dev_eprintln!(
                    "[USB] Feedback endpoint 0x{:02x} resubmit failed: {}",
                    endpoint.address,
                    error
                );
            }
        }
    }
}

impl AndroidDirectUsbRuntimeStats {
    fn new(sample_rate: u32, channels: usize, capacity_ms: usize, target_ms: usize) -> Self {
        let frames_per_ms = sample_rate as usize / 1_000;
        let capacity_frames = frames_per_ms.saturating_mul(capacity_ms);
        let target_frames = frames_per_ms.saturating_mul(target_ms);
        let capacity_samples = capacity_frames.saturating_mul(channels);
        let target_samples = target_frames.saturating_mul(channels);

        Self {
            sample_rate,
            channels,
            buffer_capacity_samples: capacity_samples,
            buffer_target_samples: target_samples,
            transfer_queue_depth: AtomicUsize::new(0),
            frames_per_packet: AtomicUsize::new(0),
            buffered_samples: AtomicUsize::new(0),
            underrun_count: AtomicU64::new(0),
            producer_frames: AtomicU64::new(0),
            consumer_frames: AtomicU64::new(0),
            lost_frames: AtomicU64::new(0),
            short_packets: AtomicU64::new(0),
            zero_packets: AtomicU64::new(0),
            data_urb_timeouts: AtomicU64::new(0),
            transport_unverified: AtomicBool::new(false),
            completed_transfers: AtomicU64::new(0),
            last_transfer_turnaround_us: AtomicU64::new(0),
            max_transfer_turnaround_us: AtomicU64::new(0),
            last_submit_gap_us: AtomicU64::new(0),
            max_submit_gap_us: AtomicU64::new(0),
            effective_consumer_rate_milli_hz: AtomicU64::new(0),
            last_push_max_abs_f32_bits: AtomicU32::new(0),
        }
    }

    fn transport_unverified(&self) -> bool {
        self.transport_unverified.load(Ordering::Acquire)
    }

    fn buffer_fill_ms(&self) -> u32 {
        samples_to_millis(
            self.buffered_samples.load(Ordering::Relaxed),
            self.sample_rate,
            self.channels,
        )
    }

    fn buffer_capacity_ms(&self) -> u32 {
        samples_to_millis(
            self.buffer_capacity_samples,
            self.sample_rate,
            self.channels,
        )
    }

    fn buffer_target_ms(&self) -> u32 {
        samples_to_millis(self.buffer_target_samples, self.sample_rate, self.channels)
    }

    fn drift_ms_from_target(&self) -> i32 {
        let buffered_samples = self.buffered_samples.load(Ordering::Relaxed) as i64;
        let target_samples = self.buffer_target_samples as i64;
        let sample_delta = buffered_samples - target_samples;
        if self.sample_rate == 0 || self.channels == 0 {
            return 0;
        }
        ((sample_delta * 1_000) / (self.sample_rate as i64 * self.channels as i64)) as i32
    }
}

impl AndroidDirectUsbPcmRingBuffer {
    fn new(capacity_samples: usize, channels: usize) -> Self {
        let channels = channels.max(1);
        let min_capacity = channels * 4;
        let capacity_samples = capacity_samples.max(min_capacity) / channels * channels;
        Self {
            samples: vec![0; capacity_samples],
            capacity_samples,
            channels,
            read_index: 0,
            write_index: 0,
            len_samples: 0,
            dop_marker_is_fa: false,
            flush_generation: 0,
            refill_pending: false,
        }
    }

    fn len_samples(&self) -> usize {
        self.len_samples
    }

    /// Either worker can observe a flush. Clearing once per generation keeps
    /// fresh audio intact and preserves the DoP phase of the running wire.
    fn observe_flush(&mut self, generation: u64) {
        if generation != self.flush_generation {
            self.read_index = 0;
            self.write_index = 0;
            self.len_samples = 0;
            self.refill_pending = true;
            self.flush_generation = generation;
        }
    }

    /// True while waiting for enough audio to fill the first transfer.
    fn awaiting_refill(&mut self, needed_samples: usize) -> bool {
        if self.refill_pending && self.len_samples < needed_samples {
            return true;
        }
        self.refill_pending = false;
        false
    }

    fn push_samples(&mut self, input: &[i32]) -> usize {
        if input.is_empty() || self.capacity_samples == 0 {
            return 0;
        }

        let writable = input
            .len()
            .min(self.capacity_samples.saturating_sub(self.len_samples));
        let writable = writable / self.channels * self.channels;
        for sample in input.iter().take(writable) {
            self.samples[self.write_index] = *sample;
            self.write_index = (self.write_index + 1) % self.capacity_samples;
        }
        self.len_samples += writable;
        writable
    }

    fn pop_into_or_pad(
        &mut self,
        output: &mut [i32],
        _channels: usize,
        dsd_transport: DsdTransportMode,
    ) -> bool {
        if output.is_empty() {
            return false;
        }

        let readable = output.len().min(self.len_samples) / self.channels * self.channels;
        for destination in output.iter_mut().take(readable) {
            *destination = self.samples[self.read_index];
            self.read_index = (self.read_index + 1) % self.capacity_samples;
        }
        self.len_samples -= readable;

        let underrun = readable < output.len();
        if underrun {
            // Zero is full-scale DC for native DSD and breaks DoP marker sync;
            // pad with a silent but valid bitstream instead.
            output[readable..].fill(wire_silence_sample(dsd_transport));
        }

        self.stamp_dop_markers(output, dsd_transport);

        underrun
    }

    /// Fills `output` with wire-correct silence and leaves the queue untouched.
    /// Used while paused or refilling after a flush to keep the isochronous
    /// stream running without consuming audio the user has not heard yet. DoP
    /// markers advance exactly as for real audio.
    fn fill_wire_silence(&mut self, output: &mut [i32], dsd_transport: DsdTransportMode) {
        output.fill(wire_silence_sample(dsd_transport));
        self.stamp_dop_markers(output, dsd_transport);
    }

    // The final USB stream owns marker phase. Decoder restarts and inserted
    // silence must not reset it or give L/R different markers.
    fn stamp_dop_markers(&mut self, output: &mut [i32], dsd_transport: DsdTransportMode) {
        if dsd_transport != DsdTransportMode::DoP {
            return;
        }
        for frame in output.chunks_exact_mut(self.channels) {
            let marker = if self.dop_marker_is_fa { 0xFAu32 } else { 0x05 };
            for sample in frame {
                *sample = ((*sample as u32 & 0x00ff_ffff) | marker << 24) as i32;
            }
            self.dop_marker_is_fa = !self.dop_marker_is_fa;
        }
    }
}

fn wire_silence_sample(dsd_transport: DsdTransportMode) -> i32 {
    match dsd_transport {
        DsdTransportMode::Native => 0x69,
        DsdTransportMode::DoP => 0x00696900,
        DsdTransportMode::None => 0,
    }
}

fn samples_to_millis(samples: usize, sample_rate: u32, channels: usize) -> u32 {
    if sample_rate == 0 || channels == 0 {
        return 0;
    }
    ((samples as u64 * 1_000) / (sample_rate as u64 * channels as u64)) as u32
}

fn effective_ring_rate(playback_format: &AndroidDirectUsbPlaybackFormat) -> u32 {
    if playback_format.dsd_transport == DsdTransportMode::Native && playback_format.dsd_bit_rate > 0
    {
        playback_format.dsd_bit_rate / 8
    } else {
        playback_format.sample_rate
    }
}

pub struct AndroidDirectUsbBackend {
    stop: Arc<AtomicBool>,
    producer_thread_handle: Option<JoinHandle<()>>,
    usb_thread_handle: Option<JoinHandle<()>>,
}

static DIRECT_USB_STATE: Lazy<Mutex<Option<AndroidDirectUsbState>>> =
    Lazy::new(|| Mutex::new(None));
static DIRECT_USB_LOCK: Lazy<Mutex<Option<AndroidDirectUsbLock>>> = Lazy::new(|| Mutex::new(None));
static DIRECT_USB_LIFECYCLE_STATE: Lazy<Mutex<AndroidDirectUsbLifecycleState>> =
    Lazy::new(|| Mutex::new(AndroidDirectUsbLifecycleState::default()));
/// Serializes Feature Unit I/O with other volume calls and final device clear.
static ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));
static DIRECT_USB_DISCOVERY_DISABLED: Once = Once::new();
static ANDROID_DIRECT_USB_ENABLED: AtomicBool = AtomicBool::new(true);
static USB_SESSION_CLEAR_PENDING: AtomicBool = AtomicBool::new(false);
static HARDWARE_VOLUME_GENERATION: AtomicU64 = AtomicU64::new(0);

/// Only one negotiation or output session can use the claimed interfaces.
/// Serialize ownership transitions with device clear before Android releases them.
static USB_SESSION_ACTIVE: AtomicBool = AtomicBool::new(false);
static USB_SESSION_GATE: Mutex<()> = Mutex::new(());

struct AndroidUsbSessionGuard;

impl AndroidUsbSessionGuard {
    // Caller holds USB_SESSION_GATE and has checked that no session is active.
    fn start_locked() -> Self {
        USB_STOP_REQUESTED.store(false, Ordering::SeqCst);
        USB_SESSION_ACTIVE.store(true, Ordering::SeqCst);
        Self
    }
}

impl Drop for AndroidUsbSessionGuard {
    fn drop(&mut self) {
        let _session_gate = USB_SESSION_GATE.lock();
        USB_SESSION_ACTIVE.store(false, Ordering::SeqCst);
        complete_pending_android_usb_clear_locked();
    }
}

// ponytail: module-level stop signal. `clear_android_usb_device()` has no handle
// to the backend's local `stop` Arc, so without this the transfer loop keeps
// running until the engine drops the backend or the USB fd dies. Set from the
// deferred-clear path; reset at session start. Ceiling: a second clear() during
// teardown is harmless (idempotent store).
static USB_STOP_REQUESTED: AtomicBool = AtomicBool::new(false);

/// Combined stop predicate for the render/output loops: bail when either the
/// backend's local `stop` Arc or the global clear-requested flag is set.
fn usb_stop_requested(stop: &AtomicBool) -> bool {
    stop.load(Ordering::Acquire) || USB_STOP_REQUESTED.load(Ordering::Acquire)
}

fn payload_audit_latch() -> PayloadAuditLatch {
    PayloadAuditLatch::new(Duration::from_millis(ANDROID_USB_PAYLOAD_FLICKER_GRACE_MS))
}

static USB_DSD_PAYLOAD_LATCH: Lazy<Mutex<PayloadAuditLatch>> =
    Lazy::new(|| Mutex::new(payload_audit_latch()));

fn usb_dsd_payload_verified() -> bool {
    USB_DSD_PAYLOAD_LATCH.lock().is_verified()
}

static USB_PCM_PAYLOAD_LATCH: Lazy<Mutex<PayloadAuditLatch>> =
    Lazy::new(|| Mutex::new(payload_audit_latch()));

fn usb_pcm_payload_verified() -> bool {
    USB_PCM_PAYLOAD_LATCH.lock().is_verified()
}

/// Unconditional diagnostic event: reaches logcat and the user-shareable
/// AppLog sink even with Developer Mode off. Only called on state transitions.
fn log_usb_event(message: String) {
    log_info!("{}", message);
    crate::api::logging::forward_to_sink(message);
}

fn observe_dsd_payload_audit(ok: bool) {
    let now = Instant::now();
    let mut latch = USB_DSD_PAYLOAD_LATCH.lock();
    if let Some(verified) = latch.observe(ok, now) {
        let constant_for = latch.constant_for(now);
        drop(latch);
        log_payload_audit_transition("DSD", verified, constant_for);
    }
}

fn observe_pcm_payload_audit(ok: bool) {
    let now = Instant::now();
    let mut latch = USB_PCM_PAYLOAD_LATCH.lock();
    if let Some(verified) = latch.observe(ok, now) {
        let constant_for = latch.constant_for(now);
        drop(latch);
        log_payload_audit_transition("PCM", verified, constant_for);
    }
}

fn log_payload_audit_transition(transport: &str, verified: bool, constant_for: Option<Duration>) {
    if verified {
        log_usb_event(format!(
            "[USB-{transport}] wire payload verified: real audio flowing, not a stuck/dead pipeline"
        ));
    } else {
        let constant_ms = constant_for.map(|duration| duration.as_millis()).unwrap_or(0);
        log_usb_event(format!(
            "[USB-{transport}] wire payload lost: audit failed for {constant_ms}ms (constant/silent transfer)"
        ));
    }
}

fn payload_constant_ms(transport: Option<DsdTransportMode>) -> Option<u64> {
    let now = Instant::now();
    let constant_for = match transport {
        Some(DsdTransportMode::None) | None => USB_PCM_PAYLOAD_LATCH.lock().constant_for(now),
        _ => USB_DSD_PAYLOAD_LATCH.lock().constant_for(now),
    };
    constant_for.map(|duration| duration.as_millis() as u64)
}

static LAST_BIT_PERFECT_LOGGED: AtomicBool = AtomicBool::new(false);

/// Transition evidence line for the bit-perfect claim. Both edges are logged
/// unconditionally so field reports can show mode flapping without Developer
/// Mode.
fn log_bit_perfect_transition(verified: bool, state: &AndroidDirectUsbState) {
    let prev = LAST_BIT_PERFECT_LOGGED.swap(verified, Ordering::Relaxed);
    if prev == verified {
        return;
    }
    let Some(effective) = state.playback_format else {
        return;
    };
    let transport = match effective.dsd_transport {
        DsdTransportMode::DoP => "dop",
        DsdTransportMode::Native => "dsd-native",
        DsdTransportMode::None => "pcm",
    };
    if verified {
        log_usb_event(format!(
            "[USB-BITPERFECT] verified: {} bit/{} Hz {}ch {} direct on \"{}\" — no mixer, no resample, no DSP",
            effective.bit_depth,
            effective.sample_rate,
            effective.channels,
            transport,
            state.device.product_name
        ));
    } else {
        log_usb_event(format!(
            "[USB-BITPERFECT] released: {} bit/{} Hz {}ch {} direct on \"{}\" — {}",
            effective.bit_depth,
            effective.sample_rate,
            effective.channels,
            transport,
            state.device.product_name,
            bit_perfect_release_reason(state)
        ));
    }
}

fn bit_perfect_release_reason(state: &AndroidDirectUsbState) -> &'static str {
    if !state.stream_active {
        return "stream inactive";
    }
    if !state.clock_verification_passed {
        return "clock verification reset";
    }
    let format_mismatch = state
        .requested_playback_format
        .zip(state.playback_format)
        .is_some_and(|(requested, effective)| {
            requested.sample_rate != effective.sample_rate
                || requested.bit_depth != effective.bit_depth
                || requested.channels != effective.channels
        });
    if format_mismatch {
        return "requested/effective format mismatch";
    }
    if state
        .runtime_stats
        .as_ref()
        .is_some_and(|stats| stats.transport_unverified())
    {
        return "USB transport interrupted or unverified";
    }
    "wire payload audit failed"
}

/// Verify the just-encoded wire payload looks like real DSD transport data.
/// DoP: all channels share a marker and every frame alternates. This is a
/// framing check, NOT proof of source-to-wire byte identity. Native: require
/// at least one non-zero byte (gross
/// pipeline-failure guard; DSD has no in-band markers to check).
fn audit_dsd_payload(
    buffer: &[u8],
    dsd_transport: DsdTransportMode,
    subslot_size: u8,
    channels: u16,
) -> bool {
    if buffer.is_empty() {
        return false;
    }
    let ss = subslot_size as usize;
    match dsd_transport {
        DsdTransportMode::DoP => {
            if !(ss == 3 || ss == 4) || channels == 0 {
                return false;
            }
            let ch = channels.max(1) as usize;
            let stride = ss * ch;
            if buffer.len() % stride != 0 || buffer.len() < 2 * stride {
                return false;
            }
            let mut previous: Option<u8> = None;
            for frame in buffer.chunks_exact(stride) {
                let marker = frame[ss - 1];
                if marker != 0x05 && marker != 0xFA {
                    return false;
                }
                if previous == Some(marker) || frame.chunks_exact(ss).any(|word| word[ss - 1] != marker) {
                    return false;
                }
                previous = Some(marker);
            }
            true
        }
        DsdTransportMode::Native => buffer.iter().any(|&b| b != 0),
        DsdTransportMode::None => true,
    }
}

/// Verify the just-encoded PCM wire payload looks like real audio, not a stuck
/// or dead pipeline. Mirrors audit_dsd_payload's gross-guard philosophy: decode
/// channel-0 samples at the negotiated subslot width (little-endian signed, per
/// UAC2 Type I PCM) and require at least two distinct values across the buffer.
/// A real music transfer is effectively never sample-constant; a dead pipeline
/// emits a constant (often all-zero or a fixed DC value).
// ponytail: statistical guard, not a bit-exact hash. Upgrade path: per-frame
// hash comparison against decoded source bytes if a stronger claim is needed.
fn audit_pcm_payload(buffer: &[u8], subslot_size: u8, channels: u16) -> bool {
    if buffer.is_empty() || subslot_size == 0 {
        return false;
    }
    let ss = subslot_size as usize;
    let ch = channels.max(1) as usize;
    let stride = ss * ch;
    if stride == 0 || buffer.len() < stride * 2 {
        return false;
    }
    let bits = ss * 8;
    let sign_extend = |v: i64| -> i64 {
        if v & (1 << (bits - 1)) != 0 {
            v | (-1i64 << bits)
        } else {
            v
        }
    };
    let decode = |i: usize| -> i64 {
        let off = i * stride;
        let mut v: i64 = 0;
        for b in 0..ss {
            v |= (buffer[off + b] as i64) << (8 * b);
        }
        sign_extend(v)
    };
    let limit = (buffer.len() / stride).min(1024);
    let first = decode(0);
    (1..limit).any(|i| decode(i) != first)
}

pub fn set_android_direct_usb_enabled(enabled: bool) {
    ANDROID_DIRECT_USB_ENABLED.store(enabled, Ordering::Release);
}

pub fn android_direct_usb_enabled() -> bool {
    ANDROID_DIRECT_USB_ENABLED.load(Ordering::Acquire)
}

pub fn is_usb_session_active() -> bool {
    USB_SESSION_ACTIVE.load(Ordering::SeqCst)
}

pub(crate) fn with_live_usb_reconnect<T>(
    expected_device: &str,
    start: impl FnOnce() -> Result<T, String>,
) -> Result<T, String> {
    let _gate = USB_SESSION_GATE.lock();
    let device_matches = DIRECT_USB_STATE
        .lock()
        .as_ref()
        .and_then(|state| state.device.device_name.as_deref())
        == Some(expected_device);
    if !device_matches
        || !is_usb_session_active()
        || USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst)
        || USB_STOP_REQUESTED.load(Ordering::SeqCst)
    {
        return Err("Direct USB reconnect no longer owns the expected DAC".into());
    }
    start()
}

// The caller holds USB_SESSION_GATE so the wait API cannot report success while
// a clear is still dropping the idle handle and its device registration.
fn complete_pending_android_usb_clear_locked() -> bool {
    if USB_SESSION_ACTIVE.load(Ordering::SeqCst) {
        return false;
    }
    if !USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst) {
        return true;
    }
    // A volume operation may still be on the worker. Android can retry the
    // clear without blocking its main thread or releasing the claimed interfaces.
    let Some(_volume_hold) = ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX.try_lock() else {
        return false;
    };

    dev_eprintln!("Android USB direct: clearing registration after USB I/O stopped");
    release_idle_lock();
    if DIRECT_USB_LIFECYCLE_STATE.lock().engine_state != AndroidDirectUsbEngineState::Fallback {
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Idle, None);
    }
    *DIRECT_USB_STATE.lock() = None;
    USB_SESSION_CLEAR_PENDING.store(false, Ordering::SeqCst);
    true
}

/// Request teardown without reporting the interfaces idle before the output
/// thread has finished with them.
pub fn force_release_usb_session() {
    let _session_gate = USB_SESSION_GATE.lock();
    if is_usb_session_active() {
        USB_STOP_REQUESTED.store(true, Ordering::SeqCst);
    } else {
        complete_pending_android_usb_clear_locked();
    }
}

pub fn register_android_usb_device(device: AndroidDirectUsbDevice) -> Result<(), String> {
    let _session_gate = USB_SESSION_GATE.lock();
    if is_usb_session_active() {
        return Err(format!(
            "Android direct USB session is still active; refusing to replace registration for '{}'",
            device.product_name
        ));
    }

    if !complete_pending_android_usb_clear_locked() {
        return Err("The previous Android direct USB DAC is still being released".into());
    }
    if DIRECT_USB_STATE.lock().is_some() {
        return Err(
            "Release the previous Android direct USB DAC before registering another".to_string(),
        );
    }
    let capability_model = inspect_android_usb_capabilities(&device)?;
    let mut guard = DIRECT_USB_STATE.lock();

    let dac_clock_policy = resolve_dac_clock_policy(&device);

    let require_verified_rate = match dac_clock_policy {
        DacClockPolicy::RequireVerifiedRate => true,
        DacClockPolicy::Force48kHzOnly | DacClockPolicy::AllowUnverified => {
            ANDROID_USB_REQUIRE_VERIFIED_RATE_DEFAULT
        }
    };

    release_idle_lock();
    set_android_usb_engine_state(AndroidDirectUsbEngineState::Idle, None);
    *guard = Some(AndroidDirectUsbState {
        device,
        requested_playback_format: None,
        playback_format: None,
        lock_requested: true,
        stream_active: false,
        active_transport: None,
        capability_model,
        clock_status: None,
        clock_control_attempted: false,
        clock_control_succeeded: false,
        clock_verification_passed: false,
        require_verified_rate,
        dac_clock_policy,
        dac_mode: DacMode::FullControl,
        last_error: None,
        direct_mode_refusal_reason: None,
        usb_stream_stable: false,
        bit_perfect_verified: false,
        software_volume_active: false,
        hardware_volume_control: None,
        hardware_volume_generation: HARDWARE_VOLUME_GENERATION.fetch_add(1, Ordering::Relaxed),
        hardware_volume_error: None,
        hardware_volume_normalized: None,
        hardware_mute_active: None,
        pending_hardware_volume_restore: None,
        packet_schedule_frames_preview: Vec::new(),
        runtime_stats: None,
    });
    Ok(())
}

/// Restore a remembered hardware level now, or stage it for backend startup.
///
/// The DAC's Feature Unit is not discovered until backend preparation, so
/// the write cannot happen during registration. Keeping the value
/// in the state lets startup apply it before the first isochronous transfer.
/// An already prepared DSP session must restore immediately, before Dart can
/// enable unity-gain passthrough on that same backend.
pub fn android_direct_queue_hardware_volume_restore(
    volume: f64,
    generation: u64,
    stage_only: bool,
) -> Result<(), String> {
    if !volume.is_finite() || !(0.0..=1.0).contains(&volume) {
        return Err(format!("USB hardware volume restore value out of range: {volume}"));
    }
    let _hold = if stage_only {
        ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX
            .try_lock()
            .ok_or("USB hardware volume is busy")?
    } else {
        ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX.lock()
    };
    let state = hardware_volume_state(generation)?;
    if state.hardware_volume_control.is_some() {
        if stage_only {
            return Err("USB hardware volume was prepared before restore".into());
        }
        return set_android_usb_hardware_volume_for_state(&state, volume);
    }
    let mut guard = DIRECT_USB_STATE.lock();
    let state = guard.as_mut()
        .filter(|current| volume_generation_is_current(current, generation))
        .ok_or_else(|| "USB volume route changed before restore".to_string())?;
    state.pending_hardware_volume_restore = Some(volume);
    Ok(())
}

pub fn set_android_usb_playback_format(
    playback_format: Option<AndroidDirectUsbPlaybackFormat>,
) -> Result<(), String> {
    let mut guard = DIRECT_USB_STATE.lock();
    let Some(state) = guard.as_mut() else {
        return if playback_format.is_some() {
            Err("No Android direct USB DAC is registered".to_string())
        } else {
            Ok(())
        };
    };

    let sanitized = playback_format.map(|format| {
        let format = sanitize_android_usb_playback_format(format);
        match state.dac_clock_policy {
            DacClockPolicy::Force48kHzOnly => {}
            DacClockPolicy::RequireVerifiedRate | DacClockPolicy::AllowUnverified => {}
        }
        format
    });

    if USB_SESSION_ACTIVE.load(Ordering::SeqCst)
        && state.playback_format == sanitized
        && state.requested_playback_format == sanitized
    {
        dev_eprintln!(
            "[USB] Keeping active direct USB verification state for unchanged playback format"
        );
        return Ok(());
    }

    state.playback_format = sanitized;
    state.requested_playback_format = sanitized;
    state.clock_status = None;
    state.clock_control_attempted = false;
    state.clock_control_succeeded = false;
    state.clock_verification_passed = false;
    state.dac_mode = DacMode::FullControl;
    state.usb_stream_stable = false;
    state.bit_perfect_verified = false;
    state.software_volume_active = false;
    state.packet_schedule_frames_preview.clear();
    state.direct_mode_refusal_reason = None;
    state.runtime_stats = None;
    set_android_usb_engine_state(AndroidDirectUsbEngineState::Idle, None);
    Ok(())
}

pub fn set_android_usb_dop_mode(
    is_dop: bool,
    carrier_rate: u32,
    bit_depth: u8,
) -> Result<(), String> {
    let mut guard = DIRECT_USB_STATE.lock();
    let Some(state) = guard.as_mut() else {
        return Err("No Android direct USB DAC is registered".to_string());
    };

    let current = state
        .playback_format
        .unwrap_or(AndroidDirectUsbPlaybackFormat {
            sample_rate: carrier_rate,
            bit_depth,
            channels: 2,
            is_dop: false,
            dsd_transport: DsdTransportMode::None,
            dsd_bit_rate: 0,
        });

    let transport = if is_dop {
        DsdTransportMode::DoP
    } else {
        DsdTransportMode::None
    };
    let dop_format = AndroidDirectUsbPlaybackFormat {
        sample_rate: carrier_rate,
        bit_depth: if is_dop { bit_depth } else { current.bit_depth },
        channels: current.channels,
        is_dop,
        dsd_transport: transport,
        dsd_bit_rate: 0,
    };
    let sanitized = sanitize_android_usb_playback_format(dop_format);

    state.playback_format = Some(sanitized);
    state.requested_playback_format = Some(sanitized);
    state.clock_status = None;
    state.clock_control_attempted = false;
    state.clock_control_succeeded = false;
    state.clock_verification_passed = false;
    Ok(())
}

pub fn set_android_usb_dsd_native_mode(dsd_bit_rate: u32) -> Result<(), String> {
    let mut guard = DIRECT_USB_STATE.lock();
    let Some(state) = guard.as_mut() else {
        return Err("No Android direct USB DAC is registered".to_string());
    };

    let wire_rate = dsd_bit_rate / (8 * 4); // DSD_U32 default wire rate
    let current = state
        .playback_format
        .unwrap_or(AndroidDirectUsbPlaybackFormat {
            sample_rate: wire_rate,
            bit_depth: 1,
            channels: 2,
            is_dop: false,
            dsd_transport: DsdTransportMode::None,
            dsd_bit_rate: 0,
        });

    let native_format = AndroidDirectUsbPlaybackFormat {
        sample_rate: wire_rate,
        bit_depth: 1,
        channels: current.channels,
        is_dop: false,
        dsd_transport: DsdTransportMode::Native,
        dsd_bit_rate,
    };
    let sanitized = sanitize_android_usb_playback_format(native_format);

    state.playback_format = Some(sanitized);
    state.requested_playback_format = Some(sanitized);
    state.clock_status = None;
    state.clock_control_attempted = false;
    state.clock_control_succeeded = false;
    state.clock_verification_passed = false;
    Ok(())
}

pub fn set_android_usb_lock_enabled(enabled: bool) -> Result<(), String> {
    let _session_gate = USB_SESSION_GATE.lock();
    let stream_active = {
        let mut guard = DIRECT_USB_STATE.lock();
        let Some(state) = guard.as_mut() else {
            if enabled {
                return Err("No Android direct USB DAC is registered".to_string());
            }
            return Ok(());
        };

        state.lock_requested = enabled;
        state.stream_active
    };

    if enabled && !stream_active && !is_usb_session_active() {
        ensure_android_usb_idle_lock()?;
    }

    Ok(())
}

pub fn clear_android_usb_device() {
    let _session_gate = USB_SESSION_GATE.lock();
    USB_SESSION_CLEAR_PENDING.store(true, Ordering::SeqCst);
    if is_usb_session_active() {
        // Signal the running transfer loop to drain before Android releases
        // the interfaces and lets the platform driver rebind.
        USB_STOP_REQUESTED.store(true, Ordering::SeqCst);
        dev_eprintln!(
            "Android USB direct: clear requested while session active; signaling transfer loop to stop"
        );
        return;
    }

    complete_pending_android_usb_clear_locked();
}

pub fn wait_for_android_usb_session_stop(timeout: Duration) -> bool {
    let started_at = Instant::now();
    loop {
        if let Some(_session_gate) = USB_SESSION_GATE.try_lock() {
            if complete_pending_android_usb_clear_locked() {
                return true;
            }
        }
        if started_at.elapsed() >= timeout {
            return false;
        }
        thread::sleep(Duration::from_millis(10));
    }
}

pub fn android_direct_output_signature(preferred_sample_rate: Option<u32>) -> Option<String> {
    if !android_direct_usb_enabled() {
        return None;
    }

    let guard = DIRECT_USB_STATE.lock();
    let state = guard.as_ref()?;
    let playback_format = state.playback_format?;

    // For devices with SkipClockValidation quirk, the stored playback_format
    // rate may be stale (e.g. hardcoded 48000 from initial DAC registration)
    // and not match the track's preferred rate. Don't reject the USB direct
    // signature over this — the engine will re-negotiate the clock during
    // stream setup. If we return None here, the engine falls back to the
    // android-shared path and audio goes to the wrong output.
    if preferred_sample_rate != Some(playback_format.sample_rate) {
        let skip_clock_validation = crate::uac2::quirk::QUIRK_DATABASE.has_quirk(
            state.device.vendor_id,
            state.device.product_id,
            &state.device.product_name,
            crate::uac2::quirk::UsbAudioQuirk::SkipClockValidation,
        );
        if !skip_clock_validation {
            return None;
        }
        // Use the preferred rate in the signature so the engine gets recreated
        // at the correct rate, and update the stored format to match.
        let effective_rate = preferred_sample_rate.unwrap_or(playback_format.sample_rate);
        return Some(format!(
            "android-uac2:{}:{}:{}:{}:{}",
            state.device.fd,
            effective_rate,
            playback_format.bit_depth,
            playback_format.channels,
            state.device.device_name.as_deref().unwrap_or("usb"),
        ));
    }

    Some(format!(
        "android-uac2:{}:{}:{}:{}:{}",
        state.device.fd,
        playback_format.sample_rate,
        playback_format.bit_depth,
        playback_format.channels,
        state.device.device_name.as_deref().unwrap_or("usb"),
    ))
}

pub fn validate_android_direct_request(preferred_sample_rate: Option<u32>) -> Result<(), String> {
    if !android_direct_usb_enabled() {
        return Ok(());
    }

    let guard = DIRECT_USB_STATE.lock();
    let Some(state) = guard.as_ref() else {
        return Ok(());
    };
    let Some(playback_format) = state.playback_format else {
        return Ok(());
    };

    if playback_format.sample_rate == 0 {
        // The DAC reported 0 Hz via GET_CUR (broken clock readback, e.g.
        // Fosi DS2 / Savitech bridge). The format is prepared at the
        // requested rate — we just can't trust the stored readback.
        // Allow validation to pass; downstream guards handle the real rate.
        dev_eprintln!(
            "[USB] validate_android_direct_request: playback_format.sample_rate is 0 (broken DAC readback), allowing validation to pass for preferred {:?} Hz",
            preferred_sample_rate
        );
        return Ok(());
    }

    // For devices with SkipClockValidation quirk, the stored playback_format
    // rate may be stale (e.g. hardcoded 48000 from initial DAC registration)
    // and not match the track's actual rate. The USB direct engine will
    // re-negotiate the clock during stream setup, so allow any positive rate.
    let skip_clock_validation = crate::uac2::quirk::QUIRK_DATABASE.has_quirk(
        state.device.vendor_id,
        state.device.product_id,
        &state.device.product_name,
        crate::uac2::quirk::UsbAudioQuirk::SkipClockValidation,
    );
    if skip_clock_validation {
        dev_eprintln!(
            "[USB] validate_android_direct_request: SkipClockValidation quirk active, accepting stored {} Hz for preferred {:?} Hz",
            playback_format.sample_rate, preferred_sample_rate
        );
        return Ok(());
    }

    if preferred_sample_rate == Some(playback_format.sample_rate) {
        return Ok(());
    }

    Err(format!(
        "Android direct USB DAC '{}' is prepared for {} Hz, but the track requires {:?} Hz",
        state.device.product_name, playback_format.sample_rate, preferred_sample_rate
    ))
}

pub fn android_direct_debug_state() -> AndroidDirectUsbDebugState {
    let state = DIRECT_USB_STATE.lock().clone();
    let idle_lock_held = DIRECT_USB_LOCK.lock().is_some();
    let lifecycle_state = DIRECT_USB_LIFECYCLE_STATE.lock().clone();
    let usb_session_active = USB_SESSION_ACTIVE.load(Ordering::SeqCst);
    if usb_session_active {
        dev_eprintln!("Android USB direct debug: USB_SESSION_ACTIVE=true");
    }

    let Some(state) = state else {
        return AndroidDirectUsbDebugState {
            idle_lock_held,
            engine_state: Some(
                android_direct_usb_engine_state_label(lifecycle_state.engine_state).to_string(),
            ),
            engine_state_reason: lifecycle_state.reason,
            ..Default::default()
        };
    };

    let active_transport = state.active_transport.as_ref();
    let clock_status = state.clock_status.as_ref();
    let runtime_stats = state.runtime_stats.as_ref();
    let capability_model = state.capability_model.as_ref();
    let transport_unverified = runtime_stats.is_some_and(|stats| stats.transport_unverified());
    // Compute live (before the struct literal moves String fields out of state).
    let bit_perfect_verified = !transport_unverified && direct_path_is_bit_perfect(&state);
    log_bit_perfect_transition(bit_perfect_verified, &state);
    let pcm_payload_verified = usb_pcm_payload_verified();
    let dsd_payload_verified = usb_dsd_payload_verified();
    let payload_constant_for_ms =
        payload_constant_ms(state.playback_format.map(|format| format.dsd_transport));

    AndroidDirectUsbDebugState {
        registered: true,
        engine_state: Some(
            android_direct_usb_engine_state_label(lifecycle_state.engine_state).to_string(),
        ),
        engine_state_reason: lifecycle_state.reason,
        requested_playback_sample_rate: state
            .requested_playback_format
            .map(|format| format.sample_rate),
        requested_playback_bit_depth: state
            .requested_playback_format
            .map(|format| format.bit_depth),
        requested_playback_channels: state
            .requested_playback_format
            .map(|format| format.channels),
        device_name: state.device.device_name,
        product_name: Some(state.device.product_name),
        playback_format_sample_rate: state.playback_format.map(|format| format.sample_rate),
        playback_format_bit_depth: state.playback_format.map(|format| format.bit_depth),
        playback_format_channels: state.playback_format.map(|format| format.channels),
        lock_requested: state.lock_requested,
        stream_active: state.stream_active,
        idle_lock_held,
        active_interface_number: active_transport.map(|transport| transport.interface_number),
        active_alt_setting: active_transport.map(|transport| transport.alt_setting),
        active_endpoint_address: active_transport.map(|transport| transport.endpoint_address),
        active_endpoint_interval: active_transport.map(|transport| transport.endpoint_interval),
        active_service_interval_us: active_transport.map(|transport| transport.service_interval_us),
        active_max_packet_bytes: active_transport.map(|transport| transport.max_packet_bytes),
        transport_format: active_transport.map(|transport| transport.format_tag.clone()),
        transport_channels: active_transport.map(|transport| transport.channels),
        transport_subslot_size: active_transport.map(|transport| transport.subslot_size),
        transport_bit_resolution: active_transport.map(|transport| transport.bit_resolution),
        advertised_sample_rates: active_transport
            .map(|transport| transport.sample_rates.clone())
            .unwrap_or_default(),
        active_sync_type: active_transport.map(|transport| transport.sync_type.clone()),
        active_usage_type: active_transport.map(|transport| transport.usage_type.clone()),
        active_refresh: active_transport.map(|transport| transport.refresh),
        active_synch_address: active_transport.map(|transport| transport.synch_address),
        clock_interface_number: clock_status.map(|clock| clock.interface_number),
        clock_id: clock_status.map(|clock| clock.clock_id),
        clock_requested_sample_rate: clock_status.map(|clock| clock.requested_sample_rate),
        clock_reported_sample_rate: clock_status.and_then(|clock| clock.reported_sample_rate),
        clock_control_attempted: state.clock_control_attempted,
        clock_control_succeeded: state.clock_control_succeeded,
        clock_verification_passed: state.clock_verification_passed,
        require_verified_rate: state.require_verified_rate,
        dac_clock_policy: Some(match state.dac_clock_policy {
            DacClockPolicy::AllowUnverified => "allowUnverified".to_string(),
            DacClockPolicy::RequireVerifiedRate => "requireVerifiedRate".to_string(),
            DacClockPolicy::Force48kHzOnly => "force48kHzOnly".to_string(),
        }),
        dac_mode: Some(match state.dac_mode {
            DacMode::FullControl => "fullControl".to_string(),
            DacMode::FixedClock => "fixedClock".to_string(),
            DacMode::AdaptiveStreaming => "adaptiveStreaming".to_string(),
        }),
        resampling_active: state
            .requested_playback_format
            .zip(state.playback_format)
            .is_some_and(|(requested, effective)| requested.sample_rate != effective.sample_rate),
        last_error: state.last_error,
        direct_mode_refusal_reason: state.direct_mode_refusal_reason,
        usb_stream_stable: state.usb_stream_stable && !transport_unverified,
        bit_perfect_verified,
        pcm_payload_verified,
        dsd_payload_verified,
        payload_constant_for_ms,
        software_volume_active: state.software_volume_active,
        hardware_volume_supported: state.hardware_volume_control.is_some(),
        hardware_mute_supported: state
            .hardware_volume_control
            .as_ref()
            .is_some_and(|control| control.mute_channel.is_some())
            && state.hardware_mute_active.is_some(),
        hardware_volume_normalized: state.hardware_volume_normalized,
        hardware_mute_active: state.hardware_mute_active,
        hardware_volume_min_raw: state
            .hardware_volume_control
            .as_ref()
            .map(|control| control.min_volume_raw),
        hardware_volume_max_raw: state
            .hardware_volume_control
            .as_ref()
            .map(|control| control.max_volume_raw),
        hardware_volume_resolution_raw: state
            .hardware_volume_control
            .as_ref()
            .map(|control| control.resolution_raw),
        hardware_volume_error: state.hardware_volume_error,
        hardware_volume_generation: state.hardware_volume_generation,
        feedback_endpoint_present: active_transport
            .map(|transport| transport.feedback_endpoint_address.is_some())
            .unwrap_or(false),
        feedback_endpoint_address: active_transport
            .and_then(|transport| transport.feedback_endpoint_address),
        feedback_transfer_type: active_transport
            .and_then(|transport| transport.feedback_transfer_type.clone()),
        packet_schedule_frames_preview: state.packet_schedule_frames_preview,
        supported_sample_rates: capability_model
            .map(|capabilities| capabilities.supported_sample_rates.clone())
            .unwrap_or_default(),
        supported_bit_depths: capability_model
            .map(|capabilities| capabilities.supported_bit_depths.clone())
            .unwrap_or_default(),
        supported_channels: capability_model
            .map(|capabilities| capabilities.supported_channels.clone())
            .unwrap_or_default(),
        available_alt_settings: capability_model
            .map(|capabilities| capabilities.alt_settings.clone())
            .unwrap_or_default(),
        buffer_fill_ms: runtime_stats.map(|stats| stats.buffer_fill_ms()),
        buffer_capacity_ms: runtime_stats.map(|stats| stats.buffer_capacity_ms()),
        buffer_target_ms: runtime_stats.map(|stats| stats.buffer_target_ms()),
        frames_per_packet: runtime_stats
            .map(|stats| stats.frames_per_packet.load(Ordering::Relaxed) as u32)
            .filter(|frames| *frames > 0),
        underrun_count: runtime_stats.map(|stats| stats.underrun_count.load(Ordering::Relaxed)),
        producer_frames: runtime_stats.map(|stats| stats.producer_frames.load(Ordering::Relaxed)),
        consumer_frames: runtime_stats.map(|stats| stats.consumer_frames.load(Ordering::Relaxed)),
        lost_frames: runtime_stats.map(|stats| stats.lost_frames.load(Ordering::Relaxed)),
        data_urb_timeouts: runtime_stats
            .map(|stats| stats.data_urb_timeouts.load(Ordering::Relaxed)),
        transport_unverified,
        drift_ms_from_target: runtime_stats.map(|stats| stats.drift_ms_from_target()),
        transfer_queue_depth: runtime_stats
            .map(|stats| stats.transfer_queue_depth.load(Ordering::Relaxed) as u32)
            .filter(|depth| *depth > 0),
        completed_transfers: runtime_stats
            .map(|stats| stats.completed_transfers.load(Ordering::Relaxed)),
        last_transfer_turnaround_us: runtime_stats
            .map(|stats| stats.last_transfer_turnaround_us.load(Ordering::Relaxed))
            .filter(|value| *value > 0),
        max_transfer_turnaround_us: runtime_stats
            .map(|stats| stats.max_transfer_turnaround_us.load(Ordering::Relaxed))
            .filter(|value| *value > 0),
        last_submit_gap_us: runtime_stats
            .map(|stats| stats.last_submit_gap_us.load(Ordering::Relaxed))
            .filter(|value| *value > 0),
        max_submit_gap_us: runtime_stats
            .map(|stats| stats.max_submit_gap_us.load(Ordering::Relaxed))
            .filter(|value| *value > 0),
        effective_consumer_rate_milli_hz: runtime_stats
            .map(|stats| {
                stats
                    .effective_consumer_rate_milli_hz
                    .load(Ordering::Relaxed)
            })
            .filter(|value| *value > 0),
    }
}

pub fn android_direct_preferred_sample_rate(preferred_sample_rate: Option<u32>) -> Option<u32> {
    DIRECT_USB_STATE
        .lock()
        .as_ref()
        .and_then(|state| state.playback_format.map(|format| format.sample_rate))
        .or(preferred_sample_rate)
}

pub fn negotiate_android_direct_output_sample_rate(
    preferred_sample_rate: Option<u32>,
) -> Result<Option<u32>, String> {
    if !android_direct_usb_enabled() {
        return Ok(preferred_sample_rate);
    }

    let session_gate = USB_SESSION_GATE.lock();
    if USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst) {
        return Err("Android direct USB is being released".to_string());
    }
    let requested_format = {
        let mut guard = DIRECT_USB_STATE.lock();
        let Some(state) = guard.as_mut() else {
            return Ok(preferred_sample_rate);
        };
        let Some(mut requested_format) = state.requested_playback_format.or(state.playback_format)
        else {
            return Ok(preferred_sample_rate);
        };
        if let Some(rate) = preferred_sample_rate {
            requested_format.sample_rate = rate.max(8_000);
            // A caller-supplied rate is a PCM request: don't inherit DSD
            // transport flags or the engine keeps claiming the DSD alt
            // setting. DSD modes re-stamp these at engine create.
            if requested_format.is_dop || requested_format.dsd_transport != DsdTransportMode::None
            {
                requested_format.is_dop = false;
                requested_format.dsd_transport = DsdTransportMode::None;
                requested_format.dsd_bit_rate = 0;
                if requested_format.bit_depth == 1 {
                    requested_format.bit_depth = 24;
                }
            }
        }

        if state.stream_active || USB_SESSION_ACTIVE.load(Ordering::SeqCst) {
            state.requested_playback_format = Some(requested_format);
            if state.playback_format.map(|f| f.sample_rate) != Some(requested_format.sample_rate) {
                state.playback_format = Some(requested_format);
            }
            return Ok(Some(requested_format.sample_rate));
        }

        state.requested_playback_format = Some(requested_format);
        state.playback_format = Some(requested_format);
        state.clock_status = None;
        state.clock_control_attempted = false;
        state.clock_control_succeeded = false;
        state.clock_verification_passed = false;
        state.dac_mode = DacMode::FullControl;
        state.direct_mode_refusal_reason = None;
        requested_format
    };

    let _session = AndroidUsbSessionGuard::start_locked();
    drop(session_gate);
    let negotiated = negotiate_android_direct_playback_format(requested_format);
    negotiated.map(|format| {
        // set_effective_playback_format may have corrected a 0 Hz rate to
        // a valid value. Read back the actual stored rate so callers get
        // the real effective rate, not the pre-correction value.
        let actual_rate = DIRECT_USB_STATE
            .lock()
            .as_ref()
            .and_then(|state| state.playback_format.map(|f| f.sample_rate))
            .filter(|&rate| rate > 0)
            .unwrap_or(format.sample_rate);
        Some(actual_rate)
    })
}

fn negotiate_android_direct_playback_format(
    requested_format: AndroidDirectUsbPlaybackFormat,
) -> Result<AndroidDirectUsbPlaybackFormat, String> {
    let device = {
        let guard = DIRECT_USB_STATE.lock();
        let Some(state) = guard.as_ref() else {
            return Ok(requested_format);
        };
        state.device.clone()
    };

    let claimed_handle = open_claimed_usb_handle(&device)?;
    let lock_requested = current_lock_requested_for_fd(device.fd);
    let mut cleanup_interface: Option<u8> = None;
    let negotiated = (|| {
        let usb_device = claimed_handle.handle.device();
        let speed = resolve_device_speed(&usb_device);
        let capability_model =
            build_android_usb_capability_model(&usb_device, &claimed_handle.handle, speed).ok();
        set_capability_model(capability_model.clone());

        let candidate = match select_stream_candidate(
            &usb_device,
            &claimed_handle.handle,
            requested_format,
            speed,
        ) {
            Ok(c) => c,
            Err(error) => {
                set_last_error(Some(error.clone()));
                set_direct_mode_refusal_reason(Some(error.clone()));
                return Err(error);
            }
        };

        // Find clock entity AFTER selecting candidate so we can trace the
        // topology using the candidate's bTerminalLink.
        let clock =
            find_audio_control_clock(&usb_device, &claimed_handle.handle, candidate.terminal_link);

        if let Err(error) = claimed_handle.ensure_interface_claimed(candidate.interface_number) {
            set_last_error(Some(error.clone()));
            set_direct_mode_refusal_reason(Some(error.clone()));
            return Err(error);
        }

        if let Err(error) = claimed_handle.set_alternate_setting(candidate.interface_number, 0) {
            let msg = format!(
                "Failed to reset USB interface {} to alt 0 before negotiation: {}",
                candidate.interface_number, error
            );
            set_last_error(Some(msg.clone()));
            set_direct_mode_refusal_reason(Some(msg.clone()));
            return Err(msg);
        }
        cleanup_interface = Some(candidate.interface_number);
        thread::sleep(Duration::from_millis(100));

        let mut effective_format = requested_format;
        let mut dac_mode = DacMode::FullControl;
        let mut clock_attempted = false;
        let mut clock_succeeded = false;
        let mut rate_verified = false;
        let mut reported_rate = None;
        let mut last_message = None;

        if let Some(clock) = clock {
            if let Err(error) = claimed_handle.ensure_interface_claimed(clock.interface_number) {
                set_last_error(Some(error.clone()));
                set_direct_mode_refusal_reason(Some(error.clone()));
                return Err(error);
            }
            set_clock_status(Some(AndroidDirectUsbClockStatus {
                interface_number: clock.interface_number,
                clock_id: clock.clock_id,
                requested_sample_rate: requested_format.sample_rate,
                reported_sample_rate: None,
            }));
            let current_rate = get_sampling_frequency(
                &claimed_handle.handle,
                clock.interface_number,
                clock.clock_id,
            )
            .ok();
            let supported_ranges = get_sampling_frequency_ranges(
                &claimed_handle.handle,
                clock.interface_number,
                clock.clock_id,
            )
            .ok();

            if supported_ranges.as_ref().is_some_and(|ranges| {
                sampling_frequency_ranges_support_rate(ranges, requested_format.sample_rate)
            }) || supported_ranges.is_none()
            {
                log::info!(
                    "[USB] NEGOTIATION: usbClaimed={}, alt={}, endpoint=0x{:02x}, rate={}Hz",
                    claimed_handle
                        .claimed_interfaces
                        .contains(&candidate.interface_number),
                    candidate.alt_setting,
                    candidate.endpoint_address,
                    requested_format.sample_rate,
                );
                let clock_outcome = apply_sampling_frequency(
                    &claimed_handle.handle,
                    clock.interface_number,
                    clock.clock_id,
                    requested_format.sample_rate,
                    ANDROID_USB_CLOCK_SETTLE_DELAY_MS_DEFAULT,
                );
                clock_attempted = true;
                clock_succeeded = clock_outcome.clock_ok;
                rate_verified = clock_outcome.rate_verified;
                reported_rate = clock_outcome.reported_sample_rate.or(current_rate);
                last_message = clock_outcome.message.clone();
                log::info!(
                    "[USB] NEGOTIATION CLOCK: confirmed={}Hz, clockOk={}, rateVerified={}, clockId={}, iface={}",
                    clock_outcome.reported_sample_rate.unwrap_or(0),
                    clock_outcome.clock_ok,
                    clock_outcome.rate_verified,
                    clock.clock_id,
                    clock.interface_number,
                );
                if clock_outcome.rate_verified
                    && clock_outcome.reported_sample_rate == Some(requested_format.sample_rate)
                {
                    dac_mode = DacMode::FullControl;
                    set_effective_playback_format(requested_format);
                    set_dac_mode(dac_mode);
                    set_clock_verification(
                        clock_attempted,
                        clock_succeeded,
                        rate_verified,
                        reported_rate,
                    );
                    if let Some(message) = last_message {
                        dev_eprintln!("Android USB direct: {}", message);
                    }
                    return Ok(requested_format);
                }
            } else {
                last_message = supported_ranges.as_ref().map(|ranges| {
                    format!(
                        "Requested {} Hz is not supported by clock {} on interface {}; supported rates: {}",
                        requested_format.sample_rate,
                        clock.clock_id,
                        clock.interface_number,
                        format_sampling_frequency_ranges(ranges),
                    )
                });
            }

            if let Some(actual_rate) = choose_adaptive_sample_rate(
                requested_format.sample_rate,
                current_rate,
                supported_ranges.as_deref(),
                capability_model.as_ref(),
                &usb_device,
                &claimed_handle.handle,
                speed,
                requested_format,
            )? {
                effective_format.sample_rate = actual_rate;
                dac_mode = if actual_rate == requested_format.sample_rate {
                    DacMode::FixedClock
                } else {
                    DacMode::AdaptiveStreaming
                };
                reported_rate = reported_rate.or(current_rate).or(Some(actual_rate));
                rate_verified =
                    current_rate == Some(actual_rate) || reported_rate == Some(actual_rate);
            } else {
                let message = last_message.unwrap_or_else(|| {
                    format!(
                        "Unable to verify DAC rate for requested {} Hz during negotiation; continuing with direct USB at the requested stream rate",
                        requested_format.sample_rate
                    )
                });
                reported_rate = reported_rate
                    .or(current_rate)
                    .or(Some(requested_format.sample_rate));
                last_message = Some(message);
            }
        } else if candidate.is_uac1 {
            match set_uac1_sampling_frequency(
                &claimed_handle.handle,
                candidate.interface_number,
                candidate.endpoint_address,
                requested_format.sample_rate,
            ) {
                Ok(()) => {
                    dev_eprintln!(
                        "[USB] UAC1 SET_CUR: endpoint=0x{:02x} rate={}Hz",
                        candidate.endpoint_address, requested_format.sample_rate
                    );
                    dac_mode = DacMode::FixedClock;
                    reported_rate = Some(requested_format.sample_rate);
                    last_message = Some(format!(
                        "UAC 1.0 device: set sampling frequency to {} Hz on endpoint 0x{:02x}",
                        requested_format.sample_rate, candidate.endpoint_address
                    ));
                }
                Err(e) => {
                    dev_eprintln!(
                        "[USB] UAC1 SET_CUR failed for endpoint=0x{:02x}: {}",
                        candidate.endpoint_address, e
                    );
                    // Defer the verdict: many UAC1 DACs (FiiO BR13) STALL every
                    // SET_CUR encoding while the streaming alt setting is
                    // inactive (alt 0). The stream-open path re-issues SET_CUR
                    // after the alt setting is live and refuses there if it
                    // still fails — bailing here would abort before the only
                    // attempt that can succeed.
                    dac_mode = DacMode::AdaptiveStreaming;
                    reported_rate = Some(requested_format.sample_rate);
                    last_message = Some(format!(
                        "UAC 1.0 device: rate set on endpoint 0x{:02x} deferred ({}); retrying after alt setting is active",
                        candidate.endpoint_address, e
                    ));
                }
            }
        } else if let Some(actual_rate) = choose_adaptive_sample_rate(
            requested_format.sample_rate,
            None,
            None,
            capability_model.as_ref(),
            &usb_device,
            &claimed_handle.handle,
            speed,
            requested_format,
        )? {
            effective_format.sample_rate = actual_rate;
            dac_mode = if actual_rate == requested_format.sample_rate {
                DacMode::FixedClock
            } else {
                DacMode::AdaptiveStreaming
            };
            let inferred_message = if actual_rate == requested_format.sample_rate {
                format!(
                    "Android USB direct: no clock control entity; using fixed clock {} Hz",
                    actual_rate
                )
            } else {
                format!(
                    "Android USB direct: SET_CUR unavailable or unsupported; using adaptive mode at {} Hz for requested {} Hz",
                    actual_rate, requested_format.sample_rate
                )
            };
            dev_eprintln!("{}", inferred_message);
            last_message = Some(inferred_message);
        } else {
            let message = format!(
                "Unable to determine a usable fixed clock rate for requested {} Hz during negotiation; continuing direct USB with assumed stream rate",
                requested_format.sample_rate
            );
            reported_rate = Some(requested_format.sample_rate);
            last_message = Some(message);
        }

        reported_rate = reported_rate.or(Some(effective_format.sample_rate));
        set_effective_playback_format(effective_format);
        set_dac_mode(dac_mode);
        set_clock_verification(
            clock_attempted,
            clock_succeeded,
            rate_verified,
            reported_rate,
        );
        if let Some(message) = last_message {
            dev_eprintln!("Android USB direct: {}", message);
        }
        Ok(effective_format)
    })();

    cleanup_claimed_handle(claimed_handle, cleanup_interface, lock_requested);
    negotiated
}

fn choose_adaptive_sample_rate(
    requested_sample_rate: u32,
    current_rate: Option<u32>,
    supported_ranges: Option<&[SamplingFrequencySubrange]>,
    capability_model: Option<&AndroidDirectUsbCapabilityModel>,
    device: &Device<Context>,
    handle: &DeviceHandle<Context>,
    speed: Speed,
    requested_format: AndroidDirectUsbPlaybackFormat,
) -> Result<Option<u32>, String> {
    let has_rate_evidence = current_rate.is_some()
        || supported_ranges.is_some_and(|ranges| !ranges.is_empty())
        || capability_model
            .is_some_and(|capabilities| !capabilities.supported_sample_rates.is_empty());

    if !has_rate_evidence {
        return Ok(None);
    }

    let mut candidates = Vec::new();
    if let Some(current_rate) = current_rate {
        candidates.push(current_rate);
    }
    if let Some(ranges) = supported_ranges {
        candidates.extend(candidate_rates_from_supported_ranges(
            ranges,
            requested_sample_rate,
        ));
    }
    if let Some(capability_model) = capability_model {
        candidates.extend(capability_model.supported_sample_rates.iter().copied());
    }
    candidates.sort_unstable();
    candidates.dedup();

    let mut ordered_candidates = Vec::new();
    if let Some(current_rate) = current_rate {
        ordered_candidates.push(current_rate);
    }
    ordered_candidates.extend(preferred_adaptive_sample_rates(requested_sample_rate));
    if let Some(ranges) = supported_ranges {
        ordered_candidates.extend(candidate_rates_from_supported_ranges(
            ranges,
            requested_sample_rate,
        ));
    }
    ordered_candidates.extend(candidates);
    ordered_candidates.sort_unstable();
    ordered_candidates.dedup();

    for candidate_rate in ordered_candidates {
        let candidate_format = AndroidDirectUsbPlaybackFormat {
            sample_rate: candidate_rate,
            ..requested_format
        };
        if select_stream_candidate(device, handle, candidate_format, speed).is_ok() {
            return Ok(Some(candidate_rate));
        }
    }

    Ok(None)
}

fn preferred_adaptive_sample_rates(requested_sample_rate: u32) -> Vec<u32> {
    let mut preferred = Vec::new();
    for rate in [
        requested_sample_rate,
        48_000,
        96_000,
        192_000,
        384_000,
        44_100,
        88_200,
        176_400,
        352_800,
    ] {
        if !preferred.contains(&rate) {
            preferred.push(rate);
        }
    }
    preferred
}

fn candidate_rates_from_supported_ranges(
    ranges: &[SamplingFrequencySubrange],
    requested_sample_rate: u32,
) -> Vec<u32> {
    let mut candidates = Vec::new();
    let preferred = preferred_adaptive_sample_rates(requested_sample_rate);

    for range in ranges {
        if range.res == 0 || range.min == range.max {
            candidates.push(range.min);
            continue;
        }

        for rate in preferred.iter().copied() {
            if sampling_frequency_ranges_support_rate(std::slice::from_ref(range), rate) {
                candidates.push(rate);
            }
        }

        candidates.push(range.min);
        if range.max != range.min {
            candidates.push(range.max);
        }
    }

    candidates.sort_unstable();
    candidates.dedup();
    candidates
}

fn sanitize_android_usb_playback_format(
    playback_format: AndroidDirectUsbPlaybackFormat,
) -> AndroidDirectUsbPlaybackFormat {
    let bit_depth = if playback_format.is_dop {
        match playback_format.bit_depth {
            24 | 32 => playback_format.bit_depth,
            _ => 24,
        }
    } else if playback_format.dsd_transport == DsdTransportMode::Native {
        playback_format.bit_depth
    } else {
        match playback_format.bit_depth {
            16 | 24 | 32 => playback_format.bit_depth,
            _ => 16,
        }
    };
    AndroidDirectUsbPlaybackFormat {
        sample_rate: playback_format.sample_rate.max(8_000),
        bit_depth,
        channels: playback_format.channels.max(1),
        is_dop: playback_format.is_dop,
        dsd_transport: playback_format.dsd_transport,
        dsd_bit_rate: playback_format.dsd_bit_rate,
    }
}

fn prepare_direct_usb_libusb() {
    DIRECT_USB_DISCOVERY_DISABLED.call_once(|| {
        if let Err(error) = disable_device_discovery() {
            dev_eprintln!(
                "Android USB direct: failed to disable libusb device discovery: {}",
                error
            );
        }
    });
}

fn current_lock_requested_for_fd(device_fd: RawFd) -> bool {
    DIRECT_USB_STATE
        .lock()
        .as_ref()
        .map(|state| state.lock_requested && state.device.fd == device_fd)
        .unwrap_or(false)
}

fn set_last_error(error: Option<String>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.last_error = error;
    }
}

fn set_direct_mode_refusal_reason(reason: Option<String>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.direct_mode_refusal_reason = reason;
    }
}

fn set_usb_stream_stable(stable: bool) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.usb_stream_stable = stable;
    }
}

fn set_software_volume_active(active: bool) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.software_volume_active = active;
        state.bit_perfect_verified = direct_path_is_bit_perfect(state);
    }
}

fn set_hardware_volume_control(control: Option<AndroidDirectUsbHardwareVolumeControl>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.hardware_volume_control = control;
        state.hardware_volume_generation = HARDWARE_VOLUME_GENERATION.fetch_add(1, Ordering::Relaxed);
        state.hardware_volume_normalized = None;
        state.hardware_mute_active = None;
        if state.hardware_volume_control.is_none() {
            state.hardware_volume_normalized = None;
            state.hardware_mute_active = None;
        }
    }
}

fn set_hardware_volume_error(error: Option<String>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.hardware_volume_error = error;
    }
}

fn publish_hardware_volume_snapshot(
    generation: u64,
    volume: f64,
    muted: Option<bool>,
) -> Result<(), String> {
    let mut guard = DIRECT_USB_STATE.lock();
    let state = guard
        .as_mut()
        .filter(|state| volume_generation_is_current(state, generation))
        .ok_or_else(|| "USB volume route changed during control transfer".to_string())?;
    state.hardware_volume_normalized = Some(volume);
    state.hardware_mute_active = muted;
    state.hardware_volume_error = None;
    Ok(())
}

fn set_hardware_volume_snapshot(volume: Option<f64>, muted: Option<bool>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        if let Some(volume) = volume {
            state.hardware_volume_normalized = Some(volume.clamp(0.0, 1.0));
        }
        if let Some(muted) = muted {
            state.hardware_mute_active = Some(muted);
        }
    }
}

fn set_runtime_stats(runtime_stats: Option<Arc<AndroidDirectUsbRuntimeStats>>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.runtime_stats = runtime_stats;
    }
}

fn set_capability_model(capability_model: Option<AndroidDirectUsbCapabilityModel>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.capability_model = capability_model;
    }
}

fn set_active_transport(candidate: Option<&AndroidIsoStreamCandidate>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.active_transport = candidate.map(|candidate| AndroidDirectUsbActiveTransport {
            interface_number: candidate.interface_number,
            alt_setting: candidate.alt_setting,
            endpoint_address: candidate.endpoint_address,
            endpoint_interval: candidate.endpoint_interval,
            service_interval_us: candidate.service_interval_us,
            max_packet_bytes: candidate.max_packet_bytes,
            format_tag: format_tag_label(candidate.format_tag).to_string(),
            channels: candidate.channels,
            subslot_size: candidate.subslot_size,
            bit_resolution: candidate.bit_resolution,
            sample_rates: candidate.sample_rates.clone(),
            sync_type: sync_type_label(candidate.sync_type).to_string(),
            usage_type: usage_type_label(candidate.usage_type).to_string(),
            refresh: candidate.refresh,
            synch_address: candidate.synch_address,
            feedback_endpoint_address: candidate.feedback_endpoint.map(|feedback| feedback.address),
            feedback_transfer_type: candidate
                .feedback_endpoint
                .map(|feedback| transfer_type_label(feedback.transfer_type).to_string()),
        });
    }
}

fn android_direct_usb_engine_state_label(state: AndroidDirectUsbEngineState) -> &'static str {
    match state {
        AndroidDirectUsbEngineState::Idle => "idle",
        AndroidDirectUsbEngineState::UsbInit => "usbInit",
        AndroidDirectUsbEngineState::UsbReady => "usbReady",
        AndroidDirectUsbEngineState::Streaming => "streaming",
        AndroidDirectUsbEngineState::Error => "error",
        AndroidDirectUsbEngineState::Fallback => "fallback",
    }
}

fn set_android_usb_engine_state(state: AndroidDirectUsbEngineState, reason: Option<String>) {
    let mut lifecycle_state = DIRECT_USB_LIFECYCLE_STATE.lock();
    let previous = lifecycle_state.engine_state;
    lifecycle_state.engine_state = state;
    lifecycle_state.reason = reason;
    if previous != state {
        dev_eprintln!(
            "Android USB direct engine state: {:?} -> {:?}",
            previous, state
        );
    }
    dev_eprintln!(
        "[USB][STATE] {}{}",
        android_direct_usb_engine_state_label(state),
        lifecycle_state
            .reason
            .as_ref()
            .map(|reason| format!(" ({})", reason))
            .unwrap_or_default()
    );
}

pub fn mark_android_usb_fallback(reason: Option<String>) {
    set_android_usb_engine_state(AndroidDirectUsbEngineState::Fallback, reason);
}

fn set_clock_status(clock_status: Option<AndroidDirectUsbClockStatus>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.clock_status = clock_status;
    }
}

fn set_clock_verification(
    attempted: bool,
    succeeded: bool,
    passed: bool,
    reported_sample_rate: Option<u32>,
) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.clock_control_attempted = attempted;
        state.clock_control_succeeded = succeeded;
        state.clock_verification_passed = passed;
        if let Some(clock_status) = state.clock_status.as_mut() {
            clock_status.reported_sample_rate = reported_sample_rate;
        }
        state.bit_perfect_verified = direct_path_is_bit_perfect(state);
    }
}

fn direct_path_is_bit_perfect(state: &AndroidDirectUsbState) -> bool {
    if !state.stream_active {
        return false;
    }

    // Later exact completions cannot verify audio from an earlier interrupted
    // transfer. Only a new stream can qualify again.
    if state
        .runtime_stats
        .as_ref()
        .is_some_and(|stats| stats.transport_unverified())
    {
        return false;
    }

    let Some(requested) = state.requested_playback_format else {
        return false;
    };
    let Some(effective) = state.playback_format else {
        return false;
    };

    // Bit-perfect requires: matching format, verified clock, and the engine
    // callback is running in bit_perfect bypass mode (no volume/EQ/dynamics).
    // Software volume is always inactive when bit_perfect bypass is enabled.
    // For DSD transports, additionally require that the live wire payload has
    // passed the DoP-marker / native-byte audit (USB_DSD_PAYLOAD_VERIFIED).
    let payload_ok = match effective.dsd_transport {
        DsdTransportMode::DoP | DsdTransportMode::Native => usb_dsd_payload_verified(),
        DsdTransportMode::None => usb_pcm_payload_verified(),
    };
    requested.sample_rate == effective.sample_rate
        && requested.bit_depth == effective.bit_depth
        && requested.channels == effective.channels
        && state.clock_verification_passed
        && payload_ok
}

fn set_effective_playback_format(mut playback_format: AndroidDirectUsbPlaybackFormat) {
    // Never store 0 Hz — buggy DACs (Fosi DS2 / Savitech) report 0 via
    // GET_CUR even after a successful SET_CUR. If the requested format has
    // a valid rate, use it instead. This stops the 0 from poisoning every
    // downstream consumer (validate_android_direct_request, format
    // selection, engine sample rate resolution, position calculation).
    if playback_format.sample_rate == 0 {
        if let Some(state) = DIRECT_USB_STATE.lock().as_ref() {
            if let Some(req) = state.requested_playback_format {
                if req.sample_rate > 0 {
                    dev_eprintln!(
                        "[USB] set_effective_playback_format: refusing to store 0 Hz, using requested {} Hz instead",
                        req.sample_rate
                    );
                    playback_format.sample_rate = req.sample_rate;
                }
            }
        }
    }
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.playback_format = Some(playback_format);
    }
}

fn set_dac_mode(mode: DacMode) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.dac_mode = mode;
    }
}

fn set_packet_schedule_preview(packet_schedule_frames_preview: Vec<u32>) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.packet_schedule_frames_preview = packet_schedule_frames_preview;
    }
}

fn set_stream_active(active: bool) {
    if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
        state.stream_active = active;
        if !active {
            state.hardware_volume_control = None;
            state.hardware_volume_normalized = None;
            state.hardware_mute_active = None;
            state.hardware_volume_generation = HARDWARE_VOLUME_GENERATION.fetch_add(1, Ordering::Relaxed);
        }
    }
}

fn release_idle_lock() {
    // Android owns the claims and releases them after the USB session stops.
    DIRECT_USB_LOCK.lock().take();
}

impl From<AndroidDirectUsbLock> for AndroidDirectUsbClaimedHandle {
    fn from(value: AndroidDirectUsbLock) -> Self {
        Self {
            device_fd: value.device_fd,
            context: value.context,
            handle: value.handle,
            claimed_interfaces: value.claimed_interfaces,
        }
    }
}

impl AndroidDirectUsbClaimedHandle {
    fn into_idle_lock(self) -> AndroidDirectUsbLock {
        AndroidDirectUsbLock {
            device_fd: self.device_fd,
            context: self.context,
            handle: self.handle,
            claimed_interfaces: self.claimed_interfaces,
        }
    }

    fn ensure_interface_claimed(&self, interface_number: u8) -> Result<(), String> {
        if !self.claimed_interfaces.contains(&interface_number) {
            return Err(format!(
                "USB interface {} was not claimed during Android direct USB registration",
                interface_number
            ));
        }
        Ok(())
    }

    fn set_alternate_setting(&self, interface_number: u8, alternate_setting: u8) -> Result<(), String> {
        self.ensure_interface_claimed(interface_number)?;
        let request = UsbfsSetInterface {
            interface: interface_number.into(),
            altsetting: alternate_setting.into(),
        };
        // Android's fd and our dup share the usbfs claims. libusb's own
        // per-handle claim table does not, so its alt-setting helper refuses
        // these interfaces. Use the same kernel ioctl Android uses instead.
        let result = unsafe { libc::ioctl(self.device_fd, USBDEVFS_SETINTERFACE, &request) };
        if result < 0 {
            return Err(std::io::Error::last_os_error().to_string());
        }
        Ok(())
    }
}

fn open_claimed_usb_handle(
    device: &AndroidDirectUsbDevice,
) -> Result<AndroidDirectUsbClaimedHandle, String> {
    if let Some(lock) = DIRECT_USB_LOCK.lock().take() {
        if lock.device_fd == device.fd {
            return Ok(lock.into());
        }
    }

    wrap_android_usb_handle(device)
}

fn wrap_android_usb_handle(
    device: &AndroidDirectUsbDevice,
) -> Result<AndroidDirectUsbClaimedHandle, String> {
    prepare_direct_usb_libusb();

    let context =
        Context::new().map_err(|error| format!("Failed to create libusb context: {}", error))?;
    let handle = unsafe { context.open_device_with_fd(device.fd) }
        .map_err(|error| format!("Failed to wrap Android USB file descriptor: {}", error))?;

    Ok(AndroidDirectUsbClaimedHandle {
        device_fd: device.fd,
        context,
        handle,
        claimed_interfaces: Arc::clone(&device.claimed_interfaces),
    })
}

#[derive(Debug, Clone)]
struct AndroidAudioControlTopology {
    interface_number: u8,
    protocol: AudioControlProtocol,
    streaming_interfaces: Vec<u8>,
    input_terminals: Vec<crate::uac2::InputTerminal>,
    feature_units: Vec<crate::uac2::FeatureUnit>,
    output_terminals: Vec<crate::uac2::OutputTerminal>,
    sources: Vec<(u8, Vec<u8>)>,
}

fn parse_audio_control_topologies(
    device: &Device<Context>,
) -> Result<Vec<AndroidAudioControlTopology>, String> {
    let config_descriptor = device
        .active_config_descriptor()
        .map_err(|error| format!("Failed to read active USB config descriptor: {}", error))?;
    let parser = AudioControlParser;
    let mut topologies = Vec::new();

    for interface in config_descriptor.interfaces() {
        for descriptor in interface.descriptors() {
            if descriptor.class_code() != USB_CLASS_AUDIO
                || descriptor.sub_class_code() != USB_SUBCLASS_AUDIOCONTROL
            {
                continue;
            }

            let mut topology = AndroidAudioControlTopology {
                interface_number: descriptor.interface_number(),
                protocol: match descriptor.protocol_code() {
                    0x00 => AudioControlProtocol::Uac1,
                    0x20 => AudioControlProtocol::Uac2,
                    _ => continue,
                },
                streaming_interfaces: Vec::new(),
                input_terminals: Vec::new(),
                feature_units: Vec::new(),
                output_terminals: Vec::new(),
                sources: Vec::new(),
            };

            for extra in DescriptorIter::new(descriptor.extra()) {
                if extra.get(1) != Some(&USB_DT_CS_INTERFACE) {
                    continue;
                }
                let is_v1 = topology.protocol == AudioControlProtocol::Uac1;
                match extra.get(2).copied() {
                    Some(1) if is_v1 => {
                        let header = parser.parse_ac_header_v1(extra).map_err(|e| e.to_string())?;
                        topology.streaming_interfaces = header.ba_interface_nr;
                    }
                    Some(UAC2_INPUT_TERMINAL) => {
                        let terminal = if is_v1 { parser.parse_input_terminal_v1(extra) }
                            else { parser.parse_input_terminal(extra) }.map_err(|e| e.to_string())?;
                        topology.input_terminals.push(terminal);
                    }
                    Some(UAC2_OUTPUT_TERMINAL) => {
                        let terminal = if is_v1 { parser.parse_output_terminal_v1(extra) }
                            else { parser.parse_output_terminal(extra) }.map_err(|e| e.to_string())?;
                        topology.sources.push((terminal.b_terminal_id, vec![terminal.b_source_id]));
                        topology.output_terminals.push(terminal);
                    }
                    Some(UAC2_FEATURE_UNIT) => {
                        let unit = if is_v1 { parser.parse_feature_unit_v1(extra) }
                            else { parser.parse_feature_unit(extra) }.map_err(|e| e.to_string())?;
                        topology.sources.push((unit.b_unit_id, vec![unit.b_source_id]));
                        topology.feature_units.push(unit);
                    }
                    Some(4 | 5) => {
                        let count = extra.get(4).copied().unwrap_or(0) as usize;
                        if count == 0 || extra.len() < 6 + count {
                            return Err("malformed USB mixer/selector sources".to_string());
                        }
                        // Do not guess the active branch of a multi-input selector.
                        if extra[2] == 4 || count == 1 {
                            topology.sources.push((extra[3], extra[5..5 + count].to_vec()));
                        }
                    }
                    _ => {}
                }
            }

            if !topology.feature_units.is_empty() || !topology.output_terminals.is_empty() {
                topologies.push(topology);
            }
        }
    }

    Ok(topologies)
}

fn read_feature_unit_i16_control(
    device: &impl FeatureUnitControl,
    interface_number: u8,
    feature_unit_id: u8,
    channel: u16,
    request: u8,
    control_selector: u16,
) -> Result<i16, String> {
    let request_type = USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = control_selector | (channel & 0xff);
    let index = (interface_number as u16) | ((feature_unit_id as u16) << 8);
    let mut data = [0u8; 2];
    let transferred = device
        .feature_unit_control(request_type, request, value, index, &mut data)
        .map_err(|error| format!(
            "USB volume read request=0x{request:02x} interface={interface_number} unit={feature_unit_id} channel={channel} selector=0x{control_selector:04x}: {error}"
        ))?;
    if transferred < data.len() {
        return Err(format!(
            "USB volume read request=0x{request:02x} interface={interface_number} unit={feature_unit_id} channel={channel} returned {} bytes, expected {}",
            transferred,
            data.len()
        ));
    }
    Ok(i16::from_le_bytes(data))
}

fn write_feature_unit_i16_control(
    device: &impl FeatureUnitControl,
    interface_number: u8,
    feature_unit_id: u8,
    channel: u16,
    control_selector: u16,
    value_raw: i16,
) -> Result<(), String> {
    let request_type = USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = control_selector | (channel & 0xff);
    let index = (interface_number as u16) | ((feature_unit_id as u16) << 8);
    let mut data = value_raw.to_le_bytes();
    let transferred = device
        .feature_unit_control(request_type, UAC2_REQUEST_SET_CUR, value, index, &mut data)
        .map_err(|error| format!(
            "USB volume SET_CUR interface={interface_number} unit={feature_unit_id} channel={channel} selector=0x{control_selector:04x}: {error}"
        ))?;
    if transferred != data.len() {
        return Err(format!(
            "short USB volume SET_CUR interface={interface_number} unit={feature_unit_id} channel={channel}: {transferred}/{} bytes", data.len()
        ));
    }
    Ok(())
}

fn read_feature_unit_bool_control(
    device: &impl FeatureUnitControl,
    interface_number: u8,
    feature_unit_id: u8,
    channel: u16,
    protocol: AudioControlProtocol,
    control_selector: u16,
) -> Result<bool, String> {
    let request_type = USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = control_selector | (channel & 0xff);
    let index = (interface_number as u16) | ((feature_unit_id as u16) << 8);
    let mut data = [0u8; 1];
    let transferred = device
        .feature_unit_control(
            request_type,
            protocol.current_request(),
            value,
            index,
            &mut data,
        )
        .map_err(|error| format!(
            "USB mute {protocol:?} GET_CUR interface={interface_number} unit={feature_unit_id} channel={channel}: {error}"
        ))?;
    if transferred < data.len() {
        return Err(format!(
            "USB mute {protocol:?} GET_CUR interface={interface_number} unit={feature_unit_id} channel={channel} returned {} bytes, expected {}",
            transferred,
            data.len()
        ));
    }
    Ok(data[0] != 0)
}

fn write_feature_unit_bool_control(
    device: &impl FeatureUnitControl,
    interface_number: u8,
    feature_unit_id: u8,
    channel: u16,
    control_selector: u16,
    enabled: bool,
) -> Result<(), String> {
    let request_type = USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = control_selector | (channel & 0xff);
    let index = (interface_number as u16) | ((feature_unit_id as u16) << 8);
    let mut data = [u8::from(enabled)];
    let transferred = device
        .feature_unit_control(request_type, UAC2_REQUEST_SET_CUR, value, index, &mut data)
        .map_err(|error| format!(
            "USB mute SET_CUR interface={interface_number} unit={feature_unit_id} channel={channel}: {error}"
        ))?;
    if transferred != data.len() {
        return Err(format!(
            "short USB mute SET_CUR interface={interface_number} unit={feature_unit_id} channel={channel}: {transferred}/{} bytes", data.len()
        ));
    }
    Ok(())
}

fn read_feature_unit_volume_range(
    device: &AndroidDirectUsbDevice,
    interface_number: u8,
    feature_unit_id: u8,
    channel: u16,
    protocol: AudioControlProtocol,
) -> Result<Vec<VolumeRange>, String> {
    if protocol == AudioControlProtocol::Uac2 {
        // Read the count first, then request exactly the advertised response.
        // Some DAC firmware rejects an oversized RANGE request.
        let request_type = USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
        let value = UAC2_FEATURE_UNIT_VOLUME_CONTROL | (channel & 0xff);
        let index = interface_number as u16 | (feature_unit_id as u16) << 8;
        let mut count_bytes = [0u8; 2];
        let transferred = device.feature_unit_control(
            request_type, UAC2_REQUEST_GET_RANGE, value, index,
            &mut count_bytes,
        ).map_err(|e| format!("USB volume RANGE count interface={interface_number} unit={feature_unit_id} channel={channel}: {e}"))?;
        if transferred != count_bytes.len() {
            return Err(format!("short USB volume RANGE count interface={interface_number} unit={feature_unit_id} channel={channel}: {transferred}/2 bytes"));
        }
        let count = u16::from_le_bytes(count_bytes) as usize;
        if !(1..=64).contains(&count) {
            return Err(format!("invalid USB volume RANGE count interface={interface_number} unit={feature_unit_id} channel={channel}: {count}"));
        }
        let mut data = [0u8; 386];
        let expected = 2 + count * 6;
        let transferred = device.feature_unit_control(
            request_type, UAC2_REQUEST_GET_RANGE, value, index,
            &mut data[..expected],
        ).map_err(|e| format!("USB volume RANGE interface={interface_number} unit={feature_unit_id} channel={channel}: {e}"))?;
        if transferred != expected {
            return Err(format!("short USB volume RANGE interface={interface_number} unit={feature_unit_id} channel={channel}: {transferred}/{expected} bytes"));
        }
        return parse_uac2_volume_ranges(&data[..transferred]);
    }
    Ok(vec![VolumeRange {
        min:
        read_feature_unit_i16_control(
            device,
            interface_number,
            feature_unit_id,
            channel,
            UAC1_REQUEST_GET_MIN,
            UAC2_FEATURE_UNIT_VOLUME_CONTROL,
        )?,
        max:
        read_feature_unit_i16_control(
            device,
            interface_number,
            feature_unit_id,
            channel,
            UAC1_REQUEST_GET_MAX,
            UAC2_FEATURE_UNIT_VOLUME_CONTROL,
        )?,
        resolution:
        read_feature_unit_i16_control(
            device,
            interface_number,
            feature_unit_id,
            channel,
            UAC1_REQUEST_GET_RES,
            UAC2_FEATURE_UNIT_VOLUME_CONTROL,
        )?,
    }.validate()?])
}

fn build_hardware_volume_control_from_feature_unit(
    device: &AndroidDirectUsbDevice,
    topology: &AndroidAudioControlTopology,
    feature_unit: &crate::uac2::FeatureUnit,
    channels: u16,
) -> Result<Option<AndroidDirectUsbHardwareVolumeControl>, String> {
    let Some(volume_channels) = topology.protocol.volume_channels(&feature_unit.bma_controls, channels)
        else { return Ok(None); };
    let mut ranges = Vec::new();
    for &channel in &volume_channels {
        let channel_ranges = read_feature_unit_volume_range(
            device, topology.interface_number, feature_unit.b_unit_id, channel, topology.protocol,
        )?;
        if ranges.is_empty() { ranges = channel_ranges; }
        else if ranges != channel_ranges {
            return Err("per-channel USB volume ranges differ; unified control refused".to_string());
        }
    }
    let (min_volume_raw, max_volume_raw) = volume_bounds(&ranges);
    if min_volume_raw == max_volume_raw {
        return Ok(None);
    }
    // Master mute only: muting one channel would not mute playback.
    let mute_channel = topology.protocol.writable(feature_unit.bma_controls[0], 1).then_some(0);
    let resolution_raw = ranges.iter().map(|range| range.resolution).min().unwrap_or(0);
    Ok(Some(AndroidDirectUsbHardwareVolumeControl {
        interface_number: topology.interface_number,
        feature_unit_id: feature_unit.b_unit_id,
        protocol: topology.protocol,
        volume_channels,
        ranges,
        mute_channel,
        min_volume_raw,
        max_volume_raw,
        resolution_raw,
    }))
}

fn discover_hardware_volume_control_for_terminal(
    device: &AndroidDirectUsbDevice,
    topology: &AndroidAudioControlTopology,
    terminal_link: u8,
    channels: u16,
) -> Result<Option<AndroidDirectUsbHardwareVolumeControl>, String> {
    // An OUT streaming terminal must be a USB input terminal, not capture.
    if !topology.input_terminals.iter().any(|terminal|
        terminal.b_terminal_id == terminal_link && terminal.w_terminal_type == 0x0101
    ) { return Ok(None); }
    let mut ancestors = HashSet::new();
    let mut pending: Vec<u8> = topology.output_terminals.iter()
        .filter(|terminal| terminal.w_terminal_type != 0x0101)
        .map(|terminal| terminal.b_terminal_id).collect();
    while let Some(entity) = pending.pop() {
        if ancestors.insert(entity) {
            for (_, sources) in topology.sources.iter().filter(|(id, _)| *id == entity) {
                pending.extend(sources.iter().copied());
            }
        }
    }
    let mut pending = vec![terminal_link];
    let mut visited = HashSet::new();

    while let Some(entity_id) = pending.pop() {
        if !visited.insert(entity_id) {
            continue;
        }

        if let Some(feature_unit) = topology
            .feature_units
            .iter()
            .find(|feature_unit| feature_unit.b_unit_id == entity_id)
        {
            if ancestors.contains(&entity_id) {
                if let Some(control) = build_hardware_volume_control_from_feature_unit(
                    device, topology, feature_unit, channels,
                )? { return Ok(Some(control)); }
            }
        }

        for (id, sources) in &topology.sources {
            if sources.contains(&entity_id) && ancestors.contains(id) {
                pending.push(*id);
            }
        }
    }

    Ok(None)
}

fn discover_android_usb_hardware_volume_control(
    descriptors: &Device<Context>,
    device: &AndroidDirectUsbDevice,
    candidate: &AndroidIsoStreamCandidate,
    clock_interface: Option<u8>,
) -> Result<Option<AndroidDirectUsbHardwareVolumeControl>, String> {
    let terminal = candidate.terminal_link.ok_or_else(|| "no playback terminal link for USB volume".to_string())?;
    let topologies = parse_audio_control_topologies(descriptors)?;
    let matches: Vec<_> = topologies.iter().filter(|topology| {
        clock_interface.map_or(true, |interface| topology.interface_number == interface)
            && (topology.protocol != AudioControlProtocol::Uac1
                || topology.streaming_interfaces.contains(&candidate.interface_number))
            && topology.input_terminals.iter().any(|input| input.b_terminal_id == terminal)
    }).collect();
    if matches.len() != 1 {
        return Err("USB playback AudioControl topology is missing or ambiguous".to_string());
    }
    discover_hardware_volume_control_for_terminal(device, matches[0], terminal, candidate.channels)
}

fn refresh_android_usb_hardware_volume_snapshot(
    device: &impl FeatureUnitControl,
    control: &AndroidDirectUsbHardwareVolumeControl,
) -> Result<(f64, Option<bool>), String> {
    const GET_CUR_RETRIES: u32 = 3;
    const RETRY_DELAY_MS: u64 = 10;

    let mut last_err = None;
    for attempt in 0..GET_CUR_RETRIES {
        let read = read_hardware_volume_snapshot(
            &control.volume_channels,
            &control.ranges,
            |channel| read_feature_unit_i16_control(
                device, control.interface_number, control.feature_unit_id, channel,
                control.protocol.current_request(), UAC2_FEATURE_UNIT_VOLUME_CONTROL,
            ),
            || control.mute_channel.map(|channel| read_feature_unit_bool_control(
                device, control.interface_number, control.feature_unit_id, channel,
                control.protocol, UAC2_FEATURE_UNIT_MUTE_CONTROL,
            )).transpose(),
        );
        match read {
            Ok(snapshot) => {
                if let Some(error) = snapshot.mute_error {
                    log_warn!("[USB] Hardware volume remains available; optional mute unavailable: {error}");
                }
                return Ok((snapshot.volume, snapshot.muted));
            }
            Err(e) => {
                dev_eprintln!("[VolFlow] GET_CUR attempt {} failed: {e}", attempt + 1);
                last_err = Some(e);
                if attempt < GET_CUR_RETRIES - 1 {
                    std::thread::sleep(Duration::from_millis(RETRY_DELAY_MS));
                }
            }
        }
    }
    Err(last_err.unwrap_or_else(|| "GET_CUR failed with no error recorded".to_string()))
}

pub fn android_direct_has_hardware_volume_control() -> bool {
    android_direct_hardware_volume_generation(true).is_some()
}

pub fn android_direct_hardware_volume_generation(require_hardware_control: bool) -> Option<u64> {
    let state = DIRECT_USB_STATE.lock();
    if USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst) {
        return None;
    }
    state
        .as_ref()
        .filter(|state| !require_hardware_control || state.hardware_volume_control.is_some())
        .map(|state| state.hardware_volume_generation)
}

fn volume_generation_is_current(state: &AndroidDirectUsbState, generation: u64) -> bool {
    state.hardware_volume_generation == generation
        && !USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst)
}

fn hardware_volume_state(generation: u64) -> Result<AndroidDirectUsbState, String> {
    DIRECT_USB_STATE
        .lock()
        .as_ref()
        .filter(|state| volume_generation_is_current(state, generation))
        .cloned()
        .ok_or_else(|| "USB volume route changed before control transfer".into())
}

fn record_hardware_volume_error(generation: u64, error: &str) {
    if let Some(state) = DIRECT_USB_STATE
        .lock()
        .as_mut()
        .filter(|state| volume_generation_is_current(state, generation))
    {
        state.hardware_volume_error = Some(error.to_owned());
        state.hardware_volume_normalized = None;
        state.hardware_mute_active = None;
    }
}

pub fn android_direct_cached_hardware_volume() -> Option<f64> {
    DIRECT_USB_STATE
        .lock()
        .as_ref()
        .and_then(|state| state.hardware_volume_normalized)
}

pub fn android_direct_cached_hardware_mute() -> Option<bool> {
    DIRECT_USB_STATE
        .lock()
        .as_ref()
        .and_then(|state| state.hardware_mute_active)
}

fn apply_android_usb_hardware_volume(
    device: &impl FeatureUnitControl,
    control: &AndroidDirectUsbHardwareVolumeControl,
    volume: f64,
    route_is_current: impl Fn() -> bool,
) -> Result<(f64, Option<bool>), String> {
    if !volume.is_finite() {
        return Err("USB hardware volume must be finite".to_string());
    }
    if !route_is_current() {
        return Err("USB volume route changed before write".into());
    }
    let target_raw = quantize_volume(volume, &control.ranges);
    dev_eprintln!(
        "[VolFlow] min={} max={} res={} -> raw={target_raw}",
        control.min_volume_raw, control.max_volume_raw, control.resolution_raw
    );
    // Snapshot every channel before a grouped write, for best-effort rollback.
    let previous = control
        .volume_channels
        .iter()
        .map(|&channel| {
            read_feature_unit_i16_control(
                device,
                control.interface_number,
                control.feature_unit_id,
                channel,
                control.protocol.current_request(),
                UAC2_FEATURE_UNIT_VOLUME_CONTROL,
            )
        })
        .collect::<Result<Vec<_>, _>>()?;
    let mut attempted = 0;
    let result = (|| {
        for &channel in &control.volume_channels {
            if !route_is_current() {
                return Err("USB volume route changed before write".into());
            }
            // A failed transfer may still have changed the device. Include it
            // when restoring the previous levels.
            attempted += 1;
            write_feature_unit_i16_control(
                device,
                control.interface_number,
                control.feature_unit_id,
                channel,
                UAC2_FEATURE_UNIT_VOLUME_CONTROL,
                target_raw,
            )?;
        }
        if !route_is_current() {
            return Err("USB volume route changed before readback".into());
        }
        let (normalized, muted) = refresh_android_usb_hardware_volume_snapshot(device, control)?;
        if !route_is_current() {
            return Err("USB volume route changed during readback".into());
        }
        let expected = normalize_volume(target_raw, &control.ranges);
        if (normalized - expected).abs() > 1e-6 {
            return Err(format!(
                "volume verification failed: expected {expected:.3}, got {normalized:.3}"
            ));
        }
        Ok((normalized, muted))
    })();
    let Err(error) = result else {
        return result;
    };

    // SET_CUR and its readback are one transaction. A successful write with
    // failed verification must not quietly leave the new gain in place. The
    // caller still holds the volume lock, so rollback uses the old DAC's fd
    // even if disconnect has been requested.
    let mut rollback_error = None;
    for (&channel, &raw) in control.volume_channels[..attempted].iter().zip(&previous) {
        if let Err(error) = write_feature_unit_i16_control(
            device,
            control.interface_number,
            control.feature_unit_id,
            channel,
            UAC2_FEATURE_UNIT_VOLUME_CONTROL,
            raw,
        ) {
            rollback_error.get_or_insert(error);
        }
    }

    if let Some(rollback_error) = rollback_error {
        return Err(format!("{error}; USB volume rollback failed: {rollback_error}"));
    }
    Err(error)
}

#[cfg(test)]
mod feature_unit_control_tests {
    use super::*;
    use std::cell::{Cell, RefCell};

    struct FakeDac {
        volume: RefCell<[i16; 2]>,
        muted: Cell<bool>,
        requests: RefCell<Vec<(u8, u8, u16, u16)>>,
        failed_write_channel: Cell<Option<u16>>,
        readback_failures: Cell<usize>,
        fail_unmute_readback: bool,
        ignore_higher_volume: bool,
        mute_unavailable: bool,
    }

    impl FakeDac {
        fn new() -> Self {
            Self {
                volume: RefCell::new([-500, -500]),
                muted: Cell::new(false),
                requests: RefCell::new(Vec::new()),
                failed_write_channel: Cell::new(None),
                readback_failures: Cell::new(0),
                fail_unmute_readback: false,
                ignore_higher_volume: false,
                mute_unavailable: false,
            }
        }
    }

    impl FeatureUnitControl for FakeDac {
        fn feature_unit_control(
            &self,
            request_type: u8,
            request: u8,
            value: u16,
            index: u16,
            data: &mut [u8],
        ) -> std::io::Result<usize> {
            self.requests.borrow_mut().push((request_type, request, value, index));
            let reading = request_type & USB_DIR_IN != 0;
            let channel = value & 0xff;
            if value & 0xff00 == UAC2_FEATURE_UNIT_MUTE_CONTROL {
                if self.mute_unavailable {
                    return Err(std::io::ErrorKind::BrokenPipe.into());
                }
                if reading {
                    if self.fail_unmute_readback && !self.muted.get() {
                        return Err(std::io::ErrorKind::TimedOut.into());
                    }
                    data.copy_from_slice(&[u8::from(self.muted.get())]);
                } else {
                    self.muted.set(data[0] != 0);
                }
                return Ok(data.len());
            }
            let slot = usize::from(channel - 1);
            let mut volume = self.volume.borrow_mut();
            if reading {
                if volume[slot] == 0 && self.readback_failures.get() > 0 {
                    self.readback_failures.set(self.readback_failures.get() - 1);
                    return Err(std::io::ErrorKind::TimedOut.into());
                }
                data.copy_from_slice(&volume[slot].to_le_bytes());
            } else {
                let target = i16::from_le_bytes(data.try_into().unwrap());
                if !self.ignore_higher_volume || target <= volume[slot] {
                    volume[slot] = target;
                }
                // Model a write that reached the DAC but returned an error.
                if self.failed_write_channel.get() == Some(channel) {
                    self.failed_write_channel.set(None);
                    return Err(std::io::ErrorKind::BrokenPipe.into());
                }
            }
            Ok(data.len())
        }
    }

    fn stereo_control() -> AndroidDirectUsbHardwareVolumeControl {
        AndroidDirectUsbHardwareVolumeControl {
            interface_number: 3,
            feature_unit_id: 9,
            protocol: AudioControlProtocol::Uac2,
            volume_channels: vec![1, 2],
            ranges: vec![VolumeRange {
                min: -1000,
                max: 0,
                resolution: 10,
            }],
            mute_channel: Some(0),
            min_volume_raw: -1000,
            max_volume_raw: 0,
            resolution_raw: 10,
        }
    }

    #[test]
    fn feature_unit_requests_keep_their_class_request_encoding() {
        let dac = FakeDac::new();
        let current = |protocol: AudioControlProtocol| {
            read_feature_unit_i16_control(
                &dac,
                3,
                9,
                1,
                protocol.current_request(),
                UAC2_FEATURE_UNIT_VOLUME_CONTROL,
            )
        };
        assert_eq!(current(AudioControlProtocol::Uac2), Ok(-500));
        assert_eq!(current(AudioControlProtocol::Uac1), Ok(-500));
        write_feature_unit_i16_control(&dac, 3, 9, 2, UAC2_FEATURE_UNIT_VOLUME_CONTROL, -20).unwrap();
        write_feature_unit_bool_control(&dac, 3, 9, 0, UAC2_FEATURE_UNIT_MUTE_CONTROL, true).unwrap();
        assert!(read_feature_unit_bool_control(
            &dac,
            3,
            9,
            0,
            AudioControlProtocol::Uac2,
            UAC2_FEATURE_UNIT_MUTE_CONTROL,
        )
        .unwrap());
        assert_eq!(
            *dac.requests.borrow(),
            [
                (0xa1, 0x01, 0x0201, 0x0903),
                (0xa1, 0x81, 0x0201, 0x0903),
                (0x21, 0x01, 0x0202, 0x0903),
                (0x21, 0x01, 0x0100, 0x0903),
                (0xa1, 0x01, 0x0100, 0x0903),
            ]
        );
    }

    #[test]
    fn grouped_write_restores_both_channels_when_later_set_cur_fails() {
        let dac = FakeDac::new();
        dac.failed_write_channel.set(Some(2));
        let error = apply_android_usb_hardware_volume(&dac, &stereo_control(), 1.0, || true)
            .unwrap_err();
        assert!(error.contains("SET_CUR") && error.contains("channel=2"), "{error}");
        assert_eq!(*dac.volume.borrow(), [-500, -500]);
    }

    #[test]
    fn grouped_write_rolls_back_when_the_new_level_cannot_be_read() {
        let dac = FakeDac::new();
        dac.readback_failures.set(3);
        let error = apply_android_usb_hardware_volume(&dac, &stereo_control(), 1.0, || true)
            .unwrap_err();
        assert!(error.contains("USB volume read request"), "{error}");
        assert_eq!(*dac.volume.borrow(), [-500, -500]);
    }

    #[test]
    fn grouped_write_rolls_back_after_a_mismatched_readback() {
        let dac = FakeDac {
            ignore_higher_volume: true,
            ..FakeDac::new()
        };
        let error = apply_android_usb_hardware_volume(&dac, &stereo_control(), 1.0, || true)
            .unwrap_err();
        assert!(error.contains("volume verification failed"), "{error}");
        assert_eq!(*dac.volume.borrow(), [-500, -500]);
        let writes = dac.requests.borrow().iter().filter(|r| r.0 == 0x21).count();
        assert_eq!(writes, 4);
    }

    #[test]
    fn verified_volume_write_does_not_require_optional_mute() {
        let dac = FakeDac {
            mute_unavailable: true,
            ..FakeDac::new()
        };
        assert_eq!(
            apply_android_usb_hardware_volume(&dac, &stereo_control(), 0.752, || true),
            Ok((0.75, None))
        );
        assert_eq!(*dac.volume.borrow(), [-250, -250]);
    }

    #[test]
    fn stale_control_generation_sends_no_requests() {
        let dac = FakeDac::new();
        assert_eq!(
            apply_android_usb_hardware_volume(&dac, &stereo_control(), 1.0, || false),
            Err("USB volume route changed before write".into())
        );
        assert!(dac.requests.borrow().is_empty());
    }

    #[test]
    fn route_invalidation_mid_write_restores_the_original_device() {
        let dac = FakeDac::new();
        let error = apply_android_usb_hardware_volume(&dac, &stereo_control(), 1.0, || {
            dac.volume.borrow()[0] == -500
        })
        .unwrap_err();
        assert_eq!(error, "USB volume route changed before write");
        assert_eq!(*dac.volume.borrow(), [-500, -500]);
        assert_eq!(
            dac.requests.borrow().iter().filter(|r| r.0 == 0x21).count(),
            2, // First channel's write and rollback only.
        );
    }

    #[test]
    fn unverifiable_unmute_restores_mute_without_touching_volume() {
        let dac = FakeDac {
            muted: Cell::new(true),
            fail_unmute_readback: true,
            ..FakeDac::new()
        };
        let error = apply_android_usb_hardware_mute(&dac, &stereo_control(), false, || true)
            .unwrap_err();
        assert!(error.contains("GET_CUR"), "{error}");
        assert!(dac.muted.get());
        assert_eq!(*dac.volume.borrow(), [-500, -500]);
        assert!(dac.requests.borrow().iter().all(|request| request.2 == 0x0100));
    }
}

pub fn android_direct_set_hardware_volume(volume: f64, generation: u64) -> Result<(), String> {
    if !volume.is_finite() {
        return Err("USB hardware volume must be finite".to_string());
    }
    let _hold = ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX.lock();
    let state = hardware_volume_state(generation)?;
    set_android_usb_hardware_volume_for_state(&state, volume)
}

/// Caller holds ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX across write/readback.
fn set_android_usb_hardware_volume_for_state(
    state: &AndroidDirectUsbState,
    volume: f64,
) -> Result<(), String> {
    let control = state
        .hardware_volume_control
        .clone()
        .ok_or_else(|| "Android direct USB hardware volume is unavailable".to_string())?;
    let (normalized, muted) = apply_android_usb_hardware_volume(
        &state.device,
        &control,
        volume,
        || android_direct_hardware_volume_generation(true) == Some(state.hardware_volume_generation),
    )
    .inspect_err(|e| {
        dev_eprintln!("[VolFlow] SET_CUR failed: {e}");
        record_hardware_volume_error(state.hardware_volume_generation, e);
    })?;

    publish_hardware_volume_snapshot(state.hardware_volume_generation, normalized, muted)?;
    if let Some(current) = DIRECT_USB_STATE
        .lock()
        .as_mut()
        .filter(|current| volume_generation_is_current(current, state.hardware_volume_generation))
    {
        current.pending_hardware_volume_restore = None;
    }
    dev_eprintln!("[VolFlow] SET_CUR OK: normalized={normalized:.3}");
    Ok(())
}

/// Refresh actual DAC state. A physical volume-button change is not a failure.
/// SET_CUR verification happens immediately after the write, not against an
/// indefinitely stale value in this periodic read.
pub fn android_direct_verify_hardware_volume_health(generation: u64) -> Result<(), String> {
    let _hold = ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX.lock();
    let state = hardware_volume_state(generation)?;
    let control = state
        .hardware_volume_control
        .clone()
        .ok_or_else(|| "Android direct USB hardware volume is unavailable".to_string())?;
    let (normalized, muted) = refresh_android_usb_hardware_volume_snapshot(&state.device, &control)
        .inspect_err(|e| record_hardware_volume_error(generation, e))?;
    publish_hardware_volume_snapshot(generation, normalized, muted)
}

fn apply_android_usb_hardware_mute(
    device: &impl FeatureUnitControl,
    control: &AndroidDirectUsbHardwareVolumeControl,
    muted: bool,
    route_is_current: impl Fn() -> bool,
) -> Result<bool, String> {
    let mute_channel = control
        .mute_channel
        .ok_or_else(|| "Android direct USB hardware mute is unavailable".to_string())?;
    if !route_is_current() {
        return Err("USB mute route changed before write".to_string());
    }
    let read_mute = || {
        read_feature_unit_bool_control(
            device,
            control.interface_number,
            control.feature_unit_id,
            mute_channel,
            control.protocol,
            UAC2_FEATURE_UNIT_MUTE_CONTROL,
        )
    };
    let write_mute = |value| {
        write_feature_unit_bool_control(
            device,
            control.interface_number,
            control.feature_unit_id,
            mute_channel,
            UAC2_FEATURE_UNIT_MUTE_CONTROL,
            value,
        )
    };
    let previous = read_mute()?;
    if !route_is_current() {
        return Err("USB mute route changed before write".into());
    }
    let result = write_mute(muted).and_then(|()| {
        if !route_is_current() {
            return Err("USB mute route changed before readback".into());
        }
        let observed = read_mute()?;
        if !route_is_current() {
            return Err("USB mute route changed during readback".into());
        }
        if observed != muted {
            return Err("USB mute write did not match readback".into());
        }
        Ok(observed)
    });
    let Err(error) = result else {
        return result;
    };
    // An unverified unmute may have reached the DAC. Restore the old mute
    // setting on the same connection without writing the volume channels.
    match write_mute(previous) {
        Ok(()) => Err(error),
        Err(rollback) => Err(format!("{error}; USB mute rollback failed: {rollback}")),
    }
}

pub fn android_direct_set_hardware_mute(muted: bool, generation: u64) -> Result<(), String> {
    let _hold = ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX.lock();
    let state = hardware_volume_state(generation)?;
    let control = state
        .hardware_volume_control
        .as_ref()
        .ok_or_else(|| "Android direct USB hardware mute is unavailable".to_string())?;
    let result = apply_android_usb_hardware_mute(&state.device, control, muted, || {
        android_direct_hardware_volume_generation(true) == Some(generation)
    });
    let mut guard = DIRECT_USB_STATE.lock();
    let current = guard
        .as_mut()
        .filter(|state| volume_generation_is_current(state, generation))
        .ok_or_else(|| "USB mute route changed during control transfer".to_string())?;
    current.hardware_mute_active = result.as_ref().ok().copied();
    result.map(|_| ())
}

fn inspect_android_usb_capabilities(
    device: &AndroidDirectUsbDevice,
) -> Result<Option<AndroidDirectUsbCapabilityModel>, String> {
    let claimed_handle = wrap_android_usb_handle(device)?;
    let inspected_device = claimed_handle.handle.device();
    let config = inspected_device
        .active_config_descriptor()
        .map_err(|error| format!("Failed to read active USB config descriptor: {}", error))?;
    // Capability discovery makes clock/endpoint control requests. Reject a
    // mismatched handoff before any of those can implicitly claim interfaces.
    validate_android_usb_claims(&claimed_handle, &config)?;
    Ok(build_android_usb_capability_model(
        &inspected_device,
        &claimed_handle.handle,
        resolve_device_speed(&inspected_device),
    )
    .ok())
}

fn build_android_usb_capability_model(
    device: &Device<Context>,
    handle: &DeviceHandle<Context>,
    speed: Speed,
) -> Result<AndroidDirectUsbCapabilityModel, String> {
    let config_descriptor = device
        .active_config_descriptor()
        .map_err(|error| format!("Failed to read active USB config descriptor: {}", error))?;

    let mut alt_settings = Vec::new();
    let mut supported_sample_rates = Vec::new();
    let mut supported_bit_depths = Vec::new();
    let mut supported_channels = Vec::new();
    let mut stream_rate_cache =
        std::collections::HashMap::<(u8, Option<u8>), Vec<SamplingFrequencySubrange>>::new();
    let dsd_subslot_override = crate::audio::dsd_engine::output::dsd_subslot_override()
        .or_else(|| resolve_dsd_quirk_for_device(device, handle).map(|q| q.preferred_subslot));

    for interface in config_descriptor.interfaces() {
        for descriptor in interface.descriptors() {
            if descriptor.class_code() != USB_CLASS_AUDIO
                || descriptor.sub_class_code() != USB_SUBCLASS_AUDIOSTREAMING
            {
                continue;
            }

            let Some(mut stream_format) = parse_android_streaming_interface_format(&descriptor) else {
                continue;
            };
            if stream_format.format_tag == FORMAT_TAG_DSD {
                if let Some(ss) = dsd_subslot_override {
                    stream_format.subslot_size = ss;
                }
            }
            let sample_rate_ranges = stream_rate_cache
                .entry((descriptor.interface_number(), stream_format.terminal_link))
                .or_insert_with(|| {
                    discover_stream_sample_rate_ranges(
                        device,
                        handle,
                        descriptor.interface_number(),
                        stream_format.terminal_link,
                        &stream_format.sample_rate_ranges,
                    )
                })
                .clone();
            let sample_rates = representative_sample_rates_from_ranges(&sample_rate_ranges);

            let speed = if speed == Speed::Unknown {
                infer_high_speed_from_sample_rates(&sample_rate_ranges).unwrap_or(speed)
            } else {
                speed
            };
            dev_eprintln!(
                "[USB] build_android_usb_capability_model using speed={:?}",
                speed
            );
            for endpoint in descriptor.endpoint_descriptors() {
                if endpoint.direction() != Direction::Out
                    || endpoint.transfer_type() != TransferType::Isochronous
                {
                    continue;
                }

                let service_interval_us = service_interval_micros(speed, endpoint.interval());
                let max_packet_bytes =
                    effective_iso_packet_bytes(endpoint.max_packet_size(), speed);

                supported_bit_depths.push(stream_format.bit_resolution);
                supported_channels.push(stream_format.channels);
                supported_sample_rates.extend(sample_rates.iter().copied());
                alt_settings.push(AndroidDirectUsbAltCapability {
                    interface_number: descriptor.interface_number(),
                    alt_setting: descriptor.setting_number(),
                    endpoint_address: endpoint.address(),
                    endpoint_interval: endpoint.interval(),
                    service_interval_us,
                    max_packet_bytes,
                    format_tag: format_tag_label(stream_format.format_tag).to_string(),
                    channels: stream_format.channels,
                    subslot_size: stream_format.subslot_size,
                    bit_resolution: stream_format.bit_resolution,
                    sample_rates: sample_rates.clone(),
                    sync_type: sync_type_label(endpoint.sync_type()).to_string(),
                    usage_type: usage_type_label(endpoint.usage_type()).to_string(),
                    refresh: endpoint.refresh(),
                    synch_address: endpoint.synch_address(),
                });
            }
        }
    }

    supported_sample_rates.sort_unstable();
    supported_sample_rates.dedup();
    supported_bit_depths.sort_unstable();
    supported_bit_depths.dedup();
    supported_channels.sort_unstable();
    supported_channels.dedup();
    alt_settings.sort_by_key(|alt| {
        (
            alt.interface_number,
            alt.alt_setting,
            alt.endpoint_address,
            alt.bit_resolution,
            alt.max_packet_bytes,
        )
    });

    Ok(AndroidDirectUsbCapabilityModel {
        supported_sample_rates,
        supported_bit_depths,
        supported_channels,
        alt_settings,
    })
}

fn cleanup_claimed_handle(
    claimed_handle: AndroidDirectUsbClaimedHandle,
    active_interface: Option<u8>,
    keep_locked: bool,
) {
    if let Some(interface_number) = active_interface {
        let _ = claimed_handle.set_alternate_setting(interface_number, 0);
    }

    if keep_locked && current_lock_requested_for_fd(claimed_handle.device_fd) {
        *DIRECT_USB_LOCK.lock() = Some(claimed_handle.into_idle_lock());
    }
}

fn ensure_android_usb_idle_lock() -> Result<(), String> {
    if DIRECT_USB_LOCK.lock().is_some() {
        return Ok(());
    }

    let state = DIRECT_USB_STATE
        .lock()
        .as_ref()
        .cloned()
        .ok_or_else(|| "No Android direct USB DAC is registered".to_string())?;
    let claimed_handle = open_claimed_usb_handle(&state.device).map_err(|error| {
        set_last_error(Some(error.clone()));
        set_direct_mode_refusal_reason(Some(error.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(error.clone()));
        error
    })?;

    dev_eprintln!(
        "Android USB direct idle lock using Android claims for '{}' interfaces {:?}",
        state.device.product_name, claimed_handle.claimed_interfaces
    );

    *DIRECT_USB_LOCK.lock() = Some(claimed_handle.into_idle_lock());
    Ok(())
}

pub fn create_android_usb_backend(
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    preferred_sample_rate: u32,
) -> Result<Option<AndroidDirectUsbBackend>, String> {
    if USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst) {
        dev_eprintln!(
            "Android USB direct backend skipped: clear requested before startup for preferred {} Hz",
            preferred_sample_rate
        );
        return Ok(None);
    }

    // Wait for any previous USB session to finish cleanup (up to 1.5s).
    // This prevents "Resource busy" when the engine is recreated for a
    // new track before the old backend's threads have fully stopped.
    for attempt in 0..15 {
        if !USB_SESSION_ACTIVE.load(Ordering::SeqCst) {
            break;
        }
        if attempt == 0 {
            dev_eprintln!("Android USB direct: previous session still active, waiting for cleanup...");
        }
        thread::sleep(Duration::from_millis(100));
    }

    let session = {
        let _session_gate = USB_SESSION_GATE.lock();
        if USB_SESSION_CLEAR_PENDING.load(Ordering::SeqCst) {
            return Ok(None);
        }
        if is_usb_session_active() {
            return Err("Previous Android direct USB session is still stopping".to_string());
        }
        Arc::new(AndroidUsbSessionGuard::start_locked())
    };
    create_android_usb_backend_inner(callback_data, event_tx, preferred_sample_rate, &session)
}

fn create_android_usb_backend_inner(
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    mut preferred_sample_rate: u32,
    session: &Arc<AndroidUsbSessionGuard>,
) -> Result<Option<AndroidDirectUsbBackend>, String> {
    // Some buggy DACs report 0 Hz via GET_CUR, and Dart passes this as
    // preferred_sample_rate = 0. Use the requested playback format's rate
    // instead of 0, which would cause a 0 == 0 format match and select a
    // zero-Hz stream configuration.
    if preferred_sample_rate == 0 {
        if let Some(guard) = DIRECT_USB_STATE.lock().as_ref() {
            if let Some(req_fmt) = guard.requested_playback_format {
                preferred_sample_rate = req_fmt.sample_rate;
            } else if let Some(eff_fmt) = guard.playback_format {
                preferred_sample_rate = eff_fmt.sample_rate;
            }
        }
        if preferred_sample_rate == 0 {
            preferred_sample_rate = 44_100;
        }
        dev_eprintln!(
            "[USB] preferred_sample_rate was 0, using {} Hz instead",
            preferred_sample_rate
        );
    }
    let (state, mut playback_format, use_requested_playback_format) = {
        let guard = DIRECT_USB_STATE.lock();
        let Some(state) = guard.as_ref() else {
            dev_eprintln!(
                "Android USB direct backend skipped: no registered DAC state for preferred {} Hz",
                preferred_sample_rate
            );
            set_android_usb_engine_state(
                AndroidDirectUsbEngineState::Error,
                Some("No registered Android USB DAC state was available".to_string()),
            );
            return Ok(None);
        };
        let Some(effective_playback_format) = state.playback_format else {
            dev_eprintln!(
                "Android USB direct backend skipped: no effective playback format is configured for '{}' (preferred {} Hz, requested {:?})",
                state.device.product_name,
                preferred_sample_rate,
                state.requested_playback_format.map(|format| format.sample_rate),
            );
            set_android_usb_engine_state(
                AndroidDirectUsbEngineState::Error,
                Some("No effective Android USB playback format was configured".to_string()),
            );
            return Ok(None);
        };
        let requested_playback_format = state
            .requested_playback_format
            .unwrap_or(effective_playback_format);
        let (playback_format, use_requested_playback_format) = if effective_playback_format
            .sample_rate
            == preferred_sample_rate
        {
            (effective_playback_format, false)
        } else if requested_playback_format.sample_rate == preferred_sample_rate {
            dev_eprintln!(
                    "Android USB direct backend: preferred {} Hz matched requested playback format for '{}' while effective playback format was {} Hz; using requested format",
                    preferred_sample_rate,
                    state.device.product_name,
                    effective_playback_format.sample_rate,
                );
            (requested_playback_format, true)
        } else if effective_playback_format.sample_rate == 0
            && requested_playback_format.sample_rate > 0
        {
            // The effective format has 0 Hz (broken DAC readback), but the
            // requested format has a valid rate. Use the requested format.
            dev_eprintln!(
                    "Android USB direct backend: effective format had 0 Hz (broken DAC readback), using requested format at {} Hz for '{}'",
                    requested_playback_format.sample_rate,
                    state.device.product_name,
                );
            (requested_playback_format, true)
        } else if effective_playback_format.sample_rate > 0
            && requested_playback_format.sample_rate == 0
        {
            // The requested format has 0 Hz, but the effective format is valid.
            dev_eprintln!(
                    "Android USB direct backend: requested format had 0 Hz, using effective format at {} Hz for '{}'",
                    effective_playback_format.sample_rate,
                    state.device.product_name,
                );
            (effective_playback_format, false)
        } else {
            dev_eprintln!(
                    "Android USB direct backend skipped: preferred {} Hz did not match effective {} Hz or requested {} Hz for '{}'",
                    preferred_sample_rate,
                    effective_playback_format.sample_rate,
                    requested_playback_format.sample_rate,
                    state.device.product_name,
                );
            set_android_usb_engine_state(
                AndroidDirectUsbEngineState::Error,
                Some(format!(
                    "Prepared playback rate did not match requested startup rate {} Hz",
                    preferred_sample_rate
                )),
            );
            return Ok(None);
        };
        debug_assert_eq!(playback_format.sample_rate, preferred_sample_rate);
        (
            state.clone(),
            playback_format,
            use_requested_playback_format,
        )
    };
    if use_requested_playback_format {
        set_effective_playback_format(playback_format);
    }
    set_android_usb_engine_state(AndroidDirectUsbEngineState::UsbInit, None);
    let clock_settle_delay_ms = resolve_dac_settle_delay_ms(&state.device);

    let claimed_handle = open_claimed_usb_handle(&state.device).map_err(|error| {
        set_last_error(Some(error.clone()));
        set_direct_mode_refusal_reason(Some(error.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(error.clone()));
        error
    })?;
    let mut requested_playback_format = state.requested_playback_format.unwrap_or(playback_format);
    let device = claimed_handle.handle.device();
    let speed = resolve_device_speed(&device);
    let lock_requested = current_lock_requested_for_fd(state.device.fd);
    set_capability_model(
        build_android_usb_capability_model(&device, &claimed_handle.handle, speed).ok(),
    );
    let candidate =
        match select_stream_candidate(&device, &claimed_handle.handle, playback_format, speed) {
            Ok(candidate) => candidate,
            Err(error) => {
                set_last_error(Some(error.clone()));
                set_direct_mode_refusal_reason(Some(error.clone()));
                set_android_usb_engine_state(
                    AndroidDirectUsbEngineState::Error,
                    Some(error.clone()),
                );
                cleanup_claimed_handle(claimed_handle, None, lock_requested);
                return Err(error);
            }
        };
    if playback_format.dsd_transport == DsdTransportMode::Native {
        // Native DSD clock frames contain subslot_size bytes per channel.
        // The producer still supplies interleaved byte-rate samples.
        if !matches!(candidate.subslot_size, 1 | 2 | 4)
            || playback_format.dsd_bit_rate == 0 {
            let error = "USB native DSD refused: invalid subslot or source bit rate".to_string();
            set_last_error(Some(error.clone()));
            set_direct_mode_refusal_reason(Some(error.clone()));
            cleanup_claimed_handle(claimed_handle, None, lock_requested);
            return Err(error);
        }
        let wire_rate = playback_format.dsd_bit_rate / (8 * u32::from(candidate.subslot_size));
        playback_format.sample_rate = wire_rate;
        requested_playback_format.sample_rate = wire_rate;
        if let Some(current) = DIRECT_USB_STATE.lock().as_mut() {
            current.playback_format = Some(playback_format);
            current.requested_playback_format = Some(requested_playback_format);
        }
    }
    let clock = find_audio_control_clock(&device, &claimed_handle.handle, candidate.terminal_link);
    let clock_detection_msg = match &clock {
        Some(c) => format!(
            "Clock found: interface={}, clockId={}, via_terminal_link={:?}",
            c.interface_number, c.clock_id, candidate.terminal_link,
        ),
        None => "Clock NOT FOUND: no UAC2 clock entity in any AudioControl descriptor".to_string(),
    };
    dev_eprintln!(
        "[USB] Clock entity for '{}': {}",
        state.device.product_name, clock_detection_msg
    );

    set_last_error(Some(format!("[clock-diag] {}", clock_detection_msg)));
    set_direct_mode_refusal_reason(None);
    set_usb_stream_stable(false);
    set_active_transport(Some(&candidate));
    let volume_hold = ANDROID_DIRECT_HARDWARE_VOLUME_MUTEX.lock();
    let hardware_volume_control = discover_android_usb_hardware_volume_control(
        &device,
        &state.device,
        &candidate,
        clock.map(|clock| clock.interface_number),
    );
    let hardware_volume_control = match hardware_volume_control {
        Ok(control) => {
            set_hardware_volume_error(if control.is_none() {
                Some("no writable volume on the active USB playback topology".to_string())
            } else { None });
            control
        }
        Err(error) => {
            log_error!("[USB] Hardware volume discovery failed: {}", error);
            set_hardware_volume_error(Some(error));
            None
        }
    };
    set_hardware_volume_control(hardware_volume_control.clone());
    if let Some(control) = hardware_volume_control.as_ref() {
        log_info!(
            "[USB] Hardware volume control found: feature_unit={}, interface={}, min={}, max={}, res={}, protocol={:?}, channels={:?}, mute_channel={:?}",
            control.feature_unit_id,
            control.interface_number,
            control.min_volume_raw,
            control.max_volume_raw,
            control.resolution_raw,
            control.protocol,
            control.volume_channels,
            control.mute_channel
        );
        let (pending_restore, generation) = DIRECT_USB_STATE
            .lock()
            .as_mut()
            .map(|state| (
                state.pending_hardware_volume_restore.take(),
                state.hardware_volume_generation,
            ))
            .unwrap_or_default();
        let restore_requested = pending_restore.is_some();
        let snapshot = if let Some(target) = pending_restore {
            match apply_android_usb_hardware_volume(
                &state.device,
                control,
                target,
                || android_direct_hardware_volume_generation(true) == Some(generation),
            )
            .and_then(|snapshot| {
                publish_hardware_volume_snapshot(generation, snapshot.0, snapshot.1)?;
                Ok(snapshot)
            }) {
                Ok(snapshot) => {
                    log_info!(
                        "[USB] Restored hardware volume before stream start: requested={target}, actual={}",
                        snapshot.0
                    );
                    Ok(snapshot)
                }
                Err(error) => {
                    // Keep the request for another playback attempt instead of
                    // starting the stream at an unknown (possibly full) level.
                    if let Some(state) = DIRECT_USB_STATE.lock().as_mut()
                        .filter(|state| state.hardware_volume_generation == generation)
                    {
                        state.pending_hardware_volume_restore = Some(target);
                    }
                    Err(error)
                }
            }
        } else {
            refresh_android_usb_hardware_volume_snapshot(&state.device, control)
        };
        match snapshot {
            Ok((volume, muted)) => {
                if !restore_requested {
                    log_info!(
                        "[USB] Hardware volume initial: volume={}, muted={:?}",
                        volume,
                        muted
                    );
                    set_hardware_volume_snapshot(Some(volume), muted);
                }
            }
            Err(error) => {
                log_error!(
                    "[USB] Failed to query hardware volume snapshot for feature unit {} on interface {}: {}",
                    control.feature_unit_id,
                    control.interface_number,
                    error
                );
                set_hardware_volume_control(None);
                set_hardware_volume_error(Some(error.clone()));
                if restore_requested {
                    let error = format!(
                        "Failed to restore USB DAC hardware volume before playback: {error}"
                    );
                    set_last_error(Some(error.clone()));
                    set_direct_mode_refusal_reason(Some(error.clone()));
                    set_android_usb_engine_state(
                        AndroidDirectUsbEngineState::Error,
                        Some(error.clone()),
                    );
                    cleanup_claimed_handle(claimed_handle, None, lock_requested);
                    return Err(error);
                }
            }
        }
    } else {
        log_info!("[USB] No hardware volume control discovered");
        if let Some(state) = DIRECT_USB_STATE.lock().as_mut() {
            state.pending_hardware_volume_restore.take();
        }
    }
    drop(volume_hold);
    set_clock_status(clock.map(|clock| {
        AndroidDirectUsbClockStatus {
            interface_number: clock.interface_number,
            clock_id: clock.clock_id,
            requested_sample_rate: playback_format.sample_rate,
            reported_sample_rate: state
                .clock_status
                .as_ref()
                .and_then(|status| status.reported_sample_rate),
        }
    }));
    set_clock_verification(
        state.clock_control_attempted,
        state.clock_control_succeeded,
        state.clock_verification_passed,
        state
            .clock_status
            .as_ref()
            .and_then(|status| status.reported_sample_rate),
    );

    dev_eprintln!(
        "[USB] Candidate device='{}' mode={:?} requested={}Hz effective={}Hz resampling={} endpoint=0x{:02x} interface={} alt={} clock={} feedbackEndpoint={} sync={:?} usage={:?} service={}us maxPacket={} speed={:?} fmt={} channels={} subslot={} bitResolution={} sampleRates={:?}",
        state.device.product_name,
        state.dac_mode,
        requested_playback_format.sample_rate,
        playback_format.sample_rate,
        requested_playback_format.sample_rate != playback_format.sample_rate,
        candidate.endpoint_address,
        candidate.interface_number,
        candidate.alt_setting,
        clock.map(|clock| clock.clock_id).unwrap_or_default(),
        candidate
            .feedback_endpoint
            .map(|feedback| format!(
                "0x{:02x}/{}",
                feedback.address,
                transfer_type_label(feedback.transfer_type)
            ))
            .unwrap_or_else(|| "none".to_string()),
        candidate.sync_type,
        candidate.usage_type,
        candidate.service_interval_us,
        candidate.max_packet_bytes,
        speed,
        format_tag_label(candidate.format_tag),
        candidate.channels,
        candidate.subslot_size,
        candidate.bit_resolution,
        candidate.sample_rates,
    );

    dev_eprintln!(
        "[USB] Interface={} alt={} endpoint=0x{:02x} syncAddress=0x{:02x} interval={} serviceIntervalUs={} refresh={}",
        candidate.interface_number,
        candidate.alt_setting,
        candidate.endpoint_address,
        candidate.synch_address,
        candidate.endpoint_interval,
        candidate.service_interval_us,
        candidate.refresh,
    );

    if let Err(error) = claimed_handle.ensure_interface_claimed(candidate.interface_number) {
        set_last_error(Some(error.clone()));
        set_direct_mode_refusal_reason(Some(error.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(error.clone()));
        cleanup_claimed_handle(claimed_handle, None, lock_requested);
        return Err(error);
    }

    if let Err(error) = claimed_handle.set_alternate_setting(candidate.interface_number, 0) {
        let message = format!(
            "Failed to reset USB interface {} to alt 0: {}",
            candidate.interface_number, error
        );
        set_last_error(Some(message.clone()));
        set_direct_mode_refusal_reason(Some(message.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(message.clone()));
        cleanup_claimed_handle(claimed_handle, None, lock_requested);
        return Err(message);
    }
    thread::sleep(Duration::from_millis(50));

    let mut clock_control_attempted = state.clock_control_attempted;
    let mut clock_control_succeeded = state.clock_control_succeeded;
    let mut clock_verification_passed = state.clock_verification_passed;
    let mut reported_sample_rate = state
        .clock_status
        .as_ref()
        .and_then(|status| status.reported_sample_rate);

    if let Some(clock) = clock {
        if let Err(error) = claimed_handle.ensure_interface_claimed(clock.interface_number) {
            set_last_error(Some(error.clone()));
            set_direct_mode_refusal_reason(Some(error.clone()));
            set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(error.clone()));
            cleanup_claimed_handle(claimed_handle, Some(candidate.interface_number), lock_requested);
            return Err(error);
        }
        match state.dac_mode {
            DacMode::FullControl => {
                // ALWAYS send SET_CUR + verify, even if a previous negotiation
                // already programmed the clock. The alt-setting reset to 0 above
                // can cause some DACs to revert to a default rate (384kHz etc.),
                // and cached state from a prior session cannot be trusted.
                let clock_outcome = apply_sampling_frequency(
                    &claimed_handle.handle,
                    clock.interface_number,
                    clock.clock_id,
                    playback_format.sample_rate,
                    clock_settle_delay_ms,
                );
                clock_control_attempted = true;
                clock_control_succeeded = clock_outcome.clock_ok;
                reported_sample_rate = clock_outcome.reported_sample_rate;
                clock_verification_passed = clock_outcome.rate_verified
                    && clock_outcome.reported_sample_rate == Some(playback_format.sample_rate);
                set_clock_verification(
                    clock_control_attempted,
                    clock_control_succeeded,
                    clock_verification_passed,
                    reported_sample_rate,
                );

                let clock_result_msg = format!(
                    "[clock-diag] SET_CUR {}Hz: clockOk={}, rateVerified={}, reported={}Hz, clockId={}, iface={}{}",
                    playback_format.sample_rate,
                    clock_outcome.clock_ok,
                    clock_outcome.rate_verified,
                    clock_outcome.reported_sample_rate.unwrap_or(0),
                    clock.clock_id,
                    clock.interface_number,
                    clock_outcome.message.as_ref().map(|m| format!(", msg={}", m)).unwrap_or_default(),
                );
                dev_eprintln!("{}", clock_result_msg);
                set_last_error(Some(clock_result_msg));

                if !clock_outcome.clock_ok {
                    dev_eprintln!(
                        "[USB] SET_CUR {}Hz -> FAILED: DAC reported={}Hz, verified={}",
                        playback_format.sample_rate,
                        clock_outcome.reported_sample_rate.unwrap_or(0),
                        clock_verification_passed,
                    );
                }

                if clock_outcome.known_mismatch {
                    dev_eprintln!(
                        "[USB] SET_CUR {}Hz -> MISMATCH: DAC reports {}Hz",
                        playback_format.sample_rate,
                        clock_outcome.reported_sample_rate.unwrap_or_default(),
                    );
                }

                dev_eprintln!(
                    "[USB] VALIDATION: usbClaimed={}, alt={}, endpoint=0x{:02x}, requestedRate={}Hz, dacRate={}Hz, verified={}",
                    claimed_handle.claimed_interfaces.contains(&candidate.interface_number),
                    candidate.alt_setting,
                    candidate.endpoint_address,
                    playback_format.sample_rate,
                    reported_sample_rate.unwrap_or(0),
                    clock_verification_passed,
                );

                if clock_outcome.set_cur_succeeded
                    && !clock_verification_passed
                    && !clock_outcome.known_mismatch
                {
                    clock_verification_passed = true;
                    reported_sample_rate = Some(playback_format.sample_rate);
                    set_clock_verification(
                        clock_control_attempted,
                        true,
                        true,
                        reported_sample_rate,
                    );
                    dev_eprintln!(
                        "[USB] SET_CUR accepted {}Hz on clock {} but readback unavailable (write-only clock); trusting SET_CUR",
                        playback_format.sample_rate, clock.clock_id,
                    );
                }
            }
            DacMode::FixedClock | DacMode::AdaptiveStreaming => {
                reported_sample_rate = get_sampling_frequency(
                    &claimed_handle.handle,
                    clock.interface_number,
                    clock.clock_id,
                )
                .ok()
                .or(reported_sample_rate);

                if let Some(actual_rate) = reported_sample_rate {
                    if actual_rate != playback_format.sample_rate {
                        let message = format!(
                            "Android USB direct: DAC reports {} Hz while stream is configured for {} Hz; continuing direct USB with unverified clock",
                            actual_rate, playback_format.sample_rate
                        );
                        set_clock_verification(
                            clock_control_attempted,
                            clock_control_succeeded,
                            false,
                            Some(actual_rate),
                        );
                        dev_eprintln!("{}", message);
                        dev_eprintln!(
                            "[USB] Actual sample rate={}Hz verified=false (reported by DAC, requested {}Hz)",
                            actual_rate,
                            playback_format.sample_rate,
                        );
                        clock_verification_passed = false;
                    } else {
                        clock_verification_passed = true;
                    }
                } else if let Ok(ranges) = get_sampling_frequency_ranges(
                    &claimed_handle.handle,
                    clock.interface_number,
                    clock.clock_id,
                ) {
                    if sampling_frequency_ranges_support_rate(&ranges, playback_format.sample_rate)
                    {
                        reported_sample_rate = Some(playback_format.sample_rate);
                        clock_verification_passed = true;
                        dev_eprintln!(
                            "Android USB direct: using GET_RANGE-verified fixed clock {} Hz on alt setting {} without SET_CUR",
                            playback_format.sample_rate, candidate.alt_setting
                        );
                    } else {
                        dev_eprintln!(
                            "[USB] Cannot verify fixed clock {}Hz for alt {} from GET_RANGE — will refuse streaming",
                            playback_format.sample_rate, candidate.alt_setting,
                        );
                        reported_sample_rate = None;
                        clock_verification_passed = false;
                        set_clock_verification(
                            clock_control_attempted,
                            clock_control_succeeded,
                            false,
                            None,
                        );
                    }
                } else {
                    dev_eprintln!(
                        "[USB] Cannot verify fixed clock {}Hz for alt {} because GET_RANGE is unavailable — will refuse streaming",
                        playback_format.sample_rate, candidate.alt_setting,
                    );
                    reported_sample_rate = None;
                    clock_verification_passed = false;
                    set_clock_verification(
                        clock_control_attempted,
                        clock_control_succeeded,
                        false,
                        None,
                    );
                }

                set_clock_verification(
                    clock_control_attempted,
                    clock_control_succeeded,
                    clock_verification_passed,
                    reported_sample_rate,
                );
            }
        }
    } else if candidate.is_uac1 {
        // UAC1 has no UAC2 clock entity; the sample rate is set endpoint-level
        // via SET_CUR (UAC1_SAM_FREQ_CONTROL 0x0100) on the streaming endpoint.
        // Re-issue it here because the alt-setting reset to 0 above may have
        // cleared device state, then trust the endpoint-level set. UAC1
        // endpoints are set-only (no GET_CUR readback for sample rate), so
        // clock "verification" is structurally impossible — a successful
        // SET_CUR is the strongest evidence available and is what the UAC1
        // spec defines as the rate-setting mechanism.
        match set_uac1_sampling_frequency(
            &claimed_handle.handle,
            candidate.interface_number,
            candidate.endpoint_address,
            playback_format.sample_rate,
        ) {
            Ok(()) => {
                clock_control_attempted = true;
                clock_control_succeeded = true;
                clock_verification_passed = true;
                reported_sample_rate = Some(playback_format.sample_rate);
                set_dac_mode(DacMode::FixedClock);
                set_clock_verification(
                    clock_control_attempted,
                    clock_control_succeeded,
                    clock_verification_passed,
                    reported_sample_rate,
                );
                let message = format!(
                    "[clock-diag] UAC1: SET_CUR {}Hz on endpoint 0x{:02x} succeeded — trusting endpoint-level rate (no UAC2 clock entity)",
                    playback_format.sample_rate, candidate.endpoint_address
                );
                dev_eprintln!("{}", message);
                set_last_error(Some(message));
            }
            Err(e) => {
                clock_control_attempted = true;
                clock_control_succeeded = false;
                // Only adaptive/synchronous UAC1 endpoints are host-paced, so a
                // rejected SET_CUR is tolerable there. Asynchronous endpoints run
                // their own clock and NoSync endpoints free-run entirely (FiiO
                // BR13: NoSync, stays locked at 48/96 kHz while we stream at the
                // file rate -> chipmunk), so a failed rate set leaves the DAC rate
                // unknown: refuse.
                if uac1_set_cur_failure_tolerable(candidate.sync_type) {
                    clock_verification_passed = true;
                    reported_sample_rate = Some(playback_format.sample_rate);
                    set_dac_mode(DacMode::AdaptiveStreaming);
                    set_clock_verification(
                        true,
                        false,
                        true,
                        Some(playback_format.sample_rate),
                    );
                    let message = format!(
                        "[clock-diag] UAC1 SET_CUR {}Hz on endpoint 0x{:02x} failed: {} — tolerable for {:?} endpoint, trusting host-driven rate",
                        playback_format.sample_rate, candidate.endpoint_address, e, candidate.sync_type,
                    );
                    dev_eprintln!("{}", message);
                    set_last_error(Some(message));
                } else {
                    clock_verification_passed = false;
                    reported_sample_rate = None;
                    set_clock_verification(true, false, false, None);
                    let message = format!(
                        "[clock-diag] UAC1 SET_CUR {}Hz on endpoint 0x{:02x} failed: {} — will refuse ({:?} endpoint is not host-paced)",
                        playback_format.sample_rate, candidate.endpoint_address, e, candidate.sync_type,
                    );
                    dev_eprintln!("{}", message);
                    set_last_error(Some(message));
                }
            }
        }
    } else {
        let message = format!(
            "[clock-diag] Cannot verify {}Hz: no clock entity for alt {} — will refuse",
            playback_format.sample_rate, candidate.alt_setting
        );
        reported_sample_rate = None;
        clock_verification_passed = false;
        set_clock_verification(
            clock_control_attempted,
            clock_control_succeeded,
            false,
            None,
        );
        dev_eprintln!("{}", message);
        set_last_error(Some(message));
    }

    if let Err(error) =
        claimed_handle.set_alternate_setting(candidate.interface_number, candidate.alt_setting)
    {
        let msg = format!(
            "Failed to set USB alt setting {} on interface {}: {}",
            candidate.alt_setting, candidate.interface_number, error
        );
        set_last_error(Some(msg.clone()));
        set_direct_mode_refusal_reason(Some(msg.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(msg.clone()));
        cleanup_claimed_handle(claimed_handle, None, lock_requested);
        return Err(msg);
    }
    thread::sleep(Duration::from_millis(50));

    // UAC1: endpoint SET_CUR is only reliable once the streaming alt setting
    // is active. Re-issue it; success here upgrades the clock verdict even if
    // the pre-alt attempt was rejected.
    if candidate.is_uac1 {
        match set_uac1_sampling_frequency(
            &claimed_handle.handle,
            candidate.interface_number,
            candidate.endpoint_address,
            playback_format.sample_rate,
        ) {
            Ok(()) => {
                clock_control_attempted = true;
                clock_control_succeeded = true;
                clock_verification_passed = true;
                reported_sample_rate = Some(playback_format.sample_rate);
                set_dac_mode(DacMode::FixedClock);
                set_clock_verification(true, true, true, reported_sample_rate);
                let message = format!(
                    "[clock-diag] UAC1: post-alt SET_CUR {}Hz on endpoint 0x{:02x} succeeded — DAC locked to requested rate",
                    playback_format.sample_rate, candidate.endpoint_address
                );
                dev_eprintln!("{}", message);
                set_last_error(Some(message));
            }
            Err(e) => {
                // SET_CUR stalled even with the alt setting active. Probe
                // GET_CUR: some UAC1 firmware auto-locks the rate and only
                // reports it read-only, in which case a matching readback is
                // sufficient verification.
                match get_uac1_sampling_frequency(
                    &claimed_handle.handle,
                    candidate.interface_number,
                    candidate.endpoint_address,
                ) {
                    Ok(reported) if reported == playback_format.sample_rate => {
                        clock_control_attempted = true;
                        clock_control_succeeded = false;
                        clock_verification_passed = true;
                        reported_sample_rate = Some(reported);
                        set_dac_mode(DacMode::FixedClock);
                        set_clock_verification(true, false, true, reported_sample_rate);
                        let message = format!(
                            "[clock-diag] UAC1: post-alt SET_CUR failed but GET_CUR reports requested {}Hz — trusting readback",
                            reported
                        );
                        dev_eprintln!("{}", message);
                        set_last_error(Some(message));
                    }
                    Ok(reported) => {
                        let message = format!(
                            "[clock-diag] UAC1: post-alt SET_CUR failed ({}) and GET_CUR reports {}Hz, requested {}Hz — keeping prior verdict",
                            e, reported, playback_format.sample_rate
                        );
                        dev_eprintln!("{}", message);
                        set_last_error(Some(message));
                    }
                    Err(readback_error) => {
                        let message = format!(
                            "[clock-diag] UAC1: post-alt SET_CUR failed: {} — keeping prior verdict (GET_CUR probe: {})",
                            e, readback_error
                        );
                        dev_eprintln!("{}", message);
                        set_last_error(Some(message));
                    }
                }
            }
        }
    }

    if !claimed_handle
        .claimed_interfaces
        .contains(&candidate.interface_number)
    {
        let refusal = format!(
            "Android USB direct refused: interface {} not claimed (endpoint=0x{:02x}, alt={})",
            candidate.interface_number, candidate.endpoint_address, candidate.alt_setting
        );
        set_last_error(Some(refusal.clone()));
        set_direct_mode_refusal_reason(Some(refusal.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(refusal.clone()));
        cleanup_claimed_handle(
            claimed_handle,
            Some(candidate.interface_number),
            lock_requested,
        );
        return Err(refusal);
    }

    if candidate.alt_setting == 0 {
        let refusal = format!(
            "Android USB direct refused: invalid alt setting 0 on interface {} (endpoint=0x{:02x})",
            candidate.interface_number, candidate.endpoint_address
        );
        set_last_error(Some(refusal.clone()));
        set_direct_mode_refusal_reason(Some(refusal.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(refusal.clone()));
        cleanup_claimed_handle(
            claimed_handle,
            Some(candidate.interface_number),
            lock_requested,
        );
        return Err(refusal);
    }

    if candidate.endpoint_address == 0 {
        let refusal =
            "Android USB direct refused: no valid isochronous OUT endpoint found".to_string();
        set_last_error(Some(refusal.clone()));
        set_direct_mode_refusal_reason(Some(refusal.clone()));
        cleanup_claimed_handle(
            claimed_handle,
            Some(candidate.interface_number),
            lock_requested,
        );
        return Err(refusal);
    }

    // Post-alt-setting clock re-verification.
    // Some DACs reset their clock when the alt setting changes. Re-read
    // GET_CUR after switching to the streaming alt setting and if the
    // rate is wrong, try one more SET_CUR + verify cycle.
    // Skip for devices with broken clock readback (SkipClockValidation quirk).
    if let Some(clock) = clock {
        let skip_clock_validation = crate::uac2::quirk::QUIRK_DATABASE.has_quirk(
            state.device.vendor_id,
            state.device.product_id,
            &state.device.product_name,
            crate::uac2::quirk::UsbAudioQuirk::SkipClockValidation,
        );
        if skip_clock_validation && playback_format.dsd_transport == DsdTransportMode::None {
            dev_eprintln!(
                "[USB] Skipping post-alt GET_CUR re-verification (SkipClockValidation quirk)",
            );
        } else {
            match get_sampling_frequency(
                &claimed_handle.handle,
                clock.interface_number,
                clock.clock_id,
            ) {
                Ok(post_alt_rate) => {
                    dev_eprintln!(
                        "[USB] GET_CUR (post-alt): clock {} reports {}Hz (expected {}Hz)",
                        clock.clock_id, post_alt_rate, playback_format.sample_rate,
                    );
                    if post_alt_rate != playback_format.sample_rate {
                        dev_eprintln!(
                            "[USB] DAC clock drifted after alt-setting change ({} -> {}Hz); re-issuing SET_CUR",
                            playback_format.sample_rate, post_alt_rate,
                        );
                        let retry = apply_sampling_frequency(
                            &claimed_handle.handle,
                            clock.interface_number,
                            clock.clock_id,
                            playback_format.sample_rate,
                            clock_settle_delay_ms,
                        );
                        clock_control_attempted = true;
                        clock_control_succeeded = retry.clock_ok;
                        reported_sample_rate = retry.reported_sample_rate;
                        clock_verification_passed = retry.rate_verified
                            && retry.reported_sample_rate == Some(playback_format.sample_rate);
                        set_clock_verification(
                            clock_control_attempted,
                            clock_control_succeeded,
                            clock_verification_passed,
                            reported_sample_rate,
                        );
                        dev_eprintln!(
                            "[USB] Re-SET_CUR result: clockOk={}, verified={}, reported={}Hz",
                            retry.clock_ok,
                            clock_verification_passed,
                            retry.reported_sample_rate.unwrap_or(0),
                        );

                        if retry.set_cur_succeeded
                            && playback_format.dsd_transport == DsdTransportMode::None
                            && !clock_verification_passed
                            && !retry.known_mismatch
                        {
                            clock_verification_passed = true;
                            reported_sample_rate = Some(playback_format.sample_rate);
                            set_clock_verification(
                                clock_control_attempted,
                                true,
                                true,
                                reported_sample_rate,
                            );
                            dev_eprintln!(
                                "[USB] Re-SET_CUR accepted {}Hz on clock {} but readback unavailable (write-only clock); trusting SET_CUR",
                                playback_format.sample_rate, clock.clock_id,
                            );
                        }
                    } else if playback_format.dsd_transport != DsdTransportMode::None {
                        reported_sample_rate = Some(post_alt_rate);
                        clock_verification_passed = true;
                        set_clock_verification(clock_control_attempted, clock_control_succeeded, true, reported_sample_rate);
                    }
                }
                Err(error) => {
                    dev_eprintln!(
                        "[USB] GET_CUR (post-alt): failed for clock {}: {}",
                        clock.clock_id, error,
                    );
                    if playback_format.dsd_transport != DsdTransportMode::None {
                        reported_sample_rate = None;
                        clock_verification_passed = false;
                        set_clock_verification(clock_control_attempted, clock_control_succeeded, false, None);
                    }
                }
            }
        } // end of else (not skip_clock_validation)
    } else if candidate.is_uac1 && playback_format.dsd_transport != DsdTransportMode::None {
        reported_sample_rate = get_uac1_sampling_frequency(
            &claimed_handle.handle, candidate.interface_number, candidate.endpoint_address,
        ).ok();
        clock_verification_passed = reported_sample_rate == Some(playback_format.sample_rate);
        set_clock_verification(clock_control_attempted, clock_control_succeeded, clock_verification_passed, reported_sample_rate);
    }

    dev_eprintln!(
        "Android USB direct output opened '{}' requested {} Hz / {}-bit / {} ch, transport {} / {} ch / {}-byte subslot on endpoint 0x{:02x} (interface {}, alt {}, speed {:?})",
        state.device.product_name,
        playback_format.sample_rate,
        playback_format.bit_depth,
        playback_format.channels,
        format_tag_label(candidate.format_tag),
        candidate.channels,
        candidate.subslot_size,
        candidate.endpoint_address,
        candidate.interface_number,
        candidate.alt_setting,
        speed,
    );

    // Hard-abort: if the clock is unverified or mismatched, refuse to
    // stream. Sending audio at the wrong sample rate causes chipmunk /
    // distorted playback.  There is NO "continue anyway" path.
    if !clock_verification_passed {
        // Check if this device has the SkipClockValidation quirk.
        // Some DACs (e.g. Fosi DS2 / Savitech bridge) have broken UAC2 clock
        // control — GET_RANGE and GET_CUR always return 0. SET_CUR is accepted
        // silently. Skip verification and trust the SET_CUR.
        let skip_clock_validation = crate::uac2::quirk::QUIRK_DATABASE.has_quirk(
            state.device.vendor_id,
            state.device.product_id,
            &state.device.product_name,
            crate::uac2::quirk::UsbAudioQuirk::SkipClockValidation,
        );

        if skip_clock_validation && playback_format.dsd_transport == DsdTransportMode::None {
            dev_eprintln!(
                "[USB] Clock verification failed but SkipClockValidation quirk is active — trusting SET_CUR for {}Hz",
                playback_format.sample_rate,
            );
            clock_verification_passed = true;
            reported_sample_rate = Some(playback_format.sample_rate);
            set_clock_verification(
                clock_control_attempted,
                clock_control_succeeded,
                true,
                reported_sample_rate,
            );
        } else {
            set_clock_verification(
                clock_control_attempted,
                clock_control_succeeded,
                false,
                reported_sample_rate,
            );

            let refusal = format!(
                "USB direct refused: DAC clock not verified at {}Hz (reported={}Hz, attempted={}, succeeded={})",
                playback_format.sample_rate,
                reported_sample_rate.unwrap_or(0),
                clock_control_attempted,
                clock_control_succeeded,
            );
            dev_eprintln!("[USB] {}", refusal);
            set_last_error(Some(refusal.clone()));
            set_direct_mode_refusal_reason(Some(refusal.clone()));
            set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(refusal.clone()));
            cleanup_claimed_handle(
                claimed_handle,
                Some(candidate.interface_number),
                lock_requested,
            );
            return Err(refusal);
        }
    }

    if let Some(rate) = reported_sample_rate {
        if rate != playback_format.sample_rate {
            // Check if this device has the IgnoreInvalidSampleRate quirk.
            // Some DACs (e.g. Fosi DS2) always report 0Hz via GET_CUR even
            // when operating correctly at the requested rate.
            let ignore_invalid_rate = crate::uac2::quirk::QUIRK_DATABASE.has_quirk(
                state.device.vendor_id,
                state.device.product_id,
                &state.device.product_name,
                crate::uac2::quirk::UsbAudioQuirk::IgnoreInvalidSampleRate,
            );

            if ignore_invalid_rate && playback_format.dsd_transport == DsdTransportMode::None {
                dev_eprintln!(
                    "[USB] DAC reported {}Hz (expected {}Hz) but IgnoreInvalidSampleRate quirk is active — continuing",
                    rate, playback_format.sample_rate,
                );
                reported_sample_rate = Some(playback_format.sample_rate);
            } else {
                let refusal = format!(
                    "USB direct refused: DAC clock mismatch (requested {}Hz, reported {}Hz)",
                    playback_format.sample_rate, rate,
                );
                dev_eprintln!("[USB] {}", refusal);
                set_last_error(Some(refusal.clone()));
                set_direct_mode_refusal_reason(Some(refusal.clone()));
                set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(refusal.clone()));
                cleanup_claimed_handle(
                    claimed_handle,
                    Some(candidate.interface_number),
                    lock_requested,
                );
                return Err(refusal);
            }
        }
    }

    let bytes_per_frame = candidate.subslot_size as usize * candidate.channels as usize;
    if bytes_per_frame == 0 {
        let refusal = format!(
            "USB direct refused: zero-size frame (subslot={}, channels={})",
            candidate.subslot_size, candidate.channels,
        );
        dev_eprintln!("[USB] {}", refusal);
        set_last_error(Some(refusal.clone()));
        set_direct_mode_refusal_reason(Some(refusal.clone()));
        cleanup_claimed_handle(
            claimed_handle,
            Some(candidate.interface_number),
            lock_requested,
        );
        return Err(refusal);
    }

    dev_eprintln!("[USB] === PRE-STREAM VALIDATION ===");
    dev_eprintln!(
        "[USB]   requested_rate  = {}Hz",
        playback_format.sample_rate
    );
    dev_eprintln!(
        "[USB]   dac_reported    = {}Hz",
        reported_sample_rate.unwrap_or(0)
    );
    dev_eprintln!("[USB]   clock_verified  = {}", clock_verification_passed);
    dev_eprintln!("[USB]   bit_depth       = {}", playback_format.bit_depth);
    dev_eprintln!("[USB]   channels        = {}", playback_format.channels);
    dev_eprintln!("[USB]   subslot_size    = {} bytes", candidate.subslot_size);
    dev_eprintln!("[USB]   bytes_per_frame = {}", bytes_per_frame);
    dev_eprintln!(
        "[USB]   interval_us     = {}",
        candidate.service_interval_us
    );
    dev_eprintln!(
        "[USB]   max_packet_size = {} bytes",
        candidate.max_packet_bytes
    );
    dev_eprintln!("[USB] ============================");

    // A rate-set clock that reports Clock Valid = false cannot lock its PLL to
    // the requested carrier. The alt-setting switch above already happened, so
    // this is the post-switch state. DoP data is then clocked against this DAC's
    // free-running oscillator instead of the host's nominal packet timing; the
    // resulting beat shows up as slow, periodic chop (first after tens of
    // seconds, then every few seconds) that looks like a transport bug but is
    // really a clock-lock refusal.
    if let Some(clock) = clock {
        match get_clock_validity(&claimed_handle.handle, clock.interface_number, clock.clock_id) {
            Ok(valid) => {
                log_info!(
                    "[clock-diag] Clock Validity after switch: clock={} iface={} valid={} rate={}Hz",
                    clock.clock_id,
                    clock.interface_number,
                    valid,
                    playback_format.sample_rate,
                );
                if !valid {
                    dev_eprintln!(
                        "[clock-diag] DAC reports Clock Valid=false at {}Hz on clock {} — PLL has not locked to the DoP carrier; periodic dropouts are expected until it locks or accepts another rate",
                        playback_format.sample_rate,
                        clock.clock_id,
                    );
                }
            }
            Err(error) => dev_eprintln!(
                "[clock-diag] Clock Validity unavailable for clock {} at {}Hz: {}",
                clock.clock_id,
                playback_format.sample_rate,
                error,
            ),
        }
    }
    log_info!(
        "[USB] FINAL_STREAM_FORMAT: sample_rate_hz={} dac_reported_hz={:?} clock_verified={} \
         app_bit_depth={} transport_bit_resolution={} subslot_bytes={} channels={} \
         endpoint=0x{:02x} alt={} format_tag=0x{:04x} max_packet_bytes={} \
         (A/B: try Dart prepare with 48000/16/2 if you suspect format mismatch)",
        playback_format.sample_rate,
        reported_sample_rate,
        clock_verification_passed,
        playback_format.bit_depth,
        candidate.bit_resolution,
        candidate.subslot_size,
        playback_format.channels,
        candidate.endpoint_address,
        candidate.alt_setting,
        candidate.format_tag,
        candidate.max_packet_bytes,
    );

    set_last_error(None);
    set_direct_mode_refusal_reason(None);
    set_stream_active(true);
    set_android_usb_engine_state(AndroidDirectUsbEngineState::UsbReady, None);
    set_software_volume_active(false);
    let runtime_stats = Arc::new(AndroidDirectUsbRuntimeStats::new(
        effective_ring_rate(&playback_format),
        playback_format.channels as usize,
        ANDROID_USB_BUFFER_CAPACITY_MS,
        ANDROID_USB_BUFFER_TARGET_MS,
    ));
    set_runtime_stats(Some(Arc::clone(&runtime_stats)));
    let geometry = IsoQueueGeometry::for_stream(
        candidate.service_interval_us,
        playback_format.is_dop || playback_format.dsd_transport == DsdTransportMode::Native,
    );
    let mut preview_scheduler = IsoPacketScheduler::with_geometry(
        playback_format.sample_rate,
        bytes_per_frame,
        candidate.service_interval_us,
        geometry,
    );
    let packet_schedule_preview = preview_scheduler
        .next_transfer_packet_bytes()
        .into_iter()
        .map(|packet_bytes| {
            (packet_bytes
                / (candidate.subslot_size as usize * candidate.channels as usize).max(1))
                as u32
        })
        .collect::<Vec<_>>();
    set_packet_schedule_preview(packet_schedule_preview);
    let pcm_buffer = Arc::new(Mutex::new(AndroidDirectUsbPcmRingBuffer::new(
        runtime_stats.buffer_capacity_samples,
        playback_format.channels as usize,
    )));
    let stop = Arc::new(AtomicBool::new(false));
    let producer_stop = Arc::clone(&stop);
    let producer_buffer = Arc::clone(&pcm_buffer);
    let producer_stats = Arc::clone(&runtime_stats);
    let producer_callback_data = Arc::clone(&callback_data);
    let producer_event_tx = event_tx.clone();
    let producer_thread_handle = match thread::Builder::new()
        .name("android-usb-direct-render".to_string())
        .spawn(move || {
            #[cfg(target_os = "android")]
            if set_audio_thread_priority().is_err() {
                dev_eprintln!("[AudioSched] Render thread running without SCHED_FIFO");
            }
            let panic_event_tx = producer_event_tx.clone();
            let panic_stop = Arc::clone(&producer_stop);
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(move || {
                run_usb_render_loop(
                    producer_callback_data,
                    producer_event_tx,
                    producer_buffer,
                    producer_stats,
                    playback_format,
                    producer_stop,
                );
            }));
            if let Err(payload) = result {
                let message = format!(
                    "Android USB direct render thread panicked: {}",
                    panic_payload_message(payload.as_ref())
                );
                dev_eprintln!("{}", message);
                set_last_error(Some(message.clone()));
                panic_stop.store(true, Ordering::Release);
                let _ = panic_event_tx.try_send(AudioEvent::Error { message });
            }
        }) {
        Ok(handle) => handle,
        Err(error) => {
            set_stream_active(false);
            set_runtime_stats(None);
            set_android_usb_engine_state(
                AndroidDirectUsbEngineState::Error,
                Some(format!(
                    "Failed to spawn Android USB direct render thread: {}",
                    error
                )),
            );
            cleanup_claimed_handle(
                claimed_handle,
                Some(candidate.interface_number),
                lock_requested,
            );
            return Err(format!(
                "Failed to spawn Android USB direct render thread: {}",
                error
            ));
        }
    };

    let usb_stop = Arc::clone(&stop);
    let usb_buffer = Arc::clone(&pcm_buffer);
    let usb_stats = Arc::clone(&runtime_stats);
    let usb_callback_data = Arc::clone(&callback_data);
    let backend_product_name = state.device.product_name.clone();
    let backend_endpoint_address = candidate.endpoint_address;
    let backend_interface_number = candidate.interface_number;
    let backend_alt_setting = candidate.alt_setting;
    let output_session = Arc::clone(session);
    // Publish before spawning: the output thread can fail immediately and must
    // not have its error state overwritten by the caller.
    set_android_usb_engine_state(AndroidDirectUsbEngineState::Streaming, None);
    let thread_handle = match thread::Builder::new()
        .name("android-usb-direct-output".to_string())
        .spawn(move || {
            // Keep the interfaces alive until the loop and its USB handles are done.
            let _session = output_session;
            #[cfg(target_os = "android")]
            if set_audio_thread_priority().is_err() {
                dev_eprintln!("[AudioSched] Output thread running without SCHED_FIFO");
            }
            let panic_event_tx = event_tx.clone();
            let panic_stop = Arc::clone(&usb_stop);
            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(move || {
                run_usb_output_loop(
                    claimed_handle,
                    candidate,
                    state,
                    event_tx,
                    usb_buffer,
                    usb_stats,
                    usb_callback_data,
                    usb_stop,
                );
            }));
            if let Err(payload) = result {
                panic_stop.store(true, Ordering::Release);
                let message = format!(
                    "Android USB direct output thread panicked: {}",
                    panic_payload_message(payload.as_ref())
                );
                dev_eprintln!("{}", message);
                set_last_error(Some(message.clone()));
                set_android_usb_engine_state(
                    AndroidDirectUsbEngineState::Error,
                    Some(message.clone()),
                );
                mark_android_usb_fallback(Some(message.clone()));
                let _ = panic_event_tx.try_send(AudioEvent::Error { message });
                set_stream_active(false);
                set_runtime_stats(None);
                set_usb_stream_stable(false);
            }
        }) {
        Ok(handle) => handle,
        Err(error) => {
            set_stream_active(false);
            set_runtime_stats(None);
            stop.store(true, Ordering::Release);
            let _ = producer_thread_handle.join();
            set_android_usb_engine_state(
                AndroidDirectUsbEngineState::Error,
                Some(format!(
                    "Failed to spawn Android USB direct output thread: {}",
                    error
                )),
            );
            return Err(format!(
                "Failed to spawn Android USB direct output thread: {}",
                error
            ));
        }
    };

    let dsd_transport_label = match playback_format.dsd_transport {
        DsdTransportMode::Native => "Native",
        DsdTransportMode::DoP => "DoP",
        DsdTransportMode::None => "None",
    };
    dev_eprintln!(
        "[USB] Streaming started device='{}' preferred={}Hz effective={}Hz requested={}Hz endpoint=0x{:02x} interface={} alt={} sample_rate={}Hz dsd_transport={}",
        backend_product_name,
        preferred_sample_rate,
        playback_format.sample_rate,
        requested_playback_format.sample_rate,
        backend_endpoint_address,
        backend_interface_number,
        backend_alt_setting,
        playback_format.sample_rate,
        dsd_transport_label,
    );
    Ok(Some(AndroidDirectUsbBackend {
        stop,
        producer_thread_handle: Some(producer_thread_handle),
        usb_thread_handle: Some(thread_handle),
    }))
}

impl AndroidDirectUsbBackend {
    pub fn stop(&mut self) -> Result<(), String> {
        self.stop.store(true, Ordering::Release);

        let mut first_error: Option<String> = None;
        if let Some(handle) = self.producer_thread_handle.take() {
            if let Err(payload) = handle.join() {
                let message = format!(
                    "Android USB direct render thread panicked: {}",
                    panic_payload_message(payload.as_ref())
                );
                first_error.get_or_insert(message);
            }
        }
        if let Some(handle) = self.usb_thread_handle.take() {
            if let Err(payload) = handle.join() {
                let message = format!(
                    "Android USB direct output thread panicked: {}",
                    panic_payload_message(payload.as_ref())
                );
                first_error.get_or_insert(message);
            }
        }

        match first_error {
            Some(error) => Err(error),
            None => Ok(()),
        }
    }
}

impl Drop for AndroidDirectUsbBackend {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

fn run_usb_render_loop(
    callback_data: Arc<AudioCallbackData>,
    event_tx: Sender<AudioEvent>,
    pcm_buffer: Arc<Mutex<AndroidDirectUsbPcmRingBuffer>>,
    runtime_stats: Arc<AndroidDirectUsbRuntimeStats>,
    playback_format: AndroidDirectUsbPlaybackFormat,
    stop: Arc<AtomicBool>,
) {
    let channels = playback_format.channels as usize;
    let ring_rate = effective_ring_rate(&playback_format);
    let chunk_frames = ((ring_rate as usize * ANDROID_USB_RENDER_CHUNK_MS) / 1_000).max(1);
    let chunk_samples = chunk_frames.saturating_mul(channels);
    let target_samples = runtime_stats.buffer_target_samples;
    let mut render_buffer = vec![0.0f32; chunk_samples];
    let mut sample_bits = vec![0i32; chunk_samples];
    let mut warned_no_frames = false;
    let mut logged_render_preview = false;
    let chunk_deadline = Duration::from_millis(ANDROID_USB_RENDER_CHUNK_MS as u64);
    let is_pcm = !playback_format.is_dop && playback_format.dsd_transport == DsdTransportMode::None;

    // Starvation fills must match the wire format: 0x00 bytes are DC on a
    // native DSD wire and zero words break DoP marker sync.
    if playback_format.is_dop {
        callback_data.set_dop_wire_silence(true);
    } else if playback_format.dsd_transport == DsdTransportMode::Native {
        callback_data.set_dsd_wire_silence(true);
    }

    while !usb_stop_requested(&stop) {
        let cycle_start = Instant::now();
        let (generation, buffered_samples, wait_for_decoder) = {
            let mut guard = pcm_buffer.lock();
            let generation = callback_data.output_flush_generation();
            guard.observe_flush(generation);
            let buffered_samples = guard.len_samples();
            (
                generation,
                buffered_samples,
                guard.refill_pending && buffered_samples == 0,
            )
        };
        runtime_stats
            .buffered_samples
            .store(buffered_samples, Ordering::Relaxed);

        if buffered_samples >= target_samples
            || !callback_data.render_for_direct_usb(
                &mut render_buffer,
                &event_tx,
                generation,
                wait_for_decoder,
            )
        {
            thread::sleep(Duration::from_millis(ANDROID_USB_RENDER_POLL_MS));
            continue;
        }

        if cycle_start.elapsed() > chunk_deadline {
            let count = crate::audio::engine::XRUN_COUNT.fetch_add(1, Ordering::Relaxed) + 1;
            dev_eprintln!(
                "[Xrun] render cycle overrun: {:.1}ms > {}ms (total={})",
                cycle_start.elapsed().as_secs_f64() * 1000.0,
                ANDROID_USB_RENDER_CHUNK_MS,
                count
            );
        }
        if render_buffer.is_empty() {
            if !warned_no_frames {
                let message = "USB stream active but no PCM frames received".to_string();
                dev_eprintln!("Android USB direct: {}", message);
                set_last_error(Some(message));
                warned_no_frames = true;
            }
            thread::sleep(Duration::from_millis(ANDROID_USB_RENDER_POLL_MS));
            continue;
        }

        for (bits, sample) in sample_bits.iter_mut().zip(&render_buffer) {
            *bits = sample.to_bits() as i32;
        }

        if is_pcm && !logged_render_preview {
            let non_zero = render_buffer.iter().filter(|s| **s != 0.0).count();
            if non_zero > 0 {
                let f32_min = render_buffer.iter().cloned().fold(f32::INFINITY, f32::min);
                let f32_max = render_buffer
                    .iter()
                    .cloned()
                    .fold(f32::NEG_INFINITY, f32::max);
                let f32_max_abs = render_buffer.iter().fold(0.0f32, |m, &s| m.max(s.abs()));
                let preview_base = render_buffer
                    .iter()
                    .enumerate()
                    .find_map(|(i, s)| (*s != 0.0).then_some(i))
                    .unwrap_or(0);
                let preview_len = 16.min(render_buffer.len().saturating_sub(preview_base));
                log_info!(
                    "[USB-RENDER] === PIPELINE CHECK (first non-zero) === bit_depth={} channels={} chunk_frames={}{}",
                    playback_format.bit_depth,
                    channels,
                    chunk_frames,
                    if channels == 2 {
                        " layout=interleaved_LR (L,R,L,R — Symphonia channel index order)"
                    } else {
                        " layout=interleaved (channel index order)"
                    },
                );
                log_info!(
                    "[USB-RENDER] pre-gain f32 preview @sample_index={}: {:?}",
                    preview_base,
                    &render_buffer[preview_base..preview_base + preview_len],
                );
                log_info!(
                    "[USB-RENDER] f32 stats: non_zero={}/{} min={:.6} max={:.6} max_abs={:.6}",
                    non_zero,
                    render_buffer.len(),
                    f32_min,
                    f32_max,
                    f32_max_abs,
                );
                logged_render_preview = true;
            }
        }

        debug_assert!(
            sample_bits.len() % channels == 0,
            "push_samples: input length {} is not frame-aligned (channels={})",
            sample_bits.len(),
            channels,
        );
        let written_samples = {
            let mut guard = pcm_buffer.lock();
            let current_generation = callback_data.output_flush_generation();
            guard.observe_flush(current_generation);
            let written = if current_generation == generation {
                guard.push_samples(&sample_bits)
            } else {
                0
            };
            runtime_stats
                .buffered_samples
                .store(guard.len_samples(), Ordering::Relaxed);
            written
        };
        runtime_stats
            .producer_frames
            .fetch_add((written_samples / channels) as u64, Ordering::Relaxed);

        if is_pcm && written_samples > 0 {
            let push_max_abs_f32 = render_buffer[..written_samples]
                .iter()
                .fold(0.0f32, |max_abs, sample| max_abs.max(sample.abs()));
            runtime_stats
                .last_push_max_abs_f32_bits
                .store(push_max_abs_f32.to_bits(), Ordering::Relaxed);
        }

        if written_samples > 0 && warned_no_frames {
            let should_clear_warning = DIRECT_USB_STATE
                .lock()
                .as_ref()
                .and_then(|state| state.last_error.as_ref())
                .is_some_and(|error| error == "USB stream active but no PCM frames received");
            if should_clear_warning {
                set_last_error(None);
            }
            warned_no_frames = false;
        }

        if written_samples == 0 {
            thread::sleep(Duration::from_millis(ANDROID_USB_RENDER_POLL_MS));
        }
    }

    callback_data.set_dop_wire_silence(false);
    callback_data.set_dsd_wire_silence(false);
}

fn prepare_iso_transfer_payload(
    scheduler: &mut IsoPacketScheduler,
    pcm_buffer: &Arc<Mutex<AndroidDirectUsbPcmRingBuffer>>,
    runtime_stats: &AndroidDirectUsbRuntimeStats,
    candidate: &AndroidIsoStreamCandidate,
    slot_bytes: usize,
    channels: usize,
    bytes_per_frame: usize,
    dsd_transport: DsdTransportMode,
    dsd_big_endian: bool,
    dsd_bit_reverse: bool,
    callback_data: &AudioCallbackData,
) -> Result<Option<IsoTransferPayload>, String> {
    let packet_sizes = scheduler.next_transfer_packet_bytes();
    let total_bytes: usize = packet_sizes.iter().sum();
    if total_bytes == 0 {
        return Ok(None);
    }

    if packet_sizes
        .iter()
        .any(|packet_size| *packet_size > candidate.max_packet_bytes)
    {
        return Err(format!(
            "Android USB direct packet exceeds endpoint max packet size: packets={:?}, endpoint_max={}",
            packet_sizes, candidate.max_packet_bytes
        ));
    }

    if packet_sizes
        .iter()
        .any(|packet_size| packet_size % bytes_per_frame != 0)
    {
        return Err(format!(
            "Android USB direct packet is not aligned to {}-byte transport frames: {:?}",
            bytes_per_frame, packet_sizes
        ));
    }

    let total_samples = if dsd_transport == DsdTransportMode::Native {
        total_bytes
    } else {
        total_bytes / slot_bytes
    };
    let mut packet_samples = vec![0i32; total_samples];
    // Held transfers carry wire silence but keep the iso stream (and the DAC's
    // clock lock) running. They neither consume the ring nor count as an
    // underrun, and they skip the payload audit: silence is expected there and
    // must not clear the verified state.
    let (underrun, held) = {
        let mut guard = pcm_buffer.lock();
        guard.observe_flush(callback_data.output_flush_generation());
        let paused = callback_data.is_paused();
        if paused {
            guard.refill_pending = true;
        }
        let held = paused || guard.awaiting_refill(total_samples);
        let underrun = if held {
            guard.fill_wire_silence(&mut packet_samples, dsd_transport);
            false
        } else {
            guard.pop_into_or_pad(&mut packet_samples, channels, dsd_transport)
        };
        runtime_stats
            .buffered_samples
            .store(guard.len_samples(), Ordering::Relaxed);
        (underrun, held)
    };

    if !held && dsd_transport == DsdTransportMode::None {
        apply_usb_pcm_gain(&mut packet_samples, callback_data);
    }
    let mut transfer_buffer = vec![0u8; total_bytes];
    encode_usb_pcm_slots(
        &packet_samples,
        &mut transfer_buffer,
        candidate.subslot_size,
        candidate.bit_resolution,
        dsd_transport,
        candidate.channels,
        dsd_big_endian,
        dsd_bit_reverse,
    )?;
    if held {
        // Expected silence: leave the audit latch alone.
    } else if dsd_transport != DsdTransportMode::None {
        observe_dsd_payload_audit(audit_dsd_payload(
            &transfer_buffer,
            dsd_transport,
            candidate.subslot_size,
            candidate.channels,
        ));
    } else {
        observe_pcm_payload_audit(audit_pcm_payload(
            &transfer_buffer,
            candidate.subslot_size,
            candidate.channels,
        ));
    }

    Ok(Some(IsoTransferPayload {
        frame_count: packet_samples.len() / channels,
        packet_sizes,
        packet_samples,
        transfer_buffer,
        underrun,
    }))
}

fn publish_transport_loss(runtime_stats: &AndroidDirectUsbRuntimeStats, tracker: &LossTracker) {
    runtime_stats
        .lost_frames
        .store(tracker.lost_frames(), Ordering::Relaxed);
    runtime_stats
        .short_packets
        .store(tracker.short_packets(), Ordering::Relaxed);
    runtime_stats
        .zero_packets
        .store(tracker.zero_packets(), Ordering::Relaxed);
    runtime_stats
        .data_urb_timeouts
        .store(tracker.data_urb_timeouts(), Ordering::Relaxed);
    if tracker.is_latched() {
        runtime_stats
            .transport_unverified
            .store(true, Ordering::Release);
    }
}

fn update_transfer_timing_stats(
    runtime_stats: &AndroidDirectUsbRuntimeStats,
    turnaround_us: u64,
    submit_gap_us: u64,
    stream_started_at: Instant,
) {
    runtime_stats
        .last_transfer_turnaround_us
        .store(turnaround_us, Ordering::Relaxed);
    if turnaround_us
        > runtime_stats
            .max_transfer_turnaround_us
            .load(Ordering::Relaxed)
    {
        runtime_stats
            .max_transfer_turnaround_us
            .store(turnaround_us, Ordering::Relaxed);
    }

    runtime_stats
        .last_submit_gap_us
        .store(submit_gap_us, Ordering::Relaxed);
    if submit_gap_us > runtime_stats.max_submit_gap_us.load(Ordering::Relaxed) {
        runtime_stats
            .max_submit_gap_us
            .store(submit_gap_us, Ordering::Relaxed);
    }

    let elapsed_us = stream_started_at.elapsed().as_micros().max(1) as u64;
    let completed_frames = runtime_stats.consumer_frames.load(Ordering::Relaxed);
    let effective_consumer_rate_milli_hz = completed_frames
        .saturating_mul(1_000_000_000)
        .checked_div(elapsed_us)
        .unwrap_or(0);
    runtime_stats
        .effective_consumer_rate_milli_hz
        .store(effective_consumer_rate_milli_hz, Ordering::Relaxed);
}

fn drain_iso_transfer_slots(context: &Context, slots: &mut [IsoTransferSlot]) {
    for slot in slots.iter_mut() {
        slot.cancel();
    }

    let deadline = Instant::now() + Duration::from_millis(2000);
    while slots.iter().any(|slot| slot.in_flight) && Instant::now() < deadline {
        let _ = context.handle_events(Some(Duration::from_millis(10)));
        for slot in slots.iter_mut() {
            if slot.take_completion().is_some() {
                slot.mark_completed();
            }
        }
    }

    let still_in_flight = slots.iter().filter(|slot| slot.in_flight).count();
    if still_in_flight > 0 {
        dev_eprintln!(
            "[USB] teardown drain timed out with {} isochronous transfer(s) still in flight; slots will be leaked",
            still_in_flight
        );
    }
}

fn drain_feedback_transfer_slot(context: &Context, slot: &mut Option<FeedbackTransferSlot>) {
    let Some(slot) = slot.as_mut() else {
        return;
    };
    slot.cancel();

    let deadline = Instant::now() + Duration::from_millis(2000);
    while slot.in_flight && Instant::now() < deadline {
        let _ = context.handle_events(Some(Duration::from_millis(10)));
        if slot.take_completion().is_some() {
            slot.mark_completed();
        }
    }

    if slot.in_flight {
        dev_eprintln!(
            "[USB] teardown drain timed out with feedback transfer 0x{:02x} still in flight; slot will be leaked",
            slot.endpoint.address
        );
    }
}

#[allow(clippy::too_many_arguments)]
fn record_prepared_iso_transfer(
    payload: &IsoTransferPayload,
    playback_format: AndroidDirectUsbPlaybackFormat,
    candidate: &AndroidIsoStreamCandidate,
    runtime_stats: &AndroidDirectUsbRuntimeStats,
    bytes_per_frame: usize,
    logged_transfer_preview: &mut bool,
    logged_usb_encode_format: &mut bool,
    underrun_count: &mut u64,
    loud_transfer_log_count: &mut u64,
) {
    if !*logged_usb_encode_format {
        log_info!(
            "[USB] PCM encoding: {}-bit (subslot {} bytes) per descriptor",
            candidate.bit_resolution,
            candidate.subslot_size,
        );
        *logged_usb_encode_format = true;
    }

    runtime_stats.frames_per_packet.store(
        payload.packet_sizes.first().copied().unwrap_or_default() / bytes_per_frame,
        Ordering::Relaxed,
    );

    let packet_max_abs_i64 = payload
        .packet_samples
        .iter()
        .map(|sample| i64::from(*sample).abs())
        .max()
        .unwrap_or(0);
    let packet_peak_equiv_f32 = (packet_max_abs_i64 as f64 / 2_147_483_647.0).min(1.0);
    if playback_format.dsd_transport == DsdTransportMode::None
        && packet_peak_equiv_f32 >= f64::from(ANDROID_USB_LOUD_RENDER_LOG_THRESHOLD)
    {
        *loud_transfer_log_count = (*loud_transfer_log_count).saturating_add(1);
        if *loud_transfer_log_count <= 4
            || *loud_transfer_log_count % ANDROID_USB_LOUD_TRANSFER_LOG_INTERVAL == 0
        {
            let max_abs_i16 = payload
                .packet_samples
                .iter()
                .map(|sample| i32::from(linear_pcm_i32_to_i16(*sample)).abs())
                .max()
                .unwrap_or(0);
            let last_push_f32 = f32::from_bits(
                runtime_stats
                    .last_push_max_abs_f32_bits
                    .load(Ordering::Relaxed),
            );
            log_info!(
                "[USB-PEAK] loud_packet packet_peak_equiv_f32={:.6} max_abs_i32={} max_abs_i16={} samples={} subslot={} bit_resolution={} last_push_pre_gain_peak={:.6}",
                packet_peak_equiv_f32,
                packet_max_abs_i64,
                max_abs_i16,
                payload.packet_samples.len(),
                candidate.subslot_size,
                candidate.bit_resolution,
                last_push_f32,
            );
        }
    }

    if payload.underrun {
        *underrun_count = (*underrun_count).saturating_add(1);
        runtime_stats
            .underrun_count
            .store(*underrun_count, Ordering::Relaxed);
        if *underrun_count <= 4 || *underrun_count % 64 == 0 {
            log_info!(
                "[USB] underrun count={} buffer_fill={}ms frames_per_packet={} packets_per_transfer={}",
                *underrun_count,
                runtime_stats.buffer_fill_ms(),
                payload.packet_sizes.first().copied().unwrap_or_default() / bytes_per_frame,
                payload.packet_sizes.len(),
            );
        }
    }

    if !*logged_transfer_preview {
        let has_nonzero = payload.packet_samples.iter().any(|sample| *sample != 0);
        if has_nonzero {
            let i32_pre: Vec<i32> = payload.packet_samples.iter().take(10).copied().collect();
            let byte_pre: Vec<u8> = payload.transfer_buffer.iter().take(24).copied().collect();
            log_info!(
                "[USB-OUTPUT] first 10 i32 samples (non-zero): {:?}",
                i32_pre,
            );
            if candidate.subslot_size == 2 && candidate.bit_resolution == 16 {
                let i16_pre: Vec<i16> = payload
                    .packet_samples
                    .iter()
                    .take(10)
                    .copied()
                    .map(linear_pcm_i32_to_i16)
                    .collect();
                log_info!("[USB-OUTPUT] first 10 as i16 (linear >>16): {:?}", i16_pre,);
            }
            log_info!("[USB-OUTPUT] first 24 encoded bytes: {:?}", byte_pre,);
            log_stream_debug_preview(
                playback_format,
                candidate,
                &payload.packet_sizes,
                &payload.packet_samples,
                &payload.transfer_buffer,
            );
            *logged_transfer_preview = true;
        }
    }
}

fn optional_age_ms(value: Option<u64>) -> String {
    value
        .map(|age| age.to_string())
        .unwrap_or_else(|| "none".to_string())
}

fn log_iso_timeout_snapshot(
    timed_out_slot: usize,
    polled_slots: &[IsoSlotDiagnostic],
    min_active_slots: usize,
    configured_queue_depth: usize,
    processed_transfers: u64,
    stream_elapsed: Duration,
    last_successful_completion_at: Option<Instant>,
    last_event_poll_gap_us: u64,
    max_event_poll_gap_us: u64,
    max_event_wait_us: u64,
    feedback_counters: &FeedbackCounters,
) {
    let summary = summarize_iso_batch(polled_slots, last_successful_completion_at);
    let pending_slots = polled_slots.iter().filter(|slot| slot.pending_at_poll).count();
    let last_validated_age_ms = summary
        .latest_packet_validated_at
        .map(|completed_at| completed_at.elapsed().as_millis() as u64);
    dev_eprintln!(
        "[USB-TIMEOUT] timedOutSlot={} pendingSlotsAtPoll={} minActiveSlots={} configuredQueueDepth={} processedTransfers={} batchCompletions={} batchPacketValidated={} streamAgeMs={} lastPacketValidatedAgeMs={} lastEventPollGapUs={} maxEventPollGapUs={} maxEventWaitUs={} feedbackReports={} feedbackTimeouts={} feedbackErrors={}",
        timed_out_slot,
        pending_slots,
        min_active_slots,
        configured_queue_depth,
        processed_transfers,
        summary.completion_count,
        summary.packet_validated_count,
        stream_elapsed.as_millis() as u64,
        optional_age_ms(last_validated_age_ms),
        last_event_poll_gap_us,
        max_event_poll_gap_us,
        max_event_wait_us,
        feedback_counters.reports,
        feedback_counters.timeouts,
        feedback_counters.errors,
    );

    for slot in polled_slots {
        let status = slot
            .completion
            .map(|completion| iso_transfer_status_label(completion.status))
            .unwrap_or("none");
        let completion_age_ms = slot
            .completion
            .map(|completion| completion.completed_at.elapsed().as_millis() as u64);
        let packet_validation = match slot.completion {
            Some(completion) if completion.status == LIBUSB_TRANSFER_COMPLETED => {
                if completion.packets_valid { "valid" } else { "invalid" }
            }
            _ => "n/a",
        };
        dev_eprintln!(
            "[USB-TIMEOUT] slot={} timedOut={} pendingAtPoll={} status={} packetValidation={} completionAgeMs={} submittedAgeUs={} queuedFrames={} submittedBytes={} generation={}",
            slot.slot_index,
            slot.slot_index == timed_out_slot,
            slot.pending_at_poll,
            status,
            packet_validation,
            optional_age_ms(completion_age_ms),
            optional_age_ms(slot.submitted_age_us),
            slot.queued_frames,
            slot.submitted_bytes,
            slot.generation,
        );
    }
}

fn run_usb_output_loop(
    claimed_handle: AndroidDirectUsbClaimedHandle,
    candidate: AndroidIsoStreamCandidate,
    state: AndroidDirectUsbState,
    event_tx: Sender<AudioEvent>,
    pcm_buffer: Arc<Mutex<AndroidDirectUsbPcmRingBuffer>>,
    runtime_stats: Arc<AndroidDirectUsbRuntimeStats>,
    callback_data: Arc<AudioCallbackData>,
    stop: Arc<AtomicBool>,
) {
    let AndroidDirectUsbClaimedHandle {
        device_fd,
        context,
        handle,
        claimed_interfaces,
    } = claimed_handle;
    let playback_format = state.playback_format.unwrap();
    USB_DSD_PAYLOAD_LATCH.lock().reset();
    USB_PCM_PAYLOAD_LATCH.lock().reset();
    LAST_BIT_PERFECT_LOGGED.store(false, Ordering::Relaxed);
    let dsd_quirk = resolve_dsd_quirk(
        state.device.vendor_id,
        state.device.product_id,
        &state.device.product_name,
    );
    let dsd_big_endian = crate::audio::dsd_engine::output::dsd_big_endian_override()
        .unwrap_or_else(|| dsd_quirk.map(|q| q.big_endian).unwrap_or(false));
    let dsd_bit_reverse = dsd_quirk.map(|q| q.bit_reverse).unwrap_or(false);
    let slot_bytes = candidate.subslot_size as usize;
    if slot_bytes == 0 {
        let message = "Android USB direct selected an invalid zero-byte subslot".to_string();
        set_last_error(Some(message.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(message.clone()));
        let _ = event_tx.try_send(AudioEvent::Error { message });
        cleanup_claimed_handle(
            AndroidDirectUsbClaimedHandle {
                device_fd,
                context,
                handle,
                claimed_interfaces,
            },
            Some(candidate.interface_number),
            current_lock_requested_for_fd(device_fd),
        );
        set_stream_active(false);
        return;
    }

    if let Err(error) = validate_transport_against_playback_format(&candidate, playback_format) {
        set_last_error(Some(error.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(error.clone()));
        let _ = event_tx.try_send(AudioEvent::Error { message: error });
        cleanup_claimed_handle(
            AndroidDirectUsbClaimedHandle {
                device_fd,
                context,
                handle,
                claimed_interfaces,
            },
            Some(candidate.interface_number),
            current_lock_requested_for_fd(device_fd),
        );
        set_stream_active(false);
        return;
    }

    let channels = candidate.channels as usize;
    let bytes_per_frame = slot_bytes.saturating_mul(channels);
    let dsd_on_wire =
        playback_format.is_dop || playback_format.dsd_transport != DsdTransportMode::None;
    let geometry = IsoQueueGeometry::for_stream(candidate.service_interval_us, dsd_on_wire);
    let mut scheduler = IsoPacketScheduler::with_geometry(
        playback_format.sample_rate,
        bytes_per_frame,
        candidate.service_interval_us,
        geometry,
    );
    let transfer_slot_count = geometry.transfer_slots;
    // One-shot: prove whether the sink links a feedback endpoint at all. If this
    // dump shows a FeedbackData IN endpoint that descriptor parsing missed, the
    // discovery path is wrong; if it shows none, host-side feedback is
    // impossible for this device and only bus-side cushioning can help.
    log_iso_endpoint_descriptors(&handle, &candidate);
    let feedback_endpoint = candidate.feedback_endpoint;
    let mut feedback_slot = None;
    if let Some(endpoint) = feedback_endpoint {
        if candidate.sync_type == SyncType::Asynchronous {
            match FeedbackTransferSlot::new(endpoint) {
                Ok(slot) => feedback_slot = Some(slot),
                Err(error) => {
                    dev_eprintln!(
                        "[USB] Failed to allocate feedback transfer for endpoint 0x{:02x}: {}",
                        endpoint.address,
                        error
                    );
                }
            }
        } else {
            dev_eprintln!(
                "[USB] Ignoring feedback endpoint 0x{:02x}: data endpoint sync type is {:?}, not asynchronous",
                endpoint.address,
                candidate.sync_type
            );
        }
    } else if candidate.sync_type == SyncType::Asynchronous {
        let packets_per_transfer = scheduler.packets_per_transfer();
        let bus_cushion_ms = transfer_slot_count
            .saturating_mul(packets_per_transfer)
            .saturating_mul(candidate.service_interval_us as usize)
            / 1000;
        log_warn!(
            "[USB] Async sink exposes no feedback endpoint; host-paced nominal timing with {} \
             queued transfers (~{}ms bus cushion). Drift beyond that cushion will still drop out.",
            transfer_slot_count,
            bus_cushion_ms,
        );
    }
    runtime_stats
        .transfer_queue_depth
        .store(transfer_slot_count, Ordering::Relaxed);
    let mut logged_transfer_preview = false;
    let mut logged_usb_encode_format = false;
    // Exact isochronous OUT completions. The geometry sets the observation window.
    let mut successful_transfers = 0usize;
    let mut logged_usb_stabilized = false;
    let mut underrun_count = 0u64;
    let mut feedback_counters = FeedbackCounters::default();
    let mut feedback_stale_warned = false;
    let mut min_active_slots = transfer_slot_count;
    let mut loud_transfer_log_count = 0u64;
    // Native DSD and DoP keep strict completion and timeout handling. Missing
    // DoP frames may break the marker sequence as well as lose audio.
    let pcm_frame_bytes = (!dsd_on_wire).then_some(bytes_per_frame);
    let mut loss_tracker = LossTracker::new(LossLimits {
        max_consecutive_lossy_urbs: ANDROID_USB_MAX_CONSECUTIVE_LOSSY_URBS,
        max_lost_frames: lost_frame_budget(
            playback_format.sample_rate,
            ANDROID_USB_MAX_LOST_AUDIO_MS,
        ),
    });
    let mut loss_log_gate = LossLogGate::new(
        ANDROID_USB_LOSS_LOG_BURST,
        ANDROID_USB_LOSS_LOG_MIN_INTERVAL_MS,
    );
    let mut timeout_snapshot_gate = LossLogGate::new(1, ANDROID_USB_LOSS_LOG_MIN_INTERVAL_MS);
    let transfer_buffer_capacity = scheduler
        .packets_per_transfer()
        .saturating_mul(candidate.max_packet_bytes.max(1));
    let mut slots = Vec::with_capacity(transfer_slot_count);
    let mut ready_completions = Vec::with_capacity(transfer_slot_count);
    let mut polled_slots = Vec::with_capacity(transfer_slot_count);
    let mut active_slots = 0usize;
    let mut fatal_error: Option<String> = None;
    let mut last_successful_completion_at: Option<Instant> = None;
    let mut last_event_poll_started_at: Option<Instant> = None;
    let mut last_event_poll_gap_us = 0u64;
    let mut max_event_poll_gap_us = 0u64;
    let mut max_event_wait_us = 0u64;

    let priming_target = runtime_stats.buffer_target_samples;
    log_info!(
        "[USB] Isochronous queue: serviceIntervalUs={} packetsPerTransfer={} slots={} stableTransfers={}",
        candidate.service_interval_us,
        geometry.packets_per_transfer,
        geometry.transfer_slots,
        geometry.stable_transfers,
    );
    log_info!(
        "[USB] Waiting for stream prime: buffered_samples must reach buffer_target_samples={} before isochronous submit",
        priming_target,
    );
    while !usb_stop_requested(&stop) {
        // Pause or seek can arrive before priming finishes. Start with valid
        // silence instead of waiting on a held or cleared ring. Protect the
        // first transfer even if the user resumes before we prepare it.
        if callback_data.is_paused() || callback_data.output_flush_generation() != 0 {
            pcm_buffer.lock().refill_pending = true;
            break;
        }
        let buffered = runtime_stats.buffered_samples.load(Ordering::Relaxed);
        if buffered >= priming_target {
            log_info!(
                "[USB] USB stream primed: {} samples buffered (target={})",
                buffered,
                priming_target,
            );
            break;
        }
        thread::sleep(Duration::from_millis(2));
    }

    for slot_index in 0..transfer_slot_count {
        if usb_stop_requested(&stop) {
            break;
        }
        match IsoTransferSlot::new(
            slot_index,
            scheduler.packets_per_transfer(),
            transfer_buffer_capacity,
        ) {
            Ok(slot) => slots.push(slot),
            Err(error) => {
                fatal_error = Some(format!(
                    "Android USB direct failed to allocate transfer slot: {}",
                    error
                ));
                break;
            }
        }
    }

    let stream_started_at = Instant::now();
    if fatal_error.is_none() {
        for slot in slots.iter_mut() {
            if usb_stop_requested(&stop) {
                break;
            }
            let payload = match prepare_iso_transfer_payload(
                &mut scheduler,
                &pcm_buffer,
                &runtime_stats,
                &candidate,
                slot_bytes,
                channels,
                bytes_per_frame,
                playback_format.dsd_transport,
                dsd_big_endian,
                dsd_bit_reverse,
                &callback_data,
            ) {
                Ok(Some(payload)) => payload,
                Ok(None) => continue,
                Err(error) => {
                    fatal_error = Some(format!(
                        "Android USB direct transfer preparation failed: {}",
                        error
                    ));
                    break;
                }
            };

            record_prepared_iso_transfer(
                &payload,
                playback_format,
                &candidate,
                &runtime_stats,
                bytes_per_frame,
                &mut logged_transfer_preview,
                &mut logged_usb_encode_format,
                &mut underrun_count,
                &mut loud_transfer_log_count,
            );

            if let Err(error) = slot.submit(&handle, candidate.endpoint_address, payload) {
                fatal_error = Some(format!("Android USB direct transfer failed: {}", error));
                break;
            }
            active_slots = active_slots.saturating_add(1);
        }
    }
    min_active_slots = min_active_slots.min(active_slots);

    if let Some(slot) = feedback_slot.as_mut().filter(|_| !usb_stop_requested(&stop)) {
        let endpoint = slot.endpoint;
        match slot.submit(&handle) {
            Ok(()) => {
                log_info!(
                    "[USB] Feedback endpoint 0x{:02x} {} interval={} service={}us maxPacket={} pollPackets={} timeout={}ms (asynchronous, nonblocking)",
                    endpoint.address,
                    transfer_type_label(endpoint.transfer_type),
                    endpoint.interval,
                    endpoint.service_interval_us,
                    endpoint.max_packet_bytes,
                    slot.packet_count,
                    slot.timeout_ms,
                );
            }
            Err(error) => {
                dev_eprintln!(
                    "[USB] Feedback endpoint 0x{:02x} initial submit failed: {}",
                    endpoint.address,
                    error
                );
                feedback_counters.errors = feedback_counters.errors.saturating_add(1);
                feedback_slot = None;
            }
        }
    }

    while fatal_error.is_none() && (!usb_stop_requested(&stop) || active_slots > 0) {
        if active_slots == 0 {
            break;
        }

        let event_poll_started_at = Instant::now();
        if let Some(previous_poll_started_at) = last_event_poll_started_at {
            last_event_poll_gap_us = event_poll_started_at
                .saturating_duration_since(previous_poll_started_at)
                .as_micros()
                .min(u128::from(u64::MAX)) as u64;
            max_event_poll_gap_us = max_event_poll_gap_us.max(last_event_poll_gap_us);
        }
        last_event_poll_started_at = Some(event_poll_started_at);

        let event_result = context.handle_events(Some(Duration::from_millis(50)));
        max_event_wait_us = max_event_wait_us.max(
            event_poll_started_at
                .elapsed()
                .as_micros()
                .min(u128::from(u64::MAX)) as u64,
        );
        if let Err(error) = event_result {
            fatal_error = Some(format!("libusb_handle_events failed: {}", error));
            break;
        }

        if let Some(feedback_slot) = feedback_slot.as_mut() {
            pump_feedback_transfer(
                &handle,
                feedback_slot,
                &mut scheduler,
                candidate.service_interval_us,
                candidate.usb_speed,
                &mut feedback_counters,
                &stop,
            );
        }

        ready_completions.clear();
        polled_slots.clear();
        for (index, slot) in slots.iter_mut().enumerate() {
            let completion = slot.take_completion().map(|(status, completed_at, _)| {
                ready_completions.push((index, status, completed_at));
                IsoCompletionDiagnostic {
                    status,
                    completed_at,
                    packets_valid: false,
                }
            });
            polled_slots.push(slot.diagnostic(completion));
        }
        // Slot indices wrap as transfers are reused. Count consecutive
        // interruptions in callback order rather than ring slot order.
        ready_completions.sort_unstable_by_key(|&(index, _, completed_at)| {
            (completed_at, slots[index].submitted_at)
        });
        let timed_out_slot = ready_completions
            .iter()
            .find(|&&(_, status, _)| status == LIBUSB_TRANSFER_TIMED_OUT)
            .map(|&(index, _, _)| index);

        let mut retired = 0;
        for &(index, status, completed_at) in &ready_completions {
            let slot = &mut slots[index];
            active_slots = active_slots.saturating_sub(1);
            min_active_slots = min_active_slots.min(active_slots);
            runtime_stats
                .transfer_queue_depth
                .store(active_slots, Ordering::Relaxed);
            let turnaround_us = slot.turnaround_us(completed_at).unwrap_or_default();
            let queued_frame_count = slot.queued_frame_count as u64;
            let completed_underrun = slot.queued_underrun;
            let timed_out = status == LIBUSB_TRANSFER_TIMED_OUT;
            let transfer_result = match status {
                LIBUSB_TRANSFER_COMPLETED => slot.validate_packets(pcm_frame_bytes, false),
                LIBUSB_TRANSFER_TIMED_OUT if pcm_frame_bytes.is_some() => {
                    slot.validate_packets(pcm_frame_bytes, true)
                }
                LIBUSB_TRANSFER_TIMED_OUT => Err("isochronous transfer timed out".to_string()),
                LIBUSB_TRANSFER_STALL => Err("isochronous transfer stalled".to_string()),
                LIBUSB_TRANSFER_NO_DEVICE => Err("USB DAC disconnected".to_string()),
                LIBUSB_TRANSFER_OVERFLOW => Err("isochronous transfer overflow".to_string()),
                LIBUSB_TRANSFER_CANCELLED => Err("isochronous transfer cancelled".to_string()),
                LIBUSB_TRANSFER_ERROR => Err("isochronous transfer failed".to_string()),
                other => Err(format!(
                    "isochronous transfer returned status {} ({})",
                    other,
                    iso_transfer_status_label(other)
                )),
            };
            slot.mark_completed();
            retired += 1;

            let completion_stats = match transfer_result {
                Ok(stats) => stats,
                Err(error) => {
                    fatal_error = Some(format!(
                        "Android USB direct transfer failed: {}; sample_rate={} channels={} \
                         subslot_bytes={} bit_resolution={} service_interval_us={} interface={} \
                         alt={} endpoint=0x{:02x} speed={:?} sync={}",
                        error,
                        playback_format.sample_rate,
                        channels,
                        slot_bytes,
                        candidate.bit_resolution,
                        candidate.service_interval_us,
                        candidate.interface_number,
                        candidate.alt_setting,
                        candidate.endpoint_address,
                        candidate.usb_speed,
                        sync_type_label(candidate.sync_type),
                    ));
                    break;
                }
            };

            let urb_loss = UrbLoss::from_completion(completion_stats, timed_out);
            let verdict = loss_tracker.record(queued_frame_count, urb_loss);
            if verdict.lossy {
                publish_transport_loss(&runtime_stats, &loss_tracker);
                if verdict.newly_latched {
                    set_usb_stream_stable(false);
                }
                if loss_log_gate.admit(stream_started_at.elapsed().as_millis() as u64) {
                    let message = format!(
                        "[USB] ISO PCM completion interrupted: timedOut={} urbLostFrames={}/{} \
                         lostFrames={} shortPackets={} zeroPackets={} dataUrbTimeouts={} \
                         consecutiveLossyUrbs={}",
                        timed_out,
                        urb_loss.lost_frames,
                        queued_frame_count,
                        loss_tracker.lost_frames(),
                        loss_tracker.short_packets(),
                        loss_tracker.zero_packets(),
                        loss_tracker.data_urb_timeouts(),
                        loss_tracker.consecutive_lossy_urbs(),
                    );
                    if verdict.newly_latched {
                        log_usb_event(message);
                    } else {
                        log_warn!("{}", message);
                    }
                }
            }

            if verdict.counts_as_successful_transfer() {
                successful_transfers = successful_transfers.saturating_add(1);
                if let Some(completion) = polled_slots[index].completion.as_mut() {
                    completion.packets_valid = true;
                }
                last_successful_completion_at =
                    last_successful_completion_at.max(Some(completed_at));
            }

            let completed_transfers = runtime_stats
                .completed_transfers
                .fetch_add(1, Ordering::Relaxed)
                .saturating_add(1);
            runtime_stats
                .consumer_frames
                .fetch_add(verdict.consumed_frames, Ordering::Relaxed);

            if let Some(limit) = verdict.fatal {
                fatal_error = Some(format!(
                    "Android USB direct transfer failed: {}; lost_frames={} short_packets={} \
                     zero_packets={} data_urb_timeouts={}; sample_rate={} channels={} \
                     subslot_bytes={} bit_resolution={} service_interval_us={} interface={} \
                     alt={} endpoint=0x{:02x} speed={:?} sync={}",
                    limit,
                    loss_tracker.lost_frames(),
                    loss_tracker.short_packets(),
                    loss_tracker.zero_packets(),
                    loss_tracker.data_urb_timeouts(),
                    playback_format.sample_rate,
                    channels,
                    slot_bytes,
                    candidate.bit_resolution,
                    candidate.service_interval_us,
                    candidate.interface_number,
                    candidate.alt_setting,
                    candidate.endpoint_address,
                    candidate.usb_speed,
                    sync_type_label(candidate.sync_type),
                ));
                break;
            }

            let mut submit_gap_us = 0u64;
            if !usb_stop_requested(&stop) {
                match prepare_iso_transfer_payload(
                    &mut scheduler,
                    &pcm_buffer,
                    &runtime_stats,
                    &candidate,
                    slot_bytes,
                    channels,
                    bytes_per_frame,
                    playback_format.dsd_transport,
                    dsd_big_endian,
                    dsd_bit_reverse,
                    &callback_data,
                ) {
                    Ok(Some(payload)) => {
                        record_prepared_iso_transfer(
                            &payload,
                            playback_format,
                            &candidate,
                            &runtime_stats,
                            bytes_per_frame,
                            &mut logged_transfer_preview,
                            &mut logged_usb_encode_format,
                            &mut underrun_count,
                            &mut loud_transfer_log_count,
                        );

                        if let Err(error) =
                            slot.submit(&handle, candidate.endpoint_address, payload)
                        {
                            fatal_error =
                                Some(format!("Android USB direct transfer failed: {}", error));
                            break;
                        }
                        submit_gap_us = completed_at
                            .elapsed()
                            .as_micros()
                            .min(u128::from(u64::MAX))
                            as u64;
                        active_slots = active_slots.saturating_add(1);
                        runtime_stats
                            .transfer_queue_depth
                            .store(active_slots, Ordering::Relaxed);
                    }
                    Ok(None) => {}
                    Err(error) => {
                        fatal_error = Some(format!(
                            "Android USB direct transfer preparation failed: {}",
                            error
                        ));
                        break;
                    }
                }
            }

            update_transfer_timing_stats(
                &runtime_stats,
                turnaround_us,
                submit_gap_us,
                stream_started_at,
            );

            if completed_transfers % ANDROID_USB_TIMING_LOG_INTERVAL == 0 {
                let effective_consumer_rate_hz = runtime_stats
                    .effective_consumer_rate_milli_hz
                    .load(Ordering::Relaxed)
                    as f64
                    / 1_000.0;
                let feedback_age_ms = feedback_counters
                    .last_report_at
                    .map(|reported_at| reported_at.elapsed().as_millis() as i64)
                    .unwrap_or(-1);
                let feedback_rate_hz = feedback_counters.last_estimated_sample_rate.unwrap_or(0.0);
                log_info!(
                    "[USB-TIMING] completed={} queueDepth={} minQueueDepth={} configuredQueueDepth={} effectiveRateHz={:.3} lastTurnaroundUs={} maxTurnaroundUs={} lastSubmitGapUs={} maxSubmitGapUs={} feedbackActive={} reports={} timeouts={} errors={} rejected={} feedbackAgeMs={} feedbackRateHz={:.2} lostFrames={} shortPackets={} zeroPackets={} dataUrbTimeouts={} transportUnverified={}",
                    completed_transfers,
                    runtime_stats.transfer_queue_depth.load(Ordering::Relaxed),
                    min_active_slots,
                    transfer_slot_count,
                    effective_consumer_rate_hz,
                    runtime_stats.last_transfer_turnaround_us.load(Ordering::Relaxed),
                    runtime_stats.max_transfer_turnaround_us.load(Ordering::Relaxed),
                    runtime_stats.last_submit_gap_us.load(Ordering::Relaxed),
                    runtime_stats.max_submit_gap_us.load(Ordering::Relaxed),
                    feedback_slot.is_some(),
                    feedback_counters.reports,
                    feedback_counters.timeouts,
                    feedback_counters.errors,
                    feedback_counters.rejected,
                    feedback_age_ms,
                    feedback_rate_hz,
                    runtime_stats.lost_frames.load(Ordering::Relaxed),
                    runtime_stats.short_packets.load(Ordering::Relaxed),
                    runtime_stats.zero_packets.load(Ordering::Relaxed),
                    runtime_stats.data_urb_timeouts.load(Ordering::Relaxed),
                    runtime_stats.transport_unverified(),
                );
                let feedback_stale = feedback_slot.is_some()
                    && if feedback_counters.reports == 0 {
                        stream_started_at.elapsed()
                            >= Duration::from_millis(ANDROID_USB_FEEDBACK_STALE_WARN_MS)
                    } else {
                        feedback_age_ms
                            >= ANDROID_USB_FEEDBACK_STALE_WARN_MS as i64
                    };
                if feedback_stale && !feedback_stale_warned {
                    if feedback_counters.reports == 0 {
                        dev_eprintln!(
                            "[USB] Feedback endpoint has produced no valid report after {}ms; nominal timing remains active",
                            stream_started_at.elapsed().as_millis()
                        );
                    } else {
                        dev_eprintln!(
                            "[USB] Feedback report is stale for {}ms; holding last feedback-derived packet timing",
                            feedback_age_ms
                        );
                    }
                    feedback_stale_warned = true;
                } else if !feedback_stale {
                    feedback_stale_warned = false;
                }
            }

            let timing_settled = verdict.counts_as_successful_transfer()
                && !completed_underrun
                && successful_transfers >= geometry.stable_transfers;
            set_usb_stream_stable(timing_settled && !loss_tracker.is_latched());
            if timing_settled && !logged_usb_stabilized {
                if feedback_slot.is_none() {
                    scheduler.lock_to_nominal_packet_timing();
                    log_info!(
                        "[USB] USB packet timing settled after {} isochronous transfers (nominal packet timing locked)",
                        successful_transfers
                    );
                } else {
                    log_info!(
                        "[USB] USB packet timing settled after {} transfers (feedback-driven packet timing active, reports={}, timeouts={})",
                        successful_transfers,
                        feedback_counters.reports,
                        feedback_counters.timeouts,
                    );
                }
                logged_usb_stabilized = true;
            }
        }

        // These callbacks have already been taken. If the loop stopped on a
        // fatal error, retire the remaining completed slots before draining.
        let unprocessed = &ready_completions[retired..];
        if !unprocessed.is_empty() {
            for &(index, status, _) in unprocessed {
                let slot = &mut slots[index];
                if timed_out_slot.is_some() && status == LIBUSB_TRANSFER_COMPLETED {
                    // Validate for the snapshot only. Do not credit or resubmit
                    // slots abandoned after a fatal error.
                    if let Some(completion) = polled_slots[index].completion.as_mut() {
                        completion.packets_valid = slot.validate_packets(None, false).is_ok();
                    }
                }
                slot.mark_completed();
            }
            active_slots = active_slots.saturating_sub(unprocessed.len());
            min_active_slots = min_active_slots.min(active_slots);
            runtime_stats
                .transfer_queue_depth
                .store(active_slots, Ordering::Relaxed);
        }

        // PCM recovery may produce several snapshots; keep fatal ones and
        // rate-limit repeated recoverable timeouts.
        if let Some(timed_out_slot) = timed_out_slot.filter(|_| {
            fatal_error.is_some()
                || timeout_snapshot_gate.admit(stream_started_at.elapsed().as_millis() as u64)
        }) {
            log_iso_timeout_snapshot(
                timed_out_slot,
                &polled_slots,
                min_active_slots,
                transfer_slot_count,
                runtime_stats.completed_transfers.load(Ordering::Relaxed),
                stream_started_at.elapsed(),
                last_successful_completion_at,
                last_event_poll_gap_us,
                max_event_poll_gap_us,
                max_event_wait_us,
                &feedback_counters,
            );
        }
    }

    if let Some(error) = fatal_error {
        runtime_stats
            .transport_unverified
            .store(true, Ordering::Release);
        set_usb_stream_stable(false);
        set_last_error(Some(error.clone()));
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Error, Some(error.clone()));
        let _ = event_tx.try_send(AudioEvent::Error {
            message: error.clone(),
        });
        dev_eprintln!("{}", error);
    }

    drain_iso_transfer_slots(&context, &mut slots);
    drain_feedback_transfer_slot(&context, &mut feedback_slot);

    cleanup_claimed_handle(
        AndroidDirectUsbClaimedHandle {
            device_fd,
            context,
            handle,
            claimed_interfaces,
        },
        Some(candidate.interface_number),
        current_lock_requested_for_fd(device_fd),
    );
    set_stream_active(false);
    set_runtime_stats(None);
    set_usb_stream_stable(false);
    if usb_stop_requested(&stop) {
        set_android_usb_engine_state(AndroidDirectUsbEngineState::Idle, None);
    }
}

/// Decode UAC feedback into frames per data-endpoint service interval.
///
/// UAC2 feedback reports samples per microframe on high-speed links and
/// samples per frame on full-speed links. The feedback endpoint's own polling
/// interval is not the data endpoint's packet interval; using it as the
/// timebase previously produced a rate error of up to 8x at 125 us service.
fn decode_feedback_report(
    raw_bytes: &[u8],
    data_service_interval_us: u32,
    speed: Speed,
) -> Option<(f64, f64)> {
    let (frames_per_base_interval, base_interval_us) = match raw_bytes.len() {
        3 => {
            let raw = u32::from(raw_bytes[0])
                | (u32::from(raw_bytes[1]) << 8)
                | (u32::from(raw_bytes[2]) << 16);
            let base_interval_us = feedback_base_interval_us(speed, data_service_interval_us);
            (raw as f64 / 16_384.0, base_interval_us)
        }
        4.. => {
            let raw = u32::from_le_bytes([raw_bytes[0], raw_bytes[1], raw_bytes[2], raw_bytes[3]]);
            let base_interval_us = feedback_base_interval_us(speed, data_service_interval_us);
            (raw as f64 / 65_536.0, base_interval_us)
        }
        _ => return None,
    };

    let packet_multiplier = data_service_interval_us as f64 / base_interval_us;
    let frames_per_packet = frames_per_base_interval * packet_multiplier;
    let estimated_sample_rate = frames_per_base_interval * (1_000_000.0 / base_interval_us);
    Some((frames_per_packet, estimated_sample_rate))
}

fn feedback_base_interval_us(speed: Speed, data_service_interval_us: u32) -> f64 {
    match speed {
        Speed::Low | Speed::Full => 1_000.0,
        Speed::High | Speed::Super | Speed::SuperPlus => 125.0,
        Speed::Unknown => {
            // Isochronous audio at sub-millisecond service intervals can only
            // exist on a high-speed link. Fall back to the data endpoint when
            // libusb could not identify the bus speed.
            if data_service_interval_us < 1_000 {
                125.0
            } else {
                1_000.0
            }
        }
        _ => {
            if data_service_interval_us < 1_000 {
                125.0
            } else {
                1_000.0
            }
        }
    }
}

fn select_stream_candidate(
    device: &Device<Context>,
    handle: &DeviceHandle<Context>,
    playback_format: AndroidDirectUsbPlaybackFormat,
    speed: Speed,
) -> Result<AndroidIsoStreamCandidate, String> {
    let config_descriptor = device
        .active_config_descriptor()
        .map_err(|error| format!("Failed to read active USB config descriptor: {}", error))?;
    let mut candidates = Vec::new();
    let prefer_padded_24bit_transport = device_prefers_padded_24bit_transport(device);
    let dsd_subslot_override = crate::audio::dsd_engine::output::dsd_subslot_override()
        .or_else(|| resolve_dsd_quirk_for_device(device, handle).map(|q| q.preferred_subslot));
    let mut stream_rate_cache =
        std::collections::HashMap::<(u8, Option<u8>), Vec<SamplingFrequencySubrange>>::new();
    for interface in config_descriptor.interfaces() {
        for descriptor in interface.descriptors() {
            if descriptor.class_code() != USB_CLASS_AUDIO
                || descriptor.sub_class_code() != USB_SUBCLASS_AUDIOSTREAMING
            {
                continue;
            }

            let mut stream_format = match parse_android_streaming_interface_format(&descriptor) {
                Some(format) => format,
                None => continue,
            };
            if stream_format.format_tag == FORMAT_TAG_DSD {
                if let Some(ss) = dsd_subslot_override {
                    stream_format.subslot_size = ss;
                }
            }

            let compatibility_penalty =
                transport_compatibility_penalty(&stream_format, playback_format);
            if compatibility_penalty == u32::MAX {
                continue;
            }

            let sample_rate_ranges = stream_rate_cache
                .entry((descriptor.interface_number(), stream_format.terminal_link))
                .or_insert_with(|| {
                    discover_stream_sample_rate_ranges(
                        device,
                        handle,
                        descriptor.interface_number(),
                        stream_format.terminal_link,
                        &stream_format.sample_rate_ranges,
                    )
                })
                .clone();
            let sample_rates = representative_sample_rates_from_ranges(&sample_rate_ranges);

            let effective_sample_rate = if playback_format.dsd_transport == DsdTransportMode::Native
                && stream_format.format_tag == FORMAT_TAG_DSD
                && playback_format.dsd_bit_rate > 0
                && stream_format.subslot_size > 0
            {
                playback_format.dsd_bit_rate / (8 * u32::from(stream_format.subslot_size))
            } else {
                playback_format.sample_rate
            };

            if !sample_rate_ranges.is_empty()
                && stream_format.format_tag != FORMAT_TAG_DSD
                && !sampling_frequency_ranges_support_rate(
                    &sample_rate_ranges,
                    effective_sample_rate,
                )
            {
                continue;
            }

            if stream_format.format_tag == FORMAT_TAG_DSD
                && !sample_rate_ranges.is_empty()
                && !sampling_frequency_ranges_support_rate(
                    &sample_rate_ranges,
                    effective_sample_rate,
                )
            {
                continue;
            }

            for endpoint in descriptor.endpoint_descriptors() {
                if descriptor.setting_number() == 0 {
                    continue;
                }
                if endpoint.direction() != Direction::Out
                    || endpoint.transfer_type() != TransferType::Isochronous
                {
                    continue;
                }
                if endpoint.interval() == 0 {
                    dev_eprintln!(
                        "Android USB direct skipping invalid isochronous endpoint=0x{:02x} on interface {} alt {} because bInterval=0",
                        endpoint.address(),
                        descriptor.interface_number(),
                        descriptor.setting_number(),
                    );
                    continue;
                }

                if !matches!(
                    endpoint.usage_type(),
                    UsageType::Data | UsageType::FeedbackData | UsageType::Feedback
                ) {
                    continue;
                }

                let speed = if speed == Speed::Unknown {
                    infer_high_speed_from_sample_rates(&sample_rate_ranges).unwrap_or(speed)
                } else {
                    speed
                };
                dev_eprintln!(
                    "[USB] select_stream_candidate using speed={:?} for interval={} → service={}us",
                    speed,
                    endpoint.interval(),
                    service_interval_micros(speed, endpoint.interval())
                );
                let service_interval_us = service_interval_micros(speed, endpoint.interval());
                let max_packet_bytes =
                    effective_iso_packet_bytes(endpoint.max_packet_size(), speed);
                let feedback_endpoint = find_feedback_endpoint(
                    &descriptor,
                    endpoint.synch_address(),
                    endpoint.sync_type(),
                    speed,
                );
                let bytes_per_frame =
                    stream_format.subslot_size as usize * stream_format.channels as usize;
                let required_max_packet_bytes = required_max_packet_bytes(
                    effective_sample_rate,
                    service_interval_us,
                    bytes_per_frame,
                );

                dev_eprintln!(
                    "Android USB direct stream candidate interface={} alt={} endpoint=0x{:02x} interval={} service={}us max_packet={} required={} sync={:?} usage={:?} fmt={} channels={} subslot={} bit_resolution={} sample_rates={:?} penalty={}",
                    descriptor.interface_number(),
                    descriptor.setting_number(),
                    endpoint.address(),
                    endpoint.interval(),
                    service_interval_us,
                    max_packet_bytes,
                    required_max_packet_bytes,
                    endpoint.sync_type(),
                    endpoint.usage_type(),
                    format_tag_label(stream_format.format_tag),
                    stream_format.channels,
                    stream_format.subslot_size,
                    stream_format.bit_resolution,
                    sample_rates,
                    compatibility_penalty,
                );

                if endpoint.synch_address() != 0 && feedback_endpoint.is_none() {
                    dev_eprintln!(
                        "[USB] Skipping async endpoint=0x{:02x} on interface {} alt {} because feedback endpoint 0x{:02x} was not found",
                        endpoint.address(),
                        descriptor.interface_number(),
                        descriptor.setting_number(),
                        endpoint.synch_address(),
                    );
                    continue;
                }

                if max_packet_bytes < required_max_packet_bytes {
                    continue;
                }

                candidates.push(AndroidIsoStreamCandidate {
                    interface_number: descriptor.interface_number(),
                    alt_setting: descriptor.setting_number(),
                    endpoint_address: endpoint.address(),
                    endpoint_interval: endpoint.interval(),
                    service_interval_us,
                    usb_speed: speed,
                    max_packet_bytes,
                    sync_type: endpoint.sync_type(),
                    usage_type: endpoint.usage_type(),
                    format_tag: stream_format.format_tag,
                    channels: stream_format.channels,
                    subslot_size: stream_format.subslot_size,
                    bit_resolution: stream_format.bit_resolution,
                    sample_rates: sample_rates.clone(),
                    refresh: endpoint.refresh(),
                    synch_address: endpoint.synch_address(),
                    feedback_endpoint,
                    terminal_link: stream_format.terminal_link,
                    is_uac1: stream_format.is_uac1,
                });
            }
        }
    }

    let dsd_bit_rate = playback_format.dsd_bit_rate;
    let is_native_dsd = playback_format.dsd_transport == DsdTransportMode::Native;
    candidates.sort_by_key(|candidate| {
        let candidate_rate = if is_native_dsd && dsd_bit_rate > 0 {
            dsd_bit_rate / (8 * u32::from(candidate.subslot_size.max(1)))
        } else {
            playback_format.sample_rate
        };
        let required_bytes = required_max_packet_bytes(
            candidate_rate,
            candidate.service_interval_us,
            candidate.subslot_size as usize * candidate.channels as usize,
        );
        (
            transport_container_preference_rank(
                candidate,
                playback_format,
                prefer_padded_24bit_transport,
            ),
            transport_compatibility_penalty_for_candidate(candidate, playback_format),
            candidate.max_packet_bytes.saturating_sub(required_bytes),
            candidate.interface_number,
            candidate.alt_setting,
        )
    });

    let label_rate = if is_native_dsd && dsd_bit_rate > 0 {
        format!("DSD{}@{}Hz", dsd_bit_rate, dsd_bit_rate / 32)
    } else {
        format!("{} Hz", playback_format.sample_rate)
    };
    candidates.into_iter().next().ok_or_else(|| {
        format!(
            "No isochronous OUT endpoint can carry {} / {}-bit / {} ch",
            label_rate, playback_format.bit_depth, playback_format.channels
        )
    })
}

/// Log every descriptor-level endpoint that *could* be a UAC2 feedback source,
/// plus what the selected alt setting actually advertises.
///
/// This is diagnostic only: it is emitted once per stream start so the log
/// answers "does this DAC expose a feedback pipe that we failed to find?" without
/// needing a host-side USB capture.
fn log_iso_endpoint_descriptors(
    handle: &DeviceHandle<Context>,
    candidate: &AndroidIsoStreamCandidate,
) {
    dev_eprintln!(
        "[USB] Endpoint audit: selected interface={} alt={} endpoint=0x{:02x}; \
         feedback={} sync={:?}",
        candidate.interface_number,
        candidate.alt_setting,
        candidate.endpoint_address,
        candidate
            .feedback_endpoint
            .map(|feedback| format!(
                "0x{:02x}/{}@interval{}",
                feedback.address,
                transfer_type_label(feedback.transfer_type),
                feedback.interval,
            ))
            .unwrap_or_else(|| "none".to_string()),
        candidate.sync_type,
    );

    if candidate.sync_type != SyncType::Asynchronous {
        return;
    }
    if candidate.feedback_endpoint.is_some() {
        return;
    }

    // Only reached for an async sink with no resolved feedback pipe. Report the
    // neighbouring IN endpoints we rejected and why, so a genuine discovery gap
    // is distinguishable from a device that simply has no feedback.
    dev_eprintln!(
        "[USB] Async sink on interface {} alt {} has no resolved feedback endpoint \
         (bSynchAddress=0x{:02x}). Playback is host-paced on nominal packet timing, so DAC \
         oscillator drift can underrun its FIFO at intervals that scale with the drift offset.",
        candidate.interface_number,
        candidate.alt_setting,
        candidate.synch_address,
    );

    let config = match handle.device().active_config_descriptor() {
        Ok(config) => config,
        Err(_) => return,
    };
    for interface in config.interfaces() {
        if interface.number() != candidate.interface_number {
            continue;
        }
        for alt in interface.descriptors() {
            for endpoint in alt.endpoint_descriptors() {
                if endpoint.direction() != Direction::In {
                    continue;
                }
                dev_eprintln!(
                    "[USB] Endpoint audit: unused IN endpoint=0x{:02x} alt={} type={:?} usage={:?} interval={} maxPacket={} on interface {} (async data endpoint has no feedback)",
                    endpoint.address(),
                    alt.setting_number(),
                    endpoint.transfer_type(),
                    endpoint.usage_type(),
                    endpoint.interval(),
                    endpoint.max_packet_size(),
                    interface.number(),
                );
            }
        }
    }
}

fn find_feedback_endpoint(
    descriptor: &rusb::InterfaceDescriptor,
    feedback_address: u8,
    sync_type: SyncType,
    speed: Speed,
) -> Option<AndroidUsbFeedbackEndpoint> {
    // Only the selected alt is active. Dawn Pro repeats 0x81 in alts 1..4;
    // walking sibling alts made that valid feedback endpoint look ambiguous.
    let endpoints = descriptor
        .endpoint_descriptors()
        .map(|endpoint| FeedbackEndpointCandidate {
            alt_setting: descriptor.setting_number(),
            address: endpoint.address(),
            transfer_type: endpoint.transfer_type(),
            usage_type: endpoint.usage_type(),
            interval: endpoint.interval(),
            max_packet_size: endpoint.max_packet_size(),
        });
    let endpoint = match select_explicit_feedback_endpoint(
        descriptor.setting_number(),
        feedback_address,
        sync_type,
        endpoints,
    ) {
        Ok(endpoint) => endpoint?,
        Err(addresses) => {
            dev_eprintln!(
                "[USB] Async endpoint has {} feedback IN candidates ({:02x?}) on interface {} alt {}; refusing ambiguous feedback selection",
                addresses.len(),
                addresses,
                descriptor.interface_number(),
                descriptor.setting_number(),
            );
            return None;
        }
    };

    let feedback = AndroidUsbFeedbackEndpoint {
        address: endpoint.address,
        transfer_type: endpoint.transfer_type,
        interval: endpoint.interval,
        service_interval_us: service_interval_micros(speed, endpoint.interval),
        max_packet_bytes: effective_iso_packet_bytes(endpoint.max_packet_size, speed),
    };
    let resolution = if feedback_address != 0 && endpoint.address == feedback_address {
        "bSynchAddress"
    } else {
        "UAC2 feedback usage"
    };
    dev_eprintln!(
        "[USB] Feedback endpoint resolved from {}: 0x{:02x} {} interval={} service={}us on interface {} alt {}",
        resolution,
        feedback.address,
        transfer_type_label(feedback.transfer_type),
        feedback.interval,
        feedback.service_interval_us,
        descriptor.interface_number(),
        descriptor.setting_number(),
    );
    Some(feedback)
}

fn validate_android_usb_claims(
    claimed_handle: &AndroidDirectUsbClaimedHandle,
    config_descriptor: &ConfigDescriptor,
) -> Result<(), String> {
    let mut required = HashSet::new();
    let mut has_control = false;
    let mut has_playback = false;
    for interface in config_descriptor.interfaces() {
        for descriptor in interface.descriptors() {
            if descriptor.class_code() != USB_CLASS_AUDIO {
                continue;
            }
            match descriptor.sub_class_code() {
                USB_SUBCLASS_AUDIOCONTROL => {
                    required.insert(descriptor.interface_number());
                    has_control = true;
                }
                USB_SUBCLASS_AUDIOSTREAMING
                    if descriptor.endpoint_descriptors().any(|endpoint| {
                        endpoint.direction() == Direction::Out
                            && endpoint.transfer_type() == TransferType::Isochronous
                    }) =>
                {
                    required.insert(descriptor.interface_number());
                    has_playback = true;
                }
                _ => {}
            }
        }
    }
    if !has_control || !has_playback {
        return Err("USB configuration is missing audio control or playback interfaces".to_string());
    }
    let claimed: HashSet<_> = claimed_handle.claimed_interfaces.iter().copied().collect();
    if claimed != required || claimed.len() != claimed_handle.claimed_interfaces.len() {
        return Err(format!(
            "Android USB claims {:?} don't match required audio control/playback interfaces {:?}",
            claimed_handle.claimed_interfaces, required
        ));
    }
    for interface_number in claimed_handle.claimed_interfaces.iter() {
        dev_eprintln!(
            "Android USB direct claimed interface {} (now {:?})",
            interface_number,
            claimed_handle.claimed_interfaces
        );
    }
    Ok(())
}

/// Find the clock entity that feeds a specific streaming interface's terminal.
///
/// UAC2 topology: AudioStreaming AS_GENERAL.bTerminalLink → Terminal.bTerminalID,
/// then Terminal.bCSourceID gives the Clock Entity ID.
///
/// If `terminal_link` is None or the trace fails, falls back to the first
/// Clock Source found in the AudioControl descriptor.
fn find_audio_control_clock(
    device: &Device<Context>,
    handle: &DeviceHandle<Context>,
    terminal_link: Option<u8>,
) -> Option<AudioControlClock> {
    let config_descriptor = device.active_config_descriptor().ok()?;

    for interface in config_descriptor.interfaces() {
        for descriptor in interface.descriptors() {
            if descriptor.class_code() != USB_CLASS_AUDIO
                || descriptor.sub_class_code() != USB_SUBCLASS_AUDIOCONTROL
            {
                continue;
            }

            let extra = descriptor.extra();
            dev_eprintln!(
                "[USB] AudioControl interface {} alt {} extra bytes: {} bytes",
                descriptor.interface_number(),
                descriptor.setting_number(),
                extra.len(),
            );

            if extra.is_empty() {
                dev_eprintln!(
                    "[USB] AudioControl interface {} has empty extra bytes; \
                     attempting raw GET_DESCRIPTOR fallback",
                    descriptor.interface_number(),
                );
                if let Some(clock) = find_clock_from_raw_config_descriptor(
                    handle,
                    &config_descriptor,
                    descriptor.interface_number(),
                ) {
                    return Some(clock);
                }
                continue;
            }

            // Pass 1: build maps of terminal_id → clock_source_id and
            // collect all clock source IDs.
            let mut terminal_to_clock: Vec<(u8, u8)> = Vec::new();
            let mut clock_source_ids: Vec<(u8, u8)> = Vec::new(); // (clock_id, ac_iface)
            let ac_iface = descriptor.interface_number();

            let mut index = 0usize;
            while index + 2 < extra.len() {
                let length = extra[index] as usize;
                if length == 0 || index + length > extra.len() {
                    break;
                }
                let desc_type = extra[index + 1];
                let desc_subtype = extra.get(index + 2).copied().unwrap_or_default();

                if desc_type == USB_DT_CS_INTERFACE {
                    match desc_subtype {
                        UAC2_INPUT_TERMINAL | UAC2_OUTPUT_TERMINAL if length >= 8 => {
                            let terminal_id = extra[index + 3];
                            let c_source_id = extra[index + 7];
                            dev_eprintln!(
                                "[USB] Terminal id={} subtype={} -> bCSourceID={}",
                                terminal_id,
                                if desc_subtype == UAC2_INPUT_TERMINAL {
                                    "IN"
                                } else {
                                    "OUT"
                                },
                                c_source_id,
                            );
                            terminal_to_clock.push((terminal_id, c_source_id));
                        }
                        UAC2_CLOCK_SOURCE if length >= 4 => {
                            let clock_id = extra[index + 3];
                            dev_eprintln!(
                                "[USB] Clock Source id={} on AC interface {}",
                                clock_id, ac_iface,
                            );
                            clock_source_ids.push((clock_id, ac_iface));
                        }
                        _ => {}
                    }
                }
                index += length;
            }

            // Pass 2: resolve via topology if terminal_link is known.
            if let Some(tl) = terminal_link {
                if let Some(&(_, c_source_id)) =
                    terminal_to_clock.iter().find(|(tid, _)| *tid == tl)
                {
                    // Verify this c_source_id is actually a clock source.
                    if clock_source_ids.iter().any(|(cid, _)| *cid == c_source_id) {
                        dev_eprintln!(
                            "[USB] Clock resolved via topology: bTerminalLink={} -> bCSourceID={} on AC interface {}",
                            tl, c_source_id, ac_iface,
                        );
                        return Some(AudioControlClock {
                            interface_number: ac_iface,
                            clock_id: c_source_id,
                        });
                    }
                    dev_eprintln!(
                        "[USB] Terminal {} references bCSourceID={} but no matching Clock Source entity found; falling back",
                        tl, c_source_id,
                    );
                } else {
                    dev_eprintln!(
                        "[USB] bTerminalLink={} not found in AC descriptor terminals; falling back to first clock",
                        tl,
                    );
                }
            }

            // Fallback: return the first Clock Source entity.
            if let Some(&(clock_id, iface)) = clock_source_ids.first() {
                dev_eprintln!(
                    "[USB] Using first Clock Source id={} on AC interface {} (fallback)",
                    clock_id, iface,
                );
                return Some(AudioControlClock {
                    interface_number: iface,
                    clock_id,
                });
            }
        }
    }

    dev_eprintln!("[USB] No AudioControl clock source entity found in any interface descriptor");
    None
}

fn find_clock_from_raw_config_descriptor(
    handle: &DeviceHandle<Context>,
    config_descriptor: &ConfigDescriptor,
    ac_interface_number: u8,
) -> Option<AudioControlClock> {
    let config_value = config_descriptor.number();
    let mut raw = vec![0u8; 1024];
    let request_type: u8 = 0x80;
    let descriptor_type_config: u8 = 0x02;
    let read = handle
        .read_control(
            request_type,
            0x06,
            (descriptor_type_config as u16) << 8 | config_value as u16,
            0,
            &mut raw,
            Duration::from_secs(1),
        )
        .ok()?;

    if read < 4 {
        log::error!(
            "[USB] Raw GET_DESCRIPTOR returned only {} bytes; cannot parse config descriptor",
            read,
        );
        return None;
    }
    let total_length = u16::from_le_bytes([raw[2], raw[3]]) as usize;
    if total_length > read {
        let mut full_raw = vec![0u8; total_length];
        match handle.read_control(
            request_type,
            0x06,
            (descriptor_type_config as u16) << 8 | config_value as u16,
            0,
            &mut full_raw,
            Duration::from_secs(1),
        ) {
            Ok(n) => {
                raw = full_raw;
                raw.truncate(n);
            }
            Err(error) => {
                log::error!(
                    "[USB] Raw GET_DESCRIPTOR full read failed: {}; using partial {} bytes",
                    error,
                    read,
                );
                raw.truncate(read);
            }
        }
    } else {
        raw.truncate(read);
    }

    log::info!(
        "[USB] Raw config descriptor: {} bytes for config {}",
        raw.len(),
        config_value,
    );
    parse_clock_from_raw_config(&raw, ac_interface_number)
}

fn parse_clock_from_raw_config(raw: &[u8], ac_interface_number: u8) -> Option<AudioControlClock> {
    let mut pos = 0usize;
    let mut inside_ac_interface = false;

    while pos + 1 < raw.len() {
        let b_length = raw[pos] as usize;
        if b_length < 2 || pos + b_length > raw.len() {
            break;
        }
        let b_descriptor_type = raw[pos + 1];

        if b_descriptor_type == 0x04 && b_length >= 9 {
            let iface_num = raw[pos + 2];
            let iface_class = raw[pos + 5];
            let iface_subclass = raw[pos + 6];
            inside_ac_interface = iface_num == ac_interface_number
                && iface_class == USB_CLASS_AUDIO
                && iface_subclass == USB_SUBCLASS_AUDIOCONTROL;
        }

        if inside_ac_interface
            && b_descriptor_type == USB_DT_CS_INTERFACE
            && b_length >= 4
            && raw.get(pos + 2).copied() == Some(UAC2_CLOCK_SOURCE)
        {
            let clock_id = raw[pos + 3];
            log::info!(
                "[USB] Found clock source via raw config descriptor: interface={} clockId={}",
                ac_interface_number,
                clock_id,
            );
            return Some(AudioControlClock {
                interface_number: ac_interface_number,
                clock_id,
            });
        }

        pos += b_length;
    }

    log::error!(
        "[USB] Raw config descriptor fallback did not find a clock source for interface {}",
        ac_interface_number,
    );
    None
}

fn set_sampling_frequency(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    clock_id: u8,
    sample_rate: u32,
) -> Result<(), String> {
    let request_type = USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = UAC2_CLOCK_SOURCE_SAM_FREQ_CONTROL;
    let index = (interface_number as u16) | ((clock_id as u16) << 8);
    let data = sample_rate.to_le_bytes();
    handle
        .write_control(
            request_type,
            UAC2_REQUEST_SET_CUR,
            value,
            index,
            &data,
            Duration::from_secs(1),
        )
        .map_err(|error| format!("Failed to set sampling frequency: {}", error))?;
    Ok(())
}

fn set_uac1_sampling_frequency(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    endpoint_address: u8,
    sample_rate: u32,
) -> Result<(), String> {
    let data = [
        (sample_rate & 0xFF) as u8,
        ((sample_rate >> 8) & 0xFF) as u8,
        ((sample_rate >> 16) & 0xFF) as u8,
    ];

    // UAC1 5.2.3.2.3.2: SAM_FREQ_CONTROL SET_CUR is an endpoint request
    // (bmRequestType 0x22, wValue 0x0100, 3-byte LE rate). Real hardware
    // disagrees on wIndex: the spec form is (interface << 8) | endpoint, but
    // Linux snd-usb-audio sends the endpoint address alone, and some legacy
    // firmware only accepts the interface-recipient hybrid. A control STALL
    // is auto-cleared before the next SETUP, so failing forms can be tried
    // in sequence. Some devices (FiiO BR13) STALL every form while the
    // streaming alt setting is inactive — the stream-open path retries after
    // the alt setting is live.
    let encodings: [(u8, u16, &str); 3] = [
        (
            USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_ENDPOINT,
            endpoint_address as u16,
            "endpoint-only (Linux)",
        ),
        (
            USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_ENDPOINT,
            ((interface_number as u16) << 8) | endpoint_address as u16,
            "endpoint+interface (spec)",
        ),
        (
            USB_DIR_OUT | USB_TYPE_CLASS | USB_RECIP_INTERFACE,
            endpoint_address as u16,
            "interface-recipient (legacy)",
        ),
    ];

    let mut last_error = String::new();
    for (request_type, index, label) in encodings {
        match handle.write_control(
            request_type,
            UAC2_REQUEST_SET_CUR,
            UAC1_SAM_FREQ_CONTROL,
            index,
            &data,
            Duration::from_secs(1),
        ) {
            Ok(_) => {
                dev_eprintln!(
                    "[USB] UAC1 SET_CUR: endpoint=0x{:02x} rate={}Hz accepted wIndex=0x{:04x} ({})",
                    endpoint_address,
                    sample_rate,
                    index,
                    label
                );
                return Ok(());
            }
            Err(error) => {
                dev_eprintln!(
                    "[USB] UAC1 SET_CUR wIndex=0x{:04x} ({}) stalled: {}",
                    index,
                    label,
                    error
                );
                last_error = format!("Failed to set UAC1 sampling frequency: {}", error);
            }
        }
    }
    Err(last_error)
}

fn get_uac1_sampling_frequency(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    endpoint_address: u8,
) -> Result<u32, String> {
    let mut data = [0u8; 3];
    let encodings: [(u8, u16, &str); 2] = [
        (
            USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_ENDPOINT,
            endpoint_address as u16,
            "endpoint-only (Linux)",
        ),
        (
            USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_ENDPOINT,
            ((interface_number as u16) << 8) | endpoint_address as u16,
            "endpoint+interface (spec)",
        ),
    ];

    let mut last_error = String::new();
    for (request_type, index, label) in encodings {
        match handle.read_control(
            request_type,
            UAC1_REQUEST_GET_CUR,
            UAC1_SAM_FREQ_CONTROL,
            index,
            &mut data,
            Duration::from_secs(1),
        ) {
            Ok(transferred) if transferred == data.len() => {
                let rate = u32::from_le_bytes([data[0], data[1], data[2], 0]);
                dev_eprintln!(
                    "[USB] UAC1 GET_CUR: endpoint=0x{:02x} reports {}Hz via wIndex=0x{:04x} ({})",
                    endpoint_address,
                    rate,
                    index,
                    label
                );
                return Ok(rate);
            }
            Ok(transferred) => {
                last_error = format!(
                    "GET_CUR returned {} bytes, expected 3 (wIndex=0x{:04x}, {})",
                    transferred, index, label
                );
            }
            Err(error) => {
                dev_eprintln!(
                    "[USB] UAC1 GET_CUR wIndex=0x{:04x} ({}) failed: {}",
                    index,
                    label,
                    error
                );
                last_error = format!("Failed to read UAC1 sampling frequency: {}", error);
            }
        }
    }
    Err(last_error)
}

fn get_sampling_frequency(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    clock_id: u8,
) -> Result<u32, String> {
    let request_type = USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = UAC2_CLOCK_SOURCE_SAM_FREQ_CONTROL;
    let index = (interface_number as u16) | ((clock_id as u16) << 8);
    let mut data = [0u8; 4];
    let transferred = handle
        .read_control(
            request_type,
            UAC2_REQUEST_GET_CUR,
            value,
            index,
            &mut data,
            Duration::from_secs(1),
        )
        .map_err(|error| format!("Failed to read sampling frequency: {}", error))?;
    if transferred != data.len() {
        return Err(format!(
            "Sampling-frequency read returned {} bytes, expected {}",
            transferred,
            data.len()
        ));
    }
    Ok(u32::from_le_bytes(data))
}

/// UAC2 Clock Validity Control (CS_CLOCK_VALID_CONTROL = 0x02).
/// Returns Ok(true) if the clock is valid/stable, Ok(false) if invalid,
/// or Err if the request is not supported.
fn get_clock_validity(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    clock_id: u8,
) -> Result<bool, String> {
    let request_type = USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = UAC2_CLOCK_SOURCE_CLOCK_VALID_CONTROL;
    let index = (interface_number as u16) | ((clock_id as u16) << 8);
    let mut data = [0u8; 1];
    let transferred = handle
        .read_control(
            request_type,
            UAC2_REQUEST_GET_CUR,
            value,
            index,
            &mut data,
            Duration::from_millis(500),
        )
        .map_err(|error| format!("Clock Validity GET_CUR failed: {}", error))?;
    if transferred != 1 {
        return Err(format!(
            "Clock Validity returned {} bytes, expected 1",
            transferred
        ));
    }
    Ok(data[0] != 0)
}

fn get_sampling_frequency_ranges(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    clock_id: u8,
) -> Result<Vec<SamplingFrequencySubrange>, String> {
    let request_type = USB_DIR_IN | USB_TYPE_CLASS | USB_RECIP_INTERFACE;
    let value = UAC2_CLOCK_SOURCE_SAM_FREQ_CONTROL;
    let index = (interface_number as u16) | ((clock_id as u16) << 8);
    let mut data = [0u8; 512];
    let transferred = handle
        .read_control(
            request_type,
            UAC2_REQUEST_GET_RANGE,
            value,
            index,
            &mut data,
            Duration::from_secs(1),
        )
        .map_err(|error| format!("Failed to read sampling-frequency range: {}", error))?;
    if transferred < 2 {
        return Err(format!(
            "Sampling-frequency GET_RANGE returned {} bytes, expected at least 2",
            transferred
        ));
    }

    let count = u16::from_le_bytes([data[0], data[1]]) as usize;
    if count == 0 {
        return Err("Sampling-frequency GET_RANGE returned zero subranges".to_string());
    }

    let expected = 2 + count * 12;
    if transferred < expected {
        return Err(format!(
            "Sampling-frequency GET_RANGE returned {} bytes, expected at least {} for {} subranges",
            transferred, expected, count
        ));
    }

    let mut ranges = Vec::with_capacity(count);
    for index in 0..count {
        let offset = 2 + index * 12;
        ranges.push(SamplingFrequencySubrange {
            min: u32::from_le_bytes([
                data[offset],
                data[offset + 1],
                data[offset + 2],
                data[offset + 3],
            ]),
            max: u32::from_le_bytes([
                data[offset + 4],
                data[offset + 5],
                data[offset + 6],
                data[offset + 7],
            ]),
            res: u32::from_le_bytes([
                data[offset + 8],
                data[offset + 9],
                data[offset + 10],
                data[offset + 11],
            ]),
        });
    }

    Ok(ranges)
}

fn discover_stream_sample_rate_ranges(
    device: &Device<Context>,
    handle: &DeviceHandle<Context>,
    streaming_interface_number: u8,
    terminal_link: Option<u8>,
    pre_parsed_ranges: &[SamplingFrequencySubrange],
) -> Vec<SamplingFrequencySubrange> {
    if !pre_parsed_ranges.is_empty() {
        return pre_parsed_ranges.to_vec();
    }

    let Some(clock) = find_audio_control_clock(device, handle, terminal_link) else {
        return Vec::new();
    };

    match get_sampling_frequency_ranges(handle, clock.interface_number, clock.clock_id) {
        Ok(ranges) => ranges,
        Err(error) => {
            dev_eprintln!(
                "[USB] GET_RANGE probe failed for streaming interface {} via clock {} on AC interface {}: {}",
                streaming_interface_number,
                clock.clock_id,
                clock.interface_number,
                error,
            );
            Vec::new()
        }
    }
}

fn representative_sample_rates_from_ranges(ranges: &[SamplingFrequencySubrange]) -> Vec<u32> {
    const COMMON_SAMPLE_RATES: &[u32] = &[
        8_000, 11_025, 16_000, 22_050, 24_000, 32_000, 44_100, 48_000, 64_000, 88_200, 96_000,
        176_400, 192_000, 352_800, 384_000, 705_600, 768_000,
    ];

    let mut sample_rates = Vec::new();

    for &rate in COMMON_SAMPLE_RATES {
        if sampling_frequency_ranges_support_rate(ranges, rate) {
            sample_rates.push(rate);
        }
    }

    for range in ranges {
        sample_rates.push(range.min);
        if range.max != range.min {
            sample_rates.push(range.max);
        }
    }

    sample_rates.sort_unstable();
    sample_rates.dedup();
    sample_rates
}

fn sampling_frequency_ranges_support_rate(
    ranges: &[SamplingFrequencySubrange],
    sample_rate: u32,
) -> bool {
    ranges.iter().any(|range| {
        if range.res == 0 {
            range.min == sample_rate && range.max == sample_rate
        } else {
            sample_rate >= range.min
                && sample_rate <= range.max
                && (sample_rate - range.min) % range.res == 0
        }
    })
}

fn format_sampling_frequency_ranges(ranges: &[SamplingFrequencySubrange]) -> String {
    ranges
        .iter()
        .map(|range| {
            if range.res == 0 || range.min == range.max {
                format!("{} Hz", range.min)
            } else {
                format!("{}..{} Hz step {}", range.min, range.max, range.res)
            }
        })
        .collect::<Vec<_>>()
        .join(", ")
}

fn apply_sampling_frequency(
    handle: &DeviceHandle<Context>,
    interface_number: u8,
    clock_id: u8,
    sample_rate: u32,
    settle_delay_ms: u64,
) -> AndroidDirectUsbClockApplyOutcome {
    log::info!(
        "[USB] apply_sampling_frequency: interface={} clockId={} targetRate={}Hz settleDelay={}ms",
        interface_number,
        clock_id,
        sample_rate,
        settle_delay_ms,
    );

    let supported_ranges = get_sampling_frequency_ranges(handle, interface_number, clock_id).ok();
    match &supported_ranges {
        Some(ranges) => {
            log::info!(
                "[USB] GET_RANGE: {} range(s) from clock {} on interface {}",
                ranges.len(),
                clock_id,
                interface_number,
            );
        }
        None => {
            log::warn!(
                "[USB] GET_RANGE: failed for clock {} on interface {}",
                clock_id,
                interface_number,
            );
        }
    }

    if let Some(ranges) = supported_ranges.as_ref() {
        if !sampling_frequency_ranges_support_rate(ranges, sample_rate) {
            return AndroidDirectUsbClockApplyOutcome {
                clock_ok: false,
                rate_verified: false,
                reported_sample_rate: get_sampling_frequency(handle, interface_number, clock_id).ok(),
                known_mismatch: true,
                set_cur_succeeded: false,
                message: Some(format!(
                    "Requested {} Hz is not supported by clock {} on interface {}; supported rates: {}",
                    sample_rate,
                    clock_id,
                    interface_number,
                    format_sampling_frequency_ranges(ranges),
                )),
            };
        }
    }

    // Read current rate for diagnostics, but NEVER trust it as proof
    // that the clock is correct. Always issue SET_CUR unconditionally
    // because the DAC may report a stale rate or may have been
    // reprogrammed by another app / alt-setting change.
    match get_sampling_frequency(handle, interface_number, clock_id) {
        Ok(current_rate) => {
            dev_eprintln!(
                "[USB] GET_CUR (pre-SET): clock {} on interface {} reports {}Hz (target={}Hz)",
                clock_id, interface_number, current_rate, sample_rate,
            );
        }
        Err(error) => {
            dev_eprintln!(
                "[USB] GET_CUR (pre-SET): failed for clock {} on interface {}: {}",
                clock_id, interface_number, error,
            );
        }
    }

    let mut last_set_error = None;
    let mut last_readback_error = None;
    let mut last_reported_rate = None;
    let mut set_cur_succeeded = false;

    for attempt in 1..=3 {
        log::info!(
            "[USB] SET_CUR attempt {}/3: clock {} interface {} rate {}Hz",
            attempt,
            clock_id,
            interface_number,
            sample_rate,
        );
        match set_sampling_frequency(handle, interface_number, clock_id, sample_rate) {
            Ok(()) => {
                log::info!("[USB] SET_CUR attempt {}/3: succeeded", attempt);
                set_cur_succeeded = true;
            }
            Err(error) => {
                log::error!("[USB] SET_CUR attempt {}/3: failed: {}", attempt, error);
                last_set_error = Some(error);
                thread::sleep(Duration::from_millis(settle_delay_ms));
                continue;
            }
        }

        thread::sleep(Duration::from_millis(settle_delay_ms));
        match get_sampling_frequency(handle, interface_number, clock_id) {
            Ok(reported_sample_rate) => {
                last_reported_rate = Some(reported_sample_rate);
                if reported_sample_rate == sample_rate {
                    // Rate verified — also check clock validity if supported.
                    let clock_valid = match get_clock_validity(handle, interface_number, clock_id) {
                        Ok(valid) => {
                            dev_eprintln!(
                                "[USB] Clock Validity: clock {} valid={} (after SET_CUR {}Hz)",
                                clock_id, valid, sample_rate,
                            );
                            Some(valid)
                        }
                        Err(e) => {
                            dev_eprintln!(
                                "[USB] Clock Validity: not supported for clock {} ({}); assuming valid",
                                clock_id, e,
                            );
                            None
                        }
                    };
                    if clock_valid == Some(false) {
                        dev_eprintln!(
                            "[USB] Clock {} reports INVALID after SET_CUR {}Hz; retrying",
                            clock_id, sample_rate,
                        );
                        thread::sleep(Duration::from_millis(settle_delay_ms));
                        continue;
                    }
                    dev_eprintln!(
                        "[USB] SET_CUR verified: {} Hz on clock {} interface {} after attempt {}",
                        sample_rate, clock_id, interface_number, attempt,
                    );
                    return AndroidDirectUsbClockApplyOutcome {
                        clock_ok: true,
                        rate_verified: true,
                        reported_sample_rate: Some(reported_sample_rate),
                        known_mismatch: false,
                        set_cur_succeeded,
                        message: None,
                    };
                }
            }
            Err(error) => {
                last_readback_error = Some(error);
                continue;
            }
        }
    }

    if let Some(mut reported_sample_rate) = last_reported_rate {
        // Some DACs (e.g. Fosi DS2 / Savitech bridge) report 0 Hz via GET_CUR
        // even after a successful SET_CUR. Replace the bogus 0 with the
        // requested rate so it doesn't poison downstream code paths.
        if reported_sample_rate == 0 {
            dev_eprintln!(
                "[USB] DAC reports 0 Hz after SET_CUR on clock {} / interface {}; falling back to requested {} Hz",
                clock_id, interface_number, sample_rate
            );
            reported_sample_rate = sample_rate;
        }
        return AndroidDirectUsbClockApplyOutcome {
            clock_ok: false,
            rate_verified: false,
            reported_sample_rate: Some(reported_sample_rate),
            known_mismatch: true,
            set_cur_succeeded,
            message: Some(format!(
                "Requested {} Hz, DAC reports {} Hz after SET_CUR on clock {} / interface {}",
                sample_rate, reported_sample_rate, clock_id, interface_number
            )),
        };
    }

    AndroidDirectUsbClockApplyOutcome {
        clock_ok: false,
        rate_verified: false,
        reported_sample_rate: None,
        known_mismatch: false,
        set_cur_succeeded,
        message: Some(format!(
            "Failed to set USB clock {} on interface {} to {} Hz{}{}",
            clock_id,
            interface_number,
            sample_rate,
            last_set_error
                .as_ref()
                .map(|error| format!(": {}", error))
                .unwrap_or_default(),
            last_readback_error
                .as_ref()
                .map(|error| format!("; readback failed: {}", error))
                .unwrap_or_default(),
        )),
    }
}

fn effective_iso_packet_bytes(raw_max_packet_size: u16, speed: Speed) -> usize {
    let base_bytes = (raw_max_packet_size & 0x07ff) as usize;
    let transactions = match speed {
        Speed::High | Speed::Super | Speed::SuperPlus => {
            1 + ((raw_max_packet_size >> 11) & 0x03) as usize
        }
        _ => 1,
    };
    base_bytes.saturating_mul(transactions)
}

fn service_interval_micros(speed: Speed, interval: u8) -> u32 {
    let exponent = interval.saturating_sub(1).min(15) as u32;
    let multiplier = 1u32 << exponent;
    match speed {
        Speed::High | Speed::Super | Speed::SuperPlus => 125u32.saturating_mul(multiplier),
        _ => 1_000u32.saturating_mul(multiplier),
    }
}

fn resolve_device_speed(device: &Device<Context>) -> Speed {
    let speed = device.speed();
    if speed != Speed::Unknown {
        return speed;
    }
    let bus = device.bus_number();
    let addr = device.address();
    if let Some(inferred) = infer_speed_from_sysfs(bus, addr) {
        dev_eprintln!(
            "[USB] libusb reported Unknown speed; inferred {:?} from sysfs (bus={}, addr={})",
            inferred, bus, addr
        );
        return inferred;
    }
    dev_eprintln!(
        "[USB] speed unknown: libusb=Unknown, sysfs lookup failed (bus={}, addr={})",
        bus,
        addr
    );
    Speed::Unknown
}

fn infer_speed_from_sysfs(bus: u8, addr: u8) -> Option<Speed> {
    let entries = std::fs::read_dir("/sys/bus/usb/devices").ok()?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name = name.to_string_lossy();
        // Skip interface entries ("1-2:1.0") — only devices have speed/busnum/devnum
        if name.contains(':') {
            continue;
        }
        let dir = entry.path();
        let busnum = std::fs::read_to_string(dir.join("busnum"))
            .ok()
            .and_then(|s| s.trim().parse::<u32>().ok());
        let devnum = std::fs::read_to_string(dir.join("devnum"))
            .ok()
            .and_then(|s| s.trim().parse::<u32>().ok());
        if busnum == Some(bus as u32) && devnum == Some(addr as u32) {
            let raw = std::fs::read_to_string(dir.join("speed")).ok()?;
            return parse_sysfs_speed(raw.trim());
        }
    }
    None
}

fn parse_sysfs_speed(raw: &str) -> Option<Speed> {
    // kernel writes Mbps as integer or "1.5" for low-speed
    let mbps: u32 = if let Ok(v) = raw.parse::<u32>() {
        v
    } else if let Some(dot) = raw.find('.') {
        raw[..dot].parse::<u32>().ok()?
    } else {
        return None;
    };
    match mbps {
        1 | 2 => Some(Speed::Low),
        12 => Some(Speed::Full),
        480 => Some(Speed::High),
        5000 => Some(Speed::Super),
        10000 | 20000 | 24000 => Some(Speed::SuperPlus),
        _ => None,
    }
}

fn infer_high_speed_from_sample_rates(
    ranges: &[SamplingFrequencySubrange],
) -> Option<Speed> {
    let max_rate = ranges.iter().map(|r| r.max).max().unwrap_or(0);
    if max_rate > 48_000 {
        dev_eprintln!(
            "[USB] libusb speed Unknown; inferred high-speed from advertised sample rates (max={}>48000Hz)",
            max_rate
        );
        Some(Speed::High)
    } else {
        dev_eprintln!(
            "[USB] speed remains Unknown; max advertised rate={} (<=48kHz, no high-speed inference)",
            max_rate
        );
        None
    }
}

fn required_max_packet_bytes(
    sample_rate: u32,
    service_interval_us: u32,
    bytes_per_frame: usize,
) -> usize {
    let max_frames = ((sample_rate as u64 * service_interval_us as u64) + 999_999) / 1_000_000;
    max_frames as usize * bytes_per_frame
}

fn bytes_per_sample(bit_depth: u8) -> Option<usize> {
    match bit_depth {
        16 => Some(2),
        24 => Some(3),
        32 => Some(4),
        _ => None,
    }
}

fn parse_android_streaming_interface_format(
    descriptor: &rusb::InterfaceDescriptor,
) -> Option<AndroidStreamingInterfaceFormat> {
    let mut channels = None;
    let mut format_tag = None;
    let mut subslot_size = None;
    let mut bit_resolution = None;
    let mut terminal_link = None;
    let mut sample_rate_ranges = Vec::new();

    let is_uac1 = descriptor.protocol_code() != 0x20;

    for extra in DescriptorIter::new(descriptor.extra()) {
        if extra.len() < 3 || extra[1] != USB_DT_CS_INTERFACE {
            continue;
        }

        match extra[2] {
            UAC2_AS_GENERAL => {
                if extra.len() >= 4 {
                    terminal_link = Some(extra[3]);
                }
                if is_uac1 {
                    if extra.len() >= 7 {
                        format_tag = Some(u16::from_le_bytes([extra[5], extra[6]]));
                    }
                } else if extra.len() >= 16 {
                    channels = Some(extra[10] as u16);
                    format_tag =
                        Some(u32::from_le_bytes([extra[6], extra[7], extra[8], extra[9]]) as u16);
                } else if extra.len() >= 7 {
                    format_tag = Some(u16::from_le_bytes([extra[5], extra[6]]));
                }
            }
            UAC2_FORMAT_TYPE if extra.get(3).copied() == Some(UAC2_FORMAT_TYPE_I) => {
                if is_uac1 {
                    if extra.len() >= 8 {
                        channels = Some(extra[4] as u16);
                        subslot_size = Some(extra[5]);
                        bit_resolution = Some(extra[6]);
                        let sam_freq_type = extra[7];
                        if sam_freq_type == 0 {
                            if extra.len() >= 14 {
                                let min = u32::from_le_bytes([extra[8], extra[9], extra[10], 0]);
                                let max = u32::from_le_bytes([extra[11], extra[12], extra[13], 0]);
                                sample_rate_ranges.push(SamplingFrequencySubrange {
                                    min,
                                    max,
                                    res: 0,
                                });
                            }
                        } else {
                            for i in 0..sam_freq_type as usize {
                                let offset = 8 + i * 3;
                                if offset + 3 <= extra.len() {
                                    let rate = u32::from_le_bytes([
                                        extra[offset],
                                        extra[offset + 1],
                                        extra[offset + 2],
                                        0,
                                    ]);
                                    sample_rate_ranges.push(SamplingFrequencySubrange {
                                        min: rate,
                                        max: rate,
                                        res: 0,
                                    });
                                }
                            }
                        }
                    }
                } else if extra.len() >= 6 {
                    subslot_size = Some(extra[4]);
                    bit_resolution = Some(extra[5]);
                }
            }
            _ => {}
        }
    }

    let format_tag = format_tag?;

    let is_dsd_format = format_tag == FORMAT_TAG_DSD;

    let subslot_size = if is_dsd_format {
        subslot_size.unwrap_or(4)
    } else {
        subslot_size?
    };
    let bit_resolution = if is_dsd_format {
        bit_resolution.unwrap_or(1)
    } else {
        bit_resolution?
    };

    Some(AndroidStreamingInterfaceFormat {
        format_tag,
        channels: channels.unwrap_or(2),
        subslot_size,
        bit_resolution,
        terminal_link,
        is_uac1,
        sample_rate_ranges,
    })
}

fn transport_compatibility_penalty(
    stream_format: &AndroidStreamingInterfaceFormat,
    playback_format: AndroidDirectUsbPlaybackFormat,
) -> u32 {
    let is_native_dsd = playback_format.dsd_transport == DsdTransportMode::Native;
    let fmt_ok = stream_format.format_tag == FORMAT_TAG_PCM
        || (is_native_dsd && stream_format.format_tag == FORMAT_TAG_DSD);
    if !fmt_ok {
        return u32::MAX;
    }
    if stream_format.subslot_size == 0 || stream_format.channels == 0 {
        return u32::MAX;
    }
    if stream_format.channels != playback_format.channels {
        return u32::MAX;
    }
    if !is_native_dsd {
        let Some(min_subslot_size) = bytes_per_sample(playback_format.bit_depth) else {
            return u32::MAX;
        };
        if stream_format.bit_resolution != playback_format.bit_depth {
            return u32::MAX;
        }
        if stream_format.subslot_size < min_subslot_size as u8 {
            return u32::MAX;
        }

        let container_bits = u32::from(stream_format.subslot_size) * 8;
        if u32::from(stream_format.bit_resolution) > container_bits {
            return u32::MAX;
        }

        u32::from(stream_format.subslot_size) - min_subslot_size as u32
    } else {
        let container_bits = u32::from(stream_format.subslot_size) * 8;
        if u32::from(stream_format.bit_resolution) > container_bits {
            return u32::MAX;
        }
        0
    }
}

fn transport_compatibility_penalty_for_candidate(
    candidate: &AndroidIsoStreamCandidate,
    playback_format: AndroidDirectUsbPlaybackFormat,
) -> u32 {
    transport_compatibility_penalty(
        &AndroidStreamingInterfaceFormat {
            format_tag: candidate.format_tag,
            channels: candidate.channels,
            subslot_size: candidate.subslot_size,
            bit_resolution: candidate.bit_resolution,
            terminal_link: candidate.terminal_link,
            is_uac1: candidate.is_uac1,
            sample_rate_ranges: vec![],
        },
        playback_format,
    )
}

fn format_tag_label(format_tag: u16) -> &'static str {
    match format_tag {
        FORMAT_TAG_PCM => "PCM",
        FORMAT_TAG_PCM8 => "PCM8",
        FORMAT_TAG_IEEE_FLOAT => "IEEE_FLOAT",
        FORMAT_TAG_DSD => "DSD",
        _ => "OTHER",
    }
}

fn sync_type_label(sync_type: SyncType) -> &'static str {
    match sync_type {
        SyncType::Adaptive => "adaptive",
        SyncType::Asynchronous => "asynchronous",
        SyncType::Synchronous => "synchronous",
        SyncType::NoSync => "none",
    }
}

// A failed UAC1 SET_CUR is only tolerable when the endpoint is host-paced
// (adaptive/synchronous). Asynchronous runs its own clock; NoSync free-runs
// (FiiO BR13) — either way the DAC rate stays unknown and direct streaming
// would be pitched wrong.
fn uac1_set_cur_failure_tolerable(sync_type: SyncType) -> bool {
    matches!(sync_type, SyncType::Adaptive | SyncType::Synchronous)
}

fn usage_type_label(usage_type: UsageType) -> &'static str {
    match usage_type {
        UsageType::Data => "data",
        UsageType::Feedback => "feedback",
        UsageType::FeedbackData => "feedback-data",
        UsageType::Reserved => "reserved",
    }
}

fn transfer_type_label(transfer_type: TransferType) -> &'static str {
    match transfer_type {
        TransferType::Control => "control",
        TransferType::Isochronous => "isochronous",
        TransferType::Bulk => "bulk",
        TransferType::Interrupt => "interrupt",
    }
}

fn validate_transport_against_playback_format(
    candidate: &AndroidIsoStreamCandidate,
    playback_format: AndroidDirectUsbPlaybackFormat,
) -> Result<(), String> {
    let is_native_dsd = playback_format.dsd_transport == DsdTransportMode::Native;
    if candidate.format_tag != FORMAT_TAG_PCM
        && !(is_native_dsd && candidate.format_tag == FORMAT_TAG_DSD)
    {
        return Err(format!(
            "Android USB direct requires PCM transport, got {}",
            format_tag_label(candidate.format_tag)
        ));
    }
    if candidate.channels != playback_format.channels {
        return Err(format!(
            "Android USB direct requires {} channels, got {}",
            playback_format.channels, candidate.channels
        ));
    }
    if !is_native_dsd {
        if candidate.bit_resolution != playback_format.bit_depth {
            return Err(format!(
                "Android USB direct requires {}-bit transport, got {}",
                playback_format.bit_depth, candidate.bit_resolution
            ));
        }
        let Some(min_subslot_size) = bytes_per_sample(playback_format.bit_depth) else {
            return Err(format!(
                "Android USB direct does not support {}-bit sample packing",
                playback_format.bit_depth
            ));
        };
        if candidate.subslot_size < min_subslot_size as u8 {
            return Err(format!(
            "Android USB direct requires at least {} bytes per subslot for {}-bit transport, got {}",
            min_subslot_size, playback_format.bit_depth, candidate.subslot_size
        ));
        }
    }
    Ok(())
}

/// Apply the current master gain before quantizing queued PCM to linear i32.
/// This also covers a volume change during pause, without touching raw DSD.
fn apply_usb_pcm_gain(samples: &mut [i32], callback_data: &AudioCallbackData) {
    let gain = callback_data.get_gain();
    let mut peak = 0.0f32;
    let mut clipped = 0;
    let mut non_finite = 0;
    for bits in samples {
        let sample = f32::from_bits(*bits as u32) * gain;
        if sample.is_finite() {
            peak = peak.max(sample.abs());
            clipped += u64::from(sample.abs() > 1.0);
        } else {
            non_finite += 1;
        }
        *bits = (f64::from(sample.clamp(-1.0, 1.0)) * f64::from(i32::MAX)) as i32;
    }
    callback_data.note_output_peak(peak, clipped, non_finite);
}

/// Map linear PCM `i32` to 16-bit samples for USB.
///
/// Uses the top 16 bits (arithmetic shift), matching UAC2-style downscale from
/// a 32-bit linear container and avoiding a float round-trip.
#[inline]
fn linear_pcm_i32_to_i16(sample: i32) -> i16 {
    (sample >> 16) as i16
}

/// 24-bit packed little-endian (3 bytes per channel), from linear full-scale i32.
#[inline]
fn encode_i24(sample: i32) -> [u8; 3] {
    let s = sample >> 8;
    [
        (s & 0xFF) as u8,
        ((s >> 8) & 0xFF) as u8,
        ((s >> 16) & 0xFF) as u8,
    ]
}

#[inline]
fn encode_i32_le(sample: i32) -> [u8; 4] {
    sample.to_le_bytes()
}

/// Pack PCM / DoP / native DSD for the active UAC subslot.
///
/// PCM and DoP: each i32 encodes `subslot_size` wire bytes.
/// Native DSD: each i32 carries one DSD byte; `subslot_size` consecutive
/// same-channel bytes are packed into each wire word (1:1 byte count).
fn encode_usb_pcm_slots(
    input: &[i32],
    output: &mut [u8],
    subslot_size: u8,
    bit_resolution: u8,
    dsd_transport: DsdTransportMode,
    channels: u16,
    big_endian: bool,
    bit_reverse: bool,
) -> Result<(), String> {
    let ss = subslot_size as usize;
    if ss == 0 {
        return Err("subslot_size is zero".to_string());
    }

    if dsd_transport == DsdTransportMode::Native {
        let ch = channels as usize;
        if ch == 0 {
            return Err("channels is zero".to_string());
        }
        if output.len() != input.len() {
            return Err(format!(
                "USB native DSD buffer length mismatch: output {} bytes, expected {} (1:1 with {} samples)",
                output.len(),
                input.len(),
                input.len()
            ));
        }
        if ss == 1 {
            for (i, &sample) in input.iter().enumerate() {
                let b = (sample & 0xFF) as u8;
                output[i] = if bit_reverse { b.reverse_bits() } else { b };
            }
        } else {
            let chunk_samples = ss * ch;
            let num_chunks = input.len() / chunk_samples;
            for chunk in 0..num_chunks {
                let in_base = chunk * chunk_samples;
                let out_base = chunk * chunk_samples;
                for chan in 0..ch {
                    for b in 0..ss {
                        let in_idx = in_base + chan + b * ch;
                        let raw = (input[in_idx] & 0xFF) as u8;
                        let dsd_byte = if bit_reverse { raw.reverse_bits() } else { raw };
                        let out_b = if big_endian { b } else { ss - 1 - b };
                        let out_idx = out_base + chan * ss + out_b;
                        output[out_idx] = dsd_byte;
                    }
                }
            }
        }
        return Ok(());
    }

    let expected = input.len().checked_mul(ss).ok_or_else(|| {
        format!(
            "USB PCM sample count overflow: {} samples × {} subslot",
            input.len(),
            ss
        )
    })?;
    if output.len() != expected {
        return Err(format!(
            "USB PCM buffer length mismatch: output {} bytes, expected {} ({} samples × {} subslot)",
            output.len(),
            expected,
            input.len(),
            ss
        ));
    }

    match dsd_transport {
        DsdTransportMode::DoP => {
            encode_dop_slots(input, output, subslot_size, bit_resolution);
            return Ok(());
        }
        DsdTransportMode::Native => unreachable!("handled above"),
        DsdTransportMode::None => {}
    }

    match subslot_size {
        2 => {
            if bit_resolution == 16 {
                encode_pcm_i16_le(input, output);
            } else {
                encode_pcm_bytes(input, output, subslot_size, bit_resolution);
            }
            Ok(())
        }
        3 => {
            for (index, sample) in input.iter().enumerate() {
                let slot = encode_i24(*sample);
                let offset = index * 3;
                output[offset..offset + 3].copy_from_slice(&slot);
            }
            Ok(())
        }
        4 => {
            if bit_resolution >= 32 {
                for (index, &sample) in input.iter().enumerate() {
                    let offset = index * 4;
                    output[offset..offset + 4].copy_from_slice(&encode_i32_le(sample));
                }
            } else {
                let unused: u32 = 32u32.saturating_sub(bit_resolution as u32);
                let mask = !((1u32.wrapping_shl(unused)).wrapping_sub(1) as i32);
                for (index, &sample) in input.iter().enumerate() {
                    let offset = index * 4;
                    let packed = (sample & mask).to_le_bytes();
                    output[offset..offset + 4].copy_from_slice(&packed);
                }
            }
            Ok(())
        }
        _ => {
            encode_pcm_bytes(input, output, subslot_size, bit_resolution);
            Ok(())
        }
    }
}

/// DoP frames arrive 32-bit left-justified (marker in bits 31:24, 16 data bits
/// in 23:8, low byte zero) — the same canonical word the DAP I32 path uses.
/// Emit the top `subslot_size` bytes little-endian so the marker stays the
/// most-significant wire byte, where the DAC scans for 0x05/0xFA.
fn encode_dop_slots(input: &[i32], output: &mut [u8], subslot_size: u8, _bit_resolution: u8) {
    let ss = subslot_size as usize;
    for (index, &sample) in input.iter().enumerate() {
        let w = sample as u32;
        let offset = index * ss;
        for b in 0..ss {
            let shift = 8 * (4usize.saturating_sub(ss) + b);
            output[offset + b] = if shift < 32 { (w >> shift) as u8 } else { 0 };
        }
    }
}

/// 16-bit PCM: linear i32 → i16 (MSB extract) → LE.
fn encode_pcm_i16_le(input: &[i32], output: &mut [u8]) {
    debug_assert_eq!(output.len(), input.len() * 2);
    for (i, &sample) in input.iter().enumerate() {
        let i16_val = linear_pcm_i32_to_i16(sample);
        let bytes = i16_val.to_le_bytes();
        output[i * 2] = bytes[0];
        output[i * 2 + 1] = bytes[1];
    }
}

/// Pack i32 PCM samples into the USB subslot byte layout.
///
/// UAC2 Data Formats spec: PCM is signed two's complement, left-justified
/// (sign bit is the MSB of the container). Unused LSBs are zero-padded.
///
/// When `subslot_size * 8 > bit_resolution`, the sample is shifted left
/// so that the sign bit occupies the MSB of the container.
fn encode_pcm_bytes(input: &[i32], output: &mut [u8], subslot_size: u8, bit_resolution: u8) {
    let subslot_bytes = usize::from(subslot_size);
    debug_assert_eq!(output.len(), input.len() * subslot_bytes);

    let container_bits = (subslot_size as u32) * 8;
    let right_shift = 32u32.saturating_sub(bit_resolution as u32);
    let left_shift = container_bits.saturating_sub(bit_resolution as u32);

    for (index, &sample) in input.iter().enumerate() {
        let offset = index * subslot_bytes;
        let kept = if right_shift == 0 {
            sample
        } else {
            sample >> right_shift
        };
        let padded = if left_shift == 0 {
            kept
        } else {
            kept << left_shift
        };
        let bytes = padded.to_le_bytes();
        for byte_index in 0..subslot_bytes {
            output[offset + byte_index] = bytes[byte_index];
        }
    }
}

fn log_stream_debug_preview(
    playback_format: AndroidDirectUsbPlaybackFormat,
    candidate: &AndroidIsoStreamCandidate,
    packet_bytes: &[usize],
    packet_samples: &[i32],
    transfer_buffer: &[u8],
) {
    let frames_per_packet: Vec<usize> = packet_bytes
        .iter()
        .map(|packet| packet / (candidate.subslot_size as usize * candidate.channels as usize))
        .collect();
    let sample_preview: Vec<i32> = packet_samples.iter().take(10).copied().collect();
    let byte_decoded_preview: Vec<i32> = transfer_buffer
        .chunks_exact(candidate.subslot_size as usize)
        .take(10)
        .map(|chunk| {
            let mut bytes = [0u8; 4];
            for (index, byte) in chunk.iter().enumerate() {
                bytes[index] = *byte;
            }
            if candidate.subslot_size < 4 && chunk.last().copied().unwrap_or_default() & 0x80 != 0 {
                for byte in bytes.iter_mut().skip(candidate.subslot_size as usize) {
                    *byte = 0xff;
                }
            }
            i32::from_le_bytes(bytes)
        })
        .collect();
    let first_bytes_preview: Vec<String> = transfer_buffer
        .iter()
        .take(32)
        .map(|byte| format!("{:02x}", byte))
        .collect();

    log_info!(
        "[USB] Stream start engineOutput=f32@{}Hz transport={} {}-bit {}ch {}-byte-subslot interface={} alt={} endpoint=0x{:02x} sync={} usage={} refresh={} synchAddress=0x{:02x} endpointMaxPacket={} feedback={} packetSizes={:?} framesPerPacket={:?}",
        playback_format.sample_rate,
        format_tag_label(candidate.format_tag),
        candidate.bit_resolution,
        candidate.channels,
        candidate.subslot_size,
        candidate.interface_number,
        candidate.alt_setting,
        candidate.endpoint_address,
        sync_type_label(candidate.sync_type),
        usage_type_label(candidate.usage_type),
        candidate.refresh,
        candidate.synch_address,
        candidate.max_packet_bytes,
        candidate
            .feedback_endpoint
            .map(|feedback| format!(
                "0x{:02x}/{}@interval{}",
                feedback.address,
                transfer_type_label(feedback.transfer_type),
                feedback.interval,
            ))
            .unwrap_or_else(|| "none".to_string()),
        packet_bytes,
        frames_per_packet,
    );
    log_info!("[USB] PCM sample preview (i32): {:?}", sample_preview);
    log_info!(
        "[USB] byte-decoded preview (i32 from LE bytes): {:?}",
        byte_decoded_preview
    );
    log_info!("[USB] first 32 transfer bytes: {:?}", first_bytes_preview);
}

fn panic_payload_message(payload: &(dyn std::any::Any + Send)) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "unknown panic".to_string()
    }
}

extern "system" fn iso_transfer_callback(transfer: *mut libusb_transfer) {
    // Panicking across the FFI boundary aborts the process, so contain every
    // panic here; a poisoned lock must not kill the app either.
    let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let Some(transfer) = std::ptr::NonNull::new(transfer) else {
            return;
        };
        let user_data_ptr = unsafe { transfer.as_ref().user_data as *mut IsoTransferUserData };
        let Some(user_data) = std::ptr::NonNull::new(user_data_ptr) else {
            return;
        };

        let completed_at = Instant::now();
        let status = unsafe { transfer.as_ref().status };
        let actual_length = unsafe { transfer.as_ref().actual_length } as usize;
        // Keep the completion state alive independently of the transfer/user
        // data so the output thread can re-arm or free the slot as soon as the
        // status is published.
        let completion = unsafe { user_data.as_ref() }.completion.clone();
        completion
            .actual_length
            .store(actual_length, Ordering::Release);
        match completion.completed_at.lock() {
            Ok(mut guard) => *guard = Some(completed_at),
            Err(poisoned) => *poisoned.into_inner() = Some(completed_at),
        }
        // Publish status last. Everything above is mine; after this store the
        // slot owner may refill or release the transfer without racing this
        // callback, because the callback no longer touches either object.
        let mut guard = match completion.status.lock() {
            Ok(guard) => guard,
            Err(poisoned) => poisoned.into_inner(),
        };
        *guard = Some(status);
    }));
}

#[allow(dead_code)]
fn submit_iso_transfer(
    context: &Context,
    handle: &DeviceHandle<Context>,
    endpoint: u8,
    packet_sizes: &[usize],
    buffer: Vec<u8>,
) -> Result<(), String> {
    let completion = Arc::new(IsoTransferCompletion::new());
    let user_data = Box::new(IsoTransferUserData { completion, buffer });
    let user_data_ptr = Box::into_raw(user_data);
    let transfer = unsafe { libusb_alloc_transfer(packet_sizes.len() as i32) };
    let callback: libusb_transfer_cb_fn = iso_transfer_callback;

    let Some(mut transfer_ptr) = std::ptr::NonNull::new(transfer) else {
        unsafe {
            drop(Box::from_raw(user_data_ptr));
        }
        return Err("libusb_alloc_transfer returned null".to_string());
    };

    unsafe {
        libusb_fill_iso_transfer(
            transfer_ptr.as_mut(),
            handle.as_raw(),
            endpoint,
            (*user_data_ptr).buffer.as_mut_ptr(),
            (*user_data_ptr).buffer.len() as i32,
            packet_sizes.len() as i32,
            callback,
            user_data_ptr as *mut c_void,
            ISO_TRANSFER_TIMEOUT_MS,
        );

        for (index, packet_size) in packet_sizes.iter().enumerate() {
            (*transfer_ptr
                .as_mut()
                .iso_packet_desc
                .as_mut_ptr()
                .add(index))
            .length = *packet_size as u32;
        }

        let submit_result = libusb_submit_transfer(transfer_ptr.as_ptr());
        if submit_result != 0 {
            libusb_free_transfer(transfer_ptr.as_ptr());
            drop(Box::from_raw(user_data_ptr));
            return Err(format!(
                "libusb_submit_transfer failed with code {}",
                submit_result
            ));
        }
    }

    let completion = unsafe { &(*user_data_ptr).completion };
    let status = loop {
        let pending_status = match completion.status.lock() {
            Ok(guard) => *guard,
            Err(poisoned) => *poisoned.into_inner(),
        };
        if let Some(status) = pending_status {
            break status;
        }

        context
            .handle_events(Some(Duration::from_millis(50)))
            .map_err(|error| format!("libusb_handle_events failed: {}", error))?;
    };

    let packet_validation = unsafe {
        let transfer_ref = transfer_ptr.as_ref();
        iso_packet_descriptors(transfer_ref, packet_sizes.len())
            .and_then(|descriptors| validate_iso_packet_descriptors(packet_sizes, descriptors))
    };

    unsafe {
        libusb_free_transfer(transfer_ptr.as_ptr());
        drop(Box::from_raw(user_data_ptr));
    }

    match status {
        LIBUSB_TRANSFER_COMPLETED => packet_validation,
        LIBUSB_TRANSFER_TIMED_OUT => Err("isochronous transfer timed out".to_string()),
        LIBUSB_TRANSFER_STALL => Err("isochronous transfer stalled".to_string()),
        LIBUSB_TRANSFER_NO_DEVICE => Err("USB DAC disconnected".to_string()),
        LIBUSB_TRANSFER_OVERFLOW => Err("isochronous transfer overflow".to_string()),
        LIBUSB_TRANSFER_CANCELLED => Err("isochronous transfer cancelled".to_string()),
        LIBUSB_TRANSFER_ERROR => Err("isochronous transfer failed".to_string()),
        other => Err(format!("isochronous transfer returned status {}", other)),
    }
}

fn read_iso_feedback_packet(
    context: &Context,
    handle: &DeviceHandle<Context>,
    feedback_endpoint: AndroidUsbFeedbackEndpoint,
) -> Result<Option<Vec<u8>>, String> {
    let completion = Arc::new(IsoTransferCompletion::new());
    let buffer = vec![0u8; feedback_endpoint.max_packet_bytes.max(4)];
    let user_data = Box::new(IsoTransferUserData { completion, buffer });
    let user_data_ptr = Box::into_raw(user_data);
    let transfer = unsafe { libusb_alloc_transfer(1) };
    let callback: libusb_transfer_cb_fn = iso_transfer_callback;

    let Some(mut transfer_ptr) = std::ptr::NonNull::new(transfer) else {
        unsafe {
            drop(Box::from_raw(user_data_ptr));
        }
        return Err("libusb_alloc_transfer returned null for feedback transfer".to_string());
    };

    unsafe {
        libusb_fill_iso_transfer(
            transfer_ptr.as_mut(),
            handle.as_raw(),
            feedback_endpoint.address,
            (*user_data_ptr).buffer.as_mut_ptr(),
            (*user_data_ptr).buffer.len() as i32,
            1,
            callback,
            user_data_ptr as *mut c_void,
            ANDROID_USB_FEEDBACK_TIMEOUT_MS,
        );

        (*transfer_ptr.as_mut().iso_packet_desc.as_mut_ptr()).length =
            (*user_data_ptr).buffer.len() as u32;

        let submit_result = libusb_submit_transfer(transfer_ptr.as_ptr());
        if submit_result != 0 {
            libusb_free_transfer(transfer_ptr.as_ptr());
            drop(Box::from_raw(user_data_ptr));
            return Err(format!(
                "libusb_submit_transfer failed for feedback endpoint 0x{:02x} with code {}",
                feedback_endpoint.address, submit_result
            ));
        }
    }

    let completion = unsafe { &(*user_data_ptr).completion };
    const MAX_FEEDBACK_POLL_ITERATIONS: usize = 5;
    let status = {
        let mut iterations = 0usize;
        loop {
            if let Some(status) = *completion.status.lock().unwrap() {
                break status;
            }
            if iterations >= MAX_FEEDBACK_POLL_ITERATIONS {
                unsafe { libusb_cancel_transfer(transfer_ptr.as_ptr()) };
                for _ in 0..MAX_FEEDBACK_POLL_ITERATIONS {
                    if (*completion.status.lock().unwrap()).is_some() {
                        break;
                    }
                    let _ = context.handle_events(Some(Duration::from_millis(10)));
                }
                unsafe {
                    libusb_free_transfer(transfer_ptr.as_ptr());
                    drop(Box::from_raw(user_data_ptr));
                }
                return Ok(None);
            }
            iterations += 1;
            context
                .handle_events(Some(Duration::from_millis(10)))
                .map_err(|error| format!("libusb_handle_events failed: {}", error))?;
        }
    };

    let (actual_length, data) = unsafe {
        let transfer_ref = transfer_ptr.as_ref();
        let actual_length = (*transfer_ref.iso_packet_desc.as_ptr()).actual_length as usize;
        let buffer = &(*user_data_ptr).buffer;
        let data = buffer[..actual_length.min(buffer.len())].to_vec();
        (actual_length, data)
    };

    unsafe {
        libusb_free_transfer(transfer_ptr.as_ptr());
        drop(Box::from_raw(user_data_ptr));
    }

    match status {
        LIBUSB_TRANSFER_COMPLETED if actual_length > 0 => Ok(Some(data)),
        LIBUSB_TRANSFER_COMPLETED => Ok(None),
        LIBUSB_TRANSFER_TIMED_OUT => Ok(None),
        LIBUSB_TRANSFER_CANCELLED => Ok(None),
        LIBUSB_TRANSFER_STALL => Err("isochronous feedback transfer stalled".to_string()),
        LIBUSB_TRANSFER_NO_DEVICE => Err("USB DAC disconnected".to_string()),
        LIBUSB_TRANSFER_OVERFLOW => Err("isochronous feedback transfer overflow".to_string()),
        LIBUSB_TRANSFER_ERROR => Err("isochronous feedback transfer failed".to_string()),
        other => Err(format!(
            "isochronous feedback transfer returned status {}",
            other
        )),
    }
}

fn iso_packet_descriptors(
    transfer: &libusb_transfer,
    allocated_packet_count: usize,
) -> Result<&[libusb_iso_packet_descriptor], String> {
    if transfer.num_iso_packets != allocated_packet_count as i32 {
        return Err(format!(
            "isochronous transfer completed with packet errors: \
             packet count changed: requested={}, transfer={}",
            allocated_packet_count, transfer.num_iso_packets,
        ));
    }

    // Both callers allocated exactly this many descriptors and call
    // this only after completion, before resubmitting or freeing the transfer.
    Ok(unsafe {
        std::slice::from_raw_parts(transfer.iso_packet_desc.as_ptr(), allocated_packet_count)
    })
}

#[cfg(test)]
mod dsd_bitperfect_tests {
    use super::*;

    // Native DSD_U32: input is byte-interleaved [c0_b0, c1_b0, c0_b1, c1_b1, ...].
    // c0 bytes = 10,11,12,13 ; c1 bytes = 20,21,22,23.
    const NATIVE_IN: [i32; 8] = [10, 20, 11, 21, 12, 22, 13, 23];

    #[test]
    fn native_dsd_u32_big_endian_groups_channels() {
        let mut out = [0u8; 8];
        encode_usb_pcm_slots(
            &NATIVE_IN, &mut out, 4, 1, DsdTransportMode::Native, 2, true, false,
        )
        .unwrap();
        // BE: each channel word is b0(MSB)..b3(LSB), channel 0 then channel 1.
        assert_eq!(out, [10, 11, 12, 13, 20, 21, 22, 23]);
    }

    #[test]
    fn native_dsd_u32_little_endian_reverses_byte_order() {
        let mut out = [0u8; 8];
        encode_usb_pcm_slots(
            &NATIVE_IN, &mut out, 4, 1, DsdTransportMode::Native, 2, false, false,
        )
        .unwrap();
        assert_eq!(out, [13, 12, 11, 10, 23, 22, 21, 20]);
    }

    #[test]
    fn native_dsd_bit_reverse_flips_each_byte() {
        let mut out = [0u8; 8];
        encode_usb_pcm_slots(
            &NATIVE_IN, &mut out, 4, 1, DsdTransportMode::Native, 2, true, true,
        )
        .unwrap();
        let bytes: [u8; 8] = [10, 11, 12, 13, 20, 21, 22, 23];
        let expect: Vec<u8> = bytes.iter().map(|b| b.reverse_bits()).collect();
        assert_eq!(out.to_vec(), expect);
    }

    #[test]
    fn native_dsd_u8_passes_low_byte() {
        let input = [0x100u32 as i32, 0x205u32 as i32];
        let mut out = [0u8; 2];
        encode_usb_pcm_slots(
            &input, &mut out, 1, 1, DsdTransportMode::Native, 2, false, false,
        )
        .unwrap();
        assert_eq!(out, [0x00, 0x05]);
    }

    #[test]
    fn dop_word_32bit_emits_marker_in_msb() {
        // marker 0x05 in bits 31:24, dsd0=0x11 @16, dsd1=0x22 @8, low byte 0.
        let w = (0x05u32 << 24) | (0x11 << 16) | (0x22 << 8);
        let mut out = [0u8; 4];
        encode_dop_slots(&[w as i32], &mut out, 4, 32);
        assert_eq!(out, [0x00, 0x22, 0x11, 0x05]);
    }

    #[test]
    fn dop_word_24bit_emits_three_bytes_marker_last() {
        let w = (0xFAu32 << 24) | (0x11 << 16) | (0x22 << 8);
        let mut out = [0u8; 3];
        encode_dop_slots(&[w as i32], &mut out, 3, 24);
        assert_eq!(out, [0x22, 0x11, 0xFA]);
    }

    #[test]
    fn unified_quirk_db_resolves_dsd_fields() {
        // Dawn Pro is in both the legacy table and the unified DB; resolution
        // must surface big_endian + subslot 4 from either source.
        let q = resolve_dsd_quirk(12230, 61546, "MOONDROP Dawn Pro").unwrap();
        assert!(q.big_endian);
        assert_eq!(q.preferred_subslot, 4);
        assert!(!q.bit_reverse);
    }

    #[test]
    fn unknown_device_has_no_dsd_quirk() {
        assert!(resolve_dsd_quirk(0x0001, 0x0002, "Mystery DAC").is_none());
    }

    #[test]
    fn audit_dop_valid_alternating_markers() {
        // ss=4 stereo: marker is the last byte of each 4-byte word; channel-0
        // words (L0,L1) alternate 0x05 -> 0xFA.
        let buf: [u8; 16] = [
            0xAA, 0xAA, 0xAA, 0x05, // L0
            0xAA, 0xAA, 0xAA, 0x05, // R0
            0xAA, 0xAA, 0xAA, 0xFA, // L1
            0xAA, 0xAA, 0xAA, 0xFA, // R1
        ];
        assert!(audit_dsd_payload(&buf, DsdTransportMode::DoP, 4, 2));
    }

    #[test]
    fn audit_dop_rejects_bad_marker_byte() {
        let buf: [u8; 8] = [0xAA, 0xAA, 0xAA, 0x05, 0xAA, 0xAA, 0xAA, 0x00];
        assert!(!audit_dsd_payload(&buf, DsdTransportMode::DoP, 4, 2));
    }

    #[test]
    fn dop_ring_preserves_phase_through_starvation_and_resume() {
        let mut ring = AndroidDirectUsbPcmRingBuffer::new(9, 2);
        assert_eq!(ring.capacity_samples % 2, 0);
        assert_eq!(ring.push_samples(&[0xfa112200u32 as i32, 0xfa334400u32 as i32]), 2);
        let mut first = [0i32; 6];
        assert!(ring.pop_into_or_pad(&mut first, 2, DsdTransportMode::DoP));
        assert_eq!(first.map(|s| s as u32), [
            0x05112200, 0x05334400, 0xfa696900, 0xfa696900, 0x05696900, 0x05696900,
        ]);
        assert_eq!(ring.push_samples(&[0x05556600, 0x05778800, 99]), 2);
        let mut resumed = [0i32; 2];
        assert!(!ring.pop_into_or_pad(&mut resumed, 2, DsdTransportMode::DoP));
        assert_eq!(resumed.map(|s| s as u32), [0xfa556600, 0xfa778800]);
    }

    #[test]
    fn dop_audit_rejects_disagreeing_channel_markers() {
        let payload = [0, 0, 0x05, 0, 0, 0xFA, 0, 0, 0xFA, 0, 0, 0x05];
        assert!(!audit_dsd_payload(&payload, DsdTransportMode::DoP, 3, 2));
    }

    #[test]
    fn audit_dop_rejects_non_alternating_or_short() {
        // two channel-0 words with identical marker -> no alternation
        let flat: [u8; 16] = [
            0xAA, 0xAA, 0xAA, 0x05, 0xAA, 0xAA, 0xAA, 0x05, 0xAA, 0xAA, 0xAA, 0x05, 0xAA, 0xAA,
            0xAA, 0x05,
        ];
        assert!(!audit_dsd_payload(&flat, DsdTransportMode::DoP, 4, 2));
        // fewer than 2 words
        assert!(!audit_dsd_payload(&[0, 0, 0, 0x05], DsdTransportMode::DoP, 4, 2));
    }

    #[test]
    fn audit_dop_24bit_marker_in_last_byte() {
        // ss=3: marker at byte[2]. L0=0x05, L1=0xFA (stereo -> 4 words).
        let buf: [u8; 12] = [
            0xAA, 0xAA, 0x05, 0xAA, 0xAA, 0x05, 0xAA, 0xAA, 0xFA, 0xAA, 0xAA, 0xFA,
        ];
        assert!(audit_dsd_payload(&buf, DsdTransportMode::DoP, 3, 2));
    }

    #[test]
    fn audit_native_requires_nonzero() {
        assert!(audit_dsd_payload(&[0x00, 0x55, 0x00], DsdTransportMode::Native, 1, 2));
        assert!(!audit_dsd_payload(&[0, 0, 0, 0], DsdTransportMode::Native, 1, 2));
        assert!(!audit_dsd_payload(&[], DsdTransportMode::Native, 1, 2));
    }

    #[test]
    fn audit_pcm_accepts_varying_16bit_stereo() {
        // stride = ss(2) * ch(2) = 4; channel-0 words at 0 and 4 differ.
        let buf: [u8; 8] = [
            0x00, 0x00, 0x00, 0x00, // L0 = 0
            0x01, 0x00, 0x00, 0x00, // L1 = 1
        ];
        assert!(audit_pcm_payload(&buf, 2, 2));
    }

    #[test]
    fn audit_pcm_rejects_dead_pipeline_all_zero() {
        let buf = [0u8; 64];
        assert!(!audit_pcm_payload(&buf, 2, 2));
    }

    #[test]
    fn audit_pcm_rejects_stuck_constant_dc() {
        // every 16-bit sample = 0x0100 (DC); channel-0 never varies.
        let buf: [u8; 16] = [
            0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01,
            0x00, 0x01,
        ];
        assert!(!audit_pcm_payload(&buf, 2, 2));
    }

    #[test]
    fn audit_pcm_accepts_24bit_packed_subslot() {
        // ss=3 stereo, stride=6; channel-0 samples differ.
        let buf: [u8; 12] = [
            0x00, 0x00, 0x01, 0x00, 0x00, 0x02, // L0
            0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x03, // L1
        ];
        assert!(audit_pcm_payload(&buf, 3, 2));
    }

    #[test]
    fn audit_pcm_rejects_empty_and_short() {
        assert!(!audit_pcm_payload(&[], 2, 2));
        assert!(!audit_pcm_payload(&[0, 0], 2, 2)); // < 2 frames
        assert!(!audit_pcm_payload(&[1, 2, 3, 4], 0, 2)); // zero subslot
    }

    #[test]
    fn effective_ring_rate_uses_byte_rate_for_native() {
        // DSD64: dsd_bit_rate 2_822_400 -> byte rate 352_800, wire rate 88_200.
        let native = AndroidDirectUsbPlaybackFormat {
            sample_rate: 88_200,
            bit_depth: 1,
            channels: 2,
            is_dop: false,
            dsd_transport: DsdTransportMode::Native,
            dsd_bit_rate: 2_822_400,
        };
        assert_eq!(effective_ring_rate(&native), 352_800);
        let pcm = AndroidDirectUsbPlaybackFormat {
            sample_rate: 96_000,
            bit_depth: 24,
            channels: 2,
            is_dop: false,
            dsd_transport: DsdTransportMode::None,
            dsd_bit_rate: 0,
        };
        assert_eq!(effective_ring_rate(&pcm), 96_000);
    }

    #[test]
    fn feedback_uses_usb_speed_timebase_not_feedback_poll_interval() {
        // UAC2 high-speed feedback is samples per microframe. A report of 44.1
        // at a 125 us data service interval is 352.8 kHz, regardless of whether
        // the feedback endpoint itself is polled every 1 ms.
        let raw = (44.1f64 * 65_536.0).round() as u32;
        let (frames_per_packet, estimated_rate) =
            decode_feedback_report(&raw.to_le_bytes(), 125, Speed::High).unwrap();
        assert!((frames_per_packet - 44.1).abs() < 0.000_1);
        assert!((estimated_rate - 352_800.0).abs() < 0.01);
    }

    #[test]
    fn feedback_full_speed_uses_one_millisecond_timebase() {
        let raw = (48.0f64 * 16_384.0) as u32;
        let bytes = [raw as u8, (raw >> 8) as u8, (raw >> 16) as u8];
        let (frames_per_packet, estimated_rate) =
            decode_feedback_report(&bytes, 1_000, Speed::Full).unwrap();
        assert!((frames_per_packet - 48.0).abs() < 0.001);
        assert!((estimated_rate - 48_000.0).abs() < 0.01);
    }

    #[test]
    fn feedback_q10_14_uses_high_speed_timebase() {
        // 10.14 feedback is still samples per microframe on a high-speed link.
        let raw = (44.1f64 * 16_384.0).round() as u32;
        let bytes = [raw as u8, (raw >> 8) as u8, (raw >> 16) as u8];
        let (frames_per_packet, estimated_rate) =
            decode_feedback_report(&bytes, 125, Speed::High).unwrap();
        assert!((frames_per_packet - 44.1).abs() < 0.000_1);
        assert!((estimated_rate - 352_800.0).abs() < 0.01);
    }
}

#[cfg(test)]
static PCM_AUDIT_TEST_MUTEX: Mutex<()> = Mutex::new(());

#[cfg(test)]
mod transport_loss_tests {
    use super::*;

    fn pcm_format() -> AndroidDirectUsbPlaybackFormat {
        AndroidDirectUsbPlaybackFormat {
            sample_rate: 44_100,
            bit_depth: 16,
            channels: 2,
            is_dop: false,
            dsd_transport: DsdTransportMode::None,
            dsd_bit_rate: 0,
        }
    }

    fn streaming_state(runtime_stats: Arc<AndroidDirectUsbRuntimeStats>) -> AndroidDirectUsbState {
        AndroidDirectUsbState {
            device: AndroidDirectUsbDevice {
                fd: -1,
                _fd_owner: Arc::new(AndroidDirectUsbOwnedFd(-1)),
                vendor_id: 0,
                product_id: 0,
                product_name: "test DAC".to_string(),
                device_name: None,
                claimed_interfaces: Arc::from([]),
            },
            requested_playback_format: Some(pcm_format()),
            playback_format: Some(pcm_format()),
            lock_requested: true,
            stream_active: true,
            active_transport: None,
            capability_model: None,
            clock_status: None,
            clock_control_attempted: true,
            clock_control_succeeded: true,
            clock_verification_passed: true,
            require_verified_rate: true,
            dac_clock_policy: DacClockPolicy::RequireVerifiedRate,
            dac_mode: DacMode::FullControl,
            last_error: None,
            direct_mode_refusal_reason: None,
            usb_stream_stable: false,
            bit_perfect_verified: false,
            software_volume_active: false,
            hardware_volume_control: None,
            hardware_volume_generation: 0,
            hardware_volume_error: None,
            hardware_volume_normalized: None,
            hardware_mute_active: None,
            pending_hardware_volume_restore: None,
            packet_schedule_frames_preview: Vec::new(),
            runtime_stats: Some(runtime_stats),
        }
    }

    /// The PCM wire audit is process-global. Satisfy it so the only thing that
    /// can change `direct_path_is_bit_perfect` in these tests is the latch.
    fn new_stream_stats() -> Arc<AndroidDirectUsbRuntimeStats> {
        USB_PCM_PAYLOAD_LATCH.lock().observe(true, Instant::now());
        Arc::new(AndroidDirectUsbRuntimeStats::new(44_100, 2, 200, 100))
    }

    fn lossy_tracker(lost_frames: u64) -> LossTracker {
        let mut tracker = LossTracker::new(LossLimits {
            max_consecutive_lossy_urbs: ANDROID_USB_MAX_CONSECUTIVE_LOSSY_URBS,
            max_lost_frames: u64::MAX,
        });
        tracker.record(
            44,
            UrbLoss {
                lost_frames,
                ..UrbLoss::default()
            },
        );
        tracker
    }

    #[test]
    fn lost_frames_clear_the_bit_perfect_claim_until_a_new_stream() {
        let _guard = PCM_AUDIT_TEST_MUTEX.lock();
        let stats = new_stream_stats();
        let state = streaming_state(Arc::clone(&stats));
        assert!(direct_path_is_bit_perfect(&state));

        publish_transport_loss(&stats, &lossy_tracker(3));
        assert!(stats.transport_unverified());
        assert_eq!(stats.lost_frames.load(Ordering::Relaxed), 3);
        assert!(!direct_path_is_bit_perfect(&state));
        assert_eq!(
            bit_perfect_release_reason(&state),
            "USB transport interrupted or unverified"
        );

        // A new stream gets fresh runtime stats, so it starts unlatched.
        let next_stream = streaming_state(new_stream_stats());
        assert!(direct_path_is_bit_perfect(&next_stream));
    }

    #[test]
    fn a_lossless_tracker_never_latches_the_stream() {
        let _guard = PCM_AUDIT_TEST_MUTEX.lock();
        let stats = new_stream_stats();
        let state = streaming_state(Arc::clone(&stats));
        publish_transport_loss(&stats, &lossy_tracker(0));
        assert!(!stats.transport_unverified());
        assert_eq!(stats.lost_frames.load(Ordering::Relaxed), 0);
        assert!(direct_path_is_bit_perfect(&state));
    }

    #[test]
    fn publish_mirrors_every_counter() {
        let stats = new_stream_stats();
        let mut tracker = LossTracker::new(LossLimits {
            max_consecutive_lossy_urbs: ANDROID_USB_MAX_CONSECUTIVE_LOSSY_URBS,
            max_lost_frames: u64::MAX,
        });
        tracker.record(
            44,
            UrbLoss {
                timed_out: true,
                lost_frames: 44,
                short_packets: 0,
                zero_packets: 0,
            },
        );
        tracker.record(
            44,
            UrbLoss {
                timed_out: false,
                lost_frames: 6,
                short_packets: 2,
                zero_packets: 1,
            },
        );
        publish_transport_loss(&stats, &tracker);
        assert_eq!(stats.lost_frames.load(Ordering::Relaxed), 50);
        assert_eq!(stats.short_packets.load(Ordering::Relaxed), 2);
        assert_eq!(stats.zero_packets.load(Ordering::Relaxed), 1);
        assert_eq!(stats.data_urb_timeouts.load(Ordering::Relaxed), 1);
    }

    #[test]
    fn timeout_invalidates_verification_without_inventing_a_frame_deficit() {
        let _guard = PCM_AUDIT_TEST_MUTEX.lock();
        let stats = new_stream_stats();
        let state = streaming_state(Arc::clone(&stats));
        let mut tracker = lossy_tracker(0);
        tracker.record(
            44,
            UrbLoss {
                timed_out: true,
                ..UrbLoss::default()
            },
        );
        publish_transport_loss(&stats, &tracker);

        assert_eq!(stats.lost_frames.load(Ordering::Relaxed), 0);
        assert_eq!(stats.data_urb_timeouts.load(Ordering::Relaxed), 1);
        assert!(!direct_path_is_bit_perfect(&state));
    }

    #[test]
    fn the_lost_audio_budget_is_about_a_tenth_of_a_second() {
        let frames = lost_frame_budget(44_100, ANDROID_USB_MAX_LOST_AUDIO_MS);
        assert_eq!(frames, 4_410);
        assert_eq!(ANDROID_USB_MAX_CONSECUTIVE_LOSSY_URBS, 3);
    }
}

#[cfg(test)]
mod pcm_ring_hold_tests {
    use super::*;
    use crate::audio::engine::{EngineDsdMode, PipelineMode};
    use crossbeam_channel::bounded;

    fn dop_frame(marker_bits: u32, payload: u32) -> [i32; 2] {
        [(marker_bits << 24 | payload) as i32; 2]
    }

    fn markers(output: &[i32], channels: usize) -> Vec<u32> {
        output
            .chunks_exact(channels)
            .map(|frame| {
                assert!(
                    frame
                        .iter()
                        .all(|s| (*s as u32) >> 24 == (frame[0] as u32) >> 24),
                    "channels of one frame must share a marker: {frame:x?}"
                );
                (frame[0] as u32) >> 24
            })
            .collect()
    }

    #[test]
    fn clear_discards_queued_audio_and_waits_for_a_whole_transfer() {
        let mut ring = AndroidDirectUsbPcmRingBuffer::new(16, 2);
        assert_eq!(ring.push_samples(&[1, 2, 3, 4, 5, 6, 7, 8]), 8);
        ring.observe_flush(1);
        assert_eq!(ring.len_samples(), 0);

        // Nothing to play yet: hold silence instead of reporting an underrun.
        assert!(ring.awaiting_refill(4));
        assert_eq!(ring.push_samples(&[20, 21]), 2);
        assert!(ring.awaiting_refill(4), "half a transfer is not enough");
        assert_eq!(ring.push_samples(&[22, 23]), 2);
        // A second worker observing the same seek must leave its new audio.
        ring.observe_flush(1);
        assert!(!ring.awaiting_refill(4));

        let mut out = [0i32; 4];
        assert!(!ring.pop_into_or_pad(&mut out, 2, DsdTransportMode::None));
        assert_eq!(out, [20, 21, 22, 23], "only post-clear audio is played");

        // The hold is one-shot: a later drain is a genuine underrun again.
        assert!(!ring.awaiting_refill(4));
        assert!(ring.pop_into_or_pad(&mut out, 2, DsdTransportMode::None));
    }

    #[test]
    fn paused_pcm_silence_does_not_consume_the_ring() {
        let mut ring = AndroidDirectUsbPcmRingBuffer::new(16, 2);
        assert_eq!(ring.push_samples(&[1, 2, 3, 4, 5, 6]), 6);

        let mut first = [0i32; 2];
        assert!(!ring.pop_into_or_pad(&mut first, 2, DsdTransportMode::None));
        assert_eq!(first, [1, 2]);

        let mut paused = [9i32; 8];
        ring.fill_wire_silence(&mut paused, DsdTransportMode::None);
        assert_eq!(paused, [0; 8]);
        assert_eq!(ring.len_samples(), 4, "pause must keep the queued audio");

        let mut resumed = [0i32; 4];
        assert!(!ring.pop_into_or_pad(&mut resumed, 2, DsdTransportMode::None));
        assert_eq!(
            resumed,
            [3, 4, 5, 6],
            "nothing lost or repeated across pause"
        );
    }

    #[test]
    fn paused_native_dsd_silence_is_the_idle_pattern_not_dc() {
        let mut ring = AndroidDirectUsbPcmRingBuffer::new(16, 2);
        assert_eq!(ring.push_samples(&[0x11, 0x22]), 2);

        let mut paused = [0i32; 4];
        ring.fill_wire_silence(&mut paused, DsdTransportMode::Native);
        assert_eq!(paused, [0x69; 4]);
        assert_eq!(ring.len_samples(), 2);
    }

    #[test]
    fn dop_markers_alternate_across_paused_and_resumed_pops() {
        let mut ring = AndroidDirectUsbPcmRingBuffer::new(16, 2);
        // Stale marker bits on the queued frames must not leak onto the wire.
        for frame in [
            dop_frame(0xAA, 0x112233),
            dop_frame(0xAA, 0x445566),
            dop_frame(0xAA, 0x778899),
        ] {
            assert_eq!(ring.push_samples(&frame), 2);
        }

        let mut before = [0i32; 2];
        assert!(!ring.pop_into_or_pad(&mut before, 2, DsdTransportMode::DoP));
        let mut paused = [0i32; 6];
        ring.fill_wire_silence(&mut paused, DsdTransportMode::DoP);
        let mut after = [0i32; 4];
        assert!(!ring.pop_into_or_pad(&mut after, 2, DsdTransportMode::DoP));

        let mut wire = Vec::new();
        wire.extend_from_slice(&before);
        wire.extend_from_slice(&paused);
        wire.extend_from_slice(&after);
        assert_eq!(
            markers(&wire, 2),
            [0x05, 0xFA, 0x05, 0xFA, 0x05, 0xFA],
            "one unbroken 05/FA alternation across pause and resume"
        );
        assert_eq!(paused.map(|s| s as u32 & 0x00ff_ffff), [0x696900; 6]);
        assert_eq!(
            after.map(|s| s as u32 & 0x00ff_ffff),
            [0x445566, 0x445566, 0x778899, 0x778899],
            "the retained audio resumes where it stopped"
        );
    }

    #[test]
    fn clear_keeps_the_dop_marker_phase() {
        let mut ring = AndroidDirectUsbPcmRingBuffer::new(16, 2);
        let mut first = [0i32; 2];
        ring.fill_wire_silence(&mut first, DsdTransportMode::DoP);
        assert_eq!(markers(&first, 2), [0x05]);

        ring.observe_flush(1);
        let mut next = [0i32; 4];
        ring.fill_wire_silence(&mut next, DsdTransportMode::DoP);
        assert_eq!(markers(&next, 2), [0xFA, 0x05]);
    }

    fn pcm_candidate() -> AndroidIsoStreamCandidate {
        AndroidIsoStreamCandidate {
            interface_number: 1,
            alt_setting: 1,
            endpoint_address: 0x01,
            endpoint_interval: 1,
            service_interval_us: 125,
            usb_speed: Speed::High,
            max_packet_bytes: 1024,
            sync_type: SyncType::Adaptive,
            usage_type: UsageType::Data,
            format_tag: FORMAT_TAG_PCM,
            channels: 2,
            subslot_size: 2,
            bit_resolution: 16,
            sample_rates: vec![48_000],
            refresh: 0,
            synch_address: 0,
            feedback_endpoint: None,
            terminal_link: None,
            is_uac1: false,
        }
    }

    fn prepare(
        ring: &Arc<Mutex<AndroidDirectUsbPcmRingBuffer>>,
        stats: &AndroidDirectUsbRuntimeStats,
        callback_data: &AudioCallbackData,
    ) -> IsoTransferPayload {
        let candidate = pcm_candidate();
        let mut scheduler = IsoPacketScheduler::new(48_000, 4, candidate.service_interval_us);
        prepare_iso_transfer_payload(
            &mut scheduler,
            ring,
            stats,
            &candidate,
            2,
            2,
            4,
            DsdTransportMode::None,
            false,
            false,
            callback_data,
        )
        .unwrap()
        .unwrap()
    }

    #[test]
    fn held_transfers_are_silent_unconsumed_and_not_underruns() {
        let _guard = PCM_AUDIT_TEST_MUTEX.lock();
        let stats = AndroidDirectUsbRuntimeStats::new(48_000, 2, 200, 100);
        let ring = Arc::new(Mutex::new(AndroidDirectUsbPcmRingBuffer::new(
            stats.buffer_capacity_samples,
            2,
        )));
        let (finished_tx, _finished_rx) = bounded(1);
        let callback_data = AudioCallbackData::new(
            48_000,
            2,
            finished_tx,
            PipelineMode::Passthrough,
            EngineDsdMode::Pcm,
        );
        let music: Vec<i32> = (0..2_000)
            .map(|i| (0.5_f32 + i as f32 / 8_000.0).to_bits() as i32)
            .collect();
        assert_eq!(ring.lock().push_samples(&music), 2_000);
        USB_PCM_PAYLOAD_LATCH.lock().reset();

        callback_data.set_paused(true);
        let paused = prepare(&ring, &stats, &callback_data);
        assert!(!paused.underrun);
        assert!(paused.transfer_buffer.iter().all(|byte| *byte == 0));
        assert_eq!(ring.lock().len_samples(), 2_000, "pause consumes nothing");
        {
            let latch = USB_PCM_PAYLOAD_LATCH.lock();
            assert!(!latch.is_verified());
            assert_eq!(latch.constant_for(Instant::now()), None, "audit untouched");
        }

        // Lower the volume after render. Resume must apply the new gain even
        // to the first sample already queued at the old volume.
        callback_data.set_volume(0.5);
        callback_data.set_paused(false);
        let playing = prepare(&ring, &stats, &callback_data);
        assert!(!playing.underrun);
        assert!(playing.transfer_buffer.iter().any(|byte| *byte != 0));
        let consumed = 2_000 - ring.lock().len_samples();
        assert_eq!(consumed, playing.packet_samples.len());
        assert_eq!(&playing.transfer_buffer[..2], &1638i16.to_le_bytes());
        assert!(USB_PCM_PAYLOAD_LATCH.lock().is_verified());

        // Muting must also affect any queued audio.
        callback_data.set_volume(0.0);
        let muted = prepare(&ring, &stats, &callback_data);
        assert!(!muted.underrun);
        assert!(muted.transfer_buffer.iter().all(|byte| *byte == 0));

        // A drain during playback is still a genuine underrun.
        ring.lock()
            .pop_into_or_pad(&mut vec![0; 4_000], 2, DsdTransportMode::None);
        assert!(prepare(&ring, &stats, &callback_data).underrun);
    }
}
