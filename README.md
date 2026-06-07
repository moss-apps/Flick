# Flick Player
---
<p align="center">
  <img src="docs/app_screenshots/flick_banner.png" alt="Flick Player Banner" width="100%">
</p>

---
### Flick Player is a high-performance music player application built with Flutter and Rust, designed primarily for audiophiles who demand bit-perfect audio playback through external DACs and amplifiers.

> **Deprecation Notice**: GitHub Releases will be deprecated once Flick's open beta test begins. Install Flick from the [Google Play Store](https://play.google.com/store/apps/details?id=com.mossapps.flick) to continue receiving updates.

## Key Features

### Audio Engine
- **Primary**: Custom Rust audio engine with UAC 2.0 support for bit-perfect PCM and native DSD playback through USB DACs/AMPs. DSD bit order handling per source format (LSB/MSB) with quirk-based byte ordering for specific DACs. I32 integer stream support for DoP/DSD transport on DAP internal path.
- **DAP Bit-Perfect**: High-resolution playback through device's internal DAC via Oboe/AAudio exclusive mode, with device qualification for confirmed bit-perfect DAPs. I32 (integer) stream support for DoP and native DSD transport without format conversion.
- **Fallback**: `just_audio` for standard audio playback on devices without USB audio support
- **Audio Processing**: Advanced EQ, dynamics, and spatial/time effects via JustAudioProcessingController on Android
- **EQ Preset Management**: Import/export functionality for EQ presets in JSON and TXT formats with parametric band support
- **31-Band Parametric EQ**: Full 1/3-octave ISO frequency equalizer (20 Hz–20 kHz) with horizontal band editors and detail panel
- **Gapless Playback**: Seamless transitions between tracks without silence
- **Crossfade Support**: Configurable crossfade between tracks
- **Bluetooth Codec Info**: Reference display of supported Bluetooth audio codecs and current route
- **DSD Playback** (experimental): Native DSD, DoP, and PCM decimation output modes for DSF, DFF, and WavPack DSD files via custom Rust engine. USB direct native DSD with quirk-based byte ordering and multi-byte interleaved payload packing. I32 stream passthrough for DAPs.
- **Audio Engine Selector**: Manual engine selection from the main menu, with auto-detection fallback

### USB Audio Class 2.0 (UAC 2.0)
- Custom Rust implementation for USB DAC/AMP detection and enumeration
- Android-side detection with expanded keyword matching and AudioManager fallback
- Descriptor parsing for Audio Control and Audio Streaming interfaces
- Core isochronous transfer engine retained for direct USB access; standard playback routes through Android's native USB DAC handling
- Hot-plug detection with toast notifications on device connect/stream
- Bit-perfect PCM audio and native DSD bitstream delivery to external USB DACs
- **USB Volume Control**: Dedicated volume popup with slider and mute for isochronous USB audio engines
- **Scoring-Based Backend Selection**: Dynamic output strategy selection with compatibility scoring
- **DAP Signature Registry**: Device detection via extensible signature registry (brand/models)
- **DSD Quirks Table**: Per-device byte ordering overrides (endianness, bit reversal, subslot size) for native DSD compatibility (e.g., MOONDROP Dawn Pro)
- **Enabled by Default**: UAC2 feature and multi-byte DSD slots active by default

### Advanced Equalizer & Audio Effects
- 31-band parametric equalizer with preamp and controls
- Real-time audio processing with EQ, dynamics, and spatial effects
- Preset management with import/export functionality (JSON/TXT formats)
- Spatial and time effects including balance, tempo, damp, filter, delay, size, mix, feedback, and width
- Android-optimized audio processing via JustAudioProcessingController
- **Visualizer Customization**: Five animation styles (Bars, Wave, Curved Wave, Mirrored, Dots), five frequency modes, three movement styles, and album-dominant-color preview in visualizer settings

