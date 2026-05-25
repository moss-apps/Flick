# Flick 0.16.0-beta.1

0.16.0-beta.1 is the audio engine release. Native DSD playback, a 31-band parametric equalizer, full metadata editing, song sharing, star ratings, a flagship home widget redesign, USB volume control, and a reworked audio backend selection system all land in this beta. The Rust engine can now deliver raw DSD bitstreams to your DAC, modify tags in-place, and export share cards for your music.

## Overview

This beta adds eleven headline features:

1. **DSD playback engine** — native DSD, DoP (DSD over PCM), Auto mode, and PCM decimation for DSF, DFF, and WavPack DSD files
2. **Metadata editor** — read and write audio tags (title, artist, album, year, genre, track number) via a Rust backend, with SAF file writing on Android
3. **Parametric equalizer 31-band** — expanded from 10 to 31 bands at 1/3-octave ISO frequencies, with horizontal band editors and a detail panel
4. **Song sharing cards** — four share card templates (album art, lyrics, minimal, solid color) with export and save-to-gallery
5. **Star rating system** — 1–5 star ratings on songs with animated overlay, persistent storage, and custom player action button placement
6. **Flagship home widget v2** — new card and split layouts, tabbed widget settings, multi-widget support
7. **USB volume control** — dedicated volume popup with slider and mute for isochronous USB audio engines
8. **Album and folder sorting** — sort albums and folders by title, artist, duration, track count with persistent preferences
9. **Audio engine selector** — manual engine selection from the menu screen, toggleable from UI settings
10. **Lyrics enhancements** — length tag injection, filename matching preferences, save location dialog, preview filtering
11. **UAC2/DAC backend refactor** — scoring-based output strategy selection, DAP detection via signature registry, device compatibility guides

## Highlights

- **DSD playback**: The Rust DSD engine supports three output modes — Native (raw bits via JNI `AudioTrack` with `ENCODING_DSD`), DoP (packed into 24/32-bit PCM frames with 0x05/0xFA markers, up to DSD512), and PCM decimation (CIC+FIR conversion to integer-multiple PCM rates). Auto mode probes device capabilities at runtime and picks the best available path. WavPack DSD files (`.wv`) are automatically detected via mode flags and routed to the DSD engine. WavPack PCM files route through Symphonia.
- **Metadata editor**: Full tag editing built into the player screen. Reads/writes ID3, Vorbis comments, and other tag formats through a Rust metadata editor module (`lofty`-powered). Changes are written to the file via Android's SAF (for content URIs) or direct filesystem access. Scanner preserves local edits on rescan and skips background metadata for edited songs. New year and genre fields in the song model with sort support.
- **31-band EQ**: Parametric equalizer expanded from 10 to 31 bands using 1/3-octave ISO center frequencies (20 Hz–20 kHz). UI redesigned with horizontal band editors and a detail panel for precise adjustments. Import/export still supported in JSON and TXT formats.
- **Share cards**: Share a song as an album art card, lyric card, minimal text card, or solid color card. Templates render the song info, album art, and share app. Cards can be saved to the device gallery as images. Accessible from the song actions bottom sheet.
- **Star ratings**: Tap stars on any song card or in the full player. Animated star overlay with half-star precision. Ratings stored persistently per song and accessible as a sort option. The rating button is one of several customizable player action buttons.
- **Flagship widget**: New larger widget layouts — a full card widget with album art, playback controls, and progress bar; a split layout with art on one side and controls on the other. Widget settings screen restructured with tabbed interface separating mini player and flagship widget options. Multi-widget support with per-widget theme preferences.
- **USB volume popup**: When using the isochronous USB audio engine, a dedicated volume popup provides precise slider control and mute. Accessible from a player action button and the audio settings screen.
- **Engine selector**: Choose your audio engine manually from a card on the main menu screen. The selector is toggleable from Settings > Interface. Helpful when auto-selection picks a suboptimal path for your setup.
- **Lyrics polish**: Synced LRC output now includes a `[length:]` tag with total duration. Save location dialog lets you choose where to export LRC files. New lyrics filename matching preference syncs sidecar filenames to the audio filename. Online lyrics search now shows previews and supports filtering.
- **Backend refactor**: The audio backend selection system was rewritten to use a scoring-based approach — each backend (USB Direct, DAP Native, Mixer, etc.) returns a compatibility score, and the highest scorer wins. DAP detection moved from a brand enum to a signature registry for easier extensibility. Device compatibility guides and extensibility docs added for DAC/DAP developers.

