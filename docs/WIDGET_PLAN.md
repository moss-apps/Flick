# Flick Player — Multi-Widget Implementation Plan

## Overview

Expand Flick Player's single 4×1 mini player widget into **4 widget variants** with **8 total themes**, implemented in 3 phases.

| Variant | Size | Themes | Phase |
|---------|------|--------|-------|
| 2×2 Flagship | ~160dp | Art Dominant, Card, Split | Phase 1 |
| 1×1 Square | ~80dp | Art + ring progress | Phase 2 |
| 4×2 Full | ~320×160dp | Classic (seek bar), Modern (art + floating panel) | Phase 2 |
| 3×2 Wide | ~240×160dp | Split (art left/controls right), Cinematic (wide art + bottom bar) | Phase 3 |

**Total:** 8 layouts, 4 providers, 1 shared infrastructure.

---

## Shared Infrastructure

### Architecture: 4 Providers, Shared Utilities

```
Kotlin Providers (new):
  FlagshipWidgetProvider.kt    — 2×2 (Phase 1)
  SquareWidgetProvider.kt      — 1×1 (Phase 2)
  FullWidgetProvider.kt        — 4×2 (Phase 2)
  WideWidgetProvider.kt        — 3×2 (Phase 3)

Shared Utilities (existing, no changes):
  WidgetActionReceiver.kt      — handles all action broadcasts
  WidgetIntents.kt             — creates PendingIntents (all actions already wired)
  WidgetPrefs.kt               — reads SharedPreferences
  WidgetArtLoader.kt           — loads/downsamples album art

Dart Services (modify):
  WidgetSyncService            — update all provider classes on each sync
  widget_settings_screen.dart  — tabbed UI for all variants
  WidgetIntentHandler          — no changes needed
```

### AndroidManifest Registrations

Each provider gets its own `<receiver>` entry with `APPWIDGET_UPDATE` intent filter and `<meta-data android:name="android.appwidget.provider">` pointing to its `widget_info.xml`.

### WidgetSyncService Changes

Refactor `updateWidget()` into `updateAllWidgets()` that calls `HomeWidget.updateWidget()` for each provider class name. Each sync method (`pushNow`, `pushPaused`, `pushKilled`) calls `updateAllWidgets()`.

Provider class name constants:
- `MiniPlayerWidgetProvider` (existing)
- `FlagshipWidgetProvider` (Phase 1)
- `SquareWidgetProvider` (Phase 2)
- `FullWidgetProvider` (Phase 2)
- `WideWidgetProvider` (Phase 3)

### Settings Screen

Refactor to tabbed layout:
- **Mini Player** — existing 4×1 settings
- **Square 1×1**
- **Flagship 2×2**
- **Wide 3×2**
- **Full 4×2**

Each tab: theme picker (where applicable), accent color, relevant toggles.

### WidgetPrefs Additions

Per-variant preference keys:
- `flick_widget_{variant}_theme` — String (theme name)
- `flick_widget_{variant}_accent` — String (accent color)
- `flick_widget_{variant}_show_artist` — Bool

---

## Phase 1: 2×2 Flagship Widget (3 Themes)

### New Files

```
kotlin/com/mossapps/flick/widgets/
  FlagshipWidgetProvider.kt

res/layout/
  widget_flagship_art.xml       — art dominant theme
  widget_flagship_card.xml      — card theme
  widget_flagship_split.xml     — split theme

res/xml/
  flagship_widget_info.xml

res/drawable/
  widget_flagship_preview.png   — widget picker preview (or previewLayout on Android 12+)
```

### FlagshipWidgetProvider Logic

1. Read `flick_widget_flagship_theme` from SharedPreferences
2. Select layout: `art_dominant` → `widget_flagship_art`, `card` → `widget_flagship_card`, `split` → `widget_flagship_split`
3. Load album art via `WidgetArtLoader`
4. Populate text (title, artist), visibility toggles
5. Apply accent color to text + progress drawables via `setColor()`
6. Attach PendingIntents (play/pause, next, prev, open app) via `WidgetIntents`
7. Handle idle/killed state with default art + "Tap to open Flick"

