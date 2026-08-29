# WavPack / DSD Metadata & Artwork Plan

Android's `MediaMetadataRetriever` has no WavPack decoder on any device, so `.wv`
(and OEM-skipped `.dsf`/`.dff`) rows scanned via MediaStore/SAF tiers land with no
tags, duration, or artwork. The Rust scanner already parses all three formats via
lofty/dsf-meta/dff-meta — this plan wires that power into the enrichment and
artwork paths.

| Phase | Work | Status |
|-------|------|--------|
| V1 | Rust `extract_file_metadata(path)` FRB API + Dart enrichment fallback for unsolved wv/dsf/dff rows | Done |
| V2 | `rawPathFromFileUri()` normalization at extraction + artwork sites (fixes `file://` rows) | Done |
| V3 | SAF tier: stage via `cacheUriForPlayback`, extract with Rust on staged raw path | Done |
| V4 | Album art: route wv/dsf/dff through Rust lofty (staged copy for SAF URIs) | Done |
| V5 | Tests, docs, CHANGELOG, verify builds | Done |

Also fixed while here: DSF/DFF bitrate from the Rust scanner was computed as
`size*8/1000/duration_ms` (numerically Mbit/s), storing ~1000×-too-low kbps;
now bits/s before the standard kbps normalization.

## Post-launch fix: DFF/WV covers still missing
V4 shipped two dead ends in the Rust extractors (DSF art worked, so the Dart
routing was fine):

- **WavPack**: APE-tagged covers live as binary *items* (`Cover Art (Front)`),
  which lofty never exposes via `Tag::pictures()`. `extract_lofty_artwork` now
  falls back to scanning tag items for APE picture keys (front cover first) and
  returning the raw `description\0`-stripped image bytes.
- **DFF**: `dff-meta` fails the entire `DffFile::open()` when the trailing ID3
  chunk has any parse error, and demands strict chunk ordering. Artwork now
  uses a tolerant chunk walker (`find_dff_id3_tag`) that scans top-level
  `FRM8`/`DSD ` chunks for `ID3 `, keeps partially parsed tags, and is reused
  as the text-tag fallback in `extract_dff_metadata` (sample rate/duration
  still come from dff-meta when it can open the file).

Covered by Rust tests with hand-built DFF and WavPack+APEv2 fixtures.

## Notes
- All fallbacks degrade silently: Rust failure → row keeps retriever results (or stays sparse); never blocks a scan.
- Staged files are shared with playback (`playback_staging/<md5(uri)>.<ext>`), so V3/V4 add no extra copies when a track has been played.
- Enrichment staging capped (~256 MB) to avoid copying huge DSD rips for tags alone.
- `.wvc` correction files stay excluded from all allowlists.
- Scoped-storage raw reads of non-indexed formats can EACCES on some OEMs; all-files access covers those devices.
