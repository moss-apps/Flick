import '../core/utils/audio_metadata_utils.dart';
import '../data/repositories/song_repository.dart';
import '../data/entities/song_entity.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Represents a group of duplicate songs.
class DuplicateGroup {
  final String key; // The common identifier (title + artist)
  final List<SongEntity> songs;

  DuplicateGroup({required this.key, required this.songs});

  SongEntity? _cachedRecommended;

  /// The automatically recommended song to keep (album art first, then bitrate).
  /// Computed once and cached — never mutates [songs].
  SongEntity get recommendedKeep => _cachedRecommended ??= _computeRecommendedKeep();

  /// Backwards-compatible alias for [recommendedKeep].
  SongEntity get songToKeep => recommendedKeep;

  SongEntity _computeRecommendedKeep() {
    int normalizedBitrate(SongEntity s) =>
        AudioMetadataUtils.normalizeStoredBitrateKbps(
          s.bitrate,
          sampleRate: s.sampleRate,
          bitDepth: s.bitDepth,
        ) ??
        0;

    final withArt = songs.where((s) => s.albumArtPath != null).toList();
    if (withArt.isNotEmpty) {
      withArt.sort((a, b) => normalizedBitrate(b).compareTo(normalizedBitrate(a)));
      return withArt.first;
    }

    final copy = List<SongEntity>.from(songs);
    copy.sort((a, b) => normalizedBitrate(b).compareTo(normalizedBitrate(a)));
    return copy.first;
  }

  /// Songs that would be removed if [keepId] (or the recommended one) is kept.
  List<SongEntity> songsToRemoveFor(int keepId) =>
      songs.where((s) => s.id != keepId).toList();

  /// Default removal list (keeps the recommended song).
  List<SongEntity> get songsToRemove => songsToRemoveFor(recommendedKeep.id);
}

/// Result of duplicate scan operation.
class DuplicateScanResult {
  final List<DuplicateGroup> duplicateGroups;
  final int totalDuplicates;
  final int totalGroups;

  DuplicateScanResult({
    required this.duplicateGroups,
    required this.totalDuplicates,
    required this.totalGroups,
  });
}

/// Result of duplicate removal operation.
class DuplicateRemovalResult {
  final int removedCount;
  final int keptCount;
  final List<String> errors;

  DuplicateRemovalResult({
    required this.removedCount,
    required this.keptCount,
    required this.errors,
  });
}

/// Service for detecting and removing duplicate songs.
class DuplicateCleanerService {
  final SongRepository _songRepository;

  DuplicateCleanerService({SongRepository? songRepository})
    : _songRepository = songRepository ?? SongRepository();

  /// Scan the library for duplicate songs.
  /// Duplicates are identified by matching title and artist (case-insensitive).
  Future<DuplicateScanResult> scanForDuplicates() async {
    devLog('Starting duplicate scan...');

    final allSongs = await _songRepository.getAllSongEntities();
    final duplicateMap = <String, List<SongEntity>>{};

    // Group songs by normalized title + artist
    for (final song in allSongs) {
      final key = _normalizeKey(song.title, song.artist);
      duplicateMap.putIfAbsent(key, () => []).add(song);
    }

    // Filter to only groups with duplicates (2+ songs)
    final duplicateGroups = duplicateMap.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => DuplicateGroup(key: entry.key, songs: entry.value))
        .toList();

    // Sort by number of duplicates (descending)
    duplicateGroups.sort((a, b) => b.songs.length.compareTo(a.songs.length));

    final totalDuplicates = duplicateGroups.fold<int>(
      0,
      (sum, group) => sum + group.songsToRemove.length,
    );

    devLog(
      'Duplicate scan complete: Found $totalDuplicates duplicates in ${duplicateGroups.length} groups',
    );

    return DuplicateScanResult(
      duplicateGroups: duplicateGroups,
      totalDuplicates: totalDuplicates,
      totalGroups: duplicateGroups.length,
    );
  }

  /// Remove all duplicate songs, keeping the best quality version.
  Future<DuplicateRemovalResult> removeAllDuplicates(
    List<DuplicateGroup> groups,
  ) async {
    devLog('Starting duplicate removal...');

    int removedCount = 0;
    int keptCount = 0;
    final errors = <String>[];

    for (final group in groups) {
      try {
        final toRemove = group.songsToRemove;

        for (final song in toRemove) {
          await _songRepository.deleteSong(song.id);
          removedCount++;
        }

        keptCount++;
        devLog(
          'Removed ${toRemove.length} duplicates of "${group.songToKeep.title}"',
        );
      } catch (e) {
        final error = 'Failed to remove duplicates for "${group.key}": $e';
        errors.add(error);
        devLog(error);
      }
    }

    devLog(
      'Duplicate removal complete: Removed $removedCount songs, kept $keptCount',
    );

    return DuplicateRemovalResult(
      removedCount: removedCount,
      keptCount: keptCount,
      errors: errors,
    );
  }

  /// Remove specific duplicate songs by their IDs.
  Future<int> removeSpecificDuplicates(List<int> songIds) async {
    int removedCount = 0;

    for (final id in songIds) {
      try {
        await _songRepository.deleteSong(id);
        removedCount++;
      } catch (e) {
        devLog('Failed to remove song $id: $e');
      }
    }

    return removedCount;
  }

  /// Normalize a title + artist combination for comparison.
  String _normalizeKey(String title, String artist) {
    // Remove common variations and normalize
    final normalizedTitle = title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), ''); // Remove special chars

    final normalizedArtist = artist
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '');

    return '$normalizedTitle|$normalizedArtist';
  }
}
