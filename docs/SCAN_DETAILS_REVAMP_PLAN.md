# Scan Details Revamp Plan

Status: **Planned** (not yet implemented)
Last updated: 2026-07-20

## Goal

Revamp the library scanning UI to expose the full scan session, not just songs-found count and current filename. Today the service computes/knows a lot that the UI never surfaces (scan engine, phase, new/modified/deleted deltas, elapsed time, folder progress, background-task state, removable-storage unavailability). This plan widens the `ScanProgress` model and redesigns both the live overlay and the post-scan summary around it.

## Files touched

Only two files change:

- `lib/services/library_scanner_service.dart` — extend `ScanProgress`; instrument every yield
- `lib/features/settings/screens/library_settings_screen.dart` — full redesign of overlay + complete sheet; add elapsed timer

No Rust changes. No new dependencies.

## Decisions (locked)

| Question | Decision |
|---|---|
| Which details to surface | All: elapsed + rate, progress %, phase, engine, new/modified/deleted, background status, folder progress |
| Scope | Full redesign of overlay AND complete sheet |
| Data plumbing | Extend `ScanProgress`; service populates new fields |
| Background tasks | Overlay stays open until foreground AND detached tasks all finish; phase row shows "Finishing metadata enrichment…" |
| Removable unavailable | Dedicated "USB storage not connected" state in the redesigned overlay |
| Progress visual | Both — circular ring around the vinyl AND a linear bar |

---

## Phase 1 — Extend `ScanProgress`

Location: `lib/services/library_scanner_service.dart:18-35`.

Add fields with defaults so existing call sites still compile:

```dart
class ScanProgress {
  final int songsFound;
  final int totalFiles;
  final int filesProcessed;           // NEW — for progress bar (processed/total)
  final String? currentFile;
  final String? currentFolder;
  final String? phase;                // NEW — 'Reading metadata', etc.
  final String? scanEngine;           // NEW — 'Rust deep scan' | 'MediaStore' | 'SAF' | 'SAF (instant)'
  final int newSongs;                 // NEW
  final int modifiedSongs;            // NEW
  final int deletedSongs;             // NEW
  final int? foldersTotal;            // NEW — scan-all only
  final int? foldersCompleted;        // NEW — scan-all only
  final bool backgroundTasksRunning;  // NEW — foreground done, detached still finishing
  final bool isComplete;
  final bool unavailable;
}
```

Defaults: numeric fields `0`, `backgroundTasksRunning false`, optionals `null`.

---

## Phase 2 — Service emits richer progress

### 2a. `_ScanAccumulator` helper

Avoid repeating the field list at every yield. Mutable holder the per-path methods write into; a single `toProgress({...overrides})` builds the immutable `ScanProgress`. Fields: `songsFound`, `totalFiles`, `filesProcessed`, `newSongs`, `modifiedSongs`, `deletedSongs`, plus `currentFolder`, `scanEngine`, `phase` set at method entry.

### 2b. Per-path instrumentation

Each scan path already has the data locally — surface it:

| Path | `scanEngine` | Where counters already live |
|---|---|---|
| `_scanFolderRust` (`:1241`) | `'Rust deep scan'` | `processed` at `:1298` / `:1409`; existing/missing in `existingMap` / `idsToDelete` |
| `_scanFolderMediaStore` (`:231`) | `'MediaStore'` | no incremental — batch builds, jump 0→total (accurate); new/modified from `existing != null` check at `:331` |
| `_scanFolderAndroid` (`:877`) | `'SAF'` | `processed` at `:1210`; `existingMap` lookups |
| `_scanFolderAndroidInstant` (`:691`) | `'SAF (instant)'` | single yield at `:742`; deltas computed from `newBatch.length` + post-pass deletions |

`phase` string emitted before each major step. Canonical labels:
`'Querying filesystem'`, `'Loading existing entries'`, `'Diffing'`, `'Reading metadata'`, `'Parsing CUE/log'`, `'Upserting songs'`, `'Syncing playlists'`, `'Syncing fingerprints'`, `'Finalizing'`.

`newSongs`/`modifiedSongs`/`deletedSongs` accumulators: per batch, `existing == null` → new, else modified; deleted from `idsToDelete.length` / `urisToDelete.length` / `chunk.deletedPaths.length`.

`filesProcessed`: reuse existing `processed` counters. MediaStore/instant paths jump 0→total (accurate — they batch).

### 2c. Detached-task tracking

Today `_runDetachedScanTask` (`:1902`) is fire-and-forget. Change to:

- Keep a `List<Future<void>> _detachedTasks` on the service instance (or per-scan accumulator).
- `_runDetachedScanTask` appends its wrapped future to the list.
- After the foreground scan loop ends, yield `ScanProgress(isComplete: false, backgroundTasksRunning: true, phase: 'Finishing metadata enrichment', filesProcessed: totalFiles)` (ring/bar pin at 100%).
- `await Future.wait(_detachedTasks)`, then clear the list, then yield the final `isComplete: true`.
- Cancel still works — `_isCancelled` already gates the detached loops.

This is the only behavior change users will notice: the overlay stays open until enrichment/playlist/fingerprint work drains, instead of closing the instant foreground finishes.

### 2d. `scanAllFolders` folder counting

Location: `:1617`. The wrapper knows `scanPlan.length` and tracks `completed` (`:1648`). Emit `foldersTotal: scanPlan.length` and `foldersCompleted: completed` on every progress forwarded through the controller.

---

## Phase 3 — Elapsed/rate timer (UI state)

Location: `_LibrarySettingsScreenState` in `library_settings_screen.dart`.

