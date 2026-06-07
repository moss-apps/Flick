# Flick 0.18.0-beta.1

0.18.0-beta.1 delivers UAC 1.0/2.0 descriptor parsing, DSD bit-order control with a quirk database, integer (I32) stream support via AAudio, artist and playlist dynamic theming, a vinyl disc morph animation with gesture seeking, navigation bar auto-collapse, a redesigned milestone system, the What's New changelog surface, and the removal of ambient background effects.

## Overview

This beta adds ten headline features:

1. **UAC 1.0 & 2.0 descriptor parsing** — USB Audio Class 1.0 and 2.0 descriptor parsing with version detection, unified quirk database, and a generic device model
2. **DSD bit order & native USB direct** — DsdBitOrder enum (LSB/MSB) with per-decoder detection, global override FFI, quirk-based byte ordering, DoP word building refactored
3. **Integer (I32) stream support** — AAudio i32 stream variant preserving DoP markers and DSD data, format conversion disabled for bit-perfect paths
4. **Artist & playlist theming** — ArtistDetailScreen and PlaylistDetailScreen with dynamic color extraction from album art, full-bleed artist backgrounds, info chips
5. **Vinyl disc & gesture seeking** — Album art morphs into a spinning vinyl record, rotational gesture seek with haptic feedback
6. **Navigation bar auto-collapse** — FlickNavBar collapses after idle timer with animated transitions, configurable behavior
7. **Milestone card redesign** — Per-tier accent colors, achievement grid collection view, "next milestone — N to go" hint line
8. **What's New system** — Bottom sheet changelog surface on first launch after update
9. **Ambient background removed** — Ambient background decoration stripped from all library screens
10. **Build & compatibility** — Core library desugaring, Isar 3.3.2 with MDBX_INCOMPATIBLE recovery, Impeller configurable per API level, V1+V2 APK signing

## Highlights

- **UAC 1.0 & 2.0 parsing**: The USB audio subsystem now parses both UAC 1.0 and UAC 2.0 descriptors — including AS General, endpoint, header, and unit descriptors. Version detection is automatic. A unified quirk database with fallback lookup consolidates device-specific workarounds. A generic USB audio device model structures parsed data for the compatibility layer. USB diagnostics were refactored to isolate transport data behind an `UrbTransportInfo` model.
- **DSD bit order control**: The `DsdBitOrder` enum (LSB/MSB) is detected per-source across all DSD format decoders (DSF, DFF, WavPack). Bit order is normalized in the output router. The `set_dsd_bit_reverse_override()` FFI function exposes manual byte-order control to Flutter. USB native DSD output now carries `dsd_bit_rate` with multi-byte interleaved payload packing and configurable endianness. The `KNOWN_DSD_QUIRKS` table includes per-device entries for vendor/product IDs, endianness, bit reversal, and preferred subslot size — starting with the MOONDROP Dawn Pro.
- **I32 stream support**: The `AndroidManagedStreamKind` enum replaces the hardcoded f32 stream with `F32` and `I32` variants. `AndroidOutputCallbackI32` reads f32 from the pipeline, extracts raw bit patterns via `f32::to_bits()`, and writes i32 to AAudio — preserving DoP markers and DSD data intact. `open_android_output_stream()` gains a `use_integer_format` parameter, opening i32 streams with format conversion disabled for DoP and native DSD on DAP devices.
- **Artist & playlist theming**: `ArtistEntity` is a new Isar collection with `id`, `name` (unique, case-insensitive), and `artPath` (nullable). `ArtistRepository` provides `getByName()`, `setArt()`, and `clearArt()` for persistent artist art path caching. `ArtistDetailScreen` was migrated from `StatefulWidget` to `ConsumerStatefulWidget` and uses `ColorExtractionService` for dynamic color theming from resolved album art. Full-bleed artist image background with animated tinted app bar replaces the old circular avatar + stat chips layout. `PlaylistDetailScreen` extracts dynamic playlist color from the most-played song's album art via `getMostPlayedSongAmong()`, displays info chips (track count, total duration, dates), and includes an "Other Playlists" horizontal section.
- **Vinyl disc morph**: Tapping album art in the player morphs it into a spinning vinyl record via a custom `_VinylDiscPainter` (radial-gradient disc with grooves and highlight). A `_morphController` (700ms) controls the transition, while a `_spinController` (16s rotation) spins the disc. Album art shrinks to center label size. Song changes reset to art mode. Haptic feedback fires on toggle. Rotational gesture seek allows scrubbing by rotating the disc, also with haptic feedback.
- **Navigation bar collapse**: `FlickNavBar` auto-collapses after a configurable idle timer, with animated transitions to a minimal state. Tapping or dragging reveals the full bar. Preferences control timer duration and collapse behavior.
- **Milestone cards**: The milestone celebration card was redesigned with per-tier accent colors (bronze, silver, gold, sapphire, amethyst), a large hero icon, tinted border + glow, and a "next milestone — N to go" hint line. A new achievement-style collection view (Settings → Milestones) lists all five tiers in a grid. Unlocked tiles re-open the celebration card with the achieved date; locked tiles show a progress bottom sheet. Settings → About → Milestones shows a live "X / 5 unlocked" counter. `MilestoneService` is now unit-testable via an optional `playCountOverride` constructor parameter.
- **What's New**: A bottom sheet changelog surface appears on first launch after an update. Structured `ChangelogEntry` data keyed by version is checked against `lastSeenChangelogVersion`. Version constants (`kAppVersion`, `kAppBuild`, `kAppVersionLabel`) centralize version references.

