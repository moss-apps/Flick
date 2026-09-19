import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/services/playback_cache_preferences_service.dart';
import '../src/rust/api/alac_converter_api.dart' as alac_api;

/// Serves a local audio file to just_audio without materialising a WAV file.
///
/// ALAC/M4A/AIFF tracks are decoded by the Rust engine on demand and exposed
/// to just_audio's local proxy as a virtual WAV stream, so a 1,500 track queue
/// no longer converts every song up front (issue #212). Sources the Rust
/// decoder cannot handle (e.g. AAC-in-M4A) are streamed straight from disk,
/// which ExoPlayer plays natively.
///
/// Only usable on non-web platforms, where just_audio's proxy turns
/// [request]s into ranged HTTP responses.
// ignore: experimental_member_use
class WavStreamAudioSource extends just_audio.StreamAudioSource {
  WavStreamAudioSource({
    required this.filePath,
    this.durationHint,
    this.extensionHint,
    this.startOffset,
    this.endOffset,
    super.tag,
  });

  /// Absolute path or Android `content://` URI.
  final String filePath;

  /// Scanned duration, used when the decode probe reports no frame count.
  final Duration? durationHint;

  /// Extension for staging hints and raw fallback MIME detection.
  final String? extensionHint;

  /// Optional clip window, mirroring `ClippingAudioSource`.
  final Duration? startOffset;
  final Duration? endOffset;

  static const _wavMimeType = 'audio/wav';
  static const _mimeTypes = {
    'm4a': 'audio/mp4',
    'mp4': 'audio/mp4',
    'alac': 'audio/mp4',
    'aac': 'audio/aac',
    'aiff': 'audio/aiff',
    'aif': 'audio/aiff',
    'aifc': 'audio/aiff',
    'flac': 'audio/flac',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'opus': 'audio/opus',
  };

  // 256 KiB of PCM per FFI read keeps single decode bursts short enough that
  // the UI isolate stays responsive without hammering FFI per packet.
  static const _readChunkBytes = 256 * 1024;

  static final _WavSessionPool _sessions = _WavSessionPool();
  static final MusicFolderService _folderService = MusicFolderService();
  static final PlaybackCachePreferencesService _cachePrefs =
      PlaybackCachePreferencesService();

  String? _resolvedPath;
  Future<String?>? _resolving;

  @override
  // ignore: experimental_member_use
  Future<just_audio.StreamAudioResponse> request([int? start, int? end]) async {
    final path = await _ensureLocalPath();
    if (path == null || path.isEmpty) {
      throw StateError('Unable to stage playback source: $filePath');
    }

    final session = _tryOpenWavSession(path);
    if (session != null) {
      return _wavResponse(session, start, end);
    }
    return _rawResponse(path, start, end);
  }

  Future<String?> _ensureLocalPath() async {
    final resolved = _resolvedPath;
    if (resolved != null) return resolved;

    final pending = _resolving ??= _resolveLocalPath();
    try {
      final path = await pending;
      if (path != null && path.isNotEmpty) {
        _resolvedPath = path;
        return path;
      }
      _resolving = null;
      return null;
    } catch (_) {
      _resolving = null;
      rethrow;
    }
  }

  Future<String?> _resolveLocalPath() async {
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(filePath)) {
      return filePath;
    }

    final parsed = Uri.tryParse(filePath);
    if (parsed == null || parsed.scheme.isEmpty) {
      return filePath;
    }
    if (parsed.scheme == 'file') {
      return parsed.toFilePath();
    }
    if (parsed.scheme != 'content') {
      return null;
    }

