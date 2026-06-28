# UAC 2.0 API Reference

Rust, Dart, and FFI surfaces for the UAC 2.0 engine.

## Rust API

### Core Types

#### `Uac2Device`

```rust
pub struct Uac2Device {
    pub id: String,
    pub vendor_id: u16,
    pub product_id: u16,
    pub manufacturer: String,
    pub product: String,
    pub serial: String,
    pub capabilities: DeviceCapabilities,
}

impl Uac2Device {
    pub fn connect(&mut self) -> Result<(), Uac2Error>;
    pub fn disconnect(&mut self) -> Result<(), Uac2Error>;
    pub fn is_connected(&self) -> bool;
    pub fn capabilities(&self) -> &DeviceCapabilities;
    pub fn start_stream(&mut self, config: StreamConfig) -> Result<(), Uac2Error>;
    pub fn stop_stream(&mut self) -> Result<(), Uac2Error>;
}
```

#### `DeviceCapabilities`

```rust
pub struct DeviceCapabilities {
    pub supported_formats: Vec<AudioFormat>,
    pub max_sample_rate: u32,
    pub max_bit_depth: u8,
    pub max_channels: u8,
    pub has_volume_control: bool,
    pub has_mute_control: bool,
}

impl DeviceCapabilities {
    pub fn find_best_format(&self, source: &AudioFormat) -> Option<AudioFormat>;
    pub fn supports_format(&self, format: &AudioFormat) -> bool;
    pub fn sample_rates(&self) -> Vec<u32>;
}
```

#### `AudioFormat`

```rust
pub struct AudioFormat {
    pub sample_rate: u32,
    pub bit_depth: u8,
    pub channels: u8,
    pub format_type: FormatType,
}

impl AudioFormat {
    pub fn new(sample_rate: u32, bit_depth: u8, channels: u8) -> Self;
    pub fn matches(&self, other: &AudioFormat) -> bool;
    pub fn needs_conversion(&self, other: &AudioFormat) -> bool;
    pub fn bytes_per_sample(&self) -> usize;
    pub fn bytes_per_frame(&self) -> usize;
}
```

#### `StreamConfig`

```rust
pub struct StreamConfig {
    pub format: AudioFormat,
    pub buffer_size: usize,
    pub num_buffers: usize,
}

impl StreamConfig {
    pub fn default_for_format(format: AudioFormat) -> Self;
    pub fn latency_ms(&self) -> f64;
    pub fn validate(&self) -> Result<(), Uac2Error>;
}
```

### Device Management

```rust
pub fn enumerate_devices() -> Result<Vec<Uac2Device>, Uac2Error>
pub fn get_device_by_id(id: &str) -> Result<Uac2Device, Uac2Error>
pub fn monitor_hotplug<F>(callback: F) -> Result<(), Uac2Error>
where
    F: Fn(HotplugEvent) + Send + 'static
```

`enumerate_devices` errors: `UsbError`, `PermissionDenied`. `get_device_by_id` errors: `DeviceNotFound`.

```rust
let devices = enumerate_devices()?;
for device in devices {
    println!("Found: {} {}", device.manufacturer, device.product);
}

monitor_hotplug(|event| {
    match event {
        HotplugEvent::Connected(device) => println!("Connected: {}", device.id),
        HotplugEvent::Disconnected(id) => println!("Disconnected: {}", id),
    }
})?;
```

### Audio Sink

```rust
pub struct Uac2AudioSink {
    device: Uac2Device,
    config: StreamConfig,
    pipeline: AudioPipeline,
}

impl Uac2AudioSink {
    pub fn new(device: Uac2Device, config: StreamConfig) -> Result<Self, Uac2Error>;
    pub fn start(&mut self) -> Result<(), Uac2Error>;
    pub fn stop(&mut self) -> Result<(), Uac2Error>;
    pub fn write(&mut self, data: &[f32]) -> Result<usize, Uac2Error>;
    pub fn buffer_fill(&self) -> f32;  // 0.0 to 1.0
}

impl AudioSink for Uac2AudioSink {
    fn write(&mut self, data: &[f32]) -> Result<(), AudioError>;
    fn flush(&mut self) -> Result<(), AudioError>;
}
```

### Format Negotiation

```rust
pub struct FormatNegotiator;

impl FormatNegotiator {
    pub fn negotiate(
        source: &AudioFormat,
        capabilities: &DeviceCapabilities
    ) -> Result<AudioFormat, Uac2Error>;

    pub fn has_exact_match(
        source: &AudioFormat,
        capabilities: &DeviceCapabilities
    ) -> bool;
}
```

### Control Requests

