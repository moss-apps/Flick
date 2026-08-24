import 'dart:io';
import 'dart:math' as math;

import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/src/rust/api/audio_analysis.dart' as rust_analysis;
import 'package:flick/src/rust/api/replaygain.dart' as rust_replaygain;

class ReplayGainScanProgress {
  final int completed;
  final int total;
  final int skipped;
  final int failed;
  final String? currentFile;
  final bool isComplete;

  const ReplayGainScanProgress({
    this.completed = 0,
    this.total = 0,
    this.skipped = 0,
    this.failed = 0,
    this.currentFile,
    this.isComplete = false,
  });

  double get fraction => total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
}

class _TrackMeasure {
  _TrackMeasure({
    required this.path,
    required this.album,
    required this.albumArtist,
    required this.lufs,
    required this.peak,
  });

  final String path;
  final String album;
  final String albumArtist;
  final double lufs;
  final double peak;
}

const double _replayGainTargetLufs = -18.0;
const int _analysisPeakBuckets = 8;
const double _maxGainDb = 30.0;
const double _minGainDb = -60.0;

/// Full-library ReplayGain scanner.
///
/// Decodes every local file once through the Rust BS.1770 analysis bridge
/// (the same loudness math the waveform/preload pass uses), derives
/// ReplayGain-2.0-style gains (`gain = -18 LUFS - loudness`), computes album
/// gains as the power average of the album's track loudness, writes
/// REPLAYGAIN_* tags back into the files with lofty, and syncs the library DB
/// so playback applies the new values immediately (no rescan needed).
class ReplayGainScanService {
  final SongRepository _songRepository;

  bool _isCancelled = false;

  ReplayGainScanService({SongRepository? songRepository})
    : _songRepository = songRepository ?? SongRepository();

  void cancel() => _isCancelled = true;

  /// Scan [songs]; yields progress as it goes. Only local files (no network
  /// source, PCM formats supported by the analysis bridge) are processed.
  Stream<ReplayGainScanProgress> scanLibrary(List<SongEntity> songs) async* {
    _isCancelled = false;

    final candidates = <SongEntity>[];
    for (final song in songs) {
      final path = song.filePath;
      if (path.isEmpty) continue;
      if (song.sourceType != null) continue;
      final ext = path.toLowerCase();
      if (ext.endsWith('.dsf') ||
          ext.endsWith('.dff') ||
          ext.endsWith('.wv')) {
        continue;
      }
      try {
        if (!File(path).existsSync()) continue;
      } catch (_) {
        continue;
      }
      candidates.add(song);
    }

    final total = candidates.length;
    if (total == 0) {
      yield const ReplayGainScanProgress(isComplete: true);
      return;
    }

    var analyzed = 0;
    var written = 0;
    var failed = 0;

    final measures = <_TrackMeasure>[];

    // Pass 1: per-track BS.1770 loudness + true peak.
    for (final song in candidates) {
      if (_isCancelled) break;
      analyzed++;

      try {
        final result = await rust_analysis.analyzeAudioFile(
          path: song.filePath,
          peakBuckets: _analysisPeakBuckets,
        );
        final lufs = result?.lufs;
        if (result == null || lufs == null || !lufs.isFinite) {
          failed++;
        } else {
          final tpDb = result.truePeakDb;
          final peak = tpDb == null
              ? 0.0
              : math.pow(10.0, tpDb / 20.0).toDouble();
          final album =
              (song.album?.trim().isNotEmpty ?? false)
              ? song.album!.trim()
              : 'Unknown Album';
          final albumArtist = (song.albumArtist?.trim().isNotEmpty ?? false)
              ? song.albumArtist!.trim()
              : (song.artist.trim().isNotEmpty ? song.artist.trim() : 'Unknown Artist');
          measures.add(
            _TrackMeasure(
              path: song.filePath,
              album: album,
              albumArtist: albumArtist,
              lufs: lufs,
              peak: peak,
            ),
          );
        }
      } catch (e) {
        failed++;
      }

      yield ReplayGainScanProgress(
        completed: analyzed + written,
        total: total,
        skipped: 0,
        failed: failed,
        currentFile: song.filePath,
      );
    }

    // Pass 2: album gains (power-average of member loudness) + tag writes.
    final albumMap = <String, List<_TrackMeasure>>{};
    for (final m in measures) {
      albumMap.putIfAbsent('${m.album}\u0000${m.albumArtist}', () => [])
          .add(m);
    }

    for (final group in albumMap.values) {
      if (_isCancelled) break;

      final albumLufs = _powerAverageLufs(group);
      final albumPeak = group.fold<double>(0.0, (p, m) => math.max(p, m.peak));
      final albumGainDb = _clampGain(_replayGainTargetLufs - albumLufs);

      for (final m in group) {
        final trackGainDb = _clampGain(_replayGainTargetLufs - m.lufs);
        try {
          await rust_replaygain.writeReplaygainTags(
            path: m.path,
            fields: rust_replaygain.ReplayGainTagFields(
              trackGainDb: trackGainDb,
              trackPeak: m.peak > 0 ? m.peak : null,
              albumGainDb: albumGainDb,
              albumPeak: albumPeak > 0 ? albumPeak : null,
            ),
          );
          await _songRepository.updateReplayGainForPath(
            m.path,
            trackGainDb: trackGainDb,
            trackPeak: m.peak > 0 ? m.peak : null,
            albumGainDb: albumGainDb,
            albumPeak: albumPeak > 0 ? albumPeak : null,
          );
          written++;
        } catch (e) {
          failed++;
        }

        yield ReplayGainScanProgress(
          completed: analyzed + written,
          total: total,
          skipped: 0,
          failed: failed,
          currentFile: m.path,
        );
      }
    }

    yield ReplayGainScanProgress(
      completed: analyzed + written,
      total: total,
      skipped: 0,
      failed: failed,
      isComplete: true,
    );
  }

  /// Loudness of the album as a whole: power-average of member loudnesses,
  /// which is what ReplayGain album gain expects (not the arithmetic mean).
  double _powerAverageLufs(List<_TrackMeasure> group) {
    var sum = 0.0;
    for (final m in group) {
      sum += math.pow(10.0, m.lufs / 10.0).toDouble();
    }
    return 10.0 * math.log(sum / group.length) / math.ln10;
  }

  double _clampGain(double gainDb) =>
      gainDb.clamp(_minGainDb, _maxGainDb).toDouble();
}
