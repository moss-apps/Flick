import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/constants/metadata_constants.dart';
import '../core/utils/audio_metadata_utils.dart';
import '../data/database.dart';
import '../data/repositories/song_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../services/music_folder_service.dart';
import '../services/permission_service.dart';
import '../services/library_scan_preferences_service.dart';
import '../services/playlist_service.dart';
import '../services/cue_file_service.dart';
import '../services/rip_log_service.dart';
import '../services/fingerprint_cache_service.dart';
import '../services/uac2_preferences_service.dart';
import '../services/audio_preload_service.dart';
import '../services/album_art_service.dart';
import '../services/album_art_import_service.dart';
import '../services/apple_music/apple_music_settings.dart';
import '../services/apple_music/auto_metadata_enricher.dart';
import '../services/artwork_backfill_tracker.dart';
import '../src/rust/api/scanner.dart'; // Rust bridge
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/l10n/l10n.dart';

/// How thoroughly a scan re-reads the library.
enum ScanMode {
  /// Only new/changed files are re-read; the walk still runs so additions
  /// and deletions are picked up.
  quick,

  /// Re-read metadata for every file found on disk.
  full,
}

/// Live snapshot of a single folder while several folders scan concurrently.
class FolderScanProgress {
  final String displayName;
  final int songsFound;
  final int totalFiles;
  final int filesProcessed;
  final String? currentFile;
  final String? phase;
  final int newSongs;
  final int modifiedSongs;
  final int deletedSongs;
  final bool isComplete;
  final bool unavailable;
  final String? unavailableMessage;

  const FolderScanProgress({
    required this.displayName,
    this.songsFound = 0,
    this.totalFiles = 0,
    this.filesProcessed = 0,
    this.currentFile,
    this.phase,
    this.newSongs = 0,
    this.modifiedSongs = 0,
    this.deletedSongs = 0,
    this.isComplete = false,
    this.unavailable = false,
    this.unavailableMessage,
  });

  double get progressFraction =>
      totalFiles > 0 ? (filesProcessed / totalFiles).clamp(0.0, 1.0) : 0.0;
}

/// Progress update during library scanning.
class ScanProgress {
  final int songsFound;
  final int totalFiles;
  final int filesProcessed;
  final String? currentFile;
  final String? currentFolder;
  final String? phase;
  final String? scanEngine;
  final int newSongs;
  final int modifiedSongs;
  final int deletedSongs;
  final int? foldersTotal;
  final int? foldersCompleted;

  /// Per-folder snapshots; non-null only when several folders run at once.
  final List<FolderScanProgress>? folders;
  final bool backgroundTasksRunning;
  final bool isComplete;
  final bool unavailable;

  /// Localized explanation for [unavailable]; null falls back to the USB
  /// storage message in the UI.
  final String? unavailableMessage;

  ScanProgress({
    required this.songsFound,
    required this.totalFiles,
    this.filesProcessed = 0,
    this.currentFile,
    this.currentFolder,
    this.phase,
    this.scanEngine,
    this.newSongs = 0,
    this.modifiedSongs = 0,
    this.deletedSongs = 0,
    this.foldersTotal,
    this.foldersCompleted,
    this.folders,
    this.backgroundTasksRunning = false,
    this.isComplete = false,
    this.unavailable = false,
    this.unavailableMessage,
  });

  double get progressFraction =>
      totalFiles > 0 ? (filesProcessed / totalFiles).clamp(0.0, 1.0) : 0.0;

  ScanProgress copyWith({
    int? songsFound,
    int? totalFiles,
    int? filesProcessed,
    String? currentFile,
    String? currentFolder,
    String? phase,
    String? scanEngine,
    int? newSongs,
    int? modifiedSongs,
    int? deletedSongs,
    int? foldersTotal,
    int? foldersCompleted,
    List<FolderScanProgress>? folders,
    bool? backgroundTasksRunning,
    bool? isComplete,
    bool? unavailable,
    String? unavailableMessage,
  }) {
    return ScanProgress(
      songsFound: songsFound ?? this.songsFound,
      totalFiles: totalFiles ?? this.totalFiles,
      filesProcessed: filesProcessed ?? this.filesProcessed,
      currentFile: currentFile ?? this.currentFile,
      currentFolder: currentFolder ?? this.currentFolder,
      phase: phase ?? this.phase,
      scanEngine: scanEngine ?? this.scanEngine,
      newSongs: newSongs ?? this.newSongs,
      modifiedSongs: modifiedSongs ?? this.modifiedSongs,
      deletedSongs: deletedSongs ?? this.deletedSongs,
      foldersTotal: foldersTotal ?? this.foldersTotal,
      foldersCompleted: foldersCompleted ?? this.foldersCompleted,
      folders: folders ?? this.folders,
      backgroundTasksRunning:
          backgroundTasksRunning ?? this.backgroundTasksRunning,
      isComplete: isComplete ?? this.isComplete,
      unavailable: unavailable ?? this.unavailable,
      unavailableMessage: unavailableMessage ?? this.unavailableMessage,
    );
  }
}

/// Service for scanning music folders and indexing songs in the database.
class LibraryScannerService {
  final SongRepository _songRepository;
  final FolderRepository _folderRepository;
  final MusicFolderService _musicFolderService;
  final PermissionService _permissionService;
  final LibraryScanPreferencesService _scanPreferencesService;
  final PlaylistService _playlistService;
  final bool _isAndroid;
  final FileFingerprintCache _fingerprintCache = FileFingerprintCache();

  bool _isCancelled = false;
  final Set<String> _currentlyScanning = {};
  final Map<String, Future<void>> _folderFinalization = {};
  final ArtworkBackfillTracker _artworkBackfill = ArtworkBackfillTracker();

  /// Aggregate progress of post-scan artwork backfill; null when idle.
  ValueListenable<ArtworkBackfillProgress?> get artworkBackfillProgress =>
      _artworkBackfill.progress;

  /// Resolves when artwork backfill for [folderUri] has finished (immediately
  /// when no backfill is pending for it).
  Future<void> awaitArtworkBackfill(String folderUri) =>
      _artworkBackfill.awaitFolder(normalizeFolderIdentifier(folderUri));

  /// Resolves when every currently pending artwork backfill has finished.
  Future<void> awaitAllArtworkBackfill() => _artworkBackfill.awaitAll();

