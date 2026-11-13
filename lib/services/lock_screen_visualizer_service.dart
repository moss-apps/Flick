import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/l10n/l10n.dart' as localization;
import 'package:flick/models/song.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/visualizer_source.dart';

/// Bridges the shared source to a native, keyguard-safe viewer. This consumer
/// deliberately follows the viewer's lifecycle, not the Flutter Activity's.
class LockScreenVisualizerService {
  LockScreenVisualizerService({
    required VisualizerSource source,
    required ValueListenable<bool> isPlaying,
    required ValueListenable<Song?> currentSong,
    MethodChannel channel = const MethodChannel(
      'com.mossapps.flick/lock_screen_visualizer',
    ),
  }) : _source = source,
       _isPlaying = isPlaying,
       _currentSong = currentSong,
       _channel = channel {
    _channel.setMethodCallHandler(_onNativeCall);
    _source.addListener(_onSourceChanged);
    _isPlaying.addListener(_sync);
    _currentSong.addListener(_sync);
  }

  final VisualizerSource _source;
  final ValueListenable<bool> _isPlaying;
  final ValueListenable<Song?> _currentSong;
  final MethodChannel _channel;
  AppPreferences _preferences = AppPreferences();
  Color? _albumColor;
  bool _visible = false;
  bool _nativeMotionAllowed = false;
  bool _acquired = false;
  bool _opening = false;
  bool _syncing = false;
  bool _disposed = false;
  bool _sending = false;
  bool _framePending = false;
  bool _armed = false;
  bool? _lastNativeEnabled;
  bool? _lastNativeSimulatedAod;
  bool? _lastNativeArmed;
  VisualizerSourceMode? _lastSourceMode;
  bool? _lastSourceAvailable;
  bool? _lastSourceNeedsPermission;

  void configure(AppPreferences preferences, {Color? albumColor}) {
    if (_disposed) return;
    _preferences = preferences;
    _albumColor = albumColor;
    _lastSourceMode = _source.mode;
    _lastSourceAvailable = _source.isAvailable;
    _lastSourceNeedsPermission = _source.needsPermission;
    _sync();
  }

  /// Called only by the explicit Open action. Permission dialogs must finish
  /// while Flick is unlocked, before the native viewer covers the keyguard.
  Future<bool> open() async {
    if (_disposed || _opening || !_preferences.lockScreenVisualizerEnabled) {
      return false;
    }
    _opening = true;
    try {
      if (await _invoke('canOpen') != true || _disposed) return false;
      if (!await _source.prepare() || _disposed) return false;
      if (!_preferences.lockScreenVisualizerEnabled) return false;
      await _publishState();
      return await _invoke('open') == true;
    } catch (error) {
      devLog('[LockScreenVisualizer] cannot prepare viewer: $error');
      return false;
    } finally {
      _opening = false;
    }
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (_disposed) return;
    switch (call.method) {
      case 'visibility':
        final state = Map<Object?, Object?>.from(call.arguments as Map);
        _visible = state['visible'] == true;
        _nativeMotionAllowed = state['motionAllowed'] == true;
        _sync();
    }
  }

  bool get _supported =>
      _source.mode == VisualizerSourceMode.android ||
      _source.mode == VisualizerSourceMode.rustFft;

  /// The native screen-off receiver may launch the viewer while the app is
  /// locked, so every condition that could require a prompt or a silent audio
  /// change must already be satisfied before arming it.
  bool get _simulatedAodArmed =>
      _preferences.lockScreenVisualizerEnabled &&
      _preferences.simulatedAodEnabled &&
      _preferences.animationsEnabled &&
      _isPlaying.value &&
      _currentSong.value != null &&
      _supported &&
      _source.isAvailable &&
      !(_source.mode == VisualizerSourceMode.android &&
          _source.needsPermission);

  void _sync() {
    if (_disposed || _syncing) return;
    _syncing = true;
    try {
      final shouldAcquire =
          _visible &&
          _preferences.lockScreenVisualizerEnabled &&
          _preferences.animationsEnabled &&
          _nativeMotionAllowed &&
          _isPlaying.value &&
          _currentSong.value != null &&
          _supported &&
          _source.isAvailable;
      if (_acquired != shouldAcquire) {
        _acquired = shouldAcquire;
        if (shouldAcquire) {
          _source.acquire();
        } else {
          _source.release();
        }
      }
      _armed = _simulatedAodArmed;
      // Publish state before arming native launch so a screen-off that races
      // this update cannot start a viewer with an empty configuration. Keep
      // publishing while the feature is on: a paused simulated viewer may be
      // stopped with the screen off and still needs the pause/route update.
      if (_preferences.lockScreenVisualizerEnabled) {
        unawaited(_publishState());
      }
      _publishNativeConfig();
      if (_visible) _sendFrame();
    } finally {
      _syncing = false;
    }
  }

