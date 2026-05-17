import 'dart:math' as math;

import 'package:flick/providers/equalizer_provider.dart';

// ============================================================================
// Chart helpers (log-frequency X, dB Y)
// ============================================================================

const double eqMinHz = 20.0;
const double eqMaxHz = 20000.0;
const double eqMinDb = -12.0;
const double eqMaxDb = 12.0;

final double eqLogMin = math.log(eqMinHz) / math.ln10;
final double eqLogMax = math.log(eqMaxHz) / math.ln10;

double hzToX(double hz) => (math.log(hz.clamp(eqMinHz, eqMaxHz)) / math.ln10);

double xToHz(double x) {
  final logMin = math.log(eqMinHz);
  final logMax = math.log(eqMaxHz);
  final t = (x - eqLogMin) / (eqLogMax - eqLogMin);
  final v = logMin + (logMax - logMin) * t.clamp(0.0, 1.0);
  return math.exp(v);
}

double tToHz(double t) {
  final logMin = math.log(eqMinHz);
  final logMax = math.log(eqMaxHz);
  final v = logMin + (logMax - logMin) * t.clamp(0.0, 1.0);
  return math.exp(v);
}

List<({double x, double db})> buildParametricCurvePoints({
  required List<ParametricBand> bands,
  required int sampleCount,
}) {
  final points = <({double x, double db})>[];
  for (var i = 0; i <= sampleCount; i++) {
    final t = i / sampleCount;
    final hz = tToHz(t);
    final db = parametricResponseDbAtHz(
      hz: hz,
      bands: bands,
      minDb: eqMinDb,
      maxDb: eqMaxDb,
    );
    points.add((x: hzToX(hz), db: db));
  }
  return points;
}

List<({double x, double db})> buildGraphicCurvePoints({
  required List<double> freqs,
  required List<double> gains,
  required int sampleCount,
}) {
  final points = <({double x, double db})>[];
  for (var i = 0; i <= sampleCount; i++) {
    final t = i / sampleCount;
    final hz = tToHz(t);
    final db = interpDbAtHz(hz, freqs, gains);
    points.add((x: hzToX(hz), db: db));
  }
  return points;
}

// Linear interpolation in log-frequency space between the nearest bands.
double interpDbAtHz(double hz, List<double> freqs, List<double> gains) {
  final clampedHz = hz.clamp(freqs.first, freqs.last).toDouble();
  final logHz = math.log(clampedHz);

  // Find the segment [i, i+1] that contains hz.
  var i = 0;
  while (i < freqs.length - 2 && clampedHz > freqs[i + 1]) {
    i++;
  }

  final f0 = freqs[i];
  final f1 = freqs[i + 1];
  final g0 = gains[i];
  final g1 = gains[i + 1];

  final t = ((logHz - math.log(f0)) / (math.log(f1) - math.log(f0))).clamp(
    0.0,
    1.0,
  );
  final db = g0 + (g1 - g0) * t;
  return db.clamp(eqMinDb, eqMaxDb).toDouble();
}

bool isGuideLogX(double x) {
  const guideFreqs = <double>[
    20,
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
  ];
  const tol = 0.025; // in log10 units
  for (final hz in guideFreqs) {
    final gx = hzToX(hz);
    if ((x - gx).abs() <= tol) return true;
  }
  return false;
}

String hzLabel(double hz) {
  if (hz >= 1000) {
    final k = hz / 1000.0;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return hz.toStringAsFixed(0);
}
