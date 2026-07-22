import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/app_preferences_service.dart';
import 'package:flick/core/utils/dev_log.dart';

class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  static const String _appGroup = 'group.com.mossapps.flick.widgets';

  static const String miniPlayerProvider = 'com.mossapps.flick.widgets.MiniPlayerWidgetProvider';
  static const String flagshipProvider = 'com.mossapps.flick.widgets.FlagshipWidgetProvider';
  static const String compactProvider = 'com.mossapps.flick.widgets.CompactWidgetProvider';

  static const String keyFlagshipAccent = 'flick_widget_flagship_accent';
  static const String keyFlagshipShowArtist = 'flick_widget_flagship_show_artist';
  static const String keyCompactBgOpacity = 'flick_widget_compact_bg_opacity';
  static const String keyCompactShowAlbumArt = 'flick_widget_compact_show_album_art';
  static const String keyCompactShowArtist = 'flick_widget_compact_show_artist';
  static const String keyCompactAccent = 'flick_widget_compact_accent';
  static const String keyMiniTextScale = 'flick_widget_text_scale';
  static const String keyFlagshipTextScale = 'flick_widget_flagship_text_scale';
  static const String keyCompactTextScale = 'flick_widget_compact_text_scale';

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
  bool? _lastPushedIsShuffle;
  int? _lastPushedLoopMode;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await HomeWidget.setAppGroupId(_appGroup);
  }

  Future<void> _updateAll() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: miniPlayerProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: flagshipProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: compactProvider);
  }

  void schedulePush(PlayerState state) {
    final songChanged = state.currentSong?.id != _lastPushedSongId;
    final playingChanged = state.isPlaying != _lastPushedIsPlaying;
    final shuffleChanged = state.isShuffle != _lastPushedIsShuffle;
    final loopChanged = state.loopMode.index != _lastPushedLoopMode;

    if (songChanged || playingChanged || shuffleChanged || loopChanged) {
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

      await _updateAll();

      _lastPushedSongId = song?.id;
      _lastPushedIsPlaying = state.isPlaying;
      _lastPushedIsShuffle = state.isShuffle;
      _lastPushedLoopMode = state.loopMode.index;
    } catch (e, st) {
      devLog('WidgetSyncService push failed: $e\n$st');
    }
  }

  Future<void> pushPaused() async {
    try {
      await _ensureInit();
      await HomeWidget.saveWidgetData<bool>(keyIsPlaying, false);
      await _updateAll();
    } catch (e, st) {
      devLog('WidgetSyncService pushPaused failed: $e\n$st');
    }
  }

  Future<void> pushKilled() async {
    try {
      await _ensureInit();
      await HomeWidget.saveWidgetData<bool>(keyIsPlaying, false);
      await _updateAll();
    } catch (e, st) {
      devLog('WidgetSyncService pushKilled failed: $e\n$st');
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
      await HomeWidget.saveWidgetData<double>(
        keyMiniTextScale,
        prefs.widgetTextScale,
      );

      // Flagship widget customization
      await HomeWidget.saveWidgetData<String>(
        keyFlagshipAccent,
        prefs.widgetFlagshipAccent,
      );
      await HomeWidget.saveWidgetData<bool>(
        keyFlagshipShowArtist,
        prefs.widgetFlagshipShowArtist,
      );
      await HomeWidget.saveWidgetData<double>(
        keyFlagshipTextScale,
        prefs.widgetFlagshipTextScale,
      );

      // Compact widget customization
      await HomeWidget.saveWidgetData<int>(
        keyCompactBgOpacity,
        prefs.widgetCompactBgOpacity,
      );
      await HomeWidget.saveWidgetData<bool>(
        keyCompactShowAlbumArt,
        prefs.widgetCompactShowAlbumArt,
      );
      await HomeWidget.saveWidgetData<bool>(
        keyCompactShowArtist,
        prefs.widgetCompactShowArtist,
      );
      await HomeWidget.saveWidgetData<String>(
        keyCompactAccent,
        prefs.widgetCompactAccent,
      );
      await HomeWidget.saveWidgetData<double>(
        keyCompactTextScale,
        prefs.widgetCompactTextScale,
      );

      await _updateAll();
    } catch (e, st) {
      devLog('WidgetSyncService pushCustomization failed: $e\n$st');
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
      case LoopMode.off:
        return 0;
      case LoopMode.one:
        return 1;
      case LoopMode.all:
        return 2;
      case LoopMode.advanceAlbum:
        return 3;
      case LoopMode.advanceArtist:
        return 4;
      case LoopMode.advanceFolder:
        return 5;
      case LoopMode.advancePlaylist:
        return 6;
      case LoopMode.stopAfterCurrent:
        return 7;
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
