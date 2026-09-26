import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/motion_art/motion_art_album_matcher.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// An Apple Music "Motion Art" record returned by the public boidu.dev proxy.
class AnimatedArtwork {
  const AnimatedArtwork({
    required this.name,
    required this.artist,
    required this.albumId,
    this.staticUrl,
    this.animatedUrl,
    this.animatedVerticalUrl,
    this.videoUrl,
    this.videoUrlVertical,
  });

  final String name;
  final String artist;
  final String albumId;
  final String? staticUrl;

  /// HLS playlist (preferred: adaptive, streams instantly).
  final String? animatedUrl;
  final String? animatedVerticalUrl;

  /// Progressive mp4. boidu serves a 2160x2160 file, so this is never
  /// downloaded up-front — it is only a last-resort stream source.
  final String? videoUrl;
  final String? videoUrlVertical;

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;

  bool get hasMotion =>
      _has(animatedUrl) ||
      _has(videoUrl) ||
      _has(animatedVerticalUrl) ||
      _has(videoUrlVertical);

  /// Best URL to feed [VideoPlayerController]: HLS before 4K mp4.
  String? get playbackUrl {
    for (final url in [
      animatedUrl,
      videoUrl,
      animatedVerticalUrl,
      videoUrlVertical,
    ]) {
      if (_has(url)) return url;
    }
    return null;
  }

  /// Portrait variant for full-bleed backgrounds, falling back to the square
  /// playlist when the album only has square motion art.
  String? get verticalPlaybackUrl {
    for (final url in [
      animatedVerticalUrl,
      videoUrlVertical,
      animatedUrl,
      videoUrl,
    ]) {
      if (_has(url)) return url;
    }
    return null;
  }

