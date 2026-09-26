import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flick/providers/equalizer_provider.dart';

const MethodChannel _androidAudioProcessingChannel = MethodChannel(
  'com.mossapps.flick/equalizer',
);

final AndroidJustAudioProcessingService androidJustAudioProcessingService =
    AndroidJustAudioProcessingService();

/// Fixed-band layout of the device's native Equalizer AudioEffect.
class EqualizerBandInfo {
  const EqualizerBandInfo({
    required this.bandCount,
    required this.centerFreqsHz,
    required this.minLevelDb,
    required this.maxLevelDb,
  });

  final int bandCount;
  final List<double> centerFreqsHz;
  final double minLevelDb;
  final double maxLevelDb;
}

class AndroidJustAudioProcessingService {
  AndroidJustAudioProcessingService({MethodChannel? channel})
    : _channel = channel ?? _androidAudioProcessingChannel;

  static const double _dbEpsilon = 0.01;

  final MethodChannel _channel;

  /// Boost gain in millibels for a linear volume > 1.0 (extended volume).
  /// 1.0 → 0 mB, 2.0 → ~602 mB (+6 dB). Returns 0 for volumes <= 1.0.
  static int volumeToBoostMb(double volume) {
    if (volume <= 1.0) return 0;
    final clamped = volume.clamp(1.0, 2.0);
    final db = 20.0 * math.log(clamped) / math.ln10;
    return (db * 100).round();
  }

  Future<void> apply({
    required EqualizerState state,
    required List<double> gainsDb,
    required int? audioSessionId,
    required bool bypassed,
  }) async {
    final request = _AndroidAudioProcessingRequest.fromState(
      state: state,
      gainsDb: gainsDb,
      audioSessionId: audioSessionId,
      bypassed: bypassed,
    );

    if (request.requiresAudioSession && audioSessionId == null) {
      debugPrint(
        '[AndroidAudioProcessing] skipping apply: audio effects requested but '
        'audio session id is not available yet',
      );
      return;
    }

    await _channel.invokeMethod<void>('applyAudioProcessing', request.toMap());
  }

  /// Apply a positive volume boost (gain in millibels) to the just_audio
  /// session via Android's LoudnessEnhancer. Pass gainMb <= 0 to release.
  Future<void> setVolumeBoost({required int gainMb, int? audioSessionId}) async {
    await _channel.invokeMethod<void>('setVolumeBoost', <String, Object?>{
      'gainMb': gainMb,
      'audioSessionId': audioSessionId,
    });
  }

  /// Reads the device equalizer's band count, center frequencies, and level
  /// range. Returns null when unavailable (no session, no effect, or failure).
  Future<EqualizerBandInfo?> getEqualizerBandInfo({
    int? audioSessionId,
  }) async {
    if (audioSessionId == null) return null;
    try {
      final response = await _channel.invokeMethod<Object?>(
        'getEqualizerBandInfo',
        <String, Object?>{'audioSessionId': audioSessionId},
      );
      if (response is! Map) return null;

      final bandCount = (response['bandCount'] as num?)?.toInt();
      final minLevelDb = (response['minLevelDb'] as num?)?.toDouble();
      final maxLevelDb = (response['maxLevelDb'] as num?)?.toDouble();
      final rawFreqs = response['centerFreqsHz'];
      if (bandCount == null ||
          bandCount <= 0 ||
          minLevelDb == null ||
          maxLevelDb == null ||
          rawFreqs is! List) {
        return null;
      }

      final freqs = <double>[];
      for (final value in rawFreqs) {
        if (value is! num) return null;
        freqs.add(value.toDouble());
      }
      if (freqs.length != bandCount) return null;

      return EqualizerBandInfo(
        bandCount: bandCount,
        centerFreqsHz: List<double>.unmodifiable(freqs),
        minLevelDb: minLevelDb,
        maxLevelDb: maxLevelDb,
      );
    } catch (_) {
      return null;
    }
  }
}

class _AndroidAudioProcessingRequest {
  const _AndroidAudioProcessingRequest({
    required this.masterEnabled,
    required this.audioSessionId,
    required this.preampDb,
    required this.gainsDb,
    required this.compressor,
    required this.limiter,
    required this.fx,
  });

  factory _AndroidAudioProcessingRequest.fromState({
    required EqualizerState state,
    required List<double> gainsDb,
    required int? audioSessionId,
    required bool bypassed,
  }) {
    final masterEnabled = state.enabled && !bypassed;

    return _AndroidAudioProcessingRequest(
      masterEnabled: masterEnabled,
      audioSessionId: audioSessionId,
      preampDb: masterEnabled ? state.preampDb : 0.0,
      gainsDb: List<double>.unmodifiable(gainsDb),
      compressor: _AndroidCompressorPayload.fromSettings(
        state.compressor,
        enabled: masterEnabled && state.compressor.enabled,
      ),
      limiter: _AndroidLimiterPayload.fromSettings(
        state.limiter,
        enabled: masterEnabled && state.limiter.enabled,
      ),
      fx: _AndroidFxPayload.fromSettings(
        state.fx,
        enabled: masterEnabled && state.fx.enabled,
      ),
    );
  }

