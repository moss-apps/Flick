import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../src/rust/api/alac_converter_api.dart' as alac_api;
import 'package:flick/core/utils/dev_log.dart';

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

  static Future<Directory> _wavCacheDir() async {
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
          return;
        }
      }
      _manifest = {};
    } catch (_) {
      _manifest = {};
    }
  }

  static Future<void> _persistManifest() async {
    final manifest = _manifest;
    if (manifest == null) return;
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

  /// Returns the persisted WAV path for [sourcePath] if a valid converted copy
  /// already exists on disk, otherwise null.
  // ponytail: validity keyed on source byte size only. A replaced source with
  // identical size would reuse a stale WAV; add content hashing if that bites.
  // Uncompressed WAVs are ~10x the source; no eviction yet, add LRU if the dir
  // grows too large.
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
      return entry.wavPath;
    } catch (_) {
      return null;
    }
  }

  /// Convert a supported source file to WAV and save to the persistent cache.
  ///
  /// Returns the path to the converted WAV file. Reuses an existing cached
  /// copy when valid, so repeated launches skip re-conversion.
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
    );
    await _persistManifest();
    return wavPath;
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

  _WavCacheEntry({required this.wavPath, required this.sourceSize});

  Map<String, dynamic> toJson() => {'wavPath': wavPath, 'sourceSize': sourceSize};

  factory _WavCacheEntry.fromJson(Map<String, dynamic> json) => _WavCacheEntry(
        wavPath: json['wavPath'] as String,
        sourceSize: json['sourceSize'] as int,
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
