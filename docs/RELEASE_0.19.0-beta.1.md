# Flick 0.19.0-beta.1

0.19.0-beta.1 ships ListenBrainz scrobbling, a floating player overlay, a complete playback modes overhaul, experimental 432 Hz tuning, bass/mid/treble tone controls, Opus audio codec support, a paginated Recently Played redesign, developer mode logging, shared vinyl record widgets, scanner UX improvements, and MediaStore song deletion.

## Overview

This beta adds twelve headline features:

1. **ListenBrainz scrobbling** — offline-safe ListenBrainz integration with rate-limited API, auth service, and freezed models
2. **Floating player overlay** — Android SYSTEM_ALERT_WINDOW mini-player with drag/tap, lifecycle handlers, and Keep Playing on Quit
3. **Playback modes overhaul** — AdvanceListOrder (album/artist/folder/playlist), ShuffleMode categories, PlaybackContext, A-B repeat, new loop modes, long-press mode sheets
4. **Experimental 432 Hz tuning** — A4=432Hz pitch shift via Rust FFI with persistent preference
5. **Bass/mid/treble tone controls** — 3-band tone stack on top of the 31-band parametric EQ
6. **Opus audio codec** — vendored opus-sys crate with full CELT+SILK sources and multi-arch optimizations
7. **Recently Played redesign** — paginated loading with smart date grouping
8. **Developer mode & logging** — gated debug logging across Rust and Dart
9. **Vinyl record & animations** — shared VinylRecord component, animated seeks and transitions
10. **Scanner & library UX** — walkdir migration, fullscreen overlay, pending-rescan flag, auto-sync on resume
11. **Song deletion & MediaStore** — safe MediaStore file removal with confirmation dialog
12. **Code formatting pass** — mass Rust reformatting to 100-column limit

## Highlights

- **ListenBrainz scrobbling**: A full offline-safe ListenBrainz integration submits track-listens to listenbrainz.org. The API client respects rate-limit headers including `retry-after`. `ListenBrainzAuthService` handles token validation and session lifecycle. Freezed models carry track metadata and timestamps. Scrobbles fire on track-start and track-end, including on app resume for any queued submissions. Settings tile under Settings → Integrations.
- **Floating player**: A persistent mini-player overlay drawn via `SYSTEM_ALERT_WINDOW` above other apps. Drag to reposition, tap to open the full player. Lifecycle-aware pause/resume handlers keep audio state coherent. "Keep Playing on Quit" in Settings → Playback prevents the audio engine from shutting down when the app is backgrounded. The floating player is accessible from every library screen — albums, artists, playlists, folders, and the equalizer. A configurable swipe action lets you choose what the mini-player swipe does.
- **Playback modes overhaul**: A completely reworked shuffle and loop system. `AdvanceListOrder` chooses how playback navigates after a track ends — by album, artist, folder, playlist, or default. `ShuffleMode` categories let you shuffle all tracks or only within the current source context. `PlaybackContext` tracks the playback origin so shuffle and advance scope correctly. A-B repeat loops a user-selected section within a track. Long-pressing shuffle or loop now opens a mode-selection bottom sheet instead of cycling blindly, with Snackbar confirmation. Playback modes are persisted and restored when resuming the last song.
- **432 Hz tuning**: An experimental A4=432 Hz pitch shift toggled from Settings → Audio → UAC2. Implemented via Rust FFI with the audio engine. Confirmation dialog warns before enabling. Preference persisted across sessions. Integrated with bit-perfect mode defaults.
- **Bass/mid/treble tone controls**: A three-band tone stack layered on top of the 31-band EQ. BMT offsets are stored in `EqPreset` and affect the EQ graph, hit detection, and parametric curve builder. `RotaryKnob` controls now feature smooth animated transitions. The animated slider widget was extracted for reuse.
- **Opus codec**: The full Opus 1.x codec is vendored via `opus-sys` — CELT for music and SILK for speech, with multi-architecture optimizations including SSE4.1, ARM NEON, ARM EDSP, and MIPSr1. Rust decoder bindings integrate directly into the audio pipeline. OGG extension hints are normalized and `.opus` files routed to the custom decoder. Training scripts, fuzzers, and unit tests are included for both SILK and CELT components.
- **Recently Played redesign**: Paginated loading replaces the infinite-scroll approach for smoother performance on large playback histories. Smart date grouping organizes entries under Today, Yesterday, This Week, and older months. Song info in the bottom sheet actions panel now updates reactively.
- **Developer mode**: A developer mode toggle in `MainActivity` gates verbose logging behind a JNI flag. The `devLog` utility replaces `debugPrint` across ~20 Dart services; `dev_eprintln!` replaces `eprintln!` in Rust. When developer mode is off, the logging path is zero-cost.
- **Vinyl record**: A shared `VinylRecord` custom-painted widget (radial-gradient disc with grooves and label) replaces the inline implementations spread across the player and milestone screens. An album art scope toggle lets you show the vinyl from one song's art or the whole album's. Vinyl mode state prevents gesture conflicts during rotation. Waveform and line seek bars now animate in with `appearProgress`. Mini-player song changes slide directionally.
- **Scanner UX**: The scanner backend migrated from `jwalk` to `walkdir` for more maintainable directory traversal. Scanning now shows a fullscreen overlay with a scan-complete summary sheet instead of toast messages and bottom sheets. A pending-rescan flag prevents missed events during concurrent processing. Auto library sync fires on app resume.
- **Song deletion**: A static `removeFromMediaStore` method safely purges files from Android's MediaStore database. Songs are deleted from the Isar repository before the file is removed from disk. A MediaStore removal fallback handles content URI files in `deleteDocumentViaSaf`. A confirmation dialog appears before deletion.