  void _publishNativeConfig() {
    if (_disposed) return;
    final enabled = _preferences.lockScreenVisualizerEnabled;
    final simulated = _preferences.simulatedAodEnabled;
    if (_lastNativeEnabled == enabled &&
        _lastNativeSimulatedAod == simulated &&
        _lastNativeArmed == _armed) {
      return;
    }
    _lastNativeEnabled = enabled;
    _lastNativeSimulatedAod = simulated;
    _lastNativeArmed = _armed;
    unawaited(
      _invoke('configure', {
        'enabled': enabled,
        'simulatedAod': simulated,
        'armed': _armed,
      }),
    );
  }

  void _onSourceChanged() {
    // Source notifications include both frames and availability changes. Only
    // the latter need a full sync; frame updates while hidden must not republish
    // state at capture rate.
    final mode = _source.mode;
    final available = _source.isAvailable;
    final needsPermission = _source.needsPermission;
    final availabilityChanged =
        mode != _lastSourceMode ||
        available != _lastSourceAvailable ||
        needsPermission != _lastSourceNeedsPermission;
    _lastSourceMode = mode;
    _lastSourceAvailable = available;
    _lastSourceNeedsPermission = needsPermission;
    if (availabilityChanged) {
      _sync();
    } else if (_acquired && _supported && available) {
      _sendFrame();
    }
  }

  Future<void> _publishState() async {
    final l10n = localization.l10n.englishForFilipino;
    final song = _currentSong.value;
    final status = !_supported
        ? (_source.mode == VisualizerSourceMode.dsdUnavailable
              ? l10n.visualizerUnavailableDsdBody
              : l10n.visualizerUnavailableBitPerfectBody)
        : !_preferences.animationsEnabled || !_nativeMotionAllowed
        ? l10n.visualizerAnimationsOffTitle
        : _source.needsPermission
        ? l10n.visualizerStandardMicBody
        : song == null
        ? l10n.lockScreenVisualizerNoTrack
        : !_isPlaying.value
        ? l10n.lockScreenVisualizerPaused
        : l10n.lockScreenVisualizerHint;
    await _invoke('state', {
      'contentDescription': '${l10n.lockScreenVisualizerTitle}. $status',
      'trackId': song?.id,
      // Capture stops immediately on pause. The native renderer may ease the
      // last real frame to black, without keeping the source alive.
      'animate':
          _preferences.animationsEnabled &&
          _nativeMotionAllowed &&
          _supported &&
          _source.isAvailable,
      'live': _acquired,
      'playing': _isPlaying.value,
      'supported': _supported,
      'closeLabel': l10n.close,
      'animationStyle': _preferences.visualizerAnimationStyle,
      'frequencyMode': _preferences.visualizerFrequencyMode,
      'movementMode': _preferences.visualizerMovementMode,
      'colorMode': _preferences.visualizerColorMode,
      'albumColor': _albumColor?.toARGB32(),
    });
  }

  void _sendFrame() {
    if (_disposed || !_visible) return;
    _framePending = true;
    if (_sending) return;
    unawaited(_flushFrames());
  }

  Future<void> _flushFrames() async {
    _sending = true;
    try {
      while (_framePending && !_disposed && _visible) {
        _framePending = false;
        // At most one channel message is in flight; stale frames are dropped.
        await _invoke('bars', _acquired ? _source.bars : null);
      }
    } finally {
      _sending = false;
    }
  }

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    if (_disposed) return null;
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      devLog('[LockScreenVisualizer] $method failed: $error');
      return null;
    }
  }

  void dispose() {
    if (_disposed) return;
    unawaited(
      _invoke('configure', {
        'enabled': false,
        'simulatedAod': false,
        'armed': false,
      }),
    );
    _disposed = true;
    _source.removeListener(_onSourceChanged);
    _isPlaying.removeListener(_sync);
    _currentSong.removeListener(_sync);
    _channel.setMethodCallHandler(null);
    if (_acquired) _source.release();
    _acquired = false;
  }
}
