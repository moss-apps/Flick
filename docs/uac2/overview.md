# UAC 2.0 Overview

Reference for the USB Audio Class 2.0 engine in Flick Player.

> **Status (partial deprecation):** UAC2 routing shifted to Android's native
> USB DAC handling (see `rust/src/uac2/android_direct.rs`). The `pipeline-info`
> and `transfer-stats` widgets were removed. The Rust engine — device
> discovery, descriptor parsing, isochronous transfers — remains the source of
> truth for this document.

## Setup

Enable the feature in `Cargo.toml`:

```toml
[dependencies]
flick_player = { version = "0.1", features = ["uac2"] }
```

Declare USB host in `AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.usb.host" android:required="false" />
<uses-permission android:name="android.permission.USB_PERMISSION" />
```

Initialize the service before `runApp`:

```dart
await Uac2Service.instance.initialize();
```

## System Layers

```
┌─────────────────────────────────────────┐
│         Flutter UI Layer                │
│  (Device Selection, Status Display)     │
└─────────────────┬───────────────────────┘
                  │ FFI Bridge
┌─────────────────▼───────────────────────┐
│      Dart Service Layer                 │
│  (Uac2Service, State Management)        │
└─────────────────┬───────────────────────┘
                  │ flutter_rust_bridge
┌─────────────────▼───────────────────────┐
│       Rust Core Layer                   │
│  (Device, Pipeline, Transfer)           │
└─────────────────┬───────────────────────┘
                  │ rusb
┌─────────────────▼───────────────────────┐
│      USB Hardware Layer                 │
│  (DAC/AMP Devices)                      │
└─────────────────────────────────────────┘
```

Threads: main (UI/state), audio (high-priority processing), USB (async transfers), worker pool (parallel descriptor parsing).

Memory: pre-allocated transfer buffers, lock-free ring buffer, zero-copy where possible, no allocations in the hot path.

## Module Hierarchy

```
rust/src/uac2/
├── mod.rs                      # Module exports and public API
├── device.rs                   # Device representation
├── device_classifier.rs        # Device type classification
├── capabilities.rs             # Device capability extraction
├── endpoint.rs                 # USB endpoint management
├── stream_config.rs            # Stream configuration
├── format_negotiation.rs       # Audio format selection
├── transfer.rs                 # Isochronous transfer management
├── transfer_buffer.rs          # Transfer buffer management
├── audio_pipeline.rs           # Audio processing pipeline
├── audio_sink.rs               # Audio engine integration
├── ring_buffer.rs              # Lock-free ring buffer
├── connection_manager.rs       # Device lifecycle management
├── error.rs                    # Error types
├── error_recovery.rs           # Recovery strategies
├── fallback_handler.rs         # Fallback to default audio
├── logging.rs                  # Logging configuration
├── android_direct.rs           # Native Android USB DAC path (current)
└── tests/
    ├── device_classifier_tests.rs
    ├── capabilities_tests.rs
    ├── stream_config_tests.rs
    ├── control_requests_tests.rs
    ├── transfer_tests.rs
    ├── audio_format_tests.rs
    └── audio_pipeline_tests.rs
```

### Dart Side

```
lib/
├── services/
│   ├── uac2_service.dart            # Main UAC2 service
│   └── uac2_preferences_service.dart # Preferences management
├── providers/
│   └── uac2_provider.dart           # Riverpod providers
├── widgets/uac2/
│   ├── uac2_device_selector.dart    # Device selection widget
│   ├── uac2_status_indicator.dart   # Status display
│   ├── uac2_device_capabilities.dart # Capability display
│   └── uac2_player_status.dart      # Player integration
└── features/settings/screens/
    ├── uac2_settings_screen.dart    # Settings UI
    └── uac2_preferences_screen.dart # Preferences UI
```

### Module Dependencies

```
device.rs
  └─> capabilities.rs
  └─> device_classifier.rs

audio_sink.rs
  └─> audio_pipeline.rs
  └─> transfer.rs
  └─> ring_buffer.rs

transfer.rs
  └─> transfer_buffer.rs
  └─> endpoint.rs

connection_manager.rs
  └─> device.rs
  └─> error_recovery.rs
  └─> fallback_handler.rs
```

