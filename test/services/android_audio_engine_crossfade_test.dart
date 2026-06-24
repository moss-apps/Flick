import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/android_audio_engine.dart';

void main() {
  group('crossfadeInVolume', () {
    test('endpoints are 0 at start and 1 at end for every curve', () {
      for (final curve in AndroidCrossfadeCurve.values) {
        expect(crossfadeInVolume(curve, 0), closeTo(0.0, 1e-9));
        expect(crossfadeInVolume(curve, 1), closeTo(1.0, 1e-9));
      }
    });

    test('outgoing fraction is the symmetric complement (1 - p)', () {
      // out(p) == in(1 - p) keeps each curve symmetric; for equal-power this is
      // exactly cos/sin so out^2 + in^2 == 1 throughout.
      for (final curve in AndroidCrossfadeCurve.values) {
        for (final p in [0.0, 0.1, 0.25, 0.5, 0.73, 0.9, 1.0]) {
          final incoming = crossfadeInVolume(curve, p);
          final outgoing = crossfadeInVolume(curve, 1 - p);
          expect(incoming, inInclusiveRange(0.0, 1.0));
          expect(outgoing, inInclusiveRange(0.0, 1.0));
          if (curve == AndroidCrossfadeCurve.equalPower) {
            expect(
              incoming * incoming + outgoing * outgoing,
              closeTo(1.0, 1e-9),
            );
          }
        }
      }
    });

    test('linear maps progress directly; sqrt and s-curve differ', () {
      expect(crossfadeInVolume(AndroidCrossfadeCurve.linear, 0.5), 0.5);
      expect(
        crossfadeInVolume(AndroidCrossfadeCurve.squareRoot, 0.5),
        closeTo(math.sqrt(0.5), 1e-9),
      );
      // smoothstep: p*p*(3 - 2p) at 0.5 == 0.5, but shaped differently.
      expect(
        crossfadeInVolume(AndroidCrossfadeCurve.sCurve, 0.5),
        closeTo(0.5, 1e-9),
      );
      // At 0.25 linear=0.25 but s-curve is lower (ease-in).
      expect(
        crossfadeInVolume(AndroidCrossfadeCurve.sCurve, 0.25),
        closeTo(0.15625, 1e-9),
      );
    });

    test('clamps progress outside 0..1', () {
      for (final curve in AndroidCrossfadeCurve.values) {
        expect(crossfadeInVolume(curve, -0.5), closeTo(0.0, 1e-9));
        expect(crossfadeInVolume(curve, 1.5), closeTo(1.0, 1e-9));
      }
    });
  });

  group('shouldArmCrossfade', () {
    const dur = Duration(minutes: 3);

    test('never arms when disabled', () {
      expect(
        shouldArmCrossfade(
          enabled: false,
          duration: dur,
          position: dur - const Duration(seconds: 1),
          fadeSecs: 3,
        ),
        isFalse,
      );
    });

    test('arms exactly inside the fade window', () {
      expect(
        shouldArmCrossfade(
          enabled: true,
          duration: dur,
          position: dur - const Duration(seconds: 3),
          fadeSecs: 3,
        ),
        isTrue,
      );
      expect(
        shouldArmCrossfade(
          enabled: true,
          duration: dur,
          position: dur - const Duration(seconds: 4),
          fadeSecs: 3,
        ),
        isFalse,
      );
    });

    test('does not arm for tracks shorter than the fade', () {
      expect(
        shouldArmCrossfade(
          enabled: true,
          duration: const Duration(seconds: 2),
          position: Duration.zero,
          fadeSecs: 3,
        ),
        isFalse,
      );
    });

    test('does not arm when duration is unknown', () {
      expect(
        shouldArmCrossfade(
          enabled: true,
          duration: Duration.zero,
          position: Duration.zero,
          fadeSecs: 3,
        ),
        isFalse,
      );
    });
  });
}
