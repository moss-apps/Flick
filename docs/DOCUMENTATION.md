# Flick Player Documentation

## About Flick Player

**Flick Player** is a modern, high-performance music player application designed for audiophiles and casual listeners alike. Primarily running on Android, it bridges the gap between a beautiful, fluid user interface and a robust, low-level audio processing engine with advanced equalizer and effects capabilities.

The application leverages the power of **Flutter** for a responsive, animated frontend and **Rust** for a stable, efficient backend. Key features include a custom "Function Code" (Audio Engine) that handles playback independent of the OS media controls in some aspects, ensuring high-fidelity audio output, along with advanced EQ and FX processing capabilities. The engine supports multiple output paths including USB DAC bit-perfect playback, Android's internal high-resolution audio path (DAP), and standard Android audio output. Recent additions include a home screen mini player widget, online lyrics search with a built-in timestamp editor (Lyrics Sync Studio), visualizer customization (animation styles, frequency modes, movement modes), a queue management overhaul, folder grid browsing, immersive full view, swipe actions on songs, Bluetooth codec reference display, and Play Store in-app updates.

### Digital Audio Player (DAP) Support

Flick Player includes support for Digital Audio Player (DAP) functionality through Android's audio subsystem:

- **DAP Internal High-Res Mode**: When no USB DAC is connected, the app can utilize Android's internal DAC in high-resolution mode through Oboe/AAudio in exclusive mode when supported by the device
- **Device Qualification**: The app checks device capabilities (manufacturer, brand, model, and audio capabilities) to confirm bit-perfect support through the internal audio path
- **Sample Rate Handling**: Supports high sample rates up to the device's maximum capabilities
- **Exclusive Mode**: Attempts to open audio streams in exclusive mode for lower latency and better performance when available

#### Supported DAP Brands & Models

The application identifies and optimizes for several known DAP brands and model series:

- **Supported Brands**:
  - FiiO
  - iBasso (including special "Mango Mode" detection)
  - HiBy
  - Shanling
  - Astell&Kern / iRiver
  - Cayin
  - Sony (Walkman series)
- **Known Model Prefixes**:
  - FiiO: M-series (M11, M15, M17, M21, M23, M27), JM-series (JM21)
  - iBasso: DX-series (DX160 through DX340)
  - HiBy: R-series (R3 through R8), M-series (M300, M0 through M8)
  - Astell&Kern: SA, SP, SE, A& series
  - Sony: NW-A, NW-WM, NW-ZX series
  - Other: Any device with a recognized DAP model prefix, no telephony, and high-res internal audio (>= 88.2 kHz) is classified as a DAP and marked as confirmed bit-perfect.

### Engine Architecture

The core audio engine in `rust/src/audio/engine.rs` features a sophisticated architecture designed for high-performance audio processing:

- **Lock-Free Design**: Uses atomic operations and lock-free data structures in the audio callback to prevent audio glitches
- **Multiple Output Strategies**: Dynamically selects between USB Direct, DAP Native, Mixer Bit-Perfect, Mixer Matched, and Resampled Fallback based on device capabilities
- **Real-Time Processing Chain**: Implements a complete DSP chain including volume control, 10-band graphic equalizer with preamp, spatial/time FX, dynamics processing (compressor/limiter), playback speed control, and crossfading
- **Runtime Pipeline Mode**: Dynamically selects between `Passthrough` (bit-perfect, skips all DSP) and `Dsp` (full processing chain) at runtime, based on output strategy and device capabilities
- **Continuous Verification**: Constantly monitors and verifies that the actual output matches the requested format for quality assurance
- **Thread Safety**: Properly separates real-time audio processing (lock-free) from control operations (thread-safe)

#### Output Strategies

The engine implements five distinct output strategies:

1. **USB Direct (`UsbDirect`)**: Bit-perfect playback through external USB DACs using libusb isochronous transfers (requires UAC 2.0 feature). The UAC2 pipeline info and transfer stats widgets have been removed from the UI, but the core engine remains.
2. **DAP Native (`DapNative`)**: High-resolution audio through device's internal DAC using Oboe/AAudio in exclusive mode
3. **Mixer Bit-Perfect (`MixerBitPerfect`)**: Android mixer path with bit-perfect format matching (Android 14+)
4. **Mixer Matched (`MixerMatched`)**: Android mixer path with sample rate conversion when needed
5. **Resampled Fallback (`ResampledFallback`)**: Fallback path with resampling when exact format matching isn't possible

