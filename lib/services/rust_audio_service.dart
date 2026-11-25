import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flick/src/rust/api/audio_api.dart' as rust_audio;
import 'package:flick/src/rust/audio/engine.dart' show AudioApiPreference;
import 'package:flick/src/rust/audio/source.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Playback state enum matching the Rust engine states.
enum RustPlaybackState {
  idle,
  playing,
  paused,
  buffering,
  crossfading,
  stopped,
}

/// Service that wraps the Rust audio engine API.
///
/// This provides a clean Dart interface for the native Rust audio engine
/// which supports gapless playback and crossfade.
class RustAudioService {
  static final RustAudioService _instance = RustAudioService._internal();

  factory RustAudioService() => _instance;

  RustAudioService._internal();

  // State notifiers for UI binding
  final ValueNotifier<RustPlaybackState> stateNotifier = ValueNotifier(
    RustPlaybackState.idle,
  );
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> bufferLevelNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> volumeNotifier = ValueNotifier(1.0);

  /// User preference, not the effective DSP setting (which may be suppressed).
  final ValueNotifier<bool> crossfadeEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<double> crossfadeDurationNotifier = ValueNotifier(3.0);
  final ValueNotifier<int> crossfeedLevelNotifier = ValueNotifier(0);
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> pitchSemitonesNotifier = ValueNotifier(0.0);

  // Throttled notifier for text labels (updates slower than progress bar)
  // Prevents unnecessary rebuilds of time labels while still providing smooth progress bar
  final ValueNotifier<Duration> positionLabelNotifier = ValueNotifier(
    Duration.zero,
  );
  int _lastPositionLabelMs = 0;

  // Event callbacks
  void Function(SourceIdentity source, BigInt? nextPlaybackId)? onTrackEnded;
  void Function(SourceIdentity from, SourceIdentity to)? onCrossfadeStarted;
  void Function(SourceIdentity source)? onNextTrackReady;
  void Function(String message)? onError;

  static const _activeEventPollInterval = Duration(milliseconds: 50);
  static const _idleEventPollInterval = Duration(milliseconds: 500);

  /// Slow safety net for a dropped `stateChanged` event. Normal state updates
  /// arrive through the event poll; this only rereads the engine after no
  /// state refresh has happened for this long.
  static const _stateRefreshFallbackInterval = Duration(seconds: 2);

  Timer? _progressTimer;
  Timer? _eventPollTimer;
  Duration? _eventPollInterval;
  final Stopwatch _stateRefreshClock = Stopwatch();
  bool _initialized = false;
  bool _highResModeEnabled = false;
  BigInt? _acceptedPlaybackId;
  bool _repeatOne = false;

  /// Check if native audio engine is available on this platform.
  bool get isNativeAvailable => rust_audio.audioIsNativeAvailable();

  /// Initialize the Rust audio engine.
  /// This only boots the manager and event bridge. The heavy native engine is
  /// created lazily on first Rust playback request.
  Future<bool> init() async {
    if (_initialized) return true;

    // Check if native audio is available on this platform
    if (!rust_audio.audioIsNativeAvailable()) {
      devLog(
        'Native audio engine not available (expected on mobile platforms)',
      );
      return false;
    }

    try {
      rust_audio.audioInit();
      rust_audio.audioSetHighResMode(enabled: _highResModeEnabled);
      // Restore the persisted Android audio-API preference so the Rust engine
      // manager picks it up before the first engine init (survives app restarts).
      try {
        final pref = await Uac2PreferencesService().getAndroidAudioApi();
        rust_audio.audioSetAudioApi(preference: pref);
        devLog('Restored Android audio API preference: ${pref.name}');
      } catch (e) {
        devLog('Failed to restore Android audio API preference: $e');
      }
      // Restore DSD output mode + transport overrides before the first play;
      // this also loads the pref notifiers (else a user-set mode is ignored).
      try {
        await Uac2PreferencesService().getDsdOutputMode();
        await Uac2PreferencesService().getDsdByteOrderOverride();
        await Uac2PreferencesService().getDsdSubslotOverride();
        await Uac2PreferencesService().getDsdWireVariant();
        await Uac2PreferencesService().getDsdWireGrouping();
        _syncDsdOutputMode();
        _syncDsdTransportOverrides();
        devLog(
          'Restored DSD output mode: '
          '${Uac2PreferencesService.dsdOutputModeSync.name}',
        );
      } catch (e) {
        devLog('Failed to restore DSD output mode: $e');
      }
      _initialized = true;
      devLog('Rust audio engine manager initialized');

      // Start event polling and the slow state-refresh fallback clock.
      _stateRefreshClock
        ..reset()
        ..start();
      _startEventPolling();
      return true;
    } catch (e) {
      devLog('Failed to initialize Rust audio engine: $e');
      return false;
    }
  }

