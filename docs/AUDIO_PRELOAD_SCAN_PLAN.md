# Audio Preload Scan — Phased Plan

A new optional scan mode that, after the normal library scan discovers files,
**preloads cover art + missing sparse metadata** and **decodes each song once
to cache waveform peaks and audio-analysis metrics** (LUFS, true peak, DR, LRA,
clipping). No PCM is retained — everything is computed in a single streaming
decode pass and stored as small per-song summaries.

Scope: the scanner (`lib/services/library_scanner_service.dart`,
`rust/src/api/scanner.rs`), a new Rust analysis bridge, a new Isar cache entity,
and small additions to Library Settings + the waveform seek bar consumer.

**Ponytail policy**: one streaming decode pass per song, hand-rolled BS.1770
loudness (no new crates), waveform peaks as ~240 floats, metrics as a handful
of scalars. Peaks + metrics live in a sibling Isar entity (not columns on the
hot `songs` row). Cover art reuses the existing `albumArtPath` flow verbatim.
No PCM cache, no per-format decoder duplication.

---

## A. What "audio preload" means here

| Component | Already done by existing scan | Added by this mode |
|-----------|-------------------------------|--------------------|
| Text tags (title/artist/album/track/disc) | yes | — |
| Technical fields (duration/bitrate/sample rate/bit depth) | yes (Rust deep scan); sparse backfill for MediaStore/SAF | sparse backfill runs **inline** instead of detached |
| Cover art | no — `extract_embedded_artwork` is on-demand only | **preloaded**, written to app docs dir, path stored on `albumArtPath` |
| Waveform peaks | no — seek bar uses synthetic `Random(duration)` data | **cached** (~240 buckets/song) |
| Loudness / dynamics analysis | no | **computed once** (LUFS, true peak, DR, LRA, clipping) |
| PCM retention | n/a | **never** — peaks + scalars only |

---

## B. Trigger model and scope (decisions)

- **Trigger**: both a **toggle in Library Settings** ("Preload audio data",
  stored on `LibraryScanPreferences`) **and** a **one-off manual action**
  ("Preload library audio") beside the existing "Rescan Library" entry in
  `library_settings_screen.dart:1140`.
- **Default scope**: only new/modified songs (skip when
  `song.lastModified <= cache.computedAt`). Cheap incremental scans.
- **Override**: the manual action exposes a **"Reprocess all" checkbox** that
  forces `forceAll: true` (ignores `computedAt`, rebuilds the whole library
  cache). Used to bump `version` after an algorithm change too.
- **Toggle semantics**: when on, every normal scan fires the preload pass as a
  detached task at the end of `_scanFolderRust` / `_scanFolderMediaStore` /
  `_scanFolderAndroid` (same `_runDetachedScanTask` pattern already used for
  sparse-metadata and playlist sync).

---

## C. Storage decision

A new Isar entity `SongAudioCacheEntity` 1:1 with `SongEntity`:

| Field | Type | Why |
|-------|------|-----|
| `songId` (PK, indexed) | Id | lookup by song; cascade-delete when the song goes |
| `peaks` | `List<double>` (~240) | waveform seek bar; ~2 KB/song |
| `lufs` | `double?` | integrated loudness, BS.1770 |
| `truePeakDb` | `double?` | dBTP |
| `dr` | `double?` | TT Dynamic Range (off-line) |
| `lra` | `double?` | Loudness Range |
| `clipping` | `bool` | samples pinned at ±1.0 |
| `version` | `int` | bump = force global recompute via the override |
| `computedAt` | `int` (ms since epoch) | skip-or-reprocess gate vs `song.lastModified` |

**Why a sibling table, not columns on `songs`**: Isar loads entire objects, so
keeping rarely-accessed blobs off the hot row keeps song lists fast. A cache
truncate (`isar.songAudioCacheEntitys.clear()`) becomes a one-liner that
doesn't touch metadata; schema migrations stay isolated; "reprocess all" is a
single collection wipe + walk.

**Cover art** stays on the existing `SongEntity.albumArtPath` field. Bytes are
written to `getApplicationDocumentsDirectory()/album_art/<songId>.<ext>` — the
same pattern already used by `album_art_service.dart:101` and
`album_art_import_service.dart:616`. Reuses
`SongRepository.updateAlbumArtPath` (`song_repository.dart:183`) unchanged.

---

## D. Rust analysis bridge (new file `rust/src/api/audio_analysis.rs`)

One streaming function, one pass per file, no PCM retained:

```rust
pub struct AudioAnalysisResult {
    pub peaks: Vec<f32>,            // length = peak_buckets, normalised 0.0..=1.0
    pub lufs: Option<f64>,          // integrated, BS.1770
    pub true_peak_db: Option<f64>,  // dBTP
    pub dr: Option<f64>,            // TT DR
    pub lra: Option<f64>,           // loudness range
    pub clipping: bool,
}

pub fn analyze_audio_file(path: String, peak_buckets: u32) -> Option<AudioAnalysisResult>
```