  void _trackFinalization(String folderUri, Future<void> task) {
    _folderFinalization[folderUri] = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_folderFinalization[folderUri], task)) {
          _folderFinalization.remove(folderUri);
        }
      }),
    );
  }

  static const MethodChannel _storageChannel = MethodChannel(
    'com.mossapps.flick/storage',
  );

  LibraryScannerService({
    SongRepository? songRepository,
    FolderRepository? folderRepository,
    MusicFolderService? musicFolderService,
    PermissionService? permissionService,
    LibraryScanPreferencesService? scanPreferencesService,
    PlaylistService? playlistService,
    @visibleForTesting bool? isAndroid,
  }) : _songRepository = songRepository ?? SongRepository(),
       _folderRepository = folderRepository ?? FolderRepository(),
       _musicFolderService = musicFolderService ?? MusicFolderService(),
       _permissionService = permissionService ?? PermissionService(),
       _scanPreferencesService =
           scanPreferencesService ?? LibraryScanPreferencesService(),
       _playlistService = playlistService ?? PlaylistService(),
       _isAndroid = isAndroid ?? Platform.isAndroid;

  void cancelScan() {
    _isCancelled = true;
    // A detached preload pass outlives the scan stream; stop it too or it
    // keeps decoding (and holding the artwork gate) against the next scan.
    AudioPreloadService.instance.cancel();
  }

  /// Backfill volume metadata onto a folder entity resolved before this
  /// feature shipped. Best-effort: failure just leaves the folder unannotated.
  Future<void> _backfillFolderStorageInfo(
    FolderEntity entity,
    StorageVolumeInfo storageInfo,
  ) async {
    try {
      await _folderRepository.updateFolderVolumeInfo(
        uri: entity.uri,
        isRemovable: storageInfo.isRemovable,
        mediaStoreVolume: storageInfo.mediaStoreVolume,
        state: storageInfo.state,
      );
    } catch (e) {
      devLog('Volume-info backfill failed for ${entity.displayName}: $e');
    }
  }

  /// Scan engine routing decision (pure; unit-tested).
  ///
  /// Deep Scan is the switch that opts into filesystem-level traversal:
  /// Rust walks wherever it can open the folder directly, MediaStore covers
  /// readable removable volumes (Rust can't open scoped FUSE paths), and the
  /// SAF tree covers Android 11+ scoped trees where only the picker grant is
  /// readable. With Deep Scan off, normal scans stay on MediaStore even when
  /// All Files Access is granted, so the toggle actually changes the engine.
  /// SAF remains the fallback when no readable path exists.
  static String chooseAndroidScanEngine({
    required bool allFilesAccess,
    required bool hasReadableFsPath,
    required bool useDeepScan,
    required bool isRemovable,
    bool scopedTreeRequired = false,
  }) {
    if (useDeepScan) {
      if (allFilesAccess && hasReadableFsPath) return 'rust';
      if (isRemovable) {
        return hasReadableFsPath ? 'mediaStore' : 'saf';
      }
      return hasReadableFsPath && !scopedTreeRequired ? 'rust' : 'saf';
    }
    return hasReadableFsPath ? 'mediaStore' : 'saf';
  }

  static const _safDocumentsPrefix =
      'content://com.android.externalstorage.documents';

  /// Songs keyed by a SAF document URI belong to the SAF engine's URI space;
  /// raw-path engines (MediaStore DATA, Rust walk) can neither match nor
  /// confirm them and must not report them as deleted.
  bool _isSafUri(String filePath) =>
      filePath.startsWith('$_safDocumentsPrefix/');

  bool _isDocumentInTree(String filePath, String folderUri) {
    final file = Uri.tryParse(filePath);
    final folder = Uri.tryParse(folderUri);
    if (file == null ||
        folder == null ||
        file.scheme != 'content' ||
        folder.scheme != 'content' ||
        file.authority != folder.authority) {
      return false;
    }
    final segments = file.pathSegments;
    final root = folder.pathSegments;
    return segments.length >= 4 &&
        root.length >= 2 &&
        segments.first == 'tree' &&
        root.first == 'tree' &&
        segments[1] == root[1] &&
        segments[2] == 'document';
  }

  /// Maps a SAF document URI
  /// (content://com.android.externalstorage.documents/tree/.../document/
  /// primary%3AMusic%2Ftrack.dsf) to its raw filesystem path
  /// (/storage/emulated/0/Music/track.dsf), or null when unmappable.
  /// Pure; unit-tested.
  static String? rawPathFromSafUri(String uriString) {
    if (!uriString.startsWith('$_safDocumentsPrefix/')) return null;
    final uri = Uri.tryParse(uriString);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    String? docId;
    for (var i = 0; i + 1 < segments.length; i++) {
      if (segments[i] == 'document') docId = segments[i + 1];
    }
    return docId == null ? null : _rawPathFromStorageDocId(docId);
  }

  static String? _rawPathFromStorageDocId(String docId, {bool isTree = false}) {
    final colon = docId.indexOf(':');
    if (colon <= 0) return null;
    final volume = docId.substring(0, colon);
    final relative = docId.substring(colon + 1);
    final volumeRoot = switch (volume) {
      'primary' => '/storage/emulated/0',
      'home' => '/storage/emulated/0/Documents',
      _ => '/storage/$volume',
    };
    if (relative.isEmpty) return isTree ? volumeRoot : null;
    return '$volumeRoot/$relative';
  }

  /// Maps a `file://` URI (or passes through a plain absolute path) to its
  /// raw filesystem path, or null for anything else. Synthesized fallback
  /// rows are keyed `file:///storage/...`; the Rust parser needs raw paths.
  /// Pure; unit-tested.
  static String? rawPathFromFileUri(String uriString) {
    if (uriString.startsWith('file://')) {
      return Uri.tryParse(uriString)?.toFilePath();
    }
    if (uriString.startsWith('/')) return uriString;
    return null;
  }

  /// Directory of [filePath] relative to the actual [scanRootPath], using
  /// on-disk names. Returns '' when the file sits directly under the root and
  /// null when [filePath] is not a raw path inside [scanRootPath] (a content
  /// URI, another volume, or an unrelated prefix). Recording this at scan
  /// time avoids guessing the root from volume-id conventions later.
  /// Pure; unit-tested.
  static String? relativeFolderPathFor(String scanRootPath, String? filePath) {
    if (filePath == null) return null;
    final root = _normalizedRawScanPath(scanRootPath);
    final file = _normalizedRawScanPath(filePath);
    if (root == null || file == null) return null;
    if (file == root) return '';

    final prefix = root.endsWith('/') ? root : '$root/';
    if (!file.startsWith(prefix)) return null;

    final relative = file.substring(prefix.length);
    final slash = relative.lastIndexOf('/');
    return slash < 0 ? '' : relative.substring(0, slash);
  }

  static String? _normalizedRawScanPath(String path) {
    final raw = rawPathFromFileUri(path);
    if (raw == null) return null;
    var normalized = raw.replaceAll('\\', '/').replaceAll(RegExp('/+'), '/');
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Selects rows whose recorded folder path is missing or stale, and updates
  /// only that field. Ids, metadata, and local edits are untouched, so callers
  /// can upsert the returned batch without recreating library entries.
  /// Discovered paths may also be keyed by their confirmed MediaStore URI.
  /// Pure apart from mutating [SongEntity.relativeFolderPath]; unit-tested.
  static List<SongEntity> folderPathBackfillFor({
    required Iterable<SongEntity> songs,
    required Map<String, String> expectedByFilePath,
    Set<int> excludedIds = const {},
  }) {
    final batch = <SongEntity>[];
    for (final song in songs) {
      if (excludedIds.contains(song.id)) continue;
      final expected =
          expectedByFilePath[song.filePath] ??
          expectedByFilePath[song.mediaStoreUri];
      if (expected == null || song.relativeFolderPath == expected) continue;
      song.relativeFolderPath = expected;
      batch.add(song);
    }
    return batch;
  }

  /// Rewrites existing raw-path rows to the SAF document URI that represents
  /// the same file in the current tree walk. The row keeps its id (playlists
  /// and history reference it), metadata, and local edits; only the identity
  /// fields change. Files without a matching SAF URI are left untouched.
  ///
  /// This is the Android 11+ upgrade path for folders that were previously
  /// indexed through MediaStore/Rust: the next SAF scan moves them to the URI
  /// space the scoped scan actually uses instead of deleting and re-adding.
  /// Pure apart from mutating the songs; unit-tested.
  static List<SongEntity> migrateRawRowsToSafUris({
    required Iterable<SongEntity> songs,
    required Map<String, String> safUriByRawPath,
    required Map<String, String> relativeFolderPathByUri,
    Set<int> excludedIds = const {},
  }) => migrateSongPaths(
    songs: songs,
    targetBySource: safUriByRawPath,
    relativeFolderPathByTarget: relativeFolderPathByUri,
    excludedIds: excludedIds,
    toSaf: true,
  );

  @visibleForTesting
  static List<SongEntity> migrateSongPaths({
    required Iterable<SongEntity> songs,
    required Map<String, String> targetBySource,
    required Map<String, String> relativeFolderPathByTarget,
    Set<int> excludedIds = const {},
    bool toSaf = false,
  }) {
    final migrated = <SongEntity>[];
    final occupied = {
      for (final song in songs)
        if (!excludedIds.contains(song.id)) (song.filePath, song.startOffsetMs),
    };
    for (final song in songs) {
      if (excludedIds.contains(song.id)) continue;
      final target = targetBySource[song.filePath];
      // Never let an upsert silently adopt another row's id. Older versions
      // may have left both aliases in the DB with valid playlist references.
      if (target == null || !occupied.add((target, song.startOffsetMs))) {
        continue;
      }

      song.filePath = target;
      song.mediaStoreUri = toSaf ? target : null;
      final relative = relativeFolderPathByTarget[target];
      if (relative != null) song.relativeFolderPath = relative;
      migrated.add(song);
    }
    return migrated;
  }

  /// Scan a single folder using appropriate method for platform.
  Stream<ScanProgress> scanFolder(
    String folderUri,
    String displayName, {
    ScanMode mode = ScanMode.quick,
    bool promptForMediaAccess = false,
  }) async* {
    // Cancellation is sticky for the whole operation; only entry points may
    // clear it, so a Stop can't be wiped by a folder scan that starts late.
    _isCancelled = false;
    yield* _scanFolderInternal(
      folderUri,
      displayName,
      mode: mode,
      requestMediaAccess: promptForMediaAccess ? _requestMediaAccess : null,
    );
  }

  Future<bool> _requestMediaAccess(int sdkInt) async {
    try {
      return await _permissionService.requestStoragePermission(sdkInt: sdkInt);
    } catch (e) {
      devLog('Could not request MediaStore permission: $e');
      return false;
    }
  }

  Stream<ScanProgress> _scanFolderInternal(
    String folderUri,
    String displayName, {
    ScanMode mode = ScanMode.quick,
    Future<bool> Function(int sdkInt)? requestMediaAccess,
  }) async* {
    final scanStopwatch = Stopwatch()..start();
    final scanKey = normalizeFolderIdentifier(folderUri);
    final scanPreferences = await _scanPreferencesService.getPreferences();

    if (_currentlyScanning.contains(scanKey)) {
      devLog('Folder $displayName is already being scanned, skipping...');
      return;
    }

    _currentlyScanning.add(scanKey);
    final artworkBackfillToken = _artworkBackfill.begin(scanKey);
    try {
      if (_isAndroid) {
        var storageInfo = await _musicFolderService.resolveStorageInfo(
          folderUri,
        );

        final folderEntity = await _folderRepository.getFolderByUri(folderUri);
        final useDeepScan =
            folderEntity?.useDeepScan ?? scanPreferences.useDeepScan;

        // A picker grant does not grant MediaStore access. Ask only for
        // user-initiated scans that may use the index, then resolve the path
        // again: granting media access can make a previously hidden path readable.
        final mayUseMediaStore =
            (!useDeepScan || storageInfo.isRemovable) &&
            (storageInfo.fsPath != null || _isSafUri(folderUri)) &&
            (!storageInfo.isRemovable || storageInfo.isMounted);
        var mediaAccessDenied = false;
        if (requestMediaAccess != null &&
            !storageInfo.allFilesAccess &&
            mayUseMediaStore) {
          mediaAccessDenied = !await requestMediaAccess(storageInfo.sdkInt);
          if (_isCancelled) return;
          if (!mediaAccessDenied) {
            storageInfo = await _musicFolderService.resolveStorageInfo(
              folderUri,
            );
          }
        }
        final resolvedScanRoot = storageInfo.fsPath;

        // Lazy migration: backfill volume metadata for pre-feature folders.
        if (folderEntity != null && folderEntity.mediaStoreVolume == null) {
          await _backfillFolderStorageInfo(folderEntity, storageInfo);
        } else if (folderEntity != null &&
            storageInfo.isRemovable &&
            folderEntity.volumeState != storageInfo.state) {
          await _folderRepository.updateFolderVolumeState(
            folderUri,
            storageInfo.state,
          );
        }

        // Unplugged removable storage: retain songs, mark unavailable, skip scan.
        if (storageInfo.isRemovable && !storageInfo.isMounted) {
          devLog(
            'Skipping scan for $displayName: removable storage not mounted '
            '("${storageInfo.state}"), songs retained',
          );
          _logScanTiming(
            displayName,
            'scan folder (unavailable: ${storageInfo.state})',
            scanStopwatch.elapsed,
          );
          yield ScanProgress(
            songsFound: 0,
            totalFiles: 0,
            currentFolder: displayName,
            isComplete: true,
            unavailable: true,
          );
          return;
        }

        final hasReadableFsPath =
            resolvedScanRoot != null && resolvedScanRoot.isNotEmpty;
        // Android 11+ without All Files Access: only the picker-granted SAF
        // tree is guaranteed to expose every file in the folder.
        final scopedTreeRequired = storageInfo.requiresSafTreeWalk;
        final scanEngineChoice = chooseAndroidScanEngine(
          allFilesAccess: storageInfo.allFilesAccess,
          hasReadableFsPath: hasReadableFsPath,
          useDeepScan: useDeepScan,
          isRemovable: storageInfo.isRemovable,
          scopedTreeRequired: scopedTreeRequired,
        );

        if (scanEngineChoice == 'rust') {
          // The null re-check is required for Dart promotion.
          if (resolvedScanRoot != null) {
            try {
              yield* _scanFolderRust(
                resolvedScanRoot,
                folderUri,
                displayName,
                scanPreferences,
                mode: mode,
              );
              _logScanTiming(
                displayName,
                'scan folder (Rust)',
                scanStopwatch.elapsed,
              );
              return;
            } catch (e) {
              devLog(
                'Rust scan failed for $displayName at $resolvedScanRoot: '
                '$e, falling back to SAF',
              );
            }
          }
        }

        if (scanEngineChoice == 'mediaStore' && !mediaAccessDenied) {
          if (resolvedScanRoot != null && resolvedScanRoot.isNotEmpty) {
            try {
              yield* _scanFolderMediaStore(
                resolvedScanRoot,
                folderUri,
                displayName,
                scanPreferences,
                volumeName: storageInfo.mediaStoreVolume,
                deepScan: useDeepScan,
                mode: mode,
              );
              _logScanTiming(
                displayName,
                'scan folder (MediaStore)',
                scanStopwatch.elapsed,
              );
              return;
            } catch (e) {
              devLog(
                'MediaStore scan failed for $displayName at $resolvedScanRoot: '
                '$e, falling back to SAF',
              );
            }
          }
        }

        // 'saf' (and any fallback above): the picker tree is authoritative.
        yield* _scanFolderAndroid(
          folderUri,
          displayName,
          scanPreferences,
          deferMetadata: !useDeepScan,
          mode: mode,
        );
        _logScanTiming(displayName, 'scan folder (SAF)', scanStopwatch.elapsed);
      } else {
        yield* _scanFolderRust(
          folderUri,
          folderUri,
          displayName,
          scanPreferences,
          mode: mode,
        );
        _logScanTiming(
          displayName,
          'scan folder (Rust)',
          scanStopwatch.elapsed,
        );
      }
    } finally {
      _currentlyScanning.remove(scanKey);
      if (_isCancelled) {
        // Cancelled: no backfill will run, so release anyone awaiting covers.
        _artworkBackfill.finish(scanKey, artworkBackfillToken);
      } else {
        // Detached artwork backfill: resolve covers the lazy tile path hasn't
        // reached yet, so art persists after the scan instead of appearing
        // only when tiles are tapped. Runs unpaused — tiles may resolve
        // concurrently; _inFlightResolutions dedupes. The tracker lets the
        // manual scan session wait for covers before reporting "done".
        final task = _runDetachedScanTask(displayName, 'artwork resolve', () async {
          // CUE/log finalization upserts entities it loaded before artwork
          // existed; wait for it so it cannot clobber freshly resolved art
          // and so CUE-created tracks get resolved too.
          final pending = _folderFinalization[folderUri];
          if (pending != null) {
            await pending;
          }
          final songs = await _songRepository.getSongEntitiesByFolder(
            folderUri,
          );
          await AlbumArtService.instance.resolveMissingArtwork(
            songs,
            onProgress: (completed, total) => _artworkBackfill.setProgress(
              scanKey,
              artworkBackfillToken,
              completed,
              total,
            ),
          );
          try {
            if (await AppleMusicSettings().autoEnrichEnabled()) {
              final models = await _songRepository.getSongsByFolder(folderUri);
              await AutoMetadataEnricher.instance.enrichMissing(models);
            }
          } catch (error) {
            devLog('Auto metadata enrichment failed for $folderUri: $error');
          }
        });
        unawaited(
          task.whenComplete(
            () => _artworkBackfill.finish(scanKey, artworkBackfillToken),
          ),
        );
      }
    }
  }

  Stream<ScanProgress> _scanFolderMediaStore(
    String folderPath,
    String folderUri,
    String displayName,
    LibraryScanPreferences scanPreferences, {
    String? volumeName,
    bool deepScan = false,
    ScanMode mode = ScanMode.quick,
  }) async* {
    if (_isCancelled) return;
    final totalStopwatch = Stopwatch()..start();
    const scanEngine = 'MediaStore';
    var newSongs = 0;
    var modifiedSongs = 0;
    var deletedSongs = 0;
    yield ScanProgress(
      songsFound: 0,
      totalFiles: 0,
      currentFolder: displayName,
      scanEngine: scanEngine,
      phase: 'Querying filesystem',
      isComplete: false,
    );

    final List<AudioFileInfo> mediaStoreFiles;
    try {
      final stopwatch = Stopwatch()..start();
      mediaStoreFiles = await _musicFolderService.queryMediaStoreAudio([
        folderPath,
      ], volumeName: volumeName);
      _logScanTiming(displayName, 'MediaStore audio query', stopwatch.elapsed);
    } catch (e) {
      devLog(
        'MediaStore audio query failed for $displayName: $e; '
        'falling back to SAF',
      );
      yield* _scanFolderAndroid(
        folderUri,
        displayName,
        scanPreferences,
        deferMetadata: !deepScan,
        mode: mode,
      );
      return;
    }

    if (_isCancelled) return;

    // ponytail: MediaStore returns an empty-but-successful list when the
    // folder isn't indexed yet (Android 15 scoped storage; no MediaScan is
    // ever triggered). Fall back to SAF before the diff logic wipes
    // existing songs and silently reports an empty library.
    if (mediaStoreFiles.isEmpty) {
      devLog(
        'MediaStore returned 0 files for $displayName at $folderPath; '
        'falling back to SAF',
      );
      yield* _scanFolderAndroid(
        folderUri,
        displayName,
        scanPreferences,
        deferMetadata: !deepScan,
        mode: mode,
      );
      return;
    }

    final dbLoadStopwatch = Stopwatch()..start();
    final existingSongs = await _songRepository.getSongEntitiesByFolder(
      folderUri,
    );
    _logScanTiming(displayName, 'existing DB load', dbLoadStopwatch.elapsed);

    final filteredExistingSongs = await _purgeExistingSongsFilteredByRules(
      existingSongs,
      scanPreferences,
    );
    final filteredSongIds = filteredExistingSongs.map((song) => song.id).toSet();
    final mediaStoreByPath = {
      for (final file in mediaStoreFiles) ?file.filePath: file,
    };
    final targetBySafUri = <String, String>{};
    final relativeByRawPath = <String, String>{};
    for (final song in existingSongs) {
      final path = rawPathFromSafUri(song.filePath);
      if (path == null || !mediaStoreByPath.containsKey(path)) continue;
      targetBySafUri[song.filePath] = path;
      final relative = relativeFolderPathFor(folderPath, path);
      if (relative != null) relativeByRawPath[path] = relative;
    }
    final migratedRows = migrateSongPaths(
      songs: existingSongs,
      targetBySource: targetBySafUri,
      relativeFolderPathByTarget: relativeByRawPath,
      excludedIds: filteredSongIds,
    );
    if (migratedRows.isNotEmpty) {
      for (final song in migratedRows) {
        song.mediaStoreUri = mediaStoreByPath[song.filePath]?.uri;
      }
      await _songRepository.upsertSongs(migratedRows);
    }

    final rawExistingMap = <String, SongEntity>{};
    final existingByContentUri = <String, SongEntity>{};
    final existingCuePaths = <String>{};
    for (var s in existingSongs) {
      if (filteredSongIds.contains(s.id)) continue;
      if (s.startOffsetMs != null) {
        existingCuePaths.add(s.filePath);
        continue;
      }
      rawExistingMap[s.filePath] = s;
      if (s.filePath.startsWith('content://')) {
        existingByContentUri[s.filePath] = s;
      }
      final mediaStoreUri = s.mediaStoreUri;
      if (mediaStoreUri != null && mediaStoreUri.isNotEmpty) {
        existingByContentUri[mediaStoreUri] = s;
      }
    }

    // Same legacy repair as the SAF path: unchanged rows are skipped below,
    // so record the path from the actual scan root before that skip. Keep the
    // discovered MediaStore URI as an alias for legacy content/file-URI rows.
    final expectedRelativeByPath = <String, String>{};
    for (final file in mediaStoreFiles) {
      final filePath = file.filePath;
      if (filePath == null) continue;
      final expected = relativeFolderPathFor(folderPath, filePath);
      if (expected != null) {
        expectedRelativeByPath[filePath] = expected;
        expectedRelativeByPath[file.uri] = expected;
      }
    }
    final folderPathBackfill = folderPathBackfillFor(
      songs: existingSongs,
      expectedByFilePath: expectedRelativeByPath,
      excludedIds: filteredSongIds,
    );
    if (folderPathBackfill.isNotEmpty) {
      await _songRepository.upsertSongs(folderPathBackfill);
    }

    final scannedByPath = <String, AudioFileInfo>{};
    final scannedByUri = <String, AudioFileInfo>{};
    for (final f in mediaStoreFiles) {
      if (f.filePath != null) scannedByPath[f.filePath!] = f;
      scannedByUri[f.uri] = f;
    }

    final allScannedPaths = scannedByPath.keys.toSet();
    final allScannedUris = scannedByUri.keys.toSet();
    final allKnownPaths = allScannedPaths.union(allScannedUris);

    final unresolvedRows = <SongEntity>[];
    for (final song in existingSongs) {
      if (filteredSongIds.contains(song.id)) continue;

      // MediaStore can't vouch for SAF rows that couldn't be migrated.
      if (_isSafUri(song.filePath)) continue;

      final mediaStoreUri = song.mediaStoreUri;
      final isKnown =
          allKnownPaths.contains(song.filePath) ||
          (mediaStoreUri != null && allKnownPaths.contains(mediaStoreUri));
      if (!isKnown) unresolvedRows.add(song);
    }

    final idsToDelete = await _confirmMediaStoreDeletions(
      folderUri,
      folderPath,
      unresolvedRows,
    );
    if (_isCancelled) return;

    if (idsToDelete.isNotEmpty) {
      await _songRepository.deleteSongsByIds(idsToDelete);
    }
    deletedSongs += idsToDelete.length;

    final urisNeedingSparseMetadata = <String>[];
    final batch = <SongEntity>[];
    final idsToDeleteInline = <int>[];
    final diffStopwatch = Stopwatch()..start();

    for (final file in mediaStoreFiles) {
      final lookupKey = file.filePath ?? file.uri;
      final existing =
          rawExistingMap[lookupKey] ?? existingByContentUri[file.uri];
      // The audio index can't tell whether a CUE sheet is absent or unindexed.
      if (existing == null && existingCuePaths.contains(lookupKey)) continue;

      if (existing != null) {
        final existingTime = existing.lastModified?.millisecondsSinceEpoch ?? 0;
        // Rows without a sample rate are re-extracted: the sparse pass marks
        // them complete after one attempt, but the Rust fallback may only
        // succeed on a later scan (retriever failures on hi-res files).
        if (mode == ScanMode.quick &&
            file.lastModified == existingTime &&
            existing.metadataComplete &&
            existing.sampleRate != null &&
            existing.metadataVersion >= kCurrentTrackMetadataVersion) {
          continue;
        }
      }

      final looksLikeAudio =
          _looksLikeSupportedAudioExtension(file.extension) ||
          (file.mimeType?.toLowerCase().startsWith('audio/') ?? false) ||
          (file.duration ?? 0) > 0;
      if (!looksLikeAudio) continue;

      if (_shouldIgnoreDiscoveredTrack(
        fileSizeBytes: file.size,
        durationMs: file.duration,
        scanPreferences: scanPreferences,
      )) {
        if (existing != null) idsToDeleteInline.add(existing.id);
        continue;
      }

      final needsSparseMetadata =
          mode == ScanMode.full ||
          existing == null ||
          file.lastModified != existing.lastModified?.millisecondsSinceEpoch ||
          existing.sampleRate == null ||
          existing.bitDepth == null ||
          existing.discNumber == null ||
          existing.metadataVersion < kCurrentTrackMetadataVersion;

      final artist = (file.artist?.trim().isNotEmpty ?? false)
          ? file.artist!.trim()
          : l10n.unknownArtist;
      final song = SongEntity()
        ..filePath = file.filePath ?? file.uri
        ..mediaStoreUri = file.uri
        ..title = (file.title?.trim().isNotEmpty ?? false)
            ? file.title!.trim()
            : _extractTitleFromFilename(file.name)
        ..artist = artist
        ..album = (file.album?.trim().isNotEmpty ?? false)
            ? file.album!.trim()
            : l10n.unknownAlbum
        ..albumArtist = (file.albumArtist?.trim().isNotEmpty ?? false)
            ? file.albumArtist!.trim()
            : artist
        ..trackNumber = file.trackNumber ?? 0
        ..trackTotal = file.trackTotal ?? existing?.trackTotal
        ..discNumber = file.discNumber ?? 1
        ..discTotal = file.discTotal ?? existing?.discTotal
        ..durationMs = file.duration ?? 0
        ..fileType = file.extension.toUpperCase()
        ..dateAdded =
            existing?.dateAdded ??
            (file.dateAdded != null
                ? DateTime.fromMillisecondsSinceEpoch(file.dateAdded!)
                : DateTime.now())
        ..lastModified = DateTime.fromMillisecondsSinceEpoch(file.lastModified)
        ..folderUri = folderUri
        ..relativeFolderPath = relativeFolderPathFor(folderPath, file.filePath)
        ..fileSize = file.size
        ..albumArtPath = _carriedArtworkPath(
          existing,
          lastModified: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
          fileSize: file.size,
        )
        ..bitrate = file.bitrate != null
            ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                int.tryParse(file.bitrate!),
              )
            : null
        ..bitDepth = file.bitDepth ?? existing?.bitDepth
        ..sampleRate = file.sampleRate ?? existing?.sampleRate
        ..genre = (file.genre?.trim().isNotEmpty ?? false)
            ? file.genre!.trim()
            : existing?.genre
        ..year = file.year ?? existing?.year
        ..ripper = existing?.ripper
        ..readMode = existing?.readMode
        ..accurateRip = existing?.accurateRip
        ..metadataComplete =
            (existing?.metadataComplete ?? false) || !needsSparseMetadata
        ..metadataVersion = needsSparseMetadata
            ? 0
            : existing.metadataVersion;

      if (existing != null) {
        song.id = existing.id;
        _preserveLocalEdits(song, existing);
        modifiedSongs++;
      } else {
        newSongs++;
      }

      batch.add(song);

      if (needsSparseMetadata) {
        urisNeedingSparseMetadata.add(file.uri);
      }
    }
    _logScanTiming(displayName, 'diff/build entities', diffStopwatch.elapsed);

    if (idsToDeleteInline.isNotEmpty) {
      await _songRepository.deleteSongsByIds(idsToDeleteInline);
    }
    deletedSongs += idsToDeleteInline.length;

    if (batch.isNotEmpty) {
      final stopwatch = Stopwatch()..start();
      await _songRepository.upsertSongs(batch);
      _logScanTiming(
        displayName,
        'upsert ${batch.length} songs',
        stopwatch.elapsed,
      );
    }

    yield ScanProgress(
      songsFound: mediaStoreFiles.length,
      totalFiles: mediaStoreFiles.length,
      filesProcessed: mediaStoreFiles.length,
      currentFolder: displayName,
      scanEngine: scanEngine,
      phase: 'Finishing up',
      newSongs: newSongs,
      modifiedSongs: modifiedSongs,
      deletedSongs: deletedSongs,
      isComplete: false,
    );

    final detachedTasks = <Future<void>>[];
    if (urisNeedingSparseMetadata.isNotEmpty) {
      detachedTasks.add(
        _runDetachedScanTask(
          displayName,
          'sparse metadata',
          () => _extractSparseMetadataInBackground(
            urisNeedingSparseMetadata,
            folderUri,
            displayName,
          ),
        ),
      );
    }

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    detachedTasks.add(
      _runDetachedScanTask(
        displayName,
        'sidecar metadata',
        () => _enrichMediaStoreSidecarsInBackground(
          folderPath: folderPath,
          folderUri: folderUri,
          displayName: displayName,
          mediaStoreFiles: mediaStoreFiles,
          scanPreferences: scanPreferences,
          volumeName: volumeName,
        ),
      ),
    );
    detachedTasks.add(
      _runDetachedScanTask(
        displayName,
        'playlist sync',
        () => _syncPlaylistSourcesForFolder(
          folderUri,
          scanPreferences,
          scanRootPath: folderPath,
        ),
      ),
    );

    _logScanTiming(
      displayName,
      'foreground scan total',
      totalStopwatch.elapsed,
    );

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: mediaStoreFiles.length,
      filesProcessed: mediaStoreFiles.length,
      currentFolder: displayName,
      scanEngine: scanEngine,
      newSongs: newSongs,
      modifiedSongs: modifiedSongs,
      deletedSongs: deletedSongs,
      isComplete: true,
    );
  }

  Future<List<int>> _confirmMediaStoreDeletions(
    String folderUri,
    String folderPath,
    List<SongEntity> unmatchedRows,
  ) async {
    if (unmatchedRows.isEmpty || !_isSafUri(folderUri)) return [];
    final segments = Uri.parse(folderUri).pathSegments;
    if (segments.length != 2 || segments.first != 'tree') return [];
    final treePath = _rawPathFromStorageDocId(segments[1], isTree: true);
    final root = folderPath.replaceFirst(RegExp(r'/+$'), '');
    if (treePath != root) return [];
    final prefix = '$root/';

    // File.exists() can return false for permission-denied paths. Use it
    // only as positive evidence, so most unindexed tracks don't need a walk.
    final candidates = <String, List<int>>{};
    for (final song in unmatchedRows) {
      final path = rawPathFromFileUri(song.filePath);
      if (path == null || !path.startsWith(prefix)) continue;
      (candidates[path] ??= []).add(song.id);
    }
    for (final path in candidates.keys.toList()) {
      if (_isCancelled) return [];
      if (await File(path).exists()) candidates.remove(path);
    }
    if (candidates.isEmpty) return [];

    try {
      final tree = await _musicFolderService.scanFolderDetailed(
        folderUri,
        filterNonMusicFilesAndFolders: false,
      );
      if (!tree.rootAccessible || !tree.complete) return [];
      for (final file in tree.files) {
        final path = rawPathFromSafUri(file.uri);
        if (!_isDocumentInTree(file.uri, folderUri) ||
            path == null ||
            !path.startsWith(prefix)) {
          return [];
        }
        candidates.remove(path);
      }
      return candidates.values.expand((ids) => ids).toList();
    } catch (e) {
      devLog('Could not confirm MediaStore deletions for $folderUri: $e');
      return [];
    }
  }

  Future<void> _extractSparseMetadataInBackground(
    List<String> contentUris,
    String folderUri,
    String displayName,
  ) async {
    final metadataBatchSize = _recommendedMetadataBatchSize(contentUris.length);
    final metadataChunks = _chunkList(contentUris, metadataBatchSize);
    final songsByUri = await _songRepository.getSongEntitiesByFolder(folderUri);
    final pathMap = <String, SongEntity>{};
    // MediaStore content URIs carry no filesystem path the Rust fallback
    // could use; hand it the row's raw path so retries read the file
    // directly instead of staging a full copy through the cache.
    final rawPathByUri = <String, String>{};
    for (final s in songsByUri) {
      pathMap[s.filePath] = s;
      final mediaStoreUri = s.mediaStoreUri;
      if (mediaStoreUri != null && mediaStoreUri.isNotEmpty) {
        pathMap[mediaStoreUri] = s;
        final raw = rawPathFromFileUri(s.filePath);
        if (raw != null && mediaStoreUri.startsWith('content://')) {
          rawPathByUri[mediaStoreUri] = raw;
        }
      }
    }

    for (final chunkUris in metadataChunks) {
      if (_isCancelled) break;

      final stopwatch = Stopwatch()..start();
      final metadataList = await _fetchMetadataChunk(
        chunkUris,
        rawPathByUri: rawPathByUri,
      );
      _logScanTiming(
        displayName,
        'sparse metadata chunk ${chunkUris.length}',
        stopwatch.elapsed,
      );
      if (metadataList == null) continue;

      final updateBatch = <SongEntity>[];

      for (final meta in metadataList) {
        final existing = pathMap[meta.uri];
        if (existing == null) continue;

        existing.sampleRate = meta.sampleRate ?? existing.sampleRate;
        existing.bitDepth = meta.bitDepth ?? existing.bitDepth;
        if ((existing.durationMs ?? 0) <= 0) {
          existing.durationMs = meta.duration ?? existing.durationMs;
        }
        if (existing.bitrate == null && meta.bitrate != null) {
          existing.bitrate = AudioMetadataUtils.bitrateFromBitsPerSecond(
            int.tryParse(meta.bitrate!),
          );
        }
        applyTrackTotals(existing, meta);
        if (!existing.hasLocalEdits) {
          existing.discNumber = meta.discNumber ?? existing.discNumber;
          existing.albumArtist = (meta.albumArtist?.trim().isNotEmpty ?? false)
              ? meta.albumArtist!.trim()
              : existing.albumArtist;
          // Synthesized fallback rows (unindexed DSD/WavPack) start with
          // empty text and filename-derived titles; fill from real tags.
          if (existing.title.trim().isEmpty &&
              (meta.title?.trim().isNotEmpty ?? false)) {
            existing.title = meta.title!.trim();
          }
          if (existing.artist.trim().isEmpty &&
              (meta.artist?.trim().isNotEmpty ?? false)) {
            existing.artist = meta.artist!.trim();
          }
          if ((existing.album ?? '').trim().isEmpty &&
              (meta.album?.trim().isNotEmpty ?? false)) {
            existing.album = meta.album!.trim();
          }
          existing.trackNumber = meta.trackNumber ?? existing.trackNumber;
          existing.genre = (meta.genre?.trim().isNotEmpty ?? false)
              ? meta.genre!.trim()
              : existing.genre;
          existing.year = meta.year ?? existing.year;
        }
        existing.metadataComplete = true;
        updateBatch.add(existing);
      }

      if (updateBatch.isNotEmpty) {
        await _songRepository.upsertSongs(updateBatch);
      }
    }
  }

  Future<void> _enrichMediaStoreSidecarsInBackground({
    required String folderPath,
    required String folderUri,
    required String displayName,
    required List<AudioFileInfo> mediaStoreFiles,
    required LibraryScanPreferences scanPreferences,
    String? volumeName,
  }) async {
    if (_isCancelled || mediaStoreFiles.isEmpty) return;

    List<Map<String, dynamic>> nonAudioFiles;
    try {
      final stopwatch = Stopwatch()..start();
      nonAudioFiles = await _musicFolderService.queryMediaStoreNonAudio([
        folderPath,
      ], volumeName: volumeName);
      _logScanTiming(
        displayName,
        'MediaStore non-audio query',
        stopwatch.elapsed,
      );
    } catch (e) {
      devLog('MediaStore non-audio query failed for $displayName: $e');
      return;
    }

    if (_isCancelled || nonAudioFiles.isEmpty) return;

    final scannedByPath = <String, AudioFileInfo>{};
    final scannedByUri = <String, AudioFileInfo>{};
    for (final file in mediaStoreFiles) {
      if (file.filePath != null) scannedByPath[file.filePath!] = file;
      scannedByUri[file.uri] = file;
    }

    final cueFilesForParsing = nonAudioFiles
        .where((f) => (f['extension'] as String?)?.toLowerCase() == 'cue')
        .map(_audioInfoFromNonAudioMap)
        .toList();
    final logFilesForParsing = nonAudioFiles
        .where((f) {
          final ext = (f['extension'] as String?)?.toLowerCase() ?? '';
          return ext == 'log' || ext == 'txt';
        })
        .map(_audioInfoFromNonAudioMap)
        .toList();

    final sidecarStopwatch = Stopwatch()..start();
    final cueMap = cueFilesForParsing.isNotEmpty
        ? await _parseCueFilesAndroid(cueFilesForParsing, scannedByPath)
        : <String, CueSheet>{};
    final logMap = logFilesForParsing.isNotEmpty
        ? await _parseLogFilesAndroid(logFilesForParsing, scannedByPath)
        : <String, RipLog>{};
    _logScanTiming(displayName, 'CUE/log parse', sidecarStopwatch.elapsed);

    if (_isCancelled || (cueMap.isEmpty && logMap.isEmpty)) return;

    final existingSongs = await _songRepository.getSongEntitiesByFolder(
      folderUri,
    );
    final rawExistingMap = <String, SongEntity>{};
    for (final song in existingSongs) {
      if (song.startOffsetMs == null) {
        rawExistingMap[song.filePath] = song;
      }
    }

    final idsToDelete = <int>[];
    final entitiesToUpsert = <SongEntity>[];

    for (final entry in cueMap.entries) {
      if (_isCancelled) break;

      final audioPath = entry.key;
      final file = scannedByPath[audioPath] ?? scannedByUri[audioPath];
      if (file == null) continue;

      final rawExisting = rawExistingMap[audioPath];
      if (rawExisting != null) idsToDelete.add(rawExisting.id);

      final cueExistingMap = <String, SongEntity>{};
      final cueTracksInDb = existingSongs.where(
        (s) => s.filePath == audioPath && s.startOffsetMs != null,
      );
      for (final song in cueTracksInDb) {
        cueExistingMap['${song.filePath}#${song.startOffsetMs}'] = song;
      }

      final cueEntities = _buildCueTrackEntities(
        audioUri: audioPath,
        cueSheet: entry.value,
        meta: file,
        folderUri: folderUri,
        existingMap: cueExistingMap,
        ripLog: logMap[audioPath],
        lastModified: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
        relativeFolderPath:
            file.relativeFolderPath ??
            relativeFolderPathFor(folderPath, file.filePath),
      );

      for (final entity in cueEntities) {
        if (_shouldIgnoreDiscoveredTrack(
          fileSizeBytes: entity.fileSize,
          durationMs: entity.durationMs,
          scanPreferences: scanPreferences,
        )) {
          continue;
        }
        entitiesToUpsert.add(entity);
      }
    }

    for (final entry in logMap.entries) {
      if (cueMap.containsKey(entry.key)) continue;
      final existing = rawExistingMap[entry.key];
      if (existing == null || existing.startOffsetMs != null) continue;

      existing.ripper = entry.value.ripper;
      existing.readMode = entry.value.readMode;
      existing.accurateRip = entry.value.accurateRipEnabled;
      entitiesToUpsert.add(existing);
    }

    if (idsToDelete.isNotEmpty) {
      await _songRepository.deleteSongsByIds(idsToDelete);
    }
    if (entitiesToUpsert.isNotEmpty) {
      await _songRepository.upsertSongs(entitiesToUpsert);
    }

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);
  }

  /// Instant SAF path: surfaces new files immediately with filename-derived
  /// metadata, then defers accurate retrieval to the background. Used for
  /// non-deep scans where appearing fast matters more than perfect metadata.
  Stream<ScanProgress> _scanFolderAndroidInstant({
    required String folderUri,
    required String displayName,
    required Map<String, AudioFileInfo> fastScanMap,
    required Map<String, SongEntity> existingMap,
    required List<String> urisToProcess,
    required int initialSongCount,
    required int totalFiles,
    required int deletedSongs,
    required Stopwatch totalStopwatch,
    required LibraryScanPreferences scanPreferences,
    required String? unavailableMessage,
  }) async* {
    final newBatch = <SongEntity>[];
    for (final uri in urisToProcess) {
      if (existingMap.containsKey(uri)) continue; // already visible
      final basic = fastScanMap[uri];
      if (basic == null) continue;
      if (!_looksLikeSupportedAudioExtension(basic.extension)) continue;
      if (_shouldIgnoreDiscoveredTrack(
        fileSizeBytes: basic.size,
        durationMs: null, // duration unknown until background enrichment
        scanPreferences: scanPreferences,
      )) {
        continue;
      }
      newBatch.add(
        SongEntity()
          ..filePath = basic.uri
          ..mediaStoreUri = basic.uri.startsWith('content://')
              ? basic.uri
              : null
          ..title = _extractTitleFromFilename(basic.name)
          ..artist = l10n.unknownArtist
          ..album = l10n.unknownAlbum
          ..albumArtist = l10n.unknownArtist
          ..trackNumber = 0
          ..discNumber = 1
          ..durationMs = 0
          ..fileType = basic.extension.toUpperCase()
          ..dateAdded = DateTime.now()
          ..lastModified = DateTime.fromMillisecondsSinceEpoch(
            basic.lastModified,
          )
          ..folderUri = folderUri
          ..relativeFolderPath = basic.relativeFolderPath
          ..fileSize = basic.size
          ..metadataComplete = false,
      );
    }

    if (newBatch.isNotEmpty) {
      await _songRepository.upsertSongs(newBatch);
    }

    const scanEngine = 'SAF (instant)';
    final newSongs = newBatch.length;
    yield ScanProgress(
      songsFound: initialSongCount + newBatch.length,
      totalFiles: totalFiles,
      filesProcessed: totalFiles,
      currentFolder: displayName,
      scanEngine: scanEngine,
      phase: 'Upserting songs',
      newSongs: newSongs,
      deletedSongs: deletedSongs,
      isComplete: false,
    );

    final detachedTasks = <Future<void>>[];
    detachedTasks.add(
      _runDetachedScanTask(
        displayName,
        'deferred metadata',
        () => _enrichSafMetadataInBackground(
          uris: urisToProcess,
          folderUri: folderUri,
          displayName: displayName,
          scanPreferences: scanPreferences,
        ),
      ),
    );

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    detachedTasks.add(
      _runDetachedScanTask(
        displayName,
        'SAF playlist sync',
        () => _syncPlaylistSourcesForFolder(folderUri, scanPreferences),
      ),
    );

    _logScanTiming(displayName, 'SAF scan total', totalStopwatch.elapsed);

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      filesProcessed: totalFiles,
      currentFolder: displayName,
      scanEngine: scanEngine,
      newSongs: newSongs,
      deletedSongs: deletedSongs,
      isComplete: true,
      unavailable: unavailableMessage != null,
      unavailableMessage: unavailableMessage,
    );
  }

  /// Background enrichment for the instant SAF path. Fetches real metadata
  /// via MediaMetadataRetriever and fills the placeholder fields left by the
  /// filename-derived basic entities.
  Future<void> _enrichSafMetadataInBackground({
    required List<String> uris,
    required String folderUri,
    required String displayName,
    required LibraryScanPreferences scanPreferences,
  }) async {
    if (uris.isEmpty) return;

    final metadataBatchSize = _recommendedMetadataBatchSize(uris.length);
    final metadataChunks = _chunkList(uris, metadataBatchSize);

    final songsByUri = await _songRepository.getSongEntitiesByFolder(folderUri);
    final pathMap = <String, SongEntity>{};
    for (final s in songsByUri) {
      if (s.startOffsetMs == null) pathMap[s.filePath] = s;
    }

    for (final chunkUris in metadataChunks) {
      if (_isCancelled) break;

      final stopwatch = Stopwatch()..start();
      final metadataList = await _fetchMetadataChunk(chunkUris);
      _logScanTiming(
        displayName,
        'deferred metadata chunk ${chunkUris.length}',
        stopwatch.elapsed,
      );
      if (metadataList == null) continue;

      final metadataByUri = {for (final m in metadataList) m.uri: m};
      final updateBatch = <SongEntity>[];
      final idsToDelete = <int>[];

      for (final uri in chunkUris) {
        final meta = metadataByUri[uri];
        if (meta == null) continue;
        final existing = pathMap[uri];
        if (existing == null) continue;

        // Duration is now known: apply the full ignore filter.
        if (_shouldIgnoreDiscoveredTrack(
          fileSizeBytes: existing.fileSize,
          durationMs: meta.duration,
          scanPreferences: scanPreferences,
        )) {
          idsToDelete.add(existing.id);
          continue;
        }

        // Technical fields are never user-edited; always refresh.
        existing.durationMs = meta.duration ?? existing.durationMs;
        existing.bitrate = meta.bitrate != null
            ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                int.tryParse(meta.bitrate!),
              )
            : existing.bitrate;
        existing.bitDepth = meta.bitDepth ?? existing.bitDepth;
        existing.sampleRate = meta.sampleRate ?? existing.sampleRate;
        applyTrackTotals(existing, meta);
        existing.metadataComplete =
            existing.metadataComplete ||
            (meta.sampleRate != null && meta.bitDepth != null);

        // Text fields respect manual edits.
        if (!existing.hasLocalEdits) {
          if (meta.title?.trim().isNotEmpty ?? false) {
            existing.title = meta.title!.trim();
          }
          if (meta.artist?.trim().isNotEmpty ?? false) {
            existing.artist = meta.artist!.trim();
          }
          if (meta.album?.trim().isNotEmpty ?? false) {
            existing.album = meta.album!.trim();
          }
          existing.albumArtist = (meta.albumArtist?.trim().isNotEmpty ?? false)
              ? meta.albumArtist!.trim()
              : existing.artist;
          existing.trackNumber = meta.trackNumber ?? existing.trackNumber;
          existing.discNumber = meta.discNumber ?? existing.discNumber;
          existing.genre = (meta.genre?.trim().isNotEmpty ?? false)
              ? meta.genre!.trim()
              : existing.genre;
          existing.year = meta.year ?? existing.year;
        }

        updateBatch.add(existing);
      }

      if (idsToDelete.isNotEmpty) {
        await _songRepository.deleteSongsByIds(idsToDelete);
      }
      if (updateBatch.isNotEmpty) {
        await _songRepository.upsertSongs(updateBatch);
      }
    }

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);
  }

  Stream<ScanProgress> _scanFolderAndroid(
    String folderUri,
    String displayName,
    LibraryScanPreferences scanPreferences, {
    bool deferMetadata = false,
    ScanMode mode = ScanMode.quick,
  }) async* {
    if (_isCancelled) return;
    final totalStopwatch = Stopwatch()..start();
    const scanEngine = 'SAF';
    var newSongs = 0;
    var modifiedSongs = 0;
    var deletedSongs = 0;
    yield ScanProgress(
      songsFound: 0,
      totalFiles: 0,
      currentFolder: displayName,
      scanEngine: scanEngine,
      phase: 'Querying filesystem',
      isComplete: false,
    );

    // 1. Fast Scan: Get all files with basic info only
    List<AudioFileInfo> fastScanFiles = [];
    var treeWalkComplete = true;
    try {
      final stopwatch = Stopwatch()..start();
      final scanResult = await _musicFolderService.scanFolderDetailed(
        folderUri,
        filterNonMusicFilesAndFolders:
            scanPreferences.filterNonMusicFilesAndFolders,
      );
      if (!scanResult.rootAccessible) {
        // Revoked permission, unplugged volume, or a provider that vanished:
        // the walk saw nothing, but that is not an empty folder. Keep the
        // library and tell the user how to restore access.
        devLog(
          'SAF tree unavailable for $displayName ($folderUri); '
          'retaining existing songs',
        );
        _logScanTiming(
          displayName,
          'SAF fast scan (root unavailable)',
          stopwatch.elapsed,
        );
        yield ScanProgress(
          songsFound: 0,
          totalFiles: 0,
          currentFolder: displayName,
          scanEngine: scanEngine,
          isComplete: true,
          unavailable: true,
          unavailableMessage: l10n.folderAccessLostReselect,
        );
        return;
      }
      fastScanFiles = scanResult.files;
      treeWalkComplete = scanResult.complete;
      _logScanTiming(
        displayName,
        'SAF fast scan (${fastScanFiles.length} files'
            '${treeWalkComplete ? '' : ', partial'})',
        stopwatch.elapsed,
      );
    } catch (e) {
      devLog("Error scanning Android folder: $e");
      yield ScanProgress(
        songsFound: 0,
        totalFiles: 0,
        currentFolder: displayName,
        scanEngine: scanEngine,
        isComplete: true,
        unavailable: true,
        unavailableMessage: l10n.scanFailedPleaseTryAgain,
      );
      return;
    }

    if (_isCancelled) return;

    // 2. Diff Logic
    final existingSongs = await _songRepository.getSongEntitiesByFolder(
      folderUri,
    );
    final filteredExistingSongs = await _purgeExistingSongsFilteredByRules(
      existingSongs,
      scanPreferences,
    );

    // Android 11+ upgrade path: rows indexed by MediaStore or the Rust walk
    // are keyed by raw paths. The SAF walk just found the same files under
    // document URIs, so rewrite those rows in place. Ids (referenced by
    // playlists/history), metadata, and local edits stay intact instead of
    // being deleted and re-added under a new identity.
    final relativeByUri = <String, String>{};
    for (final file in fastScanFiles) {
      final relative = file.relativeFolderPath;
      if (relative != null) relativeByUri[file.uri] = relative;
    }
    final safUriByRawPath = <String, String>{};
    for (final file in fastScanFiles) {
      final raw = rawPathFromSafUri(file.uri);
      if (raw == null) continue;
      safUriByRawPath[raw] = file.uri;
      safUriByRawPath['file://$raw'] = file.uri;
      safUriByRawPath[Uri.file(raw).toString()] = file.uri;
    }
    final filteredSongIds = filteredExistingSongs.map((s) => s.id).toSet();
    final migratedRows = migrateRawRowsToSafUris(
      songs: existingSongs,
      safUriByRawPath: safUriByRawPath,
      relativeFolderPathByUri: relativeByUri,
      excludedIds: filteredSongIds,
    );
    if (migratedRows.isNotEmpty) {
      await _songRepository.upsertSongs(migratedRows);
      devLog(
        'Migrated ${migratedRows.length} raw-path rows to SAF URIs '
        'for $displayName',
      );
    }

    // Keep unsplit songs separate from CUE tracks sharing the same file.
    final rawExistingMap = <String, SongEntity>{};
    final activeSongs = existingSongs
        .where((song) => !filteredSongIds.contains(song.id))
        .toList(growable: false);
    for (final s in activeSongs) {
      if (s.startOffsetMs == null) {
        rawExistingMap[s.filePath] = s;
      }
    }
    final fastScanMap = {for (var f in fastScanFiles) f.uri: f};

    // Repair the folder path recorded for rows imported before the SAF walker
    // persisted it. This must run before the unchanged-row skip below: quick
    // scans never re-read those rows, so without an explicit backfill legacy
    // entries keep a null path forever and folder grouping has to guess it
    // from opaque document ids (issue #283).
    final folderPathBackfill = folderPathBackfillFor(
      songs: activeSongs,
      expectedByFilePath: relativeByUri,
    );
    if (folderPathBackfill.isNotEmpty) {
      await _songRepository.upsertSongs(folderPathBackfill);
    }

    // 2b. Parse CUE and log files
    final cueFiles = fastScanFiles
        .where((f) => f.extension.toLowerCase() == 'cue')
        .toList();
    final logFiles = fastScanFiles.where((f) {
      final ext = f.extension.toLowerCase();
      return ext == 'log' || ext == 'txt';
    }).toList();

    final sidecarStopwatch = Stopwatch()..start();
    var cueReadFailed = false;
    final cueMap = cueFiles.isNotEmpty
        ? await _parseCueFilesAndroid(
            cueFiles,
            fastScanMap,
            onReadFailure: () => cueReadFailed = true,
          )
        : <String, CueSheet>{};
    final logMap = logFiles.isNotEmpty
        ? await _parseLogFilesAndroid(logFiles, fastScanMap)
        : <String, RipLog>{};
    _logScanTiming(displayName, 'SAF CUE/log parse', sidecarStopwatch.elapsed);
    final unavailableMessage = !treeWalkComplete || cueReadFailed
        ? l10n.scanFailedPleaseTryAgain
        : null;

    // Calculate variations
    final scannedUris = fastScanMap.keys.toSet();

    // Delete by id, not by a single row per URI: every CUE offset is a song.
    // Only a complete walk can prove missing documents in this tree are gone.
    final missingIds = [
      if (treeWalkComplete)
        for (final song in activeSongs)
          if (_isDocumentInTree(song.filePath, folderUri) &&
              !scannedUris.contains(song.filePath))
            song.id,
    ];
    if (missingIds.isNotEmpty) {
      await _songRepository.deleteSongsByIds(missingIds);
      deletedSongs += missingIds.length;
    }

    // Delete orphaned CUE tracks (audio file in scan but no CUE file)
    final audioFilesWithCue = cueMap.keys.toSet();
    final existingCuePaths = activeSongs
        .where((s) => s.startOffsetMs != null)
        .map((s) => s.filePath)
        .toSet();
    if (treeWalkComplete && !cueReadFailed) {
      final orphanedCueIds = [
        for (final song in activeSongs)
          if (song.startOffsetMs != null &&
              scannedUris.contains(song.filePath) &&
              !audioFilesWithCue.contains(song.filePath))
            song.id,
      ];
      if (orphanedCueIds.isNotEmpty) {
        await _songRepository.deleteSongsByIds(orphanedCueIds);
        deletedSongs += orphanedCueIds.length;
      }
    }

    // Updates: New files or Modified files
    final urisToProcess = <String>[];
    for (final file in fastScanFiles) {
      if (!_looksLikeSupportedAudioExtension(file.extension)) continue;
      // A sidecar may be temporarily unavailable. Don't replace its tracks
      // with an unsplit row unless we've confirmed the sidecar is gone.
      if (existingCuePaths.contains(file.uri) &&
          !audioFilesWithCue.contains(file.uri) &&
          (!treeWalkComplete || cueReadFailed)) {
        continue;
      }
      final existing = rawExistingMap[file.uri];
      if (existing == null) {
        // New file
        urisToProcess.add(file.uri);
      } else {
        // Check modification time (DB stores DateTime, File has int timestamp)
        // DateTime.millisecondsSinceEpoch == file.lastModified (if file.lastModified is ms)
        // Wait, MusicFolderService parses lastModified as int.
        // Android DocumentFile.lastModified() returns MS.
        // SongEntity.lastModified is DateTime.

        final existingTime = existing.lastModified?.millisecondsSinceEpoch ?? 0;

        // Check for modification OR missing text/audio properties.
        final currentFileType = file.extension.trim().toUpperCase();
        final storedFileType = existing.fileType?.trim().toUpperCase();
        final fileTypeMismatch =
            currentFileType.isNotEmpty &&
            (storedFileType == null || storedFileType != currentFileType);
        final missingMetadata =
            !existing.metadataComplete ||
            existing.bitrate == null ||
            existing.sampleRate == null ||
            existing.metadataVersion < kCurrentTrackMetadataVersion ||
            fileTypeMismatch;

        if (mode == ScanMode.full ||
            file.lastModified != existingTime ||
            missingMetadata) {
          urisToProcess.add(file.uri);
        }
      }
    }

    // Ensure audio files referenced by CUE sheets are processed
    for (final audioUri in cueMap.keys) {
      if (!urisToProcess.contains(audioUri)) {
        urisToProcess.add(audioUri);
      }
    }

    // 3. Process Metadata in Chunks
    int processed = 0;

    // UX Metric: Total files found in filesystem
    int totalFiles = fastScanFiles.length;

    // UX Metric: Initial "Songs Found" = Existing - Deleted
    int initialSongCount = activeSongs.length - deletedSongs;

    // Unchanged files are already accounted for on the progress bar; the
    // metadata loop below adds the ones that actually get re-read.
    final initiallyAccounted = (totalFiles - urisToProcess.length).clamp(
      0,
      totalFiles,
    );

    // Report initial state after diff
    yield ScanProgress(
      songsFound: initialSongCount,
      totalFiles: totalFiles,
      filesProcessed: initiallyAccounted,
      currentFolder: displayName,
      scanEngine: scanEngine,
      phase: 'Reading metadata',
      deletedSongs: deletedSongs,
      isComplete: false,
    );

    if (deferMetadata && cueMap.isEmpty) {
      yield* _scanFolderAndroidInstant(
        folderUri: folderUri,
        displayName: displayName,
        fastScanMap: fastScanMap,
        existingMap: rawExistingMap,
        urisToProcess: urisToProcess,
        initialSongCount: initialSongCount,
        totalFiles: totalFiles,
        deletedSongs: deletedSongs,
        totalStopwatch: totalStopwatch,
        scanPreferences: scanPreferences,
        unavailableMessage: unavailableMessage,
      );
      return;
    }

    final metadataBatchSize = _recommendedMetadataBatchSize(
      urisToProcess.length,
    );
    final metadataChunks = _chunkList(urisToProcess, metadataBatchSize);

    for (final chunkUris in metadataChunks) {
      if (_isCancelled) break;

      final chunkStopwatch = Stopwatch()..start();
      final metadataList = await _fetchMetadataChunk(chunkUris);
      _logScanTiming(
        displayName,
        'SAF metadata chunk ${chunkUris.length}',
        chunkStopwatch.elapsed,
      );
      if (metadataList == null) {
        continue;
      }

      final batch = <SongEntity>[];
      final idsToDelete = <int>[];
      final metadataByUri = <String, AudioFileInfo>{
        for (final meta in metadataList) meta.uri: meta,
      };

      for (final uri in chunkUris) {
        final basic = fastScanMap[uri];
        if (basic == null) continue;

        final meta = metadataByUri[uri];
        final existing = rawExistingMap[basic.uri];
        final looksLikeAudio =
            _looksLikeSupportedAudioExtension(basic.extension) ||
            (meta?.mimeType?.toLowerCase().startsWith('audio/') ?? false) ||
            ((meta?.duration ?? 0) > 0);
        if (!looksLikeAudio) {
          continue;
        }

        final cueSheet = cueMap[basic.uri];
        final ripLog = logMap[basic.uri];

        if (cueSheet != null) {
          // Delete raw entity for this audio file if present
          final rawExisting = rawExistingMap[basic.uri];
          if (rawExisting != null) {
            idsToDelete.add(rawExisting.id);
          }

          // Build composite-key map so _buildCueTrackEntities can
          // preserve IDs of existing CUE tracks across rescans.
          final cueExistingMap = <String, SongEntity>{};
          final cueTracksInDb = activeSongs.where(
            (s) => s.filePath == basic.uri && s.startOffsetMs != null,
          );
          for (final s in cueTracksInDb) {
            cueExistingMap['${s.filePath}#${s.startOffsetMs}'] = s;
          }

          final cueEntities = _buildCueTrackEntities(
            audioUri: basic.uri,
            cueSheet: cueSheet,
            meta: meta ?? basic,
            folderUri: folderUri,
            existingMap: cueExistingMap,
            ripLog: ripLog,
            lastModified: DateTime.fromMillisecondsSinceEpoch(
              basic.lastModified,
            ),
            relativeFolderPath: basic.relativeFolderPath,
          );

          for (final entity in cueEntities) {
            if (_shouldIgnoreDiscoveredTrack(
              fileSizeBytes: entity.fileSize,
              durationMs: entity.durationMs,
              scanPreferences: scanPreferences,
            )) {
              continue;
            }
            batch.add(entity);
          }
          continue;
        }

        final artist = (meta?.artist?.trim().isNotEmpty ?? false)
            ? meta!.artist!.trim()
            : l10n.unknownArtist;
        final song = SongEntity()
          ..filePath = basic.uri
          ..mediaStoreUri = basic.uri.startsWith('content://')
              ? basic.uri
              : null
          ..title = (meta?.title?.trim().isNotEmpty ?? false)
              ? meta!.title!.trim()
              : _extractTitleFromFilename(basic.name)
          ..artist = artist
          ..album = (meta?.album?.trim().isNotEmpty ?? false)
              ? meta!.album!.trim()
              : l10n.unknownAlbum
          ..albumArtist = (meta?.albumArtist?.trim().isNotEmpty ?? false)
              ? meta!.albumArtist!.trim()
              : artist
          ..trackNumber = meta?.trackNumber ?? 0
          ..trackTotal = meta?.metadataRead == true
              ? meta!.trackTotal
              : existing?.trackTotal
          ..discNumber = meta?.discNumber ?? 1
          ..discTotal = meta?.metadataRead == true
              ? meta!.discTotal
              : existing?.discTotal
          ..durationMs = meta?.duration ?? 0
          ..fileType = basic.extension.toUpperCase()
          ..dateAdded = existing?.dateAdded ?? DateTime.now()
          ..lastModified = DateTime.fromMillisecondsSinceEpoch(
            basic.lastModified,
          )
          ..folderUri = folderUri
          ..relativeFolderPath = basic.relativeFolderPath
          ..fileSize = basic.size
          ..albumArtPath = _carriedArtworkPath(
            existing,
            lastModified: DateTime.fromMillisecondsSinceEpoch(
              basic.lastModified,
            ),
            fileSize: basic.size,
          )
          ..bitrate = meta?.bitrate != null
              ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                  int.tryParse(meta!.bitrate!),
                )
              : null
          ..bitDepth = meta?.bitDepth
          ..sampleRate = meta?.sampleRate
          ..genre = (meta?.genre?.trim().isNotEmpty ?? false)
              ? meta!.genre!.trim()
              : existing?.genre
          ..year = meta?.year ?? existing?.year
          ..ripper = ripLog?.ripper
          ..readMode = ripLog?.readMode
          ..accurateRip = ripLog?.accurateRipEnabled
          // ponytail: mark complete on any successful parse. sampleRate/bitDepth
          // are API 31+ only, so requiring them kept this false on older devices
          // and forced a full re-extract every rescan.
          ..metadataComplete = (meta?.duration ?? 0) > 0
          ..metadataVersion = _metadataVersionFor(meta, existing);

        if (existing != null) {
          song.id = existing.id;
          _preserveLocalEdits(song, existing);
          modifiedSongs++;
        } else {
          newSongs++;
        }

        if (_shouldIgnoreDiscoveredTrack(
          fileSizeBytes: basic.size,
          durationMs: song.durationMs,
          scanPreferences: scanPreferences,
        )) {
          if (existing != null) {
            idsToDelete.add(existing.id);
          }
          continue;
        }

        batch.add(song);
      }

      if (idsToDelete.isNotEmpty) {
        await _songRepository.deleteSongsByIds(idsToDelete);
      }
      deletedSongs += idsToDelete.length;

      if (batch.isNotEmpty) {
        await _songRepository.upsertSongs(batch);
      }

      processed += chunkUris.length;

      yield ScanProgress(
        songsFound: initialSongCount + processed,
        totalFiles: totalFiles,
        filesProcessed: initiallyAccounted + processed,
        currentFile: batch.isNotEmpty ? batch.last.title : null,
        currentFolder: displayName,
        scanEngine: scanEngine,
        phase: 'Reading metadata',
        newSongs: newSongs,
        modifiedSongs: modifiedSongs,
        deletedSongs: deletedSongs,
        isComplete: false,
      );
    }

    if (_isCancelled) return;

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    _logScanTiming(displayName, 'SAF scan total', totalStopwatch.elapsed);

    // Metadata is written; report completion now so the UI can close. Folder
    // stats and playlist sync are bookkeeping and run detached so they cannot
    // hold the completion event back.
    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      filesProcessed: totalFiles,
      currentFolder: displayName,
      scanEngine: scanEngine,
      newSongs: newSongs,
      modifiedSongs: modifiedSongs,
      deletedSongs: deletedSongs,
      phase: 'Finishing up',
      isComplete: false,
    );

    final finalization = _runDetachedScanTask(
      displayName,
      'scan finalization',
      () async {
        if (_isCancelled) return;
        await _folderRepository.updateFolderScanInfo(folderUri, finalCount);
        await _syncPlaylistSourcesForFolder(folderUri, scanPreferences);
      },
    );
    _trackFinalization(folderUri, finalization);

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      filesProcessed: totalFiles,
      currentFolder: displayName,
      scanEngine: scanEngine,
      newSongs: newSongs,
      modifiedSongs: modifiedSongs,
      deletedSongs: deletedSongs,
      isComplete: true,
      unavailable: unavailableMessage != null,
      unavailableMessage: unavailableMessage,
    );
  }

  Stream<ScanProgress> _scanFolderRust(
    String scanRootPath,
    String folderUri,
    String displayName,
    LibraryScanPreferences scanPreferences, {
    ScanMode mode = ScanMode.quick,
  }) async* {
    if (_isCancelled) return;
    final totalStopwatch = Stopwatch()..start();
    const scanEngine = 'Rust deep scan';
    var newSongs = 0;
    var modifiedSongs = 0;
    var deletedSongs = 0;
    final preloadCandidates = <SongEntity>[];

    yield ScanProgress(
      songsFound: 0,
      totalFiles: 0,
      currentFolder: displayName,
      scanEngine: scanEngine,
      phase: 'Loading existing entries',
      isComplete: false,
    );

    // 1. Fetch existing file state from DB
    final dbLoadStopwatch = Stopwatch()..start();
    final existingSongs = await _songRepository.getSongEntitiesByFolder(
      folderUri,
    );
    _logScanTiming(displayName, 'existing DB load', dbLoadStopwatch.elapsed);
    final filteredExistingSongs = await _purgeExistingSongsFilteredByRules(
      existingSongs,
      scanPreferences,
    );
    final knownFiles = <String, int>{};
    final existingMap = <String, SongEntity>{};
    final newOrModifiedFingerprints = <String, int>{};
    final deletedPaths = <String>[];
    final safRowsByRawPath = <String, List<SongEntity>>{};
    final rawRowsByPath = <String, List<SongEntity>>{};

    // Full mode re-reads every file and skips the fingerprint shortcuts,
    // including the CUE/log unchanged checks below. A single stale metadata
    // row also forces this folder's rescan so track totals backfill once.
    final forceFull = mode == ScanMode.full || needsMetadataBackfill(
      existingSongs,
      excludedSongs: filteredExistingSongs,
    );

    // Load fingerprint cache — supplements DB with faster lookup
    final cachedFingerprints = forceFull
        ? null
        : await _fingerprintCache.load(folderUri);

    for (var song in existingSongs) {
      if (filteredExistingSongs.contains(song)) {
        continue;
      }
      // Only migrate to a raw path after Rust confirms it can read the file.
      if (song.filePath.startsWith('content://')) {
        final rawPath = rawPathFromSafUri(song.filePath);
        if (rawPath != null) {
          (safRowsByRawPath[rawPath] ??= []).add(song);
        }
        continue;
      }
      (rawRowsByPath[song.filePath] ??= []).add(song);
      if (song.startOffsetMs == null || !existingMap.containsKey(song.filePath)) {
        existingMap[song.filePath] = song;
      }
      if (song.lastModified != null) {
        knownFiles[song.filePath] = song.lastModified!.millisecondsSinceEpoch;
      }
    }

    // Merge fingerprint cache: only entries that correspond to an existing DB
    // song are trusted. An orphaned cache (e.g. restored after reinstall while
    // the DB was wiped) must not mark files as "known", or the scanner skips
    // every file and the library ends up empty.
    if (cachedFingerprints != null) {
      for (final entry in cachedFingerprints.entries) {
        if (existingMap.containsKey(entry.key)) {
          knownFiles[entry.key] = entry.value;
        }
      }
    }
    for (final path in safRowsByRawPath.keys) {
      knownFiles.remove(path);
    }

    // Repair rows from scans that predate this field. The Rust stream only
    // returns new/modified files, so unchanged rows otherwise stay null and
    // folder grouping has to reconstruct the path from volume conventions.
    final expectedRelativeByPath = <String, String>{};
    for (final song in existingMap.values) {
      final expected = relativeFolderPathFor(scanRootPath, song.filePath);
      if (expected != null) expectedRelativeByPath[song.filePath] = expected;
    }
    final folderPathBackfill = folderPathBackfillFor(
      // CUE rows share a file path, so existingMap retains only one of them.
      // Repair every row, without re-inserting songs removed by scan filters.
      songs: existingSongs,
      expectedByFilePath: expectedRelativeByPath,
      excludedIds: filteredExistingSongs.map((song) => song.id).toSet(),
    );
    if (folderPathBackfill.isNotEmpty) {
      await _songRepository.upsertSongs(folderPathBackfill);
    }

    // 2. Stream scan batches from Rust
    int processed = 0;
    int filesAccounted = 0;
    int totalFiles = 0;
    int initialSongCount = existingMap.length;
    bool initialProgressSent = false;
    final rustScanStopwatch = Stopwatch()..start();

    await for (final chunk in scanMusicLibrary(
      rootPath: scanRootPath,
      knownFiles: knownFiles,
      scanOptions: ScanOptions(
        filterNonMusicFilesAndFolders:
            scanPreferences.filterNonMusicFilesAndFolders,
        forceFullRescan: forceFull,
      ),
    )) {
      if (_isCancelled) {
        break;
      }

      // Walk-phase heartbeat: the directory walk is still running, so there
      // is no file total yet. filesWalked drives the "checking" counter.
      if (chunk.totalFiles == 0 && chunk.filesWalked > 0 && !chunk.isComplete) {
        yield ScanProgress(
          songsFound: initialSongCount,
          totalFiles: 0,
          filesProcessed: chunk.filesWalked,
          currentFolder: displayName,
          scanEngine: scanEngine,
          phase: 'Checking for changes',
          deletedSongs: deletedSongs,
          isComplete: false,
        );
        continue;
      }

      totalFiles = chunk.totalFiles;
      // Unchanged files (and deletions) are accounted for up front, so the
      // bar reflects checked files instead of only re-read ones.
      filesAccounted = chunk.filesProcessed;

      if (!initialProgressSent) {
        // Deletions are collected here and applied only after the walk
        // finishes: an interrupted or failed scan must never leave the
        // folder emptied (files are re-verified by the next scan).
        deletedPaths.addAll(chunk.deletedPaths);
        initialSongCount = existingMap.length - chunk.deletedPaths.length;
        initialProgressSent = true;
      }

      SongEntity? lastProcessed;
      if (chunk.newOrModified.isNotEmpty) {
        final batch = <SongEntity>[];
        final migratedRows = <SongEntity>[];
        final idsToDelete = <int>[];

        for (final metadata in chunk.newOrModified) {
          final safRows = safRowsByRawPath[metadata.path];
          if (safRows != null) {
            final migrated = migrateSongPaths(
              songs: [...?rawRowsByPath[metadata.path], ...safRows],
              targetBySource: {
                for (final row in safRows) row.filePath: metadata.path,
              },
              relativeFolderPathByTarget: {
                metadata.path: ?relativeFolderPathFor(
                  scanRootPath,
                  metadata.path,
                ),
              },
            );
            migratedRows.addAll(migrated);
            for (final song in migrated) {
              if (song.startOffsetMs == null ||
                  !existingMap.containsKey(metadata.path)) {
                existingMap[metadata.path] = song;
              }
            }
          }
          final existing = existingMap[metadata.path];
          // The sidecar pass owns CUE rows. Don't overwrite one of them with
          // an unsplit song just to refresh metadata for the source file.
          if (existing?.startOffsetMs != null) continue;
          final artist = (metadata.artist?.trim().isNotEmpty ?? false)
              ? metadata.artist!.trim()
              : l10n.unknownArtist;
          final song = SongEntity()
            ..filePath = metadata.path
            ..title = (metadata.title?.trim().isNotEmpty ?? false)
                ? metadata.title!.trim()
                : _extractTitleFromFilename(metadata.path.split('/').last)
            ..artist = artist
            ..album = (metadata.album?.trim().isNotEmpty ?? false)
                ? metadata.album!.trim()
                : l10n.unknownAlbum
            ..albumArtist = existing?.albumArtist ?? artist
            ..trackNumber = metadata.trackNumber ?? existing?.trackNumber ?? 0
            ..trackTotal = metadata.trackTotal
            ..discNumber = metadata.discNumber ?? existing?.discNumber ?? 1
            ..discTotal = metadata.discTotal
            ..durationMs = metadata.durationMs?.toInt() ?? 0
            ..fileType = metadata.format.toUpperCase()
            ..dateAdded = existing?.dateAdded ?? DateTime.now()
            ..lastModified = DateTime.fromMillisecondsSinceEpoch(
              metadata.lastModified,
            )
            ..folderUri = folderUri
            ..relativeFolderPath = relativeFolderPathFor(
              scanRootPath,
              metadata.path,
            )
            ..fileSize = metadata.fileSize.toInt()
            ..albumArtPath = _carriedArtworkPath(
              existing,
              lastModified: DateTime.fromMillisecondsSinceEpoch(
                metadata.lastModified,
              ),
              fileSize: metadata.fileSize.toInt(),
            )
            ..bitrate = AudioMetadataUtils.normalizeStoredBitrateKbps(
              metadata.bitrate,
              sampleRate: metadata.sampleRate,
              bitDepth: metadata.bitDepth,
            )
            ..bitDepth = metadata.bitDepth
            ..sampleRate = metadata.sampleRate
            ..replaygainTrackGain = metadata.replaygainTrackGain
            ..replaygainTrackPeak = metadata.replaygainTrackPeak
            ..replaygainAlbumGain = metadata.replaygainAlbumGain
            ..replaygainAlbumPeak = metadata.replaygainAlbumPeak
            ..metadataComplete = true
            ..metadataVersion = kCurrentTrackMetadataVersion;

          if (existing != null) {
            song.id = existing.id;
            _preserveLocalEdits(song, existing);
            modifiedSongs++;
          } else {
            newSongs++;
          }

          if (_shouldIgnoreDiscoveredTrack(
            fileSizeBytes: metadata.fileSize.toInt(),
            durationMs: song.durationMs,
            scanPreferences: scanPreferences,
          )) {
            if (existing != null) {
              idsToDelete.add(existing.id);
            }
            continue;
          }

          batch.add(song);
          newOrModifiedFingerprints[metadata.path] = metadata.lastModified;
        }

        if (migratedRows.isNotEmpty) {
          await _songRepository.upsertSongs(migratedRows);
        }
        if (idsToDelete.isNotEmpty) {
          await _songRepository.deleteSongsByIds(idsToDelete);
        }
        deletedSongs += idsToDelete.length;

        if (batch.isNotEmpty) {
          await _songRepository.upsertSongs(batch);
          preloadCandidates.addAll(batch);
        }
        processed += batch.length;
        lastProcessed = batch.isNotEmpty ? batch.last : null;
      }

      yield ScanProgress(
        songsFound: initialSongCount + processed,
        totalFiles: totalFiles,
        filesProcessed: filesAccounted,
        currentFile: lastProcessed?.title,
        currentFolder: displayName,
        scanEngine: scanEngine,
        phase: 'Reading metadata',
        newSongs: newSongs,
        modifiedSongs: modifiedSongs,
        deletedSongs: deletedSongs,
        isComplete: false,
      );
    }
    _logScanTiming(displayName, 'Rust scan stream', rustScanStopwatch.elapsed);

    // Stopped mid-scan: skip deletions, sidecars, playlist/cache sync and the
    // detached preload, so a cancelled scan can't keep mutating state.
    if (_isCancelled) return;

    // Apply deletions only now that the walk completed successfully.
    if (!_isCancelled && deletedPaths.isNotEmpty) {
      final idsToDelete = [
        for (final path in deletedPaths.toSet())
          for (final song in rawRowsByPath[path] ?? const <SongEntity>[])
            song.id,
      ];
      if (idsToDelete.isNotEmpty) {
        await _songRepository.deleteSongsByIds(idsToDelete);
        deletedSongs += idsToDelete.length;
      }
    }

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    _logScanTiming(displayName, 'Rust scan total', totalStopwatch.elapsed);

    // The scan itself is done. Anything left (CUE/log sidecars, playlist and
    // fingerprint caches, the optional preload) is bookkeeping the UI should
    // not have to wait on, so announce the "finishing up" state and then run
    // it as one detached task before reporting completion.
    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      filesProcessed: totalFiles,
      currentFolder: displayName,
      scanEngine: scanEngine,
      newSongs: newSongs,
      modifiedSongs: modifiedSongs,
      deletedSongs: deletedSongs,
      phase: 'Finishing up',
      isComplete: false,
    );

    final finalization = _runDetachedScanTask(
      displayName,
      'scan finalization',
      () async {
        if (_isCancelled) return;

        // Post-process CUE and log files (single walk, both collected in one pass)
        if (!_isCancelled) {
          final sidecarStopwatch = Stopwatch()..start();
          final (:cueMap, :logMap) = await _parseCueAndLogFilesRust(
            scanRootPath,
          );
          _logScanTiming(
            displayName,
            'Rust CUE/log parse',
            sidecarStopwatch.elapsed,
          );

          if (cueMap.isNotEmpty || logMap.isNotEmpty) {
            final existingSongsAfterScan = await _songRepository
                .getSongEntitiesByFolder(folderUri);
            // Separate raw entities from CUE tracks — the old collapsible map
            // (keyed only by filePath) lost raw entities when CUE tracks shared
            // the same path, causing raw entities to survive alongside CUE tracks.
            final rawEntitiesByPath = <String, SongEntity>{};
            final logExistingByPath = <String, SongEntity>{};
            for (var s in existingSongsAfterScan) {
              if (s.startOffsetMs == null) {
                rawEntitiesByPath[s.filePath] = s;
              }
              logExistingByPath[s.filePath] = s;
            }

            // Process CUE files
            for (final entry in cueMap.entries) {
              final audioPath = entry.key;
              final cueSheet = entry.value;

              // Skip if audio file unchanged since last scan and CUE tracks
              // already exist in DB — avoids redundant re-parsing.
              final cachedTs = cachedFingerprints?[audioPath];
              if (cachedTs != null) {
                final existingCueCount = existingSongsAfterScan
                    .where(
                      (s) => s.filePath == audioPath && s.startOffsetMs != null,
                    )
                    .length;
                if (existingCueCount > 0) {
                  try {
                    final stat = FileStat.statSync(audioPath);
                    if (stat.type != FileSystemEntityType.notFound &&
                        stat.modified.millisecondsSinceEpoch == cachedTs) {
                      continue;
                    }
                  } catch (_) {}
                }
              }

              final rawEntity = rawEntitiesByPath[audioPath];

              // Re-fetch existing CUE tracks for this path to preserve IDs
              final cueExistingMap = <String, SongEntity>{};
              final cueTracksInDb = existingSongsAfterScan.where(
                (s) => s.filePath == audioPath && s.startOffsetMs != null,
              );
              for (final s in cueTracksInDb) {
                cueExistingMap['${s.filePath}#${s.startOffsetMs}'] = s;
              }

              // Build fallback metadata — prefer raw entity (fresh audio tags),
              // then fall back to existing CUE tracks (preserve across rescans
              // when the raw entity was already deleted).
              SongEntity? fallbackSource = rawEntity;
              fallbackSource ??= cueTracksInDb.isNotEmpty
                  ? cueTracksInDb.first
                  : null;
              final AudioFileInfo? fallbackMeta = fallbackSource != null
                  ? AudioFileInfo(
                      uri: audioPath,
                      name: audioPath.split('/').last,
                      size: fallbackSource.fileSize ?? 0,
                      lastModified:
                          fallbackSource.lastModified?.millisecondsSinceEpoch ??
                          0,
                      extension: audioPath.split('.').last,
                      title: fallbackSource.title,
                      artist: fallbackSource.artist,
                      album: fallbackSource.album,
                      albumArtist: fallbackSource.albumArtist,
                      trackNumber: fallbackSource.trackNumber,
                      trackTotal: fallbackSource.trackTotal,
                      discNumber: fallbackSource.discNumber,
                      discTotal: fallbackSource.discTotal,
                      duration: fallbackSource.durationMs,
                      albumArtPath: fallbackSource.albumArtPath,
                      bitrate: fallbackSource.bitrate?.toString(),
                      bitDepth: fallbackSource.bitDepth,
                      sampleRate: fallbackSource.sampleRate,
                    )
                  : null;

              // Delete raw entity if present
              if (rawEntity != null) {
                await _songRepository.deleteSongsByIds([rawEntity.id]);
              }

              final ripLog = logMap[audioPath];
              final lastModified =
                  rawEntity?.lastModified ??
                  fallbackSource?.lastModified ??
                  DateTime.fromMillisecondsSinceEpoch(
                    DateTime.now().millisecondsSinceEpoch,
                  );

              final entities = _buildCueTrackEntities(
                audioUri: audioPath,
                cueSheet: cueSheet,
                meta: fallbackMeta,
                folderUri: folderUri,
                existingMap: cueExistingMap,
                ripLog: ripLog,
                lastModified: lastModified,
                relativeFolderPath:
                    fallbackSource?.relativeFolderPath ??
                    relativeFolderPathFor(scanRootPath, audioPath),
              );

              if (entities.isNotEmpty) {
                await _songRepository.upsertSongs(entities);
              }
            }

            // Apply log metadata to raw audio files without CUE
            for (final entry in logMap.entries) {
              final audioPath = entry.key;
              if (cueMap.containsKey(audioPath)) continue;

              // Skip if audio file unchanged since last scan and already
              // has log metadata — avoids redundant re-parsing.
              final cachedTs = cachedFingerprints?[audioPath];
              final existing = logExistingByPath[audioPath];
              if (cachedTs != null &&
                  existing != null &&
                  existing.ripper != null) {
                try {
                  final stat = FileStat.statSync(audioPath);
                  if (stat.type != FileSystemEntityType.notFound &&
                      stat.modified.millisecondsSinceEpoch == cachedTs) {
                    continue;
                  }
                } catch (_) {}
              }

              if (existing == null) continue;
              existing.ripper = entry.value.ripper;
              existing.readMode = entry.value.readMode;
              existing.accurateRip = entry.value.accurateRipEnabled;
              await _songRepository.upsertSong(existing);
            }
          }
        }

        final playlistStopwatch = Stopwatch()..start();
        await _syncPlaylistSourcesForFolder(
          folderUri,
          scanPreferences,
          scanRootPath: scanRootPath,
        );
        _logScanTiming(
          displayName,
          'Rust playlist sync',
          playlistStopwatch.elapsed,
        );

        final fingerprintStopwatch = Stopwatch()..start();
        await _fingerprintCache.sync(
          folderUri,
          newOrModifiedFingerprints,
          deletedPaths,
        );
        _logScanTiming(
          displayName,
          'Rust fingerprint sync',
          fingerprintStopwatch.elapsed,
        );

        _logScanTiming(displayName, 'Rust scan total', totalStopwatch.elapsed);
      },
    );
    _trackFinalization(folderUri, finalization);

    // Audio preload runs after finalization (CUE/log upserts must exist first)
    // but detached from the artwork wait, so cover resolution is not delayed
    // by the decode pass — which holds the artwork gate for its whole run.
    unawaited(
      _runDetachedScanTask(displayName, 'scan preload', () async {
        await finalization;
        // Re-read the pref at spawn time so a mid-scan toggle is honored
        // instead of using the snapshot captured at scan start.
        final currentPrefs = await _scanPreferencesService.getPreferences();
        if (_isCancelled) return;
        if (currentPrefs.preloadAudioData && preloadCandidates.isNotEmpty) {
          await _preloadAudioData(preloadCandidates);
        }
      }),
    );

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      filesProcessed: totalFiles,
      currentFolder: displayName,
      scanEngine: scanEngine,
      newSongs: newSongs,
      modifiedSongs: modifiedSongs,
      deletedSongs: deletedSongs,
      isComplete: true,
    );
  }

  Stream<ScanProgress> scanAllFolders({
    ScanMode mode = ScanMode.quick,
    bool promptForMediaAccess = false,
  }) async* {
    _isCancelled = false;
    final totalStopwatch = Stopwatch()..start();
    final folders = await _folderRepository.getAllFolders();
    final scanPlan = _deduplicateFoldersForScan(folders);
    if (scanPlan.isEmpty) return;

    final foldersTotal = scanPlan.length;

    // Scan all deduplicated folders concurrently, but publish one aggregated
    // progress event per folder update so the UI never bounces between
    // per-folder counters.
    final controller = StreamController<ScanProgress>();
    final folderStates = <String, FolderScanProgress>{};
    var started = 0;
    var completed = 0;
    Future<bool>? mediaAccess;
    String? aggScanEngine;
    String? lastPhase;
    String? lastCurrentFile;

    int sumOf(int Function(FolderScanProgress) pick) =>
        folderStates.values.fold(0, (sum, state) => sum + pick(state));

    void emitAggregate() {
      if (controller.isClosed) return;
      final snapshots = folderStates.values.toList(growable: false);
      var totalFiles = 0;
      var filesProcessed = 0;
      var songsFound = 0;
      for (final snapshot in snapshots) {
        totalFiles += snapshot.totalFiles;
        filesProcessed += snapshot.filesProcessed;
        songsFound += snapshot.songsFound;
      }
      controller.add(
        ScanProgress(
          songsFound: songsFound,
          totalFiles: totalFiles,
          filesProcessed: filesProcessed,
          currentFile: lastCurrentFile,
          currentFolder: snapshots.length == 1
              ? snapshots.first.displayName
              : null,
          phase: lastPhase,
          scanEngine: aggScanEngine,
          newSongs: sumOf((s) => s.newSongs),
          modifiedSongs: sumOf((s) => s.modifiedSongs),
          deletedSongs: sumOf((s) => s.deletedSongs),
          foldersTotal: foldersTotal,
          foldersCompleted: completed,
          folders: snapshots,
          isComplete: false,
        ),
      );
    }

    for (final folder in scanPlan) {
      if (_isCancelled) break;
      started++;

      _scanFolderInternal(
        folder.uri,
        folder.displayName,
        mode: mode,
        requestMediaAccess: promptForMediaAccess
            ? (sdkInt) => mediaAccess ??= _requestMediaAccess(sdkInt)
            : null,
      ).listen(
        (progress) {
          folderStates[folder.uri] = FolderScanProgress(
            displayName: folder.displayName,
            songsFound: progress.songsFound,
            totalFiles: progress.totalFiles,
            filesProcessed: progress.filesProcessed,
            currentFile: progress.currentFile,
            phase: progress.phase,
            newSongs: progress.newSongs,
            modifiedSongs: progress.modifiedSongs,
            deletedSongs: progress.deletedSongs,
            isComplete: progress.isComplete,
            unavailable: progress.unavailable,
            unavailableMessage: progress.unavailableMessage,
          );
          aggScanEngine ??= progress.scanEngine;
          lastPhase = progress.phase;
          lastCurrentFile = progress.currentFile;
          emitAggregate();
        },
        onDone: () {
          completed++;
          final state = folderStates[folder.uri];
          if (state != null && state.totalFiles > 0) {
            folderStates[folder.uri] = FolderScanProgress(
              displayName: state.displayName,
              songsFound: state.songsFound,
              totalFiles: state.totalFiles,
              filesProcessed: state.totalFiles,
              phase: state.phase,
              newSongs: state.newSongs,
              modifiedSongs: state.modifiedSongs,
              deletedSongs: state.deletedSongs,
              isComplete: true,
              unavailable: state.unavailable,
              unavailableMessage: state.unavailableMessage,
            );
          }
          emitAggregate();
          // Close only when every attached folder stream finished; `started`
          // (not `running`) keeps a fast first folder from closing early.
          if (completed == started && !controller.isClosed) {
            controller.close();
          }
        },
        onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        },
        cancelOnError: false,
      );
    }

    yield* controller.stream;

    if (!_isCancelled) {
      final finalCount = await _songRepository.getSongCount();
      _logScanTiming('all folders', 'scan all total', totalStopwatch.elapsed);
      yield ScanProgress(
        songsFound: finalCount,
        totalFiles: 0,
        scanEngine: aggScanEngine,
        newSongs: sumOf((s) => s.newSongs),
        modifiedSongs: sumOf((s) => s.modifiedSongs),
        deletedSongs: sumOf((s) => s.deletedSongs),
        foldersTotal: foldersTotal,
        foldersCompleted: foldersTotal,
        folders: folderStates.values.toList(growable: false),
        isComplete: true,
        unavailable: folderStates.values.any((state) => state.unavailable),
      );
    }
  }

  /// Efficiently check for externally deleted files across all folders.
  /// Only removes songs whose file paths no longer exist on disk.
  Future<void> refreshDeletions() async {
    final stopwatch = Stopwatch()..start();
    final folders = await _folderRepository.getAllFolders();
    if (folders.isEmpty) return;

    final scanPreferences = await _scanPreferencesService.getPreferences();

    for (final folder in folders) {
      try {
        await _refreshDeletionsForFolder(
          folder.uri,
          folder.displayName,
          scanPreferences,
        );
      } catch (e) {
        devLog('Deletion refresh failed for ${folder.displayName}: $e');
      }
    }

    _logScanTiming('all folders', 'deletion refresh total', stopwatch.elapsed);
  }

  Future<int> _refreshDeletionsForFolder(
    String folderUri,
    String displayName,
    LibraryScanPreferences scanPreferences,
  ) async {
    final stopwatch = Stopwatch()..start();
    final existingSongs = await _songRepository.getSongEntitiesByFolder(
      folderUri,
    );
    if (existingSongs.isEmpty) return 0;

    final hasContentUris = existingSongs.any(
      (s) => s.filePath.startsWith('content://'),
    );

    // Scoped storage: the SAF tree is authoritative. Raw-path rows are legacy
    // entries awaiting migration by the next scan; keep them rather than
    // judging them through MediaStore, which may not index their files.
    var scopedTreeWalk = false;
    if (_isAndroid) {
      final storageInfo = await _musicFolderService.resolveStorageInfo(
        folderUri,
      );
      scopedTreeWalk = storageInfo.requiresSafTreeWalk;
    }

    List<String> deletedPaths;

    if (hasContentUris || scopedTreeWalk) {
      deletedPaths = await _checkDeletedPathsSaf(
        folderUri,
        existingSongs,
        scanPreferences,
      );
    } else if (_isAndroid) {
      final resolvedScanRoot = await _musicFolderService.resolveFilesystemPath(
        folderUri,
      );
      if (resolvedScanRoot != null && resolvedScanRoot.isNotEmpty) {
        deletedPaths = await _checkDeletedPathsRust(
          resolvedScanRoot,
          existingSongs,
          scanPreferences,
        );
      } else {
        devLog(
          'Skipping deletion check for $displayName: '
          'cannot resolve filesystem path',
        );
        return 0;
      }
    } else {
      deletedPaths = await _checkDeletedPathsRust(
        folderUri,
        existingSongs,
        scanPreferences,
      );
    }

    final missingPaths = deletedPaths.toSet();
    final idsToDelete = [
      for (final song in existingSongs)
        if (missingPaths.contains(song.filePath)) song.id,
    ];
    if (idsToDelete.isNotEmpty) {
      await _songRepository.deleteSongsByIds(idsToDelete);
      devLog('Deleted ${idsToDelete.length} missing songs from $displayName');
    }

    // Update folder stats
    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    _logScanTiming(
      displayName,
      'deletion refresh (${idsToDelete.length} removed)',
      stopwatch.elapsed,
    );

    return idsToDelete.length;
  }

  Future<List<String>> _checkDeletedPathsSaf(
    String folderUri,
    List<SongEntity> existingSongs,
    LibraryScanPreferences scanPreferences,
  ) async {
    final scanResult = await _musicFolderService.scanFolderDetailed(
      folderUri,
      filterNonMusicFilesAndFolders:
          scanPreferences.filterNonMusicFilesAndFolders,
    );
    if (!scanResult.rootAccessible || !scanResult.complete) {
      // Never interpret an unavailable or partial walk as a mass deletion.
      devLog(
        'Skipping SAF deletion check for $folderUri: '
        'rootAccessible=${scanResult.rootAccessible} '
        'complete=${scanResult.complete}',
      );
      return [];
    }
    final scannedUris = scanResult.files.map((f) => f.uri).toSet();
    // The SAF walk only speaks in SAF document URIs, so it can only vouch
    // for rows keyed the same way. Raw-path rows belong to the filesystem
    // engines and must not be judged here.
    return existingSongs
        .where((s) => _isDocumentInTree(s.filePath, folderUri))
        .where((s) => !scannedUris.contains(s.filePath))
        .map((s) => s.filePath)
        .toList();
  }

  Future<List<String>> _checkDeletedPathsRust(
    String rootPath,
    List<SongEntity> existingSongs,
    LibraryScanPreferences scanPreferences,
  ) async {
    final knownFiles = <String, int>{};
    for (final song in existingSongs) {
      // SAF-keyed rows live in a URI space the Rust walker cannot see;
      // handing them over would mark every one of them as deleted.
      if (song.filePath.startsWith('content://')) {
        continue;
      }
      if (song.lastModified != null) {
        knownFiles[song.filePath] = song.lastModified!.millisecondsSinceEpoch;
      }
    }

    final stopwatch = Stopwatch()..start();
    final result = await checkDeletedPaths(
      rootPath: rootPath,
      knownFiles: knownFiles,
      scanOptions: ScanOptions(
        filterNonMusicFilesAndFolders:
            scanPreferences.filterNonMusicFilesAndFolders,
        forceFullRescan: false,
      ),
    );
    if (Uac2PreferencesService.isDeveloperModeEnabledSync) {
      devLog(
        '[LibraryScanner] Rust deletion check (${knownFiles.length} known): '
        '${stopwatch.elapsed.inMilliseconds}ms, ${result.length} deleted',
      );
    }
    return result;
  }

  List<FolderEntity> _deduplicateFoldersForScan(List<FolderEntity> folders) {
    final sortedFolders = List<FolderEntity>.from(folders)
      ..sort((a, b) {
        final normalizedA = normalizeFolderIdentifier(a.uri);
        final normalizedB = normalizeFolderIdentifier(b.uri);
        final lengthCompare = normalizedA.length.compareTo(normalizedB.length);
        if (lengthCompare != 0) {
          return lengthCompare;
        }
        return normalizedA.compareTo(normalizedB);
      });

    final scheduledRoots = <String>{};
    final scanPlan = <FolderEntity>[];

    for (final folder in sortedFolders) {
      final normalized = normalizeFolderIdentifier(folder.uri);
      final overlapsExisting = scheduledRoots.any(
        (root) =>
            isSameOrDescendantFolder(normalized, root) ||
            isSameOrDescendantFolder(root, normalized),
      );
      if (overlapsExisting) {
        devLog(
          'Skipping overlapping scan root ${folder.displayName} (${folder.uri})',
        );
        continue;
      }
      scheduledRoots.add(normalized);
      scanPlan.add(folder);
    }

    return scanPlan;
  }

  String _extractTitleFromFilename(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    String name = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
    name = name.replaceFirst(RegExp(r'^\d{1,3}[\s._-]+'), '');
    name = name.replaceAll('_', ' ');
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Extensions MediaMetadataRetriever cannot reliably decode (WavPack:
  /// never, on any device; DSD: most OEM builds). Rows of these types get a
  /// second chance through the Rust parsers.
  static const _rustFallbackExtensions = {'wv', 'dsf', 'dff'};

  /// Decides whether a retriever result warrants a Rust parser retry.
  ///
  /// WavPack/DSD always retry. Other formats retry when the retriever could
  /// not establish the core stream layout (missing sample rate or duration) —
  /// OEM extractors have been seen failing on hi-res FLAC (HiOS, 192 kHz)
  /// while reporting the container bitrate. Missing bit depth alone is normal
  /// for lossy codecs and must not trigger a parse. Pure; unit-tested.
  static bool shouldRustRetryMetadata({
    required String extension,
    required bool hasMetadata,
    required bool hasSampleRate,
    required bool hasDuration,
  }) {
    if (_rustFallbackExtensions.contains(extension)) return true;
    return !hasMetadata || !hasSampleRate || !hasDuration;
  }

  /// Upper bound for staging a SAF document just to read its tags (256 MB).
  /// Larger files stay sparse in the SAF tier; playback staging is unaffected.
  static const _metadataStagingMaxBytes = 256 * 1024 * 1024;

  Future<List<AudioFileInfo>?> _fetchMetadataChunk(
    List<String> chunkUris, {
    Map<String, String>? rawPathByUri,
  }) async {
    try {
      final metadataList = await _musicFolderService.fetchMetadata(chunkUris);
      return await _fillRustMetadataFallback(
        metadataList,
        chunkUris,
        rawPathByUri: rawPathByUri,
      );
    } catch (e) {
      devLog('Error fetching metadata chunk (${chunkUris.length} files): $e');
      return null;
    }
  }

  /// For URIs whose retriever metadata came back unsolved, retry with the
  /// Rust parser (lofty / dsf-meta / dff-meta). WavPack and DSD always go
  /// through Rust; other formats escalate when the retriever failed to
  /// establish the stream layout (missing sample rate or duration). Raw-path
  /// URIs are read directly; content URIs stage through the shared cache
  /// with a size cap (or use a caller-supplied raw path when the DB row has
  /// one). Degrades silently — retriever results stand when Rust also fails.
  Future<List<AudioFileInfo>> _fillRustMetadataFallback(
    List<AudioFileInfo> metadataList,
    List<String> chunkUris, {
    Map<String, String>? rawPathByUri,
  }) async {
    if (chunkUris.isEmpty || !_isAndroid) return metadataList;

    final byUri = {for (final m in metadataList) m.uri: m};
    var changed = false;

    for (final uri in chunkUris) {
      if (_isCancelled) break;

      final meta = byUri[uri];
      final retrieverSolved =
          meta != null &&
          meta.duration != null &&
          meta.sampleRate != null &&
          meta.bitDepth != null &&
          meta.bitrate != null;
      // Android commonly omits standalone Vorbis/MP4 total tags even when it
      // can read the stream. Check them with Rust during this metadata pass;
      // the version marker prevents repeating the backfill on unchanged rows.
      final needsTotals = meta?.trackTotal == null || meta?.discTotal == null;
      if (retrieverSolved && !needsTotals) continue;

      if (!needsTotals && !shouldRustRetryMetadata(
        extension: _extensionOfUri(rawPathByUri?[uri] ?? uri),
        hasMetadata: meta != null,
        hasSampleRate: meta?.sampleRate != null,
        hasDuration: meta?.duration != null,
      )) {
        continue;
      }

      final rustMeta = await extractRustMetadataForUri(
        uri,
        rawPath: rawPathByUri?[uri],
      );
      if (rustMeta == null) continue;

      byUri[uri] = _mergeRustMetadata(meta, uri, rustMeta);
      changed = true;
    }

    if (!changed) return metadataList;

    // Preserve the original order; append entries for URIs the retriever
    // never returned (defensive — Kotlin always emits a row per URI).
    final result = <AudioFileInfo>[];
    final seen = <String>{};
    for (final m in metadataList) {
      result.add(byUri[m.uri] ?? m);
      seen.add(m.uri);
    }
    for (final uri in chunkUris) {
      if (!seen.contains(uri) && byUri.containsKey(uri)) {
        result.add(byUri[uri]!);
      }
    }
    return result;
  }

  String _extensionOfUri(String uri) {
    final path = rawPathFromFileUri(uri) ?? rawPathFromSafUri(uri) ?? uri;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  @visibleForTesting
  Future<AudioFileMetadata?> extractRustMetadataForUri(
    String uri, {
    String? rawPath,
  }) async {
    Future<AudioFileMetadata?> readMetadata(String path) async {
      try {
        return await extractFileMetadata(path: path);
      } catch (e) {
        devLog('Rust metadata fallback failed for $uri: $e');
        return null;
      }
    }

    final directPath =
        rawPathFromFileUri(uri) ?? rawPath ?? rawPathFromSafUri(uri);
    if (directPath != null) {
      final metadata = await readMetadata(directPath);
      if (metadata != null) return metadata;
    }
    if (!uri.startsWith('content://') || _isCancelled) return null;
    // A derived path can be valid but unreadable under scoped storage. The
    // document grant still lets Android copy the original bytes to the cache.
    final stagedPath = await _musicFolderService.cacheUriForPlayback(
      uri,
      extensionHint: _extensionOfUri(uri),
      maxSizeBytes: _metadataStagingMaxBytes,
    );
    return stagedPath == null ? null : await readMetadata(stagedPath);
  }

  AudioFileInfo _mergeRustMetadata(
    AudioFileInfo? base,
    String uri,
    AudioFileMetadata rust,
  ) {
    return AudioFileInfo(
      uri: uri,
      name: base?.name ?? '',
      size: base?.size ?? rust.fileSize.toInt(),
      lastModified: base?.lastModified ?? rust.lastModified.toInt(),
      mimeType: base?.mimeType,
      extension: base?.extension ?? rust.format,
      title: base?.title ?? rust.title,
      artist: base?.artist ?? rust.artist,
      album: base?.album ?? rust.album,
      albumArtist: base?.albumArtist,
      trackNumber: base?.trackNumber ?? rust.trackNumber,
      trackTotal: base?.trackTotal ?? rust.trackTotal,
      discNumber: base?.discNumber ?? rust.discNumber,
      discTotal: base?.discTotal ?? rust.discTotal,
      genre: base?.genre ?? rust.genre,
      duration: base?.duration ?? rust.durationMs?.toInt(),
      albumArtPath: base?.albumArtPath,
      // Call sites parse this as bits-per-second (retriever convention);
      // the Rust parsers report bits-per-second too.
      bitrate: base?.bitrate ?? rust.bitrate?.toString(),
      // Lofty reports plain-u32 rates for MP4, where a failed ALAC cookie
      // parse yields 0 — treat that as unsolved rather than "0 kHz".
      bitDepth:
          _positiveOrNull(base?.bitDepth) ?? _positiveOrNull(rust.bitDepth),
      sampleRate:
          _positiveOrNull(base?.sampleRate) ?? _positiveOrNull(rust.sampleRate),
      filePath: base?.filePath,
      year: base?.year ?? rust.year,
      dateAdded: base?.dateAdded,
      relativeFolderPath: base?.relativeFolderPath,
      metadataRead: true,
    );
  }

  static int? _positiveOrNull(int? value) =>
      value != null && value > 0 ? value : null;

  Future<void> _runDetachedScanTask(
    String displayName,
    String label,
    Future<void> Function() task,
  ) {
    final future = () async {
      final stopwatch = Stopwatch()..start();
      try {
        await task();
      } catch (e) {
        devLog('[LibraryScanner] $label failed for $displayName: $e');
      } finally {
        _logScanTiming(displayName, label, stopwatch.elapsed);
      }
    }();
    unawaited(future);
    return future;
  }

  void _logScanTiming(String displayName, String label, Duration elapsed) {
    if (!Uac2PreferencesService.isDeveloperModeEnabledSync) return;
    devLog('[LibraryScanner] $displayName $label: ${elapsed.inMilliseconds}ms');
  }

  /// Queues newly scanned songs onto the shared auto preload pass.
  Future<void> _preloadAudioData(List<SongEntity> songs) async {
    await AudioPreloadService.instance.enqueueAutoPreload(songs);
  }

  AudioFileInfo _audioInfoFromNonAudioMap(Map<String, dynamic> map) {
    return AudioFileInfo(
      uri: map['filePath'] as String? ?? '',
      name: map['name'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      lastModified: (map['lastModified'] as num?)?.toInt() ?? 0,
      extension: map['extension'] as String? ?? '',
    );
  }

  int _recommendedMetadataBatchSize(int pendingFiles) {
    return 100;
  }

  List<List<T>> _chunkList<T>(List<T> items, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      chunks.add(items.sublist(i, end));
    }
    return chunks;
  }

  Future<List<SongEntity>> _purgeExistingSongsFilteredByRules(
    List<SongEntity> existingSongs,
    LibraryScanPreferences scanPreferences,
  ) async {
    final filtered = existingSongs
        .where((song) => _shouldIgnoreStoredSong(song, scanPreferences))
        .toList();

    final ids = filtered.map((song) => song.id).toList();
    if (ids.isNotEmpty) {
      await _songRepository.deleteSongsByIds(ids);
    }

    return filtered;
  }

  bool _shouldIgnoreStoredSong(
    SongEntity song,
    LibraryScanPreferences scanPreferences,
  ) {
    return _shouldIgnoreDiscoveredTrack(
      fileSizeBytes: song.fileSize,
      durationMs: song.durationMs,
      scanPreferences: scanPreferences,
    );
  }

  bool _shouldIgnoreDiscoveredTrack({
    required int? fileSizeBytes,
    required int? durationMs,
    required LibraryScanPreferences scanPreferences,
  }) {
    if (scanPreferences.ignoreTracksSmallerThan500Kb &&
        fileSizeBytes != null &&
        fileSizeBytes > 0 &&
        fileSizeBytes < kIgnoredTrackMinSizeBytes) {
      return true;
    }

    if (scanPreferences.ignoreTracksShorterThan60Seconds &&
        durationMs != null &&
        durationMs > 0 &&
        durationMs < kIgnoredTrackMinDurationMs) {
      return true;
    }

    return false;
  }

  bool _looksLikeSupportedAudioExtension(String extension) {
    const supportedExtensions = {
      'mp3',
      'flac',
      'ogg',
      'oga',
      'ogx',
      'opus',
      'm4a',
      'wav',
      'aif',
      'aiff',
      'alac',
      'aac',
      'wma',
      'dsf',
      'dff',
      'wv',
    };

    return supportedExtensions.contains(extension.trim().toLowerCase());
  }

  Future<void> _syncPlaylistSourcesForFolder(
    String folderUri,
    LibraryScanPreferences scanPreferences, {
    String? scanRootPath,
  }) async {
    if (_isCancelled || !scanPreferences.createPlaylistsFromM3uFiles) {
      return;
    }

    try {
      final sources = scanRootPath != null && scanRootPath.isNotEmpty
          ? await _discoverRustPlaylistSources(
              scanRootPath,
              folderUri,
              scanPreferences,
            )
          : _isAndroid
          ? await _discoverAndroidPlaylistSources(folderUri, scanPreferences)
          : await _discoverRustPlaylistSources(
              folderUri,
              folderUri,
              scanPreferences,
            );
      if (sources.isEmpty) {
        return;
      }

      await _playlistService.syncPlaylistsFromSources(sources);
    } catch (e) {
      devLog('Failed to sync playlists from $folderUri: $e');
    }
  }

  Future<List<PlaylistSourceFile>> _discoverAndroidPlaylistSources(
    String folderUri,
    LibraryScanPreferences scanPreferences,
  ) async {
    final files = await _musicFolderService.scanPlaylistFiles(
      folderUri,
      filterNonMusicFilesAndFolders:
          scanPreferences.filterNonMusicFilesAndFolders,
    );

    return files
        .map(
          (file) =>
              PlaylistSourceFile(sourcePath: file.uri, displayName: file.name),
        )
        .toList();
  }

  Future<List<PlaylistSourceFile>> _discoverRustPlaylistSources(
    String scanRootPath,
    String folderUri,
    LibraryScanPreferences scanPreferences,
  ) async {
    final files = await discoverPlaylistFiles(
      rootPath: scanRootPath,
      scanOptions: ScanOptions(
        filterNonMusicFilesAndFolders:
            scanPreferences.filterNonMusicFilesAndFolders,
        forceFullRescan: false,
      ),
    );

    return files.map((path) => PlaylistSourceFile(sourcePath: path)).toList();
  }

  // ── CUE / Log helpers ──────────────────────────────────────────────

  Future<String?> _readTextFile(String uri) async {
    try {
      if (uri.startsWith('/') && File(uri).existsSync()) {
        return await File(uri).readAsString();
      }
      return await _storageChannel.invokeMethod<String>('readTextDocument', {
        'uri': uri,
      });
    } catch (e) {
      devLog('[LibraryScanner] Failed to read text file $uri: $e');
      return null;
    }
  }

  String _sidecarLookupPath(AudioFileInfo file) {
    if (file.filePath case final path?) return path;
    final relative = file.relativeFolderPath;
    if (relative == null || relative.isEmpty) return '/${file.name}';
    return '/$relative/${file.name}';
  }

  Future<Map<String, CueSheet>> _parseCueFilesAndroid(
    List<AudioFileInfo> cueFiles,
    Map<String, AudioFileInfo> fastScanMap, {
    void Function()? onReadFailure,
  }) async {
    final cueService = CueFileService();
    final result = <String, CueSheet>{};
    final audioFilesByDir = <String, Map<String, String>>{};
    for (final file in fastScanMap.values) {
      if (!_looksLikeSupportedAudioExtension(file.extension)) continue;
      final path = _sidecarLookupPath(file);
      final slash = path.lastIndexOf('/');
      final directory = slash < 0 ? '' : path.substring(0, slash);
      audioFilesByDir.putIfAbsent(directory, () => {})[file.name.toLowerCase()] =
          file.filePath ?? file.uri;
    }
    for (final cue in cueFiles) {
      final content = await _readTextFile(cue.uri);
      if (content == null) {
        onReadFailure?.call();
        continue;
      }
      if (content.isEmpty) continue;
      final sheets = cueService.parseCueSheets(content, cueFilePath: cue.uri);
      for (final sheet in sheets) {
        final audioUri = resolveCueAudioPath(
          cuePath: _sidecarLookupPath(cue),
          audioFile: sheet.audioFile,
          audioFilesByDir: audioFilesByDir,
        );
        if (audioUri != null) {
          result[audioUri] = sheet;
        }
      }
    }
    return result;
  }

  Future<Map<String, RipLog>> _parseLogFilesAndroid(
    List<AudioFileInfo> logFiles,
    Map<String, AudioFileInfo> fastScanMap,
  ) async {
    final logService = RipLogService();
    final result = <String, RipLog>{};
    for (final log in logFiles) {
      final content = await _readTextFile(log.uri);
      if (content == null || content.isEmpty) continue;
      final ripLog = logService.parseLog(content);
      if (ripLog == null) continue;
      final logStem = _fileStem(log.name).toLowerCase();
      for (final entry in fastScanMap.values) {
        if (_looksLikeSupportedAudioExtension(entry.extension)) {
          final audioStem = _fileStem(entry.name).toLowerCase();
          if (audioStem == logStem) {
            result[entry.filePath ?? entry.uri] = ripLog;
            break;
          }
        }
      }
    }
    return result;
  }

  Future<({Map<String, CueSheet> cueMap, Map<String, RipLog> logMap})>
  _parseCueAndLogFilesRust(String scanRootPath) async {
    final cueService = CueFileService();
    final logService = RipLogService();
    final cueMap = <String, CueSheet>{};
    final result = <String, RipLog>{};
    try {
      final dir = Directory(scanRootPath);
      if (!dir.existsSync()) return (cueMap: cueMap, logMap: result);

      // Single walk — collect audio stems, cue files, log files simultaneously
      final cueFiles = <String>[];
      final logFiles = <String>[];
      final audioStems = <String, String>{};
      final audioFilesByDir = <String, Map<String, String>>{};

      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (_isCancelled) break;
        if (entity is! File) continue;
        final path = entity.path;
        final ext = path.split('.').last.toLowerCase();
        final name = path.split('/').last;

        if (_looksLikeSupportedAudioExtension(ext)) {
          audioStems[_fileStem(name).toLowerCase()] = path;
          final sep = path.lastIndexOf('/');
          final dirPath = sep == -1 ? '' : path.substring(0, sep);
          audioFilesByDir.putIfAbsent(dirPath, () => {})[name.toLowerCase()] =
              path;
        } else if (ext == 'cue') {
          cueFiles.add(path);
        } else if (ext == 'log' || ext == 'txt') {
          logFiles.add(path);
        }
      }

      // Parse CUE files
      for (final path in cueFiles) {
        if (_isCancelled) break;
        final content = await File(path).readAsString().catchError((_) => '');
        if (content.isEmpty) continue;
        final sheets = cueService.parseCueSheets(content, cueFilePath: path);
        for (final sheet in sheets) {
          final audioPath = resolveCueAudioPath(
            cuePath: path,
            audioFile: sheet.audioFile,
            audioFilesByDir: audioFilesByDir,
          );
          if (audioPath == null) continue;
          cueMap[audioPath] = sheet;
        }
      }

      // Parse log files
      for (final path in logFiles) {
        if (_isCancelled) break;
        final content = await File(path).readAsString().catchError((_) => '');
        if (content.isEmpty) continue;
        final ripLog = logService.parseLog(content);
        if (ripLog == null) continue;
        final stem = _fileStem(path.split('/').last).toLowerCase();
        final audioPath = audioStems[stem];
        if (audioPath != null) {
          result[audioPath] = ripLog;
        }
      }
    } catch (e) {
      devLog('[LibraryScanner] Error scanning for CUE/log files: $e');
    }
    return (cueMap: cueMap, logMap: result);
  }

  static String _fileStem(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot <= 0) return fileName;
    return fileName.substring(0, lastDot);
  }

  /// Resolve a CUE `FILE` entry to an audio file discovered in the same scan.
  ///
  /// Exact names win. A unique same-stem sibling is accepted as well so a
  /// converted rip with a stale `.wav` entry still binds to its `.flac` file;
  /// ambiguous or missing names are treated as unresolved instead of creating
  /// rows for paths that do not exist.
  @visibleForTesting
  static String? resolveCueAudioPath({
    required String cuePath,
    required String audioFile,
    required Map<String, Map<String, String>> audioFilesByDir,
  }) {
    final resolved = CueFileService().resolveAudioFilePath(cuePath, audioFile);
    final slash = resolved.lastIndexOf('/');
    final dir = slash == -1 ? '' : resolved.substring(0, slash);
    final name = (slash == -1 ? resolved : resolved.substring(slash + 1))
        .toLowerCase();
    final files = audioFilesByDir[dir];
    if (files == null) return null;

    final exact = files[name];
    if (exact != null) return exact;

    final stem = _fileStem(name);
    String? match;
    for (final entry in files.entries) {
      if (_fileStem(entry.key) != stem) continue;
      if (match != null) return null;
      match = entry.value;
    }
    return match;
  }

  /// Only a successful read can complete the versioned tag backfill.
  static int _metadataVersionFor(AudioFileInfo? meta, SongEntity? existing) {
    return meta?.metadataRead == true
        ? kCurrentTrackMetadataVersion
        : (existing?.metadataVersion ?? 0);
  }

  @visibleForTesting
  static bool needsMetadataBackfill(
    Iterable<SongEntity> songs, {
    Iterable<SongEntity> excludedSongs = const [],
  }) {
    final excluded = excludedSongs.toSet();
    return songs.any(
      (song) => !excluded.contains(song) &&
          song.metadataVersion < kCurrentTrackMetadataVersion,
    );
  }

  /// Refresh totals independently of user-edited titles and track numbers.
  /// A successful read with absent tags must also clear stale cached totals.
  @visibleForTesting
  static void applyTrackTotals(SongEntity song, AudioFileInfo metadata) {
    if (!metadata.metadataRead) return;
    song.trackTotal = metadata.trackTotal;
    song.discTotal = metadata.discTotal;
    song.metadataVersion = kCurrentTrackMetadataVersion;
  }

  /// When an existing song has `hasLocalEdits == true`, preserve its text
  /// metadata fields instead of overwriting them with scanned file tags.
  void _preserveLocalEdits(SongEntity song, SongEntity? existing) {
    if (existing == null || !existing.hasLocalEdits) return;
    song.title = existing.title;
    song.artist = existing.artist;
    song.album = existing.album;
    song.albumArtist = existing.albumArtist;
    song.genre = existing.genre;
    song.year = existing.year;
    song.trackNumber = existing.trackNumber;
    song.discNumber = existing.discNumber;
    song.hasLocalEdits = true;
  }

  /// Whether an existing artwork pointer can safely move to a rebuilt row.
  /// User-picked overrides always survive; auto-resolved art only while the
  /// source file is unchanged, so a re-tagged file drops the pointer and the
  /// post-scan backfill re-derives its cover from the current tags.
  @visibleForTesting
  static bool canCarryArtworkPointer({
    required String? albumArtPath,
    required bool isCustom,
    required DateTime? existingLastModified,
    required int? existingFileSize,
    required DateTime? lastModified,
    required int? fileSize,
  }) {
    if (albumArtPath == null || albumArtPath.isEmpty) return false;
    if (isCustom) return true;
    final sameTimestamp = existingLastModified == lastModified;
    final sameSize = fileSize == null || existingFileSize == fileSize;
    return sameTimestamp && sameSize;
  }

  String? _carriedArtworkPath(
    SongEntity? existing, {
    required DateTime? lastModified,
    required int? fileSize,
  }) {
    final path = existing?.albumArtPath;
    if (existing == null || path == null || path.isEmpty) return null;
    final carried = canCarryArtworkPointer(
      albumArtPath: path,
      isCustom: AlbumArtImportService.instance.isCustomArtworkPath(path),
      existingLastModified: existing.lastModified,
      existingFileSize: existing.fileSize,
      lastModified: lastModified,
      fileSize: fileSize,
    );
    if (!carried) {
      devLog(
        '[LibraryScanner] dropped stale artwork pointer for '
        '${existing.filePath}',
      );
    }
    return carried ? path : null;
  }

  List<SongEntity> _buildCueTrackEntities({
    required String audioUri,
    required CueSheet cueSheet,
    required AudioFileInfo? meta,
    required String folderUri,
    required Map<String, SongEntity> existingMap,
    required RipLog? ripLog,
    required DateTime lastModified,
    String? relativeFolderPath,
  }) {
    final entities = <SongEntity>[];
    final seenStartOffsets = <int>{};
    for (final track in cueSheet.tracks) {
      // SongEntity is unique on (filePath, startOffsetMs). Malformed sheets can
      // repeat an INDEX time; keep the first track instead of aborting the
      // whole bulk upsert with a unique-index violation.
      if (!seenStartOffsets.add(track.startOffsetMs)) continue;
      final artist = track.performer.trim().isNotEmpty
          ? track.performer.trim()
          : (cueSheet.performer?.trim().isNotEmpty ?? false)
          ? cueSheet.performer!.trim()
          : (meta?.artist?.trim().isNotEmpty ?? false)
          ? meta!.artist!.trim()
          : l10n.unknownArtist;
      final existing = existingMap['$audioUri#${track.startOffsetMs}'];
      final trackLog = ripLog?.tracks.firstWhere(
        (t) => t.trackNumber == track.trackNumber,
        orElse: () => const RipLogTrack(trackNumber: -1),
      );
      final entity = SongEntity()
        ..filePath = audioUri
        ..mediaStoreUri = meta?.uri.startsWith('content://') == true
            ? meta!.uri
            : null
        ..startOffsetMs = track.startOffsetMs
        ..endOffsetMs = track.endOffsetMs
        ..title = track.title.trim().isNotEmpty
            ? track.title.trim()
            : _extractTitleFromFilename(
                meta?.name ?? 'Track ${track.trackNumber}',
              )
        ..artist = artist
        ..album = cueSheet.title?.trim().isNotEmpty ?? false
            ? cueSheet.title!.trim()
            : (meta?.album?.trim().isNotEmpty ?? false)
            ? meta!.album!.trim()
            : l10n.unknownAlbum
        ..albumArtist = cueSheet.performer?.trim().isNotEmpty ?? false
            ? cueSheet.performer!.trim()
            : artist
        ..trackNumber = track.trackNumber
        ..trackTotal = meta?.trackTotal ?? cueSheet.tracks.length
        ..discNumber = meta?.discNumber ?? 1
        ..discTotal = meta?.discTotal
        ..durationMs = track.durationMs(sourceDurationMs: meta?.duration)
        ..fileType = meta?.extension.toUpperCase() ?? 'UNKNOWN'
        ..dateAdded = existing?.dateAdded ?? DateTime.now()
        ..lastModified = lastModified
        ..folderUri = folderUri
        ..relativeFolderPath = relativeFolderPath
        ..fileSize = meta?.size ?? 0
        ..albumArtPath = _carriedArtworkPath(
          existing,
          lastModified: lastModified,
          fileSize: meta?.size,
        )
        ..bitrate = meta?.bitrate != null
            ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                int.tryParse(meta!.bitrate!),
              )
            : null
        ..bitDepth = meta?.bitDepth
        ..sampleRate = meta?.sampleRate
        ..genre = (cueSheet.genre?.trim().isNotEmpty ?? false)
            ? cueSheet.genre!.trim()
            : (meta?.genre?.trim().isNotEmpty ?? false)
            ? meta!.genre!.trim()
            : null
        ..year = int.tryParse(cueSheet.date ?? '') ?? meta?.year
        ..ripper = ripLog?.ripper
        ..readMode = ripLog?.readMode
        ..accurateRip = trackLog?.trackNumber == track.trackNumber
            ? trackLog?.accurate
            : null
        ..testCrc = trackLog?.trackNumber == track.trackNumber
            ? trackLog?.testCrc
            : null
        ..copyCrc = trackLog?.trackNumber == track.trackNumber
            ? trackLog?.copyCrc
            : null
        ..metadataComplete = meta?.sampleRate != null && meta?.bitDepth != null
        ..metadataVersion = kCurrentTrackMetadataVersion;

      if (existing != null) {
        entity.id = existing.id;
        _preserveLocalEdits(entity, existing);
      }
      entities.add(entity);
    }
    return entities;
  }
}