## Device Discovery

Discovery enumerates the USB bus and filters by class, subclass, and protocol.

| Field    | Value | Meaning         |
|----------|-------|-----------------|
| Class    | 0x01  | Audio           |
| Subclass | 0x02  | Audio Streaming |
| Protocol | 0x20  | UAC 2.0         |

```rust
pub fn enumerate_devices() -> Result<Vec<Uac2Device>, Uac2Error> {
    // Enumerate all USB devices
    // Filter by UAC 2.0 class/subclass/protocol
    // Parse descriptors
    // Return device list
}
```

`Uac2Device` carries VID, PID, serial, manufacturer, product, and capabilities. `ConnectionManager` (`rust/src/uac2/connection_manager.rs`) maintains the registry: tracks additions/removals, lookup by ID, lifecycle.

### Process

1. Enumerate USB devices, filter by class.
2. Read string descriptors for VID/PID/serial/manufacturer/product.
3. Parse configuration, interface, and endpoint descriptors.
4. Extract supported formats and channel configurations.
5. Register device, notify the application.

### Hot-plug

`monitor_hotplug` registers a callback for arrival and removal. Arrival triggers enumeration and registration. Removal stops active streams, unregisters the device, and activates `FallbackHandler`.

```rust
pub fn monitor_hotplug() -> Result<(), Uac2Error> {
    // Register hotplug callback
    // Handle device arrival
    // Handle device removal
}
```

### Filter Criteria

Devices must be UAC 2.0 protocol, expose an audio streaming interface, expose isochronous endpoints, and support PCM format (minimum).

### Platform Notes

**Android** requires the USB Host API, user-granted USB permission, a `<device-filter>` in `AndroidManifest.xml`, and a permission dialog on connection.

**Linux** requires udev rules for non-root access, uses the libusb backend, and consumes hot-plug events from udev.

## Descriptor Parsing

USB descriptors describe audio interfaces, supported formats, sample rates, bit depths, channel configurations, and control capabilities.

### Standard Descriptors

- **Device descriptor**: VID, PID, device class, USB version.
- **Configuration descriptor**: interface count, power requirements, attributes.
- **Interface descriptor**: class `0x01`, subclass `0x02`, protocol `0x20`, endpoint count.
- **Endpoint descriptor**: address, transfer type (isochronous), max packet size, interval.

### Audio Class Descriptors

- **IAD**: groups Audio Control and Audio Streaming interfaces.
- **Audio Control Header**: UAC version, total length, streaming interface count.
- **Input/Output Terminal**: terminal type, channel config, available controls.
- **Feature Unit**: volume, mute, bass/treble, channel-specific controls.
- **Audio Streaming Interface**: terminal link, format type, controls.
- **Format Type**: format type (Type I PCM, Type II, III), subframe size, bit resolution, supported sample rates.

### Parser Architecture

```rust
pub trait DescriptorParser {
    type Output;
    fn parse(&self, data: &[u8]) -> Result<Self::Output, Uac2Error>;
}
```

- `AudioControlParser` parses the Audio Control interface, extracts terminal and unit info, builds control topology.
- `AudioStreamingParser` parses Audio Streaming interfaces, extracts format info, identifies endpoints.
- `FormatTypeParser` parses Format Type descriptors, extracts sample rates, bit depths, channel counts.

### Process

1. Read configuration descriptor.
2. Parse interface descriptors; locate Audio Control and Audio Streaming interfaces.
3. Parse Audio Control descriptors (header, terminals, units).
4. Parse Audio Streaming descriptors (AS interface, format type).
5. Parse endpoint descriptors (isochronous, packet size, interval).
6. Aggregate into `DeviceCapabilities`.

### Sample Rate Encoding

Format Type descriptors encode rates as either discrete lists or continuous ranges (min/max/resolution).

### Caching

Parsed descriptors cache per device. Cache invalidates on reconnection, avoiding repeated USB traffic.