  /// Check if the engine is initialized.
  bool get isInitialized => _initialized;

  /// Whether a native engine handle currently exists. [isInitialized] only
  /// covers the Rust manager, which can be up before the first engine is
  /// prepared (or after a stop/shutdown).
  bool get hasNativeEngine {
    if (!_initialized) return false;
    try {
      return rust_audio.audioIsInitialized();
    } catch (e) {
      devLog('[RustAudio] Failed to query native engine state: $e');
      return false;
    }
  }

  /// Whether the user explicitly requested the native high-res engine path.
  bool get isHighResModeEnabled => _highResModeEnabled;

  /// The engine currently selected by the Rust-side manager.
  String get activeEngine => rust_audio.audioGetActiveEngine();

  /// Enable or disable high-res mode.
  Future<void> setHighResMode(bool enabled) async {
    _highResModeEnabled = enabled;
    rust_audio.audioSetHighResMode(enabled: enabled);
  }

  /// Stage the Android audio-API preference (Auto / AAudio / OpenSL ES) on the
  /// Rust engine manager. The next engine re-init reopens the Oboe stream with
  /// the chosen API. On non-Android targets this is a no-op.
  void setAndroidAudioApi(AudioApiPreference preference) {
    try {
      rust_audio.audioSetAudioApi(preference: preference);
      devLog('Android audio API preference set: ${preference.name}');
    } catch (e) {
      devLog('Failed to set Android audio API preference: $e');
    }
  }

  /// Detect whether a DAC is available for the requested output rate.
  Future<bool> isDacAvailable({int? preferredSampleRate}) async {
    if (!isNativeAvailable) return false;

    try {
      return await rust_audio.audioIsDacAvailable(
        preferredSampleRate: preferredSampleRate,
      );
    } catch (e) {
      devLog('Error detecting DAC availability: $e');
      return false;
    }
  }

  /// Update the current route capability hint used by the Rust engine manager.
  Future<void> setCapabilityInfo(rust_audio.AudioCapabilityInfo info) async {
    if (!isNativeAvailable) return;

    try {
      rust_audio.audioSetCapabilityInfo(info: info);
    } catch (e) {
      devLog('Error updating audio capability info: $e');
    }
  }

  /// Get the merged capability snapshot after local detection and platform hints.
  Future<rust_audio.AudioCapabilityInfo> getCapabilityInfo({
    int? preferredSampleRate,
  }) async {
    if (!isNativeAvailable) {
      return const rust_audio.AudioCapabilityInfo(
        capabilities: [rust_audio.AudioCapabilityType.standard],
        routeType: 'unknown',
        routeLabel: null,
        maxSampleRate: null,
      );
    }

    try {
      return await rust_audio.audioGetCapabilityInfo(
        preferredSampleRate: preferredSampleRate,
      );
    } catch (e) {
      devLog('Error reading audio capability info: $e');
      return const rust_audio.AudioCapabilityInfo(
        capabilities: [rust_audio.AudioCapabilityType.standard],
        routeType: 'unknown',
        routeLabel: null,
        maxSampleRate: null,
      );
    }
  }

  bool capabilityInfoPrefersRust(rust_audio.AudioCapabilityInfo info) {
    return info.capabilities.contains(rust_audio.AudioCapabilityType.usbDac) ||
        info.capabilities.contains(
          rust_audio.AudioCapabilityType.hiResInternal,
        );
  }

  /// Resolve whether the native Rust backend should be preferred for playback.
  Future<bool> shouldPreferRustEngine({int? preferredSampleRate}) async {
    final info = await getCapabilityInfo(
      preferredSampleRate: preferredSampleRate,
    );
    return capabilityInfoPrefersRust(info);
  }

