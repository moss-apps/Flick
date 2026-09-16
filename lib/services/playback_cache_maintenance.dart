import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'alac_converter_service.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'playback_cache_preferences_service.dart';

const MethodChannel _storageChannel = MethodChannel('com.mossapps.flick/storage');

/// One-shot cache housekeeping at app launch:
/// 1. Enforces the WAV conversion cache cap (prunes caches grown huge under
///    pre-cap releases — issue #212).
/// 2. Sweeps legacy converted WAVs abandoned in the OS temp dir root by
///    0.20.x (which wrote there with no eviction).
/// 3. Asks Android to prune the SAF playback staging dir down to the cap.
Future<void> runPlaybackCacheMaintenance() async {
  try {
    final maxBytes = await PlaybackCachePreferencesService().getMaxCacheBytes();
    await AlacConverterService.enforceCacheCap(maxBytes);
    await _sweepLegacyTempWavs();
    if (Platform.isAndroid) {
      await _storageChannel.invokeMethod<void>(
        'prunePlaybackStaging',
        {'maxBytes': maxBytes},
      );
    }
  } catch (e) {
    devLog('[cache-maintenance] failed: $e');
  }
}

/// 0.20.x wrote converted WAVs (`name_<hash>.wav`, and `name.wav` from the
/// streaming converter) straight into the temp dir root. The persistent
/// cache lives elsewhere now; anything wav-shaped in the root is garbage.
/// Subdirectories (e.g. metadata_edits) belong to other features and are
/// left alone.
Future<void> _sweepLegacyTempWavs() async {
  try {
    final temp = await getTemporaryDirectory();
    final root = Directory(temp.path);
    if (!await root.exists()) return;
    await for (final entity in root.list()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.wav')) continue;
      try {
        await entity.delete();
      } catch (_) {
        // locked or racing; next launch retries
      }
    }
  } catch (_) {
    // path_provider unavailable on this platform; nothing to sweep
  }
}