### Validation

Descriptors validate for correct length fields, valid types, consistent cross-references, supported format types, and valid sample rates. Invalid descriptors raise parsing errors.

```rust
let config_desc = device.active_config_descriptor()?;
let parser = AudioStreamingParser::new();
let formats = parser.parse_formats(&config_desc)?;
let best = formats.iter()
    .max_by_key(|f| f.sample_rate * f.bit_depth);
```

## Data Flow

### Device Connection

```
USB Device Connected
        │
        ▼
┌───────────────────┐
│ Hot-plug Event    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Enumerate Devices │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Filter UAC 2.0    │
│ (Class 0x01)      │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Parse Descriptors │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Extract           │
│ Capabilities      │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Classify Device   │
│ (DAC/AMP/Combo)   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Register Device   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Notify Flutter    │
└───────────────────┘
```

### Audio Streaming

```
Audio Engine
     │
     │ PCM Audio Data
     ▼
┌─────────────────┐
│ Uac2AudioSink   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Format Check    │
│ (Match?)        │
└────┬────┬───────┘
     │    │
  Yes│    │No
     │    │
     │    ▼
     │  ┌─────────────────┐
     │  │ AudioPipeline   │
     │  │ (Convert)       │
     │  └────────┬────────┘
     │           │
     └───────────┘
         │
         ▼
┌─────────────────┐
│ RingBuffer      │
│ (Producer)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ RingBuffer      │
│ (Consumer)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ TransferBuffer  │
│ (Fill)          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Isochronous     │
│ Transfer        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ USB Device      │
│ (DAC/AMP)       │
└─────────────────┘
```

### Control Request

```
User Action (Volume Change)
        │
        ▼
┌───────────────────┐
│ Flutter UI        │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Uac2Service       │
└────────┬──────────┘
         │ FFI Call
         ▼
┌───────────────────┐
│ Rust API          │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Build Control     │
│ Request           │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ USB Control       │
│ Transfer          │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Device Response   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Update State      │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Notify Flutter    │
└───────────────────┘
```

### Error Recovery

```
Transfer Error
     │
     ▼
┌─────────────────┐
│ Error Detection │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Classify Error  │
└────┬────┬───────┘
     │    │
Retry│    │Fatal
     │    │
     │    ▼
     │  ┌─────────────────┐
     │  │ Fallback        │
     │  │ Handler         │
     │  └────────┬────────┘
     │           │
     │           ▼
     │         ┌─────────────────┐
     │         │ Switch to       │
     │         │ Default Audio   │
     │         └────────┬────────┘
     │                  │
     │                  ▼
     │                ┌─────────────────┐
     │                │ Notify User     │
     │                └─────────────────┘
     │
     ▼
┌─────────────────┐
│ Retry Transfer  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Success?        │
└────┬────┬───────┘
     │    │
  Yes│    │No (Max Retries)
     │    │
     │    └──> Fallback Handler
     │
     ▼
┌─────────────────┐
│ Resume Playback │
└─────────────────┘
```

### State Transitions

```
┌──────┐
│ Idle │
└───┬──┘
    │ connect()
    ▼
┌────────────┐
│ Connecting │
└─────┬──────┘
      │
      ├─> Success
      │   │
      │   ▼
      │ ┌───────────┐
      │ │ Connected │
      │ └─────┬─────┘
      │       │ start_stream()
      │       ▼
      │     ┌───────────┐
      │     │ Streaming │
      │     └─────┬─────┘
      │           │
      │           ├─> stop_stream()
      │           │   │
      │           │   └──> Connected
      │           │
      │           └─> disconnect()
      │               │
      │               └──> Idle
      │
      └─> Error
          │
          ▼
        ┌───────┐
        │ Error │
        └───┬───┘
            │ retry()
            │
            └──> Connecting
```

### Buffer Management

