import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/dev_log.dart';
import '../../data/database.dart';
import '../../data/repositories/song_repository.dart';
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import 'network_source_service.dart';

/// Tidal client over the reverse-engineered web/OAuth2 surface.
///
/// Auth is Tidal's OAuth2 **device-authorization grant**: the app impersonates a
/// Tidal web/desktop client using its public `clientId` and the user authorizes
/// on their own device with their own Tidal account. Tokens (access + refresh)
/// are persisted as a JSON blob in [NetworkServerEntity.token] and refreshed
/// transparently on expiry, writing the new token back to the DB.
///
/// Playback: `/tracks/{id}/playbackinfopostpaywall` returns a `vnd.tidal.bts`
/// manifest. For `encryptionType: NONE` (HiFi lossless FLAC/ALAC) the contained
/// CDN url is fed straight to the engine as a ranged HTTP source (or cached).
/// Encrypted manifests (MQA / HiRes Master / Atmos, `encryptionType != NONE` or
/// DASH) are **not** decryptable here and fail with a clear error rather than
/// fake playback — matching the project's "no fake transport" rule. This is the
/// tradeoff of the no-partner-SDK path the user explicitly accepted.
///
/// Tidal rotates the web client credentials; update [clientId]/[clientSecret]
/// if auth starts returning `invalid_client`.
class TidalService implements NetworkSourceService {
  TidalService._({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    Future<bool> Function(Uri)? urlOpener,
  })  : _client = client ?? http.Client(),
        _songRepository = songRepository,
        _networkCache = networkCache,
        _urlOpener = urlOpener ?? _defaultOpenUrl;

  static TidalService instance = TidalService._();

