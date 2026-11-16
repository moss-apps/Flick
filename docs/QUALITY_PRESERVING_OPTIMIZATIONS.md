# Quality-Preserving Optimizations

**Status:** Proposed, based on a source review—not benchmarked or implemented.

## Goal

Reduce unnecessary CPU work, database reads, and storage writes without changing
audio output or making the app harder to use. These are lower-risk changes, not
a guarantee against bugs.

## First priorities

| Optimization | Benefit | Preserve |
|---|---|---|
| Use indexed database lookups instead of scanning records. | Faster metadata and artwork updates. | Correct record selection, CUE tracks, and user edits. |
| Reuse library and search data until it changes. | Fewer reloads and allocations. | Search matches, counts, ordering, and fresh results after scans, edits, or deletions. |
| Remove redundant sorting and cache normalized sort keys. | Faster large-library browsing. | Existing case-insensitive ordering and tie-breaking. |
| Restore playback using saved song IDs instead of loading the entire library. | Faster restoration. | Playlist order, duplicates, missing-song handling, position, and paused restoration. |
| Save unchanged playlist data only when needed. | Less serialization and storage activity. | Current position checkpoints, prompt saves when the playlist changes, and consistent restoration after interruption. |

These changes do not require modifying decoded samples, DSP, or audio transport.
Caches must be invalidated correctly and kept within a reasonable memory budget.

## Separate follow-ups

- **Background analysis cancellation:** stop native analysis work too, without
  interrupting playback or saving incomplete results as valid.
- **Staged startup:** show a usable screen sooner while preserving locale,
  external-file opening, and restored playback behavior.
- **Library notification batching:** reduce repeated work without introducing
  noticeable delays or losing the final update.

## Keep audio-engine changes separate

Audio-thread locking, FFT convolution, playback buffers, USB scheduling, and
thread priorities need a separate plan and hardware verification.

Do not trade quality for speed: no silent resampling, bit-depth reduction,
reduced DSP precision, shortened impulse responses, lower-quality artwork, or
removed features. Preserve bit-perfect PCM, native DSD, DoP, and DAC wire formats.

## Acceptance criteria

- Change one optimization at a time and add regression tests for its safeguards.
- Compare relevant before/after timings, reload counts, allocations, and writes;
  check memory use as well as speed.
- Keep search, library updates, and playback restoration behavior unchanged.
- Verify playback reliability on user-tested hardware; distinguish those results
  from local automated checks.

Related: [Front-end battery optimizations](FRONTEND_BATTERY_OPTIMIZATIONS.md).