```rust
pub fn set_volume(device: &mut Uac2Device, volume: f32) -> Result<(), Uac2Error>  // volume: 0.0–1.0
pub fn get_volume(device: &Uac2Device) -> Result<f32, Uac2Error>
pub fn set_mute(device: &mut Uac2Device, muted: bool) -> Result<(), Uac2Error>
pub fn get_mute(device: &Uac2Device) -> Result<bool, Uac2Error>
```

### Error Type

```rust
pub enum Uac2Error {
    UsbError(rusb::Error),
    DeviceNotFound,
    DeviceBusy,
    PermissionDenied,
    InvalidDescriptor,
    UnsupportedFormat,
    TransferFailed,
    ConnectionLost,
    // ... more variants
}

impl Uac2Error {
    pub fn with_context(self, context: &str) -> Self;
    pub fn is_recoverable(&self) -> bool;
    pub fn user_message(&self) -> String;
}
```

Context example:

```rust
device.connect()
    .map_err(|e| e.with_context("Failed to connect to DAC"))?;
```

### Logging

```rust
pub fn configure_logging(level: LogLevel) -> Result<(), Uac2Error>
```

`level`: Error, Warn, Info, Debug, Trace.

### Constants

```rust
pub const USB_CLASS_AUDIO: u8 = 0x01;
pub const USB_SUBCLASS_AUDIOSTREAMING: u8 = 0x02;
pub const USB_PROTOCOL_UAC2: u8 = 0x20;
pub const DEFAULT_BUFFER_SIZE: usize = 2048;
pub const DEFAULT_NUM_BUFFERS: usize = 4;
```

### Thread Safety

- `Uac2Device`: not `Send` or `Sync` (contains USB handle).
- `DeviceCapabilities`, `AudioFormat`: `Send + Sync`.
- `Uac2AudioSink`: `Send` (for use in audio thread).

## Flutter API

### `Uac2Service`

**Location:** `lib/services/uac2_service.dart`

```dart
final uac2Service = Uac2Service.instance;
```

| Method                                          | Returns                            | Throws           |
|-------------------------------------------------|------------------------------------|------------------|
| `enumerateDevices()`                            | `Future<List<Uac2DeviceInfo>>`     | `Uac2Exception`  |
| `connectDevice(String deviceId)`                | `Future<void>`                     | `Uac2Exception`  |
| `disconnectDevice()`                            | `Future<void>`                     | `Uac2Exception`  |
| `getDeviceCapabilities(String deviceId)`        | `Future<Uac2Capabilities>`         | `Uac2Exception`  |
| `startStream(Uac2StreamConfig config)`          | `Future<void>`                     | `Uac2Exception`  |
| `stopStream()`                                  | `Future<void>`                     | `Uac2Exception`  |
| `setVolume(double volume)`                      | `Future<void>`                     | `Uac2Exception`  |
| `getVolume()`                                   | `Future<double>`                   | `Uac2Exception`  |
| `setMute(bool muted)`                           | `Future<void>`                     | `Uac2Exception`  |
| `getMute()`                                     | `Future<bool>`                     | `Uac2Exception`  |

### Streams

```dart
Stream<Uac2State> get deviceStateStream
Stream<Uac2HotplugEvent> get hotplugStream
```

```dart
uac2Service.deviceStateStream.listen((state) {
  switch (state) {
    case Uac2State.idle:       print('Idle');
    case Uac2State.connecting: print('Connecting...');
    case Uac2State.connected:  print('Connected');
    case Uac2State.streaming:  print('Streaming');
    case Uac2State.error:      print('Error');
  }
});

uac2Service.hotplugStream.listen((event) {
  if (event.connected) {
    print('Device connected: ${event.deviceId}');
  } else {
    print('Device disconnected: ${event.deviceId}');
  }
});
```

### Data Models

```dart
class Uac2DeviceInfo {
  final String id;
  final int vendorId;
  final int productId;
  final String manufacturer;
  final String product;
  final String serial;
  final Uac2Capabilities capabilities;
}

class Uac2Capabilities {
  final List<Uac2AudioFormat> supportedFormats;
  final int maxSampleRate;
  final int maxBitDepth;
  final int maxChannels;
  final bool hasVolumeControl;
  final bool hasMuteControl;
}

class Uac2AudioFormat {
  final int sampleRate;
  final int bitDepth;
  final int channels;

  const Uac2AudioFormat({
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
  });
}

class Uac2StreamConfig {
  final Uac2AudioFormat format;
  final int bufferSize;
  final int numBuffers;

  const Uac2StreamConfig({
    required this.format,
    this.bufferSize = 2048,
    this.numBuffers = 4,
  });
}

enum Uac2State { idle, connecting, connected, streaming, error }

class Uac2HotplugEvent {
  final String deviceId;
  final bool connected;

  const Uac2HotplugEvent({
    required this.deviceId,
    required this.connected,
  });
}

class Uac2Exception implements Exception {
  final String message;
  final Uac2ErrorCode code;

  const Uac2Exception(this.message, this.code);
}

enum Uac2ErrorCode {
  deviceNotFound,
  deviceBusy,
  permissionDenied,
  connectionFailed,
  transferFailed,
  unsupportedFormat,
  unknown,
}
```

