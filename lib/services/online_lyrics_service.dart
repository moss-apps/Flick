import 'dart:convert';

import 'package:http/http.dart' as http;

class OnlineLyricsResult {
  final int id;
  final String? trackName;
  final String? artistName;
  final String? albumName;
  final double? duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  const OnlineLyricsResult({
    required this.id,
    this.trackName,
    this.artistName,
    this.albumName,
    this.duration,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  factory OnlineLyricsResult.fromJson(Map<String, dynamic> json) {
    return OnlineLyricsResult(
      id: json['id'] as int,
      trackName: json['trackName'] as String?,
      artistName: json['artistName'] as String?,
      albumName: json['albumName'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
    );
  }

  bool get hasSyncedLyrics =>
      syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;
  bool get hasPlainLyrics =>
      plainLyrics != null && plainLyrics!.trim().isNotEmpty;

  String get bestLyrics => syncedLyrics ?? plainLyrics ?? '';

  int get lineCount {
    final text = bestLyrics;
    if (text.isEmpty) return 0;
    return text.split('\n').where((l) => l.trim().isNotEmpty).length;
  }

  String? get snippet {
    final text = bestLyrics;
    if (text.isEmpty) return null;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return null;
    // Strip LRC tags for snippet
    final clean = lines
        .map((l) => l.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (clean.isEmpty) return null;
    if (clean.length <= 2) return clean.join('\n');
    return clean.take(3).join('\n');
  }

  bool get isSyncedOnly => hasSyncedLyrics && !hasPlainLyrics;
  bool get isPlainOnly => hasPlainLyrics && !hasSyncedLyrics;

  String get formatLabel {
    if (instrumental) return 'Instrumental';
    if (hasSyncedLyrics) return 'Synced LRC';
    if (hasPlainLyrics) return 'Plain Text';
    return 'Unknown';
  }

  String get shortFormatLabel {
    if (instrumental) return 'Inst';
    if (hasSyncedLyrics) return 'LRC';
    if (hasPlainLyrics) return 'TXT';
    return '?';
  }
}

class OnlineLyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxCacheEntries = 50;

  // Static so state survives per-sheet instance recreation — same singleton
  // idiom as album_art_import_service.
  static final http.Client _client = http.Client();
  static final Map<String, OnlineLyricsResult?> _exactCache = {};
  static final Map<String, List<OnlineLyricsResult>> _searchCache = {};

  static String _norm(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _exactCacheKey({
    required String artist,
    required String title,
    String? album,
    Duration? duration,
  }) {
    return 'exact|${_norm(artist)}|${_norm(title)}|${_norm(album)}|'
        '${duration?.inSeconds ?? 0}';
  }

  String _searchCacheKey({
    String? query,
    String? artist,
    String? title,
    String? album,
  }) {
    final parts = <String>['search'];
    if (query != null && query.isNotEmpty) parts.add('q=${_norm(query)}');
    if (artist != null && artist.isNotEmpty) parts.add('a=${_norm(artist)}');
    if (title != null && title.isNotEmpty) parts.add('t=${_norm(title)}');
    if (album != null && album.isNotEmpty) parts.add('al=${_norm(album)}');
    return parts.join('|');
  }

  void _put<T>(Map<String, T> cache, String key, T value) {
    cache[key] = value;
    // ponytail: FIFO eviction, not true LRU — fine at this volume.
    while (cache.length > _maxCacheEntries) {
      cache.remove(cache.keys.first);
    }
  }

  Future<OnlineLyricsResult?> fetchExact({
    required String artist,
    required String title,
    String? album,
    Duration? duration,
  }) async {
    final cacheKey = _exactCacheKey(
      artist: artist,
      title: title,
      album: album,
      duration: duration,
    );
    if (_exactCache.containsKey(cacheKey)) return _exactCache[cacheKey];

    final queryParams = <String, String>{
      'track_name': title,
      'artist_name': artist,
    };
    if (album != null && album.isNotEmpty) {
      queryParams['album_name'] = album;
    }
    if (duration != null && duration.inSeconds > 0) {
      queryParams['duration'] = duration.inSeconds.toString();
    }

    final uri =
        Uri.parse('$_baseUrl/get').replace(queryParameters: queryParams);
    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = OnlineLyricsResult.fromJson(json);
        _put(_exactCache, cacheKey, result);
        return result;
      }
      // Definitive miss (e.g. 404) — cache it. 5xx is transient, skip caching.
      if (response.statusCode < 500) {
        _put(_exactCache, cacheKey, null);
      }
    } catch (_) {
      // Network/timeout error — do not cache.
    }
    return null;
  }

  Future<List<OnlineLyricsResult>> search({
    String? query,
    String? artist,
    String? title,
    String? album,
  }) async {
    final cacheKey = _searchCacheKey(
      query: query,
      artist: artist,
      title: title,
      album: album,
    );
    if (_searchCache.containsKey(cacheKey)) return _searchCache[cacheKey]!;

    final queryParams = <String, String>{};
    if (query != null && query.isNotEmpty) {
      queryParams['q'] = query;
    }
    if (artist != null && artist.isNotEmpty) {
      queryParams['artist_name'] = artist;
    }
    if (title != null && title.isNotEmpty) {
      queryParams['track_name'] = title;
    }
    if (album != null && album.isNotEmpty) {
      queryParams['album_name'] = album;
    }

    final uri =
        Uri.parse('$_baseUrl/search').replace(queryParameters: queryParams);
    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final results = list
            .map(
              (e) =>
                  OnlineLyricsResult.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        _put(_searchCache, cacheKey, results);
        return results;
      }
      if (response.statusCode < 500) {
        _put(_searchCache, cacheKey, const []);
      }
    } catch (_) {
      // Network/timeout error — do not cache.
    }
    return [];
  }
}
