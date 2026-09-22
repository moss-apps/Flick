import 'package:flutter/foundation.dart';

import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/album_art_import_service.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';
import 'package:flick/services/apple_music/apple_music_models.dart';
import 'package:flick/services/metadata_editor_service.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' show TagEditFields;

/// One local file paired with the Apple Music track it likely is.
class AlbumIdentificationSuggestion {
  const AlbumIdentificationSuggestion({
    required this.song,
    this.track,
    this.durationDeltaMs,
  });

  final Song song;
  final AppleMusicTrack? track;
  final int? durationDeltaMs;

  bool get matched => track != null;
}

/// A candidate release with every local file mapped onto its track list.
class AlbumIdentificationCandidate {
  const AlbumIdentificationCandidate({
    required this.match,
    required this.tracks,
    required this.suggestions,
    required this.confidence,
    required this.matchedCount,
    required this.nameMatchCount,
  });

  final AppleMusicAlbumMatch match;
  final List<AppleMusicTrack> tracks;
  final List<AlbumIdentificationSuggestion> suggestions;
  final double confidence;
  final int matchedCount;
  final int nameMatchCount;

  int get songCount => suggestions.length;

  String get matchedLabel => '$matchedCount/${suggestions.length} matched';

  int? get year => match.releaseDate == null
      ? null
      : int.tryParse(match.releaseDate!.split('-').first);
}

/// Outcome of writing an identification to the library database.
class AlbumIdentificationApplyResult {
  const AlbumIdentificationApplyResult({
    required this.updatedSongs,
    required this.artworkApplied,
  });

  final int updatedSongs;
  final bool artworkApplied;
}

/// Matches untagged local albums against Apple Music releases by combining
/// folder-derived seeds, filename/tag text and track duration.
class AlbumIdentificationService {
  AlbumIdentificationService._({
    AppleMusicMetadataService? metadata,
    SongRepository? repository,
  }) : _metadata = metadata ?? AppleMusicMetadataService.instance,
       _repository = repository;

  static final AlbumIdentificationService instance =
      AlbumIdentificationService._();

  @visibleForTesting
  static AlbumIdentificationService create({
    AppleMusicMetadataService? metadata,
    SongRepository? repository,
  }) => AlbumIdentificationService._(
    metadata: metadata,
    repository: repository,
  );

  final AppleMusicMetadataService _metadata;
  final SongRepository? _repository;

  static const int _durationToleranceMs = 5000;
  static const int _scoredCandidateLimit = 8;

  static const Set<String> _unknownNames = {
    '',
    'unknown',
    'unknown artist',
    'unknown album',
    'various artists',
    'va',
  };

  static const Set<String> _genericFolders = {
    'music',
    'downloads',
    'download',
    'audio',
    'sdcard',
    'storage',
    'emulated',
    'internal storage',
    'files',
    'media',
    '0',
  };

  static bool isUnknownName(String? value) =>
      _unknownNames.contains(value?.trim().toLowerCase() ?? '');

  /// True when a candidate clearly corresponds to the supplied seeds: same
  /// normalized artist and album names, plus agreement on file lengths.
  static bool matchesSeed(
    AlbumIdentificationCandidate candidate, {
    required String artist,
    required String album,
    double minConfidence = 0.5,
  }) {
    if (artist.trim().isEmpty || album.trim().isEmpty) return false;
    return _normalize(candidate.match.artistName) == _normalize(artist) &&
        _normalize(candidate.match.name) == _normalize(album) &&
        candidate.matchedCount >= 1 &&
        candidate.confidence >= minConfidence;
  }

  /// Guesses artist and album from the folder layout. Walks parent folders
  /// upwards so `.../<Artist>/<Album>/<track>` yields artist + album, while
  /// generic folders such as `Music` are skipped.
  static ({String artist, String album}) deriveFolderSeeds(
    Iterable<Song> songs,
  ) {
    for (final song in songs) {
      final path = song.filePath;
      if (path == null || path.isEmpty) continue;
      final segments = path
          .replaceAll('\\', '/')
          .split('/')
          .where((segment) => segment.trim().isNotEmpty)
          .toList();
      if (segments.length < 2) continue;

      String? album;
      String? artist;
      for (var index = segments.length - 2; index >= 0; index--) {
        final segment = segments[index].trim();
        if (_genericFolders.contains(segment.toLowerCase())) continue;
        if (album == null) {
          album = segment;
        } else {
          artist = segment;
          break;
        }
      }
      if (album == null && artist == null) continue;
      return (artist: artist ?? '', album: album ?? '');
    }
    return (artist: '', album: '');
  }

  /// Searches Apple Music for the album and scores every plausible release
  /// against the local files, best candidate first.
  Future<List<AlbumIdentificationCandidate>> findCandidates({
    required List<Song> songs,
    String? artist,
    String? album,
    int limit = 25,
    String? storefront,
  }) async {
    final seed = deriveFolderSeeds(songs);
    final effectiveArtist = isUnknownName(artist) ? seed.artist : artist!.trim();
    final effectiveAlbum = isUnknownName(album) ? seed.album : album!.trim();
    final matchable = _matchableSongs(songs);
    if (matchable.isEmpty || effectiveAlbum.isEmpty) return const [];

    final term = [effectiveArtist, effectiveAlbum]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final matches = await _metadata.searchAlbums(
      term,
      limit: limit,
      storefront: storefront,
    );
    if (matches.isEmpty) return const [];

    final ordered = _orderMatches(matches, effectiveArtist, effectiveAlbum);
    final scored = await Future.wait([
      for (final match in ordered.take(_scoredCandidateLimit))
        _score(match, matchable, storefront),
    ]);
    scored.sort((a, b) {
      final byConfidence = b.confidence.compareTo(a.confidence);
      if (byConfidence != 0) return byConfidence;
      return b.nameMatchCount.compareTo(a.nameMatchCount);
    });
    return scored;
  }