Each strategy is selected based on device capabilities and current playback requirements, with runtime verification ensuring the selected path meets quality expectations. The engine supports multiple output paths including USB DAC bit-perfect playback, Android's internal high-resolution audio path (DAP), and standard Android audio output.

## Planned Features

The current roadmap includes:

- **DSD/DSF support**: Full engine-level native DSD/DSF decoding and playback (in progress)
- MQA support
- Poweramp-style EQ filters, including low-pass
- Themes and broader UI customization options
- Advanced audio tweaks
- Android audio settings
- Internal Hi-Res audio settings
- USB audio tweaks
- Further performance optimizations

### Deprecated / Removed

- **GitHub Releases**: Will be deprecated once Flick's open beta test begins. Install from the Google Play Store to continue receiving updates.

### Recently Completed

- **Home Screen Widget**: Native Android mini player widget with album art, progress bar, and transport controls. Customizable background, accent, and content visibility. Works when app is killed.
- **Online Lyrics Search**: Search for synced (LRC) or plain-text lyrics via LRCLib.net with exact-match and fuzzy search
- **Lyrics Sync Studio**: Built-in timestamp editor with Simple (tap-to-stamp) and Advanced (direct edit) modes, time-shift tools, file import, and reset
- **Visualizer Customization**: Five animation styles, five frequency modes, three movement styles via dedicated settings screen
- **Queue Management Overhaul**: Now Playing / Up Next / Manual queue with multi-select, batch remove, drag to reorder, clear all, swipe to dismiss
- **Folder Grid View**: Paginated grid of folder cards with infinite scroll when browsing by folder
- **Immersive Full View**: Auto-hiding controls with full-bleed album art, floating metadata card, visualizer-only mode
- **Swipe Actions**: Swipe left to queue, right to favorite on song cards (toggleable)
- **Player Layout Customization**: Artwork card scale, text size, text placement, metadata visibility preferences
- **Bluetooth Codec Info**: Reference display of supported codecs and current route in Audio settings
- **Play Store Updates**: Automatic and manual update checks with Play Store integration
- **Audio Visualizer**: FFT-based 48-bar visualizer with real-time Android Visualizer API + simulated fallback (spring-physics smoothing, glow effects)
- **Album Art Import**: Online album art search from MusicBrainz/Cover Art Archive, iTunes, and Deezer with score-based deduplication
- **Delete Song**: Library removal and file deletion with SAF content URI awareness
- **Content URI Staging**: Android SAF content URIs staged to local cache for reliable playback, with ALAC/AIFF/M4A to WAV conversion
- **Flick Replay Recap**: Daily/weekly/monthly/yearly listening recaps with hero cards, ranking posters, custom backgrounds (album art / camera photo), and gallery export. CSV/TXT export support.
- **Rip Log Metadata**: EAC-style rip metadata (ripper, read mode, AccurateRip, CRCs) stored per track
- **CUE Sheet Support**: Track start/end offset support for CUE sheet-based files
- **In-App Updates**: Shorebird code push replaced with Google Play InAppUpdate API
- **Hardware Volume Control**: Three-tier volume system with UAC2 Feature Unit SET_CUR, Rust engine f32 multiply, and Android system fallback
- **MediaStore Scanning**: ~34× faster library scanning via Android MediaStore queries with differential sync, background metadata extraction, and live content observer
- **USB Audio Detection**: Improved Android-side detection with expanded keyword matching and AudioManager fallback for USB audio devices
- **Device Connect Toast**: Snackbar notification when UAC2 device connects or starts streaming, showing device name and format
- **Crossfade Curve in Bit-Perfect Mode**: Crossfade curve is no longer set when bit-perfect mode is active (avoids unnecessary configuration)
- **Android 7 Dropped**: minSdk raised from 21 to 26; Android 7 crash (Impeller + missing desugaring) resolved by dropping API 21–25

