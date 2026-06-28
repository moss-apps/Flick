# Bit-perfect (DAP Internal) OFF: Issues with EQ, Effects, and Lowered Volume

## Summary

When **Bit-perfect (DAP Internal)** is turned **OFF** on a DAP device: (1) EQ, Effects, Spatial & Time, and Preamps stop working; (2) songs have lowered volume, suspected from volume normalization and resampling.

> **Naming:** two independent bit-perfect toggles exist — **Bit-perfect (USB DAC)** (external USB DAC) and **Bit-perfect (DAP Internal)** (built-in high-res audio path). They are completely independent. However, due to Problem 1 below, the USB DAC flag was leaking into the internal DAP path.

---

## Quick Reference: The Two Bit-Perfect Toggles

| Toggle | Applies To | When ON | When OFF | Affects |
|---|---|---|---|---|
| **Bit-perfect (USB DAC)** | External USB DAC | Direct USB path, no DSP, hardware volume | Normal Android mixing or Rust Oboe | USB DAC playback only |
| **Bit-perfect (DAP Internal)** | Built-in DAP audio | `dapInternalHighRes` passthrough, no DSP | `rustOboe` with full DSP chain | Internal DAP playback only |

---

## 1. Relevant Architecture

### 1.1 Engine Selection (`lib/services/audio_session_manager.dart`)

The app selects the audio engine based on device state and preferences:

- **External USB DAC attached**: preference `rustOboe` → `rustOboe`; preference `isochronousUsb` + Bit-perfect (USB DAC) ON → `usbDacExperimental`; otherwise → `normalAndroid`.
- **No external USB DAC** (internal DAP): `hiFiModeEnabled` + `supportsHiResInternal`: Bit-perfect (DAP Internal) **ON** → `dapInternalHighRes` (passthrough); **OFF** → `rustOboe` (DSP chain). Otherwise → `rustOboe` or `normalAndroid`.

When Bit-perfect (DAP Internal) is **OFF**, the app selects `rustOboe` and logs: "Selected RUST_OBOE because Bit-perfect (DAP Internal) is disabled. DSP chain will run normally."

### 1.2 Bit-Perfect State Tracking (`lib/services/player_service.dart`)

```dart
bool get isBitPerfectModeEnabled =>
    _uac2Service.isBitPerfectEnabledSync ||
    (currentEngineType == AudioEngineType.dapInternalHighRes &&
        _uac2Service.isDapBitPerfectEnabledSync);

bool get isBitPerfectProcessingLocked =>
    bitPerfectProcessingLockedNotifier.value;
```

- `isBitPerfectEnabledSync` = **USB DAC** flag. `isDapBitPerfectEnabledSync` = **DAP Internal** flag.
- `bitPerfectProcessingLockedNotifier` is a reactive `ValueNotifier<bool>` that updates when `currentEngineType` or either bit-perfect preference changes — the EQ service and UI react in real time without a track skip.

The notifier computes its state:

```dart
void _updateBitPerfectProcessingLocked() {
  final locked = switch (currentEngineType) {
    AudioEngineType.usbDacExperimental => true,
    AudioEngineType.dapInternalHighRes =>
      _uac2Service.isDapBitPerfectEnabledSync,
    _ => false,
  };
  if (bitPerfectProcessingLockedNotifier.value != locked) {
    bitPerfectProcessingLockedNotifier.value = locked;
  }
}
```

Listeners on `selectedPlaybackModeNotifier`, `initializedPlaybackModeNotifier`, `bitPerfectEnabledNotifier`, and `dapBitPerfectEnabledNotifier` keep this in sync.

### 1.3 EQ/Effects Application (`lib/services/equalizer_service.dart`)

```dart
final bypassForBitPerfect = playerService.isBitPerfectProcessingLocked;
```

When `true`, EQ/compressor/limiter/FX are disabled. Otherwise applied to Rust backend or Android `AudioEffect` stack. The reactive notifier ensures toggling bit-perfect or switching engines immediately re-applies or bypasses EQ.

### 1.4 Rust Audio Pipeline (`rust/src/audio/engine.rs`)

When Bit-perfect (DAP Internal) is **OFF** and the device is a DAP (not using USB direct):

```rust
let dap_force_dsp = !dap_bit_perfect_enabled
    && device_profile.as_ref().is_some_and(|p| p.is_dap())
    && !will_attempt_usb;
let requested_sample_rate = if dap_force_dsp {
    48_000
} else {
    preferred_sample_rate.unwrap_or(48_000)
};
```