## What's New

### ListenBrainz Scrobbling

- Offline-safe scrobble queue with SharedPreferences persistence
- API client with rate-limit handling (`retry-after` header respect)
- `ListenBrainzAuthService` for token validation and session management
- Freezed models for session tokens and listen entries
- Track-start and track-end scrobble events; queued submissions on app resume
- Settings tile under Settings → Integrations

### Floating Player Overlay

- `SYSTEM_ALERT_WINDOW` permission for drawing above other apps
- Drag-to-move and tap-to-open interactions
- Lifecycle-aware pause/resume handlers
- "Keep Playing on Quit" prevents audio engine shutdown on app exit
- Toggle in Settings → Playback
- Configurable mini-player swipe action
- Integrated on every library screen (albums, artists, playlists, folders, equalizer)

### Playback Modes Overhaul

- `AdvanceListOrder` enum (album, artist, folder, playlist) with per-category icons
- `ShuffleMode` categories (off, all, within context)
- `PlaybackContext` model for source tracking
- A-B repeat mode
- New loop modes: off, track, context, all
- Long-press shuffle/loop opens mode-selection bottom sheets with Snackbar feedback
- Modes restored when loading last played song

### Experimental 432 Hz Tuning

- A4=432 Hz via Rust FFI with audio engine integration
- Toggle in Settings → Audio → UAC2 with confirmation dialog
- Preference persisted across sessions
- Cache initialized with `AudioSessionManager`
- Integrated with bit-perfect mode defaults

### Bass / Mid / Treble Tone Controls

- Bass, mid, treble tone offsets layered on the 31-band EQ
- BMT fields on `EqPreset` for import/export
- Affects EQ graph rendering, hit detection, and parametric curve builder
- Smooth animated `RotaryKnob` transitions
- Reusable `AnimatedSlider` widget extracted

### Opus Audio Codec

- Vendored opus-sys with full Opus 1.x source (CELT + SILK)
- Multi-arch optimizations: SSE4.1, ARM NEON, ARM EDSP, MIPSr1
- Rust decoder bindings in the audio pipeline
- OGG extension hints normalized; `.opus` routing
- Training scripts, fuzzers, unit tests for SILK and CELT

### Recently Played Redesign

- Paginated loading for large histories
- Smart date grouping (Today, Yesterday, This Week, older months)
- Reactive song info in bottom sheet actions

