import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/models/album_color_mode.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/album_color_mode_preference_service.dart';
import 'package:flick/services/color_extraction_service.dart';

// ============================================================================
// Album color mode preference
// ============================================================================

final albumColorModePreferenceServiceProvider =
    Provider<AlbumColorModePreferenceService>((ref) {
  return AlbumColorModePreferenceService();
});

class AlbumColorModeNotifier extends Notifier<AlbumColorMode> {
  bool _initialized = false;

  @override
  AlbumColorMode build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_loadFromPreferences);
    }
    return AlbumColorMode.vibrant;
  }

  Future<void> _loadFromPreferences() async {
    final mode =
        await ref.read(albumColorModePreferenceServiceProvider).getMode();
    if (ref.mounted && state != mode) {
      state = mode;
    }
  }

  Future<void> setMode(AlbumColorMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(albumColorModePreferenceServiceProvider).setMode(mode);
  }
}

final albumColorModeProvider =
    NotifierProvider<AlbumColorModeNotifier, AlbumColorMode>(
  AlbumColorModeNotifier.new,
);

// ============================================================================
// Dominant color extraction from current song's album art
// ============================================================================

final _colorExtractionServiceProvider = Provider<ColorExtractionService>((ref) {
  return ColorExtractionService();
});

/// Watches the current song's album art path directly.
/// Avoids `currentSongProvider` because its `select()` uses `Song.==` (by id),
/// which masks in-place album art updates from `syncAlbumArtPaths`.
final _currentAlbumArtPathProvider = Provider<String?>((ref) {
  return ref.watch(playerProvider).currentSong?.albumArt;
});

/// Extracted dominant color from the current song's album art.
/// Returns null when no album art is available.
final albumDominantColorProvider = FutureProvider.autoDispose<Color?>((
  ref,
) async {
  final albumArt = ref.watch(_currentAlbumArtPathProvider);
  final colorService = ref.watch(_colorExtractionServiceProvider);

  if (albumArt == null || albumArt.isEmpty) {
    return null;
  }

  return colorService.extractDominantColor(albumArt);
});

/// Synchronous accessor — returns the dominant color or null.
final albumDominantColorSyncProvider = Provider<Color?>((ref) {
  return ref.watch(albumDominantColorProvider).value;
});
