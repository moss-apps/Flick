import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/visualizer_service.dart';
import 'package:flick/src/rust/api/visualizer_api.dart';

/// Where the visualizer's bars come from for the current audio path.
enum VisualizerSourceMode {
  /// Flick's Rust engine taps the PCM it renders and computes an FFT.
  rustFft,

  /// Android's Visualizer effect is attached to the Standard Engine session.
  android,

  /// The current engine sends audio directly to the DAC and exposes no PCM.
  unavailable,

  /// The current track is native/DoP DSD, which has no PCM stream to analyze.
  dsdUnavailable,
}

/// Small interface consumed by [AudioVisualizer] and the full player UI.
///
/// Production uses [VisualizerSourceController]. Tests can override the
/// provider with a deterministic fake without constructing a PlayerService.
abstract class VisualizerSource extends ChangeNotifier {
  VisualizerSourceMode get mode;
  List<double>? get bars;
  bool get isAvailable;
  bool get needsPermission;

  /// Requests any runtime permission needed by the source. Returns false when
  /// the source cannot provide live bars.
  Future<bool> prepare();

  void acquire();
  void release();
}

typedef VisualizerGetBars = Future<VisualizerBars?> Function();
typedef VisualizerSetActive = Future<bool> Function({required bool active});
typedef VisualizerPermissionResolver =
    Future<bool> Function({required bool request});

/// Default runtime check. Android's Visualizer API requires RECORD_AUDIO to
/// read the output mix; Flick never records or stores the samples.
Future<bool> _requestMicrophonePermission({required bool request}) async {
  var status = await Permission.microphone.status;
  if (!status.isGranted && request) {
    status = await Permission.microphone.request();
  }
  return status.isGranted || status.isLimited;
}

Future<bool> _defaultSetActive({required bool active}) =>
    visualizerSetActive(active: active);

/// Resolves the correct visualizer backend for the current engine and owns the
/// lifetime of exactly one live source at a time.
///
/// - High Quality (`rustOboe`): polls `visualizerGetBars()` from Rust.
/// - Standard (`normalAndroid`): attaches Android's Visualizer to the
///   ExoPlayer session after microphone permission is granted.
/// - Direct USB / DAP native: no source.
/// - DoP/native DSD: no source.
class VisualizerSourceController extends VisualizerSource {
  static const int _barCount = 48;
  static const Duration _pollInterval = Duration(milliseconds: 33);
  static const Duration _androidRetryInterval = Duration(seconds: 1);

  final PlayerService _playerService;
  final VisualizerService _androidService;
  final VisualizerGetBars _rustGetBars;
  final VisualizerSetActive _rustSetActive;
  final VisualizerPermissionResolver _permissionResolver;
  final bool _androidPlatform;

  VisualizerSourceMode _mode = VisualizerSourceMode.unavailable;
  List<double>? _bars;
  int _refCount = 0;
  bool _started = false;
  bool _disposed = false;
  int _generation = 0;

  Timer? _pollTimer;
  Timer? _androidRetryTimer;
  bool _pollInFlight = false;
  BigInt? _lastSequence;
  bool _rustActive = false;

  bool _androidPermissionGranted = false;
  bool _androidAttached = false;
  bool _androidAttachFailed = false;
  bool _androidAttachInFlight = false;
  int? _androidSessionId;

  /// Serializes Rust tap activation so a rapid stop/start cannot deliver the
  /// activate and deactivate calls out of order.
  Future<void> _rustActivation = Future<void>.value();

  VisualizerSourceController({
    required PlayerService playerService,
    VisualizerService? androidService,
    VisualizerGetBars? rustGetBars,
    VisualizerSetActive? rustSetActive,
    VisualizerPermissionResolver? permissionResolver,
    bool? androidPlatform,
  }) : _playerService = playerService,
       _androidService = androidService ?? VisualizerService(),
       _rustGetBars = rustGetBars ?? visualizerGetBars,
       _rustSetActive = rustSetActive ?? _defaultSetActive,
       _permissionResolver = permissionResolver ?? _requestMicrophonePermission,
       _androidPlatform = androidPlatform ?? Platform.isAndroid {
    _mode = _resolveMode();
    _androidService.barHeightsNotifier.addListener(_onAndroidBars);
    _playerService.selectedPlaybackModeNotifier.addListener(_onEngineChanged);
    _playerService.initializedPlaybackModeNotifier.addListener(
      _onEngineChanged,
    );
    _playerService.bitPerfectProcessingLockedNotifier.addListener(
      _onEngineChanged,
    );
    _playerService.isPlayingNotifier.addListener(_onPlayingChanged);
    _playerService.currentSongNotifier.addListener(_onSongChanged);
  }

