# Native DSD via C++ ALSA Backend — Planning Document

## Problem

The HiBy R4's HAL does not expose `AudioFormat.ENCODING_DSD` through the public
Android AudioTrack API. Our probe (`DsdAudioTrackManager.isEncodingDsdAvailable`)
builds an ENCODING_DSD AudioTrack at 2,822,400 Hz — it throws on the R4. Native
DSD falls back to DoP.

Meanwhile, other music players on the same device (HiBy Music, UAPP, Neutron)
deliver native DSD to the internal DAC. They are not using `AudioTrack.ENCODING_DSD`.

## Root Cause

Android's audio stack:

```
App → AudioTrack/AAudio → AudioFlinger → Audio HAL → ALSA driver → DAC
```

`ENCODING_DSD` is an AudioFlinger/HAL contract. HiBy's custom HAL doesn't register
DSD as a supported encoding for the built-in output device through this path. But
the underlying **ALSA kernel driver does support DSD** — it has to, because the DAC
chip (ESS/Cirrus) requires a DSD bitstream.

Other players bypass layers 2–3 (AudioTrack → AudioFlinger → Audio HAL) and talk
directly to the ALSA driver:

```
App → tinyalsa → /dev/snd/pcmDxp → DAC
```

This is the "magic."

## Proposed Solution: C++ Native DSD Output Backend ("libdsd")

A small C++ library compiled via NDK that opens the ALSA playback device directly,
configures it for DSD format, and writes raw DSD bytes. No AudioTrack, no
AudioFlinger, no HAL negotiation.

### Why C++ and not Rust?

| Factor | Rust | C++ |
|--------|------|-----|
| tinyalsa linkage | FFI overhead, manual bindings | Direct `#include <tinyalsa/pcm.h>` |
| NDK CMake integration | Requires cargo-ndk cross-compilation | Native CMake, zero friction |
| ALSA/tinyalsa ecosystem | Bindings are incomplete/stale | First-class, header-only available |
| Existing project | Rust engine already handles decode + PCM output | C++ only for DSD output path |
| Other players' approach | N/A — they all use C/C++ | Industry standard for this task |

**Scope:** C++ replaces only the DSD **output** path. Rust keeps DSD **decoding**
(DSF/DFF/WavPack → raw DSD bytes) and all PCM output.

### Architecture

```
┌─────────────────────────────────────────┐
│  Flutter (Dart)                         │
│  └─ player_service.dart                 │
└──────────────┬──────────────────────────┘
               │ FFI (flutter_rust_bridge)
┌──────────────▼──────────────────────────┐
│  Rust Engine (existing)                 │
│  ├─ DSD Decoder (DSF/DFF → DSD bytes)   │  ← UNCHANGED, works fine
│  ├─ PCM Output (Oboe/AudioTrack)        │  ← UNCHANGED, works fine
│  └─ DSD Output Strategy                 │
│     ├─ Strategy: DsdNative              │
│     │   └─ DsdNativeBackend::start()    │
│     │      ├─ Try: ENCODING_DSD (JNI)   │  ← fails on R4
│     │      └─ Try: ALSA Direct (NEW)    │  ← NEW FALLBACK
│     │           ↓ JNI                   │
│     └─ Strategy: DsdDoP / PCM           │  ← existing fallbacks
└──────────────┬──────────────────────────┘
               │ JNI
┌──────────────▼──────────────────────────┐
│  C++ libdsd (NEW)                       │
│  ├─ dsd_alsa_output.cpp                 │
│  │   ├─ open(card, device, format, rate)│
│  │   ├─ write(dsd_bytes)                │
│  │   └─ close()                         │
│  └─ CMakeLists.txt                      │
│         ↓ links                          │
│    libtinyalsa (Android system lib)     │
└──────────────┬──────────────────────────┘
               │
         /dev/snd/pcmDxp → DAC chip → analog out
```

### Data Flow

1. Rust decodes DSF/DFF → raw DSD bytes (existing, works)
2. Rust strategy selects `DsdNative`
3. Rust calls JNI to C++ `dsd_alsa_open(card, device, rate, channels)`
4. C++ opens `/dev/snd/pcmDxp` via tinyalsa, configures DSD format
5. Rust audio callback pushes DSD byte chunks via JNI `dsd_alsa_write(bytes)`
6. C++ writes directly to ALSA driver → DAC receives raw DSD bitstream
7. On stop/interrupt: JNI `dsd_alsa_close()`

### ALSA DSD Format Constants

The ALSA DSD formats (from `<sound/asound.h>` in the Linux kernel):

