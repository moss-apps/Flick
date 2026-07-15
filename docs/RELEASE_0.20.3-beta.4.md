# Flick 0.20.3-beta.4

0.20.3-beta.4 refactors the full player screen into composable widgets, adds an inline lyrics panel with waveform strip, fixes multi-artist album grouping for compilations, optimizes artwork loading performance during scroll, syncs widget state on service restart, and introduces a dedicated Queue Settings screen.

## Overview

This beta adds six headline features:

1. **Full player refactor** — player broken into composable widgets with dedicated action bottom sheets
2. **Lyrics panel & waveform** — inline lyrics with synced/plain views, swipe gesture, waveform strip
3. **Multi-artist album grouping** — compilations with different artists now group correctly
4. **Artwork performance** — paused extraction during scroll, 2× decode cap, memoized path checks
5. **Widget sync fix** — playback state survives audio service kill
6. **Queue settings** — dedicated screen with wrap-around toggle, playlist context from recents

## Highlights

- **Player refactor**: `FullPlayerScreen` was split into `PlayerControls`, `PlayerActionButtonRow`, `AnimatedSongScene`, and `AnimatedAlbumArt` — each a standalone widget. Multi-layout support lets the scene widget adapt to different player configurations. Vinyl morph and rotation seek logic was extracted into `AnimatedAlbumArt` for reuse. New player bottom sheets cover song actions (queue, favorite, add to playlist, share, delete), volume control, playback speed, sleep timer with preset times, and player layout customization. `PlayerNavigation` centralizes queue and navigation actions. A `VisualizerArtBox` widget provides consistent frame and shadow styling. A shared duration formatting utility avoids duplication. Interactive seek lifecycle was fixed to suppress engine position writes during drag and clean up on widget dispose.
- **Lyrics panel**: An inline lyrics panel with synced and plain lyrics views lets you sing along without leaving the player screen. A lyrics-mode waveform strip with swipe gesture provides a discoverable affordance — swipe up to reveal lyrics, with an animated arrow indicator. The waveform layer was extracted for reusable progress bar styling across the player.
- **Album grouping**: Multi-artist compilations where tracks on the same album have different artist fields now group correctly. Album filtering was narrowed to match only the `albumArtist` field. Unit tests cover compilation edge cases in `SongRepository.resolveGroupArtist`.
- **Artwork performance**: Artwork extraction is paused during fast scroll and resumed after a debounce period when scroll momentum settles. Artwork is always decoded at 2× display size to prevent out-of-memory errors on fast fling through large libraries. Path existence checks are memoized to avoid redundant filesystem I/O.
- **Widget sync**: When the audio service is killed (e.g., by Android memory pressure) and restarted, widget playback state now syncs correctly. An `updateAllWidgets` helper on `WidgetPrefs` enables batch widget refresh.
- **Queue settings**: A dedicated Queue Settings screen holds the wrap-around queue toggle, moved out of the Playback settings screen. Playlist context is now passed when tapping a recently played or recently added song, so scrobbling and shuffle scope correctly.

## What's New

### Full Player Refactor & Widgets

- Composable widgets: `PlayerControls`, `PlayerActionButtonRow`, `AnimatedSongScene`, `AnimatedAlbumArt`
- Multi-layout player support
- Extracted `AnimatedAlbumArt` with vinyl morph + rotation seek
- Bottom sheets: song actions, volume, playback speed, sleep timer, layout customization
- `PlayerNavigation` for centralized queue/navigation
- `VisualizerArtBox` with frame and shadow
- Interactive seek lifecycle fixes

### Lyrics Panel & Waveform

- Inline synced and plain lyrics panel
- Waveform strip with swipe gesture to lyrics
- Animated arrow affordance
- Extracted waveform layer for progress bar styling

### Multi-Artist Album Grouping

- Compilations with multiple artists per album key group correctly
- `albumArtist` filtering only
- Unit tests for `resolveGroupArtist`

### Artwork Performance

- Scroll-paused extraction (debounced)
- 2× decode cap to prevent OOM
- Memoized path existence checks

### Widget Sync Fix

- Widget state sync on service kill/restart
- `updateAllWidgets` batch helper

### Queue Settings & Playlist Context

- Dedicated Queue Settings screen with wrap-around toggle
- Playlist context from recently played / recently added

## Files Changed

| Area | Key Paths |
| --- | --- |
| Player | `lib/features/player/screens/full_player_screen.dart`, `lib/features/player/widgets/` |
| Lyrics | `lib/features/lyrics/widgets/inline_lyrics_panel.dart`, `lib/features/lyrics/widgets/lyrics_waveform_strip.dart` |
| Albums | `lib/models/album.dart`, `lib/data/repositories/song_repository.dart`, `test/data/repositories/song_repository_test.dart` |
| Artwork | `lib/services/artwork_extraction_service.dart`, `lib/services/artwork_cache_service.dart` |
| Widgets | `android/.../widget/`, `lib/services/widget_prefs.dart` |
| Queue | `lib/features/settings/screens/queue_settings_screen.dart`, `lib/providers/player_provider.dart` |

## Upgrading

1. Player bottom sheets are accessed from the player controls — tap the three-dot menu, volume icon, speed badge, or timer
2. Lyrics panel: swipe up from the waveform strip to reveal inline lyrics
3. Multi-artist album grouping applies on next scan — compilation albums will re-group correctly
4. Artwork performance improvements are automatic — no configuration needed
5. Queue settings moved to Settings → Playback → Queue; old wrap-around toggle removed from Playback screen