### Decoder reuse

| Format | Existing decoder to reuse |
|--------|---------------------------|
| MP3/FLAC/OGG/Opus/AIFF/WAV/ALAC/M4A | **Symphonia** (already a dep; probed in `audio_api.rs:878-893`) |
| DSF | `dsf_meta::DsfFile` (already used in `scanner.rs:434`) |
| DFF | `dff_meta::DffFile` (already used in `scanner.rs:479`) |
| WavPack | existing wavpack thread (`rust/src/audio/wavpack_thread.rs`) |

For DSD formats the analysis pass downsamples the 1-bit stream to PCM at
~176.4 kHz on the fly (existing DSD pipeline does this for playback). No new
codec code.

### Single-pass computation

The loop over decoded sample blocks maintains, in O(1) memory beyond the
bucket arrays:

- **Peaks**: per bucket, track `min` and `max` (or RMS — TBD in Phase 2). At
  the end, normalise each bucket to `0.0..=1.0` against the global max. Bucket
  boundaries are sample-count based, independent of decoder rate.
- **LUFS / LRA**: ITU-R BS.1770 — K-weighting biquad (shelf + high-pass),
  400 ms blocks with 75 % overlap, absolute-gating at −70 LUFS, relative gate
  at −10 LU below the gated mean. ~150 LOC of stdlib math, no crate.
- **True peak**: oversample ×4 via a simple sinc interpolation and take the
  max; cheap approximation of dBTP (good enough for a metrics badge, not for
  mastering).
- **DR**: sliding-block (3 s) peak-to-RMS ratio, classify into DR bands.
- **Clipping**: count samples at `|s| >= 0.9999`.

### Bridge plumbing

Register in `rust/src/api/mod.rs`, regenerate FRB
(`flutter_rust_bridge_codegen generate`). The generated Dart binding lands in
`lib/src/rust/api/audio_analysis.dart`.

---

## E. Confirmed gaps (what does not exist yet)

| # | Gap | Severity | Location |
|---|-----|----------|----------|
| G1 | No offline audio decode-then-discard path; only realtime playback decoders exist. | High | new file `rust/src/api/audio_analysis.rs` |
| G2 | No BS.1770 / DR / true-peak / LRA / clipping implementation. | High | new file `rust/src/api/audio_analysis.rs` |
| G3 | No `SongAudioCacheEntity` Isar collection. | High | new file `lib/data/entities/song_audio_cache_entity.dart` + repo methods in `song_repository.dart` |
| G4 | No `AudioPreloadService` (orchestrates decode + art + cache upsert, throttle, cancel). | High | new file `lib/services/audio_preload_service.dart` |
| G5 | Scanner does not spawn the preload pass after a scan. | High | `library_scanner_service.dart` (after each `_scanFolder*`) |
| G6 | No `preloadAudioData` toggle on `LibraryScanPreferences`. | Medium | `library_scan_preferences_service.dart:6-87` |
| G7 | No Library Settings toggle row + no manual action sheet. | Medium | `library_settings_screen.dart:810, 1140` |
| G8 | Waveform seek bar still renders synthetic `Random(duration)` data. | Medium | `waveform_seek_bar.dart:33, 58-65` |
| G9 | Sparse-metadata backfill is detached-only; not reusable inline from the preload pass. | Low | `library_scanner_service.dart:486` (`_extractSparseMetadataInBackground`) |

---

## F. Phases

### Phase 1 — Storage + bridge skeleton

| Task | Gap | Change |
|------|-----|--------|
| P1.1 | G3 | New `lib/data/entities/song_audio_cache_entity.dart` (Isar `@collection`), register in `database.dart`. Add `getBySongId`, `upsert`, `clearAll`, `deleteBySongIds` to a small `SongAudioCacheRepository` (or fold into `SongRepository`). |
| P1.2 | G1 | New `rust/src/api/audio_analysis.rs` with `analyze_audio_file(path, peak_buckets)` returning **peaks only** (`lufs`/`dr`/etc. left `None`). Symphonia path for standard formats; DSD/WavPack return `None` for now (graceful skip). |
| P1.3 | G1 | Register the module in `rust/src/api/mod.rs`, run `flutter_rust_bridge_codegen generate`. |
| P1.4 | G4 | New `lib/services/audio_preload_service.dart` with `Stream<PreloadProgress> preloadSongs(List<SongEntity>, {bool forceAll})`. Concurrency cap = 2, honours `cancel()`, skips when cache fresh unless `forceAll`. End-to-end on one test file at this stage. |

### Phase 2 — Analysis metrics

