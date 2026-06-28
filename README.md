# Flick
---
<p align="center">
  <img src="docs/app_screenshots/flick_banner.png" alt="Flick Banner" width="100%">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.mossapps.flick">
    <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="80">
  </a>
</p>

---
Flick is an Android music player built with Flutter and Rust. The Rust engine handles bit-perfect PCM, native DSD, and DoP output to USB DACs and the DAP internal audio path, with a DSP chain (EQ, convolution reverb, crossfade).

> **GitHub Releases**: builds at [GitHub Releases](https://github.com/anomalyco/opencode/releases) or the [Google Play Store](https://play.google.com/store/apps/details?id=com.mossapps.flick).

## Key Features

### Audio Engine
- Rust audio engine; UAC 2.0 USB DAC support for bit-perfect PCM and native DSD
- DSD bit order per source format (LSB/MSB); per-DAC quirk overrides (byte order, bit reverse, subslot size) from a unified quirk DB
- I32 integer AAudio streams for DoP/DSD on DAP internal paths — raw bit patterns, no format conversion
- DAP bit-perfect via Oboe/AAudio exclusive mode on qualified devices (FiiO, iBasso, HiBy, Shanling, Astell&Kern, Cayin, Sony Walkman)
- `just_audio` fallback where USB audio is unsupported
- 31-band parametric EQ (20 Hz–20 kHz, 1/3-octave) with preamp; preset import/export (JSON/TXT)
- Dynamics (compressor/limiter), spatial/time FX, playback speed (0.5×–2.0×)
- Convolution reverb from impulse-response WAV files (`convolver_enable`/`convolver_mix`/`convolver_load_ir`/`convolver_clear`)
- Crossfade between tracks with selectable `CrossfadeCurve`; pending config held in atomics, survives engine recreation
- Gapless playback
- Bluetooth: A2DP codec info + battery level, low-latency mode (Rust Oboe), pause-on-disconnect, reconnect resume, Android 12+ connect permission
- DSD playback (experimental): Native, DoP, PCM decimation for DSF/DFF/WavPack DSD
- Manual engine selector with auto-detection

### USB Audio Class 2.0 (UAC 2.0)
- Rust implementation for USB DAC/AMP detection and enumeration
- Android-side detection with keyword matching and AudioManager fallback
- Audio Control and Audio Streaming interface descriptor parsing
- Isochronous transfer engine for direct USB access; standard playback routes through Android's native USB DAC handling
- Hot-plug detection with toast notifications
- Bit-perfect PCM and native DSD bitstream delivery to external USB DACs
- USB volume popup (slider + mute) for isochronous USB engines
- Scoring-based output strategy selection
- DAP signature registry for device detection (brand/model)
- Unified quirk DB: per-device DSD transport overrides (byte order, bit order, byte reverse, subslot size) synced to the Rust engine before playback (e.g. MOONDROP Dawn Pro). 24-bit USB DoP uses corrected bits-per-frame; UAC2 alt-settings probed for DSD/DoP capability before stream start
- UAC2 feature and multi-byte DSD slots active by default

### Equalizer & Audio Effects
- 31-band parametric EQ with preamp
- Dynamics (compressor/limiter), spatial and time FX (balance, tempo, damp, filter, delay, size, mix, feedback, width)
- Preset import/export (JSON/TXT)
- Convolution reverb (IR WAV files) with dry/wet mix, on the equalizer screen
- Android processing via `JustAudioProcessingController`
- Visualizer: five animation styles (Bars, Wave, Curved Wave, Mirrored, Dots), five frequency modes, three movement styles, album-dominant-color preview

### Library Management
- MediaStore-based scanning with differential DB sync (~34× faster than filesystem walk)
- Removable storage (SD/USB) scanning via Android SAF with per-volume MediaStore support; `FolderEntity` carries `isRemovable`, `mediaStoreVolume`, `volumeState`; unmount events fall back to instant SAF scan
- Background metadata extraction; `MediaStoreObserverService` for live updates
- Metadata via `lofty` (ID3, Vorbis comments) with DSD parsers (`dsf-meta`, `dff-meta`) for DSF/DFF/WavPack DSD
- Isar database for library queries
- Browse by songs, albums, artists, folders, playlists, favorites, recently played
- Album list view with multi-select and queue-all
- Album art import from MusicBrainz/Cover Art Archive, iTunes, Deezer
- Delete songs from library or delete files
- Android SAF content URIs staged to cache for playback (ALAC/AIFF/M4A via WAV conversion)
- EAC-style rip log metadata (ripper, read mode, AccurateRip, CRCs) per track
- CUE sheet track offset support
- Duplicate detection and cleanup
- Folder grid view with pagination
- Swipe actions on song cards (queue / favorite; toggleable)
- Multi-select (long-press) with batch queue/favorite
- Metadata editor (title, artist, album, year, genre, track) via Rust with SAF writes; verified writes, pre-save validation, temp-file rollback, persisted write URI permission
- Album/folder sorting (title, artist, duration, track count) with persistent prefs
- Artist detail: Riverpod, dynamic color theming from album art, full-bleed image, cached `ArtistEntity`
- Playlist detail: color theming from most-played song's art, info chips, "Other Playlists" section

### Playback
- Shuffle and repeat (off / one / all)
- Playback speed (0.5×–2.0×)
- Sleep timer
- Waveform seek bar
- Audio visualizer: FFT-based, real mode via Android Visualizer API + simulated fallback
- Queue management: Now Playing / Up Next / Manual, multi-select, batch remove, drag reorder, swipe dismiss
- Online lyrics search (synced LRC or plain text) via LRCLib.net
- Lyrics Sync Studio: timestamp editor, Simple and Advanced modes, time-shift, file import
- Immersive full view: auto-hiding controls, full-bleed album art
- Vinyl disc morph: tap album art to spin a radial-gradient vinyl
- Star ratings (1–5) with animated overlay
- Song sharing as album art / lyric / minimal / solid color cards
- Custom player action buttons (left/right slots: rating, share, lyrics, shuffle, etc.)
- Milestone tracking: songs played (100/500/1000), listen time (10/50h), per-tier accents, collection view (Settings → Milestones)
- Day streaks with flame popup + snooze; unique-artist milestone; emerald tier; category-grouped milestones

### Home Screen Widget
- Mini player widget: album art, progress bar, transport controls; scrim overlay tracks album art presence
- Compact 2×2 widget (`CompactWidgetProvider`) with its own preferences tab
- Flagship widget: larger card and split-layout with theme support
- Works when the app is killed
- Customizable background opacity, accent, content visibility (Settings → Widgets)
- Tabbed widget settings with swipe + animated transitions

### Flick Replay (Listening Recap)
- Daily, weekly, monthly, yearly recaps
- Hero cards: total plays, top song, listen time, active days, peak hour
- Ranked top songs and top artists posters
- Poster backgrounds: default gradient, blurred album art, camera photos
- Save recaps to gallery as PNG

### Ecosystem Integration
- Part of the Moss app ecosystem
- Latch integration: receives playback handoffs from Latch
- Cross-app playback from external sources via Latch
- Shared infrastructure: Last.fm scrobbling, adaptive theming, library scanning across Moss apps

### User Interface
- Adaptive theme from album artwork colors
- Glassmorphism elements
- Mini player and full player screens
- Visualizer toggle in full player (replaces album art)
- High refresh rate support (90 Hz/120 Hz)
- Responsive layout
- Immersive full view
- Player layout customization (artwork scale, text size/placement, metadata visibility)
- Reorderable bottom nav (show/hide per button)
- Fast index: collapsible alphabetical scroll overlay

### In-App Updates
- Google Play InAppUpdate API
- Automatic update checks when online
- Manual scan/install from settings
- Flexible (background) updates
- Patch notes from GitHub Releases API

### Support & Donations
- In-app donation screen (Play Store fees, audio testing gear, DSD development)
- Ko-fi donations
- Heart button in settings header

## Moss Ecosystem

Flick is part of the **Moss ecosystem** — a suite of interconnected apps sharing infrastructure.

### Apps
- **Flick**: audiophile music player with UAC 2.0 support
- **Latch**: [moss-apps/Latch](https://github.com/moss-apps/Latch)

### Cross-App Integration
Flick integrates with other Moss apps via platform channels:
- **Playback handoff**: receives songs from Latch via `ExternalPlaybackService`
- **Shared audio infrastructure**: audio processing, EQ, library scanning are shared across Moss apps
- **Last.fm**: scrobbling continues regardless of which app initiated playback

### Using Flick with Latch
To switch a song playing in Latch to Flick's audio engine (EQ, effects, UAC 2.0 DAC):
1. The playback intent routes to Flick
2. Flick handles metadata extraction and playback
3. Last.fm scrobbling continues

## Roadmap

- MQA support
- Poweramp-style EQ filters (incl. low-pass)
- Android audio settings
- Internal hi-res audio settings
- USB audio tweaks
- Themes and broader UI customization
- Further performance optimizations

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
|-------|--------|
| `symphonia` | Audio decoding (MP3, FLAC, WAV, OGG, M4A/ALAC, AIFF) |
| `rusb` | USB device access (UAC 2.0) |
| `lofty` | Audio metadata parsing (MP3, FLAC, WAV, OGG, M4A/ALAC, AIFF, WavPack) |
| `dsf-meta` | DSF file metadata reading |
| `dff-meta` | DFF/DSDIFF file metadata reading |
| `id3` | ID3 tag access for DSD formats |
| `wavpack-sys` | WavPack DSD decoding (FFI to libwavpack) |
| `cpal` | Cross-platform audio I/O (Oboe/AAudio on Android) |
| `oboe` | Low-latency Android audio (CPAL backend) |
| `rubato` | Sample rate conversion |
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
│   │   ├── bluetooth_service.dart            # Bluetooth device/codec management
│   │   └── widget_intent_handler.dart        # Widget action dispatch
│   └── widgets/                 # Reusable widgets
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
│       │   ├── convolver/        # Direct-time-domain IR convolution reverb
│       │   ├── dynamics.rs       # Compressor/limiter
│       │   ├── crossfader.rs     # Crossfade engine (CrossfadeCurve)
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
- Flutter SDK 3.10+
- Rust toolchain (stable)
- Android SDK (minSdk 26 / Android 8.0+)
- USB host (OTG) for UAC 2.0

### Installation
```bash
git clone <repository-url>
cd flick_player
flutter pub get
cd rust && cargo fetch && cd ..
```

### Running
```bash
flutter run                    # debug mode
flutter run -d <device-id>     # specific device
```

### Building
```bash
flutter build apk --debug
flutter build apk --release
```

## Platform-Specific Notes

### Android
Flick is Android-only. The audio engine selects one of:

- **USB Direct**: bit-perfect via the Rust UAC 2.0 isochronous engine through external USB DACs
- **DAP Native**: hi-res through the internal DAC via Oboe/AAudio exclusive mode on qualified DAPs
- **Mixer Bit-Perfect**: Android mixer with bit-perfect format matching (Android 14+)
- **Mixer Matched / Resampled Fallback**: standard mixer paths when exact format matching isn't possible
- **just_audio fallback**: standard playback where advanced audio is unsupported

UAC 2.0 DAC/AMP detection uses the USB Host API. The pipeline-info and transfer-stats widgets were removed when UAC2 routing shifted to Android's native USB DAC handling. The core UAC2 engine (discovery, descriptor parsing, isochronous transfers) remains in the Rust backend.

- **Requirements**: USB host (OTG). `android.hardware.usb.host` is declared optional, so the app installs on devices without it.
- **Permissions**: on UAC 2.0 attach, the app lists the device and requests access. Grant when prompted. `Uac2Service.instance.requestPermission(deviceName)` — on Android, `deviceName` is in `Uac2DeviceInfo.serial` when the device has no serial string.
- **Device filter**: only UAC 2.0 devices (class 0x01, subclass 0x02, protocol 0x20) are listed.

## Architecture

Feature-based with separation of concerns:

- **Services**: audio playback, library, device communication
- **Providers**: Riverpod reactive state
- **Feature modules**: self-contained screens, widgets, logic
- **Rust backend**: audio processing and USB via `flutter_rust_bridge`

The Rust backend exposes real-time engine control, audio DSP, and direct USB device access for UAC 2.0.

## Documentation

Architecture and design notes live in [`docs/`](docs/). Release history is in [`CHANGELOG.md`](CHANGELOG.md). Key references:

- [`docs/DSD_ARCHITECTURE.md`](docs/DSD_ARCHITECTURE.md) — DSD/DSF/DFF/WavPack engine
- [`docs/LIBRARY_SCAN_ARCHITECTURE.md`](docs/LIBRARY_SCAN_ARCHITECTURE.md) — MediaStore + SAF scanner
- [`docs/uac2/`](docs/uac2/) — USB Audio Class 2.0 subsystem
- [`docs/hardware_volume_control.md`](docs/hardware_volume_control.md) — three-tier volume control

## License

MIT — see [LICENSE](LICENSE).

Open-source and free. No premium features, ads, or paid components.

## Contributors

- [@Harleythetech](https://github.com/Harleythetech)
- [@MagosVox](https://github.com/MagosVox) — bit-perfect USB DAC expertise

## Contributing

Contributions welcome. Ensure changes pass linting and testing before opening pull requests.
