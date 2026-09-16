import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../src/rust/api/alac_converter_api.dart' as alac_api;
import 'package:flick/core/utils/dev_log.dart';
import 'playback_cache_preferences_service.dart';

/// Service for converting ALAC/M4A/AIFF files to WAV/PCM format
///
/// This service provides both one-shot and streaming conversion modes:
/// - One-shot: Convert entire file to WAV in memory (for small files)
/// - Streaming: Decode chunks progressively (for large files)
class AlacConverterService {
  static final Map<String, bool> _wavConversionSupportCache = {};

  // --- persistent WAV cache (survives app restarts) ---
  static const _cacheDirName = 'wav_cache';
  static const _manifestName = 'manifest.json';
  static Map<String, _WavCacheEntry>? _manifest;
  static bool _manifestLoaded = false;
  static String? _cacheRootOverride;
  static final PlaybackCachePreferencesService _prefs =
      PlaybackCachePreferencesService();
  // Manifest rewrites on cache hits are throttled; entry bookkeeping still
  // updates in memory so eviction order stays correct between writes.
  static DateTime? _lastManifestPersist;
  static const _manifestPersistThrottle = Duration(minutes: 5);

  /// Tests point the cache at a throwaway directory.
  @visibleForTesting
  static void setCacheRootForTesting(String? path) {
    _cacheRootOverride = path;
    resetForTesting();
  }

  /// Clears in-memory cache state; tests call between cases.
  @visibleForTesting
  static void resetForTesting() {
    _manifest = null;
    _manifestLoaded = false;
    _lastManifestPersist = null;
  }

  static Future<Directory> _wavCacheDir() async {
    final override = _cacheRootOverride;
    if (override != null) {
      final dir = Directory(override);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/$_cacheDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _ensureManifest() async {
    if (_manifestLoaded) return;
    _manifestLoaded = true;
    try {
      final dir = await _wavCacheDir();
      final file = File('${dir.path}/$_manifestName');
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, dynamic>) {
          _manifest = raw.map(
            (k, v) => MapEntry(k, _WavCacheEntry.fromJson(v as Map<String, dynamic>)),
          );
          await _backfillLastUsedFromDisk();
          return;
        }
      }
      _manifest = {};
    } catch (_) {
      _manifest = {};
    }
  }

  /// Manifests written before LRU tracking existed carry lastUsedAt = 0.
  /// Recover real usage order from file mtimes once at load.
  static Future<void> _backfillLastUsedFromDisk() async {
    final manifest = _manifest;
    if (manifest == null) return;
    for (final entry in manifest.entries) {
      if (entry.value.lastUsedAt > 0) continue;
      try {
        final mtime = await File(entry.value.wavPath).lastModified();
        manifest[entry.key] = _WavCacheEntry(
          wavPath: entry.value.wavPath,
          sourceSize: entry.value.sourceSize,
          lastUsedAt: mtime.millisecondsSinceEpoch,
        );
      } catch (_) {
        // Missing file: entry gets evicted on the next cap pass anyway.
      }
    }
  }