  /// Ensure the native engine is fully created for the requested output rate.
  Future<void> prepareEngine({int? preferredSampleRate}) async {
    if (!_initialized) {
      throw StateError('Rust audio engine manager is not initialized');
    }

    try {
      await rust_audio.audioPrepareEngine(
        preferredSampleRate: preferredSampleRate,
      );
    } catch (e) {
      devLog('Error preparing Rust audio engine: $e');
      rethrow;
    }
  }

  /// A failed command carrying "disconnected channel" means the Rust audio
  /// thread died — it owns the command receiver, so its death breaks every
  /// subsequent send. Re-preparing forces the manager to recreate the engine
  /// (the Rust-side liveness gate refuses to reuse dead handles).
  static bool _isDeadEngineError(Object error) =>
      error.toString().toLowerCase().contains('disconnected channel');

  Future<T> _reviveAndRetry<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      if (!_isDeadEngineError(e)) rethrow;
      devLog(
        '[RustAudio] Command channel dead; respawning engine and retrying',
      );
      await prepareEngine();
      return await call();
    }
  }

  /// Get the current playback state.
  RustPlaybackState get state => stateNotifier.value;

  /// Get whether audio is currently playing.
  bool get isPlaying =>
      stateNotifier.value == RustPlaybackState.playing ||
      stateNotifier.value == RustPlaybackState.crossfading;

  /// Get the current track path.
  String? get currentPath => currentSource?.path;

  /// Includes the logical track bounds and follows progress during a fade.
  SourceIdentity? get currentSource {
    if (!_initialized) return null;
    try {
      return rust_audio.audioGetCurrentSource();
    } catch (e) {
      devLog('Error getting current path: $e');
      return null;
    }
  }

  /// Playback accepted by an explicit play or by PlayerService's native handoff.
  /// Unlike [currentSource], it remains available after the source reaches EOF.
  BigInt? get acceptedPlaybackId => _acceptedPlaybackId;

  void acceptNativeHandoff(BigInt playbackId) {
    _acceptedPlaybackId = playbackId;
  }

  /// Whether a next track is already queued in the engine.
  bool get hasQueuedNext => _initialized && rust_audio.audioHasQueuedNext();

  /// Play an audio file.
  Future<void> play(String path, {double? startSecs, double? endSecs}) async {
    if (!_initialized) {
      throw StateError('Rust audio engine not initialized');
    }

    _syncDsdOutputMode();
    _syncDsdTransportOverrides();
    final source = await _reviveAndRetry(
      () => rust_audio.audioPlay(
        path: path,
        startSecs: startSecs,
        endSecs: endSecs,
      ),
    );
    _acceptedPlaybackId = source.playbackId;
    _startProgressUpdates(fast: true);
    _updateState();
  }

  /// Play a remote audio stream directly over HTTP (range-based, no cache
  /// download before play). Auth is carried via [headers] (e.g. WebDAV Basic);
  /// Subsonic/Jellyfin embed credentials in [url] and pass an empty map.
  Future<void> playHttp({
    required String url,
    Map<String, String> headers = const {},
    double? startSecs,
    double? endSecs,
  }) async {
    if (!_initialized) {
      throw StateError('Rust audio engine not initialized');
    }
    _syncDsdOutputMode();
    _syncDsdTransportOverrides();
    final source = await _reviveAndRetry(
      () => rust_audio.audioPlayFromHttp(
        url: url,
        headers: headers,
        startSecs: startSecs,
        endSecs: endSecs,
      ),
    );
    _acceptedPlaybackId = source.playbackId;
    _startProgressUpdates(fast: true);
    _updateState();
  }

  /// Enable/disable Repeat One at the native engine.
  ///
  /// The native manager applies the guard to both live and replacement engines.
  Future<void> setRepeatOne(bool enabled) async {
    _repeatOne = enabled;
    if (!_initialized) return;
    await _reviveAndRetry(
      () => rust_audio.audioSetRepeatOne(enabled: enabled),
    );
  }

  /// Queue the next track for gapless playback.
  /// The next track will automatically start when the current one ends.
  Future<void> queueNext(
    String path, {
    double? startSecs,
    double? endSecs,
  }) async {
    if (!_initialized) {
      throw StateError('Rust audio engine not initialized');
    }
    if (_repeatOne) {
      devLog('[repeat-one] ignoring queueNext while Repeat One is active');
      return;
    }

    _syncDsdOutputMode();
    _syncDsdTransportOverrides();
    await _reviveAndRetry(
      () => rust_audio.audioQueueNext(
        path: path,
        startSecs: startSecs,
        endSecs: endSecs,
      ),
    );
  }

  /// Queue a remote HTTP stream as the next track for gapless playback.
  Future<void> queueNextHttp({
    required String url,
    Map<String, String> headers = const {},
    double? startSecs,
    double? endSecs,
  }) async {
    if (!_initialized) {
      throw StateError('Rust audio engine not initialized');
    }
    if (_repeatOne) {
      devLog('[repeat-one] ignoring queueNextHttp while Repeat One is active');
      return;
    }
    _syncDsdOutputMode();
    _syncDsdTransportOverrides();
    await _reviveAndRetry(
      () => rust_audio.audioQueueNextFromHttp(
        url: url,
        headers: headers,
        startSecs: startSecs,
        endSecs: endSecs,
      ),
    );
  }

  void _syncDsdOutputMode() {
    final mode = Uac2PreferencesService.dsdOutputModeSync;
    final rustMode = switch (mode) {
      DsdOutputMode.auto => 3,
      DsdOutputMode.forcePcm => 0,
      DsdOutputMode.forceDop => 1,
      DsdOutputMode.native => 2,
    };
    // frb(sync): executes synchronously, so the store is done before the
    // audioPlay call issued right after this.
    rust_audio.audioSetDsdOutputMode(mode: rustMode);
  }

  /// Push native-DSD tuning overrides to the engine. Byte order + subslot
  /// affect the USB direct path; wire variant + grouping the DAP shim path.
  void _syncDsdTransportOverrides() {
    final byteOrder = Uac2PreferencesService.dsdByteOrderOverrideSync;
    rust_audio.audioSetDsdBigEndianOverride(
      value: switch (byteOrder) {
        DsdByteOrderOverride.auto => null,
        DsdByteOrderOverride.littleEndian => false,
        DsdByteOrderOverride.bigEndian => true,
      },
    );
    rust_audio.audioSetDsdSubslotOverride(
      value: Uac2PreferencesService.dsdSubslotOverrideSync,
    );
    rust_audio.audioSetSasWireVariant(
      variant: switch (Uac2PreferencesService.dsdWireVariantSync) {
        DsdWireVariant.auto => 0,
        DsdWireVariant.beMsb => 0,
        DsdWireVariant.leMsb => 1,
        DsdWireVariant.beLsb => 2,
        DsdWireVariant.leLsb => 3,
      },
    );
    // Auto = U8: on-device calibration picked plain byte interleaving (LRLR).
    rust_audio.audioSetSasWireGrouping(
      grouping: switch (Uac2PreferencesService.dsdWireGroupingSync) {
        DsdWireGrouping.auto => 2,
        DsdWireGrouping.u32 => 0,
        DsdWireGrouping.u16 => 1,
        DsdWireGrouping.u8 => 2,
      },
    );
  }

  /// Pause playback.
  Future<void> pause() async {
    if (!_initialized) return;
    await rust_audio.audioPause();
    // Switch to slower updates when paused to reduce CPU usage while keeping UI synced
    _startProgressUpdates(fast: false);
    // Force immediate state update for responsive UI
    _updateState();
  }

  /// Resume playback.
  Future<void> resume() async {
    if (!_initialized) return;
    await rust_audio.audioResume();
    // Resume fast updates for smooth progress bar
    _startProgressUpdates(fast: true);
    // Force immediate state update
    _updateState();
  }

  /// Stop playback completely.
  Future<void> stop() async {
    if (!_initialized) return;
    await rust_audio.audioStop();
    _stopProgressUpdates();
    _acceptedPlaybackId = null;
    _updateState();
  }

  /// Seek to a position in seconds.
  Future<void> seek(Duration position) async {
    if (!_initialized) return;
    await rust_audio.audioSeek(positionSecs: position.inMilliseconds / 1000.0);
  }

  /// Set the volume (0.0 to 2.0; values >1.0 apply extended gain).
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;
    final clampedVolume = volume.clamp(0.0, 2.0);
    volumeNotifier.value = clampedVolume;
    await rust_audio.audioSetVolume(volume: clampedVolume);
  }

  /// Set the effective ReplayGain (dB) for the current track and as the
  /// default for subsequently spawned sources. Call before [play]/[queueNext]
  /// so the next track picks it up.
  Future<void> setReplayGain(double gainDb) async {
    if (!_initialized) return;
    await rust_audio.audioSetReplaygain(gainDb: gainDb.clamp(-60.0, 30.0));
  }

  /// Set only the spawn-time default ReplayGain (dB); the currently-running
  /// source keeps its own gain. Used when pre-queueing the next gapless track.
  Future<void> setReplayGainDefault(double gainDb) async {
    if (!_initialized) return;
    await rust_audio.audioSetReplaygainDefault(
      gainDb: gainDb.clamp(-60.0, 30.0),
    );
  }

  /// Select the callback's base pipeline mode.
  Future<void> setPipelineModePassthrough(bool enabled) async {
    if (!_initialized) return;
    try {
      rust_audio.audioSetPipelineModePassthrough(enabled: enabled);
    } catch (e) {
      devLog('[RustAudio] Failed to set pipeline mode: $e');
    }
  }

  /// Apply effective crossfade policy without changing the user's preference.
  Future<void> setCrossfade({
    required bool enabled,
    double? durationSecs,
  }) async {
    if (!_initialized) return;

    if (durationSecs != null) {
      crossfadeDurationNotifier.value = durationSecs;
    }

    await rust_audio.audioSetCrossfade(
      enabled: enabled,
      durationSecs: crossfadeDurationNotifier.value,
    );
    devLog(
      '[crossfade] applied: effective=$enabled, '
      'preference=${crossfadeEnabledNotifier.value}, '
      'duration=${crossfadeDurationNotifier.value}s',
    );
  }

  /// Set the crossfade curve type.
  Future<void> setCrossfadeCurve(rust_audio.CrossfadeCurveType curve) async {
    if (!_initialized) return;
    await rust_audio.audioSetCrossfadeCurve(curve: curve);
  }

  /// Set the BS2B crossfeed level.
  /// 0 = off, 1 = default, 2 = crossfeed, 3 = crossfeed easy.
  Future<void> setCrossfeed(int level) async {
    if (!_initialized) return;
    crossfeedLevelNotifier.value = level.clamp(0, 3);
    await rust_audio.audioSetCrossfeed(level: crossfeedLevelNotifier.value);
  }

  /// Skip to the next queued track (with crossfade if enabled).
  Future<void> skipToNext() async {
    if (!_initialized) return;
    await rust_audio.audioSkipToNext();
  }

  /// Set the playback speed (0.5 to 2.0).
  Future<void> setPlaybackSpeed(double speed) async {
    if (!_initialized) return;
    final clampedSpeed = speed.clamp(0.5, 2.0);
    playbackSpeedNotifier.value = clampedSpeed;
    await _reviveAndRetry(
      () => rust_audio.audioSetPlaybackSpeed(speed: clampedSpeed),
    );
  }

  /// Set pitch shift in semitones (tempo preserved). 0 = bypass.
  Future<void> setPitchShiftSemitones(double semitones) async {
    if (!_initialized) return;
    final clamped = semitones.clamp(-12.0, 12.0);
    pitchSemitonesNotifier.value = clamped;
    await rust_audio.audioSetPitchShiftSemitones(semitones: clamped);
  }

  /// Get the current playback speed.
  double getPlaybackSpeed() {
    if (!_initialized) return 1.0;
    return rust_audio.audioGetPlaybackSpeed() ?? 1.0;
  }

  /// Get the sample rate of the audio engine.
  int? getSampleRate() {
    if (!_initialized) return null;
    return rust_audio.audioGetSampleRate();
  }

  /// Get the number of audio channels.
  int? getChannels() {
    if (!_initialized) return null;
    return rust_audio.audioGetChannels()?.toInt();
  }

  /// Shutdown the audio engine.
  Future<void> shutdown() async {
    if (!_initialized) return;

    _stopProgressUpdates();
    _stopEventPolling();
    _stateRefreshClock
      ..stop()
      ..reset();
    await rust_audio.audioShutdown();
    _initialized = false;
    _acceptedPlaybackId = null;
  }

  /// Start periodic progress updates.
  ///
  /// Note: Uses background timer (not during build) to avoid blocking UI.
  /// Each tick reads only audioGetProgress(); playback state changes arrive
  /// as audioPollEvent stateChanged events, with a slow fallback refresh.
  void _startProgressUpdates({bool fast = true}) {
    _stopProgressUpdates();

    // Update progress every 50ms for smooth UI updates when playing
    // Update slower (250ms) when paused to keep UI in sync without waste
    final interval = fast
        ? const Duration(milliseconds: 50)
        : const Duration(milliseconds: 250);
    _progressTimer = Timer.periodic(interval, (_) {
      _updateProgress();
    });
  }

  /// Stop progress updates.
  void _stopProgressUpdates() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Update progress from the Rust engine.
  void _updateProgress() {
    final progress = rust_audio.audioGetProgress();
    if (progress != null) {
      final positionSecs = progress.positionSecs;
      if (!positionSecs.isFinite || positionSecs < 0) {
        return;
      }
      final newPositionMs = (positionSecs * 1000).round();
      final currentPositionMs = positionNotifier.value.inMilliseconds;

      // Only update if position actually changed (skip no-op updates)
      if (newPositionMs != currentPositionMs) {
        positionNotifier.value = Duration(milliseconds: newPositionMs);

        // Update label notifier at lower rate (every 500ms)
        if (newPositionMs - _lastPositionLabelMs >= 500) {
          positionLabelNotifier.value = positionNotifier.value;
          _lastPositionLabelMs = newPositionMs;
        }
      }

      if (progress.durationSecs != null &&
          progress.durationSecs!.isFinite &&
          progress.durationSecs! >= 0) {
        final newDurationMs = (progress.durationSecs! * 1000).round();
        final currentDurationMs = durationNotifier.value.inMilliseconds;

        if (newDurationMs != currentDurationMs) {
          durationNotifier.value = Duration(milliseconds: newDurationMs);
        }
      }

      // Only update buffer level if it actually changed
      final newBufferLevel = progress.bufferLevel;
      if (newBufferLevel != bufferLevelNotifier.value) {
        bufferLevelNotifier.value = newBufferLevel;
      }
    }
    // Playback state is event-driven; _refreshStateIfFallbackDue() repairs a
    // missed transition without adding an FFI call to every progress tick.
  }

  /// Update playback state from the Rust engine.
  ///
  /// [stopProgressWhenInactive] is set by event-driven and fallback refreshes.
  /// Command paths leave the progress timer alone because they explicitly
  /// start or stop it around the command.
  void _updateState({bool stopProgressWhenInactive = false}) {
    final nextState = _parseState(rust_audio.audioGetState());
    _setPlaybackState(nextState);
    if (stopProgressWhenInactive &&
        (nextState == RustPlaybackState.stopped ||
            nextState == RustPlaybackState.idle)) {
      _stopProgressUpdates();
    }
    _stateRefreshClock.reset();
  }

  /// Whether the slow state-refresh fallback is due.
  ///
  /// Events drive normal state updates; this only repairs a missed transition.
  @visibleForTesting
  static bool isStateRefreshFallbackDue(Duration elapsed) =>
      elapsed >= _stateRefreshFallbackInterval;

  /// Repair a dropped state transition without polling state on every tick.
  void _refreshStateIfFallbackDue() {
    if (!isStateRefreshFallbackDue(_stateRefreshClock.elapsed)) return;
    _updateState(stopProgressWhenInactive: true);
  }

  /// Update the public state and keep the event-poll cadence in sync.
  void _setPlaybackState(RustPlaybackState nextState) {
    if (stateNotifier.value != nextState) {
      stateNotifier.value = nextState;
    }
    _syncEventPolling();
  }

  /// Parse state string to enum.
  RustPlaybackState _parseState(String state) {
    switch (state) {
      case 'playing':
        return RustPlaybackState.playing;
      case 'paused':
        return RustPlaybackState.paused;
      case 'buffering':
        return RustPlaybackState.buffering;
      case 'crossfading':
        return RustPlaybackState.crossfading;
      case 'stopped':
        return RustPlaybackState.stopped;
      default:
        return RustPlaybackState.idle;
    }
  }

  /// Event polling cadence for a playback state.
  ///
  /// Track-end, crossfade, and error events only matter while the pipeline is
  /// active. Idle states can back off without affecting progress, which is
  /// polled separately.
  @visibleForTesting
  static Duration eventPollIntervalForState(RustPlaybackState state) {
    return switch (state) {
      RustPlaybackState.playing ||
      RustPlaybackState.buffering ||
      RustPlaybackState.crossfading => _activeEventPollInterval,
      RustPlaybackState.paused ||
      RustPlaybackState.idle ||
      RustPlaybackState.stopped => _idleEventPollInterval,
    };
  }

  /// Start polling for events from the Rust engine.
  void _startEventPolling() {
    _stopEventPolling();
    _syncEventPolling();
  }

  /// Reschedule event polling when the playback state changes cadence.
  void _syncEventPolling() {
    if (!_initialized) return;

    final interval = eventPollIntervalForState(stateNotifier.value);
    if (_eventPollTimer != null && _eventPollInterval == interval) return;

    _eventPollTimer?.cancel();
    _eventPollInterval = interval;
    _eventPollTimer = Timer.periodic(interval, (_) {
      _pollEvents();
      _refreshStateIfFallbackDue();
    });
  }

  /// Stop event polling.
  void _stopEventPolling() {
    _eventPollTimer?.cancel();
    _eventPollTimer = null;
    _eventPollInterval = null;
  }

  /// Poll for events from the Rust engine.
  void _pollEvents() {
    while (true) {
      final event = rust_audio.audioPollEvent();
      if (event == null) break;

      event.when(
        stateChanged: (_) {
          // Events are queued; a Playing event from before a completed pause
          // must not revive the UI/priority anchor after output was suspended.
          // _updateState reads the authoritative state and stops progress when
          // the engine is no longer active.
          _updateState(stopProgressWhenInactive: true);
        },
        progress: (positionSecs, durationSecs, bufferLevel) {
          final newPositionMs = (positionSecs * 1000).round();
          final currentPositionMs = positionNotifier.value.inMilliseconds;

          if (newPositionMs != currentPositionMs) {
            positionNotifier.value = Duration(milliseconds: newPositionMs);

            // Update label notifier at lower rate
            if (newPositionMs - _lastPositionLabelMs >= 500) {
              positionLabelNotifier.value = positionNotifier.value;
              _lastPositionLabelMs = newPositionMs;
            }
          }

          if (durationSecs != null) {
            final newDurationMs = (durationSecs * 1000).round();
            final currentDurationMs = durationNotifier.value.inMilliseconds;

            if (newDurationMs != currentDurationMs) {
              durationNotifier.value = Duration(milliseconds: newDurationMs);
            }
          }

          if (bufferLevel != bufferLevelNotifier.value) {
            bufferLevelNotifier.value = bufferLevel;
          }
        },
        trackEnded: (source, nextPlaybackId) {
          onTrackEnded?.call(source, nextPlaybackId);
        },
        crossfadeStarted: (from, to) {
          onCrossfadeStarted?.call(from, to);
        },
        error: (message) {
          devLog('Rust audio error: $message');
          onError?.call(message);
        },
        nextTrackReady: (source) {
          onNextTrackReady?.call(source);
        },
      );
    }
  }

  /// Dispose resources.
  void dispose() {
    _stopProgressUpdates();
    _stopEventPolling();
    _stateRefreshClock
      ..stop()
      ..reset();
    stateNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    bufferLevelNotifier.dispose();
    volumeNotifier.dispose();
    crossfadeEnabledNotifier.dispose();
    crossfadeDurationNotifier.dispose();
    crossfeedLevelNotifier.dispose();
    playbackSpeedNotifier.dispose();
    positionLabelNotifier.dispose();
  }
}
