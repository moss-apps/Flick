# DSD / DSF / DFF / WavPack Playback Architecture

## Overview

| Format | Extension | Container | Source |
|--------|-----------|-----------|--------|
| **DSF** (DSD Stream File) | `.dsf` | Sony DSD container | `dsf_meta` crate |
| **DFF** (DSD Interchange File) | `.dff` | Philips DSD container | `dff_meta` crate |
| **WavPack DSD** | `.wv` | WavPack with DSD content | `wavpack-sys` C bindings |
| **WavPack PCM** | `.wv` | WavPack with lossless PCM | `wavpack-sys` C bindings |

Three output modes for DSD content:

| Mode | Behavior | Requirement |
|------|----------|-------------|
| **PCM Decimation** | DSD bitstream → integer-multiple PCM (44.1k–705.6k) via software CIC+FIR decimator | Any output device |
| **DoP** (DSD over PCM) | Raw DSD bits packed into 24/32-bit PCM frames with 0x05/0xFA markers | DoP-capable DAC |
| **Native DSD** | Raw DSD bitstream delivered directly, no DSP. USB isochronous (quirk-based byte order) or AAudio I32 (DAP) | Native-DSD-capable DAC |

## 1. File Detection and Routing

`rust/src/audio/decoder_handles.rs:49-67`

```rust
enum FileType { Standard, Dsd, WavPack }
```

`detect_file_type()` routes by extension:
- `.dsf`, `.dff` → `FileType::Dsd`
- `.wv` → probes `is_wavpack_dsd()` (bit 31 of WavPack mode flags). DSD → `FileType::Dsd`, PCM → `FileType::WavPack`
- Everything else → `FileType::Standard` (Symphonia)

`engine.rs:2024-2061` — `spawn_decoder()`:

```
FileType::Dsd     → DsdDecoderThread
FileType::WavPack → WavpackDecoderThread (PCM), or DsdDecoderThread (DSD)
FileType::Standard → DecoderThread (Symphonia)
```

## 2. Format Decoders

All DSD decoders implement `DsdFormatDecoder` (`rust/src/audio/dsd_engine/format/mod.rs:14-23`):

```rust
trait DsdFormatDecoder: Send {
    fn sample_rate(&self) -> u32;
    fn channels(&self) -> u16;
    fn total_samples(&self) -> u64;
    fn duration_secs(&self) -> f64;
    fn seek(&mut self, sample: u64) -> Result<()>;
    fn read_dsd_bytes(&mut self, buf: &mut [u8]) -> Result<usize>;
    fn is_finished(&self) -> bool;
    fn channel_layout(&self) -> DsdChannelLayout;
    fn bit_order(&self) -> DsdBitOrder;
}
```

`DsdBitOrder` (`Lsb`/`Msb`) indicates source bit ordering. All decoders report MSB by default. `open_dsd_decoder()` (`format/mod.rs:25-46`) dispatches by extension.

### DSF (`format/dsf_decoder.rs`)
Sequential channel blocks: all bytes for channel 0, then channel 1, etc. Each block is `block_size` bytes (typically 4096).
- Header via `dsf_meta::DsfFile`
- `DsdChannelLayout::SequentialBlocks { block_size }`
- Seek: block-aligned (`sample / block_size`)
- No deinterleave needed

### DFF (`format/dff_decoder.rs`)
Interleaved: one byte per channel per frame.
- Header via `dff_meta::DffFile`
- `DsdChannelLayout::Interleaved`
- Seek: byte-level (`sample / 8 * channels`)
- Thread layer deinterleaves (section 4)

### WavPack DSD (`format/wavpack_decoder.rs`)
Opened via `wavpack-sys` with `OPEN_DSD_NATIVE` (0x100) — returns raw DSD bitstream instead of PCM.
- Detection (`wavpack_thread.rs:13-36`): bit 31 of `WavpackGetMode()` (`0x80000000`)
- `read_dsd_bytes()` calls `WavpackUnpackSamples()`, truncates i32 → `u8`
- `DsdChannelLayout::Interleaved`; `WavpackSeekSample64` for seeking

## 3. DSD Output Router

`rust/src/audio/dsd_engine/output/mod.rs`

`DsdOutputRouter` routes raw DSD bytes to one of three processors by `DsdOutputMode`:

```
dsd_bytes ──→ DsdOutputRouter
                  │
                  ├── PcmDecimation → DsdDecimationPipeline (CIC+FIR)
                  │     → interleaved f32 PCM samples
                  │
                  ├── Dop → DopPacker
                  │     → f32 samples with 0x05/0xFA markers
                  │
                  └── Native → normalize_dsd_byte() per byte
                        → raw f32 bit containers (f32::from_bits)
```

