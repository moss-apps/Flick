# Flick 0.20.5-beta.6

0.20.5-beta.6 ships audio preload with BS.1770 loudness analysis and waveform caching, DSD ALSA direct output bypassing AudioFlinger, configurable detail screen art and title preferences, redesigned playlist/artist/album detail screens, nav bar button customization, widget text scaling, pause-on-connect for USB DAC and Bluetooth, artwork extraction gate improvements, and UI polish throughout.

## Overview

This beta adds nine headline features:

1. **Audio preload & analysis** — BS.1770 loudness metrics and waveform peaks cached during library scan
2. **DSD ALSA direct output** — ALSA direct output bypassing AudioFlinger on DAPs
3. **Detail screen art & title preferences** — expanded header art, centered title, configurable gradient stops
4. **Detail screen redesigns** — redesigned playlist, artist, and album detail screens with lossless indicator
5. **Nav bar button customization** — hide/show individual bottom nav buttons
6. **Widget text scaling** — configurable font scale for mini, flagship, and compact widgets
7. **Pause on connect** — auto-pause on USB DAC attach and Bluetooth connect
8. **Artwork extraction gate** — refcounted pause, 30-day LRU cache, scroll gate mixin
9. **UI polish** — speed/sleep sliders, back gesture improvements, manual screen ambient background

## Highlights

- **Audio preload & analysis**: A single-pass audio analysis run during library scan extracts BS.1770 loudness metrics (integrated, short-term, momentary) and waveform peak data per song. Results are cached in `SongAudioCacheEntity` (Isar) and served by the audio preload service for instant waveform rendering. FFI bindings expose `analyze_audio_file` and `AudioAnalysisResult`. A preload toggle in Library scan preferences shows progress during the scan.
- **DSD ALSA direct output**: On DAP devices, DSD playback now bypasses Android's AudioFlinger entirely through ALSA direct output. JNI runtime probes detect DAP ALSA capabilities. The transport label reads `dsd-native-alsa` with detailed debug logging. A PCM payload audit and global stop signal handle USB clear on mode changes. The engine prevents reuse across DSD mode changes and forces DsdDoP when the effective output mode requires it.
- **Detail screen preferences**: Album, playlist, and artist detail screens gain configurable header art expansion and title centering. Expanded art uses larger header heights and configurable gradient stops. Centered title alignment is toggleable. All options live under Settings → Interface → UI Customization.
- **Detail screen redesigns**: The playlist detail screen was redesigned with compact action buttons and a lossless indicator. The artist detail screen has a fresh layout with improved visual hierarchy. The album detail screen was refactored for better artwork extraction. Scroll-induced translation was removed from album art, and an artwork extraction scroll gate was added for performance.
- **Nav bar customization**: Individual bottom nav bar buttons can now be hidden or shown from Settings → Interface → Bottom Bar. A `NavBarConfig` holds the hidden buttons set, persisted via SharedPreferences.
- **Widget text scaling**: Mini, flagship, and compact widgets now support configurable font scaling. Text scale preferences are persisted per widget type. The compact widget text scales responsively with widget width.
- **Pause on connect**: Playback pauses automatically when a USB DAC is attached or a Bluetooth device connects. A device attached event stream notifies the UI. Each behavior has an independent toggle in Bluetooth settings.
- **Artwork extraction**: Artwork extraction pauses during audio preload and scroll for consistent performance. A refcounted pause with scroll gate mixin and dedicated artwork gate service replaces the previous inline logic. Artwork cache staleness was reduced to 30 days with a 500-entry LRU eviction cap.

## What's New

### Audio Preload & Analysis

- Single-pass BS.1770 loudness and waveform peak analysis
- `SongAudioCacheEntity` Isar collection for cached metrics
- Audio preload service with background execution
- FFI bindings for `analyze_audio_file` and `AudioAnalysisResult`
- Preload toggle in Library scan preferences

