import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/app_preferences_service.dart';

class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  static const String _appGroup = 'group.com.mossapps.flick.widgets';

  static const String miniPlayerProvider = 'com.mossapps.flick.widgets.MiniPlayerWidgetProvider';

  static const String keySongId = 'flick_widget_song_id';
  static const String keyTitle = 'flick_widget_title';
  static const String keyArtist = 'flick_widget_artist';
  static const String keyAlbumArt = 'flick_widget_album_art';
  static const String keyIsPlaying = 'flick_widget_is_playing';
  static const String keyHasSong = 'flick_widget_has_song';

  static const String keyBgOpacity = 'flick_widget_bg_opacity';
  static const String keyShowAlbumArt = 'flick_widget_show_album_art';
  static const String keyShowArtist = 'flick_widget_show_artist';
  static const String keyAccentColor = 'flick_widget_accent_color';
  static const String keyPositionMs = 'flick_widget_position_ms';
  static const String keyDurationMs = 'flick_widget_duration_ms';
  static const String keyIsShuffle = 'flick_widget_is_shuffle';
  static const String keyLoopMode = 'flick_widget_loop_mode';
  static const String keyQueueCount = 'flick_widget_queue_count';

  bool _initialized = false;
  Timer? _debounce;
  String? _lastPushedSongId;
  bool? _lastPushedIsPlaying;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await HomeWidget.setAppGroupId(_appGroup);
  }

  void schedulePush(PlayerState state) {
    final songChanged = state.currentSong?.id != _lastPushedSongId;
    final playingChanged = state.isPlaying != _lastPushedIsPlaying;

    if (songChanged || playingChanged) {
      _debounce?.cancel();
      unawaited(_push(state));
    } else if (_debounce?.isActive != true) {
      _debounce = Timer(const Duration(seconds: 2), () {
        unawaited(_push(state));
      });
    }
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
      await HomeWidget.saveWidgetData<int>(
        keyPositionMs,
        state.position.inMilliseconds,
      );
      await HomeWidget.saveWidgetData<int>(
        keyDurationMs,
        state.duration.inMilliseconds,
      );
      await HomeWidget.saveWidgetData<bool>(keyIsShuffle, state.isShuffle);
      await HomeWidget.saveWidgetData<int>(
        keyLoopMode,
        _loopModeToInt(state.loopMode),
      );
      await HomeWidget.saveWidgetData<int>(
        keyQueueCount,
        state.upNext.length,
      );

      await Future.wait<void>([
        HomeWidget.updateWidget(
          qualifiedAndroidName: miniPlayerProvider,
        ),
      ]);

      _lastPushedSongId = song?.id;
      _lastPushedIsPlaying = state.isPlaying;
    } catch (e, st) {
      debugPrint('WidgetSyncService push failed: $e\n$st');
    }
  }

  Future<void> pushPaused() async {
    try {
      await _ensureInit();
      await HomeWidget.saveWidgetData<bool>(keyIsPlaying, false);
      await Future.wait<void>([
        HomeWidget.updateWidget(
          qualifiedAndroidName: miniPlayerProvider,
        ),
      ]);
    } catch (e, st) {
      debugPrint('WidgetSyncService pushPaused failed: $e\n$st');
    }
  }

  Future<void> pushCustomization(AppPreferences prefs) async {
    try {
      await _ensureInit();
      await HomeWidget.saveWidgetData<int>(keyBgOpacity, prefs.widgetBgOpacity);
      await HomeWidget.saveWidgetData<bool>(
        keyShowAlbumArt,
        prefs.widgetShowAlbumArt,
      );
      await HomeWidget.saveWidgetData<bool>(
        keyShowArtist,
        prefs.widgetShowArtist,
      );
      await HomeWidget.saveWidgetData<String>(
        keyAccentColor,
        prefs.widgetAccentColor,
      );

      await Future.wait<void>([
        HomeWidget.updateWidget(
          qualifiedAndroidName: miniPlayerProvider,
        ),
      ]);
    } catch (e, st) {
      debugPrint('WidgetSyncService pushCustomization failed: $e\n$st');
    }
  }

  Future<void> pushInitialCustomization() async {
    try {
      await _ensureInit();
      final prefs = await _loadPrefsFromAppPrefs();
      await pushCustomization(prefs);
    } catch (_) {}
  }

  Future<AppPreferences> _loadPrefsFromAppPrefs() async {
    try {
      final prefsService = AppPreferencesService();
      return await prefsService.getPreferences();
    } catch (_) {
      return const AppPreferences();
    }
  }

  int _loopModeToInt(LoopMode mode) {
    switch (mode) {
      case LoopMode.one:
        return 1;
      case LoopMode.all:
        return 2;
      case LoopMode.off:
        return 0;
    }
  }

  String _resolveLocalArt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return '';
    final cleaned = raw.startsWith('file://') ? raw.substring(7) : raw;
    if (!File(cleaned).existsSync()) return '';
    return cleaned;
  }
}

ProviderSubscription<PlayerState> installWidgetSync(WidgetRef ref) {
  unawaited(WidgetSyncService.instance.pushInitialCustomization());
  return ref.listenManual<PlayerState>(
    playerProvider,
    (prev, next) => WidgetSyncService.instance.schedulePush(next),
    fireImmediately: true,
  );
}