## Code "Functions" (Core Architecture)

The application behaves as a hybrid system. Here is a breakdown of the key *Function Codes* (modules) that drive the application:

### 1. The Core Audio Engine (Rust)

Located in `rust/src/audio`, this is the heart of the application. It bypasses standard high-level players to give direct control over the audio stream.

- **Engine (`engine.rs`)**: The central coordinator featuring a lock-free architecture for real-time audio processing. It runs on a designated high-priority thread to ensure music never stutters, managing the flow of data from the file to the speakers. The engine implements multiple output strategies:
  - **USB Direct**: Bit-perfect playback through external USB DACs using libusb isochronous transfers
  - **Android Managed**: Standard audio playback through Oboe/AAudio or the Android mixer
  - **DAP Internal High-Res**: High-resolution audio through the device's internal DAC using Oboe/AAudio in exclusive mode

- **Decoder (`decoder.rs`)**: Uses `symphonia` to read various audio formats (MP3, FLAC, WAV, OGG, M4A, ALAC, AIFF) and decode them into raw sound waves (PCM).
- **ALAC Converter (`alac_converter.rs`)**: Lossless real-time conversion of ALAC/M4A/AIFF files to WAV/PCM, preserving original bit depth (16/24/32-bit). Session-based streaming conversion for memory efficiency.
- **Resampler (`resampler.rs`)**: Uses `rubato` to change the audio quality on-the-fly. If a song is 44.1kHz but your speakers are 48kHz, this module smooths out the difference without losing quality.
- **Crossfader (`crossfader.rs`)**: Handles the smooth blending between songs, so there is no silence when one track ends and the next begins.
- **Equalizer (`equalizer.rs`)**: Implements a 10-band graphic equalizer with preamp control and parametric band support for precise tonal control.
- **FX Processing (`fx.rs`)**: Implements spatial and time effects including balance, tempo, damp, filter, delay, size, mix, feedback, and width for creative audio processing.
- **Android Audio Processing (`android_audio_processing_service.dart`)**: On Android, uses JustAudioProcessingController for enhanced EQ and effects management with real-time processing capabilities.
- **Source Provider (`source.rs`)**: Manages the queue for **Gapless Playback**, ensuring there are no awkward pauses between tracks by pre-loading the next song before the current one finishes.
- **Dynamics Processing**: Includes compressor and limiter modules for dynamic range control when needed.
- **Output Verification**: Continuously verifies that the actual output matches the requested format for bit-perfect playback assurance.
- **PCM Conversion**: ALAC/AIFF/M4A files are automatically converted to WAV/PCM for compatibility.

### 2. Album Art Import Service

- **Album Art Import Service (`album_art_import_service.dart`)**: Searches for album art from online sources in cascade order: MusicBrainz/Cover Art Archive (primary), iTunes (fallback), Deezer (fallback). Uses score-based deduplication (by image URL, max 12 candidates), validates image headers (PNG/JPEG/WebP/GIF/BMP), saves to `album_art_overrides/` directory, and syncs to all songs in the same album. Supports custom artwork removal.

### 3. EQ Preset Management

- **EQ Preset File Service (`eq_preset_file_service.dart`)**: Handles conversion of EQ presets between JSON and TXT formats for import/export functionality.
- **EQ Preset Service (`eq_preset_service.dart`)**: Manages EQ preset operations including saving, loading, and organizing presets.
- **Equalizer Service (`equalizer_service.dart`)**: Applies EQ and FX settings to the audio stream, integrating with both Rust engine and Android processing service.

### 4. Home Screen Widget

