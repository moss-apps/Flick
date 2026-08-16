import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/app_log.dart';
import '../data/database.dart';
import '../data/repositories/song_repository.dart';
import '../models/song.dart';
import '../src/rust/api/audio_api.dart' as rust_audio;
import 'sources/network_source_service.dart';

/// Bridges playback/download for network-sourced songs.
///
/// A cache hit returns the local file path immediately (gapless/crossfade
/// handoff reads a local file); a miss downloads the original-quality stream
/// into [NetworkCacheService] via the protocol service registered for the
/// song's `sourceType`.
class RemoteSourceService {
  RemoteSourceService._();

  static RemoteSourceService instance = RemoteSourceService._();

  @visibleForTesting
  static RemoteSourceService create() => RemoteSourceService._();

  /// Progress (0..1) of the interactive playback download, null when idle.
  final ValueNotifier<double?> downloadProgressNotifier = ValueNotifier(null);

  /// Songs whose format probe failed (e.g. AAC-in-M4A Symphonia gap);
  /// skip retrying them every play.
  final Set<String> _probeFailed = {};

  Future<NetworkServerEntity> _serverFor(Song song) async {
    final serverId = song.remoteServerId;
    if (serverId == null) {
      throw StateError('Network song has no remote server id');
    }
    final server = await Database.networkServers.get(serverId);
    if (server == null) {
      throw StateError('Network server $serverId not found');
    }
    return server;
  }

  /// Ensure a playable local copy of [song] exists and return its path.
  /// Downloads (with progress on [downloadProgressNotifier]) when uncached.
  Future<String> ensureLocal(Song song, {bool reportProgress = true}) async {
    if (!song.isNetworkSource) {
      throw StateError('Song is not a network source');
    }
    final sourceType = song.sourceType;
    if (sourceType == null) {
      throw StateError('Network song has no source type');
    }
    final server = await _serverFor(song);
    final remoteId = song.remoteId;
    if (remoteId == null) {
      throw StateError('Network song has no remote id');
    }
    final service = networkSourceServiceFor(sourceType);
    try {
      final path = await service.stream(
        server,
        remoteId,
        extension: song.fileType,
        onProgress: reportProgress
            ? (p) => downloadProgressNotifier.value = p
            : null,
      );
      unawaited(_backfillAudioFormat(song, path));
      return path;
    } finally {
      if (reportProgress) downloadProgressNotifier.value = null;
    }
  }

  /// ponytail: probe-once backfill for sources whose sync can't read tags
  /// (SMB/WebDAV listing has no sampleRate/bitDepth). Runs after the file is
  /// local either way; HTTP-direct streams skip it. Full tag read at sync time
  /// is the upgrade path if users want quality labels before first play.
  Future<void> _backfillAudioFormat(Song song, String localPath) async {
    if (song.sampleRate != null || song.bitDepth != null) return;
    if (_probeFailed.contains(song.id)) return;
    try {
      final probed = await rust_audio.audioProbeFormat(path: localPath);
      await SongRepository().updateAudioFormat(
        song.filePath!,
        sampleRate: probed.sampleRate,
        bitDepth: probed.bitsPerSample,
      );
    } catch (e) {
      _probeFailed.add(song.id);
      AppLog.instance.add('Format backfill failed for "${song.title}": $e');
    }
  }

  /// Resolve a direct ranged HTTP stream for [song] when the protocol supports
  /// byte-range requests. Returns null when unsupported (UPnP/SMB) or on
  /// resolve failure — callers fall back to cache-then-play via [ensureLocal].
  Future<({String url, Map<String, String> headers})?> resolveHttpPlayback(
    Song song,
  ) async {
    if (!song.isNetworkSource) return null;
    final sourceType = song.sourceType;
    final remoteId = song.remoteId;
    if (sourceType == null || remoteId == null) return null;
    try {
      final server = await _serverFor(song);
      final service = networkSourceServiceFor(sourceType);
      return await service.streamDescriptor(
        server,
        remoteId,
        extension: song.fileType,
      );
    } catch (e) {
      AppLog.instance.add('HTTP stream resolve failed for "${song.title}": $e');
      return null;
    }
  }

  /// Background prefetch for the next queue entry. Best effort: never throws,
  /// does not touch [downloadProgressNotifier] (interactive downloads own it).
  Future<void> prefetch(Song song) async {
    try {
      await ensureLocal(song, reportProgress: false);
    } catch (e) {
      AppLog.instance.add('Prefetch failed for "${song.title}": $e');
    }
  }
}
