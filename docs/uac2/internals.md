# UAC 2.0 Internals

Audio pipeline behavior, error handling, and the bit-perfect distortion fix.

## Audio Pipeline

The pipeline receives PCM from the engine and prepares it for isochronous USB transfer to the DAC/AMP. When source and device formats match, audio passes through unmodified. When they differ, the pipeline converts sample rate, bit depth, and channel layout.

```
Audio Engine
     │
     ▼
┌─────────────────┐
│ Uac2AudioSink   │  ← Receives audio from engine
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Format Check    │  ← Compare source vs device format
└────────┬────────┘
         │
         ├─> Match: Direct Passthrough
         │   │
         │   ▼
         │ ┌─────────────────┐
         │ │ Zero Processing │  ← Bit-perfect
         │ └────────┬────────┘
         │          │
         └──────────┘
         │
         └─> Mismatch: Convert
             │
             ▼
           ┌─────────────────┐
           │ AudioPipeline   │  ← Format conversion
           └────────┬────────┘
                    │
                    ▼
         ┌─────────────────┐
         │ RingBuffer      │  ← Buffering
         └────────┬────────┘
                  │
                  ▼
         ┌─────────────────┐
         │ USB Transfer    │  ← Send to device
         └─────────────────┘
```

### Components

**`Uac2AudioSink`** (`rust/src/uac2/audio_sink.rs`) receives PCM from the engine, checks format compatibility, routes to direct transfer or pipeline:

```rust
impl AudioSink for Uac2AudioSink {
    fn write(&mut self, data: &[f32]) -> Result<(), AudioError> {
        if self.needs_conversion() {
            self.pipeline.process(data)?;
        } else {
            self.direct_write(data)?;
        }
        Ok(())
    }
}
```

**`AudioPipeline`** (`rust/src/uac2/audio_pipeline.rs`) runs the optional converters:

```rust
pub struct AudioPipeline {
    resampler: Option<Resampler>,
    bit_converter: Option<BitDepthConverter>,
    channel_mixer: Option<ChannelMixer>,
}
```

**`RingBuffer`** (`rust/src/uac2/ring_buffer.rs`) is a lock-free single-producer/single-consumer buffer bridging the audio thread and USB thread:

```rust
pub struct RingBuffer<T> {
    buffer: Vec<T>,
    read_pos: AtomicUsize,
    write_pos: AtomicUsize,
}
```

### Format Conversion

| Conversion      | Behavior                                           |
|-----------------|----------------------------------------------------|
| Sample rate     | Resampler; only when source and device rates differ |
| Bit depth       | 16↔24, 24↔32; dither on downsampling              |
| Channel layout  | Mono→stereo (duplicate), stereo→mono (mix), multichannel mapping |

### Bit-Perfect Mode

When source and device formats match exactly: no resampling, no bit-depth conversion, no channel mixing, direct memory copy, zero DSP processing.

### Buffering

Buffer size trades latency for stability. Smaller buffers lower latency but risk underrun; larger buffers raise latency but stay stable.

| Profile          | Size (samples) |
|------------------|----------------|
| Low latency      | 256–512        |
| Balanced         | 1024–2048      |
| High stability   | 4096+          |

Buffer size adapts based on transfer success rate, underrun frequency, and device latency characteristics.

- **Underrun** (buffer empty): insert silence to prevent glitches, log, grow the buffer if frequent.
- **Overrun** (buffer full): drop oldest samples, log, shrink the buffer if frequent.

### Transfer Management

**`transfer_buffer.rs`**: pool of pre-allocated reusable buffers sized for isochronous packets, recycled after completion.

**`transfer.rs`**: real-time isochronous USB transfers — fixed interval (1ms typical), no retransmission, time-critical delivery.

```rust
pub struct TransferManager {
    active_transfers: Vec<Transfer>,
    buffer_pool: BufferPool,
}
```

### Latency Sources

Buffer latency (buffer_size / sample_rate) + processing latency (conversion) + USB latency (transfer interval) + device latency (DAC processing). Minimized by smaller buffers, avoiding unnecessary conversion, and tight transfer scheduling.