## What's New

### DSD Playback Engine

- **Native DSD**: JNI `AudioTrack` backend opens Android `AudioTrack` with `ENCODING_DSD` (encoding 29). A dedicated render loop feeds raw DSD bytes from the engine's ring buffer directly to the DAC — no PCM conversion, no decimation. Supports DSD64–DSD512.
- **DoP transport**: DSD bits packed into 24-bit or 32-bit PCM frames with 0x05/0xFA marker bytes. DSD64 → 176.4k 24-bit, DSD128 → 352.8k 24-bit, DSD256 → 705.6k 24-bit, DSD512 → 705.6k 32-bit. Dual-probe fallback at init: tries original DSD rate then 2× rate. Supports USB Direct and Mixer strategies.
- **Auto output mode**: Runtime probing chain: Native DSD (DAP brand/model check + `ENCODING_DSD` probe) → DoP → PCM decimation. Picks the highest-fidelity working path. Effective mode is displayed in debug state JSON.
- **Format decoders**: DSF (Sony container, `dsf-meta`), DFF (Philips container, `dff-meta`), WavPack DSD (`.wv` with DSD content, vendored `wavpack-sys` FFI crate). WavPack PCM support via dedicated decoder thread with resampling and channel remixing.
- **Decimation pipeline**: CIC+FIR decimator converts DSD to integer-multiple PCM rates (44.1k–705.6k). CIC filter state split into integer and fractional parts for precision. FIR tuned to 256 taps with Kaiser beta 8.0. Sinc filter formula corrected with frequency response test. `SequentialBlocks` deinterleaving for channel layout support.
- **DSF fixes**: Seek calculation corrected for metadata chunks. Sample counting fixed for multi-block streams. Sample data offset read from FMT chunk metadata (not hardcoded).
- **Experimental gating**: Native, DoP, and Auto modes gated behind an experimental flag. Only PCM decimation is ungated by default. DSD rate label and quality badge displayed in the full player screen.

### Metadata Editor

- Rust metadata editor module reading and writing tags via `lofty` (ID3, Vorbis comments, APE tags)
- Dart `MetadataEditorService` bridging the Rust FFI
- Metadata editor screen: edit title, artist, album, album artist, year, genre, track number, comment
- SAF file writing via `writeFileBytesViaSaf` method channel for content URI files
- Direct filesystem writes for regular files
- `hasLocalEdits` field on `SongEntity` tracks locally modified metadata
- Scanner skips background metadata extraction for locally edited songs
- Scanner preserves local edits when matching scanned songs to existing database entries
- Year and genre fields added to `Song` model with sort options

### Parametric Equalizer 31-Band

- Expanded from 10 to 31 bands at 1/3-octave ISO center frequencies (20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000 Hz)
- UI redesigned with horizontal band editors showing frequency, gain, and Q per band
- Detail panel for precise gain/Q entry on the selected band

### Song Sharing Cards

- **Album Art Share Card**: full-bleed album artwork with song title and artist overlay
- **Lyric Share Card**: current lyrics rendered as styled text
- **Minimal Share Card**: clean text-only layout
- **Solid Color Share Card**: single-color background with song info
- Share bottom sheet: select template → share via system share sheet or save to gallery
- `share_plus` integration for cross-app sharing

### Star Rating System

- `RatingButton` widget: 1–5 stars with animated overlay and half-star precision
- `RatingService` persists ratings per song
- `RatingProvider` for reactive state management
- Player action buttons are now customizable — left and right button slots configurable in preferences
- `PlayerActionButton` model with enum of available actions (rating, share, lyrics, visualizer, shuffle, loop, etc.)

### Flagship Home Widget v2

- `FlagshipWidgetProvider` (Kotlin): new `AppWidgetProvider` with theme support
- Card layout: full-bleed album art, progress bar, play/pause/skip controls
- Split layout: album art on one side, controls and info on the other
- Widget settings screen restructured with tabbed interface:
  - Mini player tab: existing customization (background, accent, content toggles)
  - Flagship tab: new theme and layout preferences