- **Widget Sync Service (`widget_sync_service.dart`)**: Pushes playback state (title, artist, album art, position, progress, shuffle, loop mode, queue count) to the native Android widget via `HomeWidget`. Debounces non-critical updates to every 2 seconds.
- **Widget Intent Handler (`widget_intent_handler.dart`)**: Listens on a `MethodChannel` and dispatches widget URI actions (play_pause, next, previous, shuffle, repeat, open queue) to the player provider.
- **MiniPlayerWidgetProvider (Kotlin)**: Native `AppWidgetProvider` rendering album art, song info, progress bar, and transport controls. Shows idle "Tap to open" state when the app is killed, active state during playback.
- **WidgetActionReceiver (Kotlin)**: `BroadcastReceiver` forwarding widget button taps to Flutter via `MethodChannel`, or launching the app with the action intent if killed.
- **WidgetPrefs (Kotlin)**: Reads shared preferences for widget state and customization (background opacity, accent color, content toggles).
- **Widget Settings Screen (`widget_settings_screen.dart`)**: UI for customizing background opacity, accent color, and visible content (album art, artist name).

### 5. Lyrics System

- **Lyrics Service (`lyrics_service.dart`)**: Core lyrics loading with priority chain: manual overrides > embedded lyrics (via platform channel) > sidecar `.lrc`/`.txt`/`.xml` files. Handles LRC parsing with `[mm:ss.xx]` timestamps, `[offset:]` tags, word-level tags, XML `<line start="...">`, and saving.
- **Online Lyrics Service (`online_lyrics_service.dart`)**: HTTP client for LRCLib.net. `/api/get` for exact match, `/api/search` for fuzzy search. Returns synced, plain-text, or instrumental lyrics.
- **Online Lyrics Search Sheet (`online_lyrics_search_sheet.dart`)**: Bottom sheet UI showing exact match results, search bar, and scrollable result cards with synced/plain/instrumental badges.
- **Lyrics Editor Bottom Sheet (`lyrics_editor_bottom_sheet.dart`)**: Full lyrics editor with Simple mode (tap "Stamp & Next" to timestamp as song plays, auto-advance) and Advanced mode (edit each timestamp directly). Includes playback assist bar, time-shift tools (+/- 100ms, +/- 500ms), auto-fill for unstamped lines, and LRC generation with metadata tags.

### 6. Audio Visualizer

- **Visualizer Service (`visualizer_service.dart`)**: Bridges Android's native `Visualizer` API via MethodChannel/EventChannel. Attaches to an Android audio session and delivers FFT data as 48 normalized bar magnitudes with logarithmic frequency distribution.
- **Audio Visualizer Widget (`audio_visualizer.dart`)**: 48-bar visualizer rendered via `CustomPainter` with spring-physics smoothing, glow effects (`MaskFilter.blur`), and two modes: real data (native FFT) and simulated (animated random bars seeded by song duration). Integrated into the full player screen with a toggle button.
- **Full Player Screen**: Visualizer mode replaces album art with the AudioVisualizer widget when toggled.
- **Visualizer Settings Screen (`visualizer_settings_screen.dart`)**: Dedicated settings for choosing animation style (Bars, Wave, Curved Wave, Mirrored, Dots), frequency focus (Full Spectrum, Bass, Mid, Treble, Bass + Treble), and movement style (Bouncy, Smooth, Snappy).

### 7. Queue Management

- **Queue Screen (`queue_screen.dart`)**: Restructured into three sections: Now Playing (current song card), Up Next (auto-generated, swipe to dismiss), Manual queue (user-added, drag to reorder via `SliverReorderableList`). Per-item actions include "Play next" and "Remove".
- **Up Next Notifier**: Independent state for upcoming songs, separated from the manual queue.
- **Multi-select Mode**: Enter via checkbox icon or long-press. Supports Select All and batch removal (reverse-order index removal).
- **Clear All**: One-tap removal of all upcoming and queued songs.

### 8. Flick Replay (Listening Recap)

### 8. Flick Replay (Listening Recap)

- **Recap Screen (`listening_recap_screen.dart`)**: Generates daily, weekly, monthly, and yearly listening recaps with hero cards (total plays, top song, listen time, active days, peak hour) and ranking posters (top 5 songs, top 5 artists). Supports three poster background modes: default gradient with glowing orbs, blurred album art, or user's camera photo. Recap images can be saved to the device gallery as PNG at 3x resolution. Export recap data as CSV or TXT.

### 9. Content URI & Song Management

