# Flick 0.21.0-beta.1

A major release, shipped while continuously keeping up with improvements and bug fixing across the app.

## Network Sources & Casting

- Stream from self-hosted servers: **Subsonic, Jellyfin/Emby, UPnP/DLNA, WebDAV, Tidal, and SMB2/3**
- HTTP-first streaming with seek, gapless prefetch, and LRU download caching
- Subsonic playlist sync — mirror playlists to/from your server
- Cast to **DLNA renderers and Chromecast**; Cast SDK optional for GMS-free devices
- Server management with validation, failure banners, token error handling, password toggle

## Extended Volume (up to 200%)

- Volume boost via LoudnessEnhancer with toggle in Audio settings
- Volume preserved across engine recreation; slider reflects boost range
- Volume authority refactor — `isHardwareVolumeAuthority` routing

## Parametric EQ & Audio

- Graphic EQ → **parametric EQ**: variable band types with RBJ coefficients, animated band add/remove
- EQ survives engine recreation; reapplies on session changes; bypassed on bit-perfect output
- Bit-perfect passthrough API — software gain removed from path
- Autoplay on queue end (optional); stuttering HAL path skipped when bit-perfect off
- Earpiece excluded from auto device selection; wake lock prevents sleep dropouts

## USB DAC Fixes

- Fosi Audio DS2 quirk (broken clock), 0 Hz readback fix, SkipClockValidation
- UAC1 SET_CUR failures tolerated on host-driven clock endpoints
- Sample-rate guards: no DAC-stored-rate overwrites or divide-by-zero

## Bluetooth

- Hi-Res Direct no longer forces the `dapInternalHighRes` engine on BT routes — fixes volume loss (~35-40% cap) and 5-10s dropouts over A2DP
- Output-mode toggles (Hi-Res Direct, Low-latency) survive app restarts
- Flags cached at startup; refined codec selection; priority anchor keeps background playback alive

## Player & UI

- Configurable action buttons: center, top-left/right, bottom — any slot hideable
- Separate mini player from nav bar (toggle in settings)
- Compact layout for very short screens; resizable activity

## Library & Artwork

- Remove All Songs option; songs deleted when their folder is removed
- Artwork survives cache prune and persists after scans
- Corrupt cached images auto-recover; extraction freeze on rapid scroll fixed

## Reliability

- Auto-resume after interruptions; pending seek cleared after completion
- Persistent WAV cache across restarts; HTTP audio source timeout
- Network sync hardening: entity IDs resolved before bulk insert, Jellyfin fetches all audio tracks

## Getting Started

1. Network sources: Settings → Network Sources → Add Server
2. Casting: Settings → Casting, or the cast button in the player
3. Volume boost: Settings → Audio → Extended Volume
4. Player buttons: Settings → Player → Layout
