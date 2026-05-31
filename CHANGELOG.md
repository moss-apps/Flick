# Changelog

## 0.17.0-beta.1 (2026-05-31)

### BitPerfect Capsule/Indicator
- BitPerfect status capsule displayed in the player UI showing active bit-perfect mode
- Visual indicator for bit-perfect audio path engagement

### Player Layout Settings
- Configurable player layout options
- Settings screen for customizing the player layout

### Equalizer Paged Layout
- Equalizer redesigned with a paged layout for better navigation across 31 bands
- Improved band browsing and adjustment workflow

### Folder Filter/Sort Controls
- Folder filtering controls for narrowing down folder listings
- Enhanced folder sort options with dedicated controls

## 0.16.0-beta.1 (2026-05-26)

### Audio Engine & DSD Playback
- **Native DSD playback**: JNI `AudioTrack` backend with `ENCODING_DSD` (encoding 29) for raw bitstream delivery to DACs
- **DoP (DSD over PCM)**: DSD64–DSD512 packed into 24/32-bit PCM frames with 0x05/0xFA markers
- **DSD Auto output mode**: Smart runtime probing (Native → DoP → PCM decimation) based on device capabilities
- **WavPack DSD detection**: Automatic `.wv` file routing to DSD or PCM decoder via WavPack mode flags
- **DSD format decoders**: DSF (Sony), DFF (Philips), WavPack DSD support via vendored `wavpack-sys` crate
- **WavPack PCM decoder**: Dedicated decoder thread with resampling and channel remixing
- **CIC filter**: State split into integer and fractional parts for improved precision at high decimation ratios
- **FIR filter**: Tuned to 256 taps with Kaiser beta 8.0 (from 512 taps, beta 12)
- **Sinc filter**: Formula corrected with frequency response test
- `SequentialBlocks` deinterleaving for DSD channel layout support
- `excluded_strategies` parameter for engine initialization
- DSD source rate and effective mode fields in debug state JSON
- `DsdOutputMode::Auto`, `DsdOutputMode::Native` variants
- DoP frame offset fix in packing logic
- DSD output sample rate fix for Native and Auto modes
- DSF: seek calculation corrected, sample counting fixed, data offset from metadata
- DSF/DFF/WavPack DSD metadata scanning and artwork extraction
- DSD rate label and quality badge in full player screen
- DSD playback architecture documentation

### Metadata Editor
- Full metadata tag editing (read/write) via Rust `lofty` backend
- Dart `MetadataEditorService` bridging Rust FFI
- Metadata editor screen: title, artist, album, album artist, year, genre, track number, comment
- SAF file writing via `writeFileBytesViaSaf` method channel
- `hasLocalEdits` field on `SongEntity` tracking locally modified metadata
- Scanner skips background metadata for locally edited songs
- Scanner preserves local edits when matching scanned songs to existing entries
- Year and genre fields added to `Song` model with sort support

### Parametric Equalizer
- Expanded from 10 to 31 bands at 1/3-octave ISO frequencies (20 Hz–20 kHz)
- Horizontal band editors with per-band gain/Q display
- Detail panel for precise band adjustments

### Song Sharing
- Four share card templates: album art, lyric, minimal, solid color
- Share bottom sheet with template selection
- Share via system share sheet or save to gallery
- `share_plus` integration

### Star Rating System
- 1–5 star rating on songs with animated star overlay
- `RatingService` for persistent rating storage
- `RatingProvider` for reactive state
- Customizable player action button slots (left/right)

### Flagship Home Widget v2
- New `FlagshipWidgetProvider` (Kotlin) with theme support
- Card layout: album art, progress bar, transport controls
- Split layout: art on one side, controls on the other
- Widget settings restructured with tabbed interface (mini player / flagship)
- Multi-widget support with per-widget theme preferences

### USB Volume Control
- `IsoVolumePopup` widget with slider and mute toggle
- Player action button integration
- UAC2 volume control preferences section

### Album and Folder Sorting
- Album sort sheet: sort by title, artist, duration, track count with persistence
- Folder sort sheet: sort by name, song count, duration with persistence
- Songs sorted by album before display

### Audio Engine Selector
- Engine selector card on main menu screen
- Toggle visibility from Settings > Interface > UI Customization
- `showEngineSelector` preference

### Lyrics Enhancements
- `[length:MM:SS.XX]` tag in synced LRC output
- Save location dialog for LRC file export
- Lyrics filename matching audio filename preference
- Lyrics settings screen
- Online lyrics search preview snippets with filtering
- Lyrics panel UI: accent-colored chips, improved empty state

### UAC2 / DAC Backend Refactor
- Scoring-based audio output strategy selection
- DAP detection refactored from brand enum to signature registry
- `AudioBackend` trait with `descriptor()` method
- USB DAC compatibility notice widget
- Device compatibility guide expanded (MOONDROP Dawn Pro)
- DAC/DAP extensibility guide documentation

### Library Scanner
- Per-folder deep scan override
- `useDeepScan` preference
- `FolderEntity.useDeepScan` field preserved on upsert
- Audio file extension filter removed

### UI / Navigation
- Nav bar overflow: animated overlay menu for excess items
- Nav bar labels wrapped with `FittedBox`
- Warning shown when >4 nav bar buttons enabled
- Programmatic navigation to disabled essential pages
- Album art candidates grid layout redesign
- Song card swipe overlay conditionally rendered
- Lyrics scroll animations chained sequentially
- Bottom sheet height constrained to 50% of screen