### Theme 1: Art Dominant

Album art fills the entire widget background. Text and controls float over a bottom scrim.

```
FrameLayout
├── ImageView (album art, scaleType=centerCrop, fills widget)
├── ImageView/View (bottom scrim gradient — widget_scrim_bottom.xml)
├── LinearLayout (bottom, horizontal)
│   ├── TextView (title, white, bold, 14sp, ellipsize end)
│   └── TextView (artist, white70, 12sp, ellipsize end)
├── LinearLayout (bottom-center, transport)
│   ├── ImageButton (prev, 32dp, widget_ic_previous)
│   ├── ImageButton (play/pause, 40dp, widget_ic_play/pause)
│   └── ImageButton (next, 32dp, widget_ic_next)
└── ProgressBar (3dp horizontal, bottom edge, accent colored)
```

### Theme 2: Card

Dark card with rounded corners. Album art on left, text + controls on right.

```
LinearLayout (horizontal, widget_mini_player_card.xml background)
├── ImageView (album art, left half, match_parent height)
└── LinearLayout (vertical, right half, padding 12dp)
    ├── TextView (title, bold, 14sp, max 2 lines, ellipsize end)
    ├── TextView (artist, 12sp, max 1 line, ellipsize end)
    ├── Space (flex)
    └── LinearLayout (horizontal, transport, gravity=center)
        ├── ImageButton (prev, 32dp)
        ├── ImageButton (play/pause, 40dp)
        └── ImageButton (next, 32dp)
```

### Theme 3: Split

Top half album art, bottom half dark panel with text and controls.

```
LinearLayout (vertical)
├── ImageView (album art, weight=0.6, scaleType=centerCrop)
└── LinearLayout (weight=0.4, dark bg, padding 12dp)
    ├── TextView (title, bold, 14sp, ellipsize end)
    ├── TextView (artist, 12sp, ellipsize end)
    ├── LinearLayout (horizontal, transport, gravity=center)
    │   ├── ImageButton (prev, 32dp)
    │   ├── ImageButton (play/pause, 40dp)
    │   └── ImageButton (next, 32dp)
    └── ProgressBar (2dp, accent colored)
```

### Widget Info (`flagship_widget_info.xml`)

```xml
<appwidget-provider
    minWidth="160dp"
    minHeight="160dp"
    targetCellWidth="2"
    targetCellHeight="2"
    resizeMode="none"
    widgetCategory="home_screen"
    updatePeriodMillis="0"
    previewLayout="@layout/widget_flagship_art" />
```

### Settings Tab: Flagship 2×2

- Theme picker (3 options with preview thumbnails)
- Accent color (white, amber, blue, green, purple)
- Show/hide artist toggle

### Preference Keys

| Key | Type | Values |
|-----|------|--------|
| `flick_widget_flagship_theme` | String | `art_dominant`, `card`, `split` |
| `flick_widget_flagship_accent` | String | `white`, `amber`, `blue`, `green`, `purple` |
| `flick_widget_flagship_show_artist` | Bool | `true` / `false` |

### Phase 1 Implementation Steps

1. Create `FlagshipWidgetProvider.kt` with theme selection logic
2. Create 3 layout XMLs (art dominant, card, split)
3. Create `flagship_widget_info.xml`
4. Register provider in `AndroidManifest.xml`
5. Add new drawables if needed (scrim variants, backgrounds)
6. Update `WidgetSyncService` to call `updateWidget` for FlagshipWidgetProvider
7. Update `widget_settings_screen.dart` with Flagship tab
8. Test all 3 themes on device
9. Verify PendingIntents work (play/pause, next, prev, open app)
10. Verify data sync (art, title, artist, is_playing state)

---

## Phase 2: 1×1 Square + 4×2 Full

