import 'song.dart';

/// Whether the tracks in the library cover an entire album.
enum AlbumCompletenessStatus { complete, incomplete, unknown }

/// A track position that is missing from the library.
class AlbumTrackPosition {
  /// Disc the missing track belongs to, or null when the numbering scheme is
  /// album-wide and the disc cannot be determined.
  final int? discNumber;
  final int trackNumber;

  const AlbumTrackPosition({this.discNumber, required this.trackNumber});

  bool get isDiscSpecific => discNumber != null;

  @override
  String toString() =>
      discNumber == null ? '$trackNumber' : '$discNumber:$trackNumber';

  @override
  bool operator ==(Object other) =>
      other is AlbumTrackPosition &&
      other.discNumber == discNumber &&
      other.trackNumber == trackNumber;

  @override
  int get hashCode => Object.hash(discNumber, trackNumber);
}

/// Result of comparing an album's tracks against its embedded total tags.
class AlbumCompleteness {
  // Tags are untrusted input. Bound work and allocations on the UI isolate,
  // including for corrupt u32 totals claiming billions of missing tracks.
  static const _maxTracks = 10000;
  static const _maxDiscs = 1000;

  final AlbumCompletenessStatus status;
  final List<AlbumTrackPosition> missingTracks;
  final List<int> missingDiscs;
  final int? expectedTrackCount;

  const AlbumCompleteness._({
    required this.status,
    this.missingTracks = const [],
    this.missingDiscs = const [],
    this.expectedTrackCount,
  });

  static const unknown = AlbumCompleteness._(
    status: AlbumCompletenessStatus.unknown,
  );

  bool get isComplete => status == AlbumCompletenessStatus.complete;
  bool get isIncomplete => status == AlbumCompletenessStatus.incomplete;
  bool get isUnknown => status == AlbumCompletenessStatus.unknown;

  List<int> get missingTrackNumbers =>
      missingTracks.map((position) => position.trackNumber).toList();

  bool get hasDiscSpecificMissingTracks =>
      missingTracks.any((position) => position.isDiscSpecific);

  /// Resolves completeness conservatively from embedded track/disc totals.
  ///
  /// A track-number gap alone is not proof that a track is missing: without a
  /// total, the album is reported as unknown. Duplicate track numbers are
  /// compared as a set, so a duplicate cannot stand in for a missing position.
  static AlbumCompleteness resolve(Iterable<Song> songs) {
    final tracks = songs.toList(growable: false);
    if (tracks.isEmpty) return unknown;

    if (tracks.any(
      (song) =>
          (song.trackNumber ?? 0) > _maxTracks ||
          (song.discNumber ?? 0) < 0 ||
          (song.discNumber ?? 0) > _maxDiscs ||
          (song.trackTotal != null &&
              (song.trackTotal! <= 0 || song.trackTotal! > _maxTracks)) ||
          (song.discTotal != null &&
              (song.discTotal! <= 0 || song.discTotal! > _maxDiscs)),
    )) {
      return unknown;
    }

    final albumArtists = tracks
        .map((song) => song.albumArtist?.trim().toLowerCase())
        .whereType<String>()
        .where((artist) => artist.isNotEmpty)
        .toSet();
    if (albumArtists.length > 1) return unknown;

    // An unnumbered track means we cannot establish which positions exist.
    if (tracks.any(
      (song) => song.trackNumber == null || song.trackNumber! <= 0,
    )) {
      return unknown;
    }

    final hasExplicitDisc = tracks.any(
      (song) => song.discNumber != null && song.discNumber! > 0,
    );
    if (hasExplicitDisc &&
        tracks.any(
          (song) => song.discNumber == null || song.discNumber! <= 0,
        )) {
      return unknown;
    }

    final byDisc = <int, List<Song>>{};
    for (final song in tracks) {
      final disc = (song.discNumber != null && song.discNumber! > 0)
          ? song.discNumber!
          : 1;
      byDisc.putIfAbsent(disc, () => <Song>[]).add(song);
    }

    // A group may contain several editions with the same album name. Copies
    // of the same track are harmless, but different songs at one position or
    // disagreeing totals cannot certify any one edition.
    for (final disc in byDisc.values) {
      final titlesByPosition = <int, String>{};
      final totals = <int>{};
      for (final song in disc) {
        final title = song.title.trim().toLowerCase();
        final previous = titlesByPosition[song.trackNumber!];
        if (previous != null && previous != title) return unknown;
        titlesByPosition[song.trackNumber!] = title;
        if (song.trackTotal != null) totals.add(song.trackTotal!);
      }
      if (totals.length > 1) return unknown;
    }

    final discTotals = tracks
        .map((song) => song.discTotal)
        .whereType<int>()
        .where((total) => total > 0)
        .toSet();
    // Conflicting disc totals are ambiguous, just like conflicting track
    // totals, so do not let one of them certify the album.
    if (discTotals.length > 1) return unknown;

    final declaredDiscCount = discTotals.isEmpty ? null : discTotals.first;
    final expectedDiscs = _expectedDiscSet(
      byDisc.keys.toSet(),
      declaredDiscCount,
    );
    if (expectedDiscs == null) return unknown;

    final missingDiscs = expectedDiscs.difference(byDisc.keys.toSet()).toList()
      ..sort();

    // Disjoint sequences across discs could mean continuous album numbering,
    // or two incomplete discs with per-disc totals. Tags cannot distinguish
    // these cases; never reinterpret a disc's total as an album-wide total.
    final seenNumbers = <int>{};
    var hasResetNumbering = false;
    for (final disc in byDisc.values) {
      final numbers = disc.map((song) => song.trackNumber!).toSet();
      if (numbers.any(seenNumbers.contains)) hasResetNumbering = true;
      seenNumbers.addAll(numbers);
    }
    final ambiguousNumbering = byDisc.length > 1 && !hasResetNumbering;
    final trackResult = ambiguousNumbering
        ? const _TrackResolution(status: AlbumCompletenessStatus.unknown)
        : _resolvePerDisc(byDisc);

    if (missingDiscs.isNotEmpty) {
      return AlbumCompleteness._(
        status: AlbumCompletenessStatus.incomplete,
        missingTracks: trackResult.missingTracks,
        missingDiscs: missingDiscs,
        // The totals on the present discs do not describe an absent disc.
        expectedTrackCount: null,
      );
    }
    if (trackResult.status == AlbumCompletenessStatus.incomplete) {
      return AlbumCompleteness._(
        status: AlbumCompletenessStatus.incomplete,
        missingTracks: trackResult.missingTracks,
        expectedTrackCount: trackResult.expectedTrackCount,
      );
    }
    if (trackResult.status == AlbumCompletenessStatus.unknown) {
      return unknown;
    }
    if (byDisc.length > 1 && declaredDiscCount == null) return unknown;
    return AlbumCompleteness._(
      status: AlbumCompletenessStatus.complete,
      expectedTrackCount: trackResult.expectedTrackCount,
    );
  }

