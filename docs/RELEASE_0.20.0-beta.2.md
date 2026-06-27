# Flick 0.20.0-beta.2

0.20.0-beta.2 ships a compact home widget, milestone streaks with new tiers, an audio convolver for impulse-response reverb, a Rust crossfade engine, DSD transport overrides via the unified quirk database, removable storage scanning through SAF, a full Bluetooth management screen, and metadata editor safety improvements.

## Overview

This beta adds ten headline features:

1. **Compact home widget** — 2×2 widget with text and controls, semi-transparent scrim on mini player
2. **Milestone streaks & new tiers** — day streak tracking, unique artist count, emerald tier, collapsible categories
3. **Audio convolver** — direct-time-domain IR reverb with dry/wet mix, integrated into the equalizer
4. **Crossfade engine** — Rust crossfade between tracks with configurable curves, atomic state persistence
5. **DSD transport overrides** — per-device byte-order and subslot overrides from the unified quirk DB
6. **Removable storage scanning** — SAF-based SD card and USB drive support with per-volume MediaStore
7. **Bluetooth management** — settings screen, A2DP codec info, low-latency mode, pause-on-disconnect, reconnect resume
8. **Metadata editor safety** — tag write verification, temp-file rollback, SAF fallback, write permission persistence
9. **Album list view** — list mode with multi-selection, queue-all button
10. **Cleanup** — app name simplified to "Flick", lyric sizing, deprecation fixes, dead code removal

## Highlights

- **Compact widget**: A new 2×2 `CompactWidgetProvider` widget shows the current track text and transport controls. Compact-specific preferences have their own settings tab, and the widget settings screen now supports swipe gestures between tabs with animated transitions. The mini player widget gained a semi-transparent scrim overlay whose visibility tracks album art presence.
- **Streaks & milestones**: Day streak tracking records consecutive listening days with a flame-icon popup and optional snooze. A unique-artist-count milestone tracks distinct artists over the listener's lifetime. An emerald tier joins the existing five tiers. The milestone collection view groups achievements by category with collapsible sections. `MilestoneService` was refactored with category-based current-value tracking. New tests cover streak and unique-artist logic.
- **Audio convolver**: A direct-time-domain convolver processes impulse response (IR) WAV files for convolution reverb. The offline IR loader feeds a streaming convolver integrated into the audio pipeline via the equalizer service. Persistent `ConvolverSettings` store enable/disable, dry/wet mix, and loaded IR. A convolver section on the equalizer screen provides UI controls. The Rust public API exposes `convolver_enable`, `convolver_mix`, `convolver_load_ir`, and `convolver_clear`.
- **Crossfade engine**: The Rust audio engine now crossfades between tracks using a `CrossfadeCurve` enum. Pending crossfade configuration is stored in atomics and survives engine recreation, applying automatically on the next audio state update. A Dart FFI API exposes pending crossfade and DSD override options. Crossfade tests cover the Android engine path.
- **DSD overrides**: Per-device DSD byte-order and subslot overrides are now applied through the unified quirk database, which drives `sub_slot_size`, `bit_order`, and `byte_reverse` settings. Override preferences are synced to the Rust engine before playback begins. 24-bit DSD over USB DoP uses corrected bits-per-frame. DSD ring rate and payload integrity are validated. UAC2 alt-settings are probed for DSD/DoP capability before stream start.
- **Removable storage**: Folders on SD cards and USB drives are now scannable via Android SAF. `FolderEntity` gains `isRemovable`, `mediaStoreVolume`, and `volumeState` fields — volume info is resolved when the folder is added. An external status label appears on the root folder card, and USB/removable status is shown inline during deep scans. Unmount events are handled gracefully with an instant SAF scan fallback. The SAF tree walk was refactored to use `contentResolver.query` per directory for faster traversal. Tests cover removable volume handling.
- **Bluetooth**: A new Bluetooth settings screen shows A2DP codec info and battery level for connected devices, backed by a service layer with device and codec DTOs. Low-latency mode selects the Rust Oboe engine for Bluetooth playback. Pause-on-disconnect automatically pauses when Bluetooth drops. Reconnect resume restarts playback on reconnect. A Bluetooth connect permission supports Android 12+.
- **Metadata editor**: Tag writes are now verified with typed outcomes. Metadata is validated before saving with improved error reporting. The original file is copied to a temp path before writing to enable safe rollback on failure. An SAF fallback handles tag writes on scoped storage. Write URI permission is requested and persisted alongside the read permission.

## What's New

### Compact Home Widget

- 2×2 `CompactWidgetProvider` with text and transport controls
- Compact-specific preferences tab in widget settings
- Swipe gesture between widget tabs with animated transitions
- Semi-transparent scrim on mini player widget, visibility matched to album art