### 1×1 Square Widget

#### New Files

```
kotlin/com/mossapps/flick/widgets/
  SquareWidgetProvider.kt

res/layout/
  widget_square.xml

res/xml/
  square_widget_info.xml

res/drawable/
  widget_ic_flick_logo.xml    — (already created, Flick dot-logo)
```

#### Layout: `widget_square.xml`

No media controls. Displays album art as background, Flick logo, song title, and artist name. Semi-transparent dark scrim for readability.

```
FrameLayout (match_parent × match_parent)
├── ImageView (id: square_art, album art, centerCrop, fills widget)
├── View (dark scrim overlay, semi-transparent)
├── ImageView (id: square_logo, Flick logo, centered, 24dp)
├── TextView (id: square_title, white, bold, 10sp, centered below logo, singleLine, ellipsize)
└── TextView (id: square_artist, white70, 8sp, centered below title, singleLine, ellipsize)
```

Idle state: Shows Flick logo + "Tap to open" text.

#### SquareWidgetProvider Logic

1. Read shared preferences (song title, artist, art path, has_song)
2. Inflate `widget_square.xml`
3. If has_song: load album art, set title/artist text, set Flick logo
4. If idle: show default art + Flick logo + "Tap to open"
5. Tapping the entire widget opens the app (no transport controls)
6. Apply accent color to artist text

#### Widget Info

```xml
<appwidget-provider
    minWidth="40dp"
    minHeight="40dp"
    targetCellWidth="1"
    targetCellHeight="1"
    resizeMode="none"
    widgetCategory="home_screen"
    updatePeriodMillis="0"
    previewLayout="@layout/widget_square" />
```

#### Settings Tab: Square 1×1

- Show/hide artist name
- Accent color

---

### 4×2 Full Widget

#### New Files

```
kotlin/com/mossapps/flick/widgets/
  FullWidgetProvider.kt

res/layout/
  widget_full_classic.xml         — traditional with seek bar
  widget_full_modern.xml          — art background + floating panel

res/xml/
  full_widget_info.xml

res/drawable/
  widget_full_preview.png
```

#### Theme 1: Classic

Traditional full-width player. Only variant with **shuffle + repeat** buttons (utilizes already-wired `WidgetIntents.playerShuffle()` and `playerRepeat()`).

```
LinearLayout (vertical, dark bg)
├── LinearLayout (horizontal, top)
│   ├── ImageView (album art, 80×80dp, rounded)
│   └── LinearLayout (vertical, padding 12dp)
│       ├── TextView (title, 15sp, bold, ellipsize end)
│       └── TextView (artist, 13sp, ellipsize end)
├── LinearLayout (horizontal, transport, gravity=center)
│   ├── ImageButton (shuffle, 28dp, widget_ic_shuffle)
│   ├── ImageButton (prev, 36dp)
│   ├── ImageButton (play/pause, 44dp, styled bg)
│   ├── ImageButton (next, 36dp)
│   └── ImageButton (repeat, 28dp, widget_ic_repeat/repeat1)
└── ProgressBar (horizontal, 4dp, seek-style, accent)
```

Shuffle icon: tinted when `is_shuffle = true` (use `setColor()` on ImageView).
Repeat icon: shows `widget_ic_repeat` normally, `widget_ic_repeat1` when `loop_mode = 1`. Tinted when `loop_mode > 0`.

#### Theme 2: Modern

Large album art background with floating semi-transparent control panel.

```
FrameLayout (match_parent × match_parent)
├── ImageView (album art, centerCrop, fills background)
├── View (dark scrim overlay)
└── LinearLayout (bottom, semi-transparent dark bg, 16dp rounded top corners)
    ├── LinearLayout (horizontal)
    │   ├── LinearLayout (vertical, weight=1)
    │   │   ├── TextView (title, white, bold, 14sp)
    │   │   └── TextView (artist, white70, 12sp)
    │   └── LinearLayout (transport: prev, play/pause, next)
    └── ProgressBar (3dp, accent)
```

