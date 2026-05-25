# DSD / DSF / DFF / WavPack Playback Architecture

## Overview

Flick Player supports four DSD-related formats through a unified DSD engine:

| Format | Extension | Container | Source |
|--------|-----------|-----------|--------|
| **DSF** (DSD Stream File) | `.dsf` | Sony DSD container | `dsf_meta` crate |
| **DFF** (DSD Interchange File) | `.dff` | Philips DSD container | `dff_meta` crate |
| **WavPack DSD** | `.wv` | WavPack with DSD content | `wavpack-sys` C bindings |
| **WavPack PCM** | `.wv` | WavPack with lossless PCM | `wavpack-sys` C bindings |

The engine provides two output modes for DSD content:
- **PCM Decimation** — converts DSD bitstream to integer-multiple PCM rates (44.1k–705.6k) via a software CIC+FIR decimator. Works on any output device.
- **DoP** (DSD over PCM) — packs raw DSD bits into 24/32-bit PCM frames with 0x05/0xFA marker bytes. Requires a DoP-capable DAC.

---

## 1. File Detection and Routing

**`rust/src/audio/decoder_handle.rs:49-67`**

```rust
enum FileType { Standard, Dsd, WavPack }
```

`detect_file_type()` routes by extension:
- `.dsf`, `.dff` → `FileType::Dsd`
- `.wv` → probes via `is_wavpack_dsd()` (bit 31 of WavPack mode flags). DSD WavPack → `FileType::Dsd`, PCM WavPack → `FileType::WavPack`
- Everything else → `FileType::Standard` (Symphonia decoder)

**`rust/src/audio/engine.rs:2024-2061`** — `spawn_decoder()` maps `FileType` to the correct decoder handle:

```
FileType::Dsd    → DsdDecoderThread
FileType::WavPack → WavpackDecoderThread (PCM), or DsdDecoderThread (DSD)
FileType::Standard → DecoderThread (Symphonia)
```

---

## 2. Format Decoders

All DSD format decoders implement the **`DsdFormatDecoder`** trait:
**`rust/src/audio/dsd_engine/format/mod.rs:14-23`**

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
}
```

**`open_dsd_decoder()`** at `format/mod.rs:25-46` dispatches by extension:

### 2.1 DSF Decoder (`format/dsf_decoder.rs`)

DSF stores DSD data as **sequential channel blocks**: all bytes for channel 0, then all bytes for channel 1, etc. Each block is `block_size` bytes (typically 4096).

- Parses header via `dsf_meta::DsfFile`
- Reports `DsdChannelLayout::SequentialBlocks { block_size }`
- Seek: aligns to block boundaries (`sample / block_size`)
- No deinterleaving needed at the format layer

### 2.2 DFF Decoder (`format/dff_decoder.rs`)

DFF stores DSD data **interleaved**: one byte per channel per frame, cycling through all channels.

- Parses header via `dff_meta::DffFile`
- Reports `DsdChannelLayout::Interleaved`
- Seek: byte-level (`sample / 8 * channels`)
- The thread layer handles deinterleaving (see section 4)

### 2.3 WavPack DSD Decoder (`format/wavpack_decoder.rs`)

WavPack files containing DSD content are opened via `wavpack-sys` with `OPEN_DSD_NATIVE` (0x100). This flag tells wavpack-sys to return the raw DSD bitstream instead of decoding to PCM.

- **Detection** (`wavpack_thread.rs:13-36`): Bit 31 of `WavpackGetMode()` (`0x80000000`) indicates DSD content
- `read_dsd_bytes()` calls `WavpackUnpackSamples()` and truncates i32 samples to `u8`
- Reports `DsdChannelLayout::Interleaved`
- Uses `WavpackSeekSample64` for seeking

---

## 3. DSD Output Router

**`rust/src/audio/dsd_engine/output/mod.rs`**

The `DsdOutputRouter` routes raw DSD bytes to one of two processors depending on `DsdOutputMode`:

```
dsd_bytes ──→ DsdOutputRouter
                  │
                  ├── PcmDecimation → DsdDecimationPipeline (CIC+FIR)
                  │     → interleaved f32 PCM samples
                  │
                  └── Dop → DopPacker
                        → f32 samples with 0x05/0xFA markers
