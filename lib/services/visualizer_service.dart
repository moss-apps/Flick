import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Service that bridges Android's [Visualizer] API to Flutter FFT bar data.
///
/// Falls back to null data when the native visualizer is unavailable
/// (Rust backend, non-Android, or no audio session).
class VisualizerService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.mossapps.flick/visualizer',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.mossapps.flick/visualizer_events',
  );

  static const int _barCount = 48;

  final ValueNotifier<List<double>?> barHeightsNotifier = ValueNotifier(null);

  StreamSubscription<dynamic>? _eventSubscription;
  bool _attached = false;
  int _lastSessionId = -1;

  /// Whether we have a live native visualizer feeding data.
  bool get hasRealData => barHeightsNotifier.value != null;

  /// Attach the native visualizer to an Android audio session.
  Future<bool> attach(int sessionId) async {
    if (sessionId <= 0 || sessionId == _lastSessionId) {
      return _attached;
    }
    _lastSessionId = sessionId;

    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'attachVisualizer',
        {'sessionId': sessionId},
      );
      if (success == true) {
        _attached = true;
        _startListening();
        return true;
      }
    } catch (e) {
      devLog('[VisualizerService] attach failed: $e');
    }
    _attached = false;
    return false;
  }

  /// Detach and clear any live data.
  Future<void> detach() async {
    _lastSessionId = -1;
    if (!_attached) {
      barHeightsNotifier.value = null;
      return;
    }
    _attached = false;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    barHeightsNotifier.value = null;
    try {
      await _methodChannel.invokeMethod('detachVisualizer');
    } catch (e) {
      devLog('[VisualizerService] detach failed: $e');
    }
  }

  void _startListening() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onFftData,
      onError: (Object e) {
        devLog('[VisualizerService] event error: $e');
        barHeightsNotifier.value = null;
      },
    );
  }

  void _onFftData(dynamic data) {
    if (data is! Uint8List) return;
    barHeightsNotifier.value = _fftToBars(data, _barCount);
  }

  /// Convert Android Visualizer FFT bytes to normalized bar magnitudes.
  ///
  /// Android returns signed 8-bit bytes:
  ///   [0]     = DC component (ignored)
  ///   [1]     = unused padding
  ///   [2..n]  = pairs of (real, imag) for each frequency bin
  static List<double> _fftToBars(Uint8List fft, int barCount) {
    final binCount = (fft.length ~/ 2) - 1;
    if (binCount <= 0) {
      return List<double>.filled(barCount, 0.04);
    }

    // Extract magnitudes from complex FFT pairs
    final magnitudes = Float64List(binCount);
    for (var i = 0; i < binCount; i++) {
      final realIdx = 2 + i * 2;
      final imagIdx = realIdx + 1;
      if (imagIdx >= fft.length) break;

      // Convert unsigned bytes to signed
      final r = fft[realIdx] <= 127 ? fft[realIdx] : fft[realIdx] - 256;
      final im = fft[imagIdx] <= 127 ? fft[imagIdx] : fft[imagIdx] - 256;

      // Magnitude in dB-ish scale
      final mag = math.sqrt(r * r + im * im).toDouble();
      // Apply a perceptual weighting: boost highs slightly since visualizer
      // capture tends to be bass-heavy
      final weight = 1.0 + (i / binCount) * 0.4;
      magnitudes[i] = mag * weight;
    }

    // Map bins to bars logarithmically (human hearing is log-scale)
    final bars = List<double>.filled(barCount, 0.0);
    for (var i = 0; i < barCount; i++) {
      final t0 = i / barCount;
      final t1 = (i + 1) / barCount;
      // Logarithmic distribution: more resolution in lower frequencies
      final start = (math.pow(t0, 1.6) * binCount).floor();
      final end = (math.pow(t1, 1.6) * binCount).ceil();

      var peak = 0.0;
      for (var j = start; j < end && j < binCount; j++) {
        if (magnitudes[j] > peak) peak = magnitudes[j];
      }
      bars[i] = peak;
    }

    // Normalize to 0..1 with a noise floor
    var maxMag = 0.0;
    for (final v in bars) {
      if (v > maxMag) maxMag = v;
    }

    if (maxMag > 1.0) {
      final scale = 1.0 / maxMag;
      for (var i = 0; i < barCount; i++) {
        bars[i] = (bars[i] * scale * 0.92 + 0.06).clamp(0.04, 1.0);
      }
    } else {
      for (var i = 0; i < barCount; i++) {
        bars[i] = (bars[i] * 0.92 + 0.06).clamp(0.04, 1.0);
      }
    }

    return bars;
  }

  void dispose() {
    detach();
    barHeightsNotifier.dispose();
  }
}
