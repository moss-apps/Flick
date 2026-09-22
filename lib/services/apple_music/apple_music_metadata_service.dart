import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'apple_music_cache.dart';
import 'apple_music_models.dart';

/// Raised when a lookup failed for a reason that may succeed later (timeout,
/// network error, rate limit). Cached briefly so it is retried soon.
class AppleMusicTransientException implements Exception {
  const AppleMusicTransientException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the artist page needs from Apple Music in one shot.
class AppleMusicArtistData {
  const AppleMusicArtistData({
    required this.artist,
    this.info,
    this.topSongs = const [],
  });

  final AppleMusicArtist artist;
  final AppleMusicArtistInfo? info;
  final List<AppleMusicTopSong> topSongs;

  bool get hasContent =>
      (info?.biography?.isNotEmpty ?? false) ||
      (info?.imageUrl?.isNotEmpty ?? false) ||
      (info?.similarArtists.isNotEmpty ?? false) ||
      topSongs.isNotEmpty;
}

/// Everything the album page needs from Apple Music in one shot.
class AppleMusicAlbumData {
  const AppleMusicAlbumData({
    required this.match,
    this.info,
    this.tracks = const [],
  });

  final AppleMusicAlbumMatch match;
  final AppleMusicAlbumInfo? info;
  final List<AppleMusicTrack> tracks;

  String? get notes => info?.notes;

  bool get hasContent => (notes?.isNotEmpty ?? false) || tracks.isNotEmpty;
}

/// Native Dart client for Apple Music metadata, modelled after the
/// navidrome/apple-music-plugin endpoints but rewritten from scratch.
///
/// iTunes Search/Lookup supplies artist ids, discographies and top songs;
/// artist and album pages are scraped for biography, images, similar artists
/// and editorial notes. Everything fails soft and is cached on disk.
class AppleMusicMetadataService {
  AppleMusicMetadataService._({http.Client? client, AppleMusicCache? cache})
    : _client = client ?? http.Client(),
      _cache = cache ?? AppleMusicCache.instance;

  static final AppleMusicMetadataService instance =
      AppleMusicMetadataService._();

  @visibleForTesting
  static AppleMusicMetadataService create({
    http.Client? client,
    AppleMusicCache? cache,
  }) => AppleMusicMetadataService._(client: client, cache: cache);

  final http.Client _client;
  final AppleMusicCache _cache;

  static const String _itunesSearchBase = 'https://itunes.apple.com/search';
  static const String _itunesLookupBase = 'https://itunes.apple.com/lookup';
  static const String _musicBase = 'https://music.apple.com';
  static const String _userAgent =
      'FlickPlayer/0.22.0 (apple-music-metadata)';
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _infoTtl = Duration(days: 7);
  static const Duration _artistIdTtl = Duration(days: 30);
  static const Duration _topSongsTtl = Duration(days: 1);
  static const Duration _negativeTtl = Duration(hours: 2);
  static const Duration _transientTtl = Duration(seconds: 30);
  static const int _artistSearchLimit = 5;
  static const int _albumLookupLimit = 200;
  static const String _cacheVersion = 'v1';
  static const int _similarWindowChars = 60000;

  int _throttleUntilMs = 0;

  static final RegExp _storefrontRe = RegExp(r'^[a-z]{2}$');
  static final RegExp _whitespaceRe = RegExp(r'\s+');
  static final RegExp _jsonLdRe = RegExp(
    r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
    dotAll: true,
    caseSensitive: false,
  );
  static final RegExp _serializedDataRe = RegExp(
    r'<script[^>]*id="serialized-server-data"[^>]*>(.*?)</script>',
    dotAll: true,
  );
  static final RegExp _lockupTitleRe = RegExp(
    r'data-testid="ellipse-lockup__title"[^>]*>([^<]+)<',
  );
  static final RegExp _htmlTagRe = RegExp(r'<[^>]+>');
  static final RegExp _imageSizeRe = RegExp(r'\d+x\d+[a-z]*\.');
  static final RegExp _sentenceEndRe = RegExp(r'[.!?\n]');

  /// The storefront derived from the device locale, falling back to `us`.
  String get deviceStorefront => _primaryStorefront(null);

