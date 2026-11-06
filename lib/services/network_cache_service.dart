import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bounded LRU download cache for network-sourced songs.
///
/// Layout: `<appCache>/network_cache/<serverId>/<md5(serverId:remoteId)>.<ext>`.
/// LRU by file mtime; eviction runs after each [stash] or [completeDownload] once the total exceeds
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
    final serverDir = Directory(
      p.join((await _root()).path, '$remoteServerId'),
    );
    if (!await serverDir.exists()) return null;

    final hash = _hash(remoteServerId, remoteId);
    final fileName = extension != null
        ? '$hash.$extension'
        : await _findByHash(serverDir, hash);
    if (fileName == null) return null;

    final file = File(p.join(serverDir.path, fileName));
    if (!await file.exists()) return null;

    // The file can be evicted (or removed by Android's cache manager) between
    // the existence check and the LRU touch. Treat that as a miss so callers
    // re-download instead of handing playback a path that no longer exists.
    final now = DateTime.now();
    try {
      if (file.lastModifiedSync() != now) {
        await file.setLastModified(now);
      }
    } on FileSystemException {
      return null;
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
    final serverDir = Directory(
      p.join((await _root()).path, '$remoteServerId'),
    );
    await serverDir.create(recursive: true);
    final file = File(
      p.join(
        serverDir.path,
        '${_hash(remoteServerId, remoteId)}.${extension ?? 'bin'}',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    await _evictIfOverCap(protect: file);
    return file.path;
  }

  /// Resolve (and create) the canonical cache path for a (server, song) entry
  /// without writing bytes. Lets a native downloader stream straight to disk,
  /// avoiding a full-file FFI buffer round-trip for large FLACs.
  Future<String> pathFor(
    int remoteServerId,
    String remoteId, {
    String? extension,
  }) async {
    final serverDir = Directory(
      p.join((await _root()).path, '$remoteServerId'),
    );
    await serverDir.create(recursive: true);
    return p.join(
      serverDir.path,
      '${_hash(remoteServerId, remoteId)}.${extension ?? 'bin'}',
    );
  }

  Future<String?> _findByHash(Directory serverDir, String hash) async {
    await for (final entry in serverDir.list()) {
      final name = p.basename(entry.path);
      if (entry is File &&
          !name.endsWith('.part') &&
          name.startsWith('$hash.')) {
        return name;
      }
    }
    return null;
  }

  /// Called only after the native downloader has atomically published a file.
  /// Staging files are hidden and excluded from lookup and eviction.
  Future<void> completeDownload(String path) =>
      _evictIfOverCap(protect: File(path));

  /// Drop cached copies for (server, remoteId), across all extensions. Used
  /// when a remote file changes so the next play cannot reuse stale bytes.
  /// Staging files are left alone: they belong to an in-flight downloader and
  /// are never lookup candidates.
  Future<void> remove(int remoteServerId, String remoteId) async {
    final serverDir = Directory(
      p.join((await _root()).path, '$remoteServerId'),
    );
    if (!await serverDir.exists()) return;

    final prefix = '${_hash(remoteServerId, remoteId)}.';
    await for (final entry in serverDir.list()) {
      if (entry is! File) continue;
      if (!p.basename(entry.path).startsWith(prefix)) continue;
      try {
        await entry.delete();
      } on FileSystemException {
        /* Another caller may have removed or locked it; best effort. */
      }
    }
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
        if (p.basename(entry.path).startsWith('.') ||
            entry.path.endsWith('.part')) {
          continue;
        }
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