  final bool masterEnabled;
  final int? audioSessionId;
  final double preampDb;
  final List<double> gainsDb;
  final _AndroidCompressorPayload compressor;
  final _AndroidLimiterPayload limiter;
  final _AndroidFxPayload fx;

  bool get hasEqualizer => gainsDb.any(
    (gain) => gain.abs() >= AndroidJustAudioProcessingService._dbEpsilon,
  );

  bool get hasPreamp => preampDb.abs() >= AndroidJustAudioProcessingService._dbEpsilon;

  bool get requiresAudioSession =>
      hasEqualizer ||
      hasPreamp ||
      compressor.enabled ||
      limiter.enabled ||
      fx.hasNativeCounterpart;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'masterEnabled': masterEnabled,
      'audioSessionId': audioSessionId,
      'preampDb': preampDb,
      'gainsDb': gainsDb,
      'compressor': compressor.toMap(),
      'limiter': limiter.toMap(),
      'fx': fx.toMap(),
    };
  }
}

class _AndroidCompressorPayload {
  const _AndroidCompressorPayload({
    required this.enabled,
    required this.thresholdDb,
    required this.ratio,
    required this.attackMs,
    required this.releaseMs,
    required this.makeupGainDb,
  });

  factory _AndroidCompressorPayload.fromSettings(
    CompressorSettings settings, {
    required bool enabled,
  }) {
    return _AndroidCompressorPayload(
      enabled: enabled,
      thresholdDb: settings.thresholdDb,
      ratio: settings.ratio,
      attackMs: settings.attackMs,
      releaseMs: settings.releaseMs,
      makeupGainDb: settings.makeupGainDb,
    );
  }

  final bool enabled;
  final double thresholdDb;
  final double ratio;
  final double attackMs;
  final double releaseMs;
  final double makeupGainDb;

  Map<String, Object> toMap() {
    return <String, Object>{
      'enabled': enabled,
      'thresholdDb': thresholdDb,
      'ratio': ratio,
      'attackMs': attackMs,
      'releaseMs': releaseMs,
      'makeupGainDb': makeupGainDb,
    };
  }
}

class _AndroidLimiterPayload {
  const _AndroidLimiterPayload({
    required this.enabled,
    required this.inputGainDb,
    required this.ceilingDb,
    required this.releaseMs,
  });

  factory _AndroidLimiterPayload.fromSettings(
    LimiterSettings settings, {
    required bool enabled,
  }) {
    return _AndroidLimiterPayload(
      enabled: enabled,
      inputGainDb: settings.inputGainDb,
      ceilingDb: settings.ceilingDb,
      releaseMs: settings.releaseMs,
    );
  }

  final bool enabled;
  final double inputGainDb;
  final double ceilingDb;
  final double releaseMs;

  Map<String, Object> toMap() {
    return <String, Object>{
      'enabled': enabled,
      'inputGainDb': inputGainDb,
      'ceilingDb': ceilingDb,
      'releaseMs': releaseMs,
    };
  }
}

class _AndroidFxPayload {
  const _AndroidFxPayload({
    required this.enabled,
    required this.balance,
    required this.tempo,
    required this.damp,
    required this.filterHz,
    required this.delayMs,
    required this.size,
    required this.mix,
    required this.feedback,
    required this.width,
  });

  factory _AndroidFxPayload.fromSettings(
    FxSettings settings, {
    required bool enabled,
  }) {
    return _AndroidFxPayload(
      enabled: enabled,
      balance: settings.balance,
      tempo: settings.tempo,
      damp: settings.damp,
      filterHz: settings.filterHz,
      delayMs: settings.delayMs,
      size: settings.size,
      mix: settings.mix,
      feedback: settings.feedback,
      width: settings.width,
    );
  }

  final bool enabled;
  final double balance;
  final double tempo;
  final double damp;
  final double filterHz;
  final double delayMs;
  final double size;
  final double mix;
  final double feedback;
  final double width;

  bool get usesReverb => enabled && mix > 0.01;

  bool get usesBalance => enabled && balance.abs() > 0.01;

  bool get usesVirtualizer => enabled && width > 1.01;

  bool get hasNativeCounterpart => usesBalance || usesReverb || usesVirtualizer;

  Map<String, Object> toMap() {
    return <String, Object>{
      'enabled': enabled,
      'balance': balance,
      'tempo': tempo,
      'damp': damp,
      'filterHz': filterHz,
      'delayMs': delayMs,
      'size': size,
      'mix': mix,
      'feedback': feedback,
      'width': width,
    };
  }
}
