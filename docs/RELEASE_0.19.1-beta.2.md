# Flick 0.19.1-beta.2

0.19.1-beta.2 is a polish release. Home screen widgets are redesigned with bitmap text rendering, crossfade gets a stability pass, a full Help & Manual system lands with a tutorial overlay, the songs screen switches to album grid mode, folders get a tree view, and the nav bar receives animation polish.

## Overview

This beta adds nine headline features:

1. **Home widgets redesigned** — bitmap text rendering for RemoteViews, flagship 2×2 widget enabled with transport controls
2. **Crossfade stability** — advance pending flag, stream restart on interruption, sample-rate rebinding, experimental tag
3. **Help & Manual system** — searchable manual screen with collapsible sections, tutorial overlay with dynamic spotlights
4. **Songs screen album grid** — songs refactored from folder grouping to album-based grid mode
5. **Folder tree view** — expandable hierarchy with glass styling and guide lines
6. **Nav bar animations** — directional slide on item select/deselect, dismiss-on-tap-outside bottom sheets
7. **Artwork card frame** — optional glass frame around album art cards
8. **UAC1 sample rate** — endpoint SET_CUR for older UAC 1.0 devices
9. **UI polish** — milestones list layout, AnimatedSize expansion, refactored tutorial state

## Highlights

- **Widgets**: The mini player and flagship widgets now use bitmap text rendering via a shared `WidgetTextRenderer` class, solving RemoteViews font compatibility issues across Android versions. The flagship 2×2 widget is enabled with a redesigned layout including transport controls, shuffle/repeat buttons, per-widget accent color, and content settings. Widget art loading accepts a max-pixel-dimension parameter for performance. Unused drawables, themes, and layout code were removed.
- **Crossfade**: A crossfade advance pending flag prevents duplicate track advancement during transitions, with state tracking moved to `RustAudioService`. The crossfader now restarts its stream on Oboe interruption and preserves settings across sample rate changes via `rebind_sample_rate`. Redundant re-queuing on duration changes is prevented. Configured and active crossfade durations are separated — the fade clamps to half the track length. Crossfade forces the DSP audio path and is suppressed under 432 Hz tuning. The Crossfade section in settings is tagged as experimental.
- **Help & Manual**: A full manual screen with search and collapsible sections covers all app features. Manual data models organize help content. A tutorial overlay uses dynamic spotlight positioning to highlight UI elements, with a target registry and anchor widget for consistency. `TutorialStep` carries metadata (title, description, target). Song search, sort button, nav bar, and mini player are wrapped in tutorial targets. Help & Manual has its own Settings section.
- **Songs & folders**: The songs screen switched from folder-based grouping to album-based grid mode. Album sort replaced the old folder sort. A new folder tree view mode has expandable hierarchy with glass-styled guide lines — toggle between grid and tree view.
- **Nav bar**: `FlickNavBar` is now a `StatefulWidget` with directional slide animation on item selection/deselection. The sliding animation on nav items was removed for a cleaner feel. Bottom sheets dismiss on tap outside. `SettingsSectionHeader` gained an optional tag badge for marking experimental features.
- **Artwork frame**: An optional glass frame around album art cards, toggled from Settings with a persisted `showArtworkCardFrame` preference. Artwork sizing adjusts to accommodate the frame.
- **Audio**: UAC1 sample rate is now handled via endpoint SET_CUR requests for older UAC 1.0 devices. The audio engine defaults to `rustOboe` only when `exoPlayer` is selected. DAP shared path logic and engine selection UI were refined.
- **Polish**: The milestone collection grid switched to a list layout. `AnimatedCrossFade` was replaced with `AnimatedSize` for smoother section expansion. Tutorial overlay logic and state management were refactored. Unused manual screen sections were removed and entry content extracted into its own widget.

## What's New

### Home Widgets Redesigned

- Mini player widget redesigned with bitmap text via `WidgetTextRenderer`
- Flagship 2×2 widget enabled with transport controls, shuffle/repeat, accent color, content settings
- Widget art loading with max-pixel-dimension parameter
- Removed unused widget drawables, themes, layouts

### Crossfade Fixes & Polish

- Advance pending flag prevents duplicate track advancement
- State tracking moved to `RustAudioService`
- Stream restart on Oboe interruption
- `rebind_sample_rate` preserves settings across rate changes
- Redundant re-queuing prevented on duration changes
- Separate configured vs. active durations; clamps to half track length
- Forces DSP path; suppressed under 432 Hz
- Tagged as experimental in settings

### Help & Manual System

- Manual screen with search and collapsible sections
- Full help content across all app features
- Tutorial overlay with dynamic spotlight positioning
- Target registry and anchor widget
- `TutorialStep` with metadata
- Settings → Help & Manual section
- Tutorial targets on search bar, sort button, nav bar, mini player

### Songs Screen: Album Grid Mode

- Folder grouping → album grid mode
- Album sort replaces folder sort

### Folder Tree View

- Expandable hierarchy with glass styling and guide lines
- Grid/tree toggle

### Nav Bar & Bottom Sheet Polish

- `StatefulWidget` with directional slide animation
- Removed item sliding animation
- Bottom sheets dismiss on tap outside
- Optional tag badge on `SettingsSectionHeader`

### Artwork Card Frame

- Optional glass frame around album art cards
- `showArtworkCardFrame` preference

### Audio Engine & UAC1

- UAC1 sample rate via endpoint SET_CUR
- `rustOboe` only for exoPlayer preference
- Refined DAP shared path logic and engine selection UI

### UI Polish

- Milestones switched to list layout
- `AnimatedSize` replaces `AnimatedCrossFade`
- Refactored tutorial overlay logic
- Extracted entry content widget

## Files Changed

| Area | Key Paths |
| --- | --- |
| Widgets | `android/.../widget/`, `android/.../MiniPlayerWidgetProvider.kt`, `android/.../FlagshipWidgetProvider.kt` |
| Crossfade | `rust/src/audio/crossfader.rs`, `rust/src/audio/crossfade_engine.rs`, `lib/services/rust_audio_service.dart` |
| Manual | `lib/features/manual/`, `lib/data/manual/` |
| Tutorial | `lib/features/tutorial/`, `lib/widgets/tutorial_target.dart` |
| Songs | `lib/features/songs/screens/songs_screen.dart` |
| Folders | `lib/features/folders/screens/folder_browser_screen.dart`, `lib/features/folders/widgets/folder_tree_view.dart` |
| Nav Bar | `lib/widgets/flick_nav_bar.dart` |
| Artwork Card | `lib/widgets/artwork_card.dart`, `lib/providers/app_preferences_provider.dart` |
| Audio Engine | `rust/src/uac1/`, `rust/src/audio/engine.rs`, `lib/features/settings/screens/audio_engine_screen.dart` |
| UI | `lib/features/milestones/`, `lib/widgets/settings_section_header.dart` |

## Upgrading

1. The widget redesign takes effect on the next widget update — no user action required
2. Flagship 2×2 widget is now available from the launcher's widget picker
3. Crossfade is experimental and tagged as such in settings — enable with caution
4. Help & Manual is accessible from Settings → Help & Manual; the tutorial overlay triggers from within the manual
5. Songs screen now defaults to album grid mode — the old folder grouping is replaced
6. Folder tree view is toggled from the folder browser toolbar
7. Artwork card frame is off by default — enable from Settings → Interface
8. UAC1 sample rate handling applies automatically to UAC 1.0 devices — no configuration needed