Output mode selected via `DsdOutputRouter::new(mode, dsd_rate, target, channels, source_bit_order)` (`dsd_thread.rs:73`).

### Native DSD Byte Ordering
`normalize_dsd_byte()` checks source bit order per byte:
- **LSB-first sources**: byte bit-reversed via `reverse_bits()`
- **MSB-first sources** (default): byte passes through

A global `DSD_BIT_REVERSE_OVERRIDE` atomic (exposed via `set_dsd_bit_reverse_override(bool)`) forces/inverts reversal — for DACs expecting the opposite bit order.

### DSD Quirks Table
Device-specific quirks for USB native DSD, in `KNOWN_DSD_QUIRKS` (`rust/src/uac2/android_direct.rs`). Each `DsdQuirk`:

| Field | Description |
|-------|-------------|
| `vendor_id` / `product_id` | USB VID/PID exact match |
| `product_name_contains` | Substring match on device name |
| `preferred_subslot` | Bytes per channel per USB frame |
| `big_endian` | Byte order for multi-byte payloads |
| `bit_reverse` | Whether bit reversal is needed |

`lookup_dsd_quirk()` queries during USB output loop init, feeding `dsd_big_endian` into `prepare_iso_transfer_payload()`. Known entry: MOONDROP Dawn Pro.

## 4. DSD Decoder Thread

`rust/src/audio/dsd_engine/dsd_thread.rs`

`dsd_decode_thread()` runs on a background thread. Per loop:
1. Read raw DSD bytes (`decoder.read_dsd_bytes()`)
2. Deinterleave if interleaved layout (DFF, WavPack DSD): `deinterleave_dsd()` (`dsd_thread.rs:219-234`) rearranges `[C0F0, C1F0, C0F1, C1F1]` → `[C0F0, C0F1, C1F0, C1F1]`. DSF (sequential blocks) skips this.
3. `output_router.process_dsd_bytes()`
4. `write_to_ring_buffer()` (f32 samples)

Read chunk size: 16,384 bytes, aligned to channel-block boundaries for DSF.

## 5. PCM Decimation Pipeline

`rust/src/audio/dsd_engine/dsd/mod.rs:86-245`

Two-stage software decimation from DSD bitrate to PCM standard rates.

### Stage 1: CIC Decimation
- 3rd-order CIC integrator (`CIC_ORDER = 3`)
- Input: DSD bytes (each byte = 8 one-bit samples); `bit_sum = (popcount(byte) * 2.0) - 8.0` (maps to -8..+8)
- Cascaded integrators at input, difference at output
- Decimation factor auto-computed to target PCM rate, max 8×
- If total decimation isn't evenly divisible, CIC=1 and FIR handles it all

### Stage 2: FIR Anti-Alias Filter
- 64-tap Blackman-windowed sinc lowpass (`coefficients.rs`)
- Cutoff = `target_pcm_rate / 2 / intermediate_rate`; DC gain = 1.0
- One filter state per channel, rotated each FIR step

### Decimation Targets
| DSD Rate | Byte Rate | PCM Targets (Hz) |
|----------|-----------|-------------------|
| DSD64 (2.8M) | 352.8k | 176.4k, 88.2k, 44.1k |
| DSD128 (5.6M) | 705.6k | 352.8k, 176.4k, 88.2k, 44.1k |
| DSD256 (11.3M) | 1.41M | 705.6k, 352.8k, 176.4k, 88.2k |
| DSD512 (22.6M) | 2.82M | 705.6k, 352.8k, 176.4k, 88.2k |

All targets are integer subdivisions of 44.1k × 64 (DSD base clock).

### FIR Coefficient Generation (`coefficients.rs`)
```rust
generate_lowpass_fir(num_taps, input_rate, output_rate) → Vec<f64>
```
Windows: Blackman (default), Hamming, Kaiser. Coefficients generated once via `OnceLock`. Kaiser's Bessel I0 function computed via series expansion.

## 6. DoP (DSD over PCM) Packer

`rust/src/audio/dsd_engine/dsd/dop.rs`

DoP encodes DSD inside PCM frames. Each PCM sample carries one DSD channel plus an 8-bit marker.

### DoP Word Building
`build_dop_word()` constructs a 32-bit DoP word from DSD bytes + marker. Shared between the f32-packing path and the I32 integer stream path — consistent marker placement regardless of output format.

### I32 Packing
`pack_dop_to_i32()` builds the same DoP words, writes `i32` directly into the output buffer. Bypasses the f32 bit-layer indirection, preserving raw DoP bit patterns for integer streams.

