import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../data/repositories/song_repository.dart';
import '../src/rust/api/scanner.dart' as rust_scanner;
import 'music_folder_service.dart';
import 'player_service.dart';

class AlbumArtService {
  AlbumArtService._();

  static final AlbumArtService instance = AlbumArtService._();
  static const String _storeKey = 'flickArtworkCache';
  static const Duration _cacheStalePeriod = Duration(days: 90);

  static final CacheManager _cacheManager = CacheManager(
    Config(_storeKey, stalePeriod: _cacheStalePeriod),
  );

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

    final cacheKey = _cacheKey(audioSourcePath);
    final cached = await _cacheManager.getFileFromCache(cacheKey);
    final cachedPath = cached?.file.path;
    if (await _isUsableImagePath(cachedPath)) {
      unawaited(_persistArtworkPath(audioSourcePath, cachedPath));
      return cachedPath;
    }

    final future = _inFlightResolutions.putIfAbsent(cacheKey, () async {
      final bytes = await _loadArtworkBytes(audioSourcePath);
      if (bytes == null || bytes.isEmpty) {
        await _persistArtworkPath(audioSourcePath, null);
        return null;
      }

      final extension = _detectFileExtension(bytes);
      final file = await _cacheManager.putFile(
        cacheKey,
        bytes,
        fileExtension: extension,
      );

      await _persistArtworkPath(audioSourcePath, file.path);
      return file.path;
    });

    try {
      return await future;
    } finally {
      _inFlightResolutions.remove(cacheKey);
    }
  }

  Future<int> getCacheSize() async {
    var total = 0;
    for (final dir in await _candidateCacheRoots()) {
      for (final name in const [_storeKey, 'libCachedImageData']) {
        final cacheDir = Directory('${dir.path}/$name');
        if (!await cacheDir.exists()) continue;
        try {
          await for (final entity
              in cacheDir.list(recursive: true, followLinks: false)) {
            if (entity is File) total += await entity.length();
          }
        } catch (_) {}
      }
    }
    return total;
  }

  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
    await DefaultCacheManager().emptyCache();
  }

  Future<List<Directory>> _candidateCacheRoots() async {
    final dirs = <Directory>[];
    for (final future in [
      getTemporaryDirectory(),
      getApplicationCacheDirectory(),
      getApplicationSupportDirectory(),
    ]) {
      try {
        dirs.add(await future);
      } catch (_) {}
    }
    return dirs;
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

  Future<Uint8List?> _loadArtworkBytes(String audioSourcePath) async {
    if (Platform.isAndroid && audioSourcePath.startsWith('content://')) {
      return _musicFolderService.fetchEmbeddedArtwork(audioSourcePath);
    }

    return rust_scanner.extractEmbeddedArtwork(path: audioSourcePath);
  }

  Future<void> _persistArtworkPath(
    String audioSourcePath,
    String? albumArtPath,
  ) async {
    try {
      await _songRepository.updateAlbumArtPath(audioSourcePath, albumArtPath);
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

  String _cacheKey(String audioSourcePath) {
    final digest = md5.convert(utf8.encode(audioSourcePath));
    return 'embedded-artwork:${digest.toString()}';
  }

  String _detectFileExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }

    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'bmp';
    }

    return 'jpg';
  }
}
