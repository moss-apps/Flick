import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../data/repositories/song_repository.dart';
import '../src/rust/api/scanner.dart' as rust_scanner;
import 'music_folder_service.dart';
import 'player_service.dart';
import 'sources/network_source_service.dart';

class AlbumArtService {
  AlbumArtService._();

  static final AlbumArtService instance = AlbumArtService._();

  // ponytail: artwork lives in the app *support* dir (durable) instead of
  // flutter_cache_manager's cache dir (OS-evictable). A DB pointer at a file
  // the OS had evicted was the root cause of art vanishing on reopen. 30-day
  // age + 500-entry cap bound storage; the tail re-extracts on demand once
  // pruned, so storage stays bounded without reintroducing the stale-pointer
  // bug for the common (recently played) set.
  static const Duration _artworkStalePeriod = Duration(days: 30);
  static const int _artworkMaxEntries = 500;
  static const Duration _pruneInterval = Duration(hours: 6);

  Directory? _artworkDir;
  DateTime _lastPrune = DateTime.fromMillisecondsSinceEpoch(0);

  final SongRepository _songRepository = SongRepository();
  final MusicFolderService _musicFolderService = MusicFolderService();
  final Map<String, Future<String?>> _inFlightResolutions = {};

  Future<String?> resolveArtworkPath({
    String? existingPath,
    required String audioSourcePath,
  }) async {
    if (audioSourcePath.isEmpty) {
      return null;
    }

    if (await _isUsableImagePath(existingPath)) {
      return existingPath;
    }

    final future = _inFlightResolutions.putIfAbsent(audioSourcePath, () async {
      final raw = await _loadArtworkBytes(audioSourcePath,
          existingPath: existingPath);
      if (raw == null || raw.isEmpty) {
        await _persistArtworkPath(audioSourcePath, null);
        return null;
      }

      // Extension is irrelevant: Flutter's image decoder sniffs magic bytes,
      // so keying the file on the content hash alone keeps lookup O(1) with
      // no glob and no raw-vs-normalized format mismatch.
      final cacheKey = _cacheKey(raw);
      final dir = await _ensureArtworkDir();
      final cachedFile = File('${dir.path}/$cacheKey');
      if (await _isUsableImagePath(cachedFile.path)) {
        unawaited(_persistArtworkPath(audioSourcePath, cachedFile.path));
        unawaited(_pruneIfNeeded(dir));
        return cachedFile.path;
      }

      final bytes = await _normalizeArtworkBytes(raw);
      await cachedFile.writeAsBytes(bytes, flush: true);

      await _persistArtworkPath(audioSourcePath, cachedFile.path);
      unawaited(_pruneIfNeeded(dir));
      return cachedFile.path;
    });

    try {
      return await future;
    } finally {
      _inFlightResolutions.remove(audioSourcePath);
    }
  }

