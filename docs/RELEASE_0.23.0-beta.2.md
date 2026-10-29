# Flick 0.23.0-beta.2

Taglish, settings search, and playlist covers — plus offline album completeness, per-DAC USB volume memory, and CUE-aware playback.

## Localization

- **Taglish replaces the experimental Baybayin pilot** — the language picker now offers a full Tagalog + English interface (draft copy pending native-speaker review), with daily rotating home greetings and streak messages, translated onboarding and help, and an optional **Baybayin labels** switch that renders curated headings, browse shortcuts, and navigation labels in script.
- Settings, Flick Replay, audio-engine surfaces, the fixed-volume notice, and full-player action sheets stay English in Taglish; existing `tl-Tglg` selections migrate to Taglish with labels enabled, while new installs default to Latin labels.
- **The in-app manual is now translated into Chinese** — all 16 sections and 172 strings resolve from the ARB catalog instead of a hardcoded English list, and searching the manual in Chinese matches translated copy.
- Closed the remaining localization gaps in Taglish surfaces and moved hardcoded English into the ARB files.

## Settings

- **Settings search** — search across page names, section titles, and setting descriptions from the Settings screen. Grouped, ranked results open the right page and scroll directly to the matched section, with a localized empty state.

## Library & Artwork

- **Offline album completeness** — albums show a tappable Complete label beside Lossless in the metadata line, known-status badges in the album grid, and missing disc/track positions on album details. Completeness is verified from embedded track/disc totals, never an online tracklist; missing or ambiguous tags stay unverified, and existing libraries backfill totals on the next scan without overwriting local edits. The Complete label opens an explanation sheet.
- **Playlist covers and rename** — set, change, or remove a custom cover from the playlist list or detail menu. The full-screen editor supports zoom-and-crop, rotate/flip, filters, and a vignette; covers appear in lists, details, and search, supply the dominant color when no collage exists, and are removed when the playlist is deleted. Playlists can also be renamed from both menus.
- **Artist portraits** — explicitly tagged artist artwork (ID3/APE picture types 7, 8, and 10) is extracted from DSF, DFF, and lofty-supported files. Local portraits are preferred, online artwork is fetched only when a file has none, and the artwork cache prunes unreferenced portraits.

## USB & DSD Audio

- **Per-DAC volume memory** — Flick remembers each USB DAC's hardware volume and restores it before playback, including when bit-perfect auto-engages. Hardware volume is applied before software gain is released, and a failed restore deactivates the direct connection instead of leaving playback at the wrong level.
- **Live volume state and clearer diagnostics** — the volume sheet and Audio Info rebuild on hardware or software volume changes, distinguish native hardware volume from the software fallback, and surface hardware volume errors in diagnostics. Mute-readback failures no longer discard the whole snapshot, and control-transfer errors name the interface, unit, and channel.
- **DSD playback fixes** — oversized DSF audio blocks are read in windows so large-block files play; multichannel fold-down shows an informational marker and labels the active fallback instead of appearing blocked; software decimation is capped at 176.4 kHz with precomputed FIR state, and rate mismatches fail instead of playing at the wrong pitch.
- USB isochronous transfers use a deeper queue for better host-scheduling tolerance, and explicit feedback endpoint selection now has test coverage.

## Playback

- **CUE tracks play only their own range on the Rust engine** — track bounds now reach the native decoder, and events carry a path-plus-range identity so adjacent tracks stay distinct through crossfade handoffs and durations no longer bleed into the next track. The standard Android engine clips to the same bounds.
- CUE sheets that use pregap indexes (`INDEX 00` / `INDEX 01`) now keep the first track instead of dropping it.
- Playback ranges currently apply to standard PCM files; DSD and WavPack still play the whole file.

## Interface & Polish

- **Artwork-aware detail headers** — album, artist, and smart-mix headers use a frosted control palette sampled from the cover, and the playlist back button adapts for contrast.
- **Playlist more sheet** restyled with a scrollable, sectioned layout and drag handle.
- **Album grid text scaling** — tiles measure their metadata with the active text theme and scale, so larger system fonts grow the tile instead of clipping titles.

## Builds & Flavors

- **This GitHub download uses the `full` flavor** — it declares **All Files Access** (`MANAGE_EXTERNAL_STORAGE`) for the raw Rust filesystem scanner and complete DSD/WavPack coverage. Build: `flutter build apk --flavor full --release`.
- **Google Play uses the `play` flavor** — no All Files Access (Play policy for media apps); it scans via MediaStore/SAF plus the DSD/DSF/WavPack reconciliation path. Build: `flutter build appbundle --flavor play --release`.
- Both flavors share `applicationId` `com.mossapps.flick`, so either installs over the other.

## Getting Started

1. Taglish: Settings → Language → Taglish (optional Baybayin labels appear below it)
2. Settings search: Settings → tap the search field
3. Playlist covers: open a playlist → overflow menu → Change cover; Rename sits in the same menu
4. Album completeness: open an album and tap Complete beside Lossless
5. USB volume: connect a USB DAC; its hardware volume is remembered per device