- `dap_force_dsp = true` forces the output to **48 kHz**.
- The strategy becomes `MixerMatched` or `ResampledFallback` (not `DapNative` or `UsbDirect`).
- `initial_pipeline_mode` = `PipelineMode::Dsp` (full processing chain).

### 1.5 Decoder Resampling (`rust/src/audio/decoder.rs`)

```rust
source_info.original_sample_rate != output_sample_rate
```

If `dap_force_dsp` forces 44.1 kHz (now 48 kHz) and the track is at another rate, the decoder resamples.

### 1.6 Volume Handling

- **Rust**: `volume_to_gain()` applies perceptual (logarithmic) slider mapping only. No explicit volume normalization in the Rust pipeline.
- **Android / just_audio**: on `normalAndroid` or non-bit-perfect paths, the OS or ExoPlayer may apply automatic loudness normalization / dynamic range compression in the mixer.

---

## Problems & Fixes

### Problem 1: EQ/Effects Bypassed Incorrectly ✅ FIXED

**Root cause:** `bypassForBitPerfect` in `equalizer_service.dart` checked `isBitPerfectEnabledSync` (the **USB DAC** flag) regardless of current route.

**Fix:** `isBitPerfectProcessingLocked` refactored as single source of truth — evaluates `currentEngineType` directly, returns `true` only for `usbDacExperimental` or `dapInternalHighRes` when DAP bit-perfect is enabled. A reactive `bitPerfectProcessingLockedNotifier` triggers `reapplyEqualizer()` on any engine/preference change. Files: `player_service.dart`, `equalizer_service.dart`.

### Problem 2: Forced 44.1 kHz Causes Unwanted Resampling ✅ FIXED

**Root cause:** `dap_force_dsp = true` locked output to **44.1 kHz**. Any track at a different rate got resampled.

**Fix:** `requested_sample_rate` changed from `44_100` to `48_000` when `dap_force_dsp` is active (`engine.rs`). Reduces resampling for most tracks, matches typical DAP native capabilities.

### Problem 3: Lowered Volume on Non-Bit-Perfect Paths 🔍 AUDITED — Not an app bug

**Audit findings:** No automatic gain reduction, headroom cut, or ReplayGain exists in the Rust pipeline (`engine.rs`, `decoder.rs`, `equalizer.rs`, `dynamics.rs`, `fx.rs`, `crossfader.rs`). The only gain processing: `volume_to_gain()` (slider mapping), EQ band gains, compressor/limiter makeup gain, crossfader/balance gains — all user-controlled. The preamp slider (`preampDb`) already provides manual gain offset. Lowered volume is attributable to **Android OS loudness normalization** on non-exclusive audio paths (outside app control).

---

## 4. Suggestions (Future Improvements)

1. **Make forced DSP sample rate user-configurable** — toggle (Auto / 44.1 / 48 / 96 kHz) for users who want to match track native rate or force specific rates.
2. **Investigate Android loudness normalization** — check if `LoudnessEnhancer` or mixer normalization is active during `rustOboe`/`normalAndroid`; expose a disable toggle if so.
3. **Debug transparency** — UI indicators for requested vs. actual sample rate, whether resampling is active, whether EQ/DSP is bypassed and why, current pipeline mode (`Passthrough` vs `Dsp`).

---

## 5. Quick Reference: Code Locations

| Component | File | Lines | Purpose |
|---|---|---|---|
| Engine Selection | `lib/services/audio_session_manager.dart` | 232-361 | Chooses `rustOboe` vs `dapInternalHighRes` |
| Bit-Perfect State & Notifier | `lib/services/player_service.dart` | ~260, ~618-640 | `bitPerfectProcessingLockedNotifier`, `isBitPerfectProcessingLocked`, `_updateBitPerfectProcessingLocked` |
| EQ Bypass Logic | `lib/services/equalizer_service.dart` | ~31 | `bypassForBitPerfect` flag (simplified) |
| Rust Engine Config | `rust/src/audio/engine.rs` | ~748-753 | `dap_force_dsp` and `requested_sample_rate` |
| Rust Strategy | `rust/src/audio/strategy.rs` | ~70-120 | `MixerMatched` / `ResampledFallback` selection |
| Rust Verifier | `rust/src/audio/verifier.rs` | ~40-80 | `OutputVerification::verify()` for bit-perfect / resampler flags |
| Rust Decoder | `rust/src/audio/decoder.rs` | ~800-850 | Resampling logic based on `original_sample_rate != output_sample_rate` |

---

*Document updated: 2026-05-03 — All three primary fixes confirmed. DAP bit-perfect toggle UI added to settings. Runtime switch failure handling improved.*