  Future<int> getCacheSize() async {
    final dir = await _ensureArtworkDir();
    var total = 0;
    try {
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) total += await entity.length();
      }
    } catch (_) {}
    return total;
  }

  Future<void> clearCache() async {
    final dir = await _ensureArtworkDir();
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }

  Future<Directory> _ensureArtworkDir() async {
    final cached = _artworkDir;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final artwork = Directory('${support.path}/artwork');
    if (!await artwork.exists()) {
      await artwork.create(recursive: true);
    }
    _artworkDir = artwork;
    return artwork;
  }

  // ponytail: throttled best-effort prune — newest _artworkMaxEntries survive,
  // anything older than _artworkStalePeriod goes regardless. Pruned entries
  // re-extract on next access via the normal self-heal path, so this only
  // bounds storage, never loses art permanently.
  Future<void> _pruneIfNeeded(Directory dir) async {
    final now = DateTime.now();
    if (now.difference(_lastPrune) < _pruneInterval) return;
    _lastPrune = now;

    try {
      final files = <({File file, DateTime modified})>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        files.add((file: entity, modified: stat.modified));
      }
      files.sort((a, b) => b.modified.compareTo(a.modified));

      final staleCut = now.subtract(_artworkStalePeriod);
      for (var i = 0; i < files.length; i++) {
        final beyondCap = i >= _artworkMaxEntries;
        final isStale = files[i].modified.isBefore(staleCut);
        if (beyondCap || isStale) {
          try {
            await files[i].file.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<bool> _isUsableImagePath(String? path) async {
    if (path == null || path.isEmpty) {
      return false;
    }

    if (path.startsWith('http')) {
      return true;
    }

    return File(path).exists();
  }

  /// Fetch raw artwork bytes. Network songs resolve through their protocol
  /// service's cover endpoint using the `<proto>-cover://<marker>` stored in
  /// the entity's albumArtPath; local songs extract embedded art as before.
  Future<Uint8List?> _loadArtworkBytes(
    String audioSourcePath, {
    String? existingPath,
  }) async {
    final uri = Uri.tryParse(audioSourcePath);
    if (uri != null && isSupportedNetworkProtocol(uri.scheme)) {
      final service = networkSourceServiceFor(uri.scheme);
      final marker = existingPath != null &&
              existingPath.startsWith(service.coverScheme)
          ? existingPath.substring(service.coverScheme.length)
          : null;
      if (marker == null || marker.isEmpty) return null;

      final serverId = int.tryParse(uri.host);
      if (serverId == null) return null;
      final server = await Database.networkServers.get(serverId);
      if (server == null) return null;

      try {
        final bytes = await service.getCoverArt(server, marker);
        return Uint8List.fromList(bytes);
      } catch (e) {
        return null;
      }
    }

    if (Platform.isAndroid && audioSourcePath.startsWith('content://')) {
      return _musicFolderService.fetchEmbeddedArtwork(audioSourcePath);
    }

    return rust_scanner.extractEmbeddedArtwork(path: audioSourcePath);
  }

  Future<Uint8List> _normalizeArtworkBytes(Uint8List raw) {
    return compute(_normalizeArtworkIsolate, raw);
  }

  Future<void> _persistArtworkPath(
    String audioSourcePath,
    String? albumArtPath,
  ) async {
    try {
      // Network songs keep their cover-art marker in the DB so a cache
      // eviction can always re-resolve; only the in-memory playlist is
      // updated with the resolved local path.
      final isNetwork =
          isSupportedNetworkProtocol(Uri.tryParse(audioSourcePath)?.scheme);
      if (!isNetwork) {
        await _songRepository.updateAlbumArtPath(audioSourcePath, albumArtPath);
      }
      if (albumArtPath != null) {
        PlayerService().syncAlbumArtPaths(
          filePaths: [audioSourcePath],
          albumArtPath: albumArtPath,
        );
      }
    } catch (_) {
      // Best-effort cache persistence should not break rendering.
    }
  }

  String _cacheKey(Uint8List bytes) {
    final digest = md5.convert(bytes);
    return 'embedded-artwork:${digest.toString()}';
  }
}

const int _artworkMaxDimension = 1000;
const int _artworkPassthroughBytes = 512 * 1024;
const int _artworkJpegQuality = 85;

Uint8List _normalizeArtworkIsolate(Uint8List raw) {
  if (raw.length < _artworkPassthroughBytes) {
    return raw;
  }

  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    return raw;
  }

  final img.Image target;
  if (decoded.width >= decoded.height) {
    target = decoded.width > _artworkMaxDimension
        ? img.copyResize(decoded, width: _artworkMaxDimension)
        : decoded;
  } else {
    target = decoded.height > _artworkMaxDimension
        ? img.copyResize(decoded, height: _artworkMaxDimension)
        : decoded;
  }

  return Uint8List.fromList(
    img.encodeJpg(target, quality: _artworkJpegQuality),
  );
}