    return _folderService.cacheUriForPlayback(
      filePath,
      extensionHint: extensionHint,
      maxStagingBytes: await _cachePrefs.getMaxCacheBytes(),
    );
  }

  _WavSession? _tryOpenWavSession(String path) {
    try {
      return _sessions.acquire(
        path,
        durationHint: durationHint,
        startOffset: startOffset,
        endOffset: endOffset,
      );
    } catch (e) {
      devLog('[WavStream] decode unavailable for $path: $e');
      return null;
    }
  }

  // ignore: experimental_member_use
  just_audio.StreamAudioResponse _wavResponse(
    _WavSession session,
    int? start,
    int? end,
  ) {
    final layout = session.layout;
    final range = layout.resolveRange(start, end);
    // ignore: experimental_member_use
    return just_audio.StreamAudioResponse(
      sourceLength: layout.totalLength,
      contentLength: range.length,
      offset: range.offset,
      contentType: _wavMimeType,
      stream: _streamWav(session, range.offset, range.length),
    );
  }

  Stream<List<int>> _streamWav(_WavSession session, int offset, int length) async* {
    final layout = session.layout;
    try {
      var position = offset;
      final end = offset + length;

      if (position < layout.dataOffset && position < end) {
        final headerEnd = math.min(end, layout.dataOffset);
        yield Uint8List.sublistView(layout.header, position, headerEnd);
        position = headerEnd;
      }

      final framesPerChunk = math.max(1, _readChunkBytes ~/ layout.blockAlign);
      while (position < end) {
        final frameStart = layout.frameAtOffset(position);
        final bytesIntoFrame = position - layout.offsetOfFrame(frameStart);
        final framesNeeded = ((end - position) / layout.blockAlign).ceil();
        final bytes = alac_api.alacReadPcm(
          sessionId: session.id,
          startFrame: BigInt.from(frameStart),
          frameCount: BigInt.from(math.min(framesNeeded, framesPerChunk)),
        );

        if (bytes.isEmpty) {
          // Probe under-reported the frame count (duration hint fallback):
          // pad with silence so the HTTP response still matches contentLength.
          while (position < end) {
            final pad = math.min(_readChunkBytes, end - position);
            yield Uint8List(pad);
            position += pad;
            await Future<void>.delayed(Duration.zero);
          }
          break;
        }

        final from = bytesIntoFrame;
        final to = math.min(bytes.length, bytesIntoFrame + (end - position));
        if (to <= from) break;

        yield Uint8List.sublistView(bytes, from, to);
        position += to - from;
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _sessions.release(session);
    }
  }

  // ignore: experimental_member_use
  Future<just_audio.StreamAudioResponse> _rawResponse(
    String path,
    int? start,
    int? end,
  ) async {
    final file = File(path);
    final total = await file.length();
    final range = VirtualWavLayout.resolveRangeOf(start, end, total);
    // ignore: experimental_member_use
    return just_audio.StreamAudioResponse(
      sourceLength: total,
      contentLength: range.length,
      offset: range.offset,
      contentType: _mimeTypeFor(path),
      stream: _streamRaw(file, range.offset, range.length),
    );
  }

  Stream<List<int>> _streamRaw(File file, int offset, int length) async* {
    final handle = await file.open();
    try {
      await handle.setPosition(offset);
      var remaining = length;
      final buffer = Uint8List(_readChunkBytes);
      while (remaining > 0) {
        final read = await handle.readInto(
          buffer,
          0,
          math.min(buffer.length, remaining),
        );
        if (read <= 0) break;
        yield Uint8List.fromList(Uint8List.sublistView(buffer, 0, read));
        remaining -= read;
      }
    } finally {
      await handle.close();
    }
  }

  String _mimeTypeFor(String path) {
    final ext = extensionHint?.toLowerCase().trim();
    final resolved = ext != null && ext.isNotEmpty
        ? ext
        : path.split('.').last.toLowerCase();
    return _mimeTypes[resolved] ?? 'application/octet-stream';
  }
}

/// A decoded session plus the virtual WAV layout it feeds.
class _WavSession {
  _WavSession({required this.key, required this.id, required this.layout});

  /// Path plus clip window; sessions are only reused for identical layouts.
  final String key;
  final BigInt id;
  final VirtualWavLayout layout;
  int lastUsed = 0;
}

/// Keeps a couple of decoders warm so seeking within a track reuses the same
/// Rust session instead of re-probing the file on every range request.
class _WavSessionPool {
  static const _maxIdle = 2;

  final List<_WavSession> _idle = [];
  var _tick = 0;