### DSD ALSA Direct Output

- ALSA direct output bypassing AudioFlinger
- JNI runtime DSD probes for DAP detection
- `dsd-native-alsa` transport with open/fail logging
- PCM payload audit and global stop signal
- Engine reuse prevention across DSD mode changes
- Forced DsdDoP strategy on mode switch

### Detail Screen Art & Title Preferences

- Expanded/normal header art toggle
- Centered/default title alignment toggle
- Configurable header art heights and gradient stops

### Detail Screen Redesigns

- Playlist detail: redesigned buttons, lossless indicator
- Artist detail: new layout and action styling
- Album detail: refactored artwork extraction
- Scroll translation removed; scroll gate added

### Nav Bar Button Customization

- Hide/show individual bottom nav buttons
- `NavBarConfig` with persisted hidden buttons

### Widget Text Scaling

- Font scale per widget type (mini, flagship, compact)
- Compact widget responsive text scaling by width

### Pause on Connect

- USB DAC attach auto-pause
- Bluetooth connect auto-pause
- Per-toggle preferences in Bluetooth settings

### Artwork Extraction Gate & Cache

- Refcounted pause during preload/scroll
- Dedicated artwork gate service
- 30-day staleness, 500-entry LRU cache cap

### UI Polish & Fixes

- Speed and sleep timer sliders replace button presets
- Wider back gesture edge with improved drag
- Chevron icon in milestone back button
- Manual screen: ConsumerStatefulWidget with ambient background
- Folder grid aspect ratio 0.70
- AlbumFilterSheet sort state initialized
- Impeller config in API 31 resource folder
- MediaStore priority for removable deep scans
- Text styles/icon sizes updated
- Docs: network sources plan, CONTRIBUTING.md

## Files Changed

| Area | Key Paths |
| --- | --- |
| Audio Preload | `rust/src/audio/audio_analysis.rs`, `lib/services/audio_preload_service.dart`, `lib/data/entities/song_audio_cache_entity.dart` |
| DSD ALSA | `rust/src/audio/dsd_engine/alsa_direct.rs`, `rust/src/audio/dsd_engine/dsd_output_router.rs` |
| Detail Preferences | `lib/features/settings/screens/ui_customization_settings_screen.dart`, `lib/providers/app_preferences_provider.dart` |
| Playlist Detail | `lib/features/playlists/screens/playlist_detail_screen.dart` |
| Artist Detail | `lib/features/artists/screens/artist_detail_screen.dart` |
| Album Detail | `lib/features/albums/screens/album_detail_screen.dart` |
| Nav Bar | `lib/providers/nav_bar_config.dart`, `lib/features/settings/screens/bottom_bar_settings_screen.dart` |
| Widget Text | `android/.../widget/`, `lib/services/widget_prefs.dart` |
| Pause on Connect | `lib/services/uac2_service.dart`, `lib/services/player_service.dart`, `lib/features/settings/screens/bluetooth_settings_screen.dart` |
| Artwork | `lib/services/artwork_extraction_service.dart`, `lib/services/artwork_gate_service.dart`, `lib/services/artwork_cache_service.dart` |
| UI Polish | `lib/features/settings/equalizer_screen.dart`, `lib/widgets/common/back_gesture_detector.dart`, `lib/features/milestones/` |

## Upgrading

1. Audio preload: enable from Settings → Library → Scan Preferences → Preload audio data (enabled by default on next scan)
2. DSD ALSA direct output applies automatically on DAP devices — no configuration needed
3. Detail screen art/title preferences: Settings → Interface → UI Customization
4. Nav bar buttons: Settings → Interface → Bottom Bar → toggle individual buttons
5. Widget text scaling: Settings → Widgets → per-widget type text scale
6. Pause on connect: Settings → Audio → Bluetooth → toggle USB DAC attach and Bluetooth connect
7. Speed and sleep timer controls are now sliders — drag to set the exact value
