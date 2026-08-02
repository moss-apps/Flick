import 'package:flutter/foundation.dart';

import '../core/utils/app_log.dart';
import '../data/database.dart';
import '../models/song.dart';
import 'sources/subsonic_service.dart';

/// Bridges playback/download for network-sourced songs.
///
/// v1 supports Subsonic only: a cache hit returns the local file path
/// immediately (gapless/crossfade handoff reads a local file), a miss
/// downloads the original-quality stream into [NetworkCacheService].
class RemoteSourceService {
  RemoteSourceService._({SubsonicService? subsonic})
      : _subsonic = subsonic ?? SubsonicService.instance;

  static RemoteSourceService instance = RemoteSourceService._();

  /// Test seam: build an isolated instance with mocked dependencies.
  @visibleForTesting
  static RemoteSourceService create({SubsonicService? subsonic}) {
    return RemoteSourceService._(subsonic: subsonic);
  }

  final SubsonicService _subsonic;

  /// Progress (0..1) of the interactive playback download, null when idle.
  final ValueNotifier<double?> downloadProgressNotifier = ValueNotifier(null);

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
    final server = await _serverFor(song);
    final remoteId = song.remoteId;
    if (remoteId == null) {
      throw StateError('Network song has no remote id');
    }
    switch (song.sourceType) {
      case 'subsonic':
        try {
          return await _subsonic.stream(
            server,
            remoteId,
            extension: song.fileType,
            onProgress: reportProgress
                ? (p) => downloadProgressNotifier.value = p
                : null,
          );
        } finally {
          if (reportProgress) downloadProgressNotifier.value = null;
        }
      default:
        throw StateError(
            'Source type "${song.sourceType}" is not supported yet');
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