  @override
  VisualizerSourceMode get mode => _mode;

  @override
  List<double>? get bars => _bars;

  @override
  bool get isAvailable => switch (_mode) {
    VisualizerSourceMode.rustFft => true,
    VisualizerSourceMode.android => _androidPermissionGranted,
    VisualizerSourceMode.unavailable ||
    VisualizerSourceMode.dsdUnavailable => false,
  };

  @override
  bool get needsPermission =>
      _mode == VisualizerSourceMode.android && !_androidPermissionGranted;

  VisualizerSourceMode _resolveMode() {
    final engine = _playerService.currentEngineType;
    if (engine == AudioEngineType.usbDacExperimental ||
        engine == AudioEngineType.dapInternalHighRes) {
      return VisualizerSourceMode.unavailable;
    }
    if (engine == AudioEngineType.normalAndroid) {
      return VisualizerSourceMode.android;
    }
    if (_playerService.isCurrentTrackDoP) {
      return VisualizerSourceMode.dsdUnavailable;
    }
    return VisualizerSourceMode.rustFft;
  }

  void _onEngineChanged() {
    if (_disposed) return;
    final next = _resolveMode();
    if (next == _mode) {
      // The session may have changed even when the source kind did not.
      if (next == VisualizerSourceMode.android) {
        unawaited(_attachAndroid(_generation));
      }
      return;
    }
    _mode = next;
    _resetActiveSource();
    if (_refCount > 0 && _isPlaying) {
      _startActiveSource();
    }
    _notify();
  }

  void _onSongChanged() {
    if (_disposed) return;
    _onEngineChanged();
  }

  bool get _isPlaying => _playerService.isPlayingNotifier.value;

  void _onPlayingChanged() {
    if (_disposed) return;
    if (_isPlaying) {
      if (_refCount > 0) _startActiveSource();
    } else {
      _stopActiveSource();
    }
  }

  @override
  void acquire() {
    if (_disposed) return;
    _refCount++;
    if (_refCount != 1) return;
    final next = _resolveMode();
    if (next != _mode) {
      _mode = next;
      _notify();
    }
    if (_isPlaying) _startActiveSource();
  }

  @override
  void release() {
    if (_disposed) return;
    _refCount = math.max(0, _refCount - 1);
    if (_refCount == 0) _stopActiveSource();
  }

  @override
  Future<bool> prepare() async {
    if (_disposed) return false;
    final next = _resolveMode();
    if (next != _mode) {
      _mode = next;
      _resetActiveSource();
      _notify();
    }
    switch (_mode) {
      case VisualizerSourceMode.rustFft:
        return true;
      case VisualizerSourceMode.android:
        final granted = await _ensureAndroidPermission();
        if (granted && _refCount > 0 && _isPlaying) {
          _startActiveSource();
        }
        return granted;
      case VisualizerSourceMode.unavailable ||
          VisualizerSourceMode.dsdUnavailable:
        return false;
    }
  }

  void _startActiveSource() {
    if (_disposed || _started || _refCount <= 0 || !_isPlaying) return;
    switch (_mode) {
      case VisualizerSourceMode.rustFft:
        _started = true;
        _startRust();
      case VisualizerSourceMode.android:
        _started = true;
        unawaited(_startAndroid(++_generation));
      case VisualizerSourceMode.unavailable ||
          VisualizerSourceMode.dsdUnavailable:
        return;
    }
  }

  void _stopActiveSource() {
    if (!_started && _bars == null) return;
    _resetActiveSource();
    _notify();
  }

  void _resetActiveSource() {
    _started = false;
    _generation++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollInFlight = false;
    _lastSequence = null;
    _androidRetryTimer?.cancel();
    _androidRetryTimer = null;
    _androidAttached = false;
    _androidAttachFailed = false;
    _androidSessionId = null;
    _bars = null;
    if (_rustActive) {
      _rustActive = false;
      _enqueueRustActive(false);
    }
    unawaited(_androidService.detach());
  }

