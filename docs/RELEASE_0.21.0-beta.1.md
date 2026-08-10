# Flick 0.21.0-beta.1

0.21.0-beta.1 is a major release, shipped while continuously keeping up with improvements and bug fixing across the app: network sources for self-hosted music servers (Subsonic, Jellyfin, DLNA, WebDAV, Tidal), DLNA and Chromecast casting, an HTTP audio streaming engine, a parametric equalizer refactor, configurable player action buttons, a volume tier system, bit-perfect passthrough mode, USB DAC fixes, and reliability improvements.

## Overview

This release adds ten headline features:

1. **Network sources** — stream from Subsonic, Jellyfin/Emby, UPnP/DLNA, WebDAV, and Tidal servers
2. **Casting** — DLNA/UPnP and Google Chromecast support with device discovery
3. **HTTP audio streaming** — ranged HTTP playback with seekable remote streams
4. **Parametric EQ** — variable band types with RBJ biquad coefficients
5. **Player action buttons** — configurable center, top-left, top-right, and bottom actions
6. **Volume tier system** — deterministic volume capability detection with unavailable tier
7. **Passthrough mode** — bit-perfect PCM on direct USB with software gain removed
8. **USB DAC fixes** — Fosi Audio DS2 quirk, 0 Hz readback fix, sample rate guards
9. **Reliability** — wake lock, auto-resume fix, persistent WAV cache, dev log gating
10. **UI polish** — ambient EQ background, USB volume preferences, settings scaling

## Highlights

- **Network sources**: Connect to your own music server. Subsonic, Jellyfin/Emby, UPnP/DLNA MediaServer, WebDAV, and Tidal are all supported through a unified `NetworkSourceService` abstraction. Each protocol has its own implementation handling auth, album art, and stream resolution. Server credentials are stored in `NetworkServerEntity` (Isar). A Network Sources screen provides server add/edit/delete with validation and failure banners. Remote songs carry `sourceType`, `remoteId`, and `remoteServerId` for sync tracking. A bounded LRU `NetworkCacheService` caches downloads for offline-ready playback. Subsonic prefetch enables gapless crossfade between streamed tracks. Album art resolution is generalized across all protocols.
- **Casting**: A `CastingService` orchestrates DLNA/UPnP renderers and Google Chromecast. The Chromecast backend uses `CastController` with cast channels and the Google Cast SDK. The DLNA backend handles renderer discovery and control. A casting settings screen provides device discovery and output routing. A cast button in the player action row lets you start casting from the player.
- **HTTP streaming**: Remote audio plays directly via HTTP with ranged requests using the `ureq` Rust client. A seekable HTTP media source lets you scrub through network streams. HTTP-first source resolution means network songs stream directly without requiring a local download. `streamDescriptor` on `NetworkSourceService` enables per-protocol HTTP playback. HTTP play and queue methods are exposed via FFI and integrated into `RustAudioEngine` and `RustAudioService`. Network-source prefetch ensures gapless crossfade between streamed tracks.
- **Parametric EQ**: The graphic EQ was converted to a full parametric EQ with variable band types (peak, low-shelf, high-shelf, low-pass, high-pass) using RBJ biquad coefficients. `EqBandSpec` and `EqBandType` FFI types replace the old raw gain arrays. Bands can be added and removed dynamically with animated transitions. The BMT tone controls are preserved alongside the parametric bands.
- **Player action buttons**: The player now has configurable action button slots: center (default: equalizer), top-left, top-right, and the existing bottom pair. Each slot can be assigned any action or set to `none` to hide it. The player layout sheet provides a selector for each slot. Sleep timer is available as an action. All preferences are persisted.
- **Volume tier system**: The old `HwVolumeCapability` enum was replaced with `determineVolumeTier()`, a pure function that's fully testable. A new `unavailable` tier handles DACs that report no volume control. A `_hwVolumeFailed` lie-detector flag catches DACs that claim volume support but fail at runtime. When hardware volume is unavailable, the slider is disabled with an explanatory message. All volume control is now routed through `PlayerService` as the single source of truth.
- **Passthrough**: The new `audio_set_pipeline_mode_passthrough` API forces a bit-perfect PCM path on direct USB. Software gain was removed from the passthrough PCM path for true bit-perfect output. Verified with wire audit (`supportsVerifiedBitPerfect = true`).
- **USB DAC fixes**: A Fosi Audio DS2 quirk was added for its broken clock control (SkipClockValidation). The 0 Hz DAC readback bug is fixed — handles DACs that return zero sample rate. Division-by-zero is guarded when `output_sample_rate` is 0. The preferred sample rate is no longer overwritten by the DAC's stored format. Non-finite and negative position/duration values are guarded in audio progress updates.
- **Reliability**: A wake lock keeps the CPU awake during audio playback, preventing sleep-related dropouts. Auto-resume after audio interruptions (phone calls, notifications) is fixed. Converted WAV files are cached persistently across app restarts. A custom artwork cache in the support directory replaces `flutter_cache_manager`. `dev_eprintln!` now prints to the terminal, and `AppLog` is gated behind developer mode. The audio stream supervisor is enabled on non-Android platforms for desktop testing.

