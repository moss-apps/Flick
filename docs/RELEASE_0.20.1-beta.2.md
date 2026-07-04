# Flick 0.20.1-beta.2

0.20.1-beta.2 ships AutoEQ headphone matching, an in-app logging system, library warmup for background metadata extraction, a Recently Added screen, visualizer and display settings, floating island toggle, wrap-around queue playback, fingerprint cache reliability fixes, USB audio engine improvements, and performance optimizations.

## Overview

This beta adds ten headline features:

1. **AutoEQ headphone matching** — search for your headphones and auto-tune the EQ with community presets
2. **App logging system** — in-app log viewer with Rust sink bridging for USB and audio diagnostics
3. **Library warmup** — background metadata extraction populates album art, year, and genre after scan
4. **Recently Added screen** — paginated song list of newly added music, accessible from Quick Access
5. **Visualizer & display settings** — refresh rate mode, visualizer on/off toggle with independent settings
6. **Floating island toggle** — enable/disable the floating mini-player overlay
7. **Wrap-around queue** — queue loops from last track back to first
8. **Fingerprint cache fixes** — cache cleared on DB incompatibility, folder removal, and rebuild
9. **USB audio fixes** — isochronous feedback polling, AAudio guard, USB fallback handling
10. **Performance** — sliver-based lists, memoized album groups, pre-built row objects

## Highlights

- **AutoEQ**: Search for your headphone brand and model from the equalizer presets sheet to apply a community-curated AutoEQ preset. The catalog is pre-bundled and browsed through a searchable bottom sheet. `AutoEqCatalogService` handles preset lookup and JSON parsing. LSC and HSC band type codes are correctly mapped to low-shelf and high-shelf IIR filter types for accurate tuning.
- **Logging system**: An in-app log viewer (Settings → UAC2 → Developer → Logs) shows real-time debug output. A singleton `AppLog` with change notifications powers reactive UI updates. A log sink bridges Rust `dev_eprintln!` output into the Dart log system via FFI. The default error handler writes uncaught exceptions to the log. Audio probe format is exposed through FFI for USB device diagnostics.
- **Library warmup**: After the first scan, a background metadata extraction pass fills in missing album art, year, and genre fields without blocking the UI. `BackgroundMetadataService` is extracted as a shared Riverpod provider. Snackbar notifications show warmup start and completion. `countIncompleteMetadataSongs` tracks progress.
- **Recently Added**: A new "Recently Added" screen shows paginated songs sorted by addition date. Accessible from the Quick Access menu. Backed by `getRecentlyAddedSongs` with cursor-based pagination.
- **Display settings**: Choose a refresh rate mode (auto, 60Hz, 90Hz, or 120Hz) from Settings → Interface. Toggle the visualizer on/off with an independent settings screen. `DisplayModeWrapper` was migrated to Riverpod with multi-mode support. When the visualizer is disabled, the render pipeline is skipped entirely.
- **Queue wrap-around**: When enabled, the queue wraps from the last track back to the first — no more silent stops at the end of the queue. Toggle in Settings → Playback.
- **Fingerprint cache**: The fingerprint cache is now cleared on database incompatibility (Isar rebuild), when a folder is removed from the library, and on full database rebuild. Orphaned cache entries are filtered on reload. These fixes prevent stale fingerprints from causing duplicate song entries.
- **USB audio**: Isochronous feedback polling is now enabled for Android USB output, improving clock synchronization with external DACs. AAudio exclusive mode is guarded by an Android API level check (API 26+). Mid-stream USB fallback on Rust backend refusal is handled gracefully. Unknown USB speed is inferred from sysfs and supported sample rates. A custom `CacheManager` with configurable stale period manages artwork caching; management controls are in Library settings.
- **Performance**: The Recently Played and Recently Added screens pre-build row objects for `ListView` instead of building on-the-fly. The folder list was converted to `SliverList` for smoother infinite scrolling. Album group computation is memoized in the artist detail screen to avoid redundant work on rebuilds.
- **Lyrics & polish**: The lyric share card now supports dynamic font sizing with dedicated controls. A false lyrics scroll jump on transient position dips was fixed. Rotary knob drag precision was improved for smoother EQ adjustments. The README was rewritten with a concise overview, UAC 2.0 API docs, and a transparency section. Stale comments were removed across the codebase.

