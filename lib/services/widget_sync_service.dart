import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../data/repositories/recently_played_repository.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../services/app_preferences_service.dart';
import 'widget_replay_snapshot.dart';
import 'package:flick/core/utils/dev_log.dart';

class WidgetSyncService {
  WidgetSyncService({
    RecentlyPlayedRepository Function()? replayRepository,
    DateTime Function()? clock,
  }) : _replayRepositoryFactory = replayRepository ?? RecentlyPlayedRepository.new,
       _clock = clock ?? DateTime.now;
  static final WidgetSyncService instance = WidgetSyncService();

  final RecentlyPlayedRepository Function() _replayRepositoryFactory;
  final DateTime Function() _clock;
  RecentlyPlayedRepository? _replayRepository;

  static const String _appGroup = 'group.com.mossapps.flick.widgets';

  static const String miniPlayerProvider = 'com.mossapps.flick.widgets.MiniPlayerWidgetProvider';
  static const String flagshipProvider = 'com.mossapps.flick.widgets.FlagshipWidgetProvider';
  static const String compactProvider = 'com.mossapps.flick.widgets.CompactWidgetProvider';
  static const String nowPlayingProvider = 'com.mossapps.flick.widgets.NowPlayingWidgetProvider';
  static const String replayProvider = 'com.mossapps.flick.widgets.ReplayWidgetProvider';

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
  static const String keyNext1Id = 'flick_widget_next_1_id';
  static const String keyNext1Title = 'flick_widget_next_1_title';
  static const String keyNext1Art = 'flick_widget_next_1_art';
  static const String keyNext2Id = 'flick_widget_next_2_id';
  static const String keyNext2Title = 'flick_widget_next_2_title';
  static const String keyNext2Art = 'flick_widget_next_2_art';

  static const String keyReplayLook = 'flick_widget_replay_look';
  static const String keyReplayDay = 'flick_widget_replay_day';
  static const String keyReplayTimeMs = 'flick_widget_replay_time_ms';
  static const String keyReplayPlays = 'flick_widget_replay_plays';
  static const String keyReplayTimeDelta = 'flick_widget_replay_time_delta';
  static const String keyReplayPlaysDelta = 'flick_widget_replay_plays_delta';
  static const String keyReplayCover1 = 'flick_widget_replay_cover_1';
  static const String keyReplayCover2 = 'flick_widget_replay_cover_2';
  static const String keyReplayCover3 = 'flick_widget_replay_cover_3';

  bool _initialized = false;
  Timer? _debounce;
  Future<void>? _playbackPush;
  PlayerState? _pendingPlayback;
  String? _lastPushedSongId;
  bool? _lastPushedIsPlaying;
  bool? _lastPushedIsShuffle;
  int? _lastPushedLoopMode;
  List<String> _lastPushedUpcoming = const [];
  List<String> _lastPreviewData = const [];
  bool _hasPushedReplay = false;
  String? _replayDayAtPush;
  List<Object?> _lastReplayData = const [];
  StreamSubscription<void>? _replayHistorySubscription;
  Timer? _replayDebounce;
  Timer? _replayDayTimer;
  bool _replayWatching = false;
  Future<bool>? _replayRefresh;
  bool _replayRefreshAgain = false;

  /// History is recorded after the listening threshold, not at song selection.
  /// Observe the committed history so repeat plays and clearing it also refresh.
  void startReplaySync() {
    if (_replayWatching) return;
    _replayWatching = true;
    _watchReplayHistory();
    _scheduleReplayDayRefresh();
  }

  void _watchReplayHistory() {
    if (!_replayWatching || _replayHistorySubscription != null) return;
    try {
      _replayRepository ??= _replayRepositoryFactory();
      _replayHistorySubscription = _replayRepository!.watchHistory().listen(
        (_) {
          _replayDebounce?.cancel();
          _replayDebounce = Timer(const Duration(milliseconds: 200), () {
            unawaited(refreshReplay());
          });
        },
        onError: (Object error) {
          devLog('WidgetSyncService replay history watch failed: $error');
        },
      );
    } catch (e) {
      // Startup can precede the database; the next successful push retries.
      devLog('WidgetSyncService replay history watch unavailable: $e');
    }
  }

  void _scheduleReplayDayRefresh() {
    _replayDayTimer?.cancel();
    if (!_replayWatching) return;
    final now = _clock();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _replayDayTimer = Timer(midnight.difference(now), () {
      unawaited(refreshReplay());
      _scheduleReplayDayRefresh();
    });
  }

