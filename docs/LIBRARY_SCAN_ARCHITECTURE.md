# Library Scan Architecture

## Overview

The scanner uses three tiers, prioritized by availability and performance:

1. **Android `MediaStore` Query** (primary, Android-only)
   Queries Android's `MediaStore` content provider for audio files in configured scan folders. Differential sync against the Isar database — only new/modified files trigger metadata parsing. Background metadata extraction handles CUE sheets and rip logs as a separate async pass. A `MediaStoreObserverService` monitors content changes and triggers live rescans.

2. **Rust `TwoPhaseScanner` + `EventDrivenScanner`** (legacy fallback)
   Used when `MediaStore` querying is unavailable or for direct filesystem access.

3. **SAF (Storage Access Framework)** (Android removable / unresolvable paths)
   Used for USB/SD cards and any granted tree URI whose raw filesystem path cannot be resolved or read under scoped storage. Traverses the granted `DocumentFile` tree via `ContentResolver`, then extracts metadata with `MediaMetadataRetriever`. See [External Storage Scanning](#external-storage-usbsd-scanning).

### Tier 1 — MediaStore Scanner (`LibraryScannerService`)

- `queryMediaStoreAudio()` — fetches audio files with path, size, last-modified, and `MediaStore` URI
- `queryMediaStoreNonAudio()` — fetches non-audio files (CUE, log, etc.) for sidecar metadata
- `queryMediaStoreDeletions()` — detects files removed since last scan
- Differential sync: compares `MediaStore` snapshot against Isar database; only `NEW`/`MODIFIED` entries proceed to metadata extraction
- Background pass: `_enrichMediaStoreSidecarsInBackground()` parses CUE sheets and rip logs

### Tier 2 — Rust File Scanner (Legacy)

The Rust scanner is split into three layers:

1. `TwoPhaseScanner`
   Performs a full filesystem walk, reads only `path`, `size`, and `last_modified_ms`, then diffs that snapshot against the shared file database.

2. `EventDrivenScanner`
   Uses OS-native watcher backends through `notify`:
   - Linux: `inotify`
   - macOS: `FSEvents` / `kqueue` fallback
   - Windows: `ReadDirectoryChangesW`

   It coalesces live events into batch updates so the database lock is taken once per flush instead of once per file.

3. `HybridScanner`
   Runs the bootstrap scan first, seeds the database, starts the watcher, and exposes a manual rescan path for recovery.

### Data Model

```text
FileFingerprint
  path: String
  size: u64
  last_modified_ms: i64
```

The fingerprint intentionally excludes expensive tag parsing. Metadata extraction can happen later, only for files classified as `NEW` or `MODIFIED`.

### Flow (MediaStore path)

```text
                         +-----------------------+
                         |   Isar SongEntity DB  |
                         +----------+------------+
                                    ^
                                    |
                     diff/batch upsert/deletes
                                    |
+------------------+       +--------+--------+       +--------------------------+
| MediaStore Query | ----> | Diff Engine     | <---- | MediaStoreObserverService|
| (audio + non-aud)|       | (snapshot vs DB)|       | (ContentObserver)        |
+------------------+       +--------+--------+       +--------------------------+
                                    |
                          +---------+---------+
                          | Metadata Parser   |
                          | (lofty, sidecars) |
                          +-------------------+
```

### Flow (Rust filesystem path)

```text
                 +----------------------+
                 | SharedFileDatabase   |
                 | path -> fingerprint  |
                 +----------+-----------+
                            ^
                            |
     bootstrap              | batch upserts/deletes
                            |
+-----------------+   diff   |   +----------------------+
| TwoPhaseScanner +----------+---+ EventDrivenScanner   |
| WalkDir + rayon |              | notify watcher       |
| stat only       |              | event coalescing     |
+--------+--------+              +----------+-----------+
         |                                  |
         | manual rescan                    | live create/modify/delete
         +----------------------------------+
```

## Complexity

- MediaStore query: `O(a + n)` where `a` = audio files, `n` = non-audio files.
  Android's `MediaStore` handles the indexed filesystem traversal internally — typically orders of magnitude faster than a full filesystem walk.
- Rust bootstrap scan: `O(n)` filesystem walk and stat collection.
- Diffing: `O(n)` with hash map lookups against the in-memory snapshot.
- Live updates: `O(k)` for `k` changed files/events.

## Expected Behavior

- MediaStore path (60 GB / ~1,300 tracks): **~328 ms total** — dominated by the `MediaStore` query itself (~180 ms), not I/O.
- Rust path (1k–10k files): Bootstrap under a second on SSD.
- Rust path (10k–100k files): Bootstrap grows linearly; unchanged files skip metadata parsing.
- Live watcher phase: Cost proportional to actual churn; effectively zero when idle.

## Trade-offs

- MediaStore query
  - Leverages Android's indexed file metadata — no full traversal needed.
  - Near-real-time via content observer, no polling overhead.
  - Android-only; cannot work on direct file URIs.

- Polling/filesystem bootstarp scan
  - Simple and deterministic.
  - Reliable for initial state.
  - Wasteful if repeated frequently because every pass touches the whole tree.

- Event-driven watcher
  - Scales with actual change volume.
  - Near-real-time updates.
  - Needs overflow/recovery handling, which is why the hybrid design keeps a manual rescan path.

## External Storage (USB/SD) Scanning

Removable volumes (USB OTG drives, SD cards) are accessed exclusively through the Android Storage Access Framework (SAF). The app holds `ACTION_OPEN_DOCUMENT_TREE` + `READ_MEDIA_AUDIO` permissions but **not** `MANAGE_EXTERNAL_STORAGE`, so it cannot read scoped raw paths on removable media. The scanner therefore routes removable folders through SAF and degrades gracefully when a drive is unplugged.

### Why removable needs special handling

| Layer | Behavior on primary storage | Failure on removable |
|---|---|---|
| Path resolve (`resolveTreeUriToPath`) | Resolves to `/storage/emulated/0/...`, readable | Raw `/storage/<uuid>` is **unreadable** under scoped storage → `fsPath = null` |
| MediaStore query | `VOLUME_EXTERNAL` indexes primary audio | Removable files live under their **own volume name** (the FAT UUID) → wrong volume = 0 rows |
| Rust deep scan | Reads the raw path directly | Cannot read scoped raw paths without `MANAGE_EXTERNAL_STORAGE` → throws |

All three fast paths break on removable, so SAF is the only viable backend there. The work below makes SAF itself fast and keeps the MediaStore/Rust fast paths correct when removable metadata *is* available.

### Routing decision tree (`scanFolder`, `library_scanner_service.dart:89`)

Every Android scan begins by resolving the volume the folder lives on:

```text
resolveStorageInfo(folderUri) ──► StorageVolumeInfo
   {fsPath, mediaStoreVolume, isRemovable, isPrimary, state}

  ┌─ isRemovable && state != "mounted" ?
  │     YES ─► retain songs, updateFolderVolumeState(state),
  │            yield ScanProgress(unavailable:true, isComplete:true), RETURN
  │
  ┌─ useDeepScan ?
  │     YES ─► isRemovable ? ─► SAF (foreground accurate)   [Rust can't read scoped paths]
  │           else fsPath resolves ? ─► Rust deep scan (fallback to SAF on throw)
  │           else ─► SAF (foreground accurate)
  │
  └─ normal scan
        fsPath resolves ? ─► MediaStore(volumeName=mediaStoreVolume) [fallback to SAF instant on throw]
        else ─► SAF INSTANT (deferMetadata:true)
```

Key consequences:
- **Removable always lands on SAF** — even when deep scan is requested, Rust is skipped because it cannot read the scoped raw path.
- **Normal scan on removable is *instant*** (`deferMetadata: true`): songs appear immediately with filename-derived metadata; real tags are filled in by a detached background pass.
- **Deep scan on removable stays accurate** (`deferMetadata: false`): `MediaMetadataRetriever` runs in the foreground so CUE splitting and duration-based filtering happen up front.
- **Unplugged drives are never purged** — existing songs are retained and the folder is flagged unavailable.

### Volume resolution — `resolveStorageInfo` (`MainActivity.kt`)

Resolves a SAF tree URI to a filesystem path *plus* its MediaStore volume name and mount state:

1. Parse the tree document id (`<volumeId>:<relative/path>`). `primary`/`home` mark the emulated internal store.
2. Match a `StorageManager.storageVolumes` entry by `uuid` (removable) or `isPrimary`.
3. Derive the path: `StorageVolume.directory` (API 30+) or hidden `getPath()` via reflection (API 26–29, minSdk is 26).
4. **`canRead()` gate** — if the resolved raw path isn't readable (the scoped-storage case on removable), `fsPath` is set to `null`. This is what forces removable onto SAF.
5. `mediaStoreVolumeNameFor()`: returns `VOLUME_EXTERNAL_PRIMARY` for primary; otherwise the FAT UUID (= the removable MediaStore volume name) on API 29+, `null` pre-29.
6. Legacy `/storage/<volumeId>` fallback when `StorageManager` didn't enumerate the volume.

> Note: `getExternalVolumeNames()` is a hidden API and was removed from this path. If MediaStore hasn't indexed the removable volume, the query simply returns 0 rows and the scanner falls back to SAF — a safe degradation.

`MusicFolderService.resolveStorageInfo(uri)` exposes this over the `com.mossapps.flick/storage` channel as `StorageVolumeInfo`, and the MediaStore queries (`queryMediaStoreAudio`/`NonAudio`/`Deletions`) thread an optional `volumeName` so they target the correct volume collection via `MediaStore.Audio.Media.getContentUri(volumeName)`.

### SAF tree traversal — `listTreeDocuments` (`MainActivity.kt`)

The original SAF walk used `DocumentFile.listFiles()`, which costs ~6 binder round-trips per file (isDirectory / name / length / lastModified / type ...). Over FUSE on USB this is the dominant cost. The replacement issues **one `contentResolver.query()` per directory** via `DocumentsContract.buildChildDocumentsUriUsingTree`, projecting:

```
COLUMN_DOCUMENT_ID, COLUMN_DISPLAY_NAME, COLUMN_MIME_TYPE, SIZE, LAST_MODIFIED
```

Directories (mime `vnd.android.document/directory`) are recursed; `.nomedia` subtrees are skipped when `respectNomedia` is set; a `HashSet` document-id set guards against cycles. File URIs are built with `buildDocumentUriUsingTree`, matching the format `DocumentFile.uri` produced previously. `fastScanAudioFiles` (audio-ext filter) and `scanPlaylistFiles` (m3u/m3u8 filter) both use this helper, preserving their existing return shapes.

### Instant vs. accurate SAF paths

Both paths share `_scanFolderAndroid`'s prefix: fast-scan traverse → diff against existing entities → compute new/modified/deleted URIs. They diverge at the metadata step:

**Instant (`_scanFolderAndroidInstant`, `deferMetadata: true`)** — for normal scans:

1. For each truly-new URI (not already in DB), build a placeholder `SongEntity`: `title` from filename (`_extractTitleFromFilename`), artist/album `"Unknown Artist"`/`"Unknown Album"`, `durationMs = 0`, `metadataComplete = false`.
2. Apply the **size-only** ignore filter (duration is unknown yet, so the duration check is skipped).
3. Batch-upsert, yield progress — songs are now visible.
4. Detach `_enrichSafMetadataInBackground`, then detach playlist sync, then yield complete.

**Enrichment (`_enrichSafMetadataInBackground`)** — runs detached after instant:
- Fetches real tags in chunks via `MediaMetadataRetriever` (`fetchMetadata`).
- Now that duration is known, applies the **full** ignore filter and deletes too-short entries.
- **Technical fields** (`durationMs`, `bitrate`, `bitDepth`, `sampleRate`, `metadataComplete`) are **always** refreshed.
- **Text fields** (`title`/`artist`/`album`/`albumArtist`/`trackNumber`/`discNumber`) are refreshed **only if `!hasLocalEdits`** — manual edits are preserved.

**Accurate (`_scanFolderAndroid`, `deferMetadata: false`)** — for deep scans:
- The foreground metadata loop runs `MediaMetadataRetriever` in chunks before returning, so CUE track splitting, rip-log parsing, and duration-based filtering all complete up front.

> ponytail: CUE track splitting is deferred to deep scan. The instant path creates one raw entity per audio file — acceptable because CUE sheets on USB are rare. Users who need CUE splitting enable deep scan on that folder.

### Unplugged resilience

When a removable volume reports `state != "mounted"` (drive ejected):
- Songs are **retained** — never purged.
- `FolderEntity.volumeState` is updated to the live state (e.g. `unmounted`).
- The scan yields `ScanProgress(unavailable: true, isComplete: true)` and returns immediately.
- UI surfaces "USB not connected" on the folder row.

The next scan re-resolves volume info on entry (and lazily backfills `mediaStoreVolume` on pre-feature folders), so a replugged drive is picked up automatically.

### Data model additions (`FolderEntity` / `MusicFolder`)

Additive nullable fields (Isar auto-migrates; no migration code):

| Field | Type | Set when |
|---|---|---|
| `isRemovable` | `bool?` | add-time via `resolveStorageInfo` |
| `mediaStoreVolume` | `String?` | add-time; lazily backfilled for older folders |
| `volumeState` | `String?` | add-time; refreshed every scan (live mount state) |

`MusicFolder`'s prefs serializer was hardened to `jsonEncode`/`jsonDecode` (the prior hand-rolled escaper only handled `"`, not `\`).

### UX indicators

| Condition | Badge (appended to folder subtitle) |
|---|---|
| `isRemovable == true` | `· External` |
| `volumeState != "mounted"` | `· USB not connected` |

Surfaces: `_RootFolderCard` (`folders_screen.dart`) and `_buildFolderItem` (`library_settings_screen.dart`).

### Expected behavior on removable

- **Normal scan:** near-instant song visibility; real tags fill in seconds later in the background.
- **Deep scan:** ~proportional to file count × `MediaMetadataRetriever` cost (already parallelized at `min(cores×2, size)` per chunk), plus a single ContentResolver pass per directory.
- **Unplugged:** scan returns immediately; songs retained.

### Trade-offs & limitations

- **No Rust on removable.** Rust can't read scoped raw paths without `MANAGE_EXTERNAL_STORAGE` (deliberately not requested). SAF + `MediaMetadataRetriever` remains the deep-scan backend on USB.
- **Per-volume MediaStore is API 29+.** Pre-29 removable falls back to SAF regardless of the resolved volume name.
- **Deletion detection gap.** `queryMediaStoreDeletions` does not yet thread `volumeName` through the deletion-check path, so MediaStore-based deletion detection on removable returns 0 rows and falls back to SAF only on MediaStore *failure*, not empty result. Pre-existing behavior; not a regression.
- **Refresh plumbing unchanged.** `songsProvider` is `autoDispose` and refreshed manually; detached enrichment follows the existing background-update pattern (visible on remount or manual refresh) rather than adding new invalidation wiring.



| Format | Extensions | Metadata Source | Scanner Paths |
|--------|-----------|-----------------|---------------|
| MP3 | `.mp3` | lofty (ID3v1/v2) | MediaStore, SAF, Rust |
| FLAC | `.flac` | lofty (Vorbis Comments) | MediaStore, SAF, Rust |
| OGG Vorbis | `.ogg`, `.oga` | lofty (Vorbis Comments) | MediaStore, SAF, Rust |
| Opus | `.opus`, `.ogx` | lofty (Vorbis Comments) | MediaStore, SAF, Rust |
| M4A/AAC | `.m4a` | lofty (MP4 atoms) | MediaStore, SAF, Rust |
| WAV | `.wav` | lofty (RIFF INFO) | MediaStore, SAF, Rust |
| AIFF | `.aif`, `.aiff` | lofty (ID3v2) | MediaStore, SAF, Rust |
| ALAC | `.alac` | lofty (MP4) | MediaStore, SAF, Rust |
| WavPack | `.wv` | lofty (APE/ID3v1) | SAF, Rust |
| WavPack DSD | `.wv` | lofty (APE/ID3v1); detected via sample rate ≥ 2.8224 MHz or 1-bit depth | SAF, Rust |
| DSF | `.dsf` | dsf-meta (ID3v2 via `id3` crate) | SAF, Rust |
| DSDIFF | `.dff` | dff-meta (ID3v2 via `id3` crate) | SAF, Rust |

Note: Android's MediaStore does not index WavPack or DSD files — these formats are only available through the SAF or Rust scanner paths.

## Extension Filter Locations

When adding a new format, these **four** extension allowlists must be updated:

| # | File | Function | Line |
|---|------|----------|------|
| 1 | `rust/src/api/scanner.rs` | `is_supported_audio_path()` | ~69 |
| 2 | `rust/src/library_scan/two_phase.rs` | `is_supported_audio_path()` | ~185 |
| 3 | `lib/services/library_scanner_service.dart` | `_looksLikeSupportedAudioExtension()` | ~1715 |
| 4 | `android/.../MainActivity.kt` | `fastScanAudioFiles()` — `audioExtensions` set | ~1429 |

The Rust scanner (`#1`) feeds metadata extraction. The two-phase scanner (`#2`) and watcher filter by extension. The Dart filter (`#3`) gates all paths reaching the scanner. The Kotlin filter (`#4`) gates the SAF filesystem walk on Android.
