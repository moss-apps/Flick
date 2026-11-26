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
import 'network_credential_store.dart';
import 'network_endpoint_policy.dart';
import 'network_source_service.dart';
import 'package:flick/l10n/l10n.dart';

/// Jellyfin / Emby REST client (JSON).
///
/// Auth: `POST /Users/AuthenticateByName` exchanges a plaintext password for
/// an access token. The access-token JSON blob `{"userId":..., "token":...}`
/// lives in Keystore-backed secure storage; [NetworkServerEntity] only holds
/// its opaque `credentialRef`. A password entered in Flick is part of the
/// same endpoint-bound bundle so a dead token can be renewed on the next 401.
class JellyfinService implements NetworkSourceService {
  JellyfinService._({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    NetworkCredentialStore? credentialStore,
  })  : _client = NetworkEndpointPolicy.secureClient(client),
        _songRepository = songRepository,
        _networkCache = networkCache,
        _credentials = credentialStore ?? NetworkCredentialStore.instance;

  static JellyfinService instance = JellyfinService._();

  @visibleForTesting
  static JellyfinService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    NetworkCredentialStore? credentialStore,
  }) =>
      JellyfinService._(
        client: client,
        songRepository: songRepository,
        networkCache: networkCache,
        credentialStore: credentialStore,
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
  final NetworkCredentialStore _credentials;
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  @override
  String get protocol => NetworkProtocol.jellyfin;

  @override
  String get coverScheme => _coverMarkerScheme;

  @override
  String? get lastPingError => null;

  String _base(NetworkServerEntity server) => NetworkEndpointPolicy
      .requireAllowed(server)
      .toString()
      .replaceAll(RegExp(r'/+$'), '');

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

  Future<_JellyfinCredentials?> _credsFor(NetworkServerEntity server) async {
    final credential = await _credentials.read(server);
    return _creds(credential?.secret);
  }

  /// Retry a rejected token with the newest session, signing in only if the
  /// rejected token is still current and we have a password for this endpoint.
  Future<String?> _reauth(NetworkServerEntity server, String? rejected) async {
    try {
      final fresh = await _credentials.refresh(server, (current) async {
        final token = _creds(current.secret)?.token;
        if (token != null && token != rejected) return current.secret;
        final password = current.password;
        if (password == null || password.isEmpty) return null;
        return resolveToken(server, password);
      });
      return _creds(fresh?.secret)?.token;
    } catch (e) {
      AppLog.instance.add('Jellyfin re-auth failed (${e.runtimeType})');
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
        // ponytail: 60s ceiling for LDAP/SSO backends (Authentik et al);
        // wrong-credential 401s still return as fast as the server sends them.
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw JellyfinNetworkException(
          'Authentication failed (HTTP ${response.statusCode})');
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final user = (body['User'] as Map<String, dynamic>?) ?? const {};
      final userId = user['Id'] as String? ?? body['UserId'] as String?;
      final accessToken = (body['AccessToken'] as String?) ??
          ((body['SessionInfo'] as Map<String, dynamic>?)?['AccessToken']
              as String?);
      if (userId != null && accessToken != null) {
        return jsonEncode({'userId': userId, 'token': accessToken});
      }
    } catch (_) {
      // Malformed authentication responses can contain part of a token.
    }
    throw JellyfinNetworkException(l10n.authenticationResponseMissingToken);
  }

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    _JellyfinCredentials? creds;
    try {
      creds = await _credsFor(server);
    } on NetworkCredentialException catch (e) {
      AppLog.instance.add('Jellyfin ping failed: ${e.message}');
      return false;
    }
    if (creds == null) {
      AppLog.instance.add('Jellyfin ping failed: no stored token');
      return false;
    }
    try {
      await _getJson(server, '/system/Info', accessToken: creds.token);
      return true;
    } catch (e) {
      AppLog.instance.add('Jellyfin ping failed (${e.runtimeType})');
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
    var token = accessToken;
    for (var attempt = 0; ; attempt++) {
      var uri = Uri.parse('${_base(server)}$path');
      if (query != null) uri = uri.replace(queryParameters: query);
      final response = await _client
          .get(uri, headers: {
            'Authorization': _authHeader(token),
            'Accept': 'application/json',
          })
          .timeout(timeout);
      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
        } on FormatException {
          // The response can contain credentials, even if decoding failed.
        }
        throw JellyfinNetworkException(l10n.couldNotReachTheServer);
      }
      if (response.statusCode == 401 && attempt == 0) {
        final fresh = await _reauth(server, token);
        if (fresh != null) {
          token = fresh;
          continue;
        }
      }
      throw JellyfinNetworkException('HTTP ${response.statusCode} for $path');
    }
  }

  Future<List<Map<String, dynamic>>> _allAudio(
    NetworkServerEntity server,
    _JellyfinCredentials creds,
  ) async {
    final payload = await _getJson(
      server,
      '/Users/${creds.userId}/Items',
      query: {
        'Recursive': 'true',
        'IncludeItemTypes': 'Audio',
        'Fields': 'MediaSources,Genres,ProductionYear',
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
    final creds = await _credsFor(server);
    var token = creds?.token;
    for (var attempt = 0; ; attempt++) {
      final uri = Uri.parse('${_base(server)}/Items/$marker/Images/Primary');
      final response = await _client
          .get(uri, headers: {'Authorization': _authHeader(token)})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return response.bodyBytes;
      if (response.statusCode == 401 && attempt == 0) {
        final fresh = await _reauth(server, token);
        if (fresh != null) {
          token = fresh;
          continue;
        }
      }
      throw JellyfinNetworkException(
          'HTTP ${response.statusCode} for cover $marker');
    }
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

    final creds = await _credsFor(server);
    if (creds == null) {
      throw NetworkCredentialException(l10n.credentialMissing(server.label));
    }
    var token = creds.token;
    http.StreamedResponse response;
    for (var attempt = 0; ; attempt++) {
      final uri = Uri.parse('${_base(server)}/Audio/$songId/stream')
          .replace(queryParameters: const {'static': 'true'});
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = _authHeader(token);
      response = await _client.send(request).timeout(const Duration(minutes: 5));
      if (response.statusCode != 401 || attempt > 0) break;
      final fresh = await _reauth(server, token);
      if (fresh == null) break;
      await response.stream.listen(null).cancel();
      token = fresh;
    }
    if (response.statusCode != 200) {
      await response.stream.listen(null).cancel();
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
    final creds = await _credsFor(server);
    if (creds == null) return null;
    final uri = Uri.parse('${_base(server)}/Audio/$songId/stream')
        .replace(queryParameters: const {'static': 'true'});
    return (
      url: uri.toString(),
      headers: {'Authorization': _authHeader(creds.token)},
    );
  }

  // --- Sync ---------------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final creds = await _credsFor(server);
    if (creds == null) {
      throw NetworkCredentialException(l10n.credentialMissing(server.label));
    }

    // Query every Audio item directly. Iterating MusicAlbum containers misses
    // loose tracks (root-level files, singles) that Jellyfin indexes but never
    // groups into an album entity — their AlbumId is null despite having tags.
    final tracks = await _allAudio(server, creds);
    final entities = <SongEntity>[];
    for (final s in tracks) {
      try {
        entities.add(_songEntityFromTrack(server, s));
      } catch (e) {
        AppLog.instance.add(
          'Jellyfin sync skipped a track (${e.runtimeType})',
        );
      }
    }

    await _repo.upsertSongs(entities);
    await purgeAndStampNetworkSync(
      server,
      entities.map((e) => e.remoteId!).toSet(),
    );

    yield ScanProgress(
      songsFound: entities.length,
      totalFiles: tracks.length,
      filesProcessed: tracks.length,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  SongEntity _songEntityFromTrack(
    NetworkServerEntity server,
    Map<String, dynamic> s,
  ) {
    final remoteId = s['Id'] as String;
    final runTimeTicks = _toInt(s['RunTimeTicks']);
    final mediaSources = s['MediaSources'] as List<dynamic>?;
    final mediaSource = mediaSources != null && mediaSources.isNotEmpty
        ? mediaSources.first as Map<String, dynamic>
        : null;
    final artists = (s['Artists'] as List<dynamic>?)?.cast<String?>();
    final genres = (s['Genres'] as List<dynamic>?)?.cast<String?>();
    final bitrateBps = _toInt(mediaSource?['Bitrate']);
    final albumName = (s['Album'] as String?) ?? '';
    final albumId = (s['AlbumId'] as String?) ?? '';
    final albumArtist = (s['AlbumArtist'] as String?) ??
        (artists != null && artists.isNotEmpty ? (artists.first ?? '') : '');
    return SongEntity()
      ..filePath = '${NetworkProtocol.jellyfin}://${server.id}/$remoteId'
      ..title = (s['Name'] as String?) ?? 'Unknown'
      ..artist = (artists != null && artists.isNotEmpty)
          ? (artists.first ?? 'Unknown')
          : (s['AlbumArtist'] as String?) ?? 'Unknown'
      ..album = albumName.isNotEmpty ? albumName : null
      ..albumArtist = albumArtist.isNotEmpty ? albumArtist : null
      ..durationMs = runTimeTicks != null ? runTimeTicks ~/ 10000 : null
      ..trackNumber = _toInt(s['IndexNumber'])
      ..discNumber = _toInt(s['ParentIndexNumber'])
      ..year = _toInt(s['ProductionYear'])
      ..genre = genres != null && genres.isNotEmpty ? genres.join(', ') : null
      ..fileSize = _toInt(s['Size'])
      ..fileType =
          (mediaSource?['Container'] as String?) ?? (s['Container'] as String?)
      ..bitrate = bitrateBps == null ? null : bitrateBps ~/ 1000
      ..sampleRate = _toInt(mediaSource?['SampleRate'])
      ..albumArtPath =
          '$_coverMarkerScheme${albumId.isNotEmpty ? albumId : remoteId}'
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
