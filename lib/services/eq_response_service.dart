import 'dart:math' as math;

import 'package:flick/providers/equalizer_provider.dart';

/// RBJ biquad magnitude response, mirroring `rust/src/audio/equalizer.rs`.
///
/// Used by the EQ graph and by the Android fixed-band mapping so the drawn
/// curve and the mapped gains match what the Rust audio path actually renders.
class EqResponseService {
  EqResponseService._();

  static const double defaultSampleRateHz = 48000.0;

  /// Sample rate of the active output. Kept in sync by the equalizer service
  /// (Rust engine rate, or device output rate on the Android path).
  static double activeSampleRateHz = defaultSampleRateHz;

  /// Magnitude response of a single band at [hz], in dB.
  ///
  /// Disabled bands and all-pass bands contribute 0 dB. Pass and notch filters
  /// ignore gain, exactly like the Rust implementation.
  static double bandResponseDb({
    required ParametricBand band,
    required double hz,
    double? sampleRateHz,
  }) {
    if (!band.enabled || band.type == ParametricBandType.allPass) return 0.0;

    final fs = sampleRateHz ?? activeSampleRateHz;
    final nyq = fs * 0.5;
    final f0 = band.frequencyHz.clamp(1.0, nyq * 0.99).toDouble();
    final q = band.q.clamp(0.2, 20.0).toDouble();

    final w0 = 2.0 * math.pi * f0 / fs;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / (2.0 * q);

    final coeffs = _biquadCoeffs(
      type: band.type,
      gainDb: band.gainDb,
      cosW0: cosW0,
      sinW0: sinW0,
      alpha: alpha,
    );
    return _magnitudeDb(coeffs, hz.clamp(1.0, nyq * 0.99).toDouble(), fs);
  }

  /// Summed response of [bands] at [hz], clamped to [minDb]..[maxDb].
  static double responseDbAtHz({
    required double hz,
    required List<ParametricBand> bands,
    double? sampleRateHz,
    double minDb = -12.0,
    double maxDb = 12.0,
  }) {
    double sum = 0.0;
    for (final band in bands) {
      sum += bandResponseDb(band: band, hz: hz, sampleRateHz: sampleRateHz);
    }
    return sum.clamp(minDb, maxDb).toDouble();
  }

  /// Normalized RBJ coefficients `[b0, b1, b2, a1, a2]` (a0 = 1).
  static List<double> _biquadCoeffs({
    required ParametricBandType type,
    required double gainDb,
    required double cosW0,
    required double sinW0,
    required double alpha,
  }) {
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final double b0, b1, b2, a0, a1, a2;
    switch (type) {
      case ParametricBandType.peaking:
        b0 = 1.0 + alpha * a;
        b1 = -2.0 * cosW0;
        b2 = 1.0 - alpha * a;
        a0 = 1.0 + alpha / a;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha / a;
      case ParametricBandType.lowShelf:
        final sq = math.sqrt(a);
        b0 = a * ((a + 1.0) - (a - 1.0) * cosW0 + 2.0 * sq * alpha);
        b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosW0);
        b2 = a * ((a + 1.0) - (a - 1.0) * cosW0 - 2.0 * sq * alpha);
        a0 = (a + 1.0) + (a - 1.0) * cosW0 + 2.0 * sq * alpha;
        a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cosW0);
        a2 = (a + 1.0) + (a - 1.0) * cosW0 - 2.0 * sq * alpha;
      case ParametricBandType.highShelf:
        final sq = math.sqrt(a);
        b0 = a * ((a + 1.0) + (a - 1.0) * cosW0 + 2.0 * sq * alpha);
        b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosW0);
        b2 = a * ((a + 1.0) + (a - 1.0) * cosW0 - 2.0 * sq * alpha);
        a0 = (a + 1.0) - (a - 1.0) * cosW0 + 2.0 * sq * alpha;
        a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosW0);
        a2 = (a + 1.0) - (a - 1.0) * cosW0 - 2.0 * sq * alpha;
      case ParametricBandType.lowPass:
        b0 = (1.0 - cosW0) / 2.0;
        b1 = 1.0 - cosW0;
        b2 = (1.0 - cosW0) / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
      case ParametricBandType.highPass:
        b0 = (1.0 + cosW0) / 2.0;
        b1 = -(1.0 + cosW0);
        b2 = (1.0 + cosW0) / 2.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
      case ParametricBandType.bandPass:
        b0 = alpha;
        b1 = 0.0;
        b2 = -alpha;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
      case ParametricBandType.notch:
        b0 = 1.0;
        b1 = -2.0 * cosW0;
        b2 = 1.0;
        a0 = 1.0 + alpha;
        a1 = -2.0 * cosW0;
        a2 = 1.0 - alpha;
      case ParametricBandType.allPass:
        b0 = 1.0;
        b1 = 0.0;
        b2 = 0.0;
        a0 = 1.0;
        a1 = 0.0;
        a2 = 0.0;
    }
    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
  }

  static double _magnitudeDb(List<double> c, double hz, double fs) {
    final w = 2.0 * math.pi * hz / fs;
    final cos1 = math.cos(w);
    final sin1 = math.sin(w);
    final cos2 = math.cos(2.0 * w);
    final sin2 = math.sin(2.0 * w);

    final numRe = c[0] + c[1] * cos1 + c[2] * cos2;
    final numIm = -c[1] * sin1 - c[2] * sin2;
    final denRe = 1.0 + c[3] * cos1 + c[4] * cos2;
    final denIm = -c[3] * sin1 - c[4] * sin2;

    final num = numRe * numRe + numIm * numIm;
    final den = denRe * denRe + denIm * denIm;
    if (den <= 0.0) return 0.0;
    if (num <= 1e-30) return -120.0;
    return 10.0 * math.log(num / den) / math.ln10;
  }
}