  _WavSession acquire(
    String path, {
    Duration? durationHint,
    Duration? startOffset,
    Duration? endOffset,
  }) {
    final key = '$path|${startOffset?.inMicroseconds}|${endOffset?.inMicroseconds}';
    final index = _idle.indexWhere((session) => session.key == key);
    if (index >= 0) {
      final session = _idle.removeAt(index);
      session.lastUsed = _tick++;
      return session;
    }

    final id = alac_api.alacCreateSessionFromPath(path: path);
    try {
      final layout = _buildLayout(
        id,
        durationHint: durationHint,
        startOffset: startOffset,
        endOffset: endOffset,
      );
      return _WavSession(key: key, id: id, layout: layout);
    } catch (_) {
      _close(id);
      rethrow;
    }
  }

  void release(_WavSession session) {
    session.lastUsed = _tick++;
    _idle.add(session);
    while (_idle.length > _maxIdle) {
      final oldest = _idle.reduce(
        (a, b) => a.lastUsed <= b.lastUsed ? a : b,
      );
      _idle.remove(oldest);
      _close(oldest.id);
    }
  }

  void _close(BigInt sessionId) {
    try {
      alac_api.alacCloseSession(sessionId: sessionId);
    } catch (_) {}
  }

  static VirtualWavLayout _buildLayout(
    BigInt sessionId, {
    Duration? durationHint,
    Duration? startOffset,
    Duration? endOffset,
  }) {
    final metadata = alac_api.alacGetMetadata(sessionId: sessionId);
    final blockAlign = math.max(1, metadata.channels * (metadata.bitDepth ~/ 8));
    final sampleRate = metadata.sampleRate;

    var totalFrames = metadata.durationSamples.toInt();
    if (totalFrames <= 0 &&
        durationHint != null &&
        durationHint > Duration.zero) {
      totalFrames = (durationHint.inMilliseconds * sampleRate / 1000).round();
    }
    if (totalFrames <= 0) {
      throw StateError('Unknown duration for session');
    }

    var startFrame = _frameFor(startOffset, sampleRate);
    var endFrame = endOffset == null
        ? totalFrames
        : _frameFor(endOffset, sampleRate);
    startFrame = startFrame.clamp(0, totalFrames);
    endFrame = endFrame.clamp(startFrame, totalFrames);
    if (endFrame <= startFrame) {
      throw StateError('Empty clip window for session');
    }

    return VirtualWavLayout(
      header: Uint8List.fromList(
        alac_api.alacGetWavHeader(sessionId: sessionId),
      ),
      blockAlign: blockAlign,
      totalFrames: endFrame - startFrame,
      startFrame: startFrame,
    );
  }

  static int _frameFor(Duration? offset, int sampleRate) {
    if (offset == null || offset <= Duration.zero) return 0;
    return (offset.inMicroseconds * sampleRate / 1000000).round();
  }
}

/// Byte layout of the virtual WAV served over HTTP. Pure math so range
/// handling is unit-testable without loading the Rust library.
@visibleForTesting
class VirtualWavLayout {
  VirtualWavLayout({
    required Uint8List header,
    required this.blockAlign,
    required this.totalFrames,
    this.startFrame = 0,
  }) : header = _withDataLength(header, totalFrames * blockAlign);

  final Uint8List header;
  final int blockAlign;

  /// Number of frames in the served window.
  final int totalFrames;

  /// Absolute frame index the window starts at.
  final int startFrame;

  int get dataOffset => header.length;
  int get dataLength => totalFrames * blockAlign;
  int get totalLength => dataOffset + dataLength;

  int frameAtOffset(int offset) => startFrame +
      ((offset - dataOffset) ~/ blockAlign).clamp(0, totalFrames);

  int offsetOfFrame(int frame) =>
      dataOffset + (frame - startFrame) * blockAlign;

  ({int offset, int length}) resolveRange(int? start, int? end) =>
      resolveRangeOf(start, end, totalLength);

  static ({int offset, int length}) resolveRangeOf(
    int? start,
    int? end,
    int totalLength,
  ) {
    final offset = (start ?? 0).clamp(0, totalLength);
    final endOffset = (end ?? totalLength).clamp(offset, totalLength);
    return (offset: offset, length: endOffset - offset);
  }

  static Uint8List _withDataLength(Uint8List header, int dataLength) {
    if (header.length < 44) return header;
    final patched = Uint8List.fromList(header);
    final view = ByteData.sublistView(patched);
    view.setUint32(4, 36 + dataLength, Endian.little);
    view.setUint32(40, dataLength, Endian.little);
    return patched;
  }
}
