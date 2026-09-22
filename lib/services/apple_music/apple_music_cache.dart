import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/dev_log.dart';

class _CacheEntry {
  const _CacheEntry({required this.value, required this.expiresAtMs});

  final Map<String, dynamic>? value;
  final int expiresAtMs;

  bool get isNegative => value == null;
}

/// File-backed JSON cache with per-entry TTLs, a memory layer and negative
/// caching. Deliberately avoids Isar: schema changes there can wipe the
/// library database.
class AppleMusicCache {
  AppleMusicCache._({Directory? root}) : _root = root;

  static final AppleMusicCache instance = AppleMusicCache._();

  @visibleForTesting
  static AppleMusicCache forDirectory(Directory root) =>
      AppleMusicCache._(root: root);

  final Directory? _root;
  final Map<String, _CacheEntry> _mem = {};

  /// Returns the cached value for [key], otherwise runs [loader].
  ///
  /// A `null` loader result is cached for [negativeTtl]; a thrown error for
  /// [transientTtl] so temporary failures retry soon. Successful values live
  /// for [ttl]. Transient failures are never written to disk. When [refresh]
  /// is true any cached entry is ignored and the loader always runs.
  Future<T?> fetch<T>({
    required String key,
    required Future<T?> Function() loader,
    required Map<String, dynamic> Function(T value) encode,
    required T Function(Map<String, dynamic> json) decode,
    Duration ttl = const Duration(days: 7),
    Duration negativeTtl = const Duration(hours: 2),
    Duration transientTtl = const Duration(seconds: 30),
    bool refresh = false,
  }) async {
    if (!refresh) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cached = _mem[key];
      if (cached != null && now < cached.expiresAtMs) {
        return _decode(cached, decode);
      }

      final disk = await _readDisk(key);
      if (disk != null) {
        _mem[key] = disk;
        return _decode(disk, decode);
      }
    }

    T? value;
    var transient = false;
    try {
      value = await loader();
    } catch (error) {
      devLog('[AppleMusic] "$key" failed: $error');
      transient = true;
    }

    final valueTtl = value != null
        ? ttl
        : (transient ? transientTtl : negativeTtl);
    final entry = _CacheEntry(
      value: value == null ? null : encode(value),
      expiresAtMs:
          DateTime.now().millisecondsSinceEpoch + valueTtl.inMilliseconds,
    );
    _mem[key] = entry;
    if (!transient) {
      unawaited(_writeDisk(key, entry));
    }
    return value;
  }

  T? _decode<T>(_CacheEntry entry, T Function(Map<String, dynamic>) decode) {
    final value = entry.value;
    if (value == null) return null;
    return decode(value);
  }

  Future<Directory> _cacheDir() async {
    final root = _root;
    if (root != null) {
      if (!await root.exists()) await root.create(recursive: true);
      return root;
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/apple_music');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  File _fileFor(Directory dir, String key) {
    final hash = sha1.convert(utf8.encode(key)).toString();
    return File('${dir.path}/$hash.json');
  }

  Future<_CacheEntry?> _readDisk(String key) async {
    try {
      final file = _fileFor(await _cacheDir(), key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final expiresAtMs = (decoded['expiresAtMs'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch >= expiresAtMs) {
        await file.delete();
        return null;
      }
      final value = decoded['value'];
      return _CacheEntry(
        value: value is Map<String, dynamic> ? value : null,
        expiresAtMs: expiresAtMs,
      );
    } catch (error) {
      devLog('[AppleMusic] cache read failed: $error');
      return null;
    }
  }

  Future<void> _writeDisk(String key, _CacheEntry entry) async {
    try {
      final file = _fileFor(await _cacheDir(), key);
      await file.writeAsString(
        jsonEncode({
          'expiresAtMs': entry.expiresAtMs,
          if (entry.value != null) 'value': entry.value,
        }),
        flush: true,
      );
    } catch (error) {
      devLog('[AppleMusic] cache write failed: $error');
    }
  }
}
