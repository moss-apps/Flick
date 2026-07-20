# Flick 0.20.4-beta.5

0.20.4-beta.5 ships real-time pitch shifting via SoundTouch, an Android audio API preference (AAudio/OpenSL/Auto), blurred backgrounds across all library screens, customizable orbit settings, album artwork stretch mode, lyrics performance caching, streak controls, artwork reliability fixes, Apple Music-style animated album art with scroll fade, an engine restart overlay, USB DAC disconnect handling, and a redesigned UAC2 settings screen.

## Overview

This beta adds twelve headline features:

1. **Pitch shifter (SoundTouch)** — real-time pitch shifting via SoundTouch DSP, lock-free bypass, semitone API
2. **Android audio API preference** — choose AAudio, OpenSL ES, or Auto for audio output
3. **Blurred backgrounds everywhere** — consistent glass-look backgrounds on all library screens
4. **Orbit customization** — tune the menu screen's orbit geometry, sizing, depth, art resolution
5. **Album artwork stretch** — stretch album art to fill cards
6. **Lyrics performance** — in-memory cache, parallel exact+fuzzy searches
7. **Streaks & preference controls** — disable streaks, toggle album detail sections
8. **Artwork reliability** — only cache confirmed paths, prefer embedded art
9. **Animated album art & scroll fade** — Apple Music-style animated art on detail screens with scroll-aware hero fade
10. **Engine restart overlay** — full-screen animated restart flow replaces snackbar prompts
11. **USB DAC disconnect** — automatic pause on DAC removal with preference toggle
12. **UAC2 settings redesign** — gradient background with ambient album artwork

## Highlights

- **Pitch shifter**: SoundTouch, the industry-standard pitch and tempo library, is integrated into Flick's DSP chain. A lock-free bypass flag makes the pitch shifter zero-cost when set to 1.0×. The semitone API spans the full musically useful range. A pitch control bottom sheet provides a semitone slider, also accessible from the song actions sheet. Pitch resets to 1.0× when playback stops in non-Rust backends.
- **Audio API**: You can now choose between **AAudio** (recommended, Android 8+), **OpenSL ES** (legacy), or **Auto** for Android audio output. The preference is persisted and applied instantly. It's exposed in Settings → Audio → UAC2 and in the Rust debug state JSON. An `AudioApiPreference` enum with FFI getter/setter and Dart bridge makes the preference reactive.
- **Blurred backgrounds**: A shared `BlurredSongBackground` widget now wraps all library screens (songs, recently played, recently added, queue, favorites, playlists, folders, artists, albums) for a consistent glass-morphism look. A fade-only route transition keeps the blurred background stable while screens change.
- **Orbit customization**: A new orbital settings screen lets you tune the menu screen's orbit — geometry parameters, card sizing, visual depth, art resolution, and general visual toggles. All parameters live in `AppPreferences` with setters and a reset option. `SongCard` sizing is now fully configurable. Unused hardcoded orbit constants were removed.
- **Album artwork stretch**: Album artwork can now stretch to fill the entire card instead of being letterboxed. Toggle from Settings → Library → Stretch album artwork. Uses a single-image display with stretch support.
- **Lyrics performance**: An in-memory cache with timeout reduces redundant API calls when searching the same lyrics repeatedly. A shared HTTP client prevents connection pool exhaustion. Exact and fuzzy searches run in parallel and return the first match.
- **Streaks & preferences**: Streaks can be disabled entirely with a reset option that clears all streak data. The day streak milestone is hidden when streaks are disabled. "More from Artist" and "More Artists" sections on album detail screens can be toggled independently. Display preferences were added to the artist sort sheet.
- **Artwork**: Only confirmed-existing artwork paths are cached, preventing phantom thumbnails from appearing when storage is unmounted. The artwork source path now prefers songs with embedded album art for fallback. The path picker matches the song that has artwork matching the album art.
- **Animated album art**: Album, artist, and playlist detail screens now feature Apple Music-style animated album artwork. A `ScrollFadeWrapper` fades the hero artwork behind the pinned app bar as you scroll down. The album art layer was extracted into an `AnimatedAlbumArt` variant with scroll-aware fade. Toggle the animation from Settings → Interface → UI Customization. Tests cover both the `ScrollFadeWrapper` and `AnimatedAlbumArt` widgets.
- **Engine restart**: A full-screen restart overlay with animated gradient progress replaces the old snackbar and toast prompts. An inline `EngineRestartNotice` widget appears when UAC2 settings require an engine restart. The restart and update notices share a consistent restyled widget.
- **USB DAC disconnect**: When a USB DAC is unplugged, playback now pauses automatically. A `DeviceDetachedEvent` stream notifies the UI of DAC removal events. Pause-on-disconnect can be toggled from Settings → Audio → Bluetooth.
- **UAC2 redesign**: The UAC2 settings screen got a gradient background with ambient album artwork. The UAC2 preferences screen background was refreshed with the same gradient styling.

## What's New

### Pitch Shifter (SoundTouch)

