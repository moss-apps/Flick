import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../core/utils/app_log.dart';
import '../../data/entities/network_server_entity.dart';
import '../../data/entities/song_entity.dart';
import '../../data/repositories/song_repository.dart';
import '../../l10n/l10n.dart';
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import 'network_credential_store.dart';
import 'network_endpoint_policy.dart';
import 'network_source_service.dart';

/// WebDAV client. Recursive PROPFIND walk of the share, HTTP Basic auth.
///
/// Auth: HTTP Basic needs the recoverable password. The protocol-specific
/// `base64(password)` secret lives in Keystore-backed secure storage, never in
/// Isar; [NetworkServerEntity] only holds its opaque `credentialRef`.
///
/// Metadata limitation: WebDAV exposes only filename + size + mtime. Title is
/// derived from the filename, album from the parent folder, artist from the
/// grandparent (or Unknown). Full tag extraction would require downloading each
/// file, out of scope for the first cut.
class WebdavService implements NetworkSourceService {
  WebdavService._({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    NetworkCredentialStore? credentialStore,
  })  : _client = NetworkEndpointPolicy.secureClient(client),
        _songRepository = songRepository,
        _networkCache = networkCache,
        _credentials = credentialStore ?? NetworkCredentialStore.instance;

  static WebdavService instance = WebdavService._();

