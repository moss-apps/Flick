# Library Scan Architecture

## Overview

Three scan tiers, prioritized by availability and performance:

1. **Android `MediaStore` Query** (primary, Android-only) — queries the `MediaStore` content provider, diffs against Isar, parses metadata only for new/modified files. `MediaStoreObserverService` triggers live rescans.
2. **Rust `TwoPhaseScanner` + `EventDrivenScanner`** (legacy fallback) — used when `MediaStore` is unavailable or for direct filesystem access.
3. **SAF (Storage Access Framework)** — USB/SD and unresolvable tree URIs. Traverses `DocumentFile` via `ContentResolver`, extracts metadata with `MediaMetadataRetriever`. See [External Storage Scanning](#external-storage-usbsd-scanning).

### Tier 1 — MediaStore Scanner (`LibraryScannerService`)

- `queryMediaStoreAudio()` — audio files with path, size, last-modified, MediaStore URI
- `queryMediaStoreNonAudio()` — non-audio (CUE, log) sidecars
- `queryMediaStoreDeletions()` — files removed since last scan
- Differential sync: only `NEW`/`MODIFIED` entries proceed to metadata extraction
- Background pass: `_enrichMediaStoreSidecarsInBackground()` parses CUE sheets and rip logs

### Tier 2 — Rust File Scanner (Legacy)

Three layers:

1. `TwoPhaseScanner` — filesystem walk, reads `path`/`size`/`last_modified_ms`, diffs against the shared file database.
2. `EventDrivenScanner` — OS-native watchers via `notify` (Linux: `inotify`; macOS: `FSEvents`/`kqueue`; Windows: `ReadDirectoryChangesW`). Coalesces events into batch updates so the DB lock is taken once per flush.
3. `HybridScanner` — bootstrap scan → seed DB → start watcher; exposes manual rescan for recovery.

### Data Model

```text
FileFingerprint
  path: String
  size: u64
  last_modified_ms: i64
```

Excludes tag parsing; metadata extraction runs only for `NEW`/`MODIFIED` files.

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

## Complexity & Expected Behavior

- MediaStore query: `O(a + n)` (`a` = audio, `n` = non-audio). MediaStore handles the indexed traversal — typically orders of magnitude faster than a full walk.
- Rust bootstrap: `O(n)` walk + stat; diffing `O(n)` hash-map lookups; live updates `O(k)` for `k` changed files.
- MediaStore path (60 GB / ~1,300 tracks): **~328 ms** — dominated by the MediaStore query (~180 ms), not I/O.
- Rust path: bootstrap under a second on SSD (1k–10k files); grows linearly (10k–100k); unchanged files skip metadata parsing. Watcher cost proportional to churn; zero when idle.
- Normal scan on removable: near-instant; tags fill in seconds later in background.
- Deep scan on removable: ~proportional to file count × `MediaMetadataRetriever` cost.
- Unplugged drive: scan returns immediately; songs retained.

## External Storage (USB/SD) Scanning

Removable volumes are accessed only through SAF. The app holds `ACTION_OPEN_DOCUMENT_TREE` + `READ_MEDIA_AUDIO` but **not** `MANAGE_EXTERNAL_STORAGE`, so scoped raw paths on removable media are unreadable. The scanner routes removable folders through SAF and degrades gracefully on unplug.

### Why removable needs special handling

| Layer | Behavior on primary | Failure on removable |
|---|---|---|
| Path resolve (`resolveTreeUriToPath`) | Resolves to `/storage/emulated/0/...`, readable | Raw `/storage/<uuid>` is **unreadable** under scoped storage → `fsPath = null` |
| MediaStore query | `VOLUME_EXTERNAL` indexes primary audio | Removable files live under their **own volume name** (FAT UUID) → wrong volume = 0 rows |
| Rust deep scan | Reads raw path directly | Cannot read scoped raw paths without `MANAGE_EXTERNAL_STORAGE` → throws |

All three fast paths break on removable.

### Routing decision tree (`scanFolder`, `library_scanner_service.dart:89`)

Every Android scan resolves the volume the folder lives on first:

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

### Volume resolution — `resolveStorageInfo` (`MainActivity.kt`)

Resolves a SAF tree URI to a filesystem path + MediaStore volume name + mount state:

1. Parse tree document id (`<volumeId>:<relative/path>`; `primary`/`home` = emulated internal store).
2. Match `StorageManager.storageVolumes` by `uuid` (removable) or `isPrimary`.
3. Derive path: `StorageVolume.directory` (API 30+) or hidden `getPath()` via reflection (API 26–29; minSdk 26).
4. **`canRead()` gate** — unreadable raw path → `fsPath = null` → forces removable onto SAF.
5. `mediaStoreVolumeNameFor()`: `VOLUME_EXTERNAL_PRIMARY` for primary; FAT UUID on API 29+, `null` pre-29.
6. Legacy `/storage/<volumeId>` fallback when `StorageManager` didn't enumerate the volume.

> `getExternalVolumeNames()` (hidden API) removed from this path. Unindexed removable volume → MediaStore returns 0 rows → SAF fallback — safe degradation.

`MusicFolderService.resolveStorageInfo(uri)` exposes this over `com.mossapps.flick/storage` as `StorageVolumeInfo`; MediaStore queries thread optional `volumeName` via `MediaStore.Audio.Media.getContentUri(volumeName)`.

### SAF tree traversal — `listTreeDocuments` (`MainActivity.kt`)

`DocumentFile.listFiles()` costs ~6 binder round-trips per file — dominant cost over USB FUSE. The replacement issues **one `contentResolver.query()` per directory** via `DocumentsContract.buildChildDocumentsUriUsingTree`, projecting:

```
COLUMN_DOCUMENT_ID, COLUMN_DISPLAY_NAME, COLUMN_MIME_TYPE, SIZE, LAST_MODIFIED
```

Directories (`vnd.android.document/directory`) are recursed; `.nomedia` subtrees skipped when `respectNomedia` set; `HashSet` document-id set guards cycles. `fastScanAudioFiles` and `scanPlaylistFiles` both use this helper.

### Instant vs. accurate SAF paths

Both share `_scanFolderAndroid`'s prefix: traverse → diff → compute new/modified/deleted URIs. They diverge at metadata:

**Instant (`_scanFolderAndroidInstant`, `deferMetadata: true`)** — normal scans: placeholder `SongEntity` per new URI (title from filename, `durationMs = 0`, `metadataComplete = false`), size-only ignore filter, batch-upsert for immediate visibility, then detached enrichment + playlist sync.

**Enrichment (`_enrichSafMetadataInBackground`)** — real tags via `MediaMetadataRetriever` in chunks; full ignore filter (deletes too-short entries); technical fields (`durationMs`/`bitrate`/`bitDepth`/`sampleRate`/`metadataComplete`) always refreshed; text fields refreshed only if `!hasLocalEdits`.

**Accurate (`_scanFolderAndroid`, `deferMetadata: false`)** — deep scans: foreground `MediaMetadataRetriever` loop before returning, so CUE splitting and duration filtering complete up front.

> ponytail: CUE splitting is deferred to deep scan. CUE sheets on USB are rare; users who need CUE splitting enable deep scan.

### Unplugged resilience

When `state != "mounted"`: songs **retained** (never purged), `FolderEntity.volumeState` updated to live state, scan yields `ScanProgress(unavailable: true, isComplete: true)` and returns. Next scan re-resolves volume info on entry; a replugged drive is picked up automatically.

### Data model additions (`FolderEntity` / `MusicFolder`)

Additive nullable fields (Isar auto-migrates):

| Field | Type | Set when |
|---|---|---|
| `isRemovable` | `bool?` | add-time via `resolveStorageInfo` |
| `mediaStoreVolume` | `String?` | add-time; lazily backfilled for older folders |
| `volumeState` | `String?` | add-time; refreshed every scan |

`MusicFolder`'s prefs serializer was hardened to `jsonEncode`/`jsonDecode` (prior hand-rolled escaper only handled `"`, not `\`).

### UX indicators

| Condition | Badge (appended to folder subtitle) |
|---|---|
| `isRemovable == true` | `· External` |
| `volumeState != "mounted"` | `· USB not connected` |

Surfaces: `_RootFolderCard` (`folders_screen.dart`), `_buildFolderItem` (`library_settings_screen.dart`).

### Trade-offs & limitations

- **No Rust on removable** — can't read scoped raw paths without `MANAGE_EXTERNAL_STORAGE` (not requested). SAF + `MediaMetadataRetriever` is the deep-scan backend on USB.
- **Per-volume MediaStore is API 29+** — pre-29 removable falls back to SAF.
- **Deletion detection gap** — `queryMediaStoreDeletions` doesn't thread `volumeName`; MediaStore-based deletion detection on removable returns 0 rows and falls back to SAF only on MediaStore *failure*, not empty result. Pre-existing.
- **Refresh plumbing unchanged** — `songsProvider` is `autoDispose`, refreshed manually; detached enrichment follows the existing background-update pattern rather than adding new invalidation wiring.

## Supported Formats

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

Android's MediaStore does not index WavPack or DSD files — those formats are SAF/Rust only.

## Extension Filter Locations

Four extension allowlists must be updated when adding a format:

| # | File | Function | Line |
|---|------|----------|------|
| 1 | `rust/src/api/scanner.rs` | `is_supported_audio_path()` | ~69 |
| 2 | `rust/src/library_scan/two_phase.rs` | `is_supported_audio_path()` | ~185 |
| 3 | `lib/services/library_scanner_service.dart` | `_looksLikeSupportedAudioExtension()` | ~1715 |
| 4 | `android/.../MainActivity.kt` | `fastScanAudioFiles()` — `audioExtensions` set | ~1429 |

`#1` feeds metadata extraction. `#2` and watcher filter by extension. `#3` gates all paths reaching the scanner. `#4` gates the SAF filesystem walk on Android.
