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
  List<double>? _smoothedBars;
  int _fftFrameCount = 0;

  /// Whether we have a live native visualizer feeding data.
  bool get hasRealData => barHeightsNotifier.value != null;

  /// Attach the native visualizer to an Android audio session.
  Future<bool> attach(int sessionId) async {
    if (sessionId <= 0) {
      return false;
    }
    if (sessionId == _lastSessionId && _attached) {
      return true;
    }

    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'attachVisualizer',
        {'sessionId': sessionId},
      );
      if (success == true) {
        _attached = true;
        _lastSessionId = sessionId;
        _smoothedBars = null;
        _fftFrameCount = 0;
        _startListening();
        return true;
      }
    } catch (e) {
      devLog('[VisualizerService] attach failed: $e');
    }
    _attached = false;
    _lastSessionId = -1;
    return false;
  }

  /// Detach and clear any live data.
  Future<void> detach() async {
    _lastSessionId = -1;
    _smoothedBars = null;
    _fftFrameCount = 0;
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
    Uint8List? fft;
    var sampleRate = 48000;

    if (data is Uint8List) {
      fft = data;
    } else if (data is Map) {
      final rawFft = data['fft'];
      if (rawFft is Uint8List) fft = rawFft;
      final rawRate = data['samplingRate'];
      if (rawRate is int && rawRate > 0) {
        // Android reports milliHertz; accept plain Hertz too.
        sampleRate = rawRate > 100000 ? rawRate ~/ 1000 : rawRate;
      }
    }
    if (fft == null) return;

    final bars = fftBytesToBars(
      fft,
      barCount: _barCount,
      sampleRate: sampleRate,
      previous: _smoothedBars,
    );
    _smoothedBars = bars;
    _fftFrameCount++;
    if (_fftFrameCount <= 3 || _fftFrameCount % 150 == 0) {
      final peak = bars.reduce((a, b) => a > b ? a : b);
      devLog(
        '[Visualizer] Android FFT frame $_fftFrameCount, '
        'rate=${sampleRate}Hz, peak=${peak.toStringAsFixed(2)}, '
        'min=${bars.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)}',
      );
    }
    barHeightsNotifier.value = bars;
  }

  void dispose() {
    detach();
    barHeightsNotifier.dispose();
  }
}

/// Convert an Android `Visualizer` FFT capture into display bars.
///
/// Android lays the capture out as signed 8-bit complex values:
///   index 0        = DC real part
///   index 1        = Nyquist real part
///   index 2, 3     = real/imaginary of bin 1
///   index 4, 5     = real/imaginary of bin 2, and so on
///
/// The values are magnitudes, not PCM. Mapping them linearly makes ordinary
/// music look like one low-frequency spike plus a flat floor, so this uses a
/// 60 dB relative window and log-spaced bands, matching the Rust visualizer.
@visibleForTesting
List<double> fftBytesToBars(
  Uint8List fft, {
  int barCount = 48,
  int sampleRate = 48000,
  List<double>? previous,
}) {
  const minHeight = 0.04;
  const minFreq = 20.0;
  const maxFreqLimit = 20000.0;
  if (barCount <= 0) return const [];
  final length = fft.length;
  if (length < 4) return List<double>.filled(barCount, minHeight);

  int signedByte(int value) => value <= 127 ? value : value - 256;

  final half = length ~/ 2;
  final magnitudes = Float64List(half + 1);
  magnitudes[0] = signedByte(fft[0]).abs().toDouble();
  magnitudes[half] = signedByte(fft[1]).abs().toDouble();
  for (var bin = 1; bin < half; bin++) {
    final real = signedByte(fft[bin * 2]).toDouble();
    final imaginary = signedByte(fft[bin * 2 + 1]).toDouble();
    magnitudes[bin] = math.sqrt(real * real + imaginary * imaginary);
  }

  var peak = 0.0;
  for (final magnitude in magnitudes) {
    if (magnitude > peak) peak = magnitude;
  }
  if (peak <= 1.0e-9) {
    final bars = List<double>.filled(barCount, minHeight);
    if (previous != null && previous.length == barCount) {
      for (var bar = 0; bar < barCount; bar++) {
        bars[bar] = (previous[bar] + (minHeight - previous[bar]) * 0.12).clamp(
          minHeight,
          1.0,
        );
      }
    }
    return bars;
  }

  double toDb(double magnitude) => 20.0 * math.log(magnitude) / math.ln10;
  final peakDb = toDb(peak);
  final floorDb = math.max(-90.0, peakDb - 60.0);
  final span = math.max(1.0, peakDb - floorDb);
  final levels = Float64List(half + 1);
  for (var bin = 0; bin <= half; bin++) {
    final magnitude = magnitudes[bin];
    final db = magnitude <= 1.0e-9 ? floorDb : toDb(magnitude);
    levels[bin] = ((db - floorDb) / span).clamp(0.0, 1.0);
  }

  final hz = sampleRate > 100000 ? sampleRate / 1000.0 : sampleRate.toDouble();
  final nyquist = hz / 2.0;
  final maxFreq = math.min(maxFreqLimit, nyquist).clamp(20.1, maxFreqLimit);
  final logSpan = math.log(maxFreq / minFreq);
  final bars = List<double>.filled(barCount, minHeight);

  for (var bar = 0; bar < barCount; bar++) {
    final low = minFreq * math.exp(logSpan * bar / barCount);
    final high = minFreq * math.exp(logSpan * (bar + 1) / barCount);
    final start = (low * length / hz).floor().clamp(1, half).toInt();
    final end = (high * length / hz).ceil().clamp(start + 1, half + 1).toInt();

    var level = 0.0;
    for (var bin = start; bin < end; bin++) {
      if (levels[bin] > level) level = levels[bin];
    }

    final target = (minHeight + level * (1.0 - minHeight)).clamp(
      minHeight,
      1.0,
    );
    final prior = previous != null && previous.length == barCount
        ? previous[bar]
        : target;
    final smoothing = target >= prior ? 0.55 : 0.12;
    bars[bar] = (prior + (target - prior) * smoothing).clamp(minHeight, 1.0);
  }

  return bars;
}