#### Widget Info

```xml
<appwidget-provider
    minWidth="320dp"
    minHeight="110dp"
    targetCellWidth="4"
    targetCellHeight="2"
    resizeMode="horizontal|vertical"
    widgetCategory="home_screen"
    updatePeriodMillis="0" />
```

#### Settings Tab: Full 4×2

- Theme picker (Classic / Modern)
- Accent color
- Show/hide shuffle + repeat buttons (Classic theme only)

---

## Phase 3: 3×2 Wide Widget

### New Files

```
kotlin/com/mossapps/flick/widgets/
  WideWidgetProvider.kt

res/layout/
  widget_wide_split.xml           — art left, controls right
  widget_wide_cinematic.xml       — wide art + bottom overlay bar

res/xml/
  wide_widget_info.xml

res/drawable/
  widget_wide_preview.png
```

### Theme 1: Split

Album art fills left half, controls on right.

```
LinearLayout (horizontal, dark bg)
├── ImageView (album art, square, weight=1, scaleType=centerCrop)
└── LinearLayout (vertical, weight=1, padding 12dp)
    ├── TextView (title, 14sp, bold, max 2 lines, ellipsize end)
    ├── TextView (artist, 12sp, ellipsize end)
    ├── Space (flex)
    └── LinearLayout (horizontal, transport, gravity=center)
        ├── ImageButton (prev, 32dp)
        ├── ImageButton (play/pause, 40dp)
        └── ImageButton (next, 32dp)
```

### Theme 2: Cinematic

Wide album art background with dark overlay bar at bottom.

```
FrameLayout (match_parent × match_parent)
├── ImageView (album art, centerCrop, fills background)
├── View (bottom scrim gradient, ~40% height)
└── LinearLayout (bottom, horizontal, padding 12dp)
    ├── LinearLayout (vertical, weight=1)
    │   ├── TextView (title, 14sp, white, bold, ellipsize end)
    │   └── TextView (artist, 12sp, white70, ellipsize end)
    └── LinearLayout (horizontal, transport)
        ├── ImageButton (prev, 32dp)
        ├── ImageButton (play/pause, 40dp)
        └── ImageButton (next, 32dp)
```

### Widget Info

```xml
<appwidget-provider
    minWidth="240dp"
    minHeight="110dp"
    targetCellWidth="3"
    targetCellHeight="2"
    resizeMode="horizontal"
    widgetCategory="home_screen"
    updatePeriodMillis="0" />
```

### Settings Tab: Wide 3×2

- Theme picker (Split / Cinematic)
- Accent color
- Show/hide artist toggle

---

## Data Flow

### Flutter → Native (per widget variant)

```
WidgetSyncService.pushNow()
  ├── HomeWidget.saveWidgetData(...)     (shared data for all widgets)
  ├── HomeWidget.updateWidget(androidProvider: 'MiniPlayerWidgetProvider')
  ├── HomeWidget.updateWidget(androidProvider: 'FlagshipWidgetProvider')
  ├── HomeWidget.updateWidget(androidProvider: 'SquareWidgetProvider')
  ├── HomeWidget.updateWidget(androidProvider: 'FullWidgetProvider')
  └── HomeWidget.updateWidget(androidProvider: 'WideWidgetProvider')
```

Each provider's `onUpdate()` reads the same shared prefs keys plus its own per-variant theme/settings keys.

### Native → Flutter (shared, no changes needed)

```
Widget button click
  → WidgetActionReceiver (BroadcastReceiver)
  → MethodChannel ("com.mossapps.flick/widget")
  → WidgetIntentHandler.dispatch()
  → Player action (play/pause/next/prev/shuffle/repeat)
```

All widget variants share the same action routing — `WidgetIntents` already creates the correct PendingIntents, and `WidgetActionReceiver` already routes them to Flutter.

---

## Shared Preference Keys