- Multi-widget implementation plan for future widget variants
- Flick logo drawable added for widget branding

### USB Volume Control

- `IsoVolumePopup` widget: slider + mute toggle for isochronous USB audio engines
- Accessible as a player action button
- UAC2 volume control section added to audio preference screen
- Only active when the isochronous USB engine is running

### Album and Folder Sorting

- Album sort sheet: sort by title, artist, duration, track count with ascending/descending toggle
- Folder sort sheet: sort by name, song count, duration
- Sort preferences persist across sessions
- Songs within albums sorted by album before display
- Folder entries sorted before display in song list

### Audio Engine Selector

- Engine selector card on the main menu screen showing available audio engines
- Toggle visibility from Settings > Interface > UI Customization
- `showEngineSelector` preference with persistence
- Useful for manual override when auto-selection picks a suboptimal path

### Lyrics Enhancements

- `[length:MM:SS.XX]` tag injected into synced LRC output with formatted total duration
- Save location dialog: choose export directory when saving LRC files
- Lyrics filename matching preference: sidecar filenames can sync to the audio filename
- Lyrics settings screen: configure filename matching and other lyrics preferences
- Online lyrics search now shows preview snippets for each result
- Search results support filtering (synced, plain-text, instrumental)
- Lyrics panel UI polished with accent-colored chips and improved empty state

### UAC2 / DAC Backend Refactor

- Audio backend selection rewritten to use scoring-based candidates instead of hardcoded fallbacks
- Each backend (`UsbDirect`, `DapNative`, `MixerBitPerfect`, etc.) returns a compatibility score
- DAP device detection moved from brand enum to signature registry — new brands/models can be added without modifying core logic
- `AudioBackend` trait with `descriptor()` method for backend metadata
- USB DAC compatibility notice widget added to UAC2 settings
- Device compatibility guide expanded with MOONDROP Dawn Pro
- DAC/DAP extensibility guide documentation for developers

### List Pagination and UI Performance

- Songs and folder screens now use paginated lists with cached artwork
- `SongsState` refactored to compute sorted songs and folder groups in the factory constructor (one-time computation)
- Folder navigation uses `MaterialPageRoute` instead of custom `PageRouteBuilder`

### Library Scanner

- Per-folder deep scan override: individual folders can bypass the fast scan and use full filesystem scanning
- `useDeepScan` preference controls the default behavior
- `FolderEntity` extended with `useDeepScan` field, preserved on upsert
- Audio file extension filter removed — scanner now considers all files in configured directories

### Other Improvements

- **Nav bar overflow**: Animated overlay menu for nav items that don't fit. Labels wrapped with `FittedBox` to prevent overflow. Warning shown when >4 buttons are enabled.
- **Programmatic nav**: Disabled essential pages can still be navigated to programmatically (e.g., from widget intents or deep links).
- **Album art grid**: Album art candidates screen redesigned with grid layout for faster browsing. Aspect ratio adjusted for better thumbnails.
- **Notification colors**: Album artwork colors extracted for the music notification background. Color parameter added to notification service.
- **Bit-perfect safety**: Bit-perfect mode default volume set to -40 dB safety level to prevent ear-splitting output when switching to a high-gain USB path.
- **Crossfade fix**: Engine correctly marks as stopped when crossfade completes with no next source (prevents stuck state).
- **Track update**: `updateTrack` method added to Rust audio engine for in-place track metadata updates.
- **Backend path fix**: Rust backend path mismatch handled correctly after skipping a track.
- **Song card refactor**: Swipe overlay conditionally rendered to reduce widget tree overhead.
- **Lyrics scroll**: Scroll animations chained sequentially for smoother transitions.
- **Bottom sheet**: Height constrained to 50% of screen for better one-handed use.
- **Dynamic padding**: Header styling updated with dynamic padding fix.
- **Compatibility notice**: Bit-perfect toggle disabled when isochronous USB engine is not active.

## Known Issues