### Riverpod Providers

```dart
final uac2DevicesProvider = StreamProvider<List<Uac2DeviceInfo>>((ref) {
  return uac2Service.deviceListStream;
});

final uac2StateProvider = StreamProvider<Uac2State>((ref) {
  return uac2Service.deviceStateStream;
});

final currentUac2DeviceProvider = StateProvider<Uac2DeviceInfo?>((ref) {
  return null;
});
```

### `Uac2PreferencesService`

**Location:** `lib/services/uac2_preferences_service.dart`

```dart
Future<String?> getSelectedDeviceId()
Future<void> setSelectedDeviceId(String deviceId)
Future<bool> getAutoConnect()
Future<void> setAutoConnect(bool enabled)
Future<Uac2AudioFormat?> getPreferredFormat()
Future<void> setPreferredFormat(Uac2AudioFormat format)
```

### Widgets

> **Deprecation note:** the `pipeline-info` and `transfer-stats` widgets were
> removed when UAC2 routing shifted to Android's native USB DAC handling.
> The widgets below remain.

```dart
// lib/widgets/uac2/uac2_device_selector.dart
Uac2DeviceSelector({
  required List<Uac2DeviceInfo> devices,
  Uac2DeviceInfo? selectedDevice,
  required ValueChanged<Uac2DeviceInfo> onDeviceSelected,
  VoidCallback? onRefresh,
})

// lib/widgets/uac2/uac2_status_indicator.dart
Uac2StatusIndicator({
  required Uac2State state,
  Uac2DeviceInfo? device,
  VoidCallback? onTap,
})

// lib/widgets/uac2/uac2_device_capabilities.dart
Uac2DeviceCapabilities({
  required Uac2Capabilities capabilities,
})

// lib/widgets/uac2/uac2_player_status.dart
Uac2PlayerStatus({
  required Uac2State state,
  Uac2AudioFormat? currentFormat,
})
```

## FFI Bridge

The bridge uses `flutter_rust_bridge` for type-safe Rust↔Dart communication with automatic code generation, async/await, error propagation, and stream support.

```
Flutter (Dart)
     │
     │ Dart API
     ▼
┌─────────────────┐
│ Generated       │
│ Dart Bindings   │
└────────┬────────┘
         │ FFI
         ▼
┌─────────────────┐
│ Generated       │
│ Rust Bindings   │
└────────┬────────┘
         │ Rust API
         ▼
Rust Implementation
```

### Bridge Definition

**Location:** `rust/src/api/audio_api.rs`

#### Device Operations

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn uac2_enumerate_devices() -> Result<Vec<Uac2DeviceInfoFfi>, Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_connect_device(device_id: String) -> Result<(), Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_disconnect_device() -> Result<(), Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_get_capabilities(device_id: String) -> Result<Uac2CapabilitiesFfi, Uac2ErrorFfi> { ... }
```

#### Streaming Operations

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn uac2_start_stream(config: Uac2StreamConfigFfi) -> Result<(), Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_stop_stream() -> Result<(), Uac2ErrorFfi> { ... }
```

#### Control Operations

```rust
#[flutter_rust_bridge::frb(sync)]
pub fn uac2_set_volume(volume: f32) -> Result<(), Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_get_volume() -> Result<f32, Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_set_mute(muted: bool) -> Result<(), Uac2ErrorFfi> { ... }

#[flutter_rust_bridge::frb(sync)]
pub fn uac2_get_mute() -> Result<bool, Uac2ErrorFfi> { ... }
```

#### Event Streams

```rust
pub fn uac2_state_stream() -> impl Stream<Item = Uac2StateFfi> { ... }
pub fn uac2_hotplug_stream() -> impl Stream<Item = Uac2HotplugEventFfi> { ... }
```

### FFI Types