### Library Management
- MediaStore-based scanning with differential database sync (~34x faster than filesystem walk)
- Background metadata extraction and MediaStore change observer for live updates
- Metadata extraction (ID3 tags, Vorbis comments) using `lofty` with dedicated DSD parsers (`dsf-meta`, `dff-meta`) for DSF, DFF, and WavPack DSD files
- Fast library queries via Isar database
- Browse by songs, albums, artists, folders, playlists, favorites, and recently played
- **Album Art Import**: Search and import album art from MusicBrainz/Cover Art Archive, iTunes, and Deezer
- **Delete Songs**: Remove songs from library or delete files entirely
- **Content URI Support**: Android SAF content URIs are staged to local cache for playback (supports ALAC/AIFF/M4A via WAV conversion)
- **Rip Log Metadata**: EAC-style rip log metadata (ripper, read mode, AccurateRip, CRCs) stored per track
- **CUE Sheet Support**: Track offset support for CUE sheet-based files
- **Duplicate Cleaner**: Built-in duplicate detection and cleanup
- **Folder Grid View**: Paginated grid of folder cards with infinite scroll when browsing by folder
- **Swipe Actions**: Swipe left to queue, right to favorite on song cards (toggleable)
- **Multi-Select**: Long-press to enter batch selection with queue/favorite bulk actions
- **Metadata Editor**: Full tag editing (title, artist, album, year, genre, track number) via Rust backend with SAF file writing
- **Album & Folder Sorting**: Sort albums and folders by title, artist, duration, track count with persistent preferences
- **Artist Detail Redesign**: Riverpod-based screen with dynamic color theming from album art, full-bleed artist image background, tinted app bar, and cached artist metadata via `ArtistEntity` Isar collection
- **Playlist Detail Redesign**: Dynamic color theming extracted from most-played song's album art, info chips (track count, total duration, dates), "Other Playlists" section, and playlist metadata helpers

### Playback Features
- Shuffle and repeat modes (off, one, all)
- Playback speed control (0.5x - 2.0x)
- Sleep timer
- Waveform seek bar for precise navigation
- **Audio Visualizer**: Real-time FFT-based visualizer with customizable animation styles, frequency focus, and movement modes (real mode via Android Visualizer API + simulated fallback)
- **Queue Management**: Now Playing / Up Next / Manual queue with multi-select, batch remove, drag to reorder, and swipe to dismiss
- **Online Lyrics**: Search for synced (LRC) or plain-text lyrics from LRCLib.net
- **Lyrics Sync Studio**: Built-in timestamp editor with Simple and Advanced modes, time-shift tools, and file import
- **Immersive Full View**: Auto-hiding controls for full-bleed album art with customizable layout
- **Vinyl Disc Morph**: Tap album art to morph into a spinning vinyl record with animated transition and radial-gradient disc rendering
- **Star Ratings**: 1–5 star ratings on songs with animated overlay and persistent storage
- **Song Sharing**: Share songs as album art, lyric, minimal, or solid color cards — save to gallery or share via apps
- **Custom Player Action Buttons**: Configure left and right action button slots (rating, share, lyrics, shuffle, etc.)
- **Milestone Tracking**: Achievement milestones for songs played (100/500/1000) and listening time (10/50 hours) with redesigned celebration cards (per-tier accent color, hero icon, "next milestone" hint) and an in-app collection view (Settings → Milestones) for re-viewing past achievements like a trophy case

### Home Screen Widget
- **Mini Player Widget**: Native Android widget with album art, progress bar, and transport controls
- **Flagship Widget**: Larger card and split-layout widgets with theme support and customizable appearance
- Works even when the app is killed
- Customizable background opacity, accent color, and visible content via Settings > Widgets
- Tabbed widget settings for managing multiple widget types

### Flick Replay (Listening Recap)
- Daily, weekly, monthly, and yearly listening recaps
- Hero recap cards with total plays, top song, listen time, active days, peak hour
- Ranked top songs and top artists posters
- Custom poster backgrounds: default gradient with glowing orbs, blurred album art, or user's camera photos
- Save recap images to gallery as PNG

### Ecosystem Integration
- **Moss Ecosystem**: Part of the Moss app ecosystem
- **Latch Integration**: Flick can receive playback handoffs from Latch (another Moss app)
- **Cross-app Playback**: Songs can be played from external sources via the Latch integration
- **Shared Infrastructure**: Last.fm scrobbling, adaptive theming, and library scanning are shared across Moss apps

### User Interface
- Adaptive theme based on album artwork colors
- Glassmorphism design elements
- Mini player and full player screens
- Audio visualizer toggle in full player (replaces album art)
- Support for high refresh rate displays (90Hz/120Hz)
- Responsive layout for various screen sizes
- **Immersive Full View**: Auto-hide controls with full-bleed album art
- **Player Layout Customization**: Artwork card scale, text size, text placement, metadata visibility
- **Dynamic Nav Bar**: Reorderable bottom navigation with show/hide per button
- **Fast Index**: Collapsible alphabetical scroll overlay for long lists
- **Swipe Actions**: Swipe to queue or favorite on song cards