## What's New

### UAC 1.0 & 2.0 Descriptor Parsing

- USB Audio Class 1.0 and 2.0 descriptor parsing with version-specific structs and types
- Version detection module distinguishes UAC 1.0 from UAC 2.0 devices
- AS General, endpoint, header, and unit descriptor parsing for both UAC versions
- Unified quirk database with fallback lookup (device-specific workarounds)
- Generic USB audio device model for UAC2 compatibility layer
- USB diagnostics refactored with `UrbTransportInfo` transport data model

### DSD Bit Order & Native USB Direct

- `DsdBitOrder` enum (LSB/MSB) with per-source detection in DSF, DFF, and WavPack decoders
- Bit order normalization in the DSD output router
- `set_dsd_bit_reverse_override()` FFI function for manual byte-order control from Flutter
- `KNOWN_DSD_QUIRKS` table with per-device entries (vendor/product IDs, endianness, bit reversal, subslot size) — includes MOONDROP Dawn Pro quirk
- DoP word building refactored into `build_dop_word()` with I32 packing for integer streams
- Default DSD bit rate initialization for newly configured USB playback formats
- UAC2 multi-byte DSD slots now enabled by default
- Pipeline mode (`PipelineMode::Dop`, `Passthrough`, `Dsp`) chosen based on output strategy
- DAP flag included in native DSD detection
- Debug transport labels updated to descriptive format: `usb-native-dsd-uNxN-bit`, `usb-dop-N-bit`, `usb-pcm`

### Integer (I32) Stream Support

- `AndroidManagedStreamKind` enum with `F32` and `I32` variants replaces hardcoded f32
- `AndroidOutputCallbackI32` preserves DoP markers and DSD data via `f32::to_bits()` → i32 passthrough
- `use_integer_format` parameter on `open_android_output_stream()` for DAP DoP/native DSD
- Fallback stream logic adapted for both f32 and i32 stream kinds

### Artist & Playlist Theming

- `ArtistEntity` Isar collection with auto-generated bindings
- `ArtistRepository` for persistent artist art path caching
- `ArtistDetailScreen` dynamic color theming with full-bleed background and scroll-aware app bar
- `PlaylistDetailScreen` dynamic playlist color, info chips, "Other Playlists" section
- `getMostPlayedSongAmong()` helper in `RecentlyPlayedRepository`
- `AlbumDetailScreen` scroll-driven fade for app bar actions
- Play all and shuffle buttons styled as accent-colored pills with fixed width

### Vinyl Disc & Gesture Seeking

- Album art → vinyl disc morph with custom `_VinylDiscPainter` (radial-gradient, grooves, highlight)
- 700ms morph transition, 16s spin rotation; song change resets to art mode
- Rotational gesture seek control on album art with haptic feedback
- Vinyl outline animation on single tap to enable rotation seeking
- Album color passed to visualizer preview when mode is not `off`

### Navigation Bar Auto-Collapse

- `FlickNavBar` auto-collapses after configurable idle timer with animated transitions
- Collapsed state reveals full bar on tap or drag
- Preferences for collapse behavior and timer duration

### Milestone Card Redesign

- Per-tier accent colors: bronze (100), silver (500), gold (1,000), sapphire (10h), amethyst (50h)
- "Next milestone — N to go" hint line on the celebration card
- Achievement grid collection view (Settings → Milestones) with locked/unlocked states
- Live "X / 5 unlocked" counter in Settings → About → Milestones
- `MilestoneService` is unit-testable via `playCountOverride` constructor parameter
- Test suite: `test/services/milestone_service_test.dart`

