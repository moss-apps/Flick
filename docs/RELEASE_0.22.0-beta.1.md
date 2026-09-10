# Flick 0.22.0-beta.1

## DSD Native Playback

- **DSD-NATIVE output** via SAS offload shim (HiBy devices) with ALSA direct fallback
- DoP packer bit-reversal; short reads handled; wire silence padding fixes audio pops
- DSD wire format and grouping settings in UAC2 preferences; restored output mode and transport overrides
- DSD reconciliation finds unindexed DSD files; decoder crash dumps captured offline

## ReplayGain & Crossfeed

- **ReplayGain** Track/Album modes with pre-amp and clipping prevention
- Scanner analyzes loudness (EBU R128 / BS.1770), writes `REPLAYGAIN_*` tags, and updates the library
- **BS2B crossfeed** with Default/strong/gentle presets; persists across engine recreation; bypassed on bit-perfect

## Karaoke Lyrics

- Word-level **karaoke sync** with gradient sweep and a toggle in lyrics settings
- Full-screen **Lyrics Sync Studio**: tap-along word stamping, enhanced LRC export, video-style word timeline, syllable splitting
- Lyrics from **MP4/M4A and OGG/Opus** containers; text alignment options and readability scrim

## Global Search

- Unified search across songs, albums, artists, and playlists
- Filter chips with persisted selection; refined search screen

## Library Scanning & Permissions

- Optional **Full Library Access** — Rust scanner walks every volume directly; falls back to MediaStore/SAF
- **DSD/DSF/WavPack always scanned**, even on devices whose media indexer skips them (Xiaomi/MIUI, Vivo, Honor)
- **WavPack/DSD tags & album art everywhere** via Rust parser fallback; fixed DFF/WavPack embedded covers
- **Fixed library wipe when switching scan engines** — each engine only deletes rows it can see
- Floating minimizable scan progress pill; preload runs as one cancellable pass with a Stop button

## Engine Recovery & Accuracy

- Rust engine **crash recovery** — revives on dead channels with panic reporting
- Lying container headers detected and corrected; implausible sample rates filtered

## Navigation & UI Refresh

- Nested navigators per tab; full player and queue routed via root navigator
- New **FlickDialog** system and **FlickArtworkPlaceholder** across the app
- Shared detail headers with glass blur back buttons; landscape mode support
- System **reduced-motion** preference respected globally

## USB & Bluetooth

- Bit-perfect **auto-prompt on DAC attach**, with per-device decline memory
- UAC1: refuses direct USB when SET_CUR fails; better sampling-frequency negotiation
- USB route monitoring at boot; Hi-Res Direct for the Bluetooth Rust Oboe path

## Network Sources

- Jellyfin **silent re-auth** via secure password store; auth failure detection
- Tidal sign-in fix with persisted session token

## Player & Library

- Rebuilt full player with song stage carousel; swipe-down previous-track gesture
- Metadata editor moved to a bottom sheet with instant sync
- Playlist sorting; bulk favorites; duplicate cleaner with per-group multi-keep
- Folder tree view toggle; EQ knobs double-tap to reset

## Getting Started

1. ReplayGain: Settings → Library → Scan Settings → ReplayGain scan
2. Crossfeed: Settings → Audio → Headphone Crossfeed
3. Karaoke: Lyrics settings → Word Sync toggle, then edit in the Sync Studio
4. Full Library Access: Settings → Library → Scan Settings