### Developer Mode & Logging

- Developer mode toggle via JNI in `MainActivity`
- `devLog` replaces `debugPrint` across all Dart services
- `dev_eprintln!` replaces `eprintln!` in Rust
- Zero-cost when disabled

### Vinyl Record & Animations

- Shared `VinylRecord` widget with custom-painted disc
- Album art scope toggle (single song vs whole album)
- Vinyl mode state tracking per-player
- Waveform and line seek bar animated appearance
- Waveform layer animation nested inside consumer
- Mini-player directional slide animation

### Scanner & Library UX

- `jwalk` → `walkdir` migration
- Fullscreen scanning overlay; scan-complete summary sheet
- Pending-rescan flag for concurrent event safety
- Auto library sync on app resume

### Song Deletion & MediaStore

- `removeFromMediaStore` static method
- Song deleted from Isar repo before file removal
- MediaStore fallback in `deleteDocumentViaSaf`
- Confirmation dialog before deletion

### USB Audio Improvements

- UAC1 sampling frequency negotiation
- USB volume falls back to bit-perfect default (-40 dB) when unsaved
- Long-press gesture handled without accidental tap
- Duck-aware audio interruption pause/resume

### Code Formatting & Polish

- Mass Rust reformatting (100-column limit, consistent structs, imports)
- Dismissible update notice with slide-fade animation
- `FolderEntity` cached via `FutureBuilder`
- Album art bitmap cache
- NaN guards on non-finite scale/opacity values
- Auto-focus search preference (Settings → Interface)
- Volume button in player action buttons
- Equalizer init/reapply on app start and audio session changes

## Files Changed

| Area | Key Paths |
| --- | --- |
| ListenBrainz | `lib/services/listenbrainz/`, `lib/models/listenbrainz/`, `lib/providers/providers.dart` |
| Floating Player | `lib/services/floating_player_service.dart`, `lib/widgets/floating_mini_player.dart`, `android/.../MainActivity.java` |
| Playback Modes | `lib/models/playback_context.dart`, `lib/models/advance_list_order.dart`, `lib/providers/player_provider.dart` |
| 432 Hz Tuning | `rust/src/audio/engine.rs`, `lib/features/settings/screens/uac2_preferences_screen.dart`, `lib/providers/` |
| BMT EQ | `rust/src/audio/equalizer.rs`, `lib/features/settings/equalizer_screen.dart`, `lib/models/eq_preset.dart` |
| Opus | `rust/vendor/opus-sys/`, `rust/src/audio/opus_decoder.rs` |
| Recently Played | `lib/features/recap/screens/recently_played_screen.dart`, `lib/providers/` |
| Dev Mode | `lib/core/utils/dev_log.dart`, `rust/src/audio/android_direct_usb.rs`, `android/.../MainActivity.java` |
| Vinyl Record | `lib/widgets/vinyl_record.dart`, `lib/features/player/widgets/vinyl_disc_painter.dart` |
| Scanner | `rust/src/api/scanner.rs`, `lib/services/library_scanner_service.dart` |
| Song Deletion | `lib/services/media_store_service.dart`, `lib/services/song_service.dart` |
| USB Audio | `rust/src/uac1/`, `rust/src/uac2/` |
| Formatting | `rust/src/audio/`, `rust/src/uac2/` |

## Upgrading

1. ListenBrainz scrobbling requires a token from listenbrainz.org — enter it under Settings → Integrations
2. The floating player requires SYSTEM_ALERT_WINDOW permission on first launch — grant from Settings → Apps → Flick → Overlay
3. "Keep Playing on Quit" is off by default — enable from Settings → Playback if you want background audio after app exit
4. Long-press shuffle/loop buttons to access the new mode-selection bottom sheets
5. 432 Hz tuning is experimental — enable from Settings → Audio → UAC2 with the confirmation dialog
6. Opus file support requires no configuration — `.opus` files are detected and decoded automatically
7. Developer mode is off by default — enable from developer options to see verbose logs
8. Previously scanned folders will use walkdir automatically on next scan — no user action required
