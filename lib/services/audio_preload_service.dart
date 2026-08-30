import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flick/core/utils/dev_log.dart';

import '../data/entities/song_entity.dart';
import '../data/entities/song_audio_cache_entity.dart';
import '../data/repositories/song_repository.dart';
import '../src/rust/api/audio_analysis.dart';
import 'album_art_service.dart';
import 'artwork_gate.dart';

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
/// bridge, caches waveform peaks + metrics, and resolves cover art.
///
/// [instance] is the app-wide singleton. Exactly one pass runs at any time:
/// post-scan auto passes merge into a shared drain queue, while a manual
/// [preloadSongs] pass takes over exclusively (cancelling any auto pass).
/// Multiple concurrent passes previously stacked decoders, held overlapping
/// artwork-gate refcounts, and made scans look wedged on slow devices.
class AudioPreloadService {
  static final AudioPreloadService instance = AudioPreloadService();

  static const int _concurrency = 2;
  static const int _peakBuckets = 240;
  static const int _currentVersion = 1;

  /// Formats [analyzeAudioFile] cannot decode yet (Rust skips them). Misses
  /// are negative-cached so every pass doesn't re-probe them. Bump
  /// [_currentVersion] when decode support lands to force a recompute.
  static const Set<String> _negativeCacheExtensions = {'dsf', 'dff', 'wv'};

  /// Pure extension check (unit-tested): should a failed analysis for [path]
  /// be persisted as a negative cache row?
  static bool shouldNegativeCache(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return _negativeCacheExtensions.contains(
      path.substring(dot + 1).toLowerCase(),
    );
  }

  final SongRepository _songRepository;
  final AlbumArtService _albumArtService;

  /// Live state of the shared auto pass; null while idle. UI can listen to
  /// surface background progress and offer cancellation.
  final ValueNotifier<PreloadProgress?> progress = ValueNotifier(null);

  bool _runnerActive = false;
  bool _cancelRequested = false;
  bool _manualPassActive = false;

  final List<SongEntity> _pending = [];
  final Set<int> _queuedIds = {};
  int _completed = 0;
  int _skipped = 0;
  int _failed = 0;
  int _total = 0;

  AudioPreloadService({
    SongRepository? songRepository,
    AlbumArtService? albumArtService,
  })  : _songRepository = songRepository ?? SongRepository(),
        _albumArtService = albumArtService ?? AlbumArtService.instance;

  bool get isRunning => _runnerActive || _manualPassActive;

  /// Stops the active pass (auto or manual) at the next chunk boundary and
  /// drops everything still queued.
  void cancel() {
    _cancelRequested = true;
    _pending.clear();
    _queuedIds.clear();
  }

  /// Auto-pass entry point (post-scan). Merges [songs] into the single drain
  /// queue — concurrent folder scans enqueue without supersetting each other.
  /// Stale-cache files are filtered out here; already-queued ids are skipped.
  Future<void> enqueueAutoPreload(List<SongEntity> songs) async {
    if (_manualPassActive || songs.isEmpty) return;

    final cacheMap = await _songRepository.getAudioCacheMap(
      songs.map((s) => s.id).toList(),
    );
    for (final song in songs) {
      if (_queuedIds.contains(song.id)) continue;
      final cache = cacheMap[song.id];
      if (cache != null && _isCacheFresh(cache, song)) continue;
      _queuedIds.add(song.id);
      _pending.add(song);
    }
    if (_pending.isEmpty) return;

    _total = _completed + _skipped + _failed + _pending.length;
    _emitAutoProgress();

    if (!_runnerActive) {
      _runnerActive = true;
      unawaited(_drainAutoQueue());
    }
  }