```
Audio Engine Thread          USB Transfer Thread
        │                            │
        │ Write Audio Data           │
        ▼                            │
┌──────────────┐                    │
│ RingBuffer   │                    │
│ Producer     │                    │
└──────┬───────┘                    │
       │                             │
       │ Lock-free Write             │
       │                             │
       ▼                             │
┌──────────────┐                    │
│ Shared       │                    │
│ Memory       │◄───────────────────┤
└──────┬───────┘                    │
       │                             │
       │ Lock-free Read              │
       │                             │
       ▼                             ▼
┌──────────────┐            ┌──────────────┐
│ RingBuffer   │            │ Transfer     │
│ Consumer     │───────────>│ Buffer       │
└──────────────┘            └──────┬───────┘
                                   │
                                   │ Submit
                                   ▼
                            ┌──────────────┐
                            │ USB Device   │
                            └──────────────┘
```

### Format Negotiation

```
Source Format              Device Capabilities
     │                            │
     │                            │
     └────────────┬───────────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Compare Formats│
         └────────┬───────┘
                  │
                  ▼
         ┌────────────────┐
         │ Exact Match?   │
         └────┬───┬───────┘
              │   │
           Yes│   │No
              │   │
              │   ▼
              │ ┌────────────────┐
              │ │ Find Best      │
              │ │ Compatible     │
              │ └────────┬───────┘
              │          │
              └──────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Conversion     │
         │ Needed?        │
         └────┬───┬───────┘
              │   │
           No │   │Yes
              │   │
              │   ▼
              │ ┌────────────────┐
              │ │ Configure      │
              │ │ Pipeline       │
              │ └────────┬───────┘
              │          │
              └──────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Configure      │
         │ Stream         │
         └────────────────┘
```

### Hot-plug

```
Device Connected/Disconnected
        │
        ▼
┌───────────────────┐
│ USB Event         │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Connection        │
│ Manager           │
└────────┬──────────┘
         │
         ├─> Connected
         │   │
         │   ▼
         │ ┌───────────────────┐
         │ │ Enumerate Device  │
         │ └────────┬──────────┘
         │          │
         │          ▼
         │        ┌───────────────────┐
         │        │ Register Device   │
         │        └────────┬──────────┘
         │                 │
         │                 ▼
         │               ┌───────────────────┐
         │               │ Notify Flutter    │
         │               └───────────────────┘
         │
         └─> Disconnected
             │
             ▼
           ┌───────────────────┐
           │ Stop Streaming    │
           └────────┬──────────┘
                    │
                    ▼
                  ┌───────────────────┐
                  │ Unregister Device │
                  └────────┬──────────┘
                           │
                           ▼
                         ┌───────────────────┐
                         │ Fallback Handler  │
                         └────────┬──────────┘
                                  │
                                  ▼
                                ┌───────────────────┐
                                │ Notify Flutter    │
                                └───────────────────┘
```

## Backend Strategy & DAC/DAP Extensibility

Output selection scores candidates and picks the highest-scoring eligible strategy.

```
User selects track
  → PlayerService (Dart)
    → AudioSessionManager._resolvePreferredMode()
      → selects AudioEngineType (Flutter-side engine selection)
    → RustAudioEngine / AndroidAudioEngine
      → EngineManager → create_audio_engine()
        → select_strategy_with_candidates(track, device, candidates)
          → selects OutputStrategy (data-driven scoring)
        → OutputVerification confirms actual output
```

### Strategy Priority

| Strategy           | Score | Condition                                                   |
|--------------------|-------|-------------------------------------------------------------|
| DapNative          | 100   | Confirmed DAP device with internal high-res path            |
| MixerBitPerfect    | 80    | Android 14+ with mixer bit-perfect support                 |
| UsbDirect          | 70    | Direct USB path available and verified                     |
| MixerMatched       | 60    | Device supports requested sample rate via mixer            |
| ResampledFallback  | 10    | Always available                                            |

Custom candidates override priority — see `select_strategy_with_candidates()`.

### Key Abstractions

