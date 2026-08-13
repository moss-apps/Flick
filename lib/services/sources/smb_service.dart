import 'dart:async';
import 'dart:convert';

import '../../core/utils/app_log.dart';
import '../../data/entities/network_server_entity.dart';
import '../../data/entities/song_entity.dart';
import '../../data/repositories/song_repository.dart';
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import '../../src/rust/api/smb_api.dart';
import 'network_source_service.dart';

/// SMB2/3 client backed by the pure-Rust `smb2` crate (via flutter_rust_bridge).
///
/// Auth: NTLM needs the recoverable password, so [NetworkServerEntity.token]
/// stores `base64(password)` (not a hash) — same tradeoff as WebDAV.
///
/// Metadata limitation: SMB exposes only filename + size + mtime. Title is
/// derived from the filename, album from the parent folder, artist from the
/// grandparent (or Unknown). Full tag extraction would require downloading each
/// file, out of scope for the first cut.
class SmbService implements NetworkSourceService {
  SmbService._({
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
  })  : _songRepository = songRepository,
        _networkCache = networkCache;

  static SmbService instance = SmbService._();

  static const _audioExtensions = {
    'flac', 'mp3', 'm4a', 'wav', 'ogg', 'opus', 'aac', 'wv', 'ape', 'mpc',
    'aiff', 'dsf', 'dff',
  };
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};
  static const _coverNames = ['cover', 'folder', 'album', 'albumart', 'front'];

  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  @override
  String get protocol => NetworkProtocol.smb;

  @override
  String get coverScheme => 'smb-cover://';

  // --- Auth + URL parsing -------------------------------------------------

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    // NTLM needs the recoverable password.
    return password.isEmpty ? null : base64Encode(utf8.encode(password));
  }

  String _password(NetworkServerEntity server) {
    if (server.token == null || server.token!.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(server.token!));
    } catch (_) {
      return '';
    }
  }

  ({String host, int port, String share, String rootPath}) _parseServer(
    NetworkServerEntity server,
  ) {
    final uri = Uri.parse(server.baseUrl);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return (
      host: uri.host,
      port: uri.port == 0 ? 445 : uri.port,
      share: segments.isNotEmpty ? Uri.decodeComponent(segments.first) : '',
      rootPath:
          segments.length > 1 ? segments.skip(1).map(Uri.decodeComponent).join('/') : '',
    );
  }

  // --- ping ---------------------------------------------------------------

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    try {
      final s = _parseServer(server);
      await smbPing(
        host: s.host,
        port: s.port,
        share: s.share,
        user: server.username ?? '',
        pass: _password(server),
      );
      return true;
    } catch (e) {
      AppLog.instance.add('SMB ping failed: $e');
      return false;
    }
  }

  // --- Cover art + stream -------------------------------------------------

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    final path = utf8.decode(base64Decode(marker));
    final s = _parseServer(server);
    return await smbReadFile(
      host: s.host,
      port: s.port,
      share: s.share,
      path: path,
      user: server.username ?? '',
      pass: _password(server),
    );
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

    final s = _parseServer(server);
    final destPath =
        await _cache.pathFor(server.id, remoteId, extension: extension);
    await for (final p in smbDownloadFile(
      host: s.host,
      port: s.port,
      share: s.share,
      path: remoteId,
      user: server.username ?? '',
      pass: _password(server),
      destPath: destPath,
    )) {
      if (onProgress != null && p.total.toInt() > 0) {
        onProgress(p.received.toInt() / p.total.toInt());
      }
    }
    return destPath;
  }

  @override
  Future<({String url, Map<String, String> headers})?> streamDescriptor(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
  }) async => null;

  // --- Library walk -------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final s = _parseServer(server);
    final user = server.username ?? '';
    final pass = _password(server);

    // Collect file entries grouped by parent directory (for per-folder
    // cover/audio classification), yielding progress as the walk streams in.
    final byDir = <String, List<SmbEntry>>{};
    var totalEntries = 0;
    await for (final entry in smbListShare(
      host: s.host,
      port: s.port,
      share: s.share,
      user: user,
      pass: pass,
      rootPath: s.rootPath,
    )) {
      totalEntries++;
      if (!entry.isDir) {
        final parent = _parentDir(entry.path);
        (byDir[parent] ??= <SmbEntry>[]).add(entry);
      }
      if (totalEntries % 500 == 0) {
        yield ScanProgress(
          songsFound: 0,
          totalFiles: totalEntries,
          filesProcessed: totalEntries,
          phase: 'Syncing ${server.label}',
          currentFile: entry.name,
        );
      }
    }

    final syncedRemoteIds = <String>{};
    var songsFound = 0;
    for (final dirPath in byDir.keys) {
      final entries = byDir[dirPath]!;
      String? coverPath;
      final songEntries = <SmbEntry>[];
      for (final e in entries) {
        if (_isCoverName(e.name)) {
          coverPath ??= e.path;
        } else if (_isAudio(e.name)) {
          songEntries.add(e);
        }
      }
      if (songEntries.isEmpty) continue;

      final album = _lastPathSegment(dirPath);
      final artist = _grandparentSegment(dirPath);
      final entities = songEntries
          .map((e) => _songEntity(
                server: server,
                entry: e,
                remoteId: e.path,
                album: album,
                artist: artist,
                coverPath: coverPath,
              ))
          .toList();
      await _repo.upsertSongs(entities);
      syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));
      songsFound += entities.length;
    }

    await purgeAndStampNetworkSync(server, syncedRemoteIds);

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: totalEntries,
      filesProcessed: totalEntries,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  SongEntity _songEntity({
    required NetworkServerEntity server,
    required SmbEntry entry,
    required String remoteId,
    required String album,
    required String artist,
    required String? coverPath,
  }) {
    final fileName = entry.name;
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot + 1).toLowerCase() : null;
    return SongEntity()
      ..filePath = '${NetworkProtocol.smb}://${server.id}/$remoteId'
      ..title = baseName.replaceAll(RegExp(r'^\d+[.\-\s]+'), '')
      ..artist = artist
      ..album = album.isEmpty ? null : album
      ..fileSize = entry.size.toInt()
      ..fileType = ext
      ..albumArtPath = coverPath != null
          ? '$coverScheme${base64Encode(utf8.encode(coverPath))}'
          : null
      ..sourceType = NetworkProtocol.smb
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }

  String _parentDir(String path) {
    final slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(0, slash) : '';
  }

  bool _isAudio(String name) {
    final ext = _extension(name);
    return ext != null && _audioExtensions.contains(ext);
  }

  bool _isCoverName(String name) {
    final ext = _extension(name);
    if (ext == null || !_imageExtensions.contains(ext)) return false;
    final dot = name.lastIndexOf('.');
    final stem =
        dot > 0 ? name.substring(0, dot).toLowerCase() : name.toLowerCase();
    return _coverNames.any((c) => stem == c || stem.startsWith('$c.'));
  }

  String? _extension(String name) {
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
    final slash = p.lastIndexOf('/');
    if (slash <= 0) return 'Unknown';
    final parent = p.substring(0, slash);
    final artist = _lastPathSegment(parent);
    return artist.isEmpty ? 'Unknown' : artist;
  }
}
