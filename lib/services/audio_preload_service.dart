import 'dart:async';

import '../data/entities/song_entity.dart';
import '../data/entities/song_audio_cache_entity.dart';
import '../data/repositories/song_repository.dart';
import '../src/rust/api/audio_analysis.dart';
import 'album_art_service.dart';

class PreloadProgress {
  final int completed;
  final int total;
  final int skipped;
  final int failed;
  final String? currentFile;
  final bool isComplete;

  const PreloadProgress({
    this.completed = 0,
    this.total = 0,
    this.skipped = 0,
    this.failed = 0,
    this.currentFile,
    this.isComplete = false,
  });

  double get fraction => total > 0 ? completed / total : 0.0;
}

/// Orchestrates the audio preload pass: decodes each song once via the Rust
/// bridge, caches waveform peaks + metrics, and resolves cover art. Concurrency
/// capped at [_concurrency]; honours [cancel].
class AudioPreloadService {
  static const int _concurrency = 2;
  static const int _peakBuckets = 240;
  static const int _currentVersion = 1;

  final SongRepository _songRepository;
  final AlbumArtService _albumArtService;

  bool _isCancelled = false;

  AudioPreloadService({
    SongRepository? songRepository,
    AlbumArtService? albumArtService,
  })  : _songRepository = songRepository ?? SongRepository(),
        _albumArtService = albumArtService ?? AlbumArtService.instance;

  void cancel() => _isCancelled = true;

  /// Preloads audio data for [songs]. Skips songs whose cache is fresh
  /// (computedAt >= song.lastModified) unless [forceAll].
  Stream<PreloadProgress> preloadSongs(
    List<SongEntity> songs, {
    bool forceAll = false,
  }) async* {
    _isCancelled = false;

    if (songs.isEmpty) {
      yield const PreloadProgress(isComplete: true);
      return;
    }

    final songIds = songs.map((s) => s.id).toList();
    final cacheMap = await _songRepository.getAudioCacheMap(songIds);

    final toProcess = <SongEntity>[];
    var skipped = 0;

    for (final song in songs) {
      if (_isCancelled) break;

      final cache = cacheMap[song.id];
      if (!forceAll && cache != null && _isCacheFresh(cache, song)) {
        skipped++;
        continue;
      }
      toProcess.add(song);
    }

    var completed = skipped;
    var failed = 0;

    yield PreloadProgress(
      completed: completed,
      total: songs.length,
      skipped: skipped,
      failed: failed,
    );

    // ponytail: chunked concurrency — simple, correct, good enough for v1.
    // Uneven decode times leave a worker idle at chunk boundaries; upgrade to
    // a shared-queue worker pool if that matters.
    for (var i = 0; i < toProcess.length; i += _concurrency) {
      if (_isCancelled) break;

      final end = (i + _concurrency).clamp(0, toProcess.length);
      final chunk = toProcess.sublist(i, end);

      final results = await Future.wait(
        chunk.map((s) => _processSong(s).then((_) => true).catchError((_) => false)),
      );

      completed += results.where((r) => r).length;
      failed += results.where((r) => !r).length;

      yield PreloadProgress(
        completed: completed,
        total: songs.length,
        skipped: skipped,
        failed: failed,
        currentFile: chunk.last.title,
      );
    }

    yield PreloadProgress(
      completed: songs.length,
      total: songs.length,
      skipped: skipped,
      failed: failed,
      isComplete: true,
    );
  }

  bool _isCacheFresh(SongAudioCacheEntity cache, SongEntity song) {
    if (cache.version != _currentVersion) return false;
    final songModified = song.lastModified?.millisecondsSinceEpoch ?? 0;
    return cache.computedAt >= songModified;
  }

  Future<void> _processSong(SongEntity song) async {
    if (_isCancelled) return;

    final path = song.filePath;
    if (path.startsWith('content://')) return;

    final result = await analyzeAudioFile(
      path: path,
      peakBuckets: _peakBuckets,
    );

    if (result == null) return;

    final entity = SongAudioCacheEntity()
      ..songId = song.id
      ..peaks = result.peaks.toList()
      ..lufs = result.lufs
      ..truePeakDb = result.truePeakDb
      ..dr = result.dr
      ..lra = result.lra
      ..clipping = result.clipping
      ..version = _currentVersion
      ..computedAt = DateTime.now().millisecondsSinceEpoch;

    await _songRepository.upsertAudioCache(entity);

    // Resolve cover art (reuses AlbumArtService's full caching pipeline).
    if (song.albumArtPath == null || song.albumArtPath!.isEmpty) {
      await _albumArtService.resolveArtworkPath(
        existingPath: song.albumArtPath,
        audioSourcePath: path,
      );
    }
  }
}