### Global (existing, shared by all widgets)

| Key | Type | Description |
|-----|------|-------------|
| `flick_widget_song_id` | String | Current song ID |
| `flick_widget_title` | String | Song title |
| `flick_widget_artist` | String | Artist name |
| `flick_widget_album_art` | String | Album art file path |
| `flick_widget_is_playing` | Bool | Playing state |
| `flick_widget_has_song` | Bool | Whether a song is loaded |
| `flick_widget_is_shuffle` | Bool | Shuffle state |
| `flick_widget_loop_mode` | Int | 0=off, 1=one, 2=all |
| `flick_widget_position_ms` | Long | Current position |
| `flick_widget_duration_ms` | Long | Song duration |
| `flick_widget_queue_count` | Int | Queue size |

### Per-Variant (new)

| Key | Type | Variant | Description |
|-----|------|---------|-------------|
| `flick_widget_flagship_theme` | String | 2×2 | `art_dominant`, `card`, `split` |
| `flick_widget_flagship_accent` | String | 2×2 | Accent color name |
| `flick_widget_flagship_show_artist` | Bool | 2×2 | Show artist text |
| `flick_widget_square_show_ring` | Bool | 1×1 | Show progress ring |
| `flick_widget_full_theme` | String | 4×2 | `classic`, `modern` |
| `flick_widget_full_accent` | String | 4×2 | Accent color name |
| `flick_widget_full_show_extras` | Bool | 4×2 | Show shuffle/repeat (classic theme) |
| `flick_widget_wide_theme` | String | 3×2 | `split`, `cinematic` |
| `flick_widget_wide_accent` | String | 3×2 | Accent color name |
| `flick_widget_wide_show_artist` | Bool | 3×2 | Show artist text |

---

## RemoteViews Constraints & Workarounds

| Constraint | Workaround |
|------------|------------|
| No custom Canvas drawing | Generate bitmaps in Kotlin (`WidgetProgressRing.kt`) |
| No blur/glass effect | Use pre-rendered gradient drawables (scrim, overlays) |
| No dynamic layout changes | Pre-build all theme layouts, select at inflation time |
| Limited view types | FrameLayout, LinearLayout, RelativeLayout, ImageView, TextView, ProgressBar, ImageButton |
| Accent color on drawables | Use `RemoteViews.setColorFilter()` on ImageViews |
| Progress bar color | Pre-build colored progress drawables (already exists: white/amber/blue/green/purple) |
| Widget preview | Use `previewLayout` attribute (Android 12+) to show actual layout |

---

## File Summary

### Phase 1 (2×2 Flagship)
- `FlagshipWidgetProvider.kt` — new
- `widget_flagship_art.xml` — new
- `widget_flagship_card.xml` — new
- `widget_flagship_split.xml` — new
- `flagship_widget_info.xml` — new
- `AndroidManifest.xml` — modify (add receiver)
- `widget_sync_service.dart` — modify
- `widget_settings_screen.dart` — modify (add tab)

### Phase 2 (1×1 + 4×2)
- `SquareWidgetProvider.kt` — new
- `WidgetProgressRing.kt` — new
- `widget_square.xml` — new
- `square_widget_info.xml` — new
- `FullWidgetProvider.kt` — new
- `widget_full_classic.xml` — new
- `widget_full_modern.xml` — new
- `full_widget_info.xml` — new
- `AndroidManifest.xml` — modify (add 2 receivers)
- `widget_sync_service.dart` — modify (add 2 providers)
- `widget_settings_screen.dart` — modify (add 2 tabs)

### Phase 3 (3×2 Wide)
- `WideWidgetProvider.kt` — new
- `widget_wide_split.xml` — new
- `widget_wide_cinematic.xml` — new
- `wide_widget_info.xml` — new
- `AndroidManifest.xml` — modify (add receiver)
- `widget_sync_service.dart` — modify (add 1 provider)
- `widget_settings_screen.dart` — modify (add 1 tab)
