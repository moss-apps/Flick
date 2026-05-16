import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';

/// Service responsible for keeping Android home-screen widgets in sync with
/// the current player state.
///
/// Three widgets are supported:
///   * Mini player    – shows current song + transport controls.
///   * Now-playing    – shows the queue currently playing, tap to jump.
///   * Library        – shortcut grid to sections of the app.
///
/// The bridge is implemented via the `home_widget` package, which writes data
/// to a shared `SharedPreferences` group readable by the Android widget
/// providers (see `android/app/src/main/kotlin/com/mossapps/flick/widgets/`).
class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  /// Android app group / iOS group identifier (Android ignores it but we set
  /// it to keep parity if iOS support is added later).
  static const String _appGroup = 'group.com.mossapps.flick.widgets';

  // Names of the three AppWidgetProvider classes on the Android side.
  static const String miniPlayerProvider = 'MiniPlayerWidgetProvider';
  static const String nowPlayingProvider = 'NowPlayingWidgetProvider';
  static const String libraryProvider = 'LibraryWidgetProvider';

  // Keys written to SharedPreferences (read by the Kotlin side).
  static const String keySongId = 'flick_widget_song_id';
  static const String keyTitle = 'flick_widget_title';
  static const String keyArtist = 'flick_widget_artist';
  static const String keyAlbumArt = 'flick_widget_album_art';
  static const String keyIsPlaying = 'flick_widget_is_playing';
  static const String keyHasSong = 'flick_widget_has_song';
  static const String keyQueueJson = 'flick_widget_queue_json';
  static const String keyCurrentIndex = 'flick_widget_current_index';

  bool _initialized = false;
  Timer? _debounce;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await HomeWidget.setAppGroupId(_appGroup);
  }

  /// Push the latest [PlayerState] to all relevant widgets.
  /// Debounced to avoid hammering the platform on rapid updates (e.g. seek).
  void schedulePush(PlayerState state) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      // Fire-and-forget; widget update failures must never crash the app.
      unawaited(_push(state));
    });
  }

  Future<void> _push(PlayerState state) async {
    try {
      await _ensureInit();
      final Song? song = state.currentSong;
      await HomeWidget.saveWidgetData<bool>(keyHasSong, song != null);
      await HomeWidget.saveWidgetData<bool>(keyIsPlaying, state.isPlaying);
      await HomeWidget.saveWidgetData<String>(keySongId, song?.id ?? '');
      await HomeWidget.saveWidgetData<String>(keyTitle, song?.title ?? '');
      await HomeWidget.saveWidgetData<String>(keyArtist, song?.artist ?? '');
      await HomeWidget.saveWidgetData<String>(
        keyAlbumArt,
        _resolveLocalArt(song?.albumArt),
      );
      await HomeWidget.saveWidgetData<int>(keyCurrentIndex, state.currentIndex);
      await HomeWidget.saveWidgetData<String>(
        keyQueueJson,
        _encodeQueue(state.queue),
      );

      // Trigger redraws on all three widgets.
      await Future.wait<void>([
        HomeWidget.updateWidget(
          name: miniPlayerProvider,
          androidName: miniPlayerProvider,
        ),
        HomeWidget.updateWidget(
          name: nowPlayingProvider,
          androidName: nowPlayingProvider,
        ),
        HomeWidget.updateWidget(
          name: libraryProvider,
          androidName: libraryProvider,
        ),
      ]);
    } catch (e, st) {
      debugPrint('WidgetSyncService push failed: $e\n$st');
    }
  }

  /// Only local filesystem paths can be loaded by Android RemoteViews via
  /// `BitmapFactory.decodeFile`. Drop network URLs – the widget will fall back
  /// to the default art placeholder.
  String _resolveLocalArt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return '';
    // Strip any `file://` prefix.
    final cleaned = raw.startsWith('file://') ? raw.substring(7) : raw;
    if (!File(cleaned).existsSync()) return '';
    return cleaned;
  }

  String _encodeQueue(List<Song> queue) {
    // Compact CSV-style encoding keeps payload small (widgets aren't allowed
    // big SharedPreferences entries on some launchers). One song per line:
    //   id\u0001title\u0001artist\u0001albumArtPath
    final sb = StringBuffer();
    final maxItems = queue.length > 50 ? 50 : queue.length;
    for (var i = 0; i < maxItems; i++) {
      final s = queue[i];
      if (i > 0) sb.write('\n');
      sb
        ..write(_sanitize(s.id))
        ..write('\u0001')
        ..write(_sanitize(s.title))
        ..write('\u0001')
        ..write(_sanitize(s.artist))
        ..write('\u0001')
        ..write(_sanitize(_resolveLocalArt(s.albumArt)));
    }
    return sb.toString();
  }

  String _sanitize(String s) => s.replaceAll('\u0001', ' ').replaceAll('\n', ' ');
}

/// Bootstraps the widget sync: listens to [playerProvider] and pushes
/// every state change to the home widgets. Returns the manual subscription so
/// the caller can dispose it when its widget is removed.
ProviderSubscription<PlayerState> installWidgetSync(WidgetRef ref) {
  return ref.listenManual<PlayerState>(
    playerProvider,
    (prev, next) => WidgetSyncService.instance.schedulePush(next),
    fireImmediately: true,
  );
}