### Marker Protocol
Markers alternate per frame: `0x05` → `0xFA` → `0x05` → ...
A DoP DAC detects these to identify the stream as DoP. Without markers, the stream looks like high-gain noise.

### Frame Layout
| DSD Rate | PCM Depth | DSD Bits/Frame | DSD Bytes/Frame/Ch | Carrier Rate |
|----------|-----------|----------------|---------------------|--------------|
| DSD64 | 24-bit | 16 | 2 | 176.4 kHz |
| DSD128 | 24-bit | 16 | 2 | 352.8 kHz |
| DSD256 | 24-bit | 16 | 2 | 705.6 kHz |
| DSD512 | 32-bit | 24 | 3 | 705.6 kHz |

**DSD64 24-bit frame** (2 bytes DSD + 1 marker, per channel):
```
byte 0: 0x05 (marker)
byte 1: DSD channel byte 0
byte 2: DSD channel byte 1
→ encoded as f32 via bit_cast (u32 interpretation)
```

**DSD512 32-bit frame** (3 bytes DSD + 1 marker, per channel):
```
byte 0: 0x05/0xFA (marker)
byte 1: DSD channel byte 0
byte 2: DSD channel byte 1
byte 3: DSD channel byte 2
→ encoded as f32 via bit_cast
```

### Packing (`DopPacker::pack_to_f32()`)
Per frame and channel:
1. Build 24/32-bit value: `marker_byte << dsd_data_bits | dsd_bytes`
2. Cast bit pattern to f32: `f32::from_bits(sample)`
3. Advance marker state (toggle 0x05 ↔ 0xFA)

The f32 values are opaque bit containers — never used as actual floating-point audio. The DAC reads the raw PCM sample bytes.

## 7. WavPack PCM Decoder Thread

`rust/src/audio/wavpack_thread.rs`

Non-DSD `.wv` (standard WavPack lossless):
1. Open via `wavpack-sys` (no `OPEN_DSD_NATIVE`)
2. Guard: reject DSD WavPack (must use DSD pipeline)
3. Read properties: sample rate, channels, bits per sample, float mode
4. Decode loop: `WavpackUnpackSamples()` → i32 (4,096 frames/chunk); convert to f32 (float uses `f32::from_bits()`, integer uses `sample / scale`; scales: 8-bit=128, 16-bit=32768, 24/32-bit=2147483648)
5. Channel remix (`remix_channels()`): downmix to mono / upmix from mono
6. Resample via `AudioResampler` (Rubato) if file rate ≠ output rate
7. Flush resampler tail after EOF
8. Write to ring buffer

Uses the same `write_to_ring_buffer()` back-pressure loop as the DSD thread.

## 8. Audio Engine Integration

### Pipeline Modes (`engine.rs:70-74`)
```rust
enum PipelineMode {
    Passthrough = 0,  // No DSP, gain only (bit-perfect path)
    Dsp = 1,          // Full processing chain
    Dop = 2,          // DoP passthrough (no gain, no DSP)
}
```

### DoP Callback Path (`engine.rs:1488-1516`)
When `PipelineMode::Dop`: read samples directly from `SourceProvider`, write to output with no processing (no gain, EQ, dynamics, or crossfade). The f32 samples are opaque DoP bit containers, forwarded as-is. Applying gain or DSP would corrupt the marker bytes and DSD data.

### DoP Override (`engine.rs:1901-1909`)
`SetDopOverride`:
- `is_dop = true` → mode `Dop`
- `is_dop = false` → mode restored to `Dsp` or `Passthrough`

### Gapless Playback
All decoder threads share the ring-buffer `SourceProvider`. On new track:
- `handle_play_prepared()` sets the new source as current
- `handle_queue_next_prepared()` queues it as "next"
- The callback detects old source completion → `AudioEvent::TrackFinished`

### Thread Model
```
┌──────────────────┐    ring buffer    ┌──────────────────┐
│  Decoder Thread  │ ────────────────→ │ Audio Callback   │
│  (per track)     │    (producer)     │ (cpal/Oboe/UAC2) │
│                  │                   │ (consumer)       │
├──────────────────┤                   ├──────────────────┤
│ DsdDecoderThread │                   │ PipelineMode::   │
│   ├─ format dec  │                   │   Dop → passthru │
│   ├─ deinterleave│                   │   Dsp → full DSP │
│   └─ output route│                   │   Passthru→gain  │
├──────────────────┤                   └──────────────────┘
│ WavpackDec.Thread│
│   ├─ wavpack-sys │
│   ├─ convert f32 │
│   ├─ remix       │
│   └─ resample    │
├──────────────────┤
│ DecoderThread    │
│   └─ Symphonia   │
└──────────────────┘
```