```c
SND_PCM_FORMAT_DSD_U8          = 0x150   // DSD, 1-byte samples, 1 bit used
SND_PCM_FORMAT_DSD_U16_LE      = 0x151   // DSD, 2-byte samples, 1 bit used
SND_PCM_FORMAT_DSD_U32_LE      = 0x152   // DSD, 4-byte samples, 1 bit used
SND_PCM_FORMAT_DSD_U16_BE      = 0x153
SND_PCM_FORMAT_DSD_U32_BE      = 0x154
```

In tinyalsa, these map to:
```c
PCM_FORMAT_DSD_U8
PCM_FORMAT_DSD_U16_LE
PCM_FORMAT_DSD_U32_LE
```

**Which format the R4 uses needs runtime discovery.** Most ESS-based DACs use
`DSD_U8` (raw 1-bit per sample, interleaved L/R). Some Cirrus Logic DACs use
`DSD_U16_LE` or `DSD_U32_LE` (packed multi-bit).

The sample rate for DSD in ALSA is the DSD rate itself:
- DSD64: 2,822,400 Hz
- DSD128: 5,644,800 Hz
- DSD256: 11,289,600 Hz

## Phase 0 — Device Reconnaissance (no code, 10 min)

Run these via `adb shell` on the R4 **before writing any code:**

```bash
# List ALSA cards
adb shell cat /proc/asound/cards

# List playback devices
adb shell ls -la /dev/snd/pcm*p

# Check permissions on audio devices
adb shell ls -la /dev/snd/

# Check which groups the app runs as
adb shell ps -A | grep flick
adb shell id $(adb shell ps -A | grep flick | awk '{print $2}')

# Try tinyplay (if available) to verify ALSA works
adb shell tinyplay /sdcard/test.wav -D 0 -d 0

# Check if AudioFlinger holds the device
adb shell lsof /dev/snd/pcmD0p 2>/dev/null
```

**Decision gate:** If `/dev/snd/` is not accessible (permission denied), the
ALSA approach won't work without root. Stop here and investigate alternatives
(HiBy SDK, AAudio MMAP exclusive, or accept DoP).

**Most likely outcome on HiBy R4:** The app runs as UID in the `audio` group
(GID 1005), which has read/write access to `/dev/snd/`. This is standard on DAPs.

## Phase 1 — C++ libdsd Skeleton (proof of concept)

### File structure

```
android/app/src/main/cpp/
├── CMakeLists.txt
├── dsd_alsa_output.cpp      # tinyalsa DSD output
├── dsd_alsa_output.h
└── dsd_jni_bridge.cpp       # JNI entry points for Rust/Kotlin
```

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.22.1)
project(libdsd)

# tinyalsa is a system library on Android — link directly
# Headers are in the NDK sysroot under tinyalsa/
add_library(dsd_alsa SHARED
    dsd_alsa_output.cpp
    dsd_jni_bridge.cpp
)

target_link_libraries(dsd_alsa
    log         # android logging
    tinyalsa    # system lib: libtinyalsa.so
)

# Ensure JNI headers are found
find_library(log-lib log)
```

**Note:** On newer Android NDKs, `tinyalsa` headers may not be in the sysroot.
If not, vendor the headers from AOSP `external/tinyalsa/include/`. The library
`libtinyalsa.so` is always present on the device at `/system/lib/libtinyalsa.so`.

### dsd_alsa_output.h

```cpp
#pragma once
#include <cstdint>
#include <string>

struct DsdAlsaConfig {
    int card;          // ALSA card number (from /proc/asound/cards)
    int device;        // ALSA device number (typically 0)
    uint32_t rate;     // DSD rate: 2822400, 5644800, etc.
    int channels;      // 2 for stereo
    int format;        // PCM_FORMAT_DSD_U8 = 0x1C, etc.
};

class DsdAlsaOutput {
public:
    bool open(const DsdAlsaConfig& config);
    int write(const uint8_t* data, size_t size);
    void close();
    bool isOpen() const;

private:
    struct pcm* mPcm = nullptr;
    bool mRunning = false;
};
```

### dsd_alsa_output.cpp (core)

```cpp
#include "dsd_alsa_output.h"
#include <tinyalsa/pcm.h>
#include <android/log.h>

#define TAG "libdsd"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

bool DsdAlsaOutput::open(const DsdAlsaConfig& config) {
    struct pcm_config pcm_config = {};
    pcm_config.channels = config.channels;
    pcm_config.rate = config.rate;
    pcm_config.format = config.format;
    pcm_config.period_size = config.rate / 8;  // ~125ms
    pcm_config.period_count = 4;

    mPcm = pcm_open(config.card, config.device, PCM_OUT, &pcm_config);
    if (!pcm_is_ready(mPcm)) {
        LOGE("pcm_open failed: card=%d device=%d rate=%u format=%d: %s",
             config.card, config.device, config.rate, config.format,
             pcm_get_error(mPcm));
        pcm_close(mPcm);
        mPcm = nullptr;
        return false;
    }

    LOGI("DSD ALSA device opened: card=%d device=%d rate=%u format=%d",
         config.card, config.device, config.rate, config.format);
    mRunning = true;
    return true;
}

