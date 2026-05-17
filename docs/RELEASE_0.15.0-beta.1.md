# Flick 0.15.0-beta.1

0.15.0-beta.1 is the biggest feature update yet. Home screen widgets, online lyrics, a full lyrics editor, visualizer customization, swipe actions, queue management, immersive full view, and folder grid browsing are all new. Play Store in-app updates are live and GitHub releases will soon be deprecated.

## Overview

This beta adds six headline features:

1. **Home screen mini player widget** — see what's playing and control playback from your home screen
2. **Online lyrics search** — find synced LRC lyrics from LRCLib.net without leaving the player
3. **Lyrics Sync Studio** — built-in timestamp editor for writing and editing synced lyrics
4. **Visualizer customization** — five animation styles, five frequency modes, three movement modes
5. **Queue management overhaul** — up next, manual queue, multi-select, clear all, drag to reorder
6. **Folder grid** — browse your music folders as a paginated grid of cards

Alongside these, Bluetooth codec info, immersive full view, swipe actions, folder grid pagination, player layout customization, and a Play Store update system round out the release.

## Highlights

- **Home screen widget**: Mini player widget with album art, progress bar, and transport controls. Customize background, accent color, and visible content from Settings > Widgets
- **Online lyrics**: Search for synced or plain-text lyrics via LRCLib.net, with exact-match and fuzzy search
- **Lyrics editor**: Stamp timestamps by tapping along as the song plays (Simple mode) or edit each line directly (Advanced mode). Import `.lrc`/`.txt`/`.xml` files
- **Visualizer settings**: Choose animation style (Bars, Wave, Curved Wave, Mirrored, Dots), frequency focus (Full, Bass, Mid, Treble, Bass+Treble), and movement (Bouncy, Smooth, Snappy)
- **Queue overhaul**: Now Playing / Up Next / Manual queue sections. Clear all, batch remove, drag to reorder, swipe to dismiss, play next
- **Folder grid**: When sorted by Folder, browse directories as a paginated card grid with infinite scroll
- **Play Store updates**: Automatic update checks with Play Store integration. Manual check available in Settings > App Info
- **Immersive full view**: Auto-hide all controls for full-bleed album art with a floating metadata card
- **Swipe actions**: Swipe left to queue, right to favorite (toggleable in Settings)
- **Player layout customization**: Artwork card scale, text size, text placement, metadata visibility

## What's New

### Home Screen Widget
- Native Android mini player widget via `home_widget` + `AppWidgetProvider`
- Shows album art (downsampled for efficiency), song title, artist, progress bar
- Transport controls: play/pause, next, previous
- Shuffle and repeat state shown on widget
- Active state while playing, idle "Tap to open" state when app is killed
- Handles widget actions even when the app process is dead (launches with intent)
- Widget sync service debounces non-critical updates to every 2 seconds
- Widget settings screen: background opacity (5 levels), accent color (5 options), content toggles

### Lyrics System
- **Online lyrics search**: Queries LRCLib.net API for synced (LRC) or plain-text lyrics
  - Exact match by artist + title + album + duration, then fuzzy fallback
  - Custom search query support
  - Results show synced/plain/instrumental badges
- **Lyrics Sync Studio (editor)**:
  - Simple mode: play the song and tap "Stamp & Next" to timestamp each line in real time
  - Advanced mode: edit each line's timestamp directly
  - Playback assist bar (-2s, play/pause, +2s)
  - Time-shift tools (+/- 100ms, +/- 500ms) for batch-shifting all stamps
  - Auto-fill for unstamped lines
  - Saves `.lrc` beside the song when possible, or managed internally
  - Import `.lrc`/`.txt`/`.xml` files from device storage
  - Reset to automatic/sidecar/embedded lyrics lookup
- Lyrics loading priority chain: manual overrides > embedded > sidecar

### Visualizer
- Five animation styles: Bars, Wave, Curved Wave, Mirrored, Dots
- Five frequency focus modes: Full Spectrum, Bass, Mid, Treble, Bass + Treble
- Three movement styles: Bouncy (spring physics), Smooth (natural EQ feel), Snappy (fast tracking)
- Dedicated visualizer settings screen (Settings > Interface > Visualizer Settings)
- Animated gradient background for immersive mode
- Visualizer-only mode in immersive full view (hides all UI chrome)

### Queue Management
- Queue screen restructured into three sections: Now Playing, Up Next, Manual queue
- Up Next: auto-generated from the current playlist; swipe to dismiss
- Manual queue: user-added songs; drag to reorder via `SliverReorderableList`
- Per-item actions: "Play next" (move to front of up-next), "Remove"
- Multi-select mode: checkbox icon in header or long-press to enter
- Select All and batch removal (reverse-order index removal)
- Clear All upcoming and queued songs in one tap
- Up Next stored as independent state with its own notifier

### Folder Grid
- Paginated grid of folder cards when songs are sorted by Folder
- 2 columns on phone, 3 on tablet
- Lazy loading in pages of 18 folders with infinite scroll
- Folder detail screen with slide-up transition
- Metadata stats (song count, total duration) on each folder card
- Pagination resets on folder list changes (detected by signature)