## What's New

### AutoEQ Headphone Matching

- Search by brand/model in EQ presets sheet
- Pre-bundled AutoEQ catalog assets
- `AutoEqCatalogService` for lookup and JSON parsing
- LSC/HSC → low/high shelf filter mapping

### App Logging System

- In-app log viewer (Settings → UAC2 → Developer → Logs)
- Singleton `AppLog` with change notifications
- Rust-to-Dart log sink FFI
- Default error handler captures uncaught exceptions
- Audio probe format via FFI

### Library Warmup

- Background metadata extraction after scan
- `BackgroundMetadataService` shared provider
- Snackbar on start/complete
- `countIncompleteMetadataSongs` progress tracking

### Recently Added Screen

- Paginated song list by addition date
- Quick Access menu entry
- `getRecentlyAddedSongs` with cursor pagination

### Visualizer & Display Settings

- Refresh rate mode (auto / 60 / 90 / 120Hz)
- Visualizer on/off toggle with settings screen
- Riverpod-based `DisplayModeWrapper` with multi-mode
- Disabled visualizer skips render pipeline

### Floating Island Toggle

- Toggle floating mini-player from Settings → Playback → Display

### Wrap-Around Queue Playback

- Queue wraps from last track to first
- Toggle in Settings → Playback

### Fingerprint Cache Reliability

- Cleared on DB incompatibility, folder removal, DB rebuild
- Orphaned entries filtered on reload

### Performance

- Pre-built row objects for Recently Played/Added
- Folder list converted to slivers
- Memoized album group computation

### USB Audio & Engine Fixes

- Isochronous feedback polling for USB
- AAudio exclusive mode API level guard
- Mid-stream USB fallback handling
- USB speed inference from sysfs
- Custom CacheManager with stale period; artwork cache settings

### Lyrics & Share Cards

- Dynamic font sizing and font size controls on lyric share card
- False scroll jump fix

### Polish

- Rotary knob drag precision
- README rewrite with docs and transparency section
- Stale comments removed

## Files Changed

| Area | Key Paths |
| --- | --- |
| AutoEQ | `assets/autoeq/`, `lib/services/autoeq_catalog_service.dart`, `lib/features/settings/equalizer_screen.dart` |
| Logging | `lib/core/logging/`, `rust/src/api/log.rs`, `lib/features/settings/screens/logs_screen.dart` |
| Library Warmup | `lib/services/background_metadata_service.dart`, `lib/providers/library_warmup_provider.dart` |
| Recently Added | `lib/features/recap/screens/recently_added_screen.dart`, `lib/data/repositories/song_repository.dart` |
| Visualizer | `lib/features/visualizer/`, `lib/providers/display_settings_provider.dart`, `lib/core/utils/display_mode_wrapper.dart` |
| Floating Island | `lib/providers/app_preferences_provider.dart`, `lib/features/settings/screens/` |
| Queue | `lib/providers/player_provider.dart`, `lib/features/settings/screens/playback_settings_screen.dart` |
| Fingerprint Cache | `lib/services/fingerprint_cache_service.dart`, `lib/data/database.dart` |
| USB Audio | `rust/src/audio/android_direct_usb.rs`, `rust/src/audio/android_output.rs` |
| Performance | `lib/features/recap/`, `lib/features/folders/`, `lib/features/artist/` |
| Artwork Cache | `lib/services/cache_manager_service.dart`, `lib/features/settings/screens/library_settings_screen.dart` |
| Lyrics | `lib/widgets/share_cards/`, `lib/features/lyrics/` |
| Docs | `README.md`, `docs/UAC2_API.md` |

## Upgrading

1. AutoEQ: open Settings → Audio → Equalizer → Presets → AutoEQ and search for your headphones
2. Logs: visible in Settings → UAC2 → Developer → Logs when developer mode is enabled
3. Library warmup runs automatically after the first scan — no action needed
4. Recently Added appears under Settings → Quick Access — toggle it on to see it on the menu screen
5. Refresh rate and visualizer settings are under Settings → Interface
6. Floating island toggle is in Settings → Playback → Display
7. Wrap-around queue is off by default — enable from Settings → Playback
8. Fingerprint cache fixes apply automatically; no data migration needed