  /// Resolves an artist name to an Apple Music artist. Exact normalized-name
  /// matches win; otherwise iTunes relevance order decides.
  Future<AppleMusicArtist?> resolveArtist(
    String name, {
    String? storefront,
    bool refresh = false,
  }) {
    final query = name.trim();
    if (query.isEmpty) return Future.value(null);
    final sf = _primaryStorefront(storefront);
    return _cache.fetch<AppleMusicArtist>(
      key: _key('artist', '${_normalize(query)}|$sf'),
      refresh: refresh,
      loader: () async {
        final results = await _itunesSearch(
          term: query,
          entity: 'musicArtist',
          limit: _artistSearchLimit,
          storefront: sf,
        );
        return _bestArtistMatch(query, results, sf);
      },
      encode: (artist) => artist.toJson(),
      decode: AppleMusicArtist.fromJson,
      ttl: _artistIdTtl,
      negativeTtl: _negativeTtl,
      transientTtl: _transientTtl,
    );
  }

  /// Biography, image and similar artists for an artist id.
  Future<AppleMusicArtistInfo?> getArtistInfo(
    String artistId, {
    String? storefront,
    bool refresh = false,
  }) {
    final id = artistId.trim();
    if (id.isEmpty) return Future.value(null);
    final sf = _primaryStorefront(storefront);
    return _cache.fetch<AppleMusicArtistInfo>(
      key: _key('artist-info', '$id|$sf'),
      refresh: refresh,
      loader: () async {
        AppleMusicArtistInfo? fallback;
        for (final candidate in _storefronts(sf)) {
          final info = await _fetchArtistInfo(id, candidate);
          if (info == null) continue;
          if (_hasArtistContent(info)) return info;
          fallback ??= info;
        }
        return fallback;
      },
      encode: (info) => info.toJson(),
      decode: AppleMusicArtistInfo.fromJson,
      ttl: _infoTtl,
      negativeTtl: _negativeTtl,
      transientTtl: _transientTtl,
    );
  }