  @visibleForTesting
  static WebdavService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    NetworkCredentialStore? credentialStore,
  }) =>
      WebdavService._(
        client: client,
        songRepository: songRepository,
        networkCache: networkCache,
        credentialStore: credentialStore,
      );

  static const String _coverMarkerScheme = 'webdav-cover://';

  static const _audioExtensions = {
    'flac', 'mp3', 'm4a', 'wav', 'ogg', 'opus', 'aac', 'wv', 'ape', 'mpc',
    'aiff', 'dsf', 'dff',
  };
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};
  // Cover filenames scanned per folder, in priority order.
  static const _coverNames = [
    'cover', 'folder', 'album', 'albumart', 'front',
  ];

  final http.Client _client;
  final NetworkCredentialStore _credentials;
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  @override
  String get protocol => NetworkProtocol.webdav;

  @override
  String get coverScheme => _coverMarkerScheme;

  @override
  String? get lastPingError => null;

  // --- Auth ---------------------------------------------------------------

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    // Local transform: HTTP Basic needs the recoverable password.
    return base64Encode(utf8.encode(password));
  }

  Future<String> _basicAuth(NetworkServerEntity server) async {
    NetworkEndpointPolicy.requireAllowed(server);
    final user = server.username ?? '';
    final password = await _password(server);
    final credentials = base64Encode(utf8.encode('$user:$password'));
    return 'Basic $credentials';
  }

  Future<String> _password(NetworkServerEntity server) async {
    final credential = await _credentials.read(server);
    final stored = credential?.secret;
    if (stored == null || stored.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(stored));
    } catch (_) {
      throw NetworkCredentialException(l10n.credentialStorageUnreadable);
    }
  }

  // --- Path encoding ------------------------------------------------------
  //
  // Invariant: every path inside this service is stored decoded exactly once
  // (at PROPFIND parse time) and re-encoded only when building a request URL.
  // Decoding twice throws ArgumentError on non-ASCII or literal `%` names,
  // which used to abort sync; skipping the re-encode lets `#`/`?` in names be
  // reparsed as fragment/query.

  /// Single-pass decode. Falls back to the raw string when the server returns
  /// non-conformant hrefs (raw UTF-8, bare `%`), so one odd entry can't abort
  /// a whole directory walk.
  static String _tryDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  /// Percent-encodes each path segment, preserving `/` separators.
  static String _encodePath(String decodedPath) =>
      decodedPath.split('/').map(Uri.encodeComponent).join('/');

  Uri _requestUri(NetworkServerEntity server, String decodedPath) {
    final endpoint = NetworkEndpointPolicy.requireAllowed(server);
    final path = decodedPath.startsWith('/') ? decodedPath : '/$decodedPath';
    // Authority always comes from the configured endpoint.
    return endpoint.replace(path: _encodePath(path));
  }

  // --- PROPFIND -----------------------------------------------------------

  static const _propfindBody = '<?xml version="1.0" encoding="utf-8"?>'
      '<D:propfind xmlns:D="DAV:"><D:prop>'
      '<D:resourcetype/><D:getcontentlength/><D:getlastmodified/>'
      '<D:displayname/>'
      '</D:prop></D:propfind>';

  Future<http.Response> _propfind(
    NetworkServerEntity server,
    Uri uri, {
    int depth = 1,
  }) async {
    final request = http.Request('PROPFIND', uri)
      ..headers['Depth'] = '$depth'
      ..headers['Content-Type'] = 'application/xml; charset=utf-8'
      ..headers['Authorization'] = await _basicAuth(server)
      ..body = _propfindBody;
    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 30),
        );
    return http.Response.fromStream(streamed);
  }

  List<_DavEntry> _parseMultistatus(String body, String requestedHref) {
    final results = <_DavEntry>[];
    XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } catch (_) {
      return results;
    }
    for (final response
        in doc.findAllElements('response', namespace: '*')) {
      final href = response
          .findElements('href', namespace: '*')
          .firstOrNull
          ?.innerText
          .trim();
      if (href == null) continue;
      final decoded = _tryDecode(href);
      // Skip the self entry (the requested collection itself).
      if (_samePath(decoded, requestedHref)) continue;

      final isCollection = response
              .findAllElements('collection', namespace: '*')
              .isNotEmpty;
      // ponytail: getcontentlength nests under propstat/prop; recursive find
      // keeps this robust to both flattened and nested multistatus bodies.
      final sizeText = response
          .findAllElements('getcontentlength', namespace: '*')
          .firstOrNull
          ?.innerText;
      results.add(_DavEntry(
        href: decoded,
        isCollection: isCollection,
        size: sizeText == null ? null : int.tryParse(sizeText),
      ));
    }
    return results;
  }

  bool _samePath(String a, String b) {
    String norm(String s) => s.endsWith('/') && s.length > 1
        ? s.substring(0, s.length - 1)
        : s;
    return norm(a) == norm(b);
  }

  // --- Test surface (pure parse helpers, no network) ----------------------

  @visibleForTesting
  static List<({String href, bool isCollection, int? size})> parseMultistatusForTest(
    String body,
    String requestedHref,
  ) {
    final svc = WebdavService._();
    return svc
        ._parseMultistatus(body, requestedHref)
        .map((e) => (
              href: e.href,
              isCollection: e.isCollection,
              size: e.size,
            ))
        .toList();
  }

  @visibleForTesting
  static bool isAudioPath(String href) => WebdavService._()._isAudio(href);

  @visibleForTesting
  static bool isCoverPath(String href) => WebdavService._()._isCoverName(href);

  // --- ping ---------------------------------------------------------------

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    try {
      final endpoint = NetworkEndpointPolicy.requireAllowed(server);
      final response = await _propfind(server, endpoint, depth: 0);
      return response.statusCode == 207 || response.statusCode == 200;
    } catch (e) {
      AppLog.instance.add('WebDAV ping failed (${e.runtimeType})');
      return false;
    }
  }

  // --- Cover art + stream -------------------------------------------------

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    final href = utf8.decode(base64Decode(marker));
    final uri = _requestUri(server, href);
    final response = await _client.get(
      uri,
      headers: {'Authorization': await _basicAuth(server)},
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw WebdavNetworkException('HTTP ${response.statusCode} for cover');
    }
    return response.bodyBytes;
  }

  @override
  Future<String> stream(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
    void Function(double progress)? onProgress,
  }) async {
    final cached =
        await _cache.getPath(server.id, remoteId, extension: extension);
    if (cached != null) return cached;

    // remoteId is stored url-encoded so the cache key is filesystem-safe;
    // decode once, then re-encode at the request boundary.
    final href = _tryDecode(remoteId);
    final uri = _requestUri(server, href);
    final request = http.Request('GET', uri)
      ..headers['Authorization'] = await _basicAuth(server);
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      await response.stream.listen(null).cancel();
      throw WebdavNetworkException('HTTP ${response.statusCode} for stream');
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
    return _cache.stash(server.id, remoteId, builder.takeBytes(),
        extension: extension);
  }

  @override
  Future<({String url, Map<String, String> headers})?> streamDescriptor(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
  }) async {
    // remoteId is stored url-encoded (cache-key-safe); decode once, then
    // re-encode at the request boundary.
    final href = _tryDecode(remoteId);
    final uri = _requestUri(server, href);
    return (
      url: uri.toString(),
      headers: {'Authorization': await _basicAuth(server)},
    );
  }

  // --- Library walk -------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final endpoint = NetworkEndpointPolicy.requireAllowed(server);
    final syncedRemoteIds = <String>{};
    var songsFound = 0;

    // Queue holds (absolutePath, depth). absolutePath is the server-relative
    // path used both to build child URLs and to derive album/artist names.
    final queue = <_DavDir>[];
    final allDirs = <String>[];
    final rootPath = _tryDecode(endpoint.path);
    queue.add(_DavDir(uri: endpoint, path: rootPath));
    allDirs.add(rootPath);

    var filesProcessed = 0;
    while (queue.isNotEmpty) {
      final dir = queue.removeAt(0);
      final response = await _propfind(server, dir.uri);
      if (response.statusCode != 207 && response.statusCode != 200) {
        // A partial walk must not delete the previously synced library.
        throw WebdavNetworkException(
          'WebDAV PROPFIND returned HTTP ${response.statusCode}',
        );
      }
      final entries = _parseMultistatus(response.body, dir.path);

      String? coverHref;
      final songEntries = <_DavEntry>[];
      for (final e in entries) {
        if (e.isCollection) {
          allDirs.add(e.href);
          queue.add(_DavDir(uri: _requestUri(server, e.href), path: e.href));
        } else if (_isCoverName(e.href)) {
          coverHref ??= e.href;
        } else if (_isAudio(e.href)) {
          songEntries.add(e);
        }
      }

      if (songEntries.isNotEmpty) {
        final albumName = _lastPathSegment(dir.path);
        final artist = _grandparentSegment(dir.path);
        final entities = songEntries.map((e) {
          final remoteId = Uri.encodeComponent(e.href);
          return _songEntity(
            server: server,
            href: e.href,
            remoteId: remoteId,
            size: e.size,
            album: albumName,
            artist: artist,
            coverHref: coverHref,
          );
        }).toList();
        await _repo.upsertSongs(entities);
        syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));
        songsFound += entities.length;
      }

      filesProcessed++;
      yield _progress(
          server, songsFound, allDirs.length, filesProcessed, dir.path);
    }

    await purgeAndStampNetworkSync(
      server,
      syncedRemoteIds,
      repo: _songRepository,
    );

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: allDirs.length,
      filesProcessed: filesProcessed,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  ScanProgress _progress(
    NetworkServerEntity server,
    int songsFound,
    int totalDirs,
    int filesProcessed,
    String currentPath,
  ) {
    return ScanProgress(
      songsFound: songsFound,
      totalFiles: totalDirs,
      filesProcessed: filesProcessed,
      phase: 'Syncing ${server.label}',
      currentFile: _lastPathSegment(currentPath),
    );
  }

  SongEntity _songEntity({
    required NetworkServerEntity server,
    required String href,
    required String remoteId,
    required int? size,
    required String album,
    required String artist,
    required String? coverHref,
  }) {
    final fileName = _lastPathSegment(href);
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot + 1).toLowerCase() : null;
    return SongEntity()
      ..filePath = '${NetworkProtocol.webdav}://${server.id}/$remoteId'
      ..title = baseName.replaceAll(RegExp(r'^\d+[.\-\s]+'), '')
      ..artist = artist
      ..album = album.isEmpty ? null : album
      ..fileSize = size
      ..fileType = ext
      ..albumArtPath = coverHref != null
          ? '$_coverMarkerScheme${base64Encode(utf8.encode(coverHref))}'
          : null
      ..sourceType = NetworkProtocol.webdav
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }

  bool _isAudio(String href) {
    final ext = _extension(href);
    return ext != null && _audioExtensions.contains(ext);
  }

  bool _isCoverName(String href) {
    final ext = _extension(href);
    if (ext == null || !_imageExtensions.contains(ext)) return false;
    final name = _lastPathSegment(href);
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot).toLowerCase() : name.toLowerCase();
    return _coverNames.any((c) => stem == c || stem.startsWith('$c.'));
  }

  String? _extension(String href) {
    final name = _lastPathSegment(href);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  String _lastPathSegment(String path) {
    var p = path;
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    final slash = p.lastIndexOf('/');
    return slash >= 0 ? p.substring(slash + 1) : p;
  }

  String _grandparentSegment(String path) {
    var p = path;
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    // Drop the last segment (album folder) and read the new last (artist).
    final slash = p.lastIndexOf('/');
    if (slash <= 0) return 'Unknown';
    final parent = p.substring(0, slash);
    final artist = _lastPathSegment(parent);
    return artist.isEmpty ? 'Unknown' : artist;
  }
}

class _DavEntry {
  const _DavEntry({
    required this.href,
    required this.isCollection,
    this.size,
  });
  final String href;
  final bool isCollection;
  final int? size;
}

class _DavDir {
  const _DavDir({required this.uri, required this.path});
  final Uri uri;
  final String path;
}

class WebdavNetworkException implements Exception {
  final String message;
  WebdavNetworkException(this.message);
  @override
  String toString() => 'WebDAV error: $message';
}
