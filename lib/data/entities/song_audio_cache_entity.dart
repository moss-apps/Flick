import 'package:isar_community/isar.dart';

part 'song_audio_cache_entity.g.dart';

/// Sibling cache table 1:1 with [SongEntity]. Stores waveform peaks and
/// audio-analysis metrics computed once during a preload scan. Kept off the
/// hot songs row so song-list queries stay fast.
@collection
class SongAudioCacheEntity {
  /// Matches [SongEntity.id]. Used as PK so lookups are O(1) and cascade
  /// deletes are explicit (call [deleteBySongIds] when songs are removed).
  @Index()
  Id songId = Isar.autoIncrement;

  /// Waveform peaks normalised 0.0..=1.0, ~240 buckets per song.
  List<double> peaks = [];

  double? lufs;
  double? truePeakDb;
  double? dr;
  double? lra;
  bool clipping = false;

  /// Bump to force a global recompute via the "Reprocess all" override.
  int version = 1;

  /// Epoch milliseconds when this cache row was computed. Compared against
  /// [SongEntity.lastModified] to skip stale entries on incremental scans.
  @Index()
  int computedAt = 0;
}