  static Future<void> _persistManifest() async {
    final manifest = _manifest;
    if (manifest == null) return;
    _lastManifestPersist = DateTime.now();
    try {
      final dir = await _wavCacheDir();
      final file = File('${dir.path}/$_manifestName');
      await file.writeAsString(
        jsonEncode(manifest.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {
      // best-effort; in-session cache still works
    }
  }

  static Future<void> _persistManifestThrottled() async {
    final last = _lastManifestPersist;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _manifestPersistThrottle) {
      return;
    }
    await _persistManifest();
  }

  /// Returns the persisted WAV path for [sourcePath] if a valid converted copy
  /// already exists on disk, otherwise null.
  // ponytail: validity keyed on source byte size only. A replaced source with
  // identical size would reuse a stale WAV; add content hashing if that bites.
  static Future<String?> tryGetCachedWav(String sourcePath) async {
    await _ensureManifest();
    final entry = _manifest?[sourcePath];
    if (entry == null) return null;
    try {
      final srcFile = File(sourcePath);
      if (!await srcFile.exists()) return null;
      if (await srcFile.length() != entry.sourceSize) return null;
      final wavFile = File(entry.wavPath);
      if (!await wavFile.exists()) return null;
      _manifest![sourcePath] = _WavCacheEntry(
        wavPath: entry.wavPath,
        sourceSize: entry.sourceSize,
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _persistManifestThrottled();
      return entry.wavPath;
    } catch (_) {
      return null;
    }
  }

  /// Convert a supported source file to WAV and save to the persistent cache.
  ///
  /// Returns the path to the converted WAV file. Reuses an existing cached
  /// copy when valid, so repeated launches skip re-conversion. After a fresh
  /// conversion the cache cap is enforced (LRU eviction; the new file is
  /// never the one evicted).
  static Future<String> convertToWavFile(String sourcePath) async {
    final cached = await tryGetCachedWav(sourcePath);
    if (cached != null) return cached;

    final dir = await _wavCacheDir();
    final wavPath = await _convertToWavFile(
      sourcePath: sourcePath,
      cacheDirPath: dir.path,
    );

    _manifest ??= {};
    _manifest![sourcePath] = _WavCacheEntry(
      wavPath: wavPath,
      sourceSize: await File(sourcePath).length(),
      lastUsedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistManifest();
    final cap = await _prefs.getMaxCacheBytes();
    await enforceCacheCap(cap, protectPath: wavPath);
    return wavPath;
  }

  /// Evicts least-recently-used cached WAVs until the cache is at or under
  /// [maxBytes]. Values <= 0 mean unlimited (no-op). [protectPath] is never
  /// deleted — used for the file that triggered enforcement. Also drops
  /// manifest rows whose files vanished and orphans on disk the manifest
  /// doesn't know about.
  static Future<void> enforceCacheCap(
    int maxBytes, {
    String? protectPath,
  }) async {
    if (maxBytes <= 0) return;
    await _ensureManifest();
    final manifest = _manifest;
    if (manifest == null) return;

    var total = 0;
    final liveEntries = <MapEntry<String, _WavCacheEntry>>[];
    for (final entry in manifest.entries.toList()) {
      final file = File(entry.value.wavPath);
      final length = await file.exists() ? await file.length() : -1;
      if (length < 0) {
        manifest.remove(entry.key);
        continue;
      }
      liveEntries.add(entry);
      total += length;
    }

    if (total > maxBytes) {
      liveEntries.sort(
        (a, b) => a.value.lastUsedAt.compareTo(b.value.lastUsedAt),
      );
      for (final entry in liveEntries) {
        if (total <= maxBytes) break;
        if (entry.value.wavPath == protectPath) continue;
        try {
          final file = File(entry.value.wavPath);
          final length = await file.length();
          await file.delete();
          total -= length;
        } catch (_) {
          continue;
        }
        manifest.remove(entry.key);
      }
    }

    await _deleteOrphanedWavFiles();
    await _persistManifest();
  }

  /// Deletes files in the cache dir the manifest doesn't reference (crash
  /// leftovers); the manifest itself is kept.
  static Future<void> _deleteOrphanedWavFiles() async {
    try {
      final dir = await _wavCacheDir();
      final referenced = _manifest?.values.map((e) => e.wavPath).toSet() ?? {};
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (entity.path.endsWith(_manifestName)) continue;
        if (referenced.contains(entity.path)) continue;
        await entity.delete();
      }
    } catch (_) {
      // best-effort
    }
  }

  /// Total size of cached WAV files on disk (excludes the manifest).
  static Future<int> getCacheSize() async {
    try {
      final dir = await _wavCacheDir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (entity.path.endsWith(_manifestName)) continue;
        try {
          total += await entity.length();
        } catch (_) {
          // raced with eviction
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes every cached WAV and resets the manifest.
  static Future<void> clearCache() async {
    await _ensureManifest();
    try {
      final dir = await _wavCacheDir();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {
              // possibly held open by playback; skip
            }
          }
        }
      }
    } catch (_) {
      // best-effort
    }
    _manifest = {};
    await _persistManifest();
  }

  static Future<String> _convertToWavFile({
    required String sourcePath,
    required String cacheDirPath,
  }) async {
    final sourceFile = File(sourcePath);
    final fileBytes = await sourceFile.readAsBytes();

    final wavBytes = alac_api.alacConvertToWav(fileBytes: fileBytes);
    if (wavBytes.isEmpty) {
      throw StateError('Rust converter returned empty WAV data');
    }

    final sourceName = sourcePath.split('/').last;
    final baseName = sourceName.replaceAll(
      RegExp(r'\.(alac|m4a|aiff|aif)$', caseSensitive: false),
      '',
    );
    final wavPath = '$cacheDirPath/${baseName}_${sourcePath.hashCode.abs()}.wav';
    final wavFile = File(wavPath);
    await wavFile.writeAsBytes(wavBytes);

    return wavPath;
  }

  /// Probe a supported file's metadata without converting.
  static Future<alac_api.AlacAudioMetadata> probeMetadata(
    String filePath,
  ) async {
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();
    return alac_api.alacProbeMetadata(fileBytes: fileBytes);
  }

  /// Quietly check whether the Rust converter can decode this source.
  ///
  /// This avoids repeatedly attempting conversions for files that the
  /// converter doesn't actually support.
  static Future<bool> canConvertToWavFile(String filePath) async {
    final cached = _wavConversionSupportCache[filePath];
    if (cached != null) {
      return cached;
    }

    try {
      await probeMetadata(filePath);
      _wavConversionSupportCache[filePath] = true;
      return true;
    } catch (e) {
      devLog('[WAV-conv] Symphonia probe FAILED for $filePath: $e');
      _wavConversionSupportCache[filePath] = false;
      return false;
    }
  }

  /// Check if a file is ALAC or M4A format
  static bool isAlacOrM4a(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return extension == 'alac' || extension == 'm4a';
  }

  /// Check if a file is AIFF format.
  static bool isAiff(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return extension == 'aiff' || extension == 'aif';
  }

  /// Check if a file should be converted to WAV before playback.
  static bool requiresWavConversion(String filePath) {
    return isAlacOrM4a(filePath) || isAiff(filePath);
  }
}

class _WavCacheEntry {
  final String wavPath;
  final int sourceSize;

  /// Epoch ms of the last cache hit/conversion; drives LRU eviction.
  /// Zero for manifests predating LRU (backfilled from file mtime on load).
  final int lastUsedAt;

  _WavCacheEntry({
    required this.wavPath,
    required this.sourceSize,
    this.lastUsedAt = 0,
  });

  Map<String, dynamic> toJson() => {
        'wavPath': wavPath,
        'sourceSize': sourceSize,
        'lastUsedAt': lastUsedAt,
      };

  factory _WavCacheEntry.fromJson(Map<String, dynamic> json) => _WavCacheEntry(
        wavPath: json['wavPath'] as String,
        sourceSize: json['sourceSize'] as int,
        lastUsedAt: (json['lastUsedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Streaming ALAC converter for large files
///
/// Usage:
/// ```dart
/// final converter = StreamingAlacConverter();
/// await converter.open(filePath);
/// final stream = converter.streamPcm();
/// await for (final chunk in stream) {
///   // Process PCM chunk
/// }
/// await converter.close();
/// ```
class StreamingAlacConverter {
  BigInt? _sessionId;
  alac_api.AlacAudioMetadata? _metadata;

  /// Open a file for streaming conversion
  Future<void> open(String filePath) async {
    final file = File(filePath);
    final fileBytes = await file.readAsBytes();

    _sessionId = alac_api.alacCreateSession(fileBytes: fileBytes);
    _metadata = alac_api.alacGetMetadata(sessionId: _sessionId!);
  }

  /// Get audio metadata
  alac_api.AlacAudioMetadata? get metadata => _metadata;

  /// Get WAV header bytes
  Future<Uint8List> getWavHeader() async {
    if (_sessionId == null) {
      throw StateError('Session not opened');
    }
    return alac_api.alacGetWavHeader(sessionId: _sessionId!);
  }

  /// Stream PCM chunks
  Stream<Uint8List> streamPcm() async* {
    if (_sessionId == null) {
      throw StateError('Session not opened');
    }

    while (true) {
      final chunk = alac_api.alacDecodeNextChunk(sessionId: _sessionId!);
      if (chunk == null) {
        break;
      }
      yield chunk;
    }
  }

  /// Seek to a specific time position
  Future<void> seek(double timeSeconds) async {
    if (_sessionId == null) {
      throw StateError('Session not opened');
    }
    alac_api.alacSeek(sessionId: _sessionId!, timeSeconds: timeSeconds);
  }

  /// Close the conversion session
  Future<void> close() async {
    if (_sessionId != null) {
      alac_api.alacCloseSession(sessionId: _sessionId!);
      _sessionId = null;
      _metadata = null;
    }
  }

  /// Convert to WAV file using streaming (memory efficient)
  Future<String> convertToWavFile(String sourcePath) async {
    await open(sourcePath);

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = sourcePath
          .split('/')
          .last
          .replaceAll(
            RegExp(r'\.(alac|m4a|aiff|aif)$', caseSensitive: false),
            '.wav',
          );
      final wavPath = '${tempDir.path}/$fileName';
      final wavFile = File(wavPath);

      // Write WAV header
      final header = await getWavHeader();
      await wavFile.writeAsBytes(header, mode: FileMode.write);

      // Stream and append PCM data
      await for (final chunk in streamPcm()) {
        await wavFile.writeAsBytes(chunk, mode: FileMode.append);
      }

      return wavPath;
    } finally {
      await close();
    }
  }
}

/// Custom audio source for just_audio that converts supported files on-the-fly.
///
/// This allows playing formats like ALAC/M4A/AIFF through just_audio by
/// converting them to WAV format transparently.
class AlacAudioSource {
  final String sourcePath;
  String? _convertedPath;

  AlacAudioSource(this.sourcePath);

  /// Get the playable audio path (converts if needed)
  Future<String> getPlayablePath() async {
    if (_convertedPath != null) {
      return _convertedPath!;
    }

    if (AlacConverterService.requiresWavConversion(sourcePath)) {
      _convertedPath = await AlacConverterService.convertToWavFile(sourcePath);
      return _convertedPath!;
    }

    return sourcePath;
  }

  /// Clean up converted file
  Future<void> dispose() async {
    if (_convertedPath != null) {
      try {
        final file = File(_convertedPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        devLog('Failed to delete converted file: $e');
      }
      _convertedPath = null;
    }
  }
}
