import 'dart:math' as math;

import 'package:flick/models/song.dart';

/// ReplayGain mode identifiers (stored as strings in preferences, mirroring
/// the codebase convention for string-keyed enums like `refreshRateMode`).
class ReplayGainMode {
  static const String off = 'off';
  static const String track = 'track';
  static const String album = 'album';
}

/// Pre-amp range shared by the settings UI and the volume normalization math.
const double replayGainPreampMinDb = -18.0;
const double replayGainPreampMaxDb = 18.0;

/// Linear multiplier for a gain in dB.
double replayGainDbToLinear(double gainDb) {
  if (gainDb == 0.0) return 1.0;
  return math.pow(10.0, gainDb / 20.0).toDouble();
}

double replayGainLinearToDb(double linear) {
  if (linear <= 0.0) return -60.0;
  return 20.0 * math.log(linear) / math.ln10;
}

/// Compute the effective ReplayGain (dB) for [song] under the given settings.
///
/// - track mode uses the track loudness gain;
/// - album mode uses the album gain (falling back to the track gain when the
///   album value is missing);
/// - the user pre-amp is added on top;
/// - when clipping prevention is on and the resulting gain is positive, it is
///   capped so the stored peak maps to exactly full scale
///   (`maxGain = -20·log10(peak)`), guaranteeing no peak exceeds 1.0.
///
/// Returns 0.0 when ReplayGain is off or no usable tag data exists.
double computeReplayGainDbForSong(
  Song? song, {
  required String mode,
  required double preampDb,
  required bool preventClipping,
}) {
  if (song == null || mode == ReplayGainMode.off) return 0.0;

  final double? gain;
  final double? peak;
  if (mode == ReplayGainMode.album) {
    gain = song.replaygainAlbumGain ?? song.replaygainTrackGain;
    peak = song.replaygainAlbumPeak ?? song.replaygainTrackPeak;
  } else {
    gain = song.replaygainTrackGain;
    peak = song.replaygainTrackPeak;
  }
  if (gain == null || !gain.isFinite) return 0.0;

  final total = preampDb + gain;
  if (total <= 0.0) {
    // Attenuation — always safe, no clipping possible.
    return total;
  }
  if (preventClipping && peak != null && peak.isFinite && peak > 0.0) {
    final maxGain = replayGainLinearToDb(peak) * -1.0;
    return math.min(total, maxGain.isFinite ? maxGain : total);
  }
  return total;
}

/// Push the effective ReplayGain (dB) to the Rust engine. Safe no-op when the
/// native engine isn't available/initialized.
/// Snapshot of the computed ReplayGain state for the current track.
class ReplayGainAppliedState {
  const ReplayGainAppliedState({
    required this.mode,
    required this.gainDb,
  });

  final String mode;
  final double gainDb;

  double get linear => replayGainDbToLinear(gainDb);

  static const neutral =
      ReplayGainAppliedState(mode: ReplayGainMode.off, gainDb: 0.0);

  bool get isActive => mode != ReplayGainMode.off && gainDb != 0.0;
}