### Notifications
- Album artwork color extraction for notification background
- Color parameter added to notification service

### Fixes
- Crossfade engine correctly marks stopped when no next source
- `updateTrack` method added to Rust audio engine
- Rust backend path mismatch after track skip fixed
- Bit-perfect mode default volume set to -40 dB safety level
- Dynamic padding and header styling fix

### Milestone Tracking
- Achievement milestones: 100, 500, 1,000 songs played; 10, 50 hours listened
- `MilestoneService` with play count and accumulated listen time tracking
- `MilestoneType` enum with title, message, and achievement date
- `pendingMilestoneNotifier` in `PlayerService` for milestone dialog triggers
- Milestone dialog displayed from app shell when a new milestone is achieved

### Donation & Support
- In-app Support Flick screen with animated info tiles (solo dev, where money goes, Ko-fi link)
- Pulsing heart icon with support button in settings header
- Ko-fi support button and credit line on listening recap screen
- External Ko-fi link replaced with in-app screen

### Welcome Card
- Animated welcome card on menu screen introducing the app and soliciting support
- Dismiss-to-close with animated transition
- `welcomeCardDismissed` preference for persistent dismissal

### Audio Engine Fixes
- Audio session now activated for Rust engine on Android (fixes audio focus/ducking)
- Volume slider gain mapping refined: 0-20 dB linear mapping replaces steep 0-60 dB curve
- WAV conversion/staging skipped for normal Android engine (not USB)

### UI Performance
- Orbit scroll refactored to use `ValueNotifier` with cache size limit
- Card width cached once and reused; `RepaintBoundary` wrapper removed
- `SingleChildScrollView` wrapper removed from column in full player screen

### Gated
- Native DSD, DoP, and Auto output modes marked experimental — disabled by default

---

## 0.15.0-beta.1 (2026-05-22)

### Added
- Home screen mini player widget (album art, progress bar, transport controls)
- Online lyrics search via LRCLib.net (exact match + fuzzy fallback)
- Lyrics Sync Studio (Simple + Advanced timestamp editor, time-shift tools, file import)
- Visualizer customization (5 animation styles, 5 frequency modes, 3 movement modes)
- Queue management overhaul (Now Playing / Up Next / Manual queue, multi-select, drag reorder)
- Folder grid (paginated, 2-col phone / 3-col tablet, infinite scroll)
- Immersive full view (auto-hide controls, floating metadata card, visualizer-only mode)
- Swipe actions (left to queue, right to favorite, toggleable)
- Player layout customization (artwork scale, text size/placement, metadata visibility)
- Play Store in-app updates (automatic + manual)
- Bluetooth codec info reference display
- Multi-select in songs screen (long-press for bulk queue/favorite)
- CSV/TXT export for listening recaps
- Favorite removal mode setting
- Widget customization (background opacity, accent color, content toggles)

### Changed
- Migrated to `ConcatenatingAudioSource` for queue
- In-place shuffle (audio source sequence shuffled instead of full rebuild)
- Fast index scrolling (collapsible alphabetical overlay with auto-hide)
- Reorderable bottom nav bar with show/hide per button
- Mini player redesign with progress bar and smaller controls
- Double back press to exit replaces auto-full-player navigation
- Onboarding redesigned with animated orb system
- Blur cache module-level for shared album art blur

### Deprecated
- GitHub Releases will be deprecated once open beta begins

---

## 0.14.0-beta.1 (2026-05-09)

### Added
- MediaStore-based library scanning (~34x faster: 328ms vs 11–12s for 60GB/1,287 tracks)
- Home screen toggle customization (Quick Access, Smart Mixes, Recent Artists, etc.)
- Configurable nav bar (reorder buttons, show/hide labels, dedicated settings screen)
- Album color theming (dynamic palette extraction from album art)
- Crossfade engine (curve selection, duration control, gapless playback)
- USB audio device detection with connection notifications
- Playback desync detection with auto-sync notification
- Undo support for queue and favorites removals
- Debounced Search screen

### Changed
- Default loop mode changed from `off` to `all`
- Snackbar duration reduced from 3s to 2s
- Duplicate entries removed from Recently Played
- Sort and file-type filter persist via SharedPreferences
- Launcher icons updated across mipmap densities
- Fingerprint cache service avoids re-reading unchanged files

### Breaking
- Android minSdk raised to 26 (dropping API 21–25)

---

## Pre-0.14.0 (notable earlier releases)

### 0.12.0-beta.2
- Last git-tagged release
- Foundation: Rust engine, just_audio fallback, UAC 2.0 subsystem, Isar database
- Library management (songs, albums, artists, playlists, favorites)
- Equalizer and audio effects
- Cross-app playback via Moss ecosystem (Locker integration)
- Flick Replay listening recaps
- Last.fm scrobbling

### 0.9.0 – 0.12.0
- Initial Flutter + Rust architecture
- DAP device detection and bit-perfect profiles
- USB Audio Class 2.0 descriptor parsing and device enumeration
- Symphonia-based PCM decoding
- Content URI staging and ALAC/AIFF/M4A conversion
- Album art import from MusicBrainz, iTunes, Deezer
- EQ preset management with import/export
- Hardware volume control (three-tier)