## Error Handling

### `Uac2Error`

**Module:** `rust/src/uac2/error.rs`

```rust
pub enum Uac2Error {
    // USB errors
    UsbError(rusb::Error),
    DeviceNotFound,
    DeviceBusy,
    PermissionDenied,

    // Descriptor errors
    InvalidDescriptor,
    UnsupportedFormat,
    MalformedDescriptor,

    // Transfer errors
    TransferFailed,
    TransferTimeout,
    TransferStalled,

    // Audio errors
    BufferUnderrun,
    BufferOverrun,
    FormatMismatch,

    // Connection errors
    ConnectionLost,
    DeviceDisconnected,

    // Configuration errors
    InvalidConfiguration,
    UnsupportedSampleRate,
    UnsupportedBitDepth,
}
```

### Recovery Strategy

**Module:** `rust/src/uac2/error_recovery.rs`

```rust
pub enum RecoveryStrategy {
    Retry { max_attempts: u32, delay: Duration },
    Reconnect,
    Fallback,
    Abort,
}
```

Classification drives automatic recovery:

| Category   | Trigger                                   | Action                          |
|------------|-------------------------------------------|---------------------------------|
| Transient  | Transfer timeout, device busy, underrun   | Retry with backoff              |
| Connection | Connection lost, device reset             | Reconnect                       |
| Fatal      | Device disconnected, unsupported format, permission denied | Fallback to default audio |

### Error Handling Flow

```
Error Occurs
     │
     ▼
┌─────────────────┐
│ Classify Error  │
└────────┬────────┘
         │
         ├─> Transient
         │   │
         │   ▼
         │ ┌─────────────────┐
         │ │ Retry Logic     │
         │ └────────┬────────┘
         │          │
         │          ├─> Success: Resume
         │          └─> Max Retries: Fallback
         │
         ├─> Connection
         │   │
         │   ▼
         │ ┌─────────────────┐
         │ │ Reconnect       │
         │ └────────┬────────┘
         │          │
         │          ├─> Success: Resume
         │          └─> Failed: Fallback
         │
         └─> Fatal
             │
             ▼
           ┌─────────────────┐
           │ Fallback        │
           └────────┬────────┘
                    │
                    ▼
                  ┌─────────────────┐
                  │ Notify User     │
                  └─────────────────┘
```

### Retry Logic

Exponential backoff:

```rust
pub struct RetryPolicy {
    max_attempts: u32,
    initial_delay: Duration,
    max_delay: Duration,
    multiplier: f64,
}
```

Example schedule: 10ms → 20ms → 40ms → 80ms → cap at 500ms.

Retried: transfer timeout, device busy, temporary USB errors, buffer underrun (with buffer adjustment).

Not retried: permission denied, device disconnected, unsupported format, invalid configuration.

### Fallback Handler

**Module:** `rust/src/uac2/fallback_handler.rs`

```rust
pub struct FallbackHandler {
    default_sink: Box<dyn AudioSink>,
}

impl FallbackHandler {
    pub fn activate(&mut self) -> Result<(), AudioError> {
        // Stop UAC2 streaming
        // Switch to default audio sink
        // Notify application
    }
}
```

Triggers: device disconnected during playback, unrecoverable transfer errors, max retry attempts exceeded, user cancels connection.

Process: stop UAC2 streaming → release USB device → switch to default sink → resume playback → notify user.

### Logging

Structured logs with context:

```rust
tracing::error!(
    device_id = %device.id(),
    error = %err,
    "Failed to start audio stream"
);
```

| Level  | Use                                  |
|--------|--------------------------------------|
| ERROR  | Unrecoverable errors                 |
| WARN   | Recoverable errors, retries          |
| INFO   | Recovery success                     |
| DEBUG  | Detailed error context               |

### Display

```rust
impl Display for Uac2Error {
    fn fmt(&self, f: &mut Formatter) -> fmt::Result {
        match self {
            Self::PermissionDenied =>
                write!(f, "USB permission denied. Please grant access."),
            Self::DeviceDisconnected =>
                write!(f, "Device disconnected. Switching to default audio."),
            // ... other messages
        }
    }
}
```

