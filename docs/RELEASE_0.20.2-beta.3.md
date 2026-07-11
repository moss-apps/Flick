# Flick 0.20.2-beta.3

0.20.2-beta.3 is a polish and stability release: Bluetooth codec control with Hi-Res Direct mode, glance card visibility toggles, streak popup visual polish, USB clock and permission fixes, artwork cache improvements, and queue wrap-around fixes.

## Overview

This beta adds seven headline features:

1. **Bluetooth codec control** — Hi-Res Direct mode, per-codec preferences, device filtering, developer debug
2. **Glance card toggles** — show/hide/minimize Quick Access cards from Interface settings
3. **Streak & milestone polish** — tier-colored text, dynamic glow effects, performance improvements
4. **USB audio fixes** — write-only clock support, PendingIntent fix
5. **Artwork cache** — content-based keys, embedded art normalization
6. **Queue wrap-around** — playlist restart from end
7. **Debug logging** — strategy and decoder selection paths

## Highlights

- **Bluetooth codec control**: A Hi-Res Direct mode forces the highest-quality codec (LDAC, aptX HD) for compatible headphones. Per-codec preferences (AAC, aptX, LDAC, SBC, etc.) are persisted and applied on Bluetooth init and device connect. Device connection state is tracked with codec configuration feedback in the UI. Hi-Res Direct mode is resolved before low-latency in audio route selection. Bluetooth settings gained device filtering, UI refinements, and a developer mode toggle for advanced codec debugging.
- **Glance cards**: Each Quick Access card (Recently Played, Smart Mixes, Artists, etc.) can now be hidden, shown, or minimized independently. Per-card preferences are persisted. `AlbumsScreen` was migrated to `ConsumerStatefulWidget` (Riverpod) with app preferences. Single-art and empty-art album edge cases are handled, and the album year is displayed on album cards. `AlbumArtPickerBottomSheet` returns a change status for reactive UI updates. A stale song provider after in-place art updates is prevented.
- **Streak polish**: The animated shimmer streak number on the popup was replaced with static tier-colored text — no more phantom shimmer glitter. Dynamic tier colors and glow effects pulse on the streak banner. Tier color and count helpers were added to `MilestoneCategoryX`. New unit tests cover tier colors and counts.
- **USB fixes**: Write-only USB clocks (devices that don't support readback on `GET_CUR`) are now supported by trusting the `SET_CUR` value. A USB permission `PendingIntent` failure on devices with restrictive package handling is fixed.
- **Artwork cache**: Embedded album art is normalized before caching so that different encodings of the same image share one cache entry. Cache keys are now content-based rather than path-based — the same artwork from different files reuses the cached bitmap.
- **Queue**: Playlists now restart from the end when wrap-around queue is enabled. A duplicate recently-played entry check that could skip play-count updates was removed.
- **Debug**: Debug logging was added to the audio strategy score calculation and decoder selection paths, making it easier to trace why a particular audio path or decoder was chosen.

## What's New

### Bluetooth Codec Control

- Hi-Res Direct mode forces highest-quality codec
- Per-codec preference persistence (AAC, aptX, LDAC, etc.)
- Codec preferences applied on init and connect
- Device connection state with codec feedback
- Hi-Res Direct before low-latency in route resolution
- Device filtering and UI refinements in Bluetooth settings
- Developer mode toggle for codec debugging

### Glance Cards & Albums

- Show/hide/minimize per Quick Access card
- Riverpod-based AlbumsScreen with app preferences
- Single-art/empty-art edge cases; album year display
- Change-status return from AlbumArtPickerBottomSheet
- Stale song provider fix on art updates

### Streak & Milestone Polish

- Static tier-colored text replaces animated shimmer
- Dynamic tier colors and glow on streak banner
- Tier-based shimmer on popup background
- `MilestoneCategoryX` tier color/count helpers
- Tier color and count tests

### USB Audio Fixes

- Write-only USB clock support (trusts SET_CUR)
- USB PendingIntent fix for restrictive packages

### Artwork Cache

- Embedded art normalized before caching
- Content-based cache keys

### Queue & Playback

- Playlist wrap-around from end
- Duplicate recently-played check removed

### Debug & Developer

- Debug logging in strategy/decoder selection
- Feature requests doc

## Files Changed

| Area | Key Paths |
| --- | --- |
| Bluetooth | `lib/services/bluetooth_service.dart`, `lib/features/settings/screens/bluetooth_settings_screen.dart`, `lib/providers/` |
| Glance Cards | `lib/features/home/widgets/menu_screen.dart`, `lib/providers/app_preferences_provider.dart` |
| Albums | `lib/features/albums/screens/albums_screen.dart`, `lib/widgets/album_art_picker_bottom_sheet.dart` |
| Streaks | `lib/features/milestones/widgets/streak_popup.dart`, `lib/services/milestone_service.dart` |
| USB | `rust/src/uac2/`, `rust/src/audio/android_direct_usb.rs` |
| Artwork | `lib/services/artwork_cache_service.dart`, `lib/services/cache_manager_service.dart` |
| Queue | `lib/providers/player_provider.dart` |

## Upgrading

1. Bluetooth codec controls are in Settings → Audio → Bluetooth — Hi-Res Direct is off by default
2. Glance card visibility toggles are in Settings → Interface — all cards default to shown
3. Streak popup styling applies automatically; no configuration needed
4. USB clock fixes are transparent — no user action required
5. Artwork cache is rebuilt with content-based keys on next scan; slightly faster subsequent lookups