- **Content URI Staging**: Android SAF content URIs are staged to a local cache directory (`cacheDir/playback_staging/`) via a Kotlin native method channel. Supports ALAC/AIFF/M4A files via WAV conversion for compatibility with the Rust decoder.
- **Delete Song**: Songs can be removed from the library or deleted from disk. SAF content URIs (`content://`) are excluded from file deletion. Falls back to library-only removal on file deletion failure.

### 10. The Interface (Flutter)

The visual layer that interacts with the user:

- **State Management (Riverpod)**: Keeps the UI in sync with the actual player state. If the song changes in the Rust engine, Riverpod updates the screen immediately.
- **Database (Isar)**: Stores the library information locally. Instead of re-scanning files every time, the app loads them instantly from this fast, local database.
- **Visuals**: Uses `Rive` for complex animations and `Skeletonizer` for loading states, ensuring the app feels "alive".
  - **Theme Selection**: Implemented with adaptive theming based on album artwork colors, featuring glassmorphism design elements.
  - **Equalizer Screen**: Enhanced UI for managing presets with import/export functionality, renaming, and saving capabilities.
  - **Player Screen**: Immersive mode support with conditional rendering of UI elements and improved lyrics display with tooltip guidance and line-seeking capability.
  - **Full Player Screen**: Optimized layout for various screen sizes with responsive design, high refresh rate support (90Hz/120Hz), audio visualizer toggle, and immersive full view with auto-hiding controls.
  - **Song Actions**: Bottom sheet with add to favorites/queue/playlist, set album art (via online import), view metadata, show in files, and delete (library only or with file removal).
  - **Immersive Full View**: Auto-hide all UI chrome after configurable delay, showing full-bleed album art with floating metadata card. Visualizer-only mode hides even the card. Customizable text size, placement, card scale, and metadata visibility.
  - **Swipe Actions**: Horizontal swipe on song cards — left to queue, right to favorite. Toggleable in settings, auto-disabled during multi-select.
  - **Folder Grid**: Paginated grid of folder cards (2 columns phone, 3 tablet) when sorted by folder, with lazy loading and infinite scroll.
  - **Dynamic Nav Bar**: Reorderable bottom navigation with show/hide per button.
  - **Fast Index**: Collapsible alphabetical scroll overlay with auto-hide timer for long lists.
  - **Player Layout Customization**: Artwork card scale, immersive view scale/offset, show/hide toggles for title, artist, album, and file info.
  - **Onboarding**: Redesigned with animated orb system and page interpolation.

### 11. The Librarian (Scanner & Metadata)

Flick uses a two-tier scanning architecture:

**Tier 1 — Android MediaStore** (primary, Android-only):
- `LibraryScannerService` queries Android's `MediaStore` for audio files in user-configured folders
- Differential sync against Isar database — only `NEW`/`MODIFIED` files get metadata parsing
- `MediaStoreObserverService` listens for `MediaStore` changes via content observer and triggers live rescans
- Non-audio files (CUE sheets, rip logs) are queried in a separate `MediaStore` pass
- Deletion detection queries `MediaStore` for missing files

**Tier 2 — Rust scanner** (legacy, used for direct filesystem access):
- Located in `rust/src/api/scanner.rs` and utilizing `lofty` and `rayon` for parallel processing
- Recursively walks user-defined folders, extracting metadata from ID3 tags, Vorbis comments, covers
- Used as fallback when `MediaStore` querying is unavailable

The combined approach delivered a **~34× speedup** (from 11–12s to 328ms for a 60GB / 1,287-track library).

## Simplified Explanation

Think of **Flick Player** like a professional restaurant kitchen:

- **The UI (Flutter)** is the **Dining Room**. It's decorated (Styles/Animations), where you (the User) order what you want to hear (Songs/Playlists).
- **The Bridge (FRB)** is the **Waiter**. It takes your order from the dining room and rushes it to the kitchen.
- **The Rust Engine** is the **Chef**. It takes raw ingredients (Audio Files), chops and prepares them (Decoding), seasons them (Resampling/Effects), and cooks them perfectly (Playback).
- **The Scanner** is the **Inventory Manager**. It checks the storage (Hard Drive) to see what ingredients are available and writes them on the Menu (Library).