```

The router is created once per track in `DsdDecoderThread::spawn()` at `dsd_thread.rs:73`.

---

## 4. DSD Decoder Thread

**`rust/src/audio/dsd_engine/dsd_thread.rs`**

The `dsd_decode_thread()` function runs on a dedicated background thread. The main loop:

1. Read raw DSD bytes from the format decoder (`decoder.read_dsd_bytes()`)
2. **Deinterleave** if needed (DFF, WavPack DSD — interleaved layout):
   - `deinterleave_dsd()` at `dsd_thread.rs:219-234` rearranges `[C0F0, C1F0, C0F1, C1F1]` → `[C0F0, C0F1, C1F0, C1F1]`
   - DSF (sequential blocks) skips this
3. Pass through `output_router.process_dsd_bytes()`
4. Write resulting f32 samples to the ring buffer via `write_to_ring_buffer()`

The read chunk size is 16,384 bytes, aligned to channel-block boundaries for DSF.

---

## 5. PCM Decimation Pipeline

**`rust/src/audio/dsd_engine/dsd/mod.rs:86-245`**

Software decimation from DSD bitrate to PCM standard rates. Two stages:

### Stage 1: CIC Decimation

- **3rd-order CIC** integrator (`CIC_ORDER = 3`)
- Input: DSD bytes (each byte = 8 one-bit samples)
  - `bit_sum = (popcount(byte) * 2.0) - 8.0` (maps to -8..+8)
- Cascaded integrators at input, difference at output
- Decimation factor computed automatically to reach target PCM rate, max 8x
- If total decimation isn't evenly divisible, CIC=1 and FIR handles it all

### Stage 2: FIR Anti-Alias Filter

- **64-tap** Blackman-windowed sinc lowpass (`coefficients.rs`)
- Cutoff = `target_pcm_rate / 2 / intermediate_rate`
- Coefficients normalized to DC gain = 1.0
- One filter state per channel, rotated each FIR step

### Decimation Targets

| DSD Rate | Byte Rate | PCM Targets (Hz) |
|----------|-----------|-------------------|
| DSD64 (2.8M) | 352.8k | 176.4k, 88.2k, 44.1k |
| DSD128 (5.6M) | 705.6k | 352.8k, 176.4k, 88.2k, 44.1k |
| DSD256 (11.3M) | 1.41M | 705.6k, 352.8k, 176.4k, 88.2k |
| DSD512 (22.6M) | 2.82M | 705.6k, 352.8k, 176.4k, 88.2k |

All targets are integer subdivisions of 44.1k × 64 (the DSD base clock).

### FIR Coefficient Generation (`coefficients.rs`)

```rust
generate_lowpass_fir(num_taps, input_rate, output_rate) → Vec<f64>
```

Supports three windows: Blackman (default), Hamming, and Kaiser. Coefficients are generated once via `OnceLock` and reused. The Bessel I0 function for Kaiser windows is computed via series expansion.

---

## 6. DoP (DSD over PCM) Packer

**`rust/src/audio/dsd_engine/dsd/dop.rs`**

The DoP standard encodes DSD data inside PCM frames. Each PCM sample carries one DSD channel of data plus an 8-bit marker byte.

### Marker Protocol

Markers alternate per frame: `0x05` → `0xFA` → `0x05` → ...

A DoP DAC detects these markers to identify the stream as DoP-encoded DSD rather than regular PCM. Without markers, the stream looks like high-gain noise.

### Frame Layout

| DSD Rate | PCM Depth | DSD Bits/Frame | DSD Bytes/Frame/Ch | Carrier Rate |
|----------|-----------|----------------|---------------------|--------------|
| DSD64 | 24-bit | 16 | 2 | 176.4 kHz |
| DSD128 | 24-bit | 16 | 2 | 352.8 kHz |
| DSD256 | 24-bit | 16 | 2 | 705.6 kHz |
| DSD512 | 32-bit | 24 | 3 | 705.6 kHz |

**DSD64 24-bit frame** (2 bytes DSD + 1 marker byte, per channel):
```
byte 0: 0x05 (marker)
byte 1: DSD channel byte 0
byte 2: DSD channel byte 1
→ encoded as f32 via bit_cast (u32 interpretation)
```

**DSD512 32-bit frame** (3 bytes DSD + 1 marker byte, per channel):
```
byte 0: 0x05/0xFA (marker)
byte 1: DSD channel byte 0
byte 2: DSD channel byte 1
byte 3: DSD channel byte 2
→ encoded as f32 via bit_cast
```

### Packing (`DopPacker::pack_to_f32()`)

For each frame and each channel:
1. Build 24/32-bit value: `marker_byte << dsd_data_bits | dsd_bytes`
2. Cast bit pattern to f32: `f32::from_bits(sample)`
3. Advance marker state (toggle 0x05 ↔ 0xFA)

The f32 values are treated as opaque bit containers — they are never used as actual floating-point audio. The DAC reads the raw PCM sample bytes.

---

## 7. WavPack PCM Decoder Thread

**`rust/src/audio/wavpack_thread.rs`**

For non-DSD `.wv` files (standard WavPack lossless compression):

1. Open file via `wavpack-sys` (no `OPEN_DSD_NATIVE` flag)
2. Guard: reject DSD WavPack files (they must use the DSD pipeline)
3. Read WavPack properties: sample rate, channels, bits per sample, float mode
4. **Decode loop:**
   - `WavpackUnpackSamples()` → i32 samples (4,096 frames per chunk)
   - Convert to f32: float WavPack uses `f32::from_bits()`; integer uses `sample / scale`
   - Scale factors: 8-bit=128, 16-bit=32768, 24/32-bit=2147483648
5. **Channel remix** (`remix_channels()`): handles mismatch between file channels and output channels (downmix to mono, upmix from mono)
6. **Resampling** via `AudioResampler` (Rubato-based) if file rate ≠ output rate
7. Flush resampler tail after EOF
8. Write to ring buffer

The thread uses the same `write_to_ring_buffer()` back-pressure loop as the DSD thread.

---

## 8. Integration with the Audio Engine

### 8.1 Pipeline Modes

**`rust/src/audio/engine.rs:70-74`**

```rust
enum PipelineMode {
    Passthrough = 0,  // No DSP, gain only (bit-perfect path)
    Dsp = 1,          // Full processing chain
    Dop = 2,          // DoP passthrough (no gain, no DSP)
}
```

### 8.2 Audio Callback Path for DoP

**`engine.rs:1488-1516`**

When `PipelineMode::Dop` is active:
1. Read samples directly from `SourceProvider` (ring buffer consumer)
2. Write to output without **any** processing — no gain, no EQ, no dynamics, no crossfade
3. The f32 samples are opaque DoP bit containers, forwarded as-is to the DAC

This is critical: applying gain or DSP to DoP-packed f32 values would corrupt the marker bytes and DSD data, making the stream unreadable by the DAC.

### 8.3 DoP Override

**`engine.rs:1901-1909`** — `SetDopOverride` switches pipeline mode:
- `is_dop = true` → mode set to `Dop`
- `is_dop = false` → mode restored to `Dsp` or `Passthrough`

### 8.4 Gapless Playback

All decoder threads use the same ring-buffer-based `SourceProvider`. When a new track starts:
- `handle_play_prepared()` sets the new source as current
- `handle_queue_next_prepared()` queues it as "next" for gapless transition
- The audio callback detects old source completion and sends `AudioEvent::TrackFinished`

### 8.5 Thread Model

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

---

## 9. Platform-Specific Output

### Non-Android (cpal)
Always uses `PipelineMode::Dsp`. DoP transport is not supported via cpal — the f32 samples are played as literal PCM (silence/garbage). PCM decimation mode must be used.

### Android Oboe (Managed)
- Stereo f32 stream at device sample rate
- Strategy selection picks the best backend from: `DsdNative`, `DapNative`, `MixerBitPerfect`, `DsdDoP`, `UsbDirect`, `MixerMatched`, `ResampledFallback`
- DoP: pipeline mode set to `Dop`; carrier rate negotiated with DAC

### Android USB Direct (UAC2)
- DoP format negotiation via UAC2 descriptors
- `AndroidDirectUsbPlaybackFormat.is_dop` flag
- DoP sample encoding uses `encode_dop_slots()` in `uac2/android_direct.rs:5904`
- Pipeline mode: `Passthrough` for bit-perfect verified, `Dop` for DoP transport
- Device classifier checks for `FORMAT_TAG_DSD = 0x0008` and `FormatType::Dsd`

---

## 10. Settings and User Preferences

**`lib/services/uac2_preferences_service.dart`**

| Setting | Key | Description |
|---------|-----|-------------|
| DSD Output Mode | `dsd_output_mode` | `auto` / `forcePcm` / `forceDop` |
| Auto-switch DoP → PCM | auto-switch flag | When enabled, activating software volume while in DoP mode triggers a decoder restart in PCM decimation mode |

**Rust bridge:**

- `current_dsd_output_mode()` — reads `DSD_OUTPUT_MODE` atomic (0=PCM, 1=DoP)
- `audio_set_dsd_output_mode(mode: u8)` — writes the atomic

**DoP volume constraint** (`player_service.dart:3682-3707`):
- DoP bypasses software gain (volume is no-op in `PipelineMode::Dop`)
- When software volume is needed (e.g. no hardware volume on DAC), the player auto-switches to PCM decimation mode

---

## 11. Data Flow Summary

```
File (.dsf/.dff/.wv)
    │
    ▼
