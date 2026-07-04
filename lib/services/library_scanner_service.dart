import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../core/utils/audio_metadata_utils.dart';
import '../data/database.dart';
import '../data/repositories/song_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../services/music_folder_service.dart';
import '../services/library_scan_preferences_service.dart';
import '../services/playlist_service.dart';
import '../services/cue_file_service.dart';
import '../services/rip_log_service.dart';
import '../services/fingerprint_cache_service.dart';
import '../services/uac2_preferences_service.dart';
import '../src/rust/api/scanner.dart'; // Rust bridge
import 'package:flick/core/utils/dev_log.dart';

/// Progress update during library scanning.
class ScanProgress {
  final int songsFound;
  final int totalFiles;
  final String? currentFile;
  final String? currentFolder;
  final bool isComplete;
  final bool unavailable;

  ScanProgress({
    required this.songsFound,
    required this.totalFiles,
    this.currentFile,
    this.currentFolder,
    this.isComplete = false,
    this.unavailable = false,
  });
}

/// Service for scanning music folders and indexing songs in the database.
class LibraryScannerService {
  final SongRepository _songRepository;
  final FolderRepository _folderRepository;
  final MusicFolderService _musicFolderService;
  final LibraryScanPreferencesService _scanPreferencesService;
  final PlaylistService _playlistService;
  final FileFingerprintCache _fingerprintCache = FileFingerprintCache();

  bool _isCancelled = false;
  final Set<String> _currentlyScanning = {};

  static const MethodChannel _storageChannel = MethodChannel(
    'com.mossapps.flick/storage',
  );

  LibraryScannerService({
    SongRepository? songRepository,
    FolderRepository? folderRepository,
    MusicFolderService? musicFolderService,
    LibraryScanPreferencesService? scanPreferencesService,
    PlaylistService? playlistService,
  }) : _songRepository = songRepository ?? SongRepository(),
       _folderRepository = folderRepository ?? FolderRepository(),
       _musicFolderService = musicFolderService ?? MusicFolderService(),
       _scanPreferencesService =
           scanPreferencesService ?? LibraryScanPreferencesService(),
       _playlistService = playlistService ?? PlaylistService();

