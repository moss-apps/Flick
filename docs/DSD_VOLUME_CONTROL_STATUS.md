# DSD Volume Control — Status & Investigation Log

**Last updated:** 2026-05-24
**Status:** DSD PCM decimation still produces silence after initial "tic"

## Problem Statement

DSD64 `.dsf`/`.dff` plays correctly in **Force DoP** mode at 176,400 Hz / 24-bit. In **PCM decimation** mode (Auto/PCM), output is a brief "tic" then silence. This blocks the volume control fallback: DoP can't apply software gain (corrupts 0x05/0xFA markers), and hardware SET_CUR is ignored by the DAC during DSD mode.

## Hardware

- **DAC:** MOONDROP Dawn Pro (USB-C)
- **Transport:** Direct USB (Android, `android-uac2` backend)
- **Verified rates:** 176,400 Hz / 24-bit works (DoP carrier)

## Architecture Overview

```text
DSD file → DsdDecoderThread → DsdOutputRouter
  ├── PcmDecimation: DsdDecimationPipeline (CIC + FIR) → f32 PCM samples
  └── Dop:           DopPacker (0x05/0xFA markers)      → f32 DoP frames

Output → AudioSource ring buffer → AudioCallbackData → USB DAC
```

## Key Files

| File | Role |
|------|------|
| `rust/src/audio/dsd_engine/dsd/mod.rs` | `DsdDecimationPipeline` — CIC + FIR two-stage decimation |
| `rust/src/audio/dsd_engine/dsd/dop.rs` | `DopPacker` — DoP frame packing with markers |
| `rust/src/audio/dsd_engine/dsd/coefficients.rs` | `generate_lowpass_fir` — Blackman-windowed sinc filter |
| `rust/src/audio/dsd_engine/dsd_thread.rs` | `DsdDecoderThread` — decoder loop, `DsdOutputRouter` construction |
| `rust/src/audio/dsd_engine/output/mod.rs` | `DsdOutputRouter` — routes to pipeline or DoP packer |
| `rust/src/audio/engine.rs` | `audio_callback`, `handle_seek`, `spawn_decoder` |
| `rust/src/api/audio_api.rs` | `audio_play`, `audio_queue_next`, engine initialization |
| `rust/src/audio/manager.rs` | `EngineManager` — engine lifecycle, rate negotiation |
| `lib/services/player_service.dart` | Volume control, `_switchDoPForVolumeTrack` |
| `lib/services/uac2_preferences_service.dart` | `autoSwitchDsdForVolume` preference |
| `lib/services/rust_audio_service.dart` | Dart→Rust bridge for volume/seek |

## Changes Made So Far

### 1. Volume Control Infrastructure (completed)
- Added `isCurrentTrackDoP` getter in `player_service.dart:761`
- Added DoP hardware volume path in `setVolume()` routing through `_uac2Service.setVolume()` (SET_CUR)
- Added `autoSwitchDsdForVolume` preference with ValueNotifier + SharedPreferences persistence
- Added `_switchDoPForVolumeTrack()` — persists PCM mode, syncs Rust global, seeks to restart decoder
- DoP path in `setVolume()` checks `autoSwitchDsdForVolumeSync` and calls `_switchDoPForVolumeTrack()` when volume < 1.0

### 2. CIC Decimation Fix (completed)
- Replaced fixed `const CIC_DECIMATION = 8` with dynamic `cic_decimation` field
- `compute_cic_decimation()` finds largest divisor ≤ 8 of total decimation ratio
- Prevents assertion panic on non-power-of-8 ratios

### 3. DSD PCM Target Rate Alignment (completed — didn't fix silence)
- Added `DsdRate::pcm_decimation_targets()` — valid integer-divisor target rates per DSD rate:
  - DSD64: [176400, 88200, 44100]
  - DSD128: [352800, 176400, 88200, 44100]
  - DSD256: [705600, 352800, 176400, 88200]
  - DSD512: [705600, 352800, 176400, 88200]