  /// Preloads audio data for [songs]. Skips songs whose cache is fresh
  /// (computedAt >= song.lastModified) unless [forceAll]. Runs exclusively:
  /// any in-flight auto pass is cancelled first.
  Stream<PreloadProgress> preloadSongs(
    List<SongEntity> songs, {
    bool forceAll = false,
  }) async* {
    if (songs.isEmpty) {
      yield const PreloadProgress(isComplete: true);
      return;
    }

    // Take over from any running auto pass before touching shared state.
    _cancelRequested = true;
    while (_runnerActive) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    _manualPassActive = true;
    _cancelRequested = false;

    // ponytail: hold the artwork gate for the whole pass so scroll-side
    // extraction steps aside. Preload owns the shared compute() isolate
    // until done; tiles refresh via watchSongs() -> invalidateSelf when each
    // path is persisted, so art appears as preload reaches it. Refcounted,
    // so a concurrent fling gate won't clobber this on its settle timer.
    pauseArtworkExtraction(true);
    try {
      final songIds = songs.map((s) => s.id).toList();
      final cacheMap = await _songRepository.getAudioCacheMap(songIds);

      final toProcess = <SongEntity>[];
      var skipped = 0;

      for (final song in songs) {
        final cache = cacheMap[song.id];
        if (!forceAll && cache != null && _isCacheFresh(cache, song)) {
          skipped++;
          continue;
        }
        toProcess.add(song);
      }

      var completed = skipped;
      var failed = 0;

      final initial = PreloadProgress(
        completed: completed,
        total: songs.length,
        skipped: skipped,
        failed: failed,
      );
      progress.value = initial;
      yield initial;

      // ponytail: chunked concurrency — simple, correct, good enough for v1.
      // Uneven decode times leave a worker idle at chunk boundaries; upgrade
      // a shared-queue worker pool if that matters.
      for (var i = 0; i < toProcess.length; i += _concurrency) {
        if (_cancelRequested) break;

        final end = (i + _concurrency).clamp(0, toProcess.length);
        final chunk = toProcess.sublist(i, end);

        final results = await Future.wait(
          chunk.map((s) => _processSong(s).then((_) => true).catchError((_) => false)),
        );

        completed += results.where((r) => r).length;
        failed += results.where((r) => !r).length;

        final snapshot = PreloadProgress(
          completed: completed,
          total: songs.length,
          skipped: skipped,
          failed: failed,
          currentFile: chunk.last.title,
        );
        progress.value = snapshot;
        yield snapshot;
      }

      progress.value = null;
      yield PreloadProgress(
        completed: songs.length,
        total: songs.length,
        skipped: skipped,
        failed: failed,
        isComplete: true,
      );
    } finally {
      pauseArtworkExtraction(false);
      _manualPassActive = false;
      _cancelRequested = false;
    }
  }

  /// Drains the merged auto queue. Holds the artwork gate while running so
  /// the release is guaranteed even on cancel — an orphaned pause previously
  /// froze artwork extraction for the rest of the session.
  Future<void> _drainAutoQueue() async {
    pauseArtworkExtraction(true);
    try {
      while (_pending.isNotEmpty) {
        if (_cancelRequested) break;

        final chunkSize = _concurrency.clamp(0, _pending.length);
        final chunk = _pending.sublist(0, chunkSize);
        _pending.removeRange(0, chunkSize);

        final results = await Future.wait(
          chunk.map((s) => _processSong(s).then((_) => true).catchError((_) => false)),
        );

        _completed += results.where((r) => r).length;
        _failed += results.where((r) => !r).length;
        _emitAutoProgress(currentFile: chunk.isNotEmpty ? chunk.last.title : null);
      }
    } finally {
      pauseArtworkExtraction(false);
      _runnerActive = false;
      final cancelled = _cancelRequested;
      final processed = _completed + _failed;
      _cancelRequested = false;
      _pending.clear();
      _queuedIds.clear();
      _completed = 0;
      _skipped = 0;
      _failed = 0;
      _total = 0;
      progress.value = null;
      devLog(
        '[AudioPreload] auto pass ${cancelled ? 'cancelled' : 'finished'}: '
        '$processed processed',
      );
    }
  }

  void _emitAutoProgress({String? currentFile}) {
    progress.value = PreloadProgress(
      completed: _completed + _skipped,
      total: _total,
      skipped: _skipped,
      failed: _failed,
      currentFile: currentFile,
    );
  }

  bool _isCacheFresh(SongAudioCacheEntity cache, SongEntity song) {
    if (cache.version != _currentVersion) return false;
    final songModified = song.lastModified?.millisecondsSinceEpoch ?? 0;
    return cache.computedAt >= songModified;
  }

  Future<void> _processSong(SongEntity song) async {
    if (_cancelRequested) return;

    final path = song.filePath;
    if (path.startsWith('content://')) return;

    final result = await analyzeAudioFile(
      path: path,
      peakBuckets: _peakBuckets,
    );

    if (result == null) {
      // Known-undecodable formats get a negative cache row so later passes
      // skip them; transient decode failures of supported formats do not.
      if (shouldNegativeCache(path)) {
        await _songRepository.upsertAudioCache(
          SongAudioCacheEntity()
            ..songId = song.id
            ..peaks = const []
            ..version = _currentVersion
            ..computedAt = DateTime.now().millisecondsSinceEpoch,
        );
      }
      return;
    }

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