detect_file_type() ─── FileType::Dsd
    │
    ▼
open_dsd_decoder() ─── Box<dyn DsdFormatDecoder>
    │                        │
    │              ┌─────────┼──────────┐
    │              │         │          │
    │          DsfDecoder  DffDecoder  WavpackDsdDecoder
    │          (sequential) (intrlvd)  (wavpack-sys)
    │
    ▼
DsdDecoderThread::spawn()
    │
    ├── DsdRate::from_sample_rate(decoder.sample_rate())
    ├── DsdOutputRouter::new(mode, dsd_rate, target, channels)
    │       │
    │       ├── PcmDecimation → DsdDecimationPipeline { CIC(3) + FIR(64) }
    │       └── Dop → DopPacker { 0x05/0xFA markers, 24/32-bit frames }
    │
    ├── AudioSource + SourceProducer (ring buffer, 480k samples)
    │
    ▼
dsd_decode_thread() [background thread]
    │
    loop:
    ├── decoder.read_dsd_bytes() → raw DSD bytes
    ├── deinterleave (DFF/WavPack only)
    ├── output_router.process_dsd_bytes() → interleaved f32
    └── producer.write(f32 samples)
    
    [ring buffer boundary]
    
audio_callback() [cpal/Oboe/UAC2 thread]
    │
    ├── PipelineMode::Dop → sources.read() → passthrough
    ├── PipelineMode::Passthrough → sources.read() → gain only
    └── PipelineMode::Dsp → sources.read() → crossfade → speed → EQ → fx → dynamics → gain
```

---

## 12. Key Constraints

- **DoP requires bit-perfect passthrough.** Any DSP processing corrupts the markers and DSD data.
- **DSF sequential blocks** need read-aligned chunk sizes: `(16384 / (block_size * channels)).ceil() * block_size * channels`.
- **CIC decimation** introduces passband droop; the FIR stage compensates via Blackman-windowed lowpass.
- **WavPack DSD detection** happens via bit 31 of mode flags, NOT file extension. The same `.wv` extension serves both DSD and PCM WavPack.
- **Ring buffer is fixed at 480,000 f32 samples** (~2.7 seconds at 176.4k mono, ~170ms at 705.6k stereo). Producers block when full; consumers output silence when empty.
