import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/app_log.dart';
import '../../data/entities/network_server_entity.dart';
import '../../data/entities/song_entity.dart';
import '../../data/repositories/song_repository.dart';
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import 'network_source_service.dart';

/// Jellyfin / Emby REST client (JSON).
///
/// Auth: `POST /Users/AuthenticateByName` exchanges a plaintext password for
/// an access token. The stored [NetworkServerEntity.token] is a JSON blob
/// `{"userId":..., "token":...}` because every library call is scoped to the
/// authenticated user id. The plaintext password is never persisted.
class JellyfinService implements NetworkSourceService {
  JellyfinService._({http.Client? client, SongRepository? songRepository, NetworkCacheService? networkCache})
      : _client = client ?? http.Client(),
        _songRepository = songRepository,
        _networkCache = networkCache;

  static JellyfinService instance = JellyfinService._();

  @visibleForTesting
  static JellyfinService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
  }) =>
      JellyfinService._(
        client: client,
        songRepository: songRepository,
        networkCache: networkCache,
      );

  static const String _clientName = 'flick';
  static const String _device = 'flick';
  // ponytail: fixed DeviceId. Jellyfin lists one device row per distinct id;
  // a per-install persisted UUID only matters if the server device list gets
  // noisy. Upgrade then.
  static const String _deviceId = 'flick-player-0001';
  static const String _clientVersion = '0.20.5';
  static const String _coverMarkerScheme = 'jellyfin-cover://';

  final http.Client _client;
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  @override
  String get protocol => NetworkProtocol.jellyfin;

  @override
  String get coverScheme => _coverMarkerScheme;

  String _base(NetworkServerEntity server) =>
      server.baseUrl.replaceAll(RegExp(r'/+$'), '');

  String _authHeader(String? accessToken) {
    final base =
        'MediaBrowser Client="$_clientName", Device="$_device", DeviceId="$_deviceId", Version="$_clientVersion"';
    if (accessToken != null && accessToken.isNotEmpty) {
      return '$base, Token="$accessToken"';
    }
    return base;
  }

  _JellyfinCredentials? _creds(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final j = jsonDecode(token) as Map<String, dynamic>;
      final uid = j['userId'] as String?;
      final tok = j['token'] as String?;
      if (uid == null || tok == null) return null;
      return _JellyfinCredentials(uid, tok);
    } catch (_) {
      return null;
    }
  }

  // --- Auth + ping --------------------------------------------------------

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    final uri = Uri.parse('${_base(server)}/Users/AuthenticateByName');
    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': _authHeader(null),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'Username': server.username ?? '',
            'Pw': password,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw JellyfinNetworkException(
          'Authentication failed (HTTP ${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = (body['User'] as Map<String, dynamic>?) ?? const {};
    final userId = user['Id'] as String? ?? body['UserId'] as String?;
    final accessToken = (body['AccessToken'] as String?) ??
        ((body['SessionInfo'] as Map<String, dynamic>?)?['AccessToken']
            as String?);
    if (userId == null || accessToken == null) {
      throw JellyfinNetworkException('Authentication response missing token');
    }
    return jsonEncode({'userId': userId, 'token': accessToken});
  }

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    final creds = _creds(server.token);
    if (creds == null) {
      AppLog.instance.add('Jellyfin ping failed: no stored token');
      return false;
    }
    try {
      await _getJson(server, '/system/Info', accessToken: creds.token);
      return true;
    } catch (e) {
      AppLog.instance.add('Jellyfin ping failed: $e');
      return false;
    }
  }

  // --- Library ------------------------------------------------------------

  Future<Map<String, dynamic>> _getJson(
    NetworkServerEntity server,
    String path, {
    Map<String, String>? query,
    String? accessToken,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    var uri = Uri.parse('${_base(server)}$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final response = await _client
        .get(uri, headers: {
          'Authorization': _authHeader(accessToken),
          'Accept': 'application/json',
        })
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw JellyfinNetworkException('HTTP ${response.statusCode} for $path');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _albums(
    NetworkServerEntity server,
    _JellyfinCredentials creds,
  ) async {
    final payload = await _getJson(
      server,
      '/Users/${creds.userId}/Items',
      query: {
        'Recursive': 'true',
        'IncludeItemTypes': 'MusicAlbum',
        'Fields': 'DateCreated',
      },
      accessToken: creds.token,
    );
    return ((payload['Items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _songsInAlbum(
    NetworkServerEntity server,
    _JellyfinCredentials creds,
    String albumId,
  ) async {
    final payload = await _getJson(
      server,
      '/Users/${creds.userId}/Items',
      query: {
        'Recursive': 'true',
        'ParentId': albumId,
        'IncludeItemTypes': 'Audio',
        'Fields': 'MediaSources,Genres',
      },
      accessToken: creds.token,
    );
    return ((payload['Items'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  // --- Cover art + stream -------------------------------------------------

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    final creds = _creds(server.token);
    var uri = Uri.parse('${_base(server)}/Items/$marker/Images/Primary');
    uri = uri.replace(queryParameters: {
      if (creds != null) 'api_key': creds.token,
    });
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw JellyfinNetworkException(
          'HTTP ${response.statusCode} for cover $marker');
    }
    return response.bodyBytes;
  }

  @override
  Future<String> stream(
    NetworkServerEntity server,
    String songId, {
    String? extension,
    void Function(double progress)? onProgress,
  }) async {
    final cached =
        await _cache.getPath(server.id, songId, extension: extension);
    if (cached != null) return cached;

    final creds = _creds(server.token);
    if (creds == null) {
      throw StateError('Jellyfin server "${server.label}" has no stored token');
    }
    final uri = Uri.parse('${_base(server)}/Audio/$songId/stream')
        .replace(queryParameters: {
      'static': 'true',
      'api_key': creds.token,
    });
    final request = http.Request('GET', uri);
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw JellyfinNetworkException(
          'HTTP ${response.statusCode} for stream $songId');
    }
    final total = response.contentLength;
    final builder = BytesBuilder();
    var received = 0;
    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      if (onProgress != null && total != null && total > 0) {
        onProgress(received / total);
      }
    }
    return _cache.stash(server.id, songId, builder.takeBytes(),
        extension: extension);
  }

  @override
  Future<({String url, Map<String, String> headers})?> streamDescriptor(
    NetworkServerEntity server,
    String songId, {
    String? extension,
  }) async {
    final creds = _creds(server.token);
    if (creds == null) return null;
    final uri = Uri.parse('${_base(server)}/Audio/$songId/stream')
        .replace(queryParameters: {
      'static': 'true',
      'api_key': creds.token,
    });
    return (url: uri.toString(), headers: const <String, String>{});
  }

  // --- Sync ---------------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final creds = _creds(server.token);
    if (creds == null) {
      throw StateError('Jellyfin server "${server.label}" has no stored token');
    }

    final albums = await _albums(server, creds);
    final syncedRemoteIds = <String>{};
    var songsFound = 0;
    var filesProcessed = 0;

    for (final album in albums) {
      final albumName = (album['Name'] as String?) ?? '';
      final albumArtist = _firstAlbumArtist(album);
      final albumId = album['Id'] as String;
      final year = _toInt(album['ProductionYear']);

      try {
        final rawSongs = await _songsInAlbum(server, creds, albumId);
        final entities = rawSongs
            .map((s) => _songEntity(
                  server,
                  s,
                  albumName: albumName,
                  albumArtist: albumArtist,
                  albumId: albumId,
                  year: year,
                ))
            .toList();
        await _repo.upsertSongs(entities);
        syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));
        songsFound += entities.length;
      } catch (e) {
        AppLog.instance.add(
          'Jellyfin sync skipped album "$albumName" on ${server.label}: $e',
        );
      }

      filesProcessed++;
      yield ScanProgress(
        songsFound: songsFound,
        totalFiles: albums.length,
        filesProcessed: filesProcessed,
        phase: 'Syncing ${server.label}',
        currentFile: albumName,
      );
    }

    await purgeAndStampNetworkSync(server, syncedRemoteIds);

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: albums.length,
      filesProcessed: filesProcessed,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  String _firstAlbumArtist(Map<String, dynamic> album) {
    final artists = album['AlbumArtists'] as List<dynamic>?;
    if (artists != null && artists.isNotEmpty) {
      final first = artists.first as Map<String, dynamic>;
      return (first['Name'] as String?) ?? '';
    }
    return (album['AlbumArtist'] as String?) ?? '';
  }

  SongEntity _songEntity(
    NetworkServerEntity server,
    Map<String, dynamic> s, {
    required String albumName,
    required String albumArtist,
    required String albumId,
    int? year,
  }) {
    final remoteId = s['Id'] as String;
    final runTimeTicks = _toInt(s['RunTimeTicks']);
    final mediaSources = s['MediaSources'] as List<dynamic>?;
    final mediaSource = mediaSources != null && mediaSources.isNotEmpty
        ? mediaSources.first as Map<String, dynamic>
        : null;
    final artists = (s['Artists'] as List<dynamic>?)?.cast<String?>();
    final genres = (s['Genres'] as List<dynamic>?)?.cast<String?>();
    final bitrateBps = _toInt(mediaSource?['Bitrate']);
    return SongEntity()
      ..filePath = '${NetworkProtocol.jellyfin}://${server.id}/$remoteId'
      ..title = (s['Name'] as String?) ?? 'Unknown'
      ..artist = (artists != null && artists.isNotEmpty)
          ? (artists.first ?? 'Unknown')
          : (s['AlbumArtist'] as String?) ?? 'Unknown'
      ..album = albumName.isNotEmpty ? albumName : (s['Album'] as String?)
      ..albumArtist = albumArtist.isNotEmpty ? albumArtist : null
      ..durationMs = runTimeTicks != null ? runTimeTicks ~/ 10000 : null
      ..trackNumber = _toInt(s['IndexNumber'])
      ..discNumber = _toInt(s['ParentIndexNumber'])
      ..year = year ?? _toInt(s['ProductionYear'])
      ..genre = genres != null && genres.isNotEmpty ? genres.join(', ') : null
      ..fileSize = _toInt(s['Size'])
      ..fileType = (mediaSource?['Container'] as String?) ??
          (s['Container'] as String?)
      ..bitrate = bitrateBps == null ? null : bitrateBps ~/ 1000
      ..sampleRate = _toInt(mediaSource?['SampleRate'])
      ..albumArtPath = '$_coverMarkerScheme$albumId'
      ..sourceType = NetworkProtocol.jellyfin
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }
}

int? _toInt(dynamic v) => v == null ? null : (v as num).toInt();

class _JellyfinCredentials {
  const _JellyfinCredentials(this.userId, this.token);
  final String userId;
  final String token;
}

class JellyfinNetworkException implements Exception {
  final String message;
  JellyfinNetworkException(this.message);
  @override
  String toString() => 'Jellyfin error: $message';
}
