import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/motion_art/motion_art_album_matcher.dart';
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
/// No token is required. The correct Apple collection id is resolved through
/// the iTunes Search API first so edition qualifiers survive (e.g.
/// "Fearless (Taylor's Version)" must never resolve to the original
/// "Fearless"), then boidu is queried by `?id=`. Song-text search is only a
/// fallback when the album is unknown or the id lookup misses.
///
/// Positive results are cached 24h, negative results 6h, both in memory and on
/// disk, so albums without motion art are not re-queried on every launch.
class AnimatedArtworkService {
  AnimatedArtworkService._();
  static final AnimatedArtworkService instance = AnimatedArtworkService._();

  static const String _boiduBase = 'https://artwork.boidu.dev/';
  static const String _itunesBase = 'https://itunes.apple.com/search';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const Duration _positiveTtl = Duration(hours: 24);
  static const Duration _negativeTtl = Duration(hours: 6);

  /// Transient failures (timeouts, 503s) are retried soon instead of being
  /// cached as "no artwork" for the full negative TTL.
  static const Duration _transientTtl = Duration(seconds: 30);
  static const int _itunesLimit = 25;

  /// boidu rate-limits its upstream, so cap concurrent requests.
  static const int _boiduMaxConcurrent = 2;

  final Map<String, _CacheEntry> _mem = {};
  final Map<String, Future<AnimatedArtwork?>> _inflight = {};

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
    return _resolve(
      key,
      () async {
        final byAlbum = await _resolveAlbum(albumName, artist, storefront);
        if (byAlbum != null) return byAlbum;
        final song = representativeSongTitle?.trim() ?? '';
        if (song.isEmpty) return null;
        return _fetchBoiduSong(
          songTitle: song,
          artist: artist,
          albumName: albumName,
          storefront: storefront,
        );
      },
    );
  }

  Future<AnimatedArtwork?> _resolveFromAlbumOrSong({
    required String songTitle,
    required String artist,
    required String albumName,
    required String storefront,
  }) async {
    if (albumName.isNotEmpty) {
      final byAlbum = await _resolveAlbum(albumName, artist, storefront);
      if (byAlbum != null) return byAlbum;
    }
    return _fetchBoiduSong(
      songTitle: songTitle,
      artist: artist,
      albumName: albumName.isEmpty ? null : albumName,
      storefront: storefront,
    );
  }

  /// iTunes collection id -> boidu `?id=`, then a validated text fallback.
  Future<AnimatedArtwork?> _resolveAlbum(
    String album,
    String artist,
    String storefront,
  ) async {
    final collectionId = await _resolveCollectionId(album, artist, storefront);
    if (collectionId != null) {
      final art = await _fetchBoiduById(collectionId);
      if (art != null && art.hasMotion) return art;
    }
    return _fetchBoiduAlbumText(album, artist, storefront);
  }

  Future<String?> _resolveCollectionId(
    String album,
    String artist,
    String storefront,
  ) async {
    final storefronts = <String>[
      storefront,
      if (storefront != 'us') 'us',
    ];
    for (final sf in storefronts) {
      try {
        final uri = Uri.parse(_itunesBase).replace(
          queryParameters: {
            'term': '$artist $album',
            'media': 'music',
            'entity': 'album',
            'limit': '$_itunesLimit',
            'country': sf,
          },
        );
        final response = await http
            .get(uri, headers: {'User-Agent': _userAgent})
            .timeout(_requestTimeout);
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final results = (decoded['results'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList();
        if (results == null || results.isEmpty) continue;
        final id = MotionArtAlbumMatcher.pickCollectionId(
          album: album,
          artist: artist,
          results: results,
        );
        if (id != null && id.isNotEmpty) return id;
      } catch (error) {
        devLog('[MotionArt] iTunes lookup "$artist - $album" ($sf): $error');
      }
    }
    return null;
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

  Future<AnimatedArtwork?> _fetchBoiduAlbumText(
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
      if (!MotionArtAlbumMatcher.nameMatchesAlbum(
        requested: album,
        candidate: name,
      )) {
        devLog('[MotionArt] rejected edition mismatch: "$album" -> "$name"');
        return null;
      }
      return art;
    } on _MotionArtTransientException {
      rethrow;
    } catch (error) {
      devLog('[MotionArt] boidu search "$artist - $album" ($storefront): $error');
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
      devLog('[MotionArt] boidu song "$artist - $songTitle" ($storefront): $error');
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
        response = await http
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

      final hasMotion = artwork != null && artwork.hasMotion;
      final ttl = hasMotion
          ? _positiveTtl
          : (transient ? _transientTtl : _negativeTtl);
      final entry = _CacheEntry(
        artwork: hasMotion ? artwork : null,
        expiresAtMs: DateTime.now().millisecondsSinceEpoch +
            ttl.inMilliseconds,
      );
      _mem[key] = entry;
      // Only persist definitive outcomes; transient failures retry next launch.
      if (!transient) unawaited(_writeDiskCache(key, entry));
      return entry.artwork;
    }();

    _inflight[key] = future;
    return future.whenComplete(() => _inflight.remove(key));
  }

  String _cacheKey(String prefix, String artist, String album, String sf) {
    final raw = '$prefix|${artist.toLowerCase()}|'
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