  @visibleForTesting
  static TidalService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    Future<bool> Function(Uri)? urlOpener,
  }) =>
      TidalService._(
        client: client,
        songRepository: songRepository,
        networkCache: networkCache,
        urlOpener: urlOpener,
      );

  // ponytail: Tidal desktop/TV app OAuth2 client credentials, scraped from the
  // app and published by the RE community (EbbLabs/python-tidal). NOT an official
  // API key; Tidal rotates these at will. If auth starts returning
  // `invalid_client`, pull a fresh client_id/client_secret pair from the same
  // source.
  static const String clientId = 'fX2JxdmntZWK0ixT';
  static const String clientSecret = '1Nn9AfDAjxrgJFJbKNWLeAyKGVGmINuXPPLHVXAvxAg=';
  static const String _scope = 'r_usr w_usr w_sub';

  static const String _authBase = 'https://auth.tidal.com/v1/oauth2';
  static const String _apiBase = 'https://api.tidal.com/v1';
  static const String _coverMarkerScheme = 'tidal-cover://';
  static const String _coverHost = 'https://resources.tidal.com/images';

  /// Tidal base url is fixed; baseUrl on the entity is cosmetic only.
  static const String tidalBaseUrl = 'https://tidal.com';

  final http.Client _client;
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;
  final Future<bool> Function(Uri) _urlOpener;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  static Future<bool> _defaultOpenUrl(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  String get protocol => NetworkProtocol.tidal;

  @override
  String get coverScheme => _coverMarkerScheme;

  _TidalCreds? _creds(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final j = jsonDecode(token) as Map<String, dynamic>;
      final access = j['access_token'] as String?;
      if (access == null) return null;
      return _TidalCreds(
        accessToken: access,
        refreshToken: j['refresh_token'] as String?,
        userId: j['user_id'] as String?,
        countryCode: (j['country_code'] as String?) ?? 'US',
        expiresAtMs: (j['expires_at_ms'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  // --- OAuth2 device-code login ------------------------------------------

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) =>
      signIn();

  /// OAuth2 device-code sign-in. The browser is auto-launched best-effort; if
  /// that fails (no browser app / ACTIVITY_NOT_FOUND), [onVerificationLink]
  /// receives the URI so the caller can offer manual copy/open. Polling
  /// continues regardless, so authorization completed on any device finishes
  /// the sign-in. Without a callback, a launch failure fast-fails with the link
  /// carried on the [TidalException].
  Future<String?> signIn({
    void Function(String verificationLink)? onVerificationLink,
  }) async {
    final dev = await _postForm('$_authBase/device_authorization', {
      'client_id': clientId,
      'scope': _scope,
    });
    final deviceCode = dev['deviceCode'] as String?;
    final rawUri = (dev['verificationUriComplete'] as String?) ??
        (dev['verificationUri'] as String?);
    // Tidal returns the verification URL scheme-less (link.tidal.com/CODE);
    // url_launcher needs https:// or the VIEW intent matches nothing and
    // throws ACTIVITY_NOT_FOUND.
    final verificationUri =
        rawUri == null || rawUri.startsWith('http') ? rawUri : 'https://$rawUri';
    final intervalSec = (dev['interval'] as num?)?.toInt() ?? 5;
    final expiresInSec = (dev['expiresIn'] as num?)?.toInt() ?? 300;
    if (deviceCode == null || verificationUri == null) {
      throw TidalException('Tidal did not return a sign-in code.');
    }
    // Opening the browser can throw (e.g. Android ACTIVITY_NOT_FOUND when no
    // app handles the link). Treat a throw the same as a false return — with a
    // callback the device-code flow still works if the user opens the link on
    // any device; without one we fast-fail carrying the link.
    var launched = false;
    try {
      launched = await _urlOpener(Uri.parse(verificationUri));
    } catch (e) {
      devLog('[Tidal] browser launch failed: $e');
    }
    if (!launched) {
      if (onVerificationLink != null) {
        onVerificationLink(verificationUri);
      } else {
        throw TidalException(
          "Couldn't open the browser automatically. Open this link on any "
          'device to finish signing in, then tap Sign in again:\n\n'
          '$verificationUri',
          verificationUri: verificationUri,
        );
      }
    }

    final deadline = DateTime.now().add(Duration(seconds: expiresInSec));
    var sleep = intervalSec;
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: sleep));
      final tok = await _postForm('$_authBase/token', {
        'client_id': clientId,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'device_code': deviceCode,
        'scope': _scope,
      }, raw: true);

      final access = tok['access_token'] as String?;
      if (access != null) {
        final session = await _fetchSession(access);
        final expiresAt = DateTime.now().add(
          Duration(seconds: (tok['expires_in'] as num?)?.toInt() ?? 3600),
        );
        return jsonEncode({
          'access_token': access,
          'refresh_token': tok['refresh_token'],
          'user_id': session.userId,
          'country_code': session.countryCode,
          'expires_at_ms': expiresAt.millisecondsSinceEpoch,
        });
      }
      switch (tok['error']) {
        case 'expired_token':
          throw TidalException('The Tidal sign-in code expired. Try again.');
        case 'access_denied':
          throw TidalException('Tidal sign-in was denied.');
        case 'slow_down':
          sleep += 5;
          break;
        default:
          break; // authorization_pending — keep polling.
      }
    }
    throw TidalException('Timed out waiting for Tidal sign-in.');
  }

  /// Resolve the user id + country code from the bearer `/sessions` endpoint.
  /// The OAuth token response carries neither, so they must be fetched here.
  Future<({String userId, String countryCode})> _fetchSession(
    String accessToken,
  ) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_apiBase/sessions'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final j = jsonDecode(response.body) as Map<String, dynamic>;
        final uid = j['userId']?.toString();
        final cc = j['countryCode'] as String?;
        if (uid != null && uid.isNotEmpty) {
          return (
            userId: uid,
            countryCode: (cc != null && cc.isNotEmpty) ? cc : 'US',
          );
        }
      }
    } catch (_) {/* fall through to defaults */}
    return (userId: '', countryCode: 'US');
  }

  // --- Token lifecycle (refresh + persist) -------------------------------

  Future<_TidalCreds> _ensureValidToken(NetworkServerEntity server) async {
    final creds = _creds(server.token);
    if (creds == null) {
      throw TidalException('No Tidal sign-in. Tap "Sign in with Tidal".');
    }
    final nearExpiry = creds.expiresAtMs == null ||
        DateTime.now().millisecondsSinceEpoch > creds.expiresAtMs! - 60000;
    if (nearExpiry && creds.refreshToken != null) {
      return _refresh(server, creds);
    }
    return creds;
  }

  Future<_TidalCreds> _refresh(
    NetworkServerEntity server,
    _TidalCreds old,
  ) async {
    final refresh = old.refreshToken;
    if (refresh == null) {
      throw TidalException('Tidal session expired. Please sign in again.');
    }
    final tok = await _postForm('$_authBase/token', {
      'client_id': clientId,
      if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
    });
    final access = tok['access_token'] as String?;
    if (access == null) {
      throw TidalException('Tidal token refresh failed.');
    }
    final updated = _TidalCreds(
      accessToken: access,
      refreshToken: (tok['refresh_token'] as String?) ?? refresh,
      userId: old.userId,
      countryCode: old.countryCode,
      expiresAtMs: DateTime.now()
          .add(Duration(seconds: (tok['expires_in'] as num?)?.toInt() ?? 3600))
          .millisecondsSinceEpoch,
    );
    await _persist(server, updated);
    return updated;
  }

  Future<void> _persist(NetworkServerEntity server, _TidalCreds creds) async {
    final token = jsonEncode({
      'access_token': creds.accessToken,
      'refresh_token': creds.refreshToken,
      'user_id': creds.userId,
      'country_code': creds.countryCode,
      'expires_at_ms': creds.expiresAtMs,
    });
    try {
      await Database.instance.writeTxn(() async {
        final stored = await Database.networkServers.get(server.id);
        if (stored != null) {
          stored.token = token;
          await Database.networkServers.put(stored);
        }
      });
    } catch (e) {
      devLog('Tidal token persist failed: $e');
    }
  }

  // --- JSON API ----------------------------------------------------------

  Future<Map<String, dynamic>> _apiGet(
    NetworkServerEntity server,
    String path, {
    Map<String, String>? query,
    bool retry = true,
  }) async {
    final creds = await _ensureValidToken(server);
    final uri = Uri.parse('$_apiBase$path').replace(queryParameters: {
      'countryCode': creds.countryCode,
      ...?query,
    });
    final response = await _client.get(uri, headers: {
      'Authorization': 'Bearer ${creds.accessToken}',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 && retry && creds.refreshToken != null) {
      await _refresh(server, creds);
      return _apiGet(server, path, query: query, retry: false);
    }
    if (response.statusCode != 200) {
      throw TidalException('HTTP ${response.statusCode} for $path');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postForm(
    String url,
    Map<String, String> fields, {
    bool raw = false,
  }) async {
    final response = await _client
        .post(Uri.parse(url), body: fields)
        .timeout(const Duration(seconds: 20));
    final body = response.body;
    Map<String, dynamic>? parsed;
    if (body.isNotEmpty) {
      try {
        parsed = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {/* parsed stays null */}
    }
    if (response.statusCode != 200 && !raw) {
      // Raw detail only for developers; the user sees a friendly message.
      devLog('[Tidal] POST $url -> HTTP ${response.statusCode}: $body');
      throw TidalException(_friendlyHttp(response.statusCode, parsed));
    }
    return parsed ?? <String, dynamic>{};
  }

  /// Map a raw HTTP failure to a short, user-facing message. The raw body is
  /// logged separately via [devLog] (developer mode only).
  static String _friendlyHttp(int status, Map<String, dynamic>? parsed) {
    final err = parsed?['error'] as String?;
    if (err == 'invalid_client') {
      return 'Tidal rejected the app sign-in key. It rotates these — the built-in '
          'key may be out of date (a known limitation of the unofficial path).';
    }
    if (status == 401 || status == 403) {
      return 'Tidal refused the sign-in. Try again.';
    }
    if (status == 429) {
      return 'Too many Tidal requests. Wait a moment and try again.';
    }
    if (status >= 500) {
      return 'Tidal is unavailable right now. Try again shortly.';
    }
    return 'Could not reach Tidal (HTTP $status). Check your connection.';
  }

  // --- ping --------------------------------------------------------------

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    final creds = _creds(server.token);
    if (creds == null || creds.userId == null || creds.userId!.isEmpty) {
      devLog('Tidal ping failed: no stored token');
      return false;
    }
    try {
      await _apiGet(server, '/users/${creds.userId}');
      return true;
    } catch (e) {
      devLog('Tidal ping failed: $e');
      return false;
    }
  }

  // --- Cover art ---------------------------------------------------------

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    final url = coverUrl(marker);
    if (url.isEmpty) {
      throw TidalException('No Tidal cover for $marker');
    }
    final response =
        await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw TidalException('HTTP ${response.statusCode} for cover $marker');
    }
    return response.bodyBytes;
  }

  /// Build a `resources.tidal.com` cover URL from a Tidal cover uuid.
  @visibleForTesting
  static String coverUrl(String coverUuid, {int size = 1280}) {
    final id = coverUuid.replaceAll('-', '');
    if (id.length < 5) return '';
    final part = '${id.substring(0, 2)}/${id.substring(2, 4)}/${id.substring(4)}';
    return '$_coverHost/$part/${size}x$size.jpg';
  }

  // --- Stream ----------------------------------------------------------

  @override
  Future<({String url, Map<String, String> headers})?> streamDescriptor(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
  }) async {
    final resolved = await _resolveStreamable(server, remoteId);
    if (resolved == null) return null;
    return (url: resolved.url, headers: const <String, String>{});
  }

  @override
  Future<String> stream(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
    void Function(double progress)? onProgress,
  }) async {
    final cached = await _cache.getPath(server.id, remoteId, extension: extension);
    if (cached != null) return cached;

    final resolved = await _resolveStreamable(server, remoteId);
    if (resolved == null) {
      throw TidalException('No playable stream for $remoteId.');
    }
    final request = http.Request('GET', Uri.parse(resolved.url));
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw TidalException('HTTP ${response.statusCode} for stream $remoteId');
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
    return _cache.stash(
      server.id,
      remoteId,
      builder.takeBytes(),
      extension: resolved.ext ?? extension,
    );
  }

  /// Resolve a directly streamable CDN url + extension for a track, or null
  /// when the content is not in a playable-unencrypted form.
  Future<({String url, String? ext})?> _resolveStreamable(
    NetworkServerEntity server,
    String trackId,
  ) async {
    final info = await _apiGet(
      server,
      '/tracks/$trackId/playbackinfopostpaywall',
      query: {'playbackmode': 'STREAM', 'assetpresentation': 'FULL'},
    );
    final mime = info['manifestMimeType'] as String?;
    final manifest = info['manifest'] as String?;
    if (mime != 'application/vnd.tidal.bts' || manifest == null) {
      throw TidalException(
        'Track $trackId uses an unsupported Tidal format (HiRes/MQA/Atmos). '
        'Only unencrypted HiFi lossless is supported.',
      );
    }
    final Map<String, dynamic> decoded;
    try {
      decoded =
          jsonDecode(utf8.decode(base64Decode(manifest))) as Map<String, dynamic>;
    } catch (e) {
      throw TidalException('Could not decode Tidal manifest for $trackId: $e');
    }
    if (decoded['encryptionType'] != 'NONE') {
      throw TidalException(
        'Track $trackId is encrypted (HiRes/MQA). Only unencrypted HiFi '
        'lossless is supported.',
      );
    }
    final urls = decoded['urls'] as List<dynamic>?;
    if (urls == null || urls.isEmpty) {
      throw TidalException('Track $trackId manifest has no stream URL.');
    }
    return (
      url: urls.first as String,
      ext: _extFromMime(decoded['mimeType'] as String?),
    );
  }

  @visibleForTesting
  static String? extFromMime(String? mime) => _extFromMime(mime);
  static String? _extFromMime(String? mime) {
    switch (mime) {
      case 'audio/flac':
      case 'audio/x-flac':
        return 'flac';
      case 'audio/mp4':
      case 'audio/m4a':
      case 'audio/x-m4a':
        return 'm4a';
      case 'audio/mpeg':
        return 'mp3';
      default:
        return null;
    }
  }

  // --- Sync --------------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final creds = _creds(server.token);
    if (creds == null || creds.userId == null || creds.userId!.isEmpty) {
      throw TidalException('No Tidal sign-in. Tap "Sign in with Tidal".');
    }
    // ponytail: sync the user's favorite tracks (paginated, capped). Favorites
    // map 1:1 to SongEntity with embedded album/artist metadata. Pulling full
    // playlists/my-collection is a follow-up; this is the bounded, predictable
    // surface that fits the existing scan progress UI.
    const pageSize = 100;
    const maxTracks = 2000;
    final syncedRemoteIds = <String>{};
    var offset = 0;
    var songsFound = 0;
    var totalEstimate = 0;

    while (offset < maxTracks) {
      final Map<String, dynamic> payload;
      try {
        payload = await _apiGet(
          server,
          '/users/${creds.userId}/favorites/tracks',
          query: {'limit': '$pageSize', 'offset': '$offset'},
        );
      } catch (e) {
        devLog('Tidal sync page @ $offset failed: $e');
        break;
      }
      final items = (payload['items'] as List<dynamic>?) ?? const [];
      if (items.isEmpty) break;
      totalEstimate =
          (payload['totalNumberOfItems'] as num?)?.toInt() ?? (offset + items.length);

      final entities = <SongEntity>[];
      for (final raw in items) {
        final item = (raw as Map<String, dynamic>)['item'] as Map<String, dynamic>?;
        if (item == null) continue;
        final entity = buildSongEntity(server, item);
        if (entity != null) entities.add(entity);
      }
      if (entities.isNotEmpty) {
        await _repo.upsertSongs(entities);
        syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));
        songsFound += entities.length;
      }

      offset += items.length;
      yield ScanProgress(
        songsFound: songsFound,
        totalFiles: totalEstimate,
        filesProcessed: offset,
        phase: 'Syncing ${server.label}',
      );
      if (items.length < pageSize) break;
    }

    await purgeAndStampNetworkSync(server, syncedRemoteIds);

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: totalEstimate,
      filesProcessed: offset,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  /// Map a Tidal track object to a [SongEntity]. Returns null when the track
  /// lacks an id. Pure (no network/DB) so it can be unit-tested directly.
  @visibleForTesting
  static SongEntity? buildSongEntity(NetworkServerEntity server, Map<String, dynamic> t) {
    final remoteId = t['id']?.toString();
    if (remoteId == null) return null;
    final artists = (t['artists'] as List<dynamic>?)?.cast<Map<String, dynamic>?>();
    final album = t['album'] as Map<String, dynamic>?;
    final durationSec = (t['duration'] as num?)?.toInt();
    final cover = (album?['cover'] as String?) ?? (t['cover'] as String?);
    return SongEntity()
      ..filePath = '${NetworkProtocol.tidal}://${server.id}/$remoteId'
      ..title = (t['title'] as String?) ?? 'Unknown'
      ..artist = (artists != null && artists.isNotEmpty)
          ? (artists.first?['name'] as String? ?? 'Unknown')
          : ((album?['artist'] as Map<String, dynamic>?)?['name'] as String?) ??
              'Unknown'
      ..album = (album?['title'] as String?)
      ..albumArtist =
          ((album?['artist'] as Map<String, dynamic>?)?['name'] as String?)
      ..durationMs = durationSec == null ? null : durationSec * 1000
      ..trackNumber = (t['trackNumber'] as num?)?.toInt()
      ..discNumber = (t['volumeNumber'] as num?)?.toInt()
      ..year = _releaseYear(album?['releaseDate'] as String?)
      ..fileType = _extForQuality(t['audioQuality'] as String?)
      ..albumArtPath = (cover != null && cover.isNotEmpty)
          ? '$_coverMarkerScheme$cover'
          : null
      ..sourceType = NetworkProtocol.tidal
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }

  static int? _releaseYear(String? isoDate) {
    if (isoDate == null || isoDate.length < 4) return null;
    return int.tryParse(isoDate.substring(0, 4));
  }

  static String? _extForQuality(String? quality) {
    switch (quality) {
      case 'HIGH':
        return 'm4a'; // AAC
      case 'LOSSLESS':
      case 'HI_RES_LOSSLESS':
        return 'flac';
      case 'HI_RES':
        return 'flac'; // MQA-in-FLAC; likely unplayable here, surfaced at play.
      default:
        return null;
    }
  }
}

class _TidalCreds {
  const _TidalCreds({
    required this.accessToken,
    this.refreshToken,
    this.userId,
    required this.countryCode,
    this.expiresAtMs,
  });
  final String accessToken;
  final String? refreshToken;
  final String? userId;
  final String countryCode;
  final int? expiresAtMs;
}

class TidalException implements Exception {
  final String message;
  /// For device-flow launch failures (no callback path): the verification URL
  /// the user can open manually to finish signing in.
  final String? verificationUri;
  TidalException(this.message, {this.verificationUri});
  @override
  String toString() => message;
}