  void cancelScan() {
    _isCancelled = true;
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

  /// Scan a single folder using appropriate method for platform.
  Stream<ScanProgress> scanFolder(String folderUri, String displayName) async* {
    final scanStopwatch = Stopwatch()..start();
    final scanKey = normalizeFolderIdentifier(folderUri);
    final scanPreferences = await _scanPreferencesService.getPreferences();

    if (_currentlyScanning.contains(scanKey)) {
      devLog('Folder $displayName is already being scanned, skipping...');
      return;
    }

    _currentlyScanning.add(scanKey);
    try {
      if (Platform.isAndroid) {
        final storageInfo = await _musicFolderService.resolveStorageInfo(
          folderUri,
        );
        final resolvedScanRoot = storageInfo.fsPath;

        final folderEntity = await _folderRepository.getFolderByUri(folderUri);
        final useDeepScan =
            folderEntity?.useDeepScan ?? scanPreferences.useDeepScan;

        // Lazy migration: backfill volume metadata for pre-feature folders.
        if (folderEntity != null && folderEntity.mediaStoreVolume == null) {
          await _backfillFolderStorageInfo(folderEntity, storageInfo);
        }

        // Unplugged removable storage: retain songs, mark unavailable, skip scan.
        if (storageInfo.isRemovable && !storageInfo.isMounted) {
          devLog(
            'Skipping scan for $displayName: removable storage not mounted '
            '("${storageInfo.state}"), songs retained',
          );
          if (folderEntity != null) {
            await _folderRepository.updateFolderVolumeState(
              folderUri,
              storageInfo.state,
            );
          }
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

        if (useDeepScan) {
          // Rust can't read scoped raw paths on removable storage; use SAF
          // (MediaMetadataRetriever) for full metadata there.
          if (storageInfo.isRemovable) {
            devLog(
              'Deep scan requested for $displayName but it is on removable '
              'storage; Rust cannot read scoped raw paths, using SAF',
            );
          } else if (resolvedScanRoot != null &&
              resolvedScanRoot.isNotEmpty) {
            try {
              yield* _scanFolderRust(
                resolvedScanRoot,
                folderUri,
                displayName,
                scanPreferences,
              );
              _logScanTiming(
                displayName,
                'scan folder (Rust deep scan)',
                scanStopwatch.elapsed,
              );
              return;
            } catch (e) {
              devLog(
                'Rust deep scan failed for $displayName at $resolvedScanRoot: $e, '
                'falling back to SAF',
              );
            }
          } else {
            devLog(
              'Deep scan requested for $displayName but no filesystem path '
              'resolvable, falling back to SAF',
            );
          }

          yield* _scanFolderAndroid(folderUri, displayName, scanPreferences);
          _logScanTiming(displayName, 'scan folder (SAF)', scanStopwatch.elapsed);
        } else {
          if (resolvedScanRoot != null && resolvedScanRoot.isNotEmpty) {
            try {
              yield* _scanFolderMediaStore(
                resolvedScanRoot,
                folderUri,
                displayName,
                scanPreferences,
                volumeName: storageInfo.mediaStoreVolume,
              );
              _logScanTiming(
                displayName,
                'scan folder (MediaStore)',
                scanStopwatch.elapsed,
              );
              return;
            } catch (e) {
              devLog(
                'MediaStore scan failed for $displayName at $resolvedScanRoot: $e, '
                'falling back to SAF',
              );
            }
          }

          yield* _scanFolderAndroid(
            folderUri,
            displayName,
            scanPreferences,
            deferMetadata: true,
          );
          _logScanTiming(displayName, 'scan folder (SAF)', scanStopwatch.elapsed);
        }
      } else {
        yield* _scanFolderRust(
          folderUri,
          folderUri,
          displayName,
          scanPreferences,
        );
        _logScanTiming(
          displayName,
          'scan folder (Rust)',
          scanStopwatch.elapsed,
        );
      }
    } finally {
      _currentlyScanning.remove(scanKey);
    }
  }

  Stream<ScanProgress> _scanFolderMediaStore(
    String folderPath,
    String folderUri,
    String displayName,
    LibraryScanPreferences scanPreferences, {
    String? volumeName,
  }) async* {
    _isCancelled = false;
    final totalStopwatch = Stopwatch()..start();
    yield ScanProgress(
      songsFound: 0,
      totalFiles: 0,
      currentFolder: displayName,
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
      devLog("MediaStore audio query failed for $displayName: $e");
      return;
    }

    if (_isCancelled) return;

    final dbLoadStopwatch = Stopwatch()..start();
    final existingSongs = await _songRepository.getSongEntitiesByFolder(
      folderUri,
    );
    _logScanTiming(displayName, 'existing DB load', dbLoadStopwatch.elapsed);

    final filteredExistingSongs = await _purgeExistingSongsFilteredByRules(
      existingSongs,
      scanPreferences,
    );

    final rawExistingMap = <String, SongEntity>{};
    final existingByContentUri = <String, SongEntity>{};
    for (var s in existingSongs) {
      if (s.startOffsetMs == null) {
        rawExistingMap[s.filePath] = s;
      }
      if (s.filePath.startsWith('content://')) {
        existingByContentUri[s.filePath] = s;
      }
      final mediaStoreUri = s.mediaStoreUri;
      if (mediaStoreUri != null && mediaStoreUri.isNotEmpty) {
        existingByContentUri[mediaStoreUri] = s;
      }
    }
    for (final song in filteredExistingSongs) {
      existingByContentUri.remove(song.filePath);
      existingByContentUri.remove(song.mediaStoreUri);
      rawExistingMap.remove(song.filePath);
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

    final filteredSongIds = filteredExistingSongs
        .map((song) => song.id)
        .toSet();
    final idsToDelete = <int>[];
    for (final song in existingSongs) {
      if (filteredSongIds.contains(song.id)) continue;

      final mediaStoreUri = song.mediaStoreUri;
      final isKnown =
          allKnownPaths.contains(song.filePath) ||
          (mediaStoreUri != null && allKnownPaths.contains(mediaStoreUri));
      if (!isKnown) idsToDelete.add(song.id);
    }

    if (idsToDelete.isNotEmpty) {
      await _songRepository.deleteSongsByIds(idsToDelete);
    }

    final urisNeedingSparseMetadata = <String>[];
    final batch = <SongEntity>[];
    final idsToDeleteInline = <int>[];
    final diffStopwatch = Stopwatch()..start();

    for (final file in mediaStoreFiles) {
      final lookupKey = file.filePath ?? file.uri;
      final existing =
          rawExistingMap[lookupKey] ?? existingByContentUri[file.uri];

      if (existing != null) {
        final existingTime = existing.lastModified?.millisecondsSinceEpoch ?? 0;
        if (file.lastModified == existingTime && existing.metadataComplete) {
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
          existing == null ||
          existing.sampleRate == null ||
          existing.bitDepth == null ||
          existing.discNumber == null;

      final artist = (file.artist?.trim().isNotEmpty ?? false)
          ? file.artist!.trim()
          : 'Unknown Artist';
      final song = SongEntity()
        ..filePath = file.filePath ?? file.uri
        ..mediaStoreUri = file.uri
        ..title = (file.title?.trim().isNotEmpty ?? false)
            ? file.title!.trim()
            : _extractTitleFromFilename(file.name)
        ..artist = artist
        ..album = (file.album?.trim().isNotEmpty ?? false)
            ? file.album!.trim()
            : 'Unknown Album'
        ..albumArtist = (file.albumArtist?.trim().isNotEmpty ?? false)
            ? file.albumArtist!.trim()
            : artist
        ..trackNumber = file.trackNumber ?? 0
        ..discNumber = file.discNumber ?? 1
        ..durationMs = file.duration ?? 0
        ..fileType = file.extension.toUpperCase()
        ..dateAdded =
            existing?.dateAdded ??
            (file.dateAdded != null
                ? DateTime.fromMillisecondsSinceEpoch(file.dateAdded!)
                : DateTime.now())
        ..lastModified = DateTime.fromMillisecondsSinceEpoch(file.lastModified)
        ..folderUri = folderUri
        ..fileSize = file.size
        ..albumArtPath = existing?.albumArtPath
        ..bitrate = file.bitrate != null
            ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                int.tryParse(file.bitrate!),
              )
            : null
        ..bitDepth = file.bitDepth
        ..sampleRate = file.sampleRate
        ..year = file.year
        ..ripper = existing?.ripper
        ..readMode = existing?.readMode
        ..accurateRip = existing?.accurateRip
        ..metadataComplete = !needsSparseMetadata;

      if (existing != null) {
        song.id = existing.id;
        _preserveLocalEdits(song, existing);
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
      currentFolder: displayName,
      isComplete: false,
    );

    if (urisNeedingSparseMetadata.isNotEmpty) {
      _runDetachedScanTask(
        displayName,
        'sparse metadata',
        () => _extractSparseMetadataInBackground(
          urisNeedingSparseMetadata,
          folderUri,
          displayName,
        ),
      );
    }

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

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
    );
    _runDetachedScanTask(
      displayName,
      'playlist sync',
      () => _syncPlaylistSourcesForFolder(
        folderUri,
        scanPreferences,
        scanRootPath: folderPath,
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
      currentFolder: displayName,
      isComplete: true,
    );
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
    for (final s in songsByUri) {
      pathMap[s.filePath] = s;
      final mediaStoreUri = s.mediaStoreUri;
      if (mediaStoreUri != null && mediaStoreUri.isNotEmpty) {
        pathMap[mediaStoreUri] = s;
      }
    }

    for (final chunkUris in metadataChunks) {
      if (_isCancelled) break;

      final stopwatch = Stopwatch()..start();
      final metadataList = await _fetchMetadataChunk(chunkUris);
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
        if (!existing.hasLocalEdits) {
          existing.discNumber = meta.discNumber ?? existing.discNumber;
          existing.albumArtist =
              (meta.albumArtist?.trim().isNotEmpty ?? false)
                  ? meta.albumArtist!.trim()
                  : existing.albumArtist;
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

    final allScannedPaths = scannedByPath.keys.toSet();
    final audioFilesWithCue = cueMap.keys.toSet();
    final existingCuePaths = existingSongs
        .where((s) => s.startOffsetMs != null)
        .map((s) => s.filePath)
        .toSet();
    final orphanedCuePaths = existingCuePaths
        .where(
          (p) => allScannedPaths.contains(p) && !audioFilesWithCue.contains(p),
        )
        .toList();
    if (orphanedCuePaths.isNotEmpty) {
      await _songRepository.deleteCueTracksByPath(orphanedCuePaths);
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
  // ponytail: CUE track splitting is deferred to deep scan; instant creates
  // raw entities per audio file. Acceptable since CUE albums on USB are rare.
  Stream<ScanProgress> _scanFolderAndroidInstant({
    required String folderUri,
    required String displayName,
    required Map<String, AudioFileInfo> fastScanMap,
    required Map<String, SongEntity> existingMap,
    required List<String> urisToProcess,
    required int initialSongCount,
    required int totalFiles,
    required Stopwatch totalStopwatch,
    required LibraryScanPreferences scanPreferences,
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
          ..mediaStoreUri =
              basic.uri.startsWith('content://') ? basic.uri : null
          ..title = _extractTitleFromFilename(basic.name)
          ..artist = 'Unknown Artist'
          ..album = 'Unknown Album'
          ..albumArtist = 'Unknown Artist'
          ..trackNumber = 0
          ..discNumber = 1
          ..durationMs = 0
          ..fileType = basic.extension.toUpperCase()
          ..dateAdded = DateTime.now()
          ..lastModified = DateTime.fromMillisecondsSinceEpoch(
            basic.lastModified,
          )
          ..folderUri = folderUri
          ..fileSize = basic.size
          ..metadataComplete = false,
      );
    }

    if (newBatch.isNotEmpty) {
      await _songRepository.upsertSongs(newBatch);
    }

    yield ScanProgress(
      songsFound: initialSongCount + newBatch.length,
      totalFiles: totalFiles,
      currentFolder: displayName,
      isComplete: false,
    );

    _runDetachedScanTask(
      displayName,
      'deferred metadata',
      () => _enrichSafMetadataInBackground(
        uris: urisToProcess,
        folderUri: folderUri,
        displayName: displayName,
        scanPreferences: scanPreferences,
      ),
    );

    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    _runDetachedScanTask(
      displayName,
      'SAF playlist sync',
      () => _syncPlaylistSourcesForFolder(folderUri, scanPreferences),
    );

    _logScanTiming(displayName, 'SAF scan total', totalStopwatch.elapsed);

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      currentFolder: displayName,
      isComplete: true,
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
        existing.metadataComplete =
            meta.sampleRate != null && meta.bitDepth != null;

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
          existing.albumArtist =
              (meta.albumArtist?.trim().isNotEmpty ?? false)
                  ? meta.albumArtist!.trim()
                  : existing.artist;
          existing.trackNumber = meta.trackNumber ?? existing.trackNumber;
          existing.discNumber = meta.discNumber ?? existing.discNumber;
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
  }) async* {
    _isCancelled = false;
    final totalStopwatch = Stopwatch()..start();
    yield ScanProgress(
      songsFound: 0,
      totalFiles: 0,
      currentFolder: displayName,
      isComplete: false,
    );

    // 1. Fast Scan: Get all files with basic info only
    List<AudioFileInfo> fastScanFiles = [];
    try {
      final stopwatch = Stopwatch()..start();
      fastScanFiles = await _musicFolderService.scanFolder(
        folderUri,
        filterNonMusicFilesAndFolders:
            scanPreferences.filterNonMusicFilesAndFolders,
      );
      _logScanTiming(displayName, 'SAF fast scan', stopwatch.elapsed);
    } catch (e) {
      devLog("Error scanning Android folder: $e");
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
    // Build two maps: one for raw entities (no startOffsetMs), one for
    // file-existence checks. The old collapsible map lost raw entities
    // when CUE tracks shared the same filePath, keeping stale raw rows.
    final rawExistingMap = <String, SongEntity>{};
    final existingMap = <String, SongEntity>{};
    for (var s in existingSongs) {
      if (s.startOffsetMs == null) {
        rawExistingMap[s.filePath] = s;
      }
      existingMap[s.filePath] = s;
    }
    for (final song in filteredExistingSongs) {
      existingMap.remove(song.filePath);
      rawExistingMap.remove(song.filePath);
    }
    final fastScanMap = {for (var f in fastScanFiles) f.uri: f};

    // 2b. Parse CUE and log files
    final cueFiles = fastScanFiles
        .where((f) => f.extension.toLowerCase() == 'cue')
        .toList();
    final logFiles = fastScanFiles.where((f) {
      final ext = f.extension.toLowerCase();
      return ext == 'log' || ext == 'txt';
    }).toList();

    final sidecarStopwatch = Stopwatch()..start();
    final cueMap = cueFiles.isNotEmpty
        ? await _parseCueFilesAndroid(cueFiles, fastScanMap)
        : <String, CueSheet>{};
    final logMap = logFiles.isNotEmpty
        ? await _parseLogFilesAndroid(logFiles, fastScanMap)
        : <String, RipLog>{};
    _logScanTiming(displayName, 'SAF CUE/log parse', sidecarStopwatch.elapsed);

    // Calculate variations
    final scannedUris = fastScanMap.keys.toSet();

    // Deletions: in DB but not in scan
    final urisToDelete = existingMap.keys
        .where((uri) => !scannedUris.contains(uri))
        .toList();

    if (urisToDelete.isNotEmpty) {
      final idsToDelete = urisToDelete
          .map((uri) => existingMap[uri]?.id)
          .whereType<int>()
          .toList();
      if (idsToDelete.isNotEmpty) {
        await _songRepository.deleteSongsByIds(idsToDelete);
      } else {
        await _songRepository.deleteSongsByPath(urisToDelete);
      }
    }

    // Delete orphaned CUE tracks (audio file in scan but no CUE file)
    final audioFilesWithCue = cueMap.keys.toSet();
    final existingCuePaths = existingSongs
        .where((s) => s.startOffsetMs != null)
        .map((s) => s.filePath)
        .toSet();
    final orphanedCuePaths = existingCuePaths
        .where((p) => scannedUris.contains(p) && !audioFilesWithCue.contains(p))
        .toList();
    if (orphanedCuePaths.isNotEmpty) {
      await _songRepository.deleteCueTracksByPath(orphanedCuePaths);
    }

    // Updates: New files or Modified files
    final urisToProcess = <String>[];
    for (final file in fastScanFiles) {
      final existing = existingMap[file.uri];
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
            fileTypeMismatch;

        if (file.lastModified != existingTime || missingMetadata) {
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
    int initialSongCount = existingMap.length - urisToDelete.length;

    // Report initial state after diff
    yield ScanProgress(
      songsFound: initialSongCount,
      totalFiles: totalFiles,
      currentFolder: displayName,
      isComplete: false,
    );

    if (deferMetadata) {
      yield* _scanFolderAndroidInstant(
        folderUri: folderUri,
        displayName: displayName,
        fastScanMap: fastScanMap,
        existingMap: existingMap,
        urisToProcess: urisToProcess,
        initialSongCount: initialSongCount,
        totalFiles: totalFiles,
        totalStopwatch: totalStopwatch,
        scanPreferences: scanPreferences,
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
        final existing = existingMap[basic.uri];
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
          final cueTracksInDb = existingSongs.where(
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
            : 'Unknown Artist';
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
              : 'Unknown Album'
          ..albumArtist = (meta?.albumArtist?.trim().isNotEmpty ?? false)
              ? meta!.albumArtist!.trim()
              : artist
          ..trackNumber = meta?.trackNumber ?? 0
          ..discNumber = meta?.discNumber ?? 1
          ..durationMs = meta?.duration ?? 0
          ..fileType = basic.extension.toUpperCase()
          ..dateAdded = existingMap[basic.uri]?.dateAdded ?? DateTime.now()
          ..lastModified = DateTime.fromMillisecondsSinceEpoch(
            basic.lastModified,
          )
          ..folderUri = folderUri
          ..fileSize = basic.size
          ..albumArtPath = existingMap[basic.uri]?.albumArtPath
          ..bitrate = meta?.bitrate != null
              ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                  int.tryParse(meta!.bitrate!),
                )
              : null
          ..bitDepth = meta?.bitDepth
          ..sampleRate = meta?.sampleRate
          ..ripper = ripLog?.ripper
          ..readMode = ripLog?.readMode
          ..accurateRip = ripLog?.accurateRipEnabled
          ..metadataComplete =
              meta?.sampleRate != null && meta?.bitDepth != null;

        if (existing != null) {
          song.id = existing.id;
          _preserveLocalEdits(song, existing);
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

      if (batch.isNotEmpty) {
        await _songRepository.upsertSongs(batch);
      }

      processed += batch.length;

      yield ScanProgress(
        songsFound: initialSongCount + processed,
        totalFiles: totalFiles,
        currentFile: batch.isNotEmpty ? batch.last.title : null,
        currentFolder: displayName,
        isComplete: false,
      );
    }

    // Update folder stats
    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    _runDetachedScanTask(
      displayName,
      'SAF playlist sync',
      () => _syncPlaylistSourcesForFolder(folderUri, scanPreferences),
    );

    _logScanTiming(displayName, 'SAF scan total', totalStopwatch.elapsed);

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      currentFolder: displayName,
      isComplete: true,
    );
  }

  Stream<ScanProgress> _scanFolderRust(
    String scanRootPath,
    String folderUri,
    String displayName,
    LibraryScanPreferences scanPreferences,
  ) async* {
    _isCancelled = false;
    final totalStopwatch = Stopwatch()..start();

    yield ScanProgress(
      songsFound: 0,
      totalFiles: 0,
      currentFolder: displayName,
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

    // Load fingerprint cache — supplements DB with faster lookup
    final cachedFingerprints = await _fingerprintCache.load(folderUri);

    for (var song in existingSongs) {
      if (filteredExistingSongs.contains(song)) {
        continue;
      }
      existingMap[song.filePath] = song;
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

    // 2. Stream scan batches from Rust
    int processed = 0;
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
      ),
    )) {
      if (_isCancelled) {
        break;
      }

      totalFiles = chunk.totalFiles;

      if (!initialProgressSent) {
        deletedPaths.addAll(chunk.deletedPaths);
        if (chunk.deletedPaths.isNotEmpty) {
          final idsToDelete = chunk.deletedPaths
              .map((path) => existingMap[path]?.id)
              .whereType<int>()
              .toList();
          if (idsToDelete.isNotEmpty) {
            await _songRepository.deleteSongsByIds(idsToDelete);
          } else {
            await _songRepository.deleteSongsByPath(chunk.deletedPaths);
          }
        }

        initialSongCount = existingMap.length - chunk.deletedPaths.length;
        initialProgressSent = true;

        yield ScanProgress(
          songsFound: initialSongCount,
          totalFiles: totalFiles,
          currentFolder: displayName,
          isComplete: false,
        );
      }

      if (chunk.newOrModified.isNotEmpty) {
        final batch = <SongEntity>[];
        final idsToDelete = <int>[];

        for (final metadata in chunk.newOrModified) {
          final existing = existingMap[metadata.path];
          final artist = (metadata.artist?.trim().isNotEmpty ?? false)
              ? metadata.artist!.trim()
              : 'Unknown Artist';
          final song = SongEntity()
            ..filePath = metadata.path
            ..title = (metadata.title?.trim().isNotEmpty ?? false)
                ? metadata.title!.trim()
                : _extractTitleFromFilename(metadata.path.split('/').last)
            ..artist = artist
            ..album = (metadata.album?.trim().isNotEmpty ?? false)
                ? metadata.album!.trim()
                : 'Unknown Album'
            ..albumArtist = existing?.albumArtist ?? artist
            ..trackNumber = metadata.trackNumber ?? existing?.trackNumber ?? 0
            ..discNumber = metadata.discNumber ?? existing?.discNumber ?? 1
            ..durationMs = metadata.durationMs?.toInt() ?? 0
            ..fileType = metadata.format.toUpperCase()
            ..dateAdded = existing?.dateAdded ?? DateTime.now()
            ..lastModified = DateTime.fromMillisecondsSinceEpoch(
              metadata.lastModified,
            )
            ..folderUri = folderUri
            ..fileSize = metadata.fileSize.toInt()
            ..albumArtPath = existing?.albumArtPath
            ..bitrate = AudioMetadataUtils.normalizeStoredBitrateKbps(
              metadata.bitrate,
              sampleRate: metadata.sampleRate,
              bitDepth: metadata.bitDepth,
            )
            ..bitDepth = metadata.bitDepth
            ..sampleRate = metadata.sampleRate
            ..metadataComplete = true;

          if (existing != null) {
            song.id = existing.id;
            _preserveLocalEdits(song, existing);
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

        if (idsToDelete.isNotEmpty) {
          await _songRepository.deleteSongsByIds(idsToDelete);
        }

        if (batch.isNotEmpty) {
          await _songRepository.upsertSongs(batch);
        }
        processed += batch.length;

        yield ScanProgress(
          songsFound: initialSongCount + processed,
          totalFiles: totalFiles,
          currentFile: batch.isNotEmpty ? batch.last.title : null,
          currentFolder: displayName,
          isComplete: false,
        );
      }
    }
    _logScanTiming(displayName, 'Rust scan stream', rustScanStopwatch.elapsed);

    // Post-process CUE and log files (single walk, both collected in one pass)
    if (!_isCancelled) {
      final sidecarStopwatch = Stopwatch()..start();
      final (:cueMap, :logMap) = await _parseCueAndLogFilesRust(scanRootPath);
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

        // Delete orphaned CUE tracks
        final existingCuePaths = existingSongsAfterScan
            .where((s) => s.startOffsetMs != null)
            .map((s) => s.filePath)
            .toSet();
        final orphanedCuePaths = existingCuePaths
            .where((p) => !cueMap.containsKey(p))
            .toList();
        if (orphanedCuePaths.isNotEmpty) {
          await _songRepository.deleteCueTracksByPath(orphanedCuePaths);
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
                      fallbackSource.lastModified?.millisecondsSinceEpoch ?? 0,
                  extension: audioPath.split('.').last,
                  title: fallbackSource.title,
                  artist: fallbackSource.artist,
                  album: fallbackSource.album,
                  albumArtist: fallbackSource.albumArtist,
                  trackNumber: fallbackSource.trackNumber,
                  discNumber: fallbackSource.discNumber,
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
          if (cachedTs != null && existing != null && existing.ripper != null) {
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

    // Update folder stats
    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

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

    yield ScanProgress(
      songsFound: finalCount,
      totalFiles: totalFiles,
      currentFolder: displayName,
      isComplete: true,
    );
  }

  Stream<ScanProgress> scanAllFolders() async* {
    _isCancelled = false;
    final totalStopwatch = Stopwatch()..start();
    final folders = await _folderRepository.getAllFolders();
    final scanPlan = _deduplicateFoldersForScan(folders);
    if (scanPlan.isEmpty) return;

    // Scan all deduplicated folders concurrently
    final controller = StreamController<ScanProgress>();
    var running = 0;
    var completed = 0;

    for (final folder in scanPlan) {
      if (_isCancelled) break;
      running++;

      scanFolder(folder.uri, folder.displayName).listen(
        (progress) {
          if (!controller.isClosed) {
            controller.add(
              ScanProgress(
                songsFound: progress.songsFound,
                totalFiles: progress.totalFiles,
                currentFile: progress.currentFile,
                currentFolder: folder.displayName,
                isComplete: false,
              ),
            );
          }
        },
        onDone: () {
          completed++;
          if (completed >= running && !controller.isClosed) {
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
        isComplete: true,
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

    List<String> deletedPaths;

    if (hasContentUris) {
      deletedPaths = await _checkDeletedPathsSaf(
        folderUri,
        existingSongs,
        scanPreferences,
      );
    } else if (Platform.isAndroid) {
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

    if (deletedPaths.isNotEmpty) {
      final existingMap = {for (final s in existingSongs) s.filePath: s};
      final idsToDelete = deletedPaths
          .map((path) => existingMap[path]?.id)
          .whereType<int>()
          .toList();

      if (idsToDelete.isNotEmpty) {
        await _songRepository.deleteSongsByIds(idsToDelete);
      } else {
        await _songRepository.deleteSongsByPath(deletedPaths);
      }

      devLog(
        'Deleted ${deletedPaths.length} missing songs from $displayName',
      );
    }

    // Update folder stats
    final finalCount = await _songRepository.countSongsInFolder(folderUri);
    await _folderRepository.updateFolderScanInfo(folderUri, finalCount);

    _logScanTiming(
      displayName,
      'deletion refresh (${deletedPaths.length} removed)',
      stopwatch.elapsed,
    );

    return deletedPaths.length;
  }

  Future<List<String>> _checkDeletedPathsSaf(
    String folderUri,
    List<SongEntity> existingSongs,
    LibraryScanPreferences scanPreferences,
  ) async {
    final filePaths = existingSongs
        .where((s) => s.filePath.startsWith('/'))
        .map((s) => s.filePath)
        .toList();

    if (filePaths.isNotEmpty && Platform.isAndroid) {
      try {
        final stopwatch = Stopwatch()..start();
        final result = await _musicFolderService.queryMediaStoreDeletions(
          filePaths,
        );
        if (Uac2PreferencesService.isDeveloperModeEnabledSync) {
          devLog(
            '[LibraryScanner] MediaStore deletion check (${filePaths.length} paths): '
            '${stopwatch.elapsed.inMilliseconds}ms, ${result.length} deleted',
          );
        }
        return result;
      } catch (e) {
        devLog('MediaStore deletion check failed, falling back to SAF: $e');
      }
    }

    final fastScanFiles = await _musicFolderService.scanFolder(
      folderUri,
      filterNonMusicFilesAndFolders:
          scanPreferences.filterNonMusicFilesAndFolders,
    );
    final scannedUris = fastScanFiles.map((f) => f.uri).toSet();
    return existingSongs
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

  Future<List<AudioFileInfo>?> _fetchMetadataChunk(
    List<String> chunkUris,
  ) async {
    try {
      return await _musicFolderService.fetchMetadata(chunkUris);
    } catch (e) {
      devLog(
        'Error fetching metadata chunk (${chunkUris.length} files): $e',
      );
      return null;
    }
  }

  void _runDetachedScanTask(
    String displayName,
    String label,
    Future<void> Function() task,
  ) {
    unawaited(() async {
      final stopwatch = Stopwatch()..start();
      try {
        await task();
      } catch (e) {
        devLog('[LibraryScanner] $label failed for $displayName: $e');
      } finally {
        _logScanTiming(displayName, label, stopwatch.elapsed);
      }
    }());
  }

  void _logScanTiming(String displayName, String label, Duration elapsed) {
    if (!Uac2PreferencesService.isDeveloperModeEnabledSync) return;
    devLog(
      '[LibraryScanner] $displayName $label: ${elapsed.inMilliseconds}ms',
    );
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
    return pendingFiles <= 0 ? 100 : 500;
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
          : Platform.isAndroid
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
      ),
    );

    return files.map((path) => PlaylistSourceFile(sourcePath: path)).toList();
  }

  // ── CUE / Log helpers ──────────────────────────────────────────────

  Future<String?> _readTextFile(String uri) async {
    try {
      if (uri.startsWith('/') && File(uri).existsSync()) {
        return File(uri).readAsString();
      }
      return await _storageChannel.invokeMethod<String>('readTextDocument', {
        'uri': uri,
      });
    } catch (e) {
      devLog('[LibraryScanner] Failed to read text file $uri: $e');
      return null;
    }
  }

  String? _resolveAudioUriFromCue(
    String cueUri,
    String audioFileName,
    Map<String, AudioFileInfo> fastScanMap,
  ) {
    final target = audioFileName.toLowerCase();
    for (final entry in fastScanMap.values) {
      if (entry.name.toLowerCase() == target) {
        return entry.filePath ?? entry.uri;
      }
    }
    return null;
  }

  Future<Map<String, CueSheet>> _parseCueFilesAndroid(
    List<AudioFileInfo> cueFiles,
    Map<String, AudioFileInfo> fastScanMap,
  ) async {
    final cueService = CueFileService();
    final result = <String, CueSheet>{};
    for (final cue in cueFiles) {
      final content = await _readTextFile(cue.uri);
      if (content == null || content.isEmpty) continue;
      final sheet = cueService.parseCueSheet(content, cueFilePath: cue.uri);
      if (sheet == null) continue;
      final audioUri = _resolveAudioUriFromCue(
        cue.uri,
        sheet.audioFile,
        fastScanMap,
      );
      if (audioUri != null) {
        result[audioUri] = sheet;
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
        final sheet = cueService.parseCueSheet(content, cueFilePath: path);
        if (sheet == null) continue;
        final audioPath = cueService.resolveAudioFilePath(
          path,
          sheet.audioFile,
        );
        cueMap[audioPath] = sheet;
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

  String _fileStem(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot <= 0) return fileName;
    return fileName.substring(0, lastDot);
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

  List<SongEntity> _buildCueTrackEntities({
    required String audioUri,
    required CueSheet cueSheet,
    required AudioFileInfo? meta,
    required String folderUri,
    required Map<String, SongEntity> existingMap,
    required RipLog? ripLog,
    required DateTime lastModified,
  }) {
    final entities = <SongEntity>[];
    for (final track in cueSheet.tracks) {
      final artist = track.performer.trim().isNotEmpty
          ? track.performer.trim()
          : (cueSheet.performer?.trim().isNotEmpty ?? false)
          ? cueSheet.performer!.trim()
          : (meta?.artist?.trim().isNotEmpty ?? false)
          ? meta!.artist!.trim()
          : 'Unknown Artist';
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
            : 'Unknown Album'
        ..albumArtist = cueSheet.performer?.trim().isNotEmpty ?? false
            ? cueSheet.performer!.trim()
            : artist
        ..trackNumber = track.trackNumber
        ..discNumber = meta?.discNumber ?? 1
        ..durationMs = track.endOffsetMs != null
            ? track.endOffsetMs! - track.startOffsetMs
            : (meta?.duration ?? 0)
        ..fileType = meta?.extension.toUpperCase() ?? 'UNKNOWN'
        ..dateAdded = existing?.dateAdded ?? DateTime.now()
        ..lastModified = lastModified
        ..folderUri = folderUri
        ..fileSize = meta?.size ?? 0
        ..albumArtPath = existing?.albumArtPath ?? meta?.albumArtPath
        ..bitrate = meta?.bitrate != null
            ? AudioMetadataUtils.bitrateFromBitsPerSecond(
                int.tryParse(meta!.bitrate!),
              )
            : null
        ..bitDepth = meta?.bitDepth
        ..sampleRate = meta?.sampleRate
        ..genre = cueSheet.genre
        ..year = int.tryParse(cueSheet.date ?? '')
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
        ..metadataComplete = meta?.sampleRate != null && meta?.bitDepth != null;

      if (existing != null) {
        entity.id = existing.id;
      }
      entities.add(entity);
    }
    return entities;
  }
}