Errors propagate to Flutter:

```dart
try {
  await uac2Service.connect(device);
} on Uac2Exception catch (e) {
  showErrorDialog(e.message);
}
```

## Bit-Perfect Distortion Fix (MOONDROP Dawn Pro)

### Problem

Direct USB audio with bit-perfect mode on the MOONDROP Dawn Pro DAC caused distortion and playback issues.

### Root Cause

1. `updateDirectUsbAudioFocus()` did not request `AUDIOFOCUS_GAIN` when direct USB playback became active. The Android audio system did not prioritize the direct USB stream.

2. When the DAC lacked UAC2 Feature Unit volume controls (no hardware volume), the code fell back to Android's system volume mixer, which does not affect direct USB audio paths.

### Fix (commit 661ebe7)

**Audio focus** (`android/app/src/main/kotlin/com/ultraelectronica/flick/MainActivity.kt`) now requests `AUDIOFOCUS_GAIN` when `directUsbPlaybackActive`:

```kotlin
private fun updateDirectUsbAudioFocus() {
    if (directUsbPlaybackActive) {
        if (directUsbFocusGain == null) {
            Log.i("UAC2", "[USB] Requesting audio focus for direct USB playback")
            requestDirectUsbAudioFocus(AudioManager.AUDIOFOCUS_GAIN)
        }
    } else {
        if (directUsbFocusGain != null || directUsbAudioFocusRequest != null) {
            Log.i("UAC2", "[USB] Releasing direct USB audio focus")
        }
        abandonDirectUsbAudioFocus()
    }
}
```

**Hardware volume bridge** (Kotlin → Rust JNI):

- `nativeHasRustDirectUsbHardwareVolume()` — check if DAC exposes hardware volume
- `nativeGetRustDirectUsbHardwareVolume()` — get current hardware volume
- `nativeSetRustDirectUsbHardwareVolume(volume)` — set hardware volume
- `nativeGetRustDirectUsbHardwareMute()` — get mute state
- `nativeSetRustDirectUsbHardwareMute(muted)` — set mute state

Rust side (`rust/src/lib.rs`):

```rust
pub extern "system" fn Java_com_ultraelectronica_flick_MainActivity_nativeHasRustDirectUsbHardwareVolume(...) -> jboolean {
    if crate::uac2::android_direct_has_hardware_volume_control() {
        1
    } else {
        0
    }
}
```

**Volume mode tracking** (`MainActivity.kt`):

```kotlin
val hasDirectUsbHardwareVolume =
    directUsbRegistered && nativeHasRustDirectUsbHardwareVolume()
val hasVolumeControl = if (directUsbRegistered) {
    hasDirectUsbHardwareVolume
} else {
    hasDirectUsbHardwareVolume || hasSystemVolumeControl
}
baseRoute["volumeMode"] = when {
    hasDirectUsbHardwareVolume -> "hardware"
    hasVolumeControl -> "system"
    else -> "unavailable"
}
```

**Player service sync** (`lib/services/player_service.dart`):

```dart
bool _hasBitPerfectUsbHardwareVolumeControl() {
    final routeStatus = _uac2Service.currentDeviceStatus;
    return Platform.isAndroid &&
        currentEngineType == AudioEngineType.usbDacExperimental &&
        isBitPerfectModeEnabled &&
        routeStatus?.hasVolumeControl == true &&
        routeStatus?.volumeMode == Uac2VolumeMode.hardware;
}
```

### Key Insight

The MOONDROP Dawn Pro (and many UAC2 devices) do not expose UAC2 Feature Unit volume controls, so hardware volume is unavailable. Properly managing audio focus and not claiming volume control availability when it does not exist keeps the audio path clean and bit-perfect.

### Files Modified

- `android/app/src/main/kotlin/com/ultraelectronica/flick/MainActivity.kt` — audio focus + volume JNI
- `rust/src/lib.rs` — native method implementations
- `lib/services/player_service.dart` — volume synchronization logic