  static _TrackResolution _resolvePerDisc(Map<int, List<Song>> byDisc) {
    final missing = <AlbumTrackPosition>[];
    var hasUnknownDisc = false;
    var positionsChecked = 0;
    int? expectedTrackCount = 0;

    for (final entry in byDisc.entries) {
      final total = _consensus(entry.value.map((song) => song.trackTotal));
      if (total == null) {
        hasUnknownDisc = true;
        expectedTrackCount = null;
        continue;
      }

      final actual = entry.value.map((song) => song.trackNumber!).toSet();
      if (actual.any((track) => track > total)) {
        hasUnknownDisc = true;
        expectedTrackCount = null;
        continue;
      }

      positionsChecked += total;
      if (positionsChecked > _maxTracks) {
        return const _TrackResolution(status: AlbumCompletenessStatus.unknown);
      }
      if (expectedTrackCount != null) expectedTrackCount += total;
      for (var track = 1; track <= total; track++) {
        if (!actual.contains(track)) {
          missing.add(
            AlbumTrackPosition(discNumber: entry.key, trackNumber: track),
          );
        }
      }
    }

    if (missing.isNotEmpty) {
      return _TrackResolution(
        status: AlbumCompletenessStatus.incomplete,
        missingTracks: missing,
        expectedTrackCount: expectedTrackCount,
      );
    }
    if (hasUnknownDisc) {
      return const _TrackResolution(status: AlbumCompletenessStatus.unknown);
    }
    return _TrackResolution(
      status: AlbumCompletenessStatus.complete,
      expectedTrackCount: expectedTrackCount,
    );
  }

  static Set<int>? _expectedDiscSet(
    Set<int> presentDiscs,
    int? declaredDiscCount,
  ) {
    if (presentDiscs.isEmpty) return null;
    if (presentDiscs.any((disc) => disc <= 0)) return null;

    if (declaredDiscCount != null) {
      if (declaredDiscCount <= 0 ||
          presentDiscs.any((disc) => disc > declaredDiscCount)) {
        return null;
      }
      return {for (var disc = 1; disc <= declaredDiscCount; disc++) disc};
    }

    // Without a disc total, a gap in the numbering still proves a disc is
    // missing (for example discs 1 and 3).
    final highestDisc = presentDiscs.reduce((a, b) => a > b ? a : b);
    if (presentDiscs.length < highestDisc) {
      return {for (var disc = 1; disc <= highestDisc; disc++) disc};
    }
    return presentDiscs;
  }

  /// Returns the single positive value shared by [values], or null when the
  /// field is absent or the tags disagree.
  static int? _consensus(Iterable<int?> values) {
    int? result;
    for (final value in values) {
      if (value == null || value <= 0) continue;
      if (result == null) {
        result = value;
      } else if (result != value) {
        return null;
      }
    }
    return result;
  }
}

class _TrackResolution {
  final AlbumCompletenessStatus status;
  final List<AlbumTrackPosition> missingTracks;
  final int? expectedTrackCount;

  const _TrackResolution({
    required this.status,
    this.missingTracks = const [],
    this.expectedTrackCount,
  });
}