### What's New System

- Bottom sheet changelog surface on first launch after update
- `ChangelogEntry` data model with versioned sections and subsections
- `lastSeenChangelogVersion` preference for tracking seen entries
- `kAppVersion`, `kAppBuild`, `kAppVersionLabel` constants centralizing version references

### Ambient Background Removed

- Ambient background decoration removed from songs, albums, artists, playlists, favorites, and folders screens
- Ambient background toggle removed from settings scaffold and playback display
- Menu screen hero refactored to use `ColorExtractionService` instead of ambient background

### Folder Browser Enhancements

- Pagination with configurable page size slider
- Pinch-to-zoom gesture support with animated grid transitions
- File type filter and sort options

### Build & Compatibility

- **minSdk stays at 26** (Android 8.0+). Core library desugaring enabled for Java 17 target.
- **Isar bumped to 3.3.2** with MDBX_INCOMPATIBLE recovery: corrupt database files are deleted and the library database is recreated automatically.
- **Impeller rendering configurable** via bools.xml, disabled on API 24/25, enabled on API 26+.
- V1 and V2 APK signing enabled in release config.
- Notification channel creation guarded behind API 26 check.

### Updates & Distribution

- GitHub release update checks for non-Play Store builds with customized update messages

### UI Polish & Fixes

- Song auto-added to player queue when added to a playlist
- Audio info bottom sheet expanded to `ConsumerStatefulWidget` with swipeable page view
- Library auto-sync refactored to event-driven with full rescan support
- Equalizer initialized on app start and reapplied after audio session changes
- Star animation overflow clamped; disc scale clamped to prevent zero/negative values
- Ring buffer write logic fixed to handle full buffer gracefully
- Bluetooth devices handled more gracefully; scratch buffer grown
- Center logo Svg in app info settings screen; version string formatting fix
- SmartMixDetailScreen back button moved from `SliverAppBar` leading to overlay position
- Version strings in UI now reference `kAppVersion` constant instead of being hardcoded

## Files Changed

| Area | Key Paths |
| --- | --- |
| UAC Parsing | `rust/src/uac2/`, `rust/src/uac1/`, `rust/src/uac/` |
| DSD Bit Order | `rust/src/audio/dsd_engine/format/`, `rust/src/audio/dsd_engine/dop.rs`, `rust/src/audio/dsd_engine/output_router.rs` |
| I32 Streams | `rust/src/audio/android_output.rs`, `rust/src/audio/stream_kind.rs` |
| Artist Theming | `lib/features/artist/screens/artist_detail_screen.dart`, `lib/models/artist_entity.dart`, `lib/services/artist_repository.dart` |
| Playlist Theming | `lib/features/playlist/screens/playlist_detail_screen.dart`, `lib/features/playlist/widgets/playlist_info_chips.dart` |
| Vinyl Disc | `lib/features/player/widgets/vinyl_disc_painter.dart`, `lib/features/player/screens/full_player_screen.dart` |
| Nav Bar | `lib/widgets/flick_nav_bar.dart`, `lib/providers/nav_bar_provider.dart` |
| Milestones | `lib/services/milestone_service.dart`, `lib/features/milestones/`, `test/services/milestone_service_test.dart` |
| What's New | `lib/features/whats_new/`, `lib/providers/whats_new_provider.dart` |
| Folder Browser | `lib/features/folders/screens/folder_browser_screen.dart` |
| Build Config | `android/app/build.gradle.kts`, `android/app/src/main/res/values/bools.xml` |
| App Constants | `lib/core/constants/app_constants.dart`, `lib/features/settings/screens/app_info_settings_screen.dart` |

## Upgrading

1. The What's New screen appears automatically on first launch after updating — no configuration needed
2. The vinyl disc morph is activated by tapping album art in the player; rotation seeking works after the single-tap outline animation
3. Navigation bar collapse happens automatically after the idle timeout; adjust or disable from Settings > Interface
4. minSdk remains 26 (Android 8.0+) — Android 7.0/7.1 are not supported
5. Impeller is disabled on API 24/25 and enabled on API 26+ via `bools.xml` per-density resources
6. Non-Play Store builds will now check for updates via the GitHub Releases API
7. Ambient background effects have been removed entirely — the menu screen hero now uses color extraction from album art
8. If an incompatible Isar database is detected, the local library is recreated automatically; users may need to rescan music folders
