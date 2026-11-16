import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/uac2_preferences_service.dart';

/// Reports frame build/raster stats every few seconds while developer mode is on.
/// Meant for diagnosing scroll sluggishness without adb (thread #210).
class FrameTimingsMonitor {
  FrameTimingsMonitor._();

  static final FrameTimingsMonitor instance = FrameTimingsMonitor._();

  static const Duration _window = Duration(seconds: 5);
  static const int _minSamples = 20;

  final List<FrameTiming> _pending = [];
  Timer? _timer;
  bool _bound = false;
  bool _collecting = false;

  /// Starts following developer mode.
  ///
  /// Frame timings are collected only while developer mode is enabled, so the
  /// normal (disabled) path installs no timings callback and runs no timer.
  void start() {
    if (_bound) return;
    _bound = true;
    Uac2PreferencesService.developerModeNotifier.addListener(_syncCollection);
    _syncCollection();
  }

  /// Stops collecting and stops following developer mode.
  void stop() {
    if (!_bound) return;
    _bound = false;
    Uac2PreferencesService.developerModeNotifier.removeListener(
      _syncCollection,
    );
    _stopCollection();
  }

  void _syncCollection() {
    final enabled = Uac2PreferencesService.isDeveloperModeEnabledSync;
    if (enabled == _collecting) return;

    if (enabled) {
      _collecting = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _timer = Timer.periodic(_window, (_) => _report());
    } else {
      _stopCollection();
    }
  }

  void _stopCollection() {
    if (_collecting) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _collecting = false;
    }
    _timer?.cancel();
    _timer = null;
    _pending.clear();
  }

  void _onTimings(List<FrameTiming> timings) {
    _pending.addAll(timings);
  }

  void _report() {
    if (_pending.isEmpty) return;
    final samples = List<FrameTiming>.of(_pending);
    _pending.clear();
    if (!Uac2PreferencesService.isDeveloperModeEnabledSync) return;
    if (samples.length < _minSamples) return;

    final build = samples
        .map((f) => f.buildDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final raster = samples
        .map((f) => f.rasterDuration.inMicroseconds / 1000)
        .toList()
      ..sort();
    final fps = samples.length / _window.inSeconds;

    devLog(
      'Frames: ${samples.length} in ${_window.inSeconds}s (~${fps.toStringAsFixed(1)} fps), '
      'build p50=${_percentile(build, 0.5)} p95=${_percentile(build, 0.95)} ms, '
      'raster p50=${_percentile(raster, 0.5)} p95=${_percentile(raster, 0.95)} ms',
    );
  }

  @visibleForTesting
  bool get isCollecting => _collecting;

  @visibleForTesting
  int get pendingTimingsCount => _pending.length;

  @visibleForTesting
  void recordTimingsForTesting(List<FrameTiming> timings) =>
      _onTimings(timings);

  static String _percentile(List<double> sorted, double q) {
    if (sorted.isEmpty) return '-';
    final index = ((sorted.length - 1) * q).round();
    return sorted[index].toStringAsFixed(1);
  }
}
