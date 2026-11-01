import 'dart:math' as math;

/// Software-tier volume curve used by the Rust engine.
///
/// Mirrors `volume_to_gain` in `rust/src/audio/engine.rs`: up to 1.0 the
/// slider maps linearly in dB over a −40 dB range (`10^(2 · (v − 1))`), so
/// 50 % is −20 dB. Above 1.0 the engine scales gain linearly for extended
/// volume (+6 dB at 200 %), which is 20 · log10(v) in dB.
double softwareVolumeToDb(double volume) {
  if (volume <= 0.0) return double.negativeInfinity;
  if (volume <= 1.0) return 40.0 * (volume - 1.0);
  return 20.0 * math.log(volume) / math.ln10;
}

/// Applies linear attenuation, then inverts Rust's slider curve. Values below
/// its smallest nonzero gain become silence, never a louder minimum gain.
double attenuateSoftwareVolume(double volume, double gain) {
  if (volume <= 0.0 || gain <= 0.0) return 0.0;
  final db = softwareVolumeToDb(volume) + 20.0 * math.log(gain) / math.ln10;
  if (db <= -40.0) return 0.0;
  return db <= 0.0 ? 1.0 + db / 40.0 : math.pow(10.0, db / 20.0).toDouble();
}

/// Formats [softwareVolumeToDb] for the volume widgets: one decimal, with
/// −∞ at silence. Only valid for the software (engine gain) tier; DAC
/// hardware attenuation must be reported from the device's own state.
String formatSoftwareVolumeDb(double volume) {
  if (volume <= 0.0) return '-∞';
  return softwareVolumeToDb(volume).toStringAsFixed(1);
}