- Add `Timer? _elapsedTimer` and `final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier(Duration.zero)`.
- On scan start (alongside `_scanStopwatch.reset()`): start a `Timer.periodic(Duration(milliseconds: 200), (_) => _elapsedNotifier.value = _scanStopwatch.elapsed)`.
- On scan end / dispose: cancel timer.
- Rate is derived in the builder, not stored: `songsFound / max(elapsed.inSeconds, 1)`.
- The overlay's root listens to both `_scanProgressNotifier` and `_elapsedNotifier` via `Listenable.merge`.

---

## Phase 4 — Redesign scanning overlay

Replace `_showScanningOverlay` (`:391-570`). Full-screen glass dashboard.

```
┌─────────────────────────────┐
│                             │
│        ┌─────────┐          │
│        │ vinyl   │  120px, circular progress ring around it
│        │  42%    │          │
│        └─────────┘          │
│                             │
│        Music Library        │  folder name (18, semibold)
│      ● Reading metadata     │  phase (accent, pulsing dot)
│                             │
│  ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░  │  linear progress bar
│      210 / 500 files        │
│                             │
│  ┌──────┬──────┬──────┐     │
│  │ 142  │  68  │  12  │     │  new / modified / deleted
│  │ New  │ Mod  │ Del  │     │
│  └──────┴──────┴──────┘     │
│                             │
│  ┌──────┬──────┬──────┐     │
│  │ 1:23 │ 42/s │ Rust │     │  elapsed / rate / engine chip
│  │Time  │Rate  │ Deep │     │
│  └──────┴──────┴──────┘     │
│                             │
│    Folder 2 of 5            │  only when foldersTotal != null
│                             │
│       [ Cancel ]            │
└─────────────────────────────┘
```

### Building blocks

- **Progress ring around vinyl**: `CustomPainter` drawing an arc from `filesProcessed / totalFiles`. Indeterminate sweep when `totalFiles == 0`. Vinyl stays at 120px (down from 180) to leave room.
- **Linear bar**: standard `LinearProgressIndicator` with the same fraction; `"$filesProcessed / $totalFiles files"` below.
- **Phase row**: accent dot (small, pulsing via `AnimationController` reuse of `_vinylController` or a new 1s repeat) + `phase` text. Falls back to `'Initializing…'` when null.
- **3-up New/Mod/Del grid**: reuse `_buildScanStat` (extract a compact variant if needed). Icons: `LucideIcons.plus`, `LucideIcons.refreshCw`, `LucideIcons.trash2`.
- **3-up Time/Rate/Engine grid**: elapsed (`m:ss`), rate (`$N/s`), engine chip (`LucideIcons.cpu`). Engine chip is a pill, hidden when `scanEngine == null`.
- **Folder progress**: single centered line `"Folder $foldersCompleted of $foldersTotal"`, rendered only when `foldersTotal != null && foldersTotal > 1`.
- **Cancel button**: keep current behavior (`_scannerService.cancelScan()` + close).

### State variants

1. **Normal scanning**: dashboard above.
2. **Background tasks running** (`backgroundTasksRunning == true`): same dashboard, ring + bar at 100%, phase row swaps to `"Finishing metadata enrichment…"` with a small spinner instead of the pulsing dot. New/Mod/Del counts hold at final values.
3. **Removable unavailable** (`progress.unavailable == true`): replace the dashboard with a centered state — `LucideIcons.usb` (or `unplug`), `"USB storage not connected"`, subtitle `"$currentFolder is offline — retained songs still listed"`, single **Done** button (not Cancel). Available immediately because the service already yields `unavailable: true` at `:133-140` for unmounted removable storage.

### Glass/styling

Keep existing `BackdropFilter` + `AppColors.glassBackground`/`glassBorder` treatment; reuse `AppConstants.spacing*` and `radius*`. The existing drag handle and bottom-sheet framing go away (full-screen now).

---

## Phase 5 — Redesign scan-complete sheet

Replace `_showScanCompleteBottomSheet` (`:572-652`). Pass the final `ScanProgress` + stopwatch into it.

Layout:

```
        ✓  (LucideIcons.circleCheck, accent, 48)

   ┌──────┬──────┬──────┐
   │ 142  │  68  │  12  │     New / Modified / Deleted
   │ New  │ Mod  │ Del  │
   └──────┴──────┴──────┘

   ┌──────┬──────┬──────┐
   │ 4210 │ 1:23 │ 34/s │     Total songs / Time / Avg rate
   │ Tot  │ Time │ Rate │
   └──────┴──────┴──────┘

   [ Rust deep scan · 5 folders ]   engine chip + folder count (scan-all only)

            [ Done ]
```

- Drop the old 1×2 `_buildScanStat` row.
- New/Mod/Del come straight from the final `ScanProgress`; Total from `progress.songsFound`; Time from stopwatch; Rate derived.
- Engine chip + folder count line only renders when `scanEngine != null` / `foldersTotal != null`.
- Keep `GlassBottomSheet.show`, `isDismissible`, `enableDrag`, `maxHeightRatio` pattern.

---

## Phase 6 — Verify

- `flutter analyze lib/services/library_scanner_service.dart lib/features/settings/screens/library_settings_screen.dart`
- Confirm scanner tests still compile: `dart test test/` if anything references `ScanProgress` (none currently do — service tests don't construct it — but re-check at impl time).
- Manual smoke: scan one folder (Rust path on desktop), scan one folder on Android (MediaStore + SAF), rescan all folders, unmount removable storage and scan.

---

## Out of scope

- Per-file ETA (rate is shown, but not "X seconds remaining" — files have wildly variable metadata cost; ETA would be misleading).
- Persisting scan history to DB. Today scans are ephemeral; this plan keeps that.
- Notification/channel updates during scan (separate surface).
- Changing the detached task set itself (sparse metadata, sidecar, playlist sync, fingerprint sync all stay as-is).