- SoundTouch library integrated into DSP chain
- Lock-free bypass flag (zero-cost at 1.0×)
- Semitones API with FFI bridge and notifier
- Pitch control bottom sheet with slider
- Song actions sheet integration
- Auto-reset to 1.0× on stop

### Android Audio API Preference

- AAudio / OpenSL ES / Auto selection
- Persisted with instant apply
- UAC2 settings and debug state exposure
- `AudioApiPreference` enum, FFI, Dart bridge

### Blurred Backgrounds Everywhere

- `BlurredSongBackground` on all library screens
- Fade-only route transition for stable backgrounds

### Orbit Customization

- Orbital settings screen (geometry, sizing, depth, art, visuals)
- Configurable `SongCard` sizing
- All parameters in `AppPreferences` with reset
- Unused constants removed

### Album Artwork Stretch

- Stretch mode toggle in Library settings
- Single-image display with stretch support

### Lyrics Performance

- In-memory cache with timeout
- Shared HTTP client
- Parallel exact + fuzzy searches

### Streaks & Preference Controls

- Disable streaks with reset
- Hide day streak when disabled
- Independent album detail section toggles
- Artist sort sheet display preferences

### Artwork Reliability

- Cache only confirmed-existing paths
- Prefer embedded art for fallback
- Match artwork source path to album art

### UI Polish & Fixes

- Glass bottom sheet engine selector with hero gradients
- Responsive songs header with Flexible labels
- Edge-drag navigation guard
- Sort sheet margin fix
- Docs: scan plan, scan revamp, feature requests

### Animated Album Art & Scroll Fade

- Apple Music-style animated album art on album, artist, and playlist detail screens
- `ScrollFadeWrapper` fades hero artwork behind the pinned app bar
- `AnimatedAlbumArt` variant with scroll-aware fade
- Toggle in Settings → Interface → UI Customization
- Tests for `ScrollFadeWrapper` and `AnimatedAlbumArt`

### Engine Restart Overlay

- Full-screen restart overlay with animated gradient progress
- Inline `EngineRestartNotice` replaces snackbar/toast prompts
- Shared restart notice restyled with the update notice

### USB DAC Disconnect & UAC2 Redesign

- Automatic pause on USB DAC unplug
- `DeviceDetachedEvent` stream for UI notifications
- Pause-on-disconnect toggle in Settings → Audio → Bluetooth
- UAC2 settings screen with gradient background and ambient artwork
- UAC2 preferences screen gradient refresh

## Files Changed

| Area | Key Paths |
| --- | --- |
| Pitch Shifter | `rust/vendor/soundtouch-sys/`, `rust/src/audio/pitch_shifter.rs`, `lib/features/player/widgets/pitch_control_sheet.dart` |
| Audio API | `rust/src/audio/android_output.rs`, `rust/src/api/audio_api_preference.rs`, `lib/features/settings/screens/uac2_preferences_screen.dart` |
| Blurred BG | `lib/widgets/common/blurred_song_background.dart`, `lib/features/**/screens/*.dart` |
| Orbit | `lib/features/settings/screens/orbit_settings_screen.dart`, `lib/widgets/orbit_view.dart`, `lib/widgets/song_card.dart` |
| Albums | `lib/features/albums/screens/albums_screen.dart`, `lib/features/albums/widgets/album_card.dart` |
| Lyrics | `lib/services/lyrics_service.dart`, `lib/services/online_lyrics_service.dart` |
| Streaks | `lib/features/milestones/`, `lib/features/settings/screens/interface_screen.dart` |
| Artwork | `lib/services/artwork_cache_service.dart`, `lib/services/artwork_extraction_service.dart` |
| Engine Selector | `lib/features/home/widgets/engine_selector.dart` |
| Animated Art | `lib/widgets/common/animated_album_art.dart`, `lib/widgets/common/scroll_fade_wrapper.dart`, `lib/features/**/detail_screen.dart` |
| Restart Flow | `lib/features/menu/screens/restarting_screen.dart`, `lib/widgets/common/engine_restart_notice.dart` |
| USB DAC | `lib/services/uac2_service.dart`, `lib/services/player_service.dart`, `lib/features/settings/screens/bluetooth_settings_screen.dart` |
| UAC2 Settings | `lib/features/settings/screens/uac2_settings_screen.dart`, `lib/features/settings/screens/uac2_preferences_screen.dart` |

## Upgrading

1. Pitch shifter: tap the pitch badge on the player or open the three-dot song actions → Pitch
2. Audio API: Settings → Audio → UAC2 → Android Audio API
3. Orbit customization: Settings → Interface → Orbit
4. Album artwork stretch: Settings → Library → Stretch album artwork
5. Streak settings: Settings → Interface → Streaks
6. Blurred backgrounds are automatic on all library screens — no configuration needed
7. Animated album art: toggle from Settings → Interface → UI Customization → Animated Album Art
8. Engine restart appears automatically when UAC2 settings change — no action needed
9. USB DAC disconnect pausing: toggle from Settings → Audio → Bluetooth → Pause on DAC disconnect
