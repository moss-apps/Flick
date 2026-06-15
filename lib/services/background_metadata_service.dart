import 'dart:async';
import 'package:flutter/foundation.dart';
import 'music_folder_service.dart';
import '../data/repositories/song_repository.dart';
import '../data/entities/song_entity.dart';
import 'uac2_preferences_service.dart';
import 'package:flick/core/utils/dev_log.dart';

class BackgroundMetadataService {
  final MusicFolderService _musicFolderService;
  final SongRepository _songRepository;

  bool _isRunning = false;
  Timer? _timer;

  BackgroundMetadataService({
    MusicFolderService? musicFolderService,
    SongRepository? songRepository,
  }) : _musicFolderService = musicFolderService ?? MusicFolderService(),
       _songRepository = songRepository ?? SongRepository();

  void startPeriodicExtraction({
    Duration interval = const Duration(minutes: 5),
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => extractPendingMetadata());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _logTiming(String label, Duration elapsed) {
    if (!Uac2PreferencesService.isDeveloperModeEnabledSync) return;
    devLog('[BackgroundMetadata] $label: ${elapsed.inMilliseconds}ms');
  }

  Future<int> extractPendingMetadata() async {
    if (_isRunning) return 0;
    _isRunning = true;

    try {
      final totalStopwatch = Stopwatch()..start();
      final dbStopwatch = Stopwatch()..start();
      final incomplete = await _songRepository.getIncompleteMetadataSongs();
      _logTiming(
        'DB query incomplete (${incomplete.length} songs)',
        dbStopwatch.elapsed,
      );

      if (incomplete.isEmpty) return 0;

      const batchSize = 100;
      var totalUpdated = 0;

      for (var i = 0; i < incomplete.length; i += batchSize) {
        final batch = incomplete.sublist(
          i,
          (i + batchSize > incomplete.length)
              ? incomplete.length
              : i + batchSize,
        );

        final contentUris = batch
            .map((s) => s.mediaStoreUri ?? s.filePath)
            .where((uri) => uri.startsWith('content://'))
            .toSet()
            .toList();

        if (contentUris.isEmpty) {
          for (final song in batch) {
            song.metadataComplete = true;
          }
          await _songRepository.upsertSongs(batch);
          totalUpdated += batch.length;
          continue;
        }

        try {
          final chunkStopwatch = Stopwatch()..start();
          final metadataList = await _musicFolderService.fetchMetadata(
            contentUris,
          );
          final metaByUri = <String, AudioFileInfo>{};
          for (final m in metadataList) {
            metaByUri[m.uri] = m;
          }

          final updateBatch = <SongEntity>[];
          for (final song in batch) {
            final lookupUri = song.mediaStoreUri ?? song.filePath;
            final meta = metaByUri[lookupUri];
            if (meta != null) {
              song.sampleRate = meta.sampleRate ?? song.sampleRate;
              song.bitDepth = meta.bitDepth ?? song.bitDepth;
              if (!song.hasLocalEdits) {
                song.discNumber = meta.discNumber ?? song.discNumber;
                song.albumArtist =
                    (meta.albumArtist?.trim().isNotEmpty ?? false)
                        ? meta.albumArtist!.trim()
                        : song.albumArtist;
              }
            }
            song.metadataComplete = true;
            updateBatch.add(song);
          }

          await _songRepository.upsertSongs(updateBatch);
          totalUpdated += updateBatch.length;
          _logTiming(
            'batch ${i ~/ batchSize + 1} (${batch.length} songs, '
            '${contentUris.length} URIs, ${updateBatch.length} updated)',
            chunkStopwatch.elapsed,
          );
        } catch (e) {
          devLog('BackgroundMetadataService batch failed: $e');
        }
      }

      _logTiming(
        'extract pending metadata total ($totalUpdated updated)',
        totalStopwatch.elapsed,
      );

      return totalUpdated;
    } finally {
      _isRunning = false;
    }
  }
}