## What's New

### Network Sources — Self-Hosted Music Servers

- Subsonic, Jellyfin/Emby, UPnP/DLNA, WebDAV, Tidal protocol support
- `NetworkSourceService` abstraction with per-protocol implementations
- `NetworkServerEntity` Isar collection for credentials
- Network Sources screen with server management
- `RemoteSourceService` for network song resolution
- `NetworkCacheService` with bounded LRU caching
- Remote sync tracking on `SongEntity`
- Generalized album art resolution
- Subsonic prefetch for gapless playback

### Casting — DLNA & Chromecast

- CastingService for DLNA and Chromecast
- Chromecast with CastController and Google Cast SDK
- DLNA/UPnP renderer discovery and control
- Casting settings screen
- Cast button in player action row

### HTTP Audio Streaming Engine

- HTTP streaming via ureq with ranged requests
- Seekable HTTP media source
- HTTP-first source resolution
- `streamDescriptor` per protocol
- HTTP play/queue via FFI
- Gapless crossfade for streamed tracks

### Parametric Equalizer Refactor

- Variable band types with RBJ biquad coefficients
- `EqBandSpec` and `EqBandType` FFI types
- Dynamic band add/removal with animations
- BMT tone controls preserved

### Player Action Button Layout

- Configurable center action (default: equalizer)
- Top-left and top-right action buttons
- `none` option to hide slots
- Player layout settings reorganized

### Volume Tier System

- `determineVolumeTier()` pure function
- `unavailable` tier
- `_hwVolumeFailed` lie-detector flag
- Volume slider disabled when unavailable
- Volume routed through PlayerService

### Passthrough Pipeline Mode

- `audio_set_pipeline_mode_passthrough` API
- Software gain removed for bit-perfect
- Wire audit verified

### USB DAC Fixes & Quirks

- Fosi Audio DS2 quirk (SkipClockValidation)
- 0 Hz DAC readback fix
- Division-by-zero guard
- Sample rate preservation guards
- Non-finite/negative value guards

### Reliability & Performance

- Wake lock during playback
- Auto-resume fix after interruptions
- Persistent WAV cache
- Custom artwork cache
- dev_eprintln to terminal; AppLog gated on dev mode
- Audio stream supervisor on desktop

### UI Polish

- Ambient background on equalizer screen
- BlurredSongBackground removed from lists
- USB volume visibility preferences
- Responsive settings icon scaling
- Launcher icons updated
- VIEW intent queries for Android 11+

## Files Changed

| Area | Key Paths |
| --- | --- |
| Network Sources | `lib/services/network/`, `lib/data/entities/network_server_entity.dart`, `lib/features/settings/screens/network_sources_screen.dart` |
| Casting | `lib/services/casting/`, `lib/features/settings/screens/casting_settings_screen.dart`, `android/.../CastController` |
| HTTP Streaming | `rust/src/audio/http_source.rs`, `rust/src/audio/audio_api.rs`, `lib/services/rust_audio_service.dart` |
| Parametric EQ | `rust/src/audio/equalizer.rs`, `rust/src/api/equalizer.rs`, `lib/features/settings/equalizer_screen.dart` |
| Player Buttons | `lib/features/player/screens/full_player_screen.dart`, `lib/providers/app_preferences_provider.dart` |
| Volume Tier | `lib/services/player_service.dart`, `lib/features/player/widgets/iso_volume_popup.dart` |
| Passthrough | `rust/src/audio/android_direct_usb.rs`, `rust/src/api/audio_api.rs` |
| USB DAC | `rust/src/uac2/quirk.rs`, `rust/src/audio/android_output.rs` |
| Reliability | `lib/services/wake_lock_service.dart`, `rust/src/audio/`, `lib/services/cache_manager_service.dart` |
| UI | `lib/features/settings/`, `lib/widgets/` |

## Upgrading

1. Network sources: Settings → Network Sources → Add Server → choose protocol (Subsonic, Jellyfin, DLNA, WebDAV, Tidal)
2. Casting: Settings → Casting → Discover Devices, or tap the cast button in the player
3. Parametric EQ: add/remove bands dynamically from the equalizer screen
4. Player buttons: Settings → Player → Layout to configure center, top, and bottom actions
5. Passthrough mode applies automatically on direct USB when supported
6. Volume tier detection is automatic — unavailable DACs show a disabled slider with message
7. Wake lock is automatic during playback — no configuration needed
8. Network songs stream via HTTP by default; enable caching from Network Sources settings