```rust
#[derive(Clone, Debug)]
pub struct Uac2DeviceInfoFfi {
    pub id: String,
    pub vendor_id: u16,
    pub product_id: u16,
    pub manufacturer: String,
    pub product: String,
    pub serial: String,
    pub capabilities: Uac2CapabilitiesFfi,
}

#[derive(Clone, Debug)]
pub struct Uac2CapabilitiesFfi {
    pub supported_formats: Vec<Uac2AudioFormatFfi>,
    pub max_sample_rate: u32,
    pub max_bit_depth: u8,
    pub max_channels: u8,
    pub has_volume_control: bool,
    pub has_mute_control: bool,
}

#[derive(Clone, Debug)]
pub struct Uac2AudioFormatFfi {
    pub sample_rate: u32,
    pub bit_depth: u8,
    pub channels: u8,
}

#[derive(Clone, Debug)]
pub struct Uac2StreamConfigFfi {
    pub format: Uac2AudioFormatFfi,
    pub buffer_size: usize,
    pub num_buffers: usize,
}

#[derive(Clone, Debug)]
pub enum Uac2StateFfi {
    Idle,
    Connecting,
    Connected,
    Streaming,
    Error,
}

#[derive(Clone, Debug)]
pub struct Uac2HotplugEventFfi {
    pub device_id: String,
    pub connected: bool,
}

#[derive(Clone, Debug)]
pub enum Uac2ErrorFfi {
    DeviceNotFound,
    DeviceBusy,
    PermissionDenied,
    ConnectionFailed,
    TransferFailed,
    UnsupportedFormat,
    Unknown { message: String },
}
```

### Type Conversions

```rust
impl From<Uac2Device> for Uac2DeviceInfoFfi {
    fn from(device: Uac2Device) -> Self {
        Self {
            id: device.id,
            vendor_id: device.vendor_id,
            product_id: device.product_id,
            manufacturer: device.manufacturer,
            product: device.product,
            serial: device.serial,
            capabilities: device.capabilities.into(),
        }
    }
}

impl From<Uac2StreamConfigFfi> for StreamConfig {
    fn from(config: Uac2StreamConfigFfi) -> Self {
        Self {
            format: config.format.into(),
            buffer_size: config.buffer_size,
            num_buffers: config.num_buffers,
        }
    }
}

impl From<Uac2Error> for Uac2ErrorFfi {
    fn from(error: Uac2Error) -> Self {
        match error {
            Uac2Error::DeviceNotFound => Self::DeviceNotFound,
            Uac2Error::DeviceBusy => Self::DeviceBusy,
            Uac2Error::PermissionDenied => Self::PermissionDenied,
            Uac2Error::ConnectionLost => Self::ConnectionFailed,
            Uac2Error::TransferFailed => Self::TransferFailed,
            Uac2Error::UnsupportedFormat => Self::UnsupportedFormat,
            _ => Self::Unknown {
                message: error.to_string(),
            },
        }
    }
}
```

Dart error handling:

```dart
try {
  await uac2ConnectDevice(deviceId);
} on FfiException catch (e) {
  final error = Uac2Exception.fromFfi(e);
  print('Error: ${error.message}');
}
```

### Streams

```rust
pub fn uac2_state_stream() -> impl Stream<Item = Uac2StateFfi> {
    let (tx, rx) = mpsc::channel(100);
    tokio::spawn(async move {
        // Send state updates to tx
    });
    ReceiverStream::new(rx)
}
```

```dart
Stream<Uac2State> get deviceStateStream {
  return uac2StateStream().map((state) {
    return Uac2State.fromFfi(state);
  });
}
```

### Code Generation

```bash
flutter_rust_bridge_codegen \
  --rust-input rust/src/api/audio_api.rs \
  --dart-output lib/bridge/audio_bridge.dart
```

Build sequence: define Rust API with `#[flutter_rust_bridge::frb]` attributes → run codegen → Dart bindings land in `lib/bridge/`, Rust bindings in `rust/src/bridge/` → build Rust library → Flutter imports generated Dart.

### Sync vs Async

Sync (`#[flutter_rust_bridge::frb(sync)]`) for fast operations under ~1ms. Async for slow operations, I/O, blocking calls.

Rust owns the data. FFI types are cloned for transfer; Dart receives owned data. No manual memory management on the Dart side.

### Thread Safety

FFI calls run from any Dart isolate. The Rust implementation must be thread-safe — use `Arc` and `Mutex` for shared state. Streams use channels for cross-thread communication.

### Debugging

```rust
// Rust
tracing::debug!("FFI call: uac2_connect_device({})", device_id);

uac2_connect_device(device_id)
    .map_err(|e| e.with_context("FFI: connect_device"))?
```

```dart
// Dart
print('Calling uac2_connect_device($deviceId)');
```