| Layer   | Component                       | Purpose                                                       |
|---------|---------------------------------|---------------------------------------------------------------|
| Rust    | `BackendType` enum              | Categorizes output types (UsbDirect, DapNative, etc.)         |
| Rust    | `BackendDescriptor` struct      | Backend capabilities (passthrough, sample rate, priority)     |
| Rust    | `AudioBackend` trait            | Streaming lifecycle (start/stop/is_active/name/descriptor)   |
| Rust    | `BackendCandidate` + scoring    | Data-driven strategy selection                                |
| Rust    | `DapSignature` + `DAP_REGISTRY` | Data-driven DAP brand detection                               |
| Dart    | `AudioEngineType` enum          | Flutter-side engine selection, maps to BackendType            |
| Android | Capability strings              | Kotlin reports "usbDac"/"hiResInternal"/"standard" to Rust   |

### Adding a DAP Brand

Add a `DapSignature` entry to `DAP_REGISTRY` in `rust/src/audio/device.rs`:

```rust
DapSignature {
    id: "cayin",                // Unique identifier (lowercase)
    label: "Cayin",             // Display name
    keywords: &["cayin"],       // Manufacturer/brand keyword matchers
    model_prefixes: &["N3", "N5", "N6", "N7"],
    manufacturer_sufficient: true,
}
```

Then add the brand keyword to the Dart list in
`lib/services/android_audio_device_service.dart` (`isLikelyDap` getter). The
Dart list must match the Rust `keywords` fields.

Set `manufacturer_sufficient: false` when a brand keyword alone cannot confirm
DAP identity. Sony also makes phones — the model prefix (NW-A, NW-WM, NW-ZX)
must also match.

### Adding an Output Strategy

1. Add a `BackendType` variant in `rust/src/audio/backend.rs`.
2. Add a matching `OutputStrategy` variant in `rust/src/audio/strategy.rs` plus the `From` conversion.
3. Add a scoring function and register a `BackendCandidate` in `DEFAULT_CANDIDATES`.
4. Add capability detection to `DeviceCaps` and `detect_capabilities_blocking()`.
5. Add engine creation in `rust/src/audio/engine.rs` (`create_audio_engine()` and `android_output_signature_for_strategy()`).
6. Add the strategy to `resolved_strategy()` in `rust/src/audio/verifier.rs`.
7. Add to `AudioEngineType` enum and update switches in session manager and player service.

```rust
fn score_network_dac(device: &DeviceCaps, track: &TrackInfo) -> Option<u8> {
    if device.network_dac_available && track.channels > 0 {
        Some(75)  // Between USB direct (70) and mixer bit-perfect (80)
    } else {
        None
    }
}
```

### Adding a DSD Quirk

For native DSD on a USB DAC that needs special byte ordering, add a `DsdQuirk` to `KNOWN_DSD_QUIRKS` in `rust/src/uac2/android_direct.rs`:

```rust
DsdQuirk {
    vendor_id: 0x1224,           // USB VID
    product_id: 0x2A2A,          // USB PID
    product_name_contains: None, // Or Some("DAC Name")
    preferred_subslot: 2,        // Bytes per channel per USB frame
    big_endian: true,            // Byte order for multi-byte payloads
    bit_reverse: false,          // Per-byte bit reversal (LSB-first DSD DACs)
}
```

- `vendor_id` / `product_id`: exact USB VID/PID match (0 for wildcard).
- `product_name_contains`: substring match on USB product name (case-insensitive).
- `preferred_subslot`: bytes per channel per USB transfer frame.
- `big_endian`: when packing multi-byte interleaved channel data, send MSB first.
- `bit_reverse`: invert bit order within each byte.

The quirk applies during USB output loop initialization via `lookup_dsd_quirk()`, which feeds the `dsd_big_endian` flag into `prepare_iso_transfer_payload()` for native DSD payload packing.

### DAP Registry

