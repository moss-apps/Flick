# DAC/DAP Extensibility Guide

This document describes how Flick Player's audio backend supports different output
types (USB DACs, DAPs, network DACs, etc.) and how to add support for new ones.

## Architecture Overview

Audio output selection follows a layered architecture:

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

### Key Abstractions

| Layer | Component | Purpose |
|-------|-----------|---------|
| Rust | `BackendType` enum | Categorizes output types (UsbDirect, DapNative, etc.) |
| Rust | `BackendDescriptor` struct | Describes backend capabilities (passthrough, sample rate, priority) |
| Rust | `AudioBackend` trait | Streaming lifecycle (start/stop/is_active/name/descriptor) |
| Rust | `BackendCandidate` + scoring | Data-driven strategy selection |
| Rust | `DapSignature` + `DAP_REGISTRY` | Data-driven DAP brand detection |
| Dart | `AudioEngineType` enum | Flutter-side engine selection, maps to BackendType |
| Android | Capability strings | Kotlin reports "usbDac"/"hiResInternal"/"standard" to Rust |

## Adding a New DAP Brand

To add a new DAP brand (e.g., "Cayin N3"), add a `DapSignature` entry to
`DAP_REGISTRY` in `rust/src/audio/device.rs`:

```rust
DapSignature {
    id: "cayin",                // Unique identifier (lowercase)
    label: "Cayin",             // Display name
    keywords: &["cayin"],       // Manufacturer/brand keyword matchers
    model_prefixes: &["N3", "N5", "N6", "N7"],  // Known model prefixes
    manufacturer_sufficient: true,  // true if keyword match alone confirms DAP
}
```

Then update the Dart keyword list in
`lib/services/android_audio_device_service.dart` (`isLikelyDap` getter) to
include the brand keyword (e.g., `"cayin"`). The Dart list should match the
Rust `keywords` fields.

### manufacturer_sufficient

Set `manufacturer_sufficient: true` when a brand keyword match is sufficient to
identify the device as a DAP (not a phone). For Sony, set `false` because Sony
also makes phones — the model prefix (NW-A, NW-WM, NW-ZX) must also match.

## Adding a New Output Strategy

To add a new output type (e.g., network DAC, Bluetooth LDAC passthrough):

### 1. Rust: Add BackendType variant

In `rust/src/audio/backend.rs`, add to `BackendType`:
```rust
pub enum BackendType {
    UsbDirect,
    DapNative,
    MixerBitPerfect,
    MixerMatched,
    ResampledFallback,
    NetworkDac,  // new
}
```

Also add to `rust/src/audio/strategy.rs` `OutputStrategy`:
```rust
pub enum OutputStrategy {
    // ...existing variants
    NetworkDac,  // new
}
```

And add the `From` conversion between them.

### 2. Rust: Add scoring function and candidate

In `rust/src/audio/strategy.rs`:

```rust
fn score_network_dac(device: &DeviceCaps, track: &TrackInfo) -> Option<u8> {
    if device.network_dac_available && track.channels > 0 {
        Some(75)  // Between USB direct (70) and mixer bit-perfect (80)
    } else {
        None
    }
}
```

Add to `DEFAULT_CANDIDATES`:
```rust
BackendCandidate { backend_type: BackendType::NetworkDac, scorer: score_network_dac },
```

### 3. Rust: Add capability detection

Add the capability field to `DeviceCaps` and detect it in
`detect_capabilities_blocking()` or the appropriate detection path.

### 4. Rust: Add engine creation logic

In `rust/src/audio/engine.rs`, add a match arm for the new strategy in
`create_audio_engine()` and `android_output_signature_for_strategy()`.

### 5. Rust: Update verifier

In `rust/src/audio/verifier.rs`, add the new strategy to
`resolved_strategy()` match arms.

### 6. Dart: Add engine type

Add to `AudioEngineType` enum and update switches in session manager,
player service, etc.

## Output Strategy Priority

Strategies are scored and the highest-scoring eligible strategy wins:

| Strategy | Score | Condition |
|----------|-------|-----------|
| DapNative | 100 | Confirmed DAP device with internal high-res path |
| MixerBitPerfect | 80 | Android 14+ with mixer bit-perfect support |
| UsbDirect | 70 | Direct USB path available and verified |
| MixerMatched | 60 | Device supports requested sample rate via mixer |
| ResampledFallback | 10 | Always available |