### In-App Updates
- **Play Store Integration**: In-app updates via Google Play InAppUpdate API
- **Automatic Checks**: Scans for Play Store updates when online
- **Manual Updates**: Settings UI allows scanning for and installing updates
- **Flexible Updates**: Download updates in the background while using the app
- **Patch Notes**: Release notes fetched from GitHub Releases API

### Support & Donations
- **Support Flick Screen**: In-app donation screen explaining where contributions go (Play Store fees, audio testing equipment, DSD development)
- **Ko-fi Integration**: Donate via Ko-fi directly from the app
- **Pulsing Heart Icon**: Heart button in settings header linking to the support screen

## Moss Ecosystem

Flick Player is part of the **Moss ecosystem**, a suite of interconnected apps that share infrastructure and capabilities.

### Apps in the Ecosystem
- **Flick Player**: High-performance audiophile music player with UAC 2.0 support
- **Latch**: [Part of the Moss ecosystem](https://github.com/moss-apps/Latch)

### Cross-App Integration
Flick integrates with other Moss apps through platform channels:
- **Playback Handoff**: Flick can receive songs from Latch via `ExternalPlaybackService`
- **Shared Audio Infrastructure**: Audio processing, EQ settings, and library scanning are designed to work consistently across the ecosystem
- **Last.fm Integration**: Scrobbling works seamlessly regardless of which app initiated the playback

### Using Flick with Latch
When a song is playing in Latch and you want to switch to Flick's advanced audio engine (for EQ, effects, or UAC 2.0 DAC output):
1. The playback intent is automatically routed to Flick
2. Flick handles metadata extraction and playback
3. Last.fm scrobbling continues uninterrupted

## Future Features

- **DSD scanning**: DSF, DFF, and WavPack DSD (.wv) metadata scanning and artwork extraction (complete)
- **DSD/DSF/DFF/WavPack playback**: engine-level native DSD decoding and playback with Native, DoP, and PCM decimation output modes (experimental)
- **DSD bit order normalization**: Per-source LSB/MSB detection with global override (complete)
- **Native DSD USB direct**: Quirk-based isochronous DSD bitstream delivery to external DACs (complete)
- MQA support
- Poweramp-style EQ filters, including low-pass
- Android audio settings
- Themes and broader UI customization options
- ~~Album art improvements~~
- ~~Lyric clickability and sync~~
- ~~Scrobble settings~~
- ~~Resampler enhancements~~
- Advanced audio tweaks
- ~~Visualizations~~
- ~~Bluetooth audio settings~~
- Internal Hi-Res audio settings
- USB audio tweaks
- Further performance optimizations
- ~~Home screen widget~~
- ~~Online lyrics search~~
- ~~Lyrics editor~~
- ~~Queue management overhaul~~
- ~~Immersive full view~~

## Technology Stack

### Frontend (Flutter)
| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `just_audio` | Audio playback (Android) |
| `isar_community` | Local database |
| `flutter_rust_bridge` | Rust/Flutter FFI |
| `rive` | Complex animations |
| `fl_chart` | Equalizer visualization |
| `flutter_cache_manager` | Image caching |
| `freezed` | Immutable data classes |
| `in_app_update` | Google Play In-App Updates |
| `home_widget` | Android home screen widget |
| `image_picker` | Camera/photo selection |
| `permission_handler` | Runtime permissions |

### Backend (Rust)
| Crate | Purpose |
|-------|---------|
| `symphonia` | Audio decoding (MP3, FLAC, WAV, OGG, M4A/ALAC, AIFF) |
| `rusb` | USB device access (UAC 2.0) |
| `lofty` | Audio metadata parsing (MP3, FLAC, WAV, OGG, M4A/ALAC, AIFF, WavPack) |
| `dsf-meta` | DSF file metadata reading |
| `dff-meta` | DFF/DSDIFF file metadata reading |
| `id3` | ID3 tag access for DSD formats |
| `wavpack-sys` | WavPack DSD decoding (FFI to libwavpack) |
| `cpal` | Cross-platform audio I/O (Oboe/AAudio on Android) |
| `oboe` | Low-latency Android audio (CPAL backend) |
| `rubato` | High-quality sample rate conversion |
| `rayon` | Parallel processing |
| `ringbuf` | Lock-free ring buffer |
| `crossbeam-channel` | Multi-threaded message passing |
| `tracing` | Logging and diagnostics |

## Project Structure

```
flick_player/
├── lib/                          # Flutter/Dart source
│   ├── main.dart                 # Application entry point
│   ├── app/                      # Main app shell widget
│   ├── core/                     # Constants, themes, utilities
│   ├── data/                     # Database and repositories
│   ├── features/                 # Feature modules
│   │   ├── albums/               # Albums browsing
│   │   ├── artists/              # Artists browsing
│   │   ├── favorites/            # Favorites management
│   │   ├── folders/              # Folder browser
│   │   ├── player/               # Player screens and widgets
│   │   │   ├── screens/
│   │   │   │   └── full_player_screen.dart    # Full player with visualizer toggle
│   │   │   └── widgets/
│   │   │       ├── audio_visualizer.dart      # FFT-based 48-bar visualizer
│   │   │       ├── waveform_seek_bar.dart     # Waveform seek bar
│   │   │       └── ...
│   │   ├── playlists/            # Playlist management
│   │   ├── recently_played/      # Recently played tracks
│   │   ├── recap/                # Flick Replay (listening recaps)
│   │   │   └── screens/
│   │   │       └── listening_recap_screen.dart  # Recap with poster generation
│   │   ├── settings/             # Settings and equalizer
│   │   │   ├── equalizer_screen.dart     # Equalizer UI with preset management
│   │   │   └── ...                       # Other settings screens
│   │   └── songs/                # Song library
│   │       └── widgets/
│   │           └── song_actions_bottom_sheet.dart  # Song actions with delete
│   ├── models/                   # Data models
│   ├── providers/                # Riverpod providers
│   ├── services/                 # Business logic services
│   │   ├── album_art_import_service.dart     # Online album art (MusicBrainz/iTunes/Deezer)
│   │   ├── eq_preset_service.dart            # EQ preset management
│   │   ├── eq_preset_file_service.dart       # EQ preset import/export (JSON/TXT)
│   │   ├── equalizer_service.dart            # EQ and FX application
│   │   ├── android_audio_processing_service.dart # Android audio processing
│   │   ├── player_service.dart               # Playback control
│   │   ├── uac2_service.dart                 # USB audio device management
│   │   ├── visualizer_service.dart           # Android Visualizer FFT bridge
│   │   ├── lyrics_service.dart               # Lyrics loading, parsing, editing
│   │   ├── online_lyrics_service.dart        # LRCLib.net lyrics search
│   │   ├── widget_sync_service.dart          # Home screen widget state sync
│   │   └── widget_intent_handler.dart        # Widget action dispatch
│   └── widgets/                 # Reusable widgets (including deprecated UAC2 widgets)
├── rust/                         # Rust backend
│   └── src/
│       ├── api/                  # FFI API bindings
│       ├── audio/                # Audio engine
│       │   ├── engine.rs         # Core audio engine
│       │   ├── decoder.rs        # PCM decoder (Symphonia)
│       │   ├── decoder_handle.rs # Decoder dispatch
│       │   ├── dsd_engine/       # DSD decoding (DSF, DFF, WavPack)
│       │   │   ├── dsd_thread.rs
│       │   │   └── format/       # DSF, DFF, WavPack decoders
│       │   ├── resampler.rs      # Sample rate conversion
│       │   ├── equalizer.rs      # 31-band parametric EQ
│       │   ├── fx.rs             # Spatial and time effects
│       │   ├── dynamics.rs       # Compressor/limiter
│       │   ├── crossfader.rs     # Crossfade support
│       │   ├── source.rs         # Gapless playback queue
│       │   └── strategy.rs       # Output strategy selection
│       └── uac2/                 # USB Audio Class 2.0
│           ├── device.rs         # Device representation
│           ├── backend.rs        # USB backend
│           ├── connection_manager.rs
│           ├── capabilities.rs   # Device capability detection
│           ├── format_negotiation.rs
│           ├── descriptors/      # USB descriptor parsing
│           ├── transfer.rs       # Isochronous transfers
│           └── audio_pipeline.rs # Format conversion
├── test/                         # Test files
│   └── services/
│       └── eq_preset_file_service_test.dart # EQ preset file service tests
├── docs/                         # Architecture documentation
├── android/                      # Android platform code
│   ├── app/src/main/kotlin/com/ultraelectronica/flick/
│   │   ├── MainActivity.kt               # Android entry point + content URI staging
│   │   └── audiofx/
│   │       └── JustAudioProcessingController.kt # Android audio effects
│   └── copy_ndk_libs.sh         # NDK libc++_shared.so copier
└── pubspec.yaml                  # Flutter dependencies
```

## Getting Started

### Prerequisites

- Flutter SDK 3.10 or higher
- Rust toolchain (stable)
- Android SDK (minSdk 26 / Android 8.0+)
- USB host support (OTG) for UAC 2.0 support

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd flick_player

# Install Flutter dependencies
flutter pub get

# Ensure Rust dependencies are available
cd rust && cargo fetch && cd ..
```

### Running the Application

```bash
# Run in debug mode
flutter run

# Run on a specific device
flutter run -d <device-id>
```

### Building

```bash
# Build for Android (debug)
flutter build apk --debug

# Build for Android (release)
flutter build apk --release
```

## Platform-Specific Notes

### Android

Flick Player is designed exclusively for Android. The application uses a multi-strategy audio engine:

- **USB Direct**: Bit-perfect playback through external USB DACs via the custom Rust UAC 2.0 isochronous engine.
- **DAP Native**: High-resolution playback through the device's internal DAC via Oboe/AAudio exclusive mode, with device qualification for confirmed bit-perfect DAPs.
- **Mixer Bit-Perfect**: Android mixer path with bit-perfect format matching (Android 14+).
- **Mixer Matched / Resampled Fallback**: Standard Android mixer paths when exact format matching isn't possible.
- **just_audio Fallback**: For standard audio playback on devices without advanced audio support.

UAC 2.0 DAC/AMP detection uses the USB Host API. The pipeline info and transfer stats widgets have been removed as the UAC2 subsystem has been partially deprecated in favor of Android's native audio routing for USB DACs. The core UAC2 engine (device discovery, descriptor parsing, isochronous transfers) remains in the Rust backend.

- **Requirements**: Device must support USB host (OTG). The app declares `android.hardware.usb.host` as optional, so it installs on devices without USB host capability.
- **Permissions**: When a USB Audio Class 2.0 device is attached, the app can list it and request access. The user must grant permission when prompted. Use `Uac2Service.instance.requestPermission(deviceName)` (on Android, `deviceName` is in `Uac2DeviceInfo.serial` when the device has no serial string).
- **Device Filter**: Only USB Audio Class 2.0 devices (class 0x01, subclass 0x02, protocol 0x20) are listed.

## Architecture

Flick Player follows a feature-based architecture with clear separation of concerns:

- **Services Layer**: Business logic for audio playback, library management, and device communication
- **Providers Layer**: Riverpod providers for reactive state management
- **Feature Modules**: Self-contained feature implementations with their own screens, widgets, and logic
- **Rust Backend**: High-performance native code for audio processing and USB device communication

The Rust backend communicates with Flutter via `flutter_rust_bridge`, providing:
- Real-time audio engine control
- Hardware-accelerated audio processing
- Direct USB device access for UAC 2.0 support

## Documentation

Documentation is available in the `docs/` directory:
- `DOCUMENTATION.md`: Detailed architecture and design documentation
- `CHANGELOG.md`: Consolidated changelog across all versions
- `RELEASE_0.17.0-beta.1.md`: Release notes for 0.17.0-beta.1
- `RELEASE_0.16.0-beta.1.md`: Release notes for 0.16.0-beta.1
- `RELEASE_0.15.0-beta.1.md`: Release notes for 0.15.0-beta.1
- `RELEASE_0.14.0-beta.1.md`: Release notes for 0.14.0-beta.1
- `DSD_ARCHITECTURE.md`: DSD/DSF/DFF/WavPack playback architecture and engine design
- `DSD_VOLUME_CONTROL_STATUS.md`: DSD volume control investigation and status
- `DAC_EXTENSIBILITY.md`: DAC/DAP extensibility guide for developers
- `UAC2_IMPLEMENTATION_CHECKLIST.md`: Implementation checklist for the UAC 2.0 subsystem
- `DAP_BIT_PERFECT_OFF_ISSUES.md`: Bit-perfect DAP Internal OFF issues and fixes
- `hardware_volume_control.md`: Three-tier hardware volume control implementation
- `LIBRARY_SCAN_ARCHITECTURE.md`: MediaStore + two-phase + event-driven library scanning architecture
- `scanning_benchmark05092026.md`: Library scanner benchmark results (34x improvement)
- `ANDROID_7_CRASH.md`: Android 7 crash root cause and minSdk 26 fix
- `ANDROID_NDK_SETUP.md`: Android NDK setup for Rust libraries

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Flick Player is purely open-source and free. There are no premium features, ads, or paid components.

## Contributors

- [@Harleythetech](https://github.com/Harleythetech) (The first ever contributor of Flick)
- [@MagosVox](https://github.com/MagosVox) (Special contributor - bit-perfect USB DAC expertise)

## Contributing

Contributions are welcome. Please ensure all changes pass linting and testing before submitting pull requests.
