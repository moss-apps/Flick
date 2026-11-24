# Library Scan Architecture

## Overview

Three scan tiers, prioritized by availability and performance:

1. **Android `MediaStore` Query** (normal scans, Android-only) — queries the `MediaStore` content provider, diffs against Isar, parses metadata only for new/modified files. `MediaStoreObserverService` triggers live rescans.
2. **Rust `TwoPhaseScanner` + `EventDrivenScanner`** — the Deep Scan backend for folders with a directly readable filesystem path (every volume with All Files Access; primary volumes without scoped-tree restrictions). See [Permission Model](#permission-model).
3. **SAF (Storage Access Framework)** — Deep Scan on Android 11+ scoped trees, USB/SD without a readable path, and the fallback when MediaStore can't query or index the folder. Traverses `DocumentFile` via `ContentResolver`, extracts metadata with `MediaMetadataRetriever`. See [External Storage Scanning](#external-storage-usbsd-scanning).

### Routing decision (`LibraryScannerService.chooseAndroidScanEngine`)

Deep Scan is what opts into filesystem-level traversal; it is not implied by All Files Access alone.

```text
deep scan, All Files Access && readable path -> Rust walk (every volume, every format)
deep scan, removable && readable path        -> MediaStore (scoped mode: Rust can't open it)
deep scan, primary, readable non-scoped path -> Rust walk
deep scan, otherwise                         -> SAF tree (foreground accurate metadata)
normal scan, readable path                   -> MediaStore (even with All Files Access)
otherwise                                    -> SAF
```

MediaStore query failures or an empty index fall back to SAF instead of treating the folder as empty.

The decision is pure and unit-tested (`test/services/library_scanner_routing_test.dart`).

### Permission model

- `MANAGE_EXTERNAL_STORAGE` (All Files Access) is **flavor-dependent** (`productFlavors { play, full }` in `android/app/build.gradle.kts`). The `full` flavor (GitHub Releases/sideload) declares it in `android/app/src/full/AndroidManifest.xml`; the `play` flavor ships without it because Play policy requires MediaStore/SAF for media apps. Both share the same applicationId.
- When declared and granted, Deep Scan can walk every volume with Rust and no OEM MediaScanner gap can hide a file; with Deep Scan off, scans stay on MediaStore so the toggle changes the engine. Settings → Library → Scan Settings → "Full Library Access" (with status) plus a dismissible notice card are shown only when `PermissionService.isAllFilesAccessSupported()` reports the permission is declared in this build's manifest.
- The `play` flavor falls back to scoped storage: MediaStore + SAF apply, and the Tier 1 DSD reconciliation walk below fills OEM indexing gaps. Android ≤10 is unaffected in both flavors — `hasAllFilesAccess()` accepts the still-declared legacy `READ_EXTERNAL_STORAGE` there.
- Legacy: `READ_EXTERNAL_STORAGE` (≤32), `WRITE_EXTERNAL_STORAGE` (≤28) + `requestLegacyExternalStorage`, `READ_MEDIA_AUDIO` (13+).
- Adding a folder or manually rescanning can request the media read permission when the scan may use MediaStore. This is separate from the folder picker grant. If denied, the scan can still use SAF; background scans never prompt.
- Kotlin exposes `hasAllFilesAccess` / `isAllFilesAccessSupported` / `requestAllFilesAccess` (opens the system settings screen) on the `com.mossapps.flick/storage` channel; `resolveStorageInfo` returns an `allFilesAccess` flag alongside `fsPath`/`mediaStoreVolume`.

### Tier 1 — MediaStore Scanner (`LibraryScannerService`)

- `queryMediaStoreAudio()` — audio files with path, size, last-modified, MediaStore URI; also pulls `.dsf`/`.dff`/`.wv` from `MediaStore.Files` (deduped by path) since OEM MediaScanners don't classify DSD/WavPack as audio
- DSD reconciliation walk (`DsdReconciliation.findUnindexedDsdFiles`) — stat-only raw walk per scanned folder, every scan: recovers `.dsf`/`.dff`/`.wv` on OEMs (MIUI/HyperOS, Vivo, Honor) where the MediaScanner skips DSD *entirely* (no Files rows either). Synthesizes `file://` rows with empty tags; the background sparse-metadata pass fills them. Skips dotfiles/dirs and `.nomedia` subtrees. Also fires a best-effort `MediaScannerConnection.scanFile()` heal so future scans may find the rows in MediaStore. JVM-tested (`android/app/src/test/.../DsdReconciliationTest.kt`).
- Change observer watches both `MediaStore.Audio.Media` and `MediaStore.Files` URIs (DSD lives only in the latter on these OEMs).
- `queryMediaStoreNonAudio()` — non-audio (CUE, log) sidecars
- Audio, DSD and sidecar queries match literal directory prefixes ending in `/`. Failed or incomplete audio/DSD queries trigger SAF fallback rather than returning partial results.
- `queryMediaStoreDeletions()` — files removed since last scan
- Differential sync: only `NEW`/`MODIFIED` entries proceed to metadata extraction
- Background pass: `_enrichMediaStoreSidecarsInBackground()` parses CUE sheets and rip logs
- Multi-FILE CUE sheets are split per `FILE` block and each block resolves to a discovered audio file in its own directory (unique same-stem fallback for converted `.wav` → `.flac` rips), so one-track-per-file sheets never collapse onto the final file path

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

Removable volumes are accessed only through SAF. Play builds hold `ACTION_OPEN_DOCUMENT_TREE` + `READ_MEDIA_AUDIO` but **not** `MANAGE_EXTERNAL_STORAGE` (Play policy), so scoped raw paths on removable media are unreadable and the scanner routes removable folders through SAF, degrading gracefully on unplug. Full/GitHub builds declare the permission and read removable raw paths directly once it is granted.

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
  │     YES ─► All Files Access && fsPath ? ─► Rust (fallback to SAF on throw)
  │           isRemovable ? ─► MediaStore(volumeName) [fallback to SAF]
  │           fsPath && !scopedTreeRequired ? ─► Rust deep scan (fallback to SAF on throw)
  │           else ─► SAF (foreground accurate)
  │
  └─ normal scan
        fsPath resolves ? ─► MediaStore(volumeName=mediaStoreVolume) [fallback to SAF instant on throw/empty]
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

### Folder-path recording (`SongEntity.relativeFolderPath`)

Folder browsing groups songs by their immediate directory under the selected root. Every engine records that path at scan time: SAF uses the walker's `relativePath`; MediaStore and Rust derive it from the resolved filesystem root with `relativeFolderPathFor()`. `''` means directly under the scan root; `null` means unresolved.

Before the unchanged-file skip, each Android scan also backfills this field on existing rows. Libraries imported before the field existed therefore repair in place on the next ordinary rescan, preserving row ids and local edits.



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

- **Scoped raw paths on removable** — without Full Library Access, removable raw paths are unreadable under scoped storage, so deep scans prefer the per-volume MediaStore index (SAF is the fallback); with Full Library Access and Deep Scan on, the Rust walker covers every volume.
- **Deletion URI-space ownership** — rows keyed by SAF document URIs are never handed to raw-path deletion checks. A switch to a raw-path engine only supersedes an SAF row once its raw equivalent is confirmed. MediaStore index misses do not prove deletion: an unmatched raw-path row is retained unless a complete, accessible SAF walk of the matching folder also confirms the file is absent. If the scan can't map the row to that tree, it leaves it alone.
- **Per-volume MediaStore is API 29+** — pre-29 removable falls back to SAF.
- **Deletion detection gap** — `queryMediaStoreDeletions` doesn't thread `volumeName`; MediaStore-based deletion detection on removable returns 0 rows and falls back to SAF only on MediaStore *failure*, not empty result. Pre-existing.
- **DSD false-deletion guard** — `.dsf`/`.dff`/`.wv` are absent from `Audio.Media` on some OEMs, so deletion detection would flag them as removed every scan. `queryMediaStoreDeletions` confirms a DSD extension via `File.exists()` before declaring it deleted.
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
| WavPack | `.wv` | lofty (APE/ID3v1) | MediaStore (Files), SAF, Rust |
| WavPack DSD | `.wv` | lofty (APE/ID3v1); detected via sample rate ≥ 2.8224 MHz or 1-bit depth | MediaStore (Files), SAF, Rust |
| DSF | `.dsf` | dsf-meta (ID3v2 via `id3` crate) | MediaStore (Files), SAF, Rust |
| DSDIFF | `.dff` | dff-meta (ID3v2 via `id3` crate) | MediaStore (Files), SAF, Rust |

Android's MediaStore does not classify WavPack or DSD as audio under `MediaStore.Audio.Media`, so the primary audio query misses them. `queryMediaStoreAudio()` runs a secondary query against `MediaStore.Files` for `.dsf`/`.dff`/`.wv` and merges the rows, deduplicating by filesystem path against the audio rows already collected. This recovers DSD on OEM MediaScanners (ColorOS/Oppo/Realme, HiOS/Tecno/Infinix) that never index DSD as audio. Metadata (title/artist/album/duration) is empty at this stage and filled in by the metadata parser. On OEMs whose MediaScanner skips DSD from the Files collection too, the DSD reconciliation walk (above) recovers the files directly from disk. Deep Scan with All Files Access uses the Rust walk and bypasses OEM indexing.

### Rust metadata fallback (WavPack/DSD enrichment)

`MediaMetadataRetriever` cannot decode WavPack on any device and often lacks DSD decoders, so every metadata chunk fetched by the MediaStore/SAF tiers gets a second pass (`_fillRustMetadataFallback` in `library_scanner_service.dart`): rows with a `.wv`/`.dsf`/`.dff` extension whose retriever result is missing duration or sample rate are re-read by the Rust parsers via the FRB `extractFileMetadata` API (same per-format extractors the deep scanner uses). Raw-path URIs (`file://` or plain paths) are read directly; SAF document URIs are staged through the shared `playback_staging` cache with a 256 MB cap so Rust can open them as plain files. Failures degrade silently — retriever results stand.

Album art follows the same rule in `album_art_service.dart`: `.wv`/`.dsf`/`.dff` sources skip the retriever's `embeddedPicture` (always null for them) and extract via Rust lofty on the raw or staged path; `file://`-keyed sources are normalized to plain paths first.

## Extension Filter Locations

Four extension allowlists must be updated when adding a format:

| # | File | Function | Line |
|---|------|----------|------|
| 1 | `rust/src/api/scanner.rs` | `is_supported_audio_path()` | ~69 |
| 2 | `rust/src/library_scan/two_phase.rs` | `is_supported_audio_path()` | ~185 |
| 3 | `lib/services/library_scanner_service.dart` | `_looksLikeSupportedAudioExtension()` | ~1715 |
| 4 | `android/.../MainActivity.kt` | `fastScanAudioFiles()` — `audioExtensions` set | ~1429 |

`#1` feeds metadata extraction. `#2` and watcher filter by extension. `#3` gates all paths reaching the scanner. `#4` gates the SAF filesystem walk on Android.