| Task | Gap | Change |
|------|-----|--------|
| P2.1 | G2 | Implement K-weighting biquad + 400 ms/75 % overlap gated block integration (BS.1770) → `lufs`. |
| P2.2 | G2 | Implement LRA (same gated blocks, stats over block loudness). |
| P2.3 | G2 | Implement true peak (×4 sinc oversample, max). |
| P2.4 | G2 | Implement DR (3 s sliding window peak/RMS). |
| P2.5 | G2 | Implement clipping flag (`|s| >= 0.9999` count > threshold). |
| P2.6 | G1 | Wire DSD (DSF/DFF) and WavPack through the same streaming loop; metrics populated for those formats too. |

### Phase 3 — Scanner integration

| Task | Gap | Change |
|------|-----|--------|
| P3.1 | G9 | Refactor the sparse-metadata chunk fetch out of `_extractSparseMetadataInBackground` so it's callable from `AudioPreloadService` (no behaviour change to current call sites). |
| P3.2 | G5 | After each `_scanFolder*` completes, if `scanPreferences.preloadAudioData == true`, spawn `AudioPreloadService.preloadSongs(newlyAddedSongs)` via `_runDetachedScanTask`. Forward `_isCancelled`. |
| P3.3 | G5 | Pass `forceAll: true` only from the manual "Reprocess all" path; default path passes `forceAll: false`. |
| P3.4 | G5 | Wire cover-art preload: per song, `extractEmbeddedArtwork(path)` → write to `album_art/<songId>.<ext>` → `SongRepository.updateAlbumArtPath`. Skip silently if no embedded art. |

### Phase 4 — UI

| Task | Gap | Change |
|------|-----|--------|
| P4.1 | G6 | Add `preloadAudioData: bool` (default `false`) to `LibraryScanPreferences` + `copyWith` + `setPreloadAudioData` (`library_scan_preferences_service.dart`). |
| P4.2 | G7 | New toggle row "Preload audio data" beside "Deep scan" (`library_settings_screen.dart:810`), same styling. |
| P4.3 | G7 | New menu action "Preload library audio" beside "Rescan Library" (`library_settings_screen.dart:1140`). Opens a sheet with a "Reprocess all" checkbox and an estimate (song count × ~real-time). |
| P4.4 | G7 | Surface preload progress via the existing `_scanProgressNotifier`/`ScanProgress` plumbing; add a `phase` field (`scanning` vs `preloading`) so the UI can label "Preloading… N / M". |

### Phase 5 — Waveform consumer

| Task | Gap | Change |
|------|-----|--------|
| P5.1 | G8 | In `waveform_seek_bar.dart`, replace `_generateWaveform()` with a lookup: read `SongAudioCacheEntity.peaks` for the current song, interpolate to `widget.barCount`. |
| P5.2 | G8 | Fall back to the existing synthetic `Random(duration)` data only when no cache row exists. No flicker: resolve async, keep synthetic shape until the cached peaks arrive. |

### Phase 6 — Self-checks (ponytail: one runnable check per non-trivial unit)

| Task | Change |
|------|--------|
| P6.1 | Rust `#[test]`: synthesise a 1 kHz sine at known RMS, assert `peaks.len() == peak_buckets` and `lufs` within ±1 LU of the analytic value. |
| P6.2 | Rust `#[test]`: a full-scale square wave asserts `clipping == true` and `true_peak_db ≈ 0.0`. |
| P6.3 | Dart unit test for `AudioPreloadService`: cache-fresh song is skipped; `forceAll: true` re-processes it. |

---

## G. Risks & open questions

- **Cost on large libraries.** 1 000 songs × ~real-time decode is many hours
  single-threaded. Concurrency cap of 2 + the "new songs only" default keeps
  incremental scans cheap. The manual action shows an estimate before starting.
  Acceptable as v1.
- **DSD decode cost.** DSF/DFF files are large and decode roughly at real time.
  Phase 2 includes them in the metrics pass; if it proves too slow in practice,
  the fallback is **peaks only for DSD** (still useful for the seek bar) with
  metrics left `None`. Decide after Phase 2 benchmarking.
- **Android SAF-only folders** (removable storage, no Rust path access). Fall
  back to MediaMetadataRetriever-only metadata + skip peaks/art for those
  files (art is still extractable via SAF if we add a separate code path
  later). The preload service treats unreachable paths as a silent skip.
- **LUFS implementation.** Hand-rolled BS.1770 keeps the dependency list flat
  (~150 LOC, stdlib math only). Switch to a crate only if accuracy becomes a
  problem in practice.
- **Peak bucket resolution.** ~240 chosen to sit above the seek bar's current
  `_cachedSampleCount = 180` (`waveform_seek_bar.dart:33`) with headroom for
  pinch-zoom. Adjustable in one constant if zoom needs more.
