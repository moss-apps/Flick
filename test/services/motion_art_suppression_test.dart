import 'package:flutter_test/flutter_test.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/services/player_service.dart';

void main() {
  group('shouldSuppressMotionArt', () {
    test('suppresses DAP internal bit-perfect by default', () {
      expect(
        shouldSuppressMotionArt(
          bitPerfectEnabled: true,
          engine: AudioEngineType.dapInternalHighRes,
          allowDuringBitPerfect: false,
        ),
        isTrue,
      );
    });

    test('suppresses USB DAC bit-perfect by default', () {
      expect(
        shouldSuppressMotionArt(
          bitPerfectEnabled: true,
          engine: AudioEngineType.usbDacExperimental,
          allowDuringBitPerfect: false,
        ),
        isTrue,
      );
    });

    test('never suppresses when bit-perfect is disabled', () {
      for (final engine in AudioEngineType.values) {
        expect(
          shouldSuppressMotionArt(
            bitPerfectEnabled: false,
            engine: engine,
            allowDuringBitPerfect: false,
          ),
          isFalse,
          reason: '$engine with bit-perfect off',
        );
      }
    });

    test('opt-in keeps motion art during bit-perfect', () {
      expect(
        shouldSuppressMotionArt(
          bitPerfectEnabled: true,
          engine: AudioEngineType.dapInternalHighRes,
          allowDuringBitPerfect: true,
        ),
        isFalse,
      );
    });

    test('non-exclusive engines are never suppressed', () {
      expect(
        shouldSuppressMotionArt(
          bitPerfectEnabled: true,
          engine: AudioEngineType.normalAndroid,
          allowDuringBitPerfect: false,
        ),
        isFalse,
      );
      expect(
        shouldSuppressMotionArt(
          bitPerfectEnabled: true,
          engine: AudioEngineType.rustOboe,
          allowDuringBitPerfect: false,
        ),
        isFalse,
      );
    });
  });
}