| ID                  | Label               | Keywords              | Model Prefixes                | Sufficient |
|--------------------|---------------------|-----------------------|-------------------------------|------------|
| fiio               | FiiO                | fiio                  | M11, M15, M17, M21, M23, M27, JM21, M0-M8 | yes |
| ibasso             | iBasso              | ibasso                | DX160-DX340                   | yes        |
| hiby               | HiBy                | hiby                  | R3, R4, R5, R6, R8            | yes        |
| shanling           | Shanling            | shanling              | M300                          | yes        |
| astellkern         | Astell&Kern         | astell, iriver        | SA, SP, SE, A&                | yes        |
| cayin              | Cayin               | cayin                 | N3, N5, N6, N7                | yes        |
| sony               | Sony                | sony                  | NW-A, NW-WM, NW-ZX            | no         |
| tempotec           | TempoTec            | tempotec              | V6, S3, Mobi, Sonata, iDSD    | yes        |
| luxury_precision   | Luxury & Precision  | luxury, luxuryprecision | P6                          | yes        |

## Tested Devices

### USB DACs (Bit-Perfect via UAC 2.0)

| Device            | Max Rate | Max Bits | Volume   | Notes                                                                  |
|-------------------|----------|----------|----------|------------------------------------------------------------------------|
| MOONDROP Dawn Pro | 384 kHz  | 32-bit   | Hardware | Dual CS43131, 4.4mm balanced, daily driver; native DSD via quirk table (big-endian USB packing) |
| FiiO K5 Pro       | 384 kHz  | 32-bit   | Hardware | Excellent compatibility                                               |
| Topping D10s      | 384 kHz  | 32-bit   | Software | All features work                                                      |
| Schiit Modi 3+    | 192 kHz  | 24-bit   | Software | Stable operation                                                       |
| iFi Zen DAC       | 384 kHz  | 32-bit   | Software | DSD support                                                            |

### DAPs (Bit-Perfect Internal DAC)

| Device                    | Max Rate | Balanced        | Detection       | Notes                  |
|---------------------------|----------|-----------------|-----------------|------------------------|
| FiiO M11/M15/M17          | 384 kHz  | Yes (4.4mm)     | Automatic       | Mango mode supported   |
| iBasso DX160-DX340        | 384 kHz  | Yes (4.4mm)     | Automatic       | Mango mode supported   |
| HiBy R3/R5/R6/R8          | 384 kHz  | Select models   | Automatic       | —                      |
| Shanling M300             | 384 kHz  | No              | Automatic       | —                      |
| Astell&Kern SP/SA/SE      | 384 kHz  | Yes (2.5/4.4mm) | Automatic       | —                      |
| Cayin N3/N5/N6/N7         | 384 kHz  | Yes (4.4mm)     | Automatic       | —                      |
| Sony NW-A/NW-WM/NW-ZX     | 384 kHz  | Select models   | Model-dependent | Sony phones excluded   |
| TempoTec V6/S3            | 384 kHz  | No              | Automatic       | —                      |
| Luxury & Precision P6     | 384 kHz  | No              | Automatic       | —                      |

### File Reference

| File                                         | Purpose                                                                  |
|----------------------------------------------|--------------------------------------------------------------------------|
| `rust/src/audio/device.rs`                   | DAP signature registry, device classification                            |
| `rust/src/audio/strategy.rs`                 | BackendCandidate scoring, strategy selection                             |
| `rust/src/audio/backend.rs`                  | BackendType, BackendDescriptor, AudioBackend trait                       |
| `rust/src/audio/engine.rs`                   | Engine creation per strategy, integer (I32) stream support, pipeline mode |
| `rust/src/audio/verifier.rs`                 | Output verification                                                      |
| `rust/src/audio/manager.rs`                  | Capability detection, engine lifecycle                                   |
| `rust/src/uac2/android_direct.rs`            | USB isochronous transfers, DSD quirk table, native DSD payload packing   |
| `rust/src/audio/dsd_engine/output/mod.rs`    | DSD output routing, byte order normalization, global bit reverse override |
| `lib/models/audio_engine_type.dart`          | Flutter engine type enum                                                 |
| `lib/services/audio_session_manager.dart`    | Mode resolution logic                                                    |
| `lib/services/android_audio_device_service.dart` | DAP keyword detection (Dart)                                          |
| `android/.../MainActivity.kt`                | USB device management, capability reporting                              |
