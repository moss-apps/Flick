import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flick/services/visualizer_service.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _capture() => Uint8List(512);

void _setBin(Uint8List fft, int bin, int real, [int imaginary = 0]) {
  if (bin == 0) {
    fft[0] = real & 0xff;
  } else if (bin == fft.length ~/ 2) {
    fft[1] = real & 0xff;
  } else {
    fft[bin * 2] = real & 0xff;
    fft[bin * 2 + 1] = imaginary & 0xff;
  }
}

int _expectedBar(double frequency, {double maxFrequency = 20000}) {
  final t = math.log(frequency / 20) / math.log(maxFrequency / 20);
  return (t * 48).floor();
}

void main() {
  test('silence produces the minimum height', () {
    final bars = fftBytesToBars(_capture());
    expect(bars, hasLength(48));
    expect(bars.every((bar) => bar == 0.04), isTrue);
  });

  test('a 1 kHz tone lands in the expected log-spaced band', () {
    final fft = _capture();
    _setBin(fft, 11, 100);
    final bars = fftBytesToBars(fft);
    final peak = bars.indexOf(bars.reduce((a, b) => a > b ? a : b));
    final expected = _expectedBar(1000);
    expect((peak - expected).abs(), lessThanOrEqualTo(2));
    expect(bars[peak], greaterThan(0.8));
  });

  test('a high tone peaks higher than a low tone', () {
    final low = _capture();
    _setBin(low, 3, 100);
    final lowBars = fftBytesToBars(low);
    final lowPeak = lowBars.indexOf(lowBars.reduce((a, b) => a > b ? a : b));

    final high = _capture();
    _setBin(high, 85, 100);
    final highBars = fftBytesToBars(high);
    final highPeak = highBars.indexOf(highBars.reduce((a, b) => a > b ? a : b));

    expect(highPeak, greaterThan(lowPeak));
  });

  test('uses the reported sample rate for bin mapping', () {
    final fft = _capture();
    _setBin(fft, 5, 100);
    final bars = fftBytesToBars(fft, sampleRate: 96000);
    final peak = bars.indexOf(bars.reduce((a, b) => a > b ? a : b));
    expect((peak - _expectedBar(1000)).abs(), lessThanOrEqualTo(2));
  });

  test('smoothing decays toward silence instead of snapping', () {
    final fft = _capture();
    _setBin(fft, 11, 100);
    final loud = fftBytesToBars(fft);
    final quiet = fftBytesToBars(_capture(), previous: loud);
    expect(quiet[27], lessThan(loud[27]));
    expect(quiet[27], greaterThan(0.04));
  });

  test('Nyquist content is outside the displayed 20 kHz range', () {
    final fft = _capture();
    _setBin(fft, fft.length ~/ 2, 100);
    final bars = fftBytesToBars(fft);
    expect(bars.every((bar) => bar == 0.04), isTrue);
  });
}
