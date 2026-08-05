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
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import 'network_source_service.dart';

/// WebDAV client. Recursive PROPFIND walk of the share, HTTP Basic auth.
///
/// Auth: HTTP Basic needs the recoverable password, so [NetworkServerEntity.token]
/// stores `base64(password)` (not a hash). The tradeoff is accepted: the secret
/// is at-rest reversible, but never in plaintext and only in the local DB.
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
  })  : _client = client ?? http.Client(),
        _songRepository = songRepository,
        _networkCache = networkCache;

  static WebdavService instance = WebdavService._();

  @visibleForTesting
  static WebdavService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
  }) =>
      WebdavService._(
        client: client,
        songRepository: songRepository,
        networkCache: networkCache,
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
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  @override
  String get protocol => NetworkProtocol.webdav;

  @override
  String get coverScheme => _coverMarkerScheme;

  // --- Auth ---------------------------------------------------------------

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    // Local transform: HTTP Basic needs the recoverable password.
    return base64Encode(utf8.encode(password));
  }

  String _basicAuth(NetworkServerEntity server) {
    final user = server.username ?? '';
    final password = _password(server);
    final credentials = base64Encode(utf8.encode('$user:$password'));
    return 'Basic $credentials';
  }

  String _password(NetworkServerEntity server) {
    if (server.token == null || server.token!.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(server.token!));
    } catch (_) {
      return '';
    }
  }

  String _origin(NetworkServerEntity server) =>
      Uri.parse(server.baseUrl).origin;

  // --- PROPFIND -----------------------------------------------------------

  static const _propfindBody = '<?xml version="1.0" encoding="utf-8"?>'
      '<D:propfind xmlns:D="DAV:"><D:prop>'
      '<D:resourcetype/><D:getcontentlength/><D:getlastmodified/>'
      '<D:displayname/>'
      '</D:prop></D:propfind>';

  Future<http.Response> _propfind(
    NetworkServerEntity server,
    String url, {
    int depth = 1,
  }) async {
    final request = http.Request('PROPFIND', Uri.parse(url))
      ..headers['Depth'] = '$depth'
      ..headers['Content-Type'] = 'application/xml; charset=utf-8'
      ..headers['Authorization'] = _basicAuth(server)
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
      final decoded = Uri.decodeComponent(href);
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
      final response = await _propfind(server, server.baseUrl, depth: 0);
      return response.statusCode == 207 || response.statusCode == 200;
    } catch (e) {
      AppLog.instance.add('WebDAV ping failed: $e');
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
    final uri = Uri.parse('${_origin(server)}$href');
    final response = await _client.get(
      uri,
      headers: {'Authorization': _basicAuth(server)},
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
    // decode to build the request URL.
    final href = remoteId.contains('%') ? Uri.decodeComponent(remoteId) : remoteId;
    final uri = Uri.parse('${_origin(server)}$href');
    final request = http.Request('GET', uri)
      ..headers['Authorization'] = _basicAuth(server);
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
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
    // remoteId is stored url-encoded (cache-key-safe); decode for the URL.
    final href = remoteId.contains('%')
        ? Uri.decodeComponent(remoteId)
        : remoteId;
    final uri = Uri.parse('${_origin(server)}$href');
    return (url: uri.toString(), headers: {'Authorization': _basicAuth(server)});
  }

  // --- Library walk -------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final syncedRemoteIds = <String>{};
    var songsFound = 0;

    // Queue holds (absolutePath, depth). absolutePath is the server-relative
    // path used both to build child URLs and to derive album/artist names.
    final queue = <_DavDir>[];
    final allDirs = <String>[];
    final origin = _origin(server);

    String rootPath;
    try {
      rootPath = Uri.parse(server.baseUrl).path;
    } catch (_) {
      rootPath = '';
    }
    queue.add(_DavDir(url: server.baseUrl, path: rootPath));
    allDirs.add(rootPath);

    var filesProcessed = 0;
    while (queue.isNotEmpty) {
      final dir = queue.removeAt(0);
      List<_DavEntry> entries;
      try {
        final response = await _propfind(server, dir.url);
        if (response.statusCode != 207 && response.statusCode != 200) {
          filesProcessed++;
          yield _progress(server, songsFound, allDirs.length, filesProcessed,
              dir.path);
          continue;
        }
        entries = _parseMultistatus(response.body, dir.path);
      } catch (e) {
        AppLog.instance
            .add('WebDAV sync skipped "${dir.path}" on ${server.label}: $e');
        filesProcessed++;
        yield _progress(
            server, songsFound, allDirs.length, filesProcessed, dir.path);
        continue;
      }

      String? coverHref;
      final songEntries = <_DavEntry>[];
      for (final e in entries) {
        if (e.isCollection) {
          allDirs.add(e.href);
          queue.add(_DavDir(url: '$origin${e.href}', path: e.href));
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

    await purgeAndStampNetworkSync(server, syncedRemoteIds);

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
    return slash >= 0 ? Uri.decodeComponent(p.substring(slash + 1)) : Uri.decodeComponent(p);
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
  const _DavDir({required this.url, required this.path});
  final String url;
  final String path;
}

class WebdavNetworkException implements Exception {
  final String message;
  WebdavNetworkException(this.message);
  @override
  String toString() => 'WebDAV error: $message';
}
