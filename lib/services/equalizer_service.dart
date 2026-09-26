import 'dart:async';
import 'dart:io';
import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/services/android_audio_processing_service.dart';
import 'package:flick/services/eq_engine_hint.dart';
import 'package:flick/services/eq_response_service.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/src/rust/api/audio_api.dart' as rust_audio;
import 'package:flick/src/rust/audio/equalizer.dart';

EqualizerState _lastRequestedState = EqualizerState.initial();

/// Applies EQ and processing state to the active audio backend.
/// Rust engine: graphic EQ, dynamics, and creative FX are applied natively.
/// just_audio on Android: uses native AudioEffect counterparts where available.
Future<void> applyEqualizer(EqualizerState state) async {
  _lastRequestedState = _snapshotState(state);

  final playerService = PlayerService();

  // The fixed-band AudioEffect cannot render an arbitrary parametric curve, so
  // a parametric EQ with enabled bands asks the session manager for the Rust
  // variable-band engine. The engine attaches on the next playback request.
  final wantsRustForParametricEq =
      state.enabled &&
      state.mode == EqMode.parametric &&
      state.parametricBands.any(
        (band) => band.enabled && band.type != ParametricBandType.allPass,
      );
  if (EqEngineHint.parametricPeqActive != wantsRustForParametricEq) {
    EqEngineHint.parametricPeqActive = wantsRustForParametricEq;
    unawaited(
      playerService.syncAudioRouteSelection(
        reason: wantsRustForParametricEq
            ? 'parametric EQ enabled; variable-band DSP required'
            : 'parametric EQ disabled',
      ),
    );
    if (wantsRustForParametricEq &&
        !playerService.isUsingRustBackend &&
        rust_audio.audioIsNativeAvailable()) {
      // Stash the specs so they land on the Rust engine when it starts.
      try {
        await rust_audio.audioSetEqualizer(
          enabled: state.enabled,
          preampDb: state.preampDb,
          specs: _buildRustSpecs(state),
        );
      } catch (_) {}
    }
  }

  final useRustBackend =
      playerService.isUsingRustBackend &&
      rust_audio.audioIsNativeAvailable() &&
      rust_audio.audioIsInitialized();
  final bypassForBitPerfect = playerService.isBitPerfectProcessingLocked;

  // Android + just_audio: the native Equalizer AudioEffect has a fixed band
  // layout, so sample the intended response at the device's real band centers.
  // Preamp is sent separately so the native side can apply it as a broadband
  // stage (DynamicsProcessing input gain on API 28+).
  if (Platform.isAndroid && !useRustBackend) {
    final audioSessionId = playerService.androidAudioSessionId;
    final bandInfo = await androidJustAudioProcessingService
        .getEqualizerBandInfo(audioSessionId: audioSessionId);
    final gains = bandInfo == null
        ? _applyBmt(
            gains: state.mode == EqMode.graphic
                ? state.graphicGainsDb
                : _parametricToGraphicGains(state.parametricBands),
            bassDb: state.bassDb,
            midDb: state.midDb,
            trebleDb: state.trebleDb,
          )
        : _mapToDeviceBands(state, bandInfo);
    try {
      await androidJustAudioProcessingService.apply(
        state: state,
        gainsDb: gains,
        audioSessionId: audioSessionId,
        bypassed: bypassForBitPerfect,
      );
    } catch (_) {}
    return;
  }

  // Rust backend: real variable-band DSP.
  if (!rust_audio.audioIsNativeAvailable() ||
      !rust_audio.audioIsInitialized()) {
    return;
  }
  try {
    final rustSampleRate = rust_audio.audioGetSampleRate();
    if (rustSampleRate != null && rustSampleRate > 0) {
      EqResponseService.activeSampleRateHz = rustSampleRate.toDouble();
    }
    if (bypassForBitPerfect) {
      await rust_audio.audioSetEqualizer(
        enabled: false,
        preampDb: 0.0,
        specs: const [],
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

    await rust_audio.audioSetEqualizer(
      enabled: state.enabled,
      preampDb: state.preampDb,
      specs: _buildRustSpecs(state),
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

/// Map parametric bands to 10-band gains for the Android fixed-band path.
/// ponytail: fallback when the device band layout can't be queried.
List<double> _parametricToGraphicGains(List<ParametricBand> bands) {
  final freqs = EqualizerState.defaultGraphicFrequenciesHz;
  return List<double>.generate(
    freqs.length,
    (i) => parametricResponseDbAtHz(hz: freqs[i], bands: bands),
    growable: false,
  );
}

/// Samples the intended response at the device's real band centers so the
/// fixed-band AudioEffect approximates the parametric/graphic curve instead of
/// averaging unrelated 10-band gains together.
List<double> _mapToDeviceBands(
  EqualizerState state,
  EqualizerBandInfo bandInfo,
) {
  final centers = bandInfo.centerFreqsHz;
  if (centers.isEmpty) return const [];

  final List<ParametricBand> bands;
  if (state.mode == EqMode.graphic) {
    final gains = _applyBmt(
      gains: state.graphicGainsDb,
      bassDb: state.bassDb,
      midDb: state.midDb,
      trebleDb: state.trebleDb,
    );
    final freqs = EqualizerState.defaultGraphicFrequenciesHz;
    bands = [
      for (var i = 0; i < freqs.length && i < gains.length; i++)
        ParametricBand(frequencyHz: freqs[i], gainDb: gains[i], q: 1.0),
    ];
  } else {
    bands = state.parametricBands;
  }

  return [
    for (final hz in centers)
      EqResponseService.responseDbAtHz(
        hz: hz,
        bands: bands,
        minDb: EqualizerNotifier.gainMinDb,
        maxDb: EqualizerNotifier.gainMaxDb,
      ),
  ];
}

/// Builds real per-band specs for the Rust variable-band engine.
/// ponytail: BMT (bass/mid/treble) is a graphic-era convenience and is only
/// applied in graphic mode here; parametric users have shelves directly.
/// Preamp is a separate broadband stage on the Rust side, never baked here.
List<EqBandSpec> _buildRustSpecs(EqualizerState state) {
  if (state.mode == EqMode.graphic) {
    final gains = _applyBmt(
      gains: state.graphicGainsDb,
      bassDb: state.bassDb,
      midDb: state.midDb,
      trebleDb: state.trebleDb,
    );
    final freqs = EqualizerState.defaultGraphicFrequenciesHz;
    return [
      for (var i = 0; i < gains.length; i++)
        EqBandSpec(
          bandType: EqBandType.peaking,
          freqHz: freqs[i],
          gainDb: gains[i],
          q: 1.0,
        ),
    ];
  }
  // Parametric: real specs from enabled bands. allPass is a no-op with no FFI
  // type, so it is skipped. Pass/notch bands ignore gainDb in the RBJ formulas.
  return [
    for (final b in state.parametricBands)
      if (b.enabled && b.type != ParametricBandType.allPass)
        EqBandSpec(
          bandType: _mapBandType(b.type),
          freqHz: b.frequencyHz,
          gainDb: b.gainDb,
          q: b.q,
        ),
  ];
}

EqBandType _mapBandType(ParametricBandType t) {
  switch (t) {
    case ParametricBandType.peaking:
      return EqBandType.peaking;
    case ParametricBandType.lowShelf:
      return EqBandType.lowShelf;
    case ParametricBandType.highShelf:
      return EqBandType.highShelf;
    case ParametricBandType.lowPass:
      return EqBandType.lowPass;
    case ParametricBandType.highPass:
      return EqBandType.highPass;
    case ParametricBandType.bandPass:
      return EqBandType.bandPass;
    case ParametricBandType.notch:
      return EqBandType.notch;
    case ParametricBandType.allPass:
      return EqBandType.peaking; // unreachable: allPass filtered before mapping
  }
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
      return gain
          .clamp(EqualizerNotifier.gainMinDb, EqualizerNotifier.gainMaxDb)
          .toDouble();
    },
    growable: false,
  );
}