Custom candidates can override this priority — see
`select_strategy_with_candidates()`.

## DAP Registry

The DAP registry in `rust/src/audio/device.rs` contains the following brands:

| ID | Label | Keywords | Model Prefixes | Sufficient |
|----|-------|----------|----------------|------------|
| fiio | FiiO | fiio | M11, M15, M17, M21, M23, M27, JM21, M0-M8 | yes |
| ibasso | iBasso | ibasso | DX160-DX340 | yes |
| hiby | HiBy | hiby | R3, R4, R5, R6, R8 | yes |
| shanling | Shanling | shanling | M300 | yes |
| astellkern | Astell&Kern | astell, iriver | SA, SP, SE, A& | yes |
| cayin | Cayin | cayin | N3, N5, N6, N7 | yes |
| sony | Sony | sony | NW-A, NW-WM, NW-ZX | no |
| tempotec | TempoTec | tempotec | V6, S3, Mobi, Sonata, iDSD | yes |
| luxury_precision | Luxury & Precision | luxury, luxuryprecision | P6 | yes |

## Recommended DACs/DAPs

### USB DACs (Bit-Perfect via UAC 2.0)

| Device | Max Rate | Max Bits | Volume | Notes |
|--------|----------|----------|--------|-------|
| MOONDROP Dawn Pro | 384 kHz | 32-bit | Hardware | Dual CS43131, 4.4mm balanced, daily driver |
| FiiO K5 Pro | 384 kHz | 32-bit | Hardware | Excellent compatibility |
| Topping D10s | 384 kHz | 32-bit | Software | All features work |
| Schiit Modi 3+ | 192 kHz | 24-bit | Software | Stable operation |
| iFi Zen DAC | 384 kHz | 32-bit | Software | DSD support |

### DAPs (Bit-Perfect Internal DAC)

| Device | Max Rate | Balanced | Detection | Notes |
|--------|----------|----------|-----------|-------|
| FiiO M11/M15/M17 | 384 kHz | Yes (4.4mm) | Automatic | Mango mode supported |
| iBasso DX160-DX340 | 384 kHz | Yes (4.4mm) | Automatic | Mango mode supported |
| HiBy R3/R5/R6/R8 | 384 kHz | Select models | Automatic | — |
| Shanling M300 | 384 kHz | No | Automatic | — |
| Astell&Kern SP/SA/SE | 384 kHz | Yes (2.5/4.4mm) | Automatic | — |
| Cayin N3/N5/N6/N7 | 384 kHz | Yes (4.4mm) | Automatic | — |
| Sony NW-A/NW-WM/NW-ZX | 384 kHz | Select models | Model-dependent | Sony phones excluded |
| TempoTec V6/S3 | 384 kHz | No | Automatic | — |
| Luxury & Precision P6 | 384 kHz | No | Automatic | — |

### Recommended Settings

- **USB DAC**: Enable "Bit-perfect (USB DAC)" mode in audio settings
- **DAP Internal**: Enable "Bit-perfect (DAP Internal)" for passthrough mode
- **iBasso DAPs**: Use "Mango Mode" for exclusive audio path
- **High-res content**: Ensure sample rate matches source file for true bit-perfect

## File Reference

| File | Purpose |
|------|---------|
| `rust/src/audio/device.rs` | DAP signature registry, device classification |
| `rust/src/audio/strategy.rs` | BackendCandidate scoring, strategy selection |
| `rust/src/audio/backend.rs` | BackendType, BackendDescriptor, AudioBackend trait |
| `rust/src/audio/engine.rs` | Engine creation per strategy |
| `rust/src/audio/verifier.rs` | Output verification |
| `rust/src/audio/manager.rs` | Capability detection, engine lifecycle |
| `lib/models/audio_engine_type.dart` | Flutter engine type enum |
| `lib/services/audio_session_manager.dart` | Mode resolution logic |
| `lib/services/android_audio_device_service.dart` | DAP keyword detection (Dart) |
| `android/.../MainActivity.kt` | USB device management, capability reporting |