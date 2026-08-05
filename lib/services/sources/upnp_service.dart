import 'dart:async';
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

/// UPnP / DLNA MediaServer client (ContentDirectory:1 over SOAP).
///
/// The user provides the device description URL (typically `rootDesc.xml`).
/// Pure Dart: device description + SOAP Browse over HTTP, audio streamed via
/// plain HTTP GET of the item's `<res>` url. No auth — home DLNA servers are
/// open on the LAN by convention.
///
/// No token is stored; [NetworkServerEntity.token] stays null.
class UpnpService implements NetworkSourceService {
  UpnpService._({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
  })  : _client = client ?? http.Client(),
        _songRepository = songRepository,
        _networkCache = networkCache;

  static UpnpService instance = UpnpService._();

  @visibleForTesting
  static UpnpService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
  }) =>
      UpnpService._(
        client: client,
        songRepository: songRepository,
        networkCache: networkCache,
      );

  static const String _coverMarkerScheme = 'upnp-cover://';
  static const String _cdServiceType =
      'urn:schemas-upnp-org:service:ContentDirectory:1';
  static const String _soapAction =
      '"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"';

  final http.Client _client;
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  @override
  String get protocol => NetworkProtocol.upnp;

  @override
  String get coverScheme => _coverMarkerScheme;

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    // DLNA home servers are anonymous on the LAN; nothing to store.
    return null;
  }

  // --- Device description -------------------------------------------------

  /// Resolve the ContentDirectory control URL from the device description, or
  /// null if it can't be found / the server is unreachable.
  Future<String?> resolveControlUrl(NetworkServerEntity server) async {
    try {
      final response = await _client
          .get(Uri.parse(server.baseUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final doc = XmlDocument.parse(response.body);
      // Find the ContentDirectory service element (case varies across servers).
      XmlNode? serviceNode;
      for (final svc in doc.findAllElements('service', namespace: '*')) {
        final st = svc
            .findElements('serviceType', namespace: '*')
            .firstOrNull
            ?.innerText;
        if (st != null && st.contains('ContentDirectory')) {
          serviceNode = svc;
          break;
        }
      }
      if (serviceNode == null) return null;
      final controlUrl = serviceNode
          .findElements('controlURL', namespace: '*')
          .firstOrNull
          ?.innerText
          .trim();
      if (controlUrl == null || controlUrl.isEmpty) return null;
      return Uri.parse(server.baseUrl).resolveUri(Uri.parse(controlUrl)).toString();
    } catch (e) {
      AppLog.instance.add('UPnP description fetch failed: $e');
      return null;
    }
  }

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    final controlUrl = await resolveControlUrl(server);
    return controlUrl != null;
  }

  // --- SOAP Browse --------------------------------------------------------

  Future<String> _browse(
    String controlUrl,
    String objectId, {
    int timeoutSeconds = 30,
  }) async {
    final body = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:Browse xmlns:u="$_cdServiceType">'
        '<ObjectID>${_escape(objectId)}</ObjectID>'
        '<BrowseFlag>BrowseDirectChildren</BrowseFlag>'
        '<Filter>*</Filter>'
        '<StartingIndex>0</StartingIndex>'
        '<RequestedCount>0</RequestedCount>'
        '<SortCriteria></SortCriteria>'
        '</u:Browse>'
        '</s:Body>'
        '</s:Envelope>';
    final request = http.Request('POST', Uri.parse(controlUrl))
      ..headers['Content-Type'] = 'text/xml; charset="utf-8"'
      ..headers['SOAPAction'] = _soapAction
      ..body = body;
    final streamed =
        await _client.send(request).timeout(Duration(seconds: timeoutSeconds));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw UpnpNetworkException(
          'HTTP ${response.statusCode} for Browse $objectId');
    }
    final doc = XmlDocument.parse(response.body);
    // The DIDL-Lite payload sits (escaped) inside the <Result> element.
    final didl = doc
        .findAllElements('Result', namespace: '*')
        .firstOrNull
        ?.innerText;
    if (didl == null || didl.isEmpty) return '';
    return didl;
  }

  String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // --- Cover art + stream -------------------------------------------------

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    final url = Uri.decodeFull(marker);
    final response =
        await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw UpnpNetworkException('HTTP ${response.statusCode} for cover');
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

    final url = Uri.decodeFull(remoteId);
    final request = http.Request('GET', Uri.parse(url));
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw UpnpNetworkException('HTTP ${response.statusCode} for stream');
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
    // remoteId is the url-encoded <res> stream URL. DLNA MediaServer spec
    // mandates byte-range support; no auth on LAN by convention.
    return (url: Uri.decodeFull(remoteId), headers: const <String, String>{});
  }

  // --- Library walk -------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final controlUrl = await resolveControlUrl(server);
    if (controlUrl == null) {
      throw StateError(
          'UPnP server "${server.label}" has no ContentDirectory service');
    }

    final syncedRemoteIds = <String>{};
    var songsFound = 0;

    // BFS over containers. Start at root "0"; some servers use different root
    // ids but "0" is the UPnP convention.
    final queue = <_UpnpContainer>[_UpnpContainer(id: '0', title: 'Root')];
    final allContainers = <_UpnpContainer>[_UpnpContainer(id: '0', title: 'Root')];
    var filesProcessed = 0;

    while (queue.isNotEmpty) {
      final container = queue.removeAt(0);
      final String didl;
      try {
        didl = await _browse(controlUrl, container.id);
      } catch (e) {
        AppLog.instance.add(
          'UPnP sync skipped container "${container.title}" on ${server.label}: $e',
        );
        filesProcessed++;
        yield _progress(server, songsFound, allContainers.length,
            filesProcessed, container.title);
        continue;
      }

      final parsed = _parseDidl(didl);
      if (parsed.items.isNotEmpty) {
        final entities = parsed.items
            .map((item) => _songEntity(server: server, item: item))
            .toList();
        await _repo.upsertSongs(entities);
        syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));
        songsFound += entities.length;
      }
      for (final sub in parsed.containers) {
        allContainers.add(sub);
        queue.add(sub);
      }

      filesProcessed++;
      yield _progress(server, songsFound, allContainers.length,
          filesProcessed, container.title);
    }

    await purgeAndStampNetworkSync(server, syncedRemoteIds);

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: allContainers.length,
      filesProcessed: filesProcessed,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  ScanProgress _progress(
    NetworkServerEntity server,
    int songsFound,
    int totalContainers,
    int filesProcessed,
    String currentTitle,
  ) {
    return ScanProgress(
      songsFound: songsFound,
      totalFiles: totalContainers,
      filesProcessed: filesProcessed,
      phase: 'Syncing ${server.label}',
      currentFile: currentTitle,
    );
  }

  _DidlParseResult _parseDidl(String didl) {
    final containers = <_UpnpContainer>[];
    final items = <_DidlItem>[];
    if (didl.isEmpty) return _DidlParseResult(containers, items);

    XmlDocument doc;
    try {
      doc = XmlDocument.parse(didl);
    } catch (_) {
      return _DidlParseResult(containers, items);
    }

    for (final c in doc.findAllElements('container', namespace: '*')) {
      final id = c.getAttribute('id');
      if (id == null) continue;
      final title = _text(c, 'title');
      final klass = _text(c, 'class');
      // Only recurse into containers that look like music navigation nodes;
      // this bounds the walk on servers with non-music subtrees.
      if (klass.isEmpty || !klass.contains('object.container')) continue;
      containers.add(_UpnpContainer(id: id, title: title.isEmpty ? id : title));
    }

    for (final it in doc.findAllElements('item', namespace: '*')) {
      final klass = _text(it, 'class');
      if (!klass.startsWith('object.item.audioItem')) continue;
      final resElement = it.findElements('res', namespace: '*').firstOrNull;
      if (resElement == null) continue;
      final resUrl = resElement.innerText.trim();
      if (resUrl.isEmpty) continue;
      final protocolInfo = resElement.getAttribute('protocolInfo') ?? '';
      final ext = _audioExtensionFromProtocolInfo(protocolInfo) ??
          _audioExtensionFromUrl(resUrl);
      items.add(_DidlItem(
        title: _text(it, 'title').isEmpty
            ? 'Unknown'
            : _text(it, 'title'),
        artist: _text(it, 'artist'),
        album: _text(it, 'album'),
        albumArtist: _text(it, 'albumArtist'),
        trackNumber: int.tryParse(_text(it, 'originalTrackNumber')),
        genre: _text(it, 'genre'),
        year: _yearFrom(_text(it, 'date')),
        durationMs: _parseDurationMs(resElement.getAttribute('duration')),
        size: int.tryParse(resElement.getAttribute('size') ?? ''),
        fileType: ext,
        resUrl: resUrl,
        coverUrl: _text(it, 'albumArtURI').isEmpty
            ? null
            : _text(it, 'albumArtURI'),
        protocolInfo: protocolInfo,
      ));
    }

    return _DidlParseResult(containers, items);
  }

  // --- Test surface (pure DIDL-Lite parse, no network) --------------------

  @visibleForTesting
  static List<({String title, String artist, String album, int? trackNumber, int? durationMs, String? fileType, String resUrl, String? coverUrl, int? year})> parseDidlItemsForTest(String didl) {
    final svc = UpnpService._();
    return svc
        ._parseDidl(didl)
        .items
        .map((i) => (
              title: i.title,
              artist: i.artist,
              album: i.album,
              trackNumber: i.trackNumber,
              durationMs: i.durationMs,
              fileType: i.fileType,
              resUrl: i.resUrl,
              coverUrl: i.coverUrl,
              year: i.year,
            ))
        .toList();
  }

  String _text(XmlElement parent, String localName) {
    return parent
            .findElements(localName, namespace: '*')
            .firstOrNull
            ?.innerText
            .trim() ??
        '';
  }

  int? _yearFrom(String date) {
    if (date.length >= 4) {
      final year = int.tryParse(date.substring(0, 4));
      if (year != null && year > 1000 && year < 3000) return year;
    }
    return null;
  }

  // Duration "H:MM:SS.fraction" → milliseconds.
  int? _parseDurationMs(String? duration) {
    if (duration == null || duration.isEmpty) return null;
    final parts = duration.split(':');
    if (parts.length != 3) return null;
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    return ((h * 3600 + m * 60 + s) * 1000).round();
  }

  String? _audioExtensionFromProtocolInfo(String protocolInfo) {
    // Format: http-get:*:<mime>:*
    final fields = protocolInfo.split(':');
    if (fields.length < 3) return null;
    final mime = fields[2].toLowerCase();
    const byMime = {
      'audio/mpeg': 'mp3',
      'audio/mp3': 'mp3',
      'audio/flac': 'flac',
      'audio/x-flac': 'flac',
      'audio/wav': 'wav',
      'audio/x-wav': 'wav',
      'audio/ogg': 'ogg',
      'audio/mp4': 'm4a',
      'audio/m4a': 'm4a',
      'audio/x-m4a': 'm4a',
      'audio/aac': 'aac',
      'audio/aiff': 'aiff',
      'audio/x-aiff': 'aiff',
      'audio/webm': 'weba',
      'audio/dsd': 'dsf',
    };
    return byMime[mime];
  }

  String? _audioExtensionFromUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    final dot = path.lastIndexOf('.');
    if (dot <= 0) return null;
    return path.substring(dot + 1).toLowerCase();
  }

  SongEntity _songEntity({
    required NetworkServerEntity server,
    required _DidlItem item,
  }) {
    final remoteId = Uri.encodeComponent(item.resUrl);
    return SongEntity()
      ..filePath = '${NetworkProtocol.upnp}://${server.id}/$remoteId'
      ..title = item.title
      ..artist = item.artist.isEmpty ? 'Unknown' : item.artist
      ..album = item.album.isEmpty ? null : item.album
      ..albumArtist =
          item.albumArtist.isEmpty ? null : item.albumArtist
      ..durationMs = item.durationMs
      ..trackNumber = item.trackNumber
      ..year = item.year
      ..genre = item.genre.isEmpty ? null : item.genre
      ..fileSize = item.size
      ..fileType = item.fileType
      ..albumArtPath = item.coverUrl != null
          ? '$_coverMarkerScheme${Uri.encodeComponent(item.coverUrl!)}'
          : null
      ..sourceType = NetworkProtocol.upnp
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }
}

class _UpnpContainer {
  const _UpnpContainer({required this.id, required this.title});
  final String id;
  final String title;
}

class _DidlItem {
  const _DidlItem({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.trackNumber,
    required this.genre,
    required this.year,
    required this.durationMs,
    required this.size,
    required this.fileType,
    required this.resUrl,
    required this.coverUrl,
    required this.protocolInfo,
  });
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final int? trackNumber;
  final String genre;
  final int? year;
  final int? durationMs;
  final int? size;
  final String? fileType;
  final String resUrl;
  final String? coverUrl;
  final String protocolInfo;
}

class _DidlParseResult {
  const _DidlParseResult(this.containers, this.items);
  final List<_UpnpContainer> containers;
  final List<_DidlItem> items;
}

class UpnpNetworkException implements Exception {
  final String message;
  UpnpNetworkException(this.message);
  @override
  String toString() => 'UPnP error: $message';
}