## 9. Platform Output

### Non-Android (cpal)
Always `PipelineMode::Dsp`. DoP not supported — f32 samples play as literal PCM (silence/garbage). Use PCM decimation mode.

### Android Oboe (Managed)
- Stereo f32 or i32 at device sample rate (I32 for DoP/DSD native, preserves bit patterns)
- Strategy selection: `DsdNative`, `DapNative`, `MixerBitPerfect`, `DsdDoP`, `UsbDirect`, `UsbDsdNative`, `MixerMatched`, `ResampledFallback`
- DoP: mode `Dop`; carrier rate negotiated with DAC
- Native DSD: mode `Dop`; raw bytes packed into f32 containers or I32 passthrough

### Android USB Direct (UAC2)
- DoP format negotiation via UAC2 descriptors; `AndroidDirectUsbPlaybackFormat.is_dop` flag
- `AndroidDirectUsbPlaybackFormat.dsd_bit_rate` for native DSD wire rate
- DoP encoding: `encode_dop_slots()` (`uac2/android_direct.rs`)
- Native DSD encoding: `encode_usb_pcm_slots()` with `dsd_big_endian` flag and `channels`
- Multi-byte interleaved payload packing: `subslot_size=1` for direct byte copy, `>1` for interleaved multi-byte per channel with configurable endianness
- Pipeline mode: `Passthrough` (bit-perfect verified PCM), `Dop` (DoP + native DSD)
- Device classifier checks `FORMAT_TAG_DSD = 0x0008` and `FormatType::Dsd`
- DSD quirks lookup at USB output loop init for per-device byte ordering

## 10. Settings

`lib/services/uac2_preferences_service.dart`

| Setting | Key | Description |
|---------|-----|-------------|
| DSD Output Mode | `dsd_output_mode` | `auto` / `forcePcm` / `forceDop` |
| Auto-switch DoP → PCM | auto-switch flag | Activating software volume while in DoP restarts the decoder in PCM decimation |

Rust bridge:
- `current_dsd_output_mode()` — reads `DSD_OUTPUT_MODE` atomic (0=PCM, 1=DoP)
- `audio_set_dsd_output_mode(mode: u8)` — writes the atomic
- `audio_set_dsd_bit_reverse_override(bool)` — forces/inverts DSD byte ordering globally (`#[flutter_rust_bridge::frb(sync)]`)

DoP volume constraint (`player_service.dart:3682-3707`):
- DoP bypasses software gain (no-op in `PipelineMode::Dop`); native DSD also bypasses (mode `Dop`)
- When software volume is needed (no hardware volume on DAC), the player auto-switches to PCM decimation

## 11. Key Constraints

- **DoP requires bit-perfect passthrough.** Any DSP corrupts markers and DSD data.
- **Native DSD requires bit-perfect passthrough.** Same constraint — any gain or DSP destroys the 1-bit sigma-delta bitstream.
- **DSD bit order is format-specific.** LSB vs MSB; the output router normalizes via the decoder's `bit_order()`. A global override inverts this for DACs expecting reversed byte order.
- **USB native DSD uses quirk-based config.** Per-device byte ordering (endianness, bit reversal, subslot) via `lookup_dsd_quirk()` at USB output loop init.
- **I32 streams required for DoP/DSD on DAP.** F32 streams apply format conversion that corrupts DoP markers. I32 passes raw bit patterns through AAudio.
- **DSF sequential blocks** need read-aligned chunks: `(16384 / (block_size * channels)).ceil() * block_size * channels`.
- **CIC decimation** introduces passband droop; the FIR stage compensates via Blackman-windowed lowpass.
- **WavPack DSD detection** is via bit 31 of mode flags, NOT extension. The same `.wv` extension serves DSD and PCM WavPack.
- **Ring buffer is fixed at 480,000 f32 samples** (~2.7s at 176.4k mono, ~170ms at 705.6k stereo). Producers block when full; consumers output silence when empty.
- **DAP native DSD requires real ENCODING_DSD support.** The runtime probe (`DsdAudioTrackManager.isEncodingDsdAvailable`) validates both the `AudioFormat.ENCODING_DSD` constant AND `getMinBufferSize > 0` at DSD64. HiBy DAPs expose the constant but the HAL may reject DSD creation; the probe catches this. Without real support, Native falls back to DoP (carrier-rate PCM with 0x05/0xFA markers) or PCM decimation — the `supports_native_dsd` flag in `DeviceProfile` is `caps || runtime_probe` only, never assumed from `is_dap`.