- Added `DsdRate::best_pcm_target(engine_rate)` — picks nearest valid target
- Added `resolve_dsd_pcm_sample_rate()` helper
- Updated `DsdDecoderThread::spawn_with_seek` to use `best_pcm_target(target_rate)` for PCM mode
- Updated `DsdOutputRouter` construction to use resolved rate
- Added `resolve_dsd_engine_sample_rate()` in `audio_api.rs` — probes DSD file, computes correct engine rate
- Updated `audio_play` and `audio_queue_next` DSD paths to initialize engine at correct rate

### 4. Rejected Approaches
- **DSD byte-level popcount scaling** — produces audible hiss (destroys noise shaping)
- **Sigma-delta remodulation** — produces audible hiss
- **Float gain on DoP frames** — corrupts 0x05/0xFA markers → hiss/silence
- **Naive DSD software volume** — fundamentally broken for 1-bit sigma-delta streams

## Current Symptom

When playing a DSD64 track in PCM decimation mode (Auto or Force PCM):
- A brief "tic" is heard (first few samples make it through)
- Then complete silence for the rest of the track
- No errors in logs
- DoP mode works perfectly for the same file

## Decimation Pipeline Details (DSD64 → 176,400 Hz)

With the target rate alignment fix, the pipeline for DSD64 → 176,400 Hz PCM should be:
- **DSD bit rate:** 2,822,400 Hz
- **Target:** 176,400 Hz
- **Total decimation:** 16 (exact integer)
- **CIC stage:** 8x decimation, order 3
  - Input: DSD bytes → popcount → [-8, +8] float per byte
  - Output at 352,800 Hz (2,822,400 / 8)
- **FIR stage:** 2x decimation, 64 taps
  - Input: 352,800 Hz CIC output
  - Output: 176,400 Hz PCM
  - Cutoff: 0.25 (88,200 / 352,800)
  - Window: Blackman

For DSD64 → 88,200 Hz:
- **Total decimation:** 32
- **CIC:** 8x → 352,800 Hz intermediate
- **FIR:** 4x → 88,200 Hz
- **Cutoff:** 0.125

## Investigation Log

1. **Is the pipeline producing non-zero samples?** Add logging to `DsdDecimationPipeline::process_bytes` — check if CIC integrators are saturating/wrapping, if FIR coefficient sum is normalized.
2. **Is the ring buffer being fed correctly?** Verify `write_to_ring_buffer` receives non-empty output; check if producer is blocked/stopped prematurely.
3. **Is the callback consuming from the right source?** The "tic" suggests the first buffer makes it through, then nothing. Could be rate mismatch between `SourceInfo.output_sample_rate` (set to resolved PCM target) and engine callback rate.
4. **Rate renegotiation with the USB DAC?** Switching from DoP (`transport=PCM/24/3`) to PCM decimation (`transport=PCM/32/4`) changes bit depth and channel count. The DAC may need re-initialization for the new format.
5. **USB backend re-initialization?** The output signature may not change, so `ensure_rust_engine` might reuse the old engine (configured for DoP 24-bit/3 bytes per frame) instead of re-creating for PCM decimation (32-bit float/4 bytes). May need `reconfigure_sample_rate` or full engine recreation.
6. **Engine prewarm rate conflict.** Transitioning from PCM (e.g. 44.1 kHz) to DSD, the engine prewarms at DSD target rate. If the previous track's decoder is still running, the callback may consume at the wrong rate. Error: `Unhandled Exception: Rust audio engine is not initialized`.

## Next Steps

1. **Diagnostic logging** on `DsdDecimationPipeline::process_bytes`: first output sample values, CIC integrator values, FIR coefficient sum.
2. **Ring buffer flow**: `output_buf.len()` after `process_dsd_bytes`, `samples_written` in `write_to_ring_buffer`.
3. **Transport comparison** (DoP vs PCM): `PCM/24/3` vs `PCM/32/4` — USB backend may need re-creation when transport format changes.
4. **Standalone pipeline test**: feed known DSD bytes to `DsdDecimationPipeline` in a unit test; verify non-zero PCM output.
5. **USB direct backend format renegotiation**: force engine recreation (new output signature) when switching DSD modes.