  List<Song> _matchableSongs(List<Song> songs) => [
    for (final song in songs)
      if (song.startOffsetMs == null &&
          song.filePath != null &&
          song.filePath!.isNotEmpty)
        song,
  ];

  List<AppleMusicAlbumMatch> _orderMatches(
    List<AppleMusicAlbumMatch> matches,
    String artist,
    String album,
  ) {
    final albumNorm = _normalize(album);
    final albumBase = _normalize(_baseName(album));
    final artistNorm = _normalize(artist);
    final ranked = List<AppleMusicAlbumMatch>.from(matches);
    int rank(AppleMusicAlbumMatch match) {
      final name = _normalize(match.name);
      final artistMatch =
          artistNorm.isEmpty || _normalize(match.artistName) == artistNorm;
      if (name == albumNorm) return artistMatch ? 0 : 1;
      if (_normalize(_baseName(match.name)) == albumBase) {
        return artistMatch ? 2 : 3;
      }
      return 4;
    }

    ranked.sort((a, b) => rank(a).compareTo(rank(b)));
    return ranked;
  }

  Future<AlbumIdentificationCandidate> _score(
    AppleMusicAlbumMatch match,
    List<Song> songs,
    String? storefront,
  ) async {
    final tracks = await _metadata.getAlbumTracks(
      match.collectionId,
      storefront: storefront,
    );
    final remaining = <AppleMusicTrack?>[...tracks];
    final suggestions = <AlbumIdentificationSuggestion>[];
    var durationMatched = 0;
    var nameMatched = 0;

    for (final song in songs) {
      final durationMs = song.duration.inMilliseconds;
      AppleMusicTrack? best;
      var bestDelta = _durationToleranceMs;

      if (durationMs > 0) {
        for (final track in remaining) {
          final trackMs = track?.durationMs;
          if (track == null || trackMs == null || trackMs <= 0) continue;
          final delta = (trackMs - durationMs).abs();
          if (delta < bestDelta) {
            bestDelta = delta;
            best = track;
          }
        }
      }

      if (best != null) {
        remaining[remaining.indexOf(best)] = null;
        durationMatched++;
        if (_nameScore(song.title, best.trackName) > 0) nameMatched++;
      }

      suggestions.add(
        AlbumIdentificationSuggestion(
          song: song,
          track: best,
          durationDeltaMs: best == null ? null : bestDelta,
        ),
      );
    }

    final total = songs.length;
    final confidence = total == 0
        ? 0.0
        : 0.65 * (durationMatched / total) + 0.35 * (nameMatched / total);

    return AlbumIdentificationCandidate(
      match: match,
      tracks: tracks,
      suggestions: suggestions,
      confidence: confidence,
      matchedCount: durationMatched,
      nameMatchCount: nameMatched,
    );
  }

  double _nameScore(String localTitle, String trackName) {
    final local = _normalize(localTitle);
    final track = _normalize(trackName);
    if (local.isEmpty || track.isEmpty) return 0;
    if (local == track) return 1;
    if (local.contains(track) || track.contains(local)) return 0.6;
    return 0;
  }

  /// Writes the chosen release to the library: artwork first (while the old
  /// album grouping is still valid), then tags for every matched file.
  /// Blank files (common with WAV) get a fresh tag created during write-back,
  /// with a DB-only fallback when the file itself cannot be written.
  Future<AlbumIdentificationApplyResult> applyCandidate(
    AlbumIdentificationCandidate candidate, {
    bool applyArtwork = true,
  }) async {
    var artworkApplied = false;
    final artworkUrl = candidate.match.artworkUrl;
    if (applyArtwork && artworkUrl != null && candidate.suggestions.isNotEmpty) {
      final bytes = await _metadata.fetchArtworkBytes(artworkUrl);
      if (bytes != null) {
        try {
          await AlbumArtImportService.instance.applyImageBytes(
            song: candidate.suggestions.first.song,
            bytes: bytes,
          );
          artworkApplied = true;
        } catch (_) {
          // Artwork is best effort; metadata still gets written.
        }
      }
    }

    final artistName = candidate.match.artistName.trim();
    final albumName = candidate.match.name.trim();
    final repository = _repository ?? SongRepository();
    var updated = 0;
    for (final suggestion in candidate.suggestions) {
      final path = suggestion.song.filePath;
      if (path == null || path.isEmpty) continue;
      final track = suggestion.track;
      final title = track?.trackName ?? suggestion.song.title;
      final fields = TagEditFields(
        title: title,
        artist: artistName.isEmpty ? null : artistName,
        album: albumName.isEmpty ? null : albumName,
        albumArtist: artistName.isEmpty ? null : artistName,
        genre: candidate.match.genre,
        year: candidate.year,
        trackNumber: track?.trackNumber,
        discNumber: track?.discNumber,
      );

      final write = await MetadataEditorService.instance.writeTags(
        suggestion.song,
        fields,
      );
      if (!write.saved) {
        await repository.updateSongMetadata(
          path,
          title: fields.title,
          artist: fields.artist,
          album: fields.album,
          albumArtist: fields.albumArtist,
          trackNumber: fields.trackNumber,
          discNumber: fields.discNumber,
          year: fields.year,
          genre: fields.genre,
        );
      }
      updated++;
    }

    return AlbumIdentificationApplyResult(
      updatedSongs: updated,
      artworkApplied: artworkApplied,
    );
  }

  static String _baseName(String name) {
    var result = name.trim();
    for (final marker in const [' (', ' [', ' - ', ': ']) {
      final index = result.indexOf(marker);
      if (index > 0) result = result.substring(0, index);
    }
    return result;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
