import 'dart:io';
import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/android_audio_processing_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/src/rust/api/audio_api.dart' as rust_audio;

EqualizerState _lastRequestedState = EqualizerState.initial();

/// Applies EQ and processing state to the active audio backend.
/// Rust engine: graphic EQ, dynamics, and creative FX are applied natively.
/// just_audio on Android: uses native AudioEffect counterparts where available.
Future<void> applyEqualizer(EqualizerState state) async {
  _lastRequestedState = _snapshotState(state);

  final useGraphic = state.mode == EqMode.graphic;
  final gains = _applyPreamp(
    gains: _applyBmt(
      gains: useGraphic
          ? state.graphicGainsDb
          : _parametricToGraphicGains(state.parametricBands),
      bassDb: state.bassDb,
      midDb: state.midDb,
      trebleDb: state.trebleDb,
    ),
    preampDb: state.preampDb,
  );

  if (gains.length != 10) return;

  final playerService = PlayerService();
  final useRustBackend =
      playerService.isUsingRustBackend &&
      rust_audio.audioIsNativeAvailable() &&
      rust_audio.audioIsInitialized();
  final bypassForBitPerfect = playerService.isBitPerfectProcessingLocked;

  // Android + just_audio: use native AudioEffect counterparts with session ID.
  if (Platform.isAndroid && !useRustBackend) {
    try {
      await androidJustAudioProcessingService.apply(
        state: state,
        gainsDb: gains,
        audioSessionId: playerService.androidAudioSessionId,
        bypassed: bypassForBitPerfect,
      );
    } catch (_) {}
    return;
  }

  // Rust backend: apply EQ + compressor + limiter to the active native engine.
  if (!rust_audio.audioIsNativeAvailable() ||
      !rust_audio.audioIsInitialized()) {
    return;
  }
  try {
    if (bypassForBitPerfect) {
      rust_audio.audioSetEqualizer(
        enabled: false,
        gainsDb: List<double>.filled(10, 0.0, growable: false),
      );
      await rust_audio.audioSetCompressor(
        enabled: false,
        thresholdDb: state.compressor.thresholdDb,
        ratio: state.compressor.ratio,
        attackMs: state.compressor.attackMs,
        releaseMs: state.compressor.releaseMs,
        makeupGainDb: state.compressor.makeupGainDb,
      );
      await rust_audio.audioSetLimiter(
        enabled: false,
        inputGainDb: state.limiter.inputGainDb,
        ceilingDb: state.limiter.ceilingDb,
        releaseMs: state.limiter.releaseMs,
      );
      await rust_audio.audioSetFx(
        enabled: false,
        balance: state.fx.balance,
        tempo: state.fx.tempo,
        damp: state.fx.damp,
        filterHz: state.fx.filterHz,
        delayMs: state.fx.delayMs,
        size: state.fx.size,
        mix: state.fx.mix,
        feedback: state.fx.feedback,
        width: state.fx.width,
      );
      await rust_audio.audioSetConvolver(
        enabled: false,
        mix: state.convolver.mix,
      );
      return;
    }

    rust_audio.audioSetEqualizer(
      enabled: state.enabled,
      gainsDb: List<double>.from(gains),
    );
    await rust_audio.audioSetCompressor(
      enabled: state.enabled && state.compressor.enabled,
      thresholdDb: state.compressor.thresholdDb,
      ratio: state.compressor.ratio,
      attackMs: state.compressor.attackMs,
      releaseMs: state.compressor.releaseMs,
      makeupGainDb: state.compressor.makeupGainDb,
    );
    await rust_audio.audioSetLimiter(
      enabled: state.enabled && state.limiter.enabled,
      inputGainDb: state.limiter.inputGainDb,
      ceilingDb: state.limiter.ceilingDb,
      releaseMs: state.limiter.releaseMs,
    );
    await rust_audio.audioSetFx(
      enabled: state.enabled && state.fx.enabled,
      balance: state.fx.balance,
      tempo: state.fx.tempo,
      damp: state.fx.damp,
      filterHz: state.fx.filterHz,
      delayMs: state.fx.delayMs,
      size: state.fx.size,
      mix: state.fx.mix,
      feedback: state.fx.feedback,
      width: state.fx.width,
    );
    await rust_audio.audioSetConvolver(
      enabled: state.enabled && state.convolver.enabled,
      mix: state.convolver.mix,
    );
  } catch (_) {}
}

Future<void> reapplyEqualizer() async {
  await applyEqualizer(_lastRequestedState);
  final ir = _lastRequestedState.convolver.irPath;
  if (ir != null && ir.isNotEmpty) {
    try {
      await rust_audio.audioLoadIr(path: ir);
    } catch (_) {}
  }
}

/// Loads (decodes + resamples) an impulse response into the native convolver.
Future<void> loadConvolverIr(String path) async {
  if (!rust_audio.audioIsNativeAvailable() ||
      !rust_audio.audioIsInitialized()) {
    return;
  }
  await rust_audio.audioLoadIr(path: path);
}

/// Clears the loaded impulse response from the native convolver.
Future<void> clearConvolverIr() async {
  if (!rust_audio.audioIsNativeAvailable() ||
      !rust_audio.audioIsInitialized()) {
    return;
  }
  await rust_audio.audioClearIr();
}

/// Map parametric bands to 10-band gains for Rust engine (graphic-only).
List<double> _parametricToGraphicGains(List<ParametricBand> bands) {
  final freqs = EqualizerState.defaultGraphicFrequenciesHz;
  return List<double>.generate(
    freqs.length,
    (i) => parametricResponseDbAtHz(hz: freqs[i], bands: bands),
    growable: false,
  );
}

EqualizerState _snapshotState(EqualizerState state) {
  return state.copyWith(
    preampDb: state.preampDb,
    graphicGainsDb: List<double>.of(state.graphicGainsDb, growable: false),
    parametricBands: List<ParametricBand>.of(
      state.parametricBands,
      growable: false,
    ),
    compressor: state.compressor.copyWith(),
    limiter: state.limiter.copyWith(),
    fx: state.fx.copyWith(),
    convolver: state.convolver.copyWith(),
  );
}

List<double> _applyPreamp({
  required List<double> gains,
  required double preampDb,
}) {
  if (preampDb == 0.0) {
    return List<double>.of(gains, growable: false);
  }
  return List<double>.generate(
    gains.length,
    (index) => gains[index] + preampDb,
    growable: false,
  );
}

List<double> _applyBmt({
  required List<double> gains,
  required double bassDb,
  required double midDb,
  required double trebleDb,
}) {
  if (bassDb == 0.0 && midDb == 0.0 && trebleDb == 0.0) {
    return List<double>.of(gains, growable: false);
  }
  // Bass: indices 0-3 (32, 64, 125, 250 Hz)
  // Mid: indices 4-7 (500, 1k, 2k, 4k Hz)
  // Treble: indices 8-9 (8k, 16k Hz)
  return List<double>.generate(
    gains.length,
    (index) {
      var gain = gains[index];
      if (index <= 3) {
        gain += bassDb;
      } else if (index <= 7) {
        gain += midDb;
      } else {
        gain += trebleDb;
      }
      return gain.clamp(-12.0, 12.0).toDouble();
    },
    growable: false,
  );
}