### Milestone Streaks & New Tiers

- Day-streak tracking with flame-icon popup and snooze
- Unique artist count milestone
- Emerald tier
- Category grouping with collapsible sections
- Category-based current-value tracking in `MilestoneService`
- Tests for streak and unique-artist logic

### Audio Convolver — IR Reverb

- Direct-time-domain convolver
- Offline WAV IR loader
- Enable/disable, dry/wet mix, load, clear API
- Persistent `ConvolverSettings`
- Convolver section on equalizer screen
- Rust public API

### Crossfade Engine (Rust)

- Track-to-track crossfade via `CrossfadeCurve`
- Atomic pending configuration survives engine recreation
- Auto-apply on audio state update
- Dart FFI API for crossfade and DSD overrides
- Android audio engine tests

### DSD Transport Overrides

- Per-device byte-order and subslot overrides
- Unified quirk database integration
- Override preferences synced before playback
- 24-bit USB DoP with corrected bits-per-frame
- DSD ring rate and payload integrity fixes
- UAC2 alt-settings DSD/DoP probing

### Removable Storage & SAF Scanning

- SAF-based scanning for SD cards and USB drives
- `FolderEntity` extended with `isRemovable`, `mediaStoreVolume`, `volumeState`
- External status label and inline USB status during scans
- Unmount handling with instant SAF scan fallback
- `contentResolver.query` per directory for fast SAF traversal
- Removable volume tests

### Bluetooth Management

- Bluetooth settings screen with codec and device management
- A2DP codec and battery level detection
- Low-latency mode (Rust Oboe for Bluetooth)
- Pause-on-disconnect
- Reconnect resume
- Android 12+ connect permission

### Metadata Editor Improvements

- Tag write verification with typed outcomes
- Pre-save validation with improved error reporting
- Temp-file copy before write for safe rollback
- SAF fallback for scoped storage tag writes
- Write URI permission persisted

### Albums & Search

- Album list view with multi-selection
- Queue all songs button
- Search playback mode preference

### UI Polish & Cleanup

- App name simplified to "Flick"
- Lyric font 34px, max 4 lines
- "Flick Replay" chip accent highlight
- `AnimatedSize`/`AnimatedOpacity` for scan settings
- Share replaces "Show in Files"
- `SizeTransition` deprecation fix
- Unused imports, dead code, deprecated test removed
- Vendored/generated files excluded from analysis

## Files Changed

| Area | Key Paths |
| --- | --- |
| Compact Widget | `android/.../widget/CompactWidgetProvider.kt`, `lib/providers/`, `lib/features/settings/screens/widget_settings_screen.dart` |
| Milestones | `lib/services/milestone_service.dart`, `lib/features/milestones/`, `test/services/milestone_service_test.dart` |
| Convolver | `rust/src/audio/convolver/`, `rust/src/api/convolver.rs`, `lib/features/settings/equalizer_screen.dart` |
| Crossfade | `rust/src/audio/crossfader.rs`, `rust/src/audio/android_audio_engine.rs`, `lib/services/rust_audio_service.dart` |
| DSD Overrides | `rust/src/uac2/quirk.rs`, `rust/src/audio/dsd_engine/`, `lib/providers/` |
| Removable Storage | `rust/src/api/scanner.rs`, `lib/data/entities/folder_entity.dart`, `lib/services/music_folder_service.dart` |
| Bluetooth | `lib/features/settings/screens/bluetooth_settings_screen.dart`, `lib/services/bluetooth_service.dart`, `lib/models/bluetooth/` |
| Metadata Editor | `rust/src/metadata_editor/`, `lib/services/metadata_editor_service.dart` |
| Albums | `lib/features/albums/screens/album_detail_screen.dart` |
| Cleanup | `README.md`, `lib/features/lyrics/`, `android/app/build.gradle.kts`, `analysis_options.yaml` |

## Upgrading

1. Compact widget: add from your launcher's widget picker, then customize from Settings → Widgets → Compact tab
2. Convolver: load a WAV impulse response file from Settings → Audio → Equalizer → Convolver
3. Crossfade: enable from Settings → Audio → Crossfade (experimental); works with the Rust engine path
4. Removable storage: add your SD card or USB drive folder from Settings → Library → Music Folders
5. Bluetooth settings: accessible from Settings → Audio → Bluetooth; low-latency mode is off by default
6. DSD overrides are applied automatically based on your device's USB descriptor — no manual config needed for known quirks
7. Metadata edits now verify writes and create temp-file backups — edits may take slightly longer but are safer