### Immersive Full View
- Auto-hide timer fades all UI chrome after configurable delay
- Floating metadata card with album art thumbnail, title, artist
- Tap anywhere to toggle full view on/off
- Song changes automatically exit full view
- Visualizer-only mode hides even the floating card
- Customizable: text size (82%-120%), text placement (-36 to +36), card scale (82%-118%)
- Toggle visibility of title, artist, and file info

### Swipe Actions
- Swipe left on a song card to add it to the queue
- Swipe right to favorite it
- Works in both orbit scroll and list views
- Haptic feedback on trigger
- Flash animation confirmation
- Toggle on/off from Settings > Interface > Swipe Actions
- Automatically disabled during multi-select mode

### Player Layout Customization
- Artwork card and immersive view scale/offset preferences
- Show/hide toggles for title, artist, album, and file info
- Player Layout bottom sheet with live preview
- Preferences persist between sessions

### Bluetooth Audio Codec Info
- New section in Audio settings showing current Bluetooth route
- Lists common codecs as reference chips (SBC, AAC, aptX, aptX HD, aptX Adaptive, LDAC, LC3, LHDC)
- Notes that codec negotiation is handled by Android and the connected device
- Route-aware description text via `AndroidAudioDeviceService`

### Play Store Updates
- Automatic update check when online
- Manual check in Settings > App Info
- Connectivity-aware: skips check when offline
- Opens Play Store listing for direct update
- Replaces Shorebird code push

### Other Improvements
- **Migrated to `ConcatenatingAudioSource`**: Queue uses `just_audio`'s native audio source API
- **In-place shuffle**: Audio source sequence shuffled in-place instead of full rebuild
- **Fast index scrolling**: Collapsible alphabetical index overlay with auto-hide timer
- **Reorderable bottom bar**: Drag to reorder nav buttons, hide unwanted items
- **Search field focus management**: Focus clears when switching tabs
- **Library scan count**: Shows added song count after scan completes
- **Timestamp parsing**: Improved LRC timestamp parsing in lyrics service
- **Onboarding redesign**: Animated orb system with page interpolation
- **Blur cache**: Module-level cache for shared album art blur to avoid recomputation
- **Mini player redesign**: New layout with smaller controls and progress bar
- **Double back press to exit**: Replaces auto-full-player navigation
- **Dynamic navbar**: Supports dynamic configuration of nav bar buttons
- **Multi-select in songs screen**: Long-press to enter multi-select with queue/favorite bulk actions
- **CSV/TXT export for listening recaps**: Export Flick Replay data as CSV or TXT
- **Favorite removal mode setting**: Configure how favorites are removed

## Deprecation Notice

**GitHub Releases will be deprecated once Flick's open beta test begins.** Downloading Flick from GitHub Releases will no longer be supported. Update via the Google Play Store to continue receiving the latest builds. If you installed Flick from GitHub, migrate to the Play Store listing before the open beta launches.

## Files Changed

| Area | Key Paths |
| --- | --- |
| Widget | `MiniPlayerWidgetProvider.kt`, `WidgetActionReceiver.kt`, `WidgetIntents.kt`, `WidgetPrefs.kt`, `WidgetArtLoader.kt`, `widget_sync_service.dart`, `widget_intent_handler.dart`, `widget_settings_screen.dart` |
| Lyrics | `lyrics_service.dart`, `online_lyrics_service.dart`, `online_lyrics_search_sheet.dart`, `lyrics_editor_bottom_sheet.dart` |
| Visualizer | `visualizer_settings_screen.dart`, `audio_visualizer.dart`, `full_player_screen.dart` |
| Queue | `queue_screen.dart`, `player_service.dart`, `player_provider.dart` |
| Songs / Folders | `songs_screen.dart`, `song_card.dart`, `orbit_scroll.dart` |
| Immersive | `full_player_screen.dart`, `player_screen_mode.dart` |
| Player Layout | `full_player_screen.dart` (player layout bottom sheet) |
| Settings | `interface_settings_screen.dart`, `audio_settings_screen.dart`, `settings_screen.dart`, `app_info_settings_screen.dart` |
| Navigation | `flick_nav_bar.dart`, `bottom_bar_settings_screen.dart` |
| Updates | `app_info_settings_screen.dart`, `update_check_provider.dart` |
| Recap | `listening_recap_screen.dart`, `recap_export_service.dart` |
| Onboarding | `onboarding_screen.dart` |
| Mini Player | Mini player redesign with progress bar and queue navigation |

## Upgrading

1. If you installed from GitHub Releases, migrate to the Play Store listing before the open beta launches
2. Widget customization is available under Settings > Widgets
3. Visualizer settings are under Settings > Interface > Visualizer Settings
4. Swipe actions can be toggled under Settings > Interface
5. Play Store update checks run automatically when online; manual check in Settings > App Info