int DsdAlsaOutput::write(const uint8_t* data, size_t size) {
    if (!mPcm || !mRunning) return -1;
    int ret = pcm_write(mPcm, data, size);
    if (ret != 0) {
        LOGE("pcm_write failed: %s", pcm_get_error(mPcm));
    }
    return ret;
}

void DsdAlsaOutput::close() {
    if (mPcm) {
        pcm_close(mPcm);
        mPcm = nullptr;
    }
    mRunning = false;
    LOGI("DSD ALSA device closed");
}
```

### dsd_jni_bridge.cpp

```cpp
#include <jni.h>
#include "dsd_alsa_output.h"

static DsdAlsaOutput gOutput;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_mossapps_flick_DsdAlsaBridge_nativeOpen(
    JNIEnv* env, jclass cls,
    jint card, jint device, jint rate, jint channels, jint format) {
    DsdAlsaConfig config = {card, device, (uint32_t)rate, channels, format};
    return gOutput.open(config) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_com_mossapps_flick_DsdAlsaBridge_nativeWrite(
    JNIEnv* env, jclass cls, jbyteArray data) {
    jbyte* buf = env->GetByteArrayElements(data, nullptr);
    jsize size = env->GetArrayLength(data);
    int ret = gOutput.write((const uint8_t*)buf, size);
    env->ReleaseByteArrayElements(data, buf, JNI_ABORT);
    return ret;
}

JNIEXPORT void JNICALL
Java_com_mossapps_flick_DsdAlsaBridge_nativeClose(
    JNIEnv* env, jclass cls) {
    gOutput.close();
}

JNIEXPORT jboolean JNICALL
Java_com_mossapps_flick_DsdAlsaBridge_nativeIsOpen(
    JNIEnv* env, jclass cls) {
    return gOutput.isOpen() ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
```

### Kotlin bridge

```kotlin
// DsdAlsaBridge.kt
package com.mossapps.flick

object DsdAlsaBridge {
    init {
        System.loadLibrary("dsd_alsa")
    }

    external fun nativeOpen(card: Int, device: Int, rate: Int, channels: Int, format: Int): Boolean
    external fun nativeWrite(data: ByteArray): Int
    external fun nativeClose()
    external fun nativeIsOpen(): Boolean
}
```

## Phase 2 — ALSA Device Discovery

Hardcoded card/device numbers are fragile. Need runtime discovery.

### Discovery strategy

```cpp
// Scan /proc/asound/cards to find the internal audio card
// For HiBy: typically card 0 (default), device 0

// Also check /proc/asound/card0/pcm0p/info for supported formats

// Fallback: try card 0 device 0, then iterate
```

### Format negotiation

Try formats in order:
1. `PCM_FORMAT_DSD_U8` (most common for ESS DACs)
2. `PCM_FORMAT_DSD_U16_LE` (Cirrus Logic, some HiBy models)
3. `PCM_FORMAT_DSD_U32_LE` (DSD512-capable DACs)

If all fail at `pcm_open`, the device doesn't support DSD via ALSA. Fall back to
DoP (existing path).

## Phase 3 — Integration with Rust Engine

### Strategy

In `DsdNativeBackend::start()` (Rust), add ALSA as a fallback before giving up:

```
1. Try ENCODING_DSD AudioTrack (existing) → fails on R4
2. Try ALSA Direct via JNI (NEW) → works on R4
3. Return Err → engine falls back to DoP
```

### Rust changes

```rust
// dsd_native_backend.rs
impl DsdNativeBackend {
    pub fn start(...) -> Result<Self, String> {
        // Attempt 1: ENCODING_DSD AudioTrack (existing)
        if dsd_track_create(sample_rate, channels) {
            return Ok(Self::AudioTrack(...));
        }

        // Attempt 2: ALSA Direct (NEW)
        if dsd_alsa_open(sample_rate, channels) {
            log::info!("[DSD-NATIVE] Using ALSA direct output");
            return Ok(Self::AlsaDirect(...));
        }

        Err("Neither ENCODING_DSD nor ALSA DSD available".into())
    }
}
```

### Engine state

New `dsd_transport` values:
- `dap-native-encoding` — ENCODING_DSD AudioTrack
- `dap-native-alsa` — Direct ALSA (NEW)
- `dap-dop` — DoP over PCM carrier

### AudioFlinger conflict handling

**Critical issue:** AudioFlinger typically holds `/dev/snd/pcmD0p` open. A direct
ALSA open will fail with `EBUSY`.

Solutions:
1. **Mute AudioFlinger first** — Create a silent AudioTrack at a dummy rate,
   then release it. On some DAP HALs, this frees the ALSA device.
2. **Use a different ALSA device** — Some DAPs have multiple PCM devices.
   Card 0 Device 0 might be AudioFlinger-managed; Card 0 Device 1 might be
   a direct passthrough.
3. **HiBy vendor extension** — HiBy's HAL may have a path that releases the
   device for direct access. Need to check `audio_policy.conf` or
   `audio_policy_configuration.xml` on the device.
4. **Stop AudioFlinger** (root only) — `stop mediaserver` or
   `setprop audio.flinger.disable 1`. Not practical for a commercial app.

**This is the highest-risk part of the project.** Phase 0 reconnaissance will
determine which solution works.

## Phase 4 — Robustness

| Concern | Solution |
|---------|----------|
| Audio interruption (calls, alarms) | Register `PhoneStateListener`, close ALSA on interrupt, reopen after |
| Audio focus | Standard `AudioManager.requestAudioFocus` — close ALSA on focus loss |
| Volume control | ALSA mixer: `mixer_open(card)` → `mixer_get_ctl_by_name` → `mixer_ctl_set_value` |
| Buffer underruns | Tune `period_size` and `period_count`; monitor `pcm_htimestamp` |
| DSD rate switching | Close + reopen ALSA device with new rate; no hot-switching |
| Multiple DAP support | Device profile with ALSA card/device/format hints per manufacturer |

## Phase 5 — Full C++ DSD Pipeline (optional, only if Phase 3 has issues)

If JNI bridge latency or stability is unacceptable:

```
DSF/DFF file → C++ decoder → C++ ALSA output (zero-copy)
```

Move DSD decoding from Rust to C++:
- Use `libdsf` / `libdff` or port the existing Rust decoder
- Direct file I/O → DSD byte stream → ALSA write
- No JNI round-trips per buffer
- Requires CMake integration with the DSD file format libraries

**This is the nuclear option.** Only do this if Phase 2–3 work but have
unacceptable latency/stability issues. The JNI bridge adds ~50-100µs per buffer
write, which is negligible at DSD rates.

## Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `/dev/snd/` not accessible | Low (DAPs grant audio group) | Fatal | Phase 0 check; fall back to DoP |
| AudioFlinger holds device (EBUSY) | High | Fatal | Try alt devices; vendor extension; AudioTrack trick |
| Wrong DSD format constant | Medium | Retries needed | Auto-probe all formats; cache working one |
| ALSA device differs on firmware versions | Medium | Discovery fails | Per-firmware card/device hints in DAP registry |
| JNI per-buffer write overhead | Low | Minor latency | Direct buffer (`GetDirectBufferAddress`) instead of byte array copy |
| App killed while ALSA open | Low | ALSA device stuck | `close()` in `onDestroy`; timeout auto-release in driver |
| No volume control via ALSA | Medium | UX issue | Fall back to digital gain in Rust pipeline |

## Success Criteria

1. `adb logcat` shows `DSD ALSA device opened: card=0 device=0 rate=2822400 format=DSD_U8`
2. R4 display shows "DSD" indicator (not PCM/DoP) during playback
3. `dsd_transport=dap-native-alsa` in diagnostics
4. `bitPerfect=true`, `resampler=false`
5. No AudioFlinger conflicts or device-lock errors
6. DSD64 and DSD128 both work
7. Audio interruptions (notifications) handled gracefully

## What We Keep

- **Rust DSD decoder** (DSF/DFF/WavPack) — works perfectly, no reason to change
- **Rust PCM output** (Oboe/AudioTrack) — works perfectly for non-DSD content
- **DoP fallback** — still the universal DSD delivery path if ALSA fails
- **Strategy selection logic** — just add ALSA as a new `DsdNative` backend option

## What We Replace

- **DSD output path only** — from AudioTrack.ENCODING_DSD to direct ALSA
- **Nothing else**

## Device-Specific Registry (future)

After confirming ALSA works on the R4, add per-device ALSA hints to the DAP registry
(`rust/src/audio/device.rs`):

```rust
// In the DAP registry
DapSignature {
    label: "HiBy",
    manufacturer_patterns: &["hiby"],
    alsa_card: 0,
    alsa_device: 0,
    dsd_format: DsdAlsaFormat::DsdU8,
    ...
}
```

This lets the C++ backend skip device discovery on known DAPs.