- **DSD volume control**: PCM decimation produces silence when DoP is not available, blocking the volume control fallback path. Hardware volume is used as primary control; digital volume is not available for native DSD streams. See `docs/DSD_VOLUME_CONTROL_STATUS.md` for details.
- **Experimental DSD modes**: Native, DoP, and Auto modes are gated behind an experimental flag. These paths are functional but not yet enabled by default. PCM decimation remains the default DSD output mode.
- **WavPack PCM decoding**: WavPack PCM files route through a dedicated WavPack decoder thread (not Symphonia). Resampling and channel remixing are supported but some edge cases with hybrid/lossy WavPack may differ from the standard decoder path.
- **Metadata editor**: Writing tags to content URI files (SAF) requires Android to grant write access. Some file managers may not propagate write permissions to the staging cache.

## Files Changed

| Area | Key Paths |
| --- | --- |
| DSD Engine | `rust/src/audio/dsd_engine/`, `rust/src/audio/decoder_handle.rs`, `rust/src/audio/strategy.rs` |
| WavPack | `rust/vendor/wavpack-sys/`, `rust/src/audio/wavpack_decoder.rs` |
| DSD Formats | `rust/src/audio/dsd_engine/format/dsf.rs`, `dff.rs`, `wavpack.rs` |
| DoP Pipeline | `rust/src/audio/dsd_engine/dop.rs`, `pipeline.rs`, `pcm_output.rs`, `output_router.rs` |
| Native JNI | `rust/src/audio/dsd_engine/native/`, `android/.../audio/DsdAudioTrackManager.java` |
| Engine Core | `rust/src/audio/engine.rs`, `rust/src/audio/backend.rs`, `rust/src/audio/resampler.rs` |
| Metadata Editor | `rust/src/metadata_editor/`, `lib/services/metadata_editor_service.dart`, `lib/features/player/screens/metadata_editor_screen.dart` |
| EQ | `rust/src/audio/equalizer.rs`, `lib/features/settings/equalizer_screen.dart` |
| Sharing | `lib/widgets/share_cards/`, `lib/features/player/widgets/share_bottom_sheet.dart` |
| Rating | `lib/widgets/rating_button.dart`, `lib/providers/rating_provider.dart`, `lib/services/rating_service.dart` |
| Widget v2 | `android/.../widget/FlagshipWidgetProvider.kt`, `lib/features/settings/screens/widget_settings_screen.dart` |
| USB Volume | `lib/widgets/iso_volume_popup.dart`, `lib/features/settings/screens/uac2_preferences_screen.dart` |
| Sorting | `lib/features/albums/screens/album_sort_sheet.dart`, `lib/features/folders/screens/folder_sort_sheet.dart` |
| Engine Selector | `lib/features/home/widgets/menu_screen.dart`, `lib/providers/app_preferences_provider.dart` |
| Lyrics | `lib/services/lyrics_service.dart`, `lib/services/online_lyrics_service.dart`, `lib/features/settings/screens/lyrics_settings_screen.dart` |
| UAC2/DAC | `rust/src/uac2/backend.rs`, `rust/src/audio/dap_profile.rs`, `rust/src/audio/output_strategy.rs` |
| Scanner | `lib/services/library_scanner_service.dart`, `rust/src/api/scanner.rs` |
| Nav Bar | `lib/widgets/flick_nav_bar.dart` |
| Player UI | `lib/features/player/screens/full_player_screen.dart`, `lib/features/player/widgets/player_action_buttons.dart` |
| Docs | `docs/DSD_ARCHITECTURE.md`, `docs/DSD_VOLUME_CONTROL_STATUS.md`, `docs/DAC_EXTENSIBILITY.md` |

## Upgrading

1. This release adds the `ENCODING_DSD` AudioTrack path — no user action required beyond updating
2. Experimental DSD modes are disabled by default; enable from Settings > Audio > DSD Output Mode
3. WavPack DSD files (`.wv`) are automatically detected and routed — no configuration needed
4. Native DSD requires a device that reports `ENCODING_DSD` support (most DACs from Android 12+)
5. The 31-band EQ replaces the previous 10-band EQ — existing presets are compatible; new bands default to 0 dB gain
6. Metadata edits are written directly to files — back up your music if you plan to bulk edit
7. The flagship widget is a separate widget from the mini player — add it from your launcher's widget picker
8. Engine selector is hidden by default — enable from Settings > Interface > UI Customization