  void stopReplaySync() {
    _replayWatching = false;
    _replayDebounce?.cancel();
    _replayDayTimer?.cancel();
    _debounce?.cancel();
    final subscription = _replayHistorySubscription;
    _replayHistorySubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// Refresh only Replay for history/day changes; ordinary progress pushes
  /// don't query the library or republish an unchanged statistics snapshot.
  Future<void> refreshReplay() async {
    try {
      await _ensureInit();
      if (await _pushReplaySnapshot(_clock())) {
        await HomeWidget.updateWidget(qualifiedAndroidName: replayProvider);
      }
    } catch (e, st) {
      devLog('WidgetSyncService replay refresh failed: $e\n$st');
    }
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await HomeWidget.setAppGroupId(_appGroup);
  }

  Future<void> _updateAll() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: miniPlayerProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: flagshipProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: compactProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: nowPlayingProvider);
    await HomeWidget.updateWidget(qualifiedAndroidName: replayProvider);
  }

  void schedulePush(PlayerState state) {
    final songChanged = state.currentSong?.id != _lastPushedSongId;
    final playingChanged = state.isPlaying != _lastPushedIsPlaying;
    final shuffleChanged = state.isShuffle != _lastPushedIsShuffle;
    final loopChanged = state.loopMode.index != _lastPushedLoopMode;
    final upcomingChanged = !listEquals(
      _upcomingSnapshot(state),
      _lastPushedUpcoming,
    );

    if (songChanged ||
        playingChanged ||
        shuffleChanged ||
        loopChanged ||
        upcomingChanged) {
      _debounce?.cancel();
      unawaited(_enqueuePlayback(state));
    } else if (_debounce?.isActive != true) {
      _debounce = Timer(const Duration(seconds: 2), () {
        unawaited(_enqueuePlayback(state));
      });
    }
  }

  Future<void> refreshPlayback(PlayerState state) {
    _debounce?.cancel();
    return _enqueuePlayback(state);
  }

  Future<void> _enqueuePlayback(PlayerState state) {
    _pendingPlayback = state;
    return _playbackPush ??= _drainPlayback();
  }

  Future<void> _drainPlayback() async {
    try {
      // A skip can arrive while the platform is writing another track's data.
      var pending = _pendingPlayback;
      while (pending != null) {
        _pendingPlayback = null;
        await _push(pending);
        pending = _pendingPlayback;
      }
    } finally {
      _playbackPush = null;
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
      final upcoming = _upcomingSnapshot(state);
      final previewData = _upcomingSnapshot(state, resolveArt: true);
      if (!listEquals(previewData, _lastPreviewData)) {
        const keys = [
          keyNext1Id,
          keyNext1Title,
          keyNext1Art,
          keyNext2Id,
          keyNext2Title,
          keyNext2Art,
        ];
        for (var index = 0; index < keys.length; index++) {
          await HomeWidget.saveWidgetData<String>(
            keys[index],
            previewData[index],
          );
        }
      }

      final now = _clock();
      final replayDue =
          !_hasPushedReplay ||
          song?.id != _lastPushedSongId ||
          _replayDayAtPush != WidgetReplaySnapshot.dayKey(now);
      if (replayDue) {
        await _pushReplaySnapshot(now);
      }

      await _updateAll();

      _lastPushedSongId = song?.id;
      _lastPushedIsPlaying = state.isPlaying;
      _lastPushedIsShuffle = state.isShuffle;
      _lastPushedLoopMode = state.loopMode.index;
      _lastPushedUpcoming = upcoming;
      _lastPreviewData = previewData;
    } catch (e, st) {
      devLog('WidgetSyncService push failed: $e\n$st');
    }
  }

  /// Refresh the Flick Replay statistics snapshot. Skips writing and keeps
  /// the retry flag set when the database is unavailable so the next push
  /// tries again instead of publishing misleading zeros.
  Future<bool> _pushReplaySnapshot(DateTime now) async {
    final active = _replayRefresh;
    if (active != null) {
      _replayRefreshAgain = true;
      return active;
    }
    final work = _refreshReplayUntilCurrent(now);
    _replayRefresh = work;
    try {
      return await work;
    } finally {
      _replayRefresh = null;
    }
  }

  Future<bool> _refreshReplayUntilCurrent(DateTime now) async {
    var changed = false;
    do {
      _replayRefreshAgain = false;
      changed = await _writeReplaySnapshot(now) || changed;
      now = _clock();
    } while (_replayRefreshAgain);
    return changed;
  }

  Future<bool> _writeReplaySnapshot(DateTime now) async {
    final dayKey = WidgetReplaySnapshot.dayKey(now);
    var timeMs = 0;
    var plays = 0;
    var timeDelta = WidgetReplaySnapshot.unknownDelta;
    var playsDelta = WidgetReplaySnapshot.unknownDelta;
    final covers = <String>['', '', ''];
    try {
      final repository = _replayRepository ??= _replayRepositoryFactory();
      _watchReplayHistory();
      final today = await repository.getListeningRecap(
        ListeningRecapPeriod.daily,
        now: now,
      );
      final yesterday = await repository.getListeningRecap(
        ListeningRecapPeriod.daily,
        // Calendar days, not 24 hours: DST can make yesterday shorter/longer.
        now: DateTime(now.year, now.month, now.day - 1),
      );
      timeMs = today.totalListeningTime.inMilliseconds;
      plays = today.totalPlays;
      timeDelta = WidgetReplaySnapshot.deltaPercent(
        current: timeMs,
        previous: yesterday.totalListeningTime.inMilliseconds,
      );
      playsDelta = WidgetReplaySnapshot.deltaPercent(
        current: plays,
        previous: yesterday.totalPlays,
      );
      final albums = today.topAlbums.take(3).toList();
      for (var index = 0; index < covers.length; index++) {
        if (index < albums.length) {
          covers[index] = WidgetReplaySnapshot.localCover(
            albums[index].representativeSong.albumArt,
          );
        }
      }
    } catch (e, st) {
      devLog('WidgetSyncService replay snapshot failed: $e\n$st');
      return false;
    }

    final snapshot = <Object?>[
      dayKey,
      timeMs,
      plays,
      timeDelta,
      playsDelta,
      covers[0],
      covers[1],
      covers[2],
    ];
    final changed = !listEquals(snapshot, _lastReplayData);
    if (changed) {
      const coverKeys = [keyReplayCover1, keyReplayCover2, keyReplayCover3];
      // Invalidate the old snapshot before writing, and publish its day last.
      // A native refresh mid-write must not mix yesterday's covers with today.
      await HomeWidget.saveWidgetData<String>(keyReplayDay, '');
      await HomeWidget.saveWidgetData<int>(keyReplayTimeMs, timeMs);
      await HomeWidget.saveWidgetData<int>(keyReplayPlays, plays);
      await HomeWidget.saveWidgetData<int>(keyReplayTimeDelta, timeDelta);
      await HomeWidget.saveWidgetData<int>(keyReplayPlaysDelta, playsDelta);
      for (var index = 0; index < coverKeys.length; index++) {
        await HomeWidget.saveWidgetData<String>(
          coverKeys[index],
          covers[index],
        );
      }
      await HomeWidget.saveWidgetData<String>(keyReplayDay, dayKey);
    }
    _lastReplayData = snapshot;
    _replayDayAtPush = dayKey;
    _hasPushedReplay = true;
    return changed;
  }

  Future<void> pushPaused({required bool isPlaying}) async {
    try {
      await _ensureInit();
      await HomeWidget.saveWidgetData<bool>(keyIsPlaying, isPlaying);
      await _pushReplaySnapshot(_clock());
      await _updateAll();
    } catch (e, st) {
      devLog('WidgetSyncService pushPaused failed: $e\n$st');
    }
  }

  Future<void> pushKilled() async {
    try {
      await _ensureInit();
      await HomeWidget.saveWidgetData<bool>(keyIsPlaying, false);
      await _pushReplaySnapshot(_clock());
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

      // Replay widget customization
      await HomeWidget.saveWidgetData<String>(
        keyReplayLook,
        prefs.widgetReplayLook,
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

  List<String> _upcomingSnapshot(PlayerState state, {bool resolveArt = false}) {
    final songs = state.currentSong == null ? const <Song>[] : state.upNext;
    return [
      for (var index = 0; index < 2; index++) ...[
        if (index < songs.length) songs[index].id else '',
        if (index < songs.length) songs[index].title else '',
        if (index < songs.length)
          resolveArt
              ? _resolveLocalArt(songs[index].albumArt)
              : songs[index].albumArt ?? ''
        else
          '',
      ],
    ];
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
  WidgetSyncService.instance.startReplaySync();
  unawaited(WidgetSyncService.instance.pushInitialCustomization());
  return ref.listenManual<PlayerState>(
    playerProvider,
    (prev, next) => WidgetSyncService.instance.schedulePush(next),
    fireImmediately: true,
  );
}
