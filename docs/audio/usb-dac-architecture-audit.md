# USB DAC Architecture Audit

## Scope

Audits Flick's Android playback architecture for: external USB DAC playback, sample-rate behavior, app-only/exclusive playback behavior, and bit-perfect claims. "Exclusive" means the app has taken direct responsibility for the USB device path and is no longer relying on Android's shared mixer for that path — not a guarantee of system-wide hardware exclusivity.

## Before Refactor: Broken Hybrid

The app had a real Rust/libusb direct USB backend, an Android-managed Rust/Oboe path, and a `just_audio` path — but the product-level state model collapsed those into a binary `android` vs `usb` decision. Problems:

- Direct USB startup depended on a playback-format side channel that could arrive too late.
- If format registration missed or mismatched, Rust silently opened the Android-managed Oboe path instead of direct USB.
- Kotlin route reporting could label the route as USB because a preferred DAC was attached, even when Android wasn't reporting USB as the current output route.

## After Refactor: Three Explicit Modes

| Mode | Backend | Mixer | Notes |
|------|---------|-------|-------|
| `NORMAL_ANDROID` | `just_audio` / ExoPlayer / AudioTrack | Android-managed | Default |
| `USB_DAC_EXPERIMENTAL` | Rust direct USB (libusb isochronous) | Bypasses mixer | Audio focus requested on host side; USB interfaces claimable across sessions. Experimental: compatibility not universal. |
| `DAP_INTERNAL_HIGH_RES` | Rust engine → Oboe / AAudio | Android-managed | Not equivalent to direct USB ownership |

### Pipeline Diagram

```text
Flutter UI
  -> PlayerService
    -> AudioSessionManager
       -> NORMAL_ANDROID
          -> AndroidAudioEngine
          -> just_audio / ExoPlayer
          -> Android shared output path

       -> USB_DAC_EXPERIMENTAL
          -> Uac2Service.prepareAndroidExperimentalUsbPlayback()
          -> MainActivity.activateDirectUsb()
          -> RustAudioEngine
          -> Rust audio engine
          -> libusb isochronous transfers
          -> USB DAC

       -> DAP_INTERNAL_HIGH_RES
          -> RustAudioEngine
          -> Rust audio engine
          -> Oboe / AAudio
          -> Android-managed internal output path
```

### Active DAC Path Diagnostics

Direct USB is only active when diagnostics report **all** of:
- playback mode is `USB_DAC_EXPERIMENTAL`
- Rust output signature starts with `android-uac2:`
- Android host reports the direct USB device is registered
- Rust direct USB debug state reports active stream or idle interface lock

If diagnostics show `android-shared:*`, `NORMAL_ANDROID`, or `DAP_INTERNAL_HIGH_RES`, playback is Android-managed even if a USB DAC is attached.

## Race Condition Fixed

Before refactor, the race was: Flutter chose the Rust "USB" engine → Rust engine creation used the probed track sample rate → direct USB backend selection required a pre-registered Android playback format → that format was pushed late through `syncPlaybackStatus()` → Rust could create `android-shared:*` instead of `android-uac2:*`.

Now: `USB_DAC_EXPERIMENTAL` prepares the USB format before engine init. If the format doesn't match the actual probed track rate, Rust rejects the direct request instead of silently creating an Android-managed stream. If metadata isn't available early enough, the app falls back to `NORMAL_ANDROID` instead of pretending direct USB is active.

## Why the DAC Could Look Locked at 384 kHz

Old architecture causes:
1. App was actually on an Android-managed route — Android/device policy can fix the USB output stream at a preferred rate.
2. Direct USB preparation could miss startup — missing/mismatched format → Rust chose `android-shared:*`.
3. Route reporting was optimistic — a preferred DAC attached could make the UI look USB-centric when the output path was still Android-managed.

Now: USB format prepared before engine init; mismatches rejected; fallback to `NORMAL_ANDROID` when metadata is insufficient. Does not guarantee Android-managed routes switch rates per track.

## Does Flick Own the DAC Directly?

Only when all hold: `USB_DAC_EXPERIMENTAL` active, Rust reports `android-uac2:*`, and direct USB state reports interfaces claimed or stream active. Outside that state, Flick does not own the DAC directly — Android-managed.

## Bit-Perfect Claim

No verified bit-perfect claim should be made for Android playback:
- `NORMAL_ANDROID` and `DAP_INTERNAL_HIGH_RES` are Android-managed.
- The direct USB path avoids Android's shared mixer, but verified bit-perfect still depends on alternate setting, transport format, clock programming, and device-specific behavior.
- Metadata gaps can force fallback before direct USB is attempted.

`supportsVerifiedBitPerfect` remains `false` on Android.

## Runtime Capability Rules

Computed from runtime mode + diagnostics, not optimistic route labels:

| Rule | True when |
|------|-----------|
| `supportsExclusiveUsbOwnership` | Direct USB experimental path active + USB interfaces claimed |
| `supportsDirectSampleRateSwitching` | Direct USB active + reported output rate matches requested track rate |
| `supportsVerifiedBitPerfect` | `false` on Android in current codebase |
| `supportsAndroidManagedHighResOnly` | `DAP_INTERNAL_HIGH_RES` active |
| `supportsInternalDapPathOnly` | `DAP_INTERNAL_HIGH_RES` without attached USB DAC |

## Why Other Apps Are Still Audible

**Android-managed routes**: `just_audio`/ExoPlayer uses Android's shared output stack; Oboe/AAudio exclusive-sharing is still not universal hardware ownership; audio focus is advisory, not USB hardware ownership.

**Direct USB path**: requests audio focus + claims USB streaming interfaces (including idle lock when enabled). Stronger than audio focus alone, but public Android APIs provide no proof that every competing app is blocked from every hardware path.

## Android USB Prompt Limitations

The chooser dialog ("Use this app for the connected USB device") is not guaranteed for every DAC. Many DACs expose audio class info only on their interfaces while the device descriptor is class `0` — a generic manifest filter can't match those. Flick can: enumerate `UsbManager.deviceList`, identify DAC candidates at runtime, call `requestPermission()` directly. Flick cannot: provide a universal UAPP-style auto-launch for every DAC model.

## Gap Analysis vs UAPP-Like Behavior

**Has**: explicit direct USB mode, USB interface claiming, optional idle lock between tracks, audio focus integration, deterministic teardown, diagnostics distinguishing Android-managed from direct-managed.

**Does not prove**: universal system-wide hardware exclusivity, guaranteed silencing of other apps, verified bit-perfect delivery, guaranteed per-track rate switching on Android-managed paths.

## Files That Matter

- `lib/services/player_service.dart`
- `lib/services/audio_session_manager.dart`
- `lib/services/uac2_service.dart`
- `android/app/src/main/kotlin/com/ultraelectronica/flick/MainActivity.kt`
- `rust/src/audio/engine.rs`
- `rust/src/uac2/android_direct.rs`
