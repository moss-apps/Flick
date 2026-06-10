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

double bmtOffsetDbAtHz(
  double hz, {
  required double bassDb,
  required double midDb,
  required double trebleDb,
}) {
  if (bassDb == 0.0 && midDb == 0.0 && trebleDb == 0.0) return 0.0;

  final logHz = math.log(hz.clamp(eqMinHz, eqMaxHz));

  final bassSigma = 0.4;
  final bassContrib =
      bassDb / (1.0 + math.exp((logHz - math.log(250.0)) / bassSigma));

  final midCenter = math.log(1500.0);
  final midSigma = 0.55;
  final midLog = logHz - midCenter;
  final midContrib =
      midDb * math.exp(-(midLog * midLog) / (2.0 * midSigma * midSigma));

  final trebleSigma = 0.4;
  final trebleContrib =
      trebleDb / (1.0 + math.exp(-(logHz - math.log(5000.0)) / trebleSigma));

  return (bassContrib + midContrib + trebleContrib)
      .clamp(eqMinDb, eqMaxDb)
      .toDouble();
}

List<({double x, double db})> buildParametricCurvePoints({
  required List<ParametricBand> bands,
  required int sampleCount,
  double bassDb = 0.0,
  double midDb = 0.0,
  double trebleDb = 0.0,
}) {
  final points = <({double x, double db})>[];
  for (var i = 0; i <= sampleCount; i++) {
    final t = i / sampleCount;
    final hz = tToHz(t);
    var db = parametricResponseDbAtHz(
      hz: hz,
      bands: bands,
      minDb: eqMinDb,
      maxDb: eqMaxDb,
    );
    db = (db + bmtOffsetDbAtHz(hz, bassDb: bassDb, midDb: midDb, trebleDb: trebleDb))
        .clamp(eqMinDb, eqMaxDb)
        .toDouble();
    points.add((x: hzToX(hz), db: db));
  }
  return points;
}

List<({double x, double db})> buildGraphicCurvePoints({
  required List<double> freqs,
  required List<double> gains,
  required int sampleCount,
  double bassDb = 0.0,
  double midDb = 0.0,
  double trebleDb = 0.0,
}) {
  final points = <({double x, double db})>[];
  for (var i = 0; i <= sampleCount; i++) {
    final t = i / sampleCount;
    final hz = tToHz(t);
    var db = interpDbAtHz(hz, freqs, gains);
    db = (db + bmtOffsetDbAtHz(hz, bassDb: bassDb, midDb: midDb, trebleDb: trebleDb))
        .clamp(eqMinDb, eqMaxDb)
        .toDouble();
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