  Future<List<AppleMusicTopSong>> getTopSongs(
    String artistId, {
    int limit = 10,
    String? storefront,
    bool refresh = false,
  }) {
    final id = artistId.trim();
    if (id.isEmpty) return Future.value(const <AppleMusicTopSong>[]);
    final sf = _primaryStorefront(storefront);
    final capped = limit.clamp(1, 25);
    return _cache
        .fetch<List<AppleMusicTopSong>>(
          key: _key('top-songs', '$id|$capped|$sf'),
          refresh: refresh,
          loader: () async {
            final results = await _itunesLookup(
              id: id,
              entity: 'song',
              sort: 'popular',
              limit: capped,
              storefront: sf,
            );
            final songs = <AppleMusicTopSong>[];
            for (final result in results) {
              if (result['wrapperType'] != 'track') continue;
              final trackName = _clean(result['trackName']);
              if (trackName == null) continue;
              songs.add(
                AppleMusicTopSong(
                  trackName: trackName,
                  artistName: _clean(result['artistName']) ?? '',
                  collectionName: _clean(result['collectionName']),
                  durationMs: (result['trackTimeMillis'] as num?)?.toInt(),
                ),
              );
              if (songs.length >= capped) break;
            }
            return songs;
          },
          encode: (songs) => {
            'songs': [for (final song in songs) song.toJson()],
          },
          decode: (json) =>
              (json['songs'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .map(AppleMusicTopSong.fromJson)
                  .toList() ??
              const <AppleMusicTopSong>[],
          ttl: _topSongsTtl,
          negativeTtl: _negativeTtl,
          transientTtl: _transientTtl,
        )
        .then((songs) => songs ?? const <AppleMusicTopSong>[]);
  }

  /// Resolves an artist and loads biography, image, similar artists and top
  /// songs in parallel. Returns null when the artist is not on Apple Music.
  Future<AppleMusicArtistData?> getArtistData(
    String name, {
    int topSongLimit = 10,
    String? storefront,
    bool refresh = false,
  }) async {
    final artist = await resolveArtist(
      name,
      storefront: storefront,
      refresh: refresh,
    );
    if (artist == null) return null;

    final (info, topSongs) = await (
      getArtistInfo(artist.artistId, storefront: storefront, refresh: refresh),
      getTopSongs(
        artist.artistId,
        limit: topSongLimit,
        storefront: storefront,
        refresh: refresh,
      ),
    ).wait;

    return AppleMusicArtistData(
      artist: artist,
      info: info,
      topSongs: topSongs,
    );
  }

  /// Finds the album in the artist's iTunes discography using exact name,
  /// base-name and containment passes in that order.
  Future<AppleMusicAlbumMatch?> resolveAlbum({
    required String album,
    required String artist,
    String? storefront,
    bool refresh = false,
  }) {
    final albumName = album.trim();
    final artistName = artist.trim();
    if (albumName.isEmpty || artistName.isEmpty) return Future.value(null);
    final sf = _primaryStorefront(storefront);
    return _cache.fetch<AppleMusicAlbumMatch>(
      key: _key('album', '${_normalize(artistName)}|${_normalize(albumName)}|$sf'),
      refresh: refresh,
      loader: () async {
        final artistMatch = await resolveArtist(
          artistName,
          storefront: sf,
          refresh: refresh,
        );
        if (artistMatch == null) return null;
        final results = await _itunesLookup(
          id: artistMatch.artistId,
          entity: 'album',
          limit: _albumLookupLimit,
          storefront: sf,
        );
        return _bestAlbumMatch(albumName, results, sf);
      },
      encode: (match) => match.toJson(),
      decode: AppleMusicAlbumMatch.fromJson,
      ttl: _infoTtl,
      negativeTtl: _negativeTtl,
      transientTtl: _transientTtl,
    );
  }

  /// Resolves an album and loads its editorial notes and track list in
  /// parallel. Returns null when the album is not on Apple Music.
  Future<AppleMusicAlbumData?> getAlbumData({
    required String album,
    required String artist,
    String? storefront,
    bool refresh = false,
  }) async {
    final match = await resolveAlbum(
      album: album,
      artist: artist,
      storefront: storefront,
      refresh: refresh,
    );
    if (match == null) return null;

    final (info, tracks) = await (
      getAlbumInfo(
        collectionId: match.collectionId,
        collectionUrl: match.url,
        storefront: storefront,
        refresh: refresh,
      ),
      getAlbumTracks(
        match.collectionId,
        storefront: storefront,
        refresh: refresh,
      ),
    ).wait;

    return AppleMusicAlbumData(match: match, info: info, tracks: tracks);
  }

  /// Editorial notes for an album page. Tries the primary storefront then
  /// `us`, so an empty page in one country does not hide notes in another.
  Future<AppleMusicAlbumInfo?> getAlbumInfo({
    required String collectionId,
    required String collectionUrl,
    String? storefront,
    bool refresh = false,
  }) {
    final id = collectionId.trim();
    final url = collectionUrl.trim();
    if (url.isEmpty) return Future.value(null);
    final sf = _primaryStorefront(storefront);
    return _cache.fetch<AppleMusicAlbumInfo>(
      key: _key('album-info', '${id.isEmpty ? url : id}|$sf'),
      refresh: refresh,
      loader: () async {
        var anyFetched = false;
        for (final candidate in _storefronts(sf)) {
          final page = _withStorefront(url, candidate);
          if (page == null) continue;
          final html = await _getHtml(Uri.parse(page));
          if (html == null) continue;
          anyFetched = true;
          final notes = _parseAlbumNotes(html);
          if (notes != null) {
            return AppleMusicAlbumInfo(
              collectionId: id,
              url: _stripTracking(url) ?? url,
              notes: notes,
            );
          }
        }
        if (!anyFetched) {
          throw const AppleMusicTransientException('album page not fetched');
        }
        return AppleMusicAlbumInfo(
          collectionId: id,
          url: _stripTracking(url) ?? url,
        );
      },
      encode: (info) => info.toJson(),
      decode: AppleMusicAlbumInfo.fromJson,
      ttl: _infoTtl,
      negativeTtl: _negativeTtl,
      transientTtl: _transientTtl,
    );
  }

  /// Full track list for an album, used to match local files by duration.
  Future<List<AppleMusicTrack>> getAlbumTracks(
    String collectionId, {
    String? storefront,
    bool refresh = false,
  }) {
    final id = collectionId.trim();
    if (id.isEmpty) return Future.value(const <AppleMusicTrack>[]);
    final sf = _primaryStorefront(storefront);
    return _cache
        .fetch<List<AppleMusicTrack>>(
          key: _key('album-tracks', '$id|$sf'),
          refresh: refresh,
          loader: () async {
            final results = await _itunesLookup(
              id: id,
              entity: 'song',
              limit: 300,
              storefront: sf,
            );
            final tracks = <AppleMusicTrack>[];
            for (final result in results) {
              if (result['wrapperType'] != 'track') continue;
              final trackName = _clean(result['trackName']);
              if (trackName == null) continue;
              tracks.add(
                AppleMusicTrack(
                  trackName: trackName,
                  trackId: _cleanId(result['trackId']),
                  artistName: _clean(result['artistName']),
                  trackNumber: (result['trackNumber'] as num?)?.toInt(),
                  discNumber: (result['discNumber'] as num?)?.toInt(),
                  durationMs: (result['trackTimeMillis'] as num?)?.toInt(),
                  url: _stripTracking(_clean(result['trackViewUrl'])),
                ),
              );
            }
            return tracks;
          },
          encode: (tracks) => {
            'tracks': [for (final track in tracks) track.toJson()],
          },
          decode: (json) =>
              (json['tracks'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .map(AppleMusicTrack.fromJson)
                  .toList() ??
              const <AppleMusicTrack>[],
          ttl: _infoTtl,
          negativeTtl: _negativeTtl,
          transientTtl: _transientTtl,
        )
        .then((tracks) => tracks ?? const <AppleMusicTrack>[]);
  }

  /// Free-text album search returning every plausible release, used by the
  /// identification flow where a single best match is not enough.
  Future<List<AppleMusicAlbumMatch>> searchAlbums(
    String term, {
    int limit = 25,
    String? storefront,
    bool refresh = false,
  }) {
    final query = term.trim();
    if (query.isEmpty) return Future.value(const <AppleMusicAlbumMatch>[]);
    final sf = _primaryStorefront(storefront);
    return _cache
        .fetch<List<AppleMusicAlbumMatch>>(
          key: _key('album-search', '${_normalize(query)}|$limit|$sf'),
          refresh: refresh,
          loader: () async {
            final results = await _itunesSearch(
              term: query,
              entity: 'album',
              limit: limit,
              storefront: sf,
            );
            final seen = <String>{};
            final matches = <AppleMusicAlbumMatch>[];
            for (final result in results) {
              if (result['wrapperType'] != 'collection') continue;
              final match = _albumFromJson(result, sf);
              if (match.collectionId.isEmpty || !seen.add(match.collectionId)) {
                continue;
              }
              matches.add(match);
            }
            return matches;
          },
          encode: (matches) => {
            'albums': [for (final match in matches) match.toJson()],
          },
          decode: (json) =>
              (json['albums'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .map(AppleMusicAlbumMatch.fromJson)
                  .toList() ??
              const <AppleMusicAlbumMatch>[],
          ttl: _infoTtl,
          negativeTtl: _negativeTtl,
          transientTtl: _transientTtl,
        )
        .then((matches) => matches ?? const <AppleMusicAlbumMatch>[]);
  }

  /// Downloads album artwork at the requested size. Null when unavailable.
  Future<Uint8List?> fetchArtworkBytes(String url, {int size = 1500}) async {
    final target = artworkUrl(url, size);
    if (target == null) return null;
    try {
      final response = await _request(Uri.parse(target));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.bodyBytes;
    } on AppleMusicTransientException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Rewrites an mzstatic image URL to the requested square size.
  static String? artworkUrl(String? url, int size) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceAll(_imageSizeRe, '${size}x${size}bb.');
  }

  static String artistPageUrl(String artistId, String storefront) =>
      '$_musicBase/$storefront/artist/-/$artistId';

  static String albumPageUrl(String collectionId, String storefront) =>
      '$_musicBase/$storefront/album/-/$collectionId';

  Future<List<Map<String, dynamic>>> _itunesSearch({
    required String term,
    required String entity,
    required int limit,
    required String storefront,
  }) async {
    final json = await _getJson(
      Uri.parse(_itunesSearchBase).replace(
        queryParameters: {
          'term': term,
          'media': 'music',
          'entity': entity,
          'limit': '$limit',
          'country': storefront,
        },
      ),
    );
    return (json['results'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _itunesLookup({
    required String id,
    required String storefront,
    String? entity,
    String? sort,
    int? limit,
  }) async {
    final json = await _getJson(
      Uri.parse(_itunesLookupBase).replace(
        queryParameters: {
          'id': id,
          'entity': ?entity,
          'sort': ?sort,
          if (limit != null) 'limit': '$limit',
          'country': storefront,
        },
      ),
    );
    return (json['results'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
  }

  AppleMusicArtist? _bestArtistMatch(
    String query,
    List<Map<String, dynamic>> results,
    String storefront,
  ) {
    final requested = _normalize(query);
    Map<String, dynamic>? fallback;
    for (final result in results) {
      if (result['wrapperType'] != 'artist') continue;
      fallback ??= result;
      final candidate = _clean(result['artistName']);
      if (candidate != null && _normalize(candidate) == requested) {
        return _artistFromJson(result, storefront);
      }
    }
    return fallback == null ? null : _artistFromJson(fallback, storefront);
  }

  AppleMusicArtist _artistFromJson(
    Map<String, dynamic> json,
    String storefront,
  ) {
    final id = _cleanId(json['artistId']);
    return AppleMusicArtist(
      artistId: id,
      name: _clean(json['artistName']) ?? '',
      genre: _clean(json['primaryGenreName']),
      url:
          _stripTracking(_clean(json['artistLinkUrl'])) ??
          artistPageUrl(id, storefront),
    );
  }

  AppleMusicAlbumMatch? _bestAlbumMatch(
    String requested,
    List<Map<String, dynamic>> results,
    String storefront,
  ) {
    final collections = [
      for (final result in results)
        if (result['wrapperType'] == 'collection') result,
    ];
    final requestedNorm = _normalize(requested);
    final requestedBase = _normalize(_baseName(requested));

    for (final result in collections) {
      final name = _clean(result['collectionName']);
      if (name != null && _normalize(name) == requestedNorm) {
        return _albumFromJson(result, storefront);
      }
    }
    for (final result in collections) {
      final name = _clean(result['collectionName']);
      if (name != null && _normalize(_baseName(name)) == requestedBase) {
        return _albumFromJson(result, storefront);
      }
    }
    if (requestedBase.length >= 4) {
      for (final result in collections) {
        final name = _clean(result['collectionName']);
        if (name == null) continue;
        final candidateBase = _normalize(_baseName(name));
        if (candidateBase.length < 4) continue;
        if (candidateBase.contains(requestedBase) ||
            requestedBase.contains(candidateBase)) {
          return _albumFromJson(result, storefront);
        }
      }
    }
    return null;
  }

  AppleMusicAlbumMatch _albumFromJson(
    Map<String, dynamic> json,
    String storefront,
  ) {
    final id = _cleanId(json['collectionId']);
    return AppleMusicAlbumMatch(
      collectionId: id,
      name: _clean(json['collectionName']) ?? '',
      artistName: _clean(json['artistName']) ?? '',
      url:
          _stripTracking(_clean(json['collectionViewUrl'])) ??
          albumPageUrl(id, storefront),
      artworkUrl: artworkUrl(_clean(json['artworkUrl100']), 1500),
      releaseDate: _shortDate(_clean(json['releaseDate'])),
      genre: _clean(json['primaryGenreName']),
      trackCount: (json['trackCount'] as num?)?.toInt(),
    );
  }

  Future<AppleMusicArtistInfo?> _fetchArtistInfo(
    String artistId,
    String storefront,
  ) async {
    final url = artistPageUrl(artistId, storefront);
    final html = await _getHtml(Uri.parse(url));
    if (html == null) return null;

    final jsonLd = _findJsonLd(html);
    var biography = _clean(jsonLd?['description']);
    if (biography != null) {
      biography = _normalizeParagraphs(_decodeEntities(_stripTags(biography)));
      if (biography.isEmpty) biography = null;
    }
    biography ??= _cleanMeta(html, 'og:description');
    if (biography != null && _isPlaceholderBiography(biography)) {
      biography = null;
    }

    var image = _jsonLdImage(jsonLd?['image']);
    image ??= _cleanMeta(html, 'og:image');
    image = artworkUrl(image, 1500);
    if (image != null && image.contains('meta/apple-music.png')) {
      image = null;
    }

    return AppleMusicArtistInfo(
      artistId: artistId,
      name: _clean(jsonLd?['name']) ?? _cleanMeta(html, 'og:title') ?? '',
      storefront: storefront,
      url: url,
      biography: biography,
      imageUrl: image,
      similarArtists: _parseSimilarArtists(html),
    );
  }

  bool _hasArtistContent(AppleMusicArtistInfo info) =>
      info.biography != null ||
      info.imageUrl != null ||
      info.similarArtists.isNotEmpty;

  Map<String, dynamic>? _findJsonLd(String html) {
    for (final match in _jsonLdRe.allMatches(html)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final decoded = _decodeJson(raw);
      final map = _firstJsonLdMap(decoded);
      if (map != null) return map;
    }
    return null;
  }

  Map<String, dynamic>? _firstJsonLdMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('description') ||
          decoded.containsKey('image') ||
          decoded.containsKey('name')) {
        return decoded;
      }
      return null;
    }
    if (decoded is List) {
      Map<String, dynamic>? fallback;
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        fallback ??= item;
        if (item.containsKey('description') || item.containsKey('image')) {
          return item;
        }
      }
      return fallback;
    }
    return null;
  }

  String? _jsonLdImage(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      return _jsonLdImage(value['url']);
    }
    if (value is List) {
      for (final item in value) {
        final found = _jsonLdImage(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  List<AppleMusicSimilarArtist> _parseSimilarArtists(String html) {
    final markerIndex = _findSimilarMarker(html);
    if (markerIndex < 0) return const <AppleMusicSimilarArtist>[];
    var window = html.substring(markerIndex);
    if (window.length > _similarWindowChars) {
      window = window.substring(0, _similarWindowChars);
    }
    final cut = window.indexOf('data-testid="section-container"', 100);
    final scope = cut > 0 ? window.substring(0, cut) : window;

    final names = <String>[];
    final seen = <String>{};
    for (final match in _lockupTitleRe.allMatches(scope)) {
      final name = _decodeEntities(match.group(1) ?? '').trim();
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) names.add(name);
    }
    return [for (final name in names) AppleMusicSimilarArtist(name: name)];
  }

  static const List<String> _similarMarkers = <String>[
    'aria-label="Similar Artists"',
    'aria-label="Ähnliche Künstler"',
    'aria-label="Artistes similaires"',
    'aria-label="Artistas similares"',
    'aria-label="Artistas semelhantes"',
    'aria-label="Artisti simili"',
    'aria-label="似ているアーティスト"',
  ];

  int _findSimilarMarker(String html) {
    var best = -1;
    for (final marker in _similarMarkers) {
      final index = html.indexOf(marker);
      if (index >= 0 && (best < 0 || index < best)) best = index;
    }
    return best;
  }

  String? _parseAlbumNotes(String html) {
    final match = _serializedDataRe.firstMatch(html);
    if (match == null) return null;
    final decoded = _decodeJson(match.group(1) ?? '');
    if (decoded is! Map<String, dynamic>) return null;
    final data = decoded['data'];
    if (data is! List) return null;
    for (final page in data) {
      if (page is! Map<String, dynamic>) continue;
      final pageData = page['data'];
      if (pageData is! Map<String, dynamic>) continue;
      final sections = pageData['sections'];
      if (sections is! List) continue;
      for (final section in sections) {
        if (section is! Map<String, dynamic>) continue;
        final items = section['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final descriptor = item['modalPresentationDescriptor'];
          if (descriptor is! Map<String, dynamic>) continue;
          final text = _clean(descriptor['paragraphText']);
          if (text == null) continue;
          final normalized = _normalizeParagraphs(
            _decodeEntities(_stripTags(text)),
          );
          if (normalized.isNotEmpty) return normalized;
        }
      }
    }
    return null;
  }

  dynamic _decodeJson(String raw) {
    for (final candidate in [raw, _decodeEntities(raw)]) {
      try {
        return jsonDecode(candidate);
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _getHtml(Uri uri) async {
    final response = await _request(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw AppleMusicTransientException('http ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _request(uri);
    if (response.statusCode != 200) {
      throw AppleMusicTransientException('http ${response.statusCode}');
    }
    final decoded = _decodeJson(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const AppleMusicTransientException('unexpected response body');
    }
    return decoded;
  }

  Future<http.Response> _request(Uri uri) async {
    _throwIfThrottled();
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AppleMusicTransientException('request timed out');
    } on AppleMusicTransientException {
      rethrow;
    } catch (error) {
      throw AppleMusicTransientException('network error: $error');
    }
    _noteThrottle(response);
    if (response.statusCode == 429) {
      throw const AppleMusicTransientException('rate limited');
    }
    if (response.statusCode == 403) {
      throw const AppleMusicTransientException('forbidden');
    }
    return response;
  }

  void _noteThrottle(http.Response response) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (response.statusCode == 429) {
      final retryAfter = int.tryParse(
        response.headers['retry-after']?.trim() ?? '',
      );
      _throttleUntilMs = now + Duration(seconds: retryAfter ?? 30).inMilliseconds;
    } else if (response.statusCode == 403) {
      _throttleUntilMs = now + const Duration(hours: 1).inMilliseconds;
    }
  }

  void _throwIfThrottled() {
    if (DateTime.now().millisecondsSinceEpoch < _throttleUntilMs) {
      throw const AppleMusicTransientException('temporarily throttled');
    }
  }

  String _primaryStorefront(String? override) {
    final value = override?.trim().toLowerCase() ?? '';
    if (_storefrontRe.hasMatch(value)) return value;
    final code = PlatformDispatcher.instance.locale.countryCode?.toLowerCase();
    return code != null && _storefrontRe.hasMatch(code) ? code : 'us';
  }

  List<String> _storefronts(String primary) => [
    primary,
    if (primary != 'us') 'us',
  ];

  String? _withStorefront(String url, String storefront) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'music.apple.com') return null;
    final segments = [...uri.pathSegments];
    if (segments.isEmpty) return null;
    segments[0] = storefront;
    return Uri(
      scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
      host: uri.host,
      pathSegments: segments,
    ).toString();
  }

  String _key(String kind, String value) => '$_cacheVersion|$kind|$value';

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(_whitespaceRe, ' ').trim();

  String _baseName(String value) {
    var end = value.length;
    for (final marker in const [' (', ' [', ' - ', ': ']) {
      final index = value.indexOf(marker);
      if (index > 0 && index < end) end = index;
    }
    return value.substring(0, end).trim();
  }

  String? _shortDate(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(value);
    return match?.group(0) ?? value;
  }

  String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _cleanId(Object? value) {
    if (value == null) return '';
    return '$value'.trim();
  }

  String? _cleanMeta(String html, String property) {
    final tagRe = RegExp(
      '<meta[^>]*(?:property|name)="${RegExp.escape(property)}"[^>]*>',
      caseSensitive: false,
    );
    final tag = tagRe.firstMatch(html)?.group(0);
    if (tag == null) return null;
    final content = RegExp(
      r'content="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1);
    return _clean(content == null ? null : _decodeEntities(content));
  }

  String? _stripTracking(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split('#').first.split('?').first;
  }

  String _stripTags(String value) => value.replaceAll(_htmlTagRe, ' ');

  bool _isPlaceholderBiography(String biography) {
    final firstSentence = biography
        .split(_sentenceEndRe)
        .first
        .trim()
        .toLowerCase();
    return firstSentence.contains('apple music');
  }

  String _normalizeParagraphs(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim());
    final out = <String>[];
    for (final line in lines) {
      if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
      out.add(line);
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }

  static final RegExp _hexEntityRe = RegExp(r'&#x([0-9a-fA-F]+);');
  static final RegExp _decEntityRe = RegExp(r'&#(\d+);');

  String _decodeEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(
          _hexEntityRe,
          (match) => String.fromCharCode(
            int.parse(match.group(1)!, radix: 16),
          ),
        )
        .replaceAllMapped(
          _decEntityRe,
          (match) => String.fromCharCode(int.parse(match.group(1)!)),
        );
  }
}
