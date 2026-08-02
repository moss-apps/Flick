import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bounded LRU download cache for network-sourced songs.
///
/// Layout: `<appCache>/network_cache/<serverId>/<md5(serverId:remoteId)>.<ext>`.
/// LRU by file mtime; eviction runs after each [stash] once the total exceeds
/// [sizeCapBytes].
class NetworkCacheService {
  NetworkCacheService({
    this.sizeCapBytes = defaultSizeCapBytes,
    Directory? rootDirectory,
  }) : _rootDirectory = rootDirectory;

  /// Default cap: 2 GiB.
  static const defaultSizeCapBytes = 2 * 1024 * 1024 * 1024;

  static const _dirName = 'network_cache';

  final int sizeCapBytes;

  /// Test seam; when null, resolves the platform app cache directory.
  final Directory? _rootDirectory;

  Future<Directory> _root() async {
    if (_rootDirectory != null) return _rootDirectory;
    final cacheDir = await getApplicationCacheDirectory();
    final root = Directory(p.join(cacheDir.path, _dirName));
    await root.create(recursive: true);
    return root;
  }

  static String _hash(int remoteServerId, String remoteId) =>
      md5.convert(utf8.encode('$remoteServerId:$remoteId')).toString();

  /// Path of the cached file for (server, song), or null if not cached.
  /// Touches the file's mtime to keep it warm in the LRU order.
  Future<String?> getPath(
    int remoteServerId,
    String remoteId, {
    String? extension,
  }) async {
    final serverDir = Directory(p.join((await _root()).path, '$remoteServerId'));
    if (!await serverDir.exists()) return null;

    final hash = _hash(remoteServerId, remoteId);
    final fileName = extension != null
        ? '$hash.$extension'
        : await _findByHash(serverDir, hash);
    if (fileName == null) return null;

    final file = File(p.join(serverDir.path, fileName));
    if (!await file.exists()) return null;

    final now = DateTime.now();
    if (file.lastModifiedSync() != now) {
      await file.setLastModified(now);
    }
    return file.path;
  }

  /// Write [bytes] to the cache and evict oldest entries if over the cap.
  /// Returns the cached file path.
  Future<String> stash(
    int remoteServerId,
    String remoteId,
    List<int> bytes, {
    String? extension,
  }) async {
    final serverDir = Directory(p.join((await _root()).path, '$remoteServerId'));
    await serverDir.create(recursive: true);
    final file = File(
      p.join(serverDir.path, '${_hash(remoteServerId, remoteId)}.${extension ?? 'bin'}'),
    );
    await file.writeAsBytes(bytes, flush: true);
    await _evictIfOverCap(protect: file);
    return file.path;
  }

  Future<String?> _findByHash(Directory serverDir, String hash) async {
    await for (final entry in serverDir.list()) {
      final name = p.basename(entry.path);
      if (name.startsWith('$hash.')) return name;
    }
    return null;
  }

  // ponytail: full O(n) size scan per eviction; track running totals only
  // if a server with a huge cache ever shows up on profile.
  Future<void> _evictIfOverCap({File? protect}) async {
    final root = await _root();
    final files = <File>[];
    var total = 0;
    await for (final serverDir in root.list()) {
      if (serverDir is! Directory) continue;
      await for (final entry in serverDir.list()) {
        if (entry is! File) continue;
        files.add(entry);
        total += await entry.length();
      }
    }
    if (total <= sizeCapBytes) return;

    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in files) {
      if (total <= sizeCapBytes) break;
      if (file.path == protect?.path) continue;
      final length = await file.length();
      await file.delete();
      total -= length;
    }
  }
}