  factory AnimatedArtwork.fromJson(Map<String, dynamic> json) {
    String? str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    return AnimatedArtwork(
      name: str(json['name']) ?? '',
      artist: str(json['artist']) ?? '',
      albumId: str(json['albumId']) ?? '',
      staticUrl: str(json['static']),
      animatedUrl: str(json['animated']),
      animatedVerticalUrl: str(json['animatedVertical']),
      videoUrl: str(json['videoUrl']),
      videoUrlVertical: str(json['videoUrlVertical']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'artist': artist,
    'albumId': albumId,
    if (staticUrl != null) 'static': staticUrl,
    if (animatedUrl != null) 'animated': animatedUrl,
    if (animatedVerticalUrl != null) 'animatedVertical': animatedVerticalUrl,
    if (videoUrl != null) 'videoUrl': videoUrl,
    if (videoUrlVertical != null) 'videoUrlVertical': videoUrlVertical,
  };
}

class _CacheEntry {
  const _CacheEntry({required this.artwork, required this.expiresAtMs});
  final AnimatedArtwork? artwork;
  final int expiresAtMs;
}

/// Thrown when a lookup failed for a reason that may succeed later (timeout,
/// network error, boidu 429/503). These are cached briefly, never for 6h.
class _MotionArtTransientException implements Exception {
  const _MotionArtTransientException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Fetches Apple Music Motion Art (animated album artwork) from the public
/// boidu.dev proxy.
///
/// No token is required. Collection ids are resolved through the iTunes
/// Search API first so edition qualifiers survive (e.g. "Fearless (Taylor's
/// Version)" must never resolve to the original "Fearless"), then every
/// candidate is probed through boidu's `?id=` until one has motion — motion
/// art often lives on a sibling edition of the same album. Validated text
/// search is the fallback when search misses the album entirely.
///
/// Positive results are cached 24h, negative results 30min, both in memory and
/// on disk, so albums without motion art are not re-queried on every launch,
/// but a newly released album that later gains motion art is picked up quickly.
class AnimatedArtworkService {
  AnimatedArtworkService._({http.Client? client})
    : _client = client ?? http.Client();

  static final AnimatedArtworkService instance = AnimatedArtworkService._();

  @visibleForTesting
  static AnimatedArtworkService create({http.Client? client}) =>
      AnimatedArtworkService._(client: client);

  final http.Client _client;

  static const String _boiduBase = 'https://artwork.boidu.dev/';
  static const String _itunesBase = 'https://itunes.apple.com/search';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _positiveTtl = Duration(hours: 24);

  /// Short so a just-released album that gains motion art upstream surfaces
  /// within the hour instead of being hidden by a day-scale negative cache.
  static const Duration _negativeTtl = Duration(minutes: 30);

  /// Transient failures (timeouts, 503s) are retried soon instead of being
  /// cached as "no artwork" for the full negative TTL.
  static const Duration _transientTtl = Duration(seconds: 30);
  static const int _itunesLimit = 25;

  /// Cap on iTunes collection candidates probed per lookup so a bad album
  /// search cannot turn into a boidu request storm.
  static const int _maxCollectionCandidates = 3;

  /// Bump when resolution logic changes: the version is part of the cache key
  /// so stale negative entries stop hiding a now-resolvable album.
  static const String _cacheVersion = 'v4';

  /// boidu rate-limits its upstream, so cap concurrent requests.
  static const int _boiduMaxConcurrent = 2;

  final Map<String, _CacheEntry> _mem = {};
  final Map<String, Future<AnimatedArtwork?>> _inflight = {};

  /// Per-key generation used to drop results of lookups that were invalidated
  /// while still in flight.
  final Map<String, int> _epoch = {};

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Bumps when cached lookups are invalidated so visible motion-art widgets
  /// can restart their load.
  ValueListenable<int> get revision => _revision;

  int _boiduActive = 0;
  final List<Completer<void>> _boiduWaiters = [];

  /// Motion art for a playing song. Album metadata takes priority so the right
  /// edition is resolved; the song title is only used as a fallback.
  Future<AnimatedArtwork?> getAnimatedArtwork({
    required String songTitle,
    required String artist,
    String? albumName,
    Duration? duration,
    String storefront = 'us',
  }) {
    final album = albumName?.trim() ?? '';
    final key = _cacheKey(
      'song:${songTitle.trim()}',
      artist,
      album,
      storefront,
    );
    return _resolve(
      key,
      () => _resolveFromAlbumOrSong(
        songTitle: songTitle,
        artist: artist,
        albumName: album,
        storefront: storefront,
      ),
    );
  }

  /// Motion art for an album hero. Album-first so the edition is preserved.
  Future<AnimatedArtwork?> getAnimatedArtworkForAlbum({
    required String albumName,
    required String artist,
    String? representativeSongTitle,
    String storefront = 'us',
  }) {
    final key = _cacheKey('album:${albumName.trim()}', artist, '', storefront);
    return _resolve(key, () async {
      final byAlbum = await _resolveAlbum(
        albumName,
        artist,
        storefront,
        representativeSongTitle: representativeSongTitle,
      );
      if (byAlbum != null) return byAlbum;
      final song = representativeSongTitle?.trim() ?? '';
      if (song.isEmpty) return null;
      return _fetchBoiduSong(
        songTitle: song,
        artist: artist,
        albumName: albumName,
        storefront: storefront,
      );
    });
  }

  /// Drops cached lookups (positive or negative) for an album and optionally
  /// one of its songs, then notifies [revision] listeners so visible widgets
  /// reload. Backs the manual "Refresh Motion Art" action.
  Future<void> refreshAlbumArtwork({
    required String artist,
    String? albumName,
    String? songTitle,
    String storefront = 'us',
  }) async {
    final album = albumName?.trim() ?? '';
    final song = songTitle?.trim() ?? '';
    final keys = <String>{
      if (album.isNotEmpty) _cacheKey('album:$album', artist, '', storefront),
      if (song.isNotEmpty) _cacheKey('song:$song', artist, album, storefront),
    };
    for (final key in keys) {
      _epoch[key] = _epochFor(key) + 1;
      _mem.remove(key);
      _inflight.remove(key);
      await _deleteDiskCache(key);
    }
    _revision.value++;
  }

  Future<AnimatedArtwork?> _resolveFromAlbumOrSong({
    required String songTitle,
    required String artist,
    required String albumName,
    required String storefront,
  }) async {
    if (albumName.isNotEmpty) {
      final byAlbum = await _resolveAlbum(
        albumName,
        artist,
        storefront,
        representativeSongTitle: songTitle,
      );
      if (byAlbum != null) return byAlbum;
    }
    return _fetchBoiduSong(
      songTitle: songTitle,
      artist: artist,
      albumName: albumName.isEmpty ? null : albumName,
      storefront: storefront,
    );
  }

  /// Resolves collection candidates from iTunes, probes each through boidu's
  /// `?id=` until one has motion, then falls back to validated text search.
  ///
  /// Album search runs first and only when it finds no motion is the song
  /// search consulted — it is a discovery backup for albums iTunes misses,
  /// not a per-lookup cost.
  Future<AnimatedArtwork?> _resolveAlbum(
    String album,
    String artist,
    String storefront, {
    String? representativeSongTitle,
  }) async {
    final albumIds = await _albumCollectionIds(album, artist, storefront);
    for (final id in albumIds) {
      final art = await _fetchBoiduById(id);
      if (art != null && art.hasMotion) return art;
    }
    if (albumIds.length < _maxCollectionCandidates) {
      final songIds = await _songCollectionIds(
        album,
        artist,
        representativeSongTitle,
        storefront,
        exclude: albumIds.toSet(),
      );
      for (final id in songIds) {
        final art = await _fetchBoiduById(id);
        if (art != null && art.hasMotion) return art;
      }
    }
    return _fetchBoiduAlbumText(album, artist, storefront);
  }

  /// Ranked album-entity candidates, best edition first.
  Future<List<String>> _albumCollectionIds(
    String album,
    String artist,
    String storefront,
  ) async {
    final ids = <String>[];
    final seen = <String>{};
    for (final sf in _storefronts(storefront)) {
      if (ids.length >= _maxCollectionCandidates) break;
      final results = await _itunesSearch(
        term: '$artist $album',
        entity: 'album',
        storefront: sf,
      );
      for (final id in MotionArtAlbumMatcher.rankCollectionIds(
        album: album,
        artist: artist,
        results: results,
      )) {
        if (seen.add(id)) ids.add(id);
      }
    }
    return ids;
  }

  /// Ranked collection ids harvested from song-entity results, with the
  /// collection holding [representativeSongTitle] first.
  Future<List<String>> _songCollectionIds(
    String album,
    String artist,
    String? representativeSongTitle,
    String storefront, {
    Set<String> exclude = const {},
  }) async {
    final song = representativeSongTitle?.trim() ?? '';
    final ids = <String>[];
    final seen = <String>{...exclude};
    for (final sf in _storefronts(storefront)) {
      if (ids.length >= _maxCollectionCandidates) break;
      final results = await _itunesSearch(
        term: song.isEmpty ? '$artist $album' : '$artist $song',
        entity: 'song',
        storefront: sf,
      );
      for (final id in MotionArtAlbumMatcher.rankCollectionIdsFromSongs(
        album: album,
        artist: artist,
        representativeSongTitle: song,
        results: results,
      )) {
        if (seen.add(id)) ids.add(id);
      }
    }
    return ids;
  }

  List<String> _storefronts(String storefront) => [
    storefront,
    if (storefront != 'us') 'us',
  ];

  Future<List<Map<String, dynamic>>> _itunesSearch({
    required String term,
    required String entity,
    required String storefront,
  }) async {
    try {
      final uri = Uri.parse(_itunesBase).replace(
        queryParameters: {
          'term': term,
          'media': 'music',
          'entity': entity,
          'limit': '$_itunesLimit',
          'country': storefront,
        },
      );
      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      return (decoded['results'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
    } catch (error) {
      devLog('[MotionArt] iTunes $entity search "$term" ($storefront): $error');
      return const [];
    }
  }

  Future<AnimatedArtwork?> _fetchBoiduById(String collectionId) async {
    try {
      final uri = Uri.parse(
        _boiduBase,
      ).replace(queryParameters: {'id': collectionId});
      final art = await _getBoidu(uri);
      return (art != null && art.hasMotion) ? art : null;
    } on _MotionArtTransientException catch (error) {
      devLog('[MotionArt] boidu id $collectionId: $error');
      rethrow;
    } catch (error) {
      devLog('[MotionArt] boidu id $collectionId failed: $error');
      throw _MotionArtTransientException('$error');
    }
  }

  /// Text-search fallback, retried with the primary artist when a collab
  /// credit ("Tiësto & Tate McRae") sends boidu into another artist's catalog.
  Future<AnimatedArtwork?> _fetchBoiduAlbumText(
    String album,
    String artist,
    String storefront,
  ) async {
    for (final candidate in MotionArtAlbumMatcher.artistVariants(artist)) {
      final art = await _fetchBoiduAlbumTextOnce(album, candidate, storefront);
      if (art != null) return art;
    }
    return null;
  }

  Future<AnimatedArtwork?> _fetchBoiduAlbumTextOnce(
    String album,
    String artist,
    String storefront,
  ) async {
    try {
      final uri = Uri.parse(_boiduBase).replace(
        queryParameters: {'s': album, 'a': artist, 'storefront': storefront},
      );
      final art = await _getBoidu(uri);
      // A valid response with no motion is definitive: stop, don't retry.
      if (art == null || !art.hasMotion) return null;
      final name = art.name.isNotEmpty ? art.name : album;
      if (MotionArtAlbumMatcher.nameMatchesAlbum(
        requested: album,
        candidate: name,
      )) {
        return art;
      }
      // boidu's `?s=` is a SONG search: it can label the right collection with
      // a track name ("All Nighter" for DRIVE). Before treating this as an
      // edition mismatch, ask by id and trust the canonical title.
      if (art.albumId.isNotEmpty &&
          MotionArtAlbumMatcher.baseName(name) !=
              MotionArtAlbumMatcher.baseName(album)) {
        final canonical = await _fetchBoiduById(art.albumId);
        if (canonical != null &&
            canonical.hasMotion &&
            MotionArtAlbumMatcher.nameMatchesAlbum(
              requested: album,
              candidate: canonical.name,
            ) &&
            MotionArtAlbumMatcher.artistMatches(artist, canonical.artist)) {
          return canonical;
        }
      }
      devLog(
        '[MotionArt] rejected edition mismatch: "$artist" "$album" -> "$name"',
      );
      return null;
    } on _MotionArtTransientException {
      rethrow;
    } catch (error) {
      devLog(
        '[MotionArt] boidu search "$artist - $album" ($storefront): $error',
      );
      throw _MotionArtTransientException('$error');
    }
  }

  Future<AnimatedArtwork?> _fetchBoiduSong({
    required String songTitle,
    required String artist,
    required String? albumName,
    required String storefront,
  }) async {
    try {
      final uri = Uri.parse(_boiduBase).replace(
        queryParameters: {
          's': songTitle,
          'a': artist,
          if (albumName != null && albumName.isNotEmpty) 'al': albumName,
          'storefront': storefront,
        },
      );
      final art = await _getBoidu(uri);
      if (art == null || !art.hasMotion) return null;
      // Guard against song-level lookups returning a different edition.
      // Only strict when the album carries an edition qualifier; otherwise
      // boidu may echo the song title instead of the album name.
      final album = albumName;
      if (album != null &&
          album.isNotEmpty &&
          art.name.isNotEmpty &&
          MotionArtAlbumMatcher.editionTokens(album).isNotEmpty &&
          !MotionArtAlbumMatcher.nameMatchesAlbum(
            requested: album,
            candidate: art.name,
          )) {
        devLog(
          '[MotionArt] rejected song-level edition mismatch: '
          '"$album" -> "${art.name}"',
        );
        return null;
      }
      return art;
    } on _MotionArtTransientException {
      rethrow;
    } catch (error) {
      devLog(
        '[MotionArt] boidu song "$artist - $songTitle" ($storefront): $error',
      );
      throw _MotionArtTransientException('$error');
    }
  }

  /// Runs [action] with at most [_boiduMaxConcurrent] boidu requests in flight.
  Future<T> _withBoiduSlot<T>(Future<T> Function() action) async {
    if (_boiduActive >= _boiduMaxConcurrent) {
      final waiter = Completer<void>();
      _boiduWaiters.add(waiter);
      await waiter.future;
    }
    _boiduActive++;
    try {
      return await action();
    } finally {
      _boiduActive--;
      if (_boiduWaiters.isNotEmpty) {
        _boiduWaiters.removeAt(0).complete();
      }
    }
  }

  Future<AnimatedArtwork?> _getBoidu(Uri uri) {
    return _withBoiduSlot(() async {
      final http.Response response;
      try {
        response = await _client
            .get(uri, headers: {'User-Agent': _userAgent})
            .timeout(_requestTimeout);
      } on TimeoutException {
        throw const _MotionArtTransientException('boidu request timed out');
      } catch (error) {
        throw _MotionArtTransientException('boidu network error: $error');
      }
      if (response.statusCode == 429 || response.statusCode == 503) {
        throw const _MotionArtTransientException('boidu rate limited');
      }
      if (response.statusCode != 200) {
        throw _MotionArtTransientException('boidu http ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['error'] != null) return null;
      final art = AnimatedArtwork.fromJson(decoded);
      return art.hasMotion ? art : null;
    });
  }

  /// Memory cache -> disk cache -> in-flight dedupe -> network.
  Future<AnimatedArtwork?> _resolve(
    String key,
    Future<AnimatedArtwork?> Function() loader,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _mem[key];
    if (cached != null && now < cached.expiresAtMs) {
      return Future.value(cached.artwork);
    }

    final existing = _inflight[key];
    if (existing != null) return existing;

    final epoch = _epochFor(key);
    final future = () async {
      final disk = await _readDiskCache(key);
      if (disk != null) {
        _mem[key] = disk;
        return disk.artwork;
      }

      AnimatedArtwork? artwork;
      var transient = false;
      try {
        artwork = await loader();
      } on _MotionArtTransientException catch (error) {
        devLog('[MotionArt] transient "$key": $error');
        transient = true;
      } catch (error) {
        devLog('[MotionArt] resolve "$key" failed: $error');
        transient = true;
      }

      // A manual refresh may have invalidated this lookup while it was in
      // flight; hand the result back but do not cache it.
      if (_epochFor(key) != epoch) return artwork;

      final hasMotion = artwork != null && artwork.hasMotion;
      final ttl = hasMotion
          ? _positiveTtl
          : (transient ? _transientTtl : _negativeTtl);
      final entry = _CacheEntry(
        artwork: hasMotion ? artwork : null,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds,
      );
      _mem[key] = entry;
      // Only persist definitive outcomes; transient failures retry next launch.
      if (!transient) unawaited(_writeDiskCache(key, entry));
      return entry.artwork;
    }();

    _inflight[key] = future;
    return future.whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    });
  }

  int _epochFor(String key) => _epoch[key] ?? 0;

  String _cacheKey(String prefix, String artist, String album, String sf) {
    final raw =
        '$_cacheVersion|$prefix|${artist.toLowerCase()}|'
        '${album.toLowerCase()}|$sf';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/motion_art');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<_CacheEntry?> _readDiskCache(String key) async {
    try {
      final file = File('${(await _cacheDir()).path}/$key.json');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final expiresAtMs = (decoded['expiresAtMs'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch >= expiresAtMs) {
        await file.delete();
        return null;
      }
      final artJson = decoded['artwork'];
      if (decoded['negative'] == true || artJson is! Map<String, dynamic>) {
        return _CacheEntry(artwork: null, expiresAtMs: expiresAtMs);
      }
      final artwork = AnimatedArtwork.fromJson(artJson);
      return _CacheEntry(
        artwork: artwork.hasMotion ? artwork : null,
        expiresAtMs: expiresAtMs,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteDiskCache(String key) async {
    try {
      final file = File('${(await _cacheDir()).path}/$key.json');
      if (await file.exists()) await file.delete();
    } catch (error) {
      devLog('[MotionArt] cache delete failed: $error');
    }
  }

  Future<void> _writeDiskCache(String key, _CacheEntry entry) async {
    try {
      final file = File('${(await _cacheDir()).path}/$key.json');
      await file.writeAsString(
        jsonEncode({
          'expiresAtMs': entry.expiresAtMs,
          'negative': entry.artwork == null,
          if (entry.artwork != null) 'artwork': entry.artwork!.toJson(),
        }),
        flush: true,
      );
    } catch (error) {
      devLog('[MotionArt] cache write failed: $error');
    }
  }
}