  void _enqueueRustActive(bool active) {
    _rustActivation = _rustActivation.then((_) async {
      try {
        await _rustSetActive(active: active);
      } catch (e) {
        devLog('[Visualizer] failed to set Rust tap active=$active: $e');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // High Quality: Rust PCM tap + FFT
  // ---------------------------------------------------------------------------

  void _startRust() {
    _bars = null;
    _lastSequence = null;
    final generation = ++_generation;
    _rustActive = true;
    _enqueueRustActive(true);
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_pollRust(generation)),
    );
    unawaited(_pollRust(generation));
  }

  Future<void> _pollRust(int generation) async {
    if (_disposed ||
        !_started ||
        _mode != VisualizerSourceMode.rustFft ||
        generation != _generation ||
        _pollInFlight) {
      return;
    }
    _pollInFlight = true;
    try {
      final frame = await _rustGetBars();
      if (_disposed ||
          !_started ||
          generation != _generation ||
          _mode != VisualizerSourceMode.rustFft) {
        return;
      }
      if (frame == null || frame.bars.length != _barCount) {
        return;
      }
      if (_lastSequence != null && frame.sequence == _lastSequence) {
        return;
      }
      _lastSequence = frame.sequence;
      _bars = List<double>.from(frame.bars);
      _notify();
    } catch (e) {
      devLog('[Visualizer] Rust FFT poll failed: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Standard: Android Visualizer attached to the ExoPlayer session
  // ---------------------------------------------------------------------------

  Future<void> _startAndroid(int generation) async {
    if (!_androidPlatform) {
      if (generation == _generation) _started = false;
      return;
    }
    final granted = await _ensureAndroidPermission(request: false);
    if (_disposed || !_started || generation != _generation) return;
    if (!granted) {
      // Leave the source idle so a later prepare() can attach after the
      // user grants permission; otherwise the stale started flag would
      // silently swallow the retry.
      _started = false;
      _notify();
      return;
    }
    _androidRetryTimer?.cancel();
    _androidRetryTimer = Timer.periodic(
      _androidRetryInterval,
      (_) => unawaited(_attachAndroid(generation)),
    );
    await _attachAndroid(generation);
  }

  Future<bool> _ensureAndroidPermission({bool request = true}) async {
    if (!_androidPlatform) return false;
    try {
      final granted = await _permissionResolver(request: request);
      _androidPermissionGranted = granted;
    } catch (e) {
      devLog('[Visualizer] microphone permission failed: $e');
      _androidPermissionGranted = false;
    }
    if (!_disposed) _notify();
    return _androidPermissionGranted;
  }

  Future<void> _attachAndroid(int generation) async {
    if (_androidAttachInFlight ||
        _disposed ||
        !_started ||
        _mode != VisualizerSourceMode.android ||
        generation != _generation ||
        !_androidPermissionGranted) {
      return;
    }
    _androidAttachInFlight = true;
    try {
      final sessionId = _playerService.androidAudioSessionId;
      if (sessionId == null || sessionId <= 0) {
        if (!_androidAttachFailed) {
          _androidAttachFailed = true;
          _notify();
        }
        return;
      }
      if (_androidAttached && _androidSessionId == sessionId) return;

      if (_androidAttached) {
        await _androidService.detach();
      }
      final attached = await _androidService.attach(sessionId);
      if (_disposed ||
          !_started ||
          generation != _generation ||
          _mode != VisualizerSourceMode.android) {
        await _androidService.detach();
        return;
      }
      _androidAttached = attached;
      _androidAttachFailed = !attached;
      _androidSessionId = attached ? sessionId : null;
      if (!attached) {
        _bars = null;
        devLog('[Visualizer] Android capture did not attach');
      }
      _notify();
    } finally {
      _androidAttachInFlight = false;
    }
  }

  void _onAndroidBars() {
    if (_disposed || !_started || _mode != VisualizerSourceMode.android) {
      return;
    }
    final latest = _androidService.barHeightsNotifier.value;
    if (latest == null) {
      if (_bars != null) {
        _bars = null;
        _notify();
      }
      return;
    }
    if (latest.length != _barCount || listEquals(latest, _bars)) return;
    _bars = List<double>.from(latest);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _playerService.selectedPlaybackModeNotifier.removeListener(
      _onEngineChanged,
    );
    _playerService.initializedPlaybackModeNotifier.removeListener(
      _onEngineChanged,
    );
    _playerService.bitPerfectProcessingLockedNotifier.removeListener(
      _onEngineChanged,
    );
    _playerService.isPlayingNotifier.removeListener(_onPlayingChanged);
    _playerService.currentSongNotifier.removeListener(_onSongChanged);
    _androidService.barHeightsNotifier.removeListener(_onAndroidBars);
    _pollTimer?.cancel();
    _androidRetryTimer?.cancel();
    if (_rustActive) {
      _rustActive = false;
      _enqueueRustActive(false);
    }
    // detach() touches the notifier after its channel work, so let it finish
    // before disposing the service rather than disposing underneath it.
    unawaited(_androidService.detach().whenComplete(_androidService.dispose));
    super.dispose();
  }
}
