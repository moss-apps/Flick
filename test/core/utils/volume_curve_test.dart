import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/utils/volume_curve.dart';

void main() {
  group('softwareVolumeToDb', () {
    test('matches the Rust engine curve', () {
      expect(softwareVolumeToDb(1.0), 0.0);
      expect(softwareVolumeToDb(0.5), closeTo(-20.0, 1e-9));
      expect(softwareVolumeToDb(0.25), closeTo(-30.0, 1e-9));
      expect(softwareVolumeToDb(0.0), double.negativeInfinity);
    });

    test('extended volume scales gain linearly', () {
      expect(softwareVolumeToDb(2.0), closeTo(6.0206, 0.0001));
    });
  });

  group('formatSoftwareVolumeDb', () {
    test('formats one decimal and silence', () {
      expect(formatSoftwareVolumeDb(0.0), '-∞');
      expect(formatSoftwareVolumeDb(1.0), '0.0');
      expect(formatSoftwareVolumeDb(0.5), '-20.0');
      expect(formatSoftwareVolumeDb(0.13), '-34.8');
    });
  });

  group('legacyUsbDacVolumeToCurrent', () {
    // Same numbers as the floored-curve tests in
    // rust/src/uac2/volume_control.rs: a DAC spanning -127..0 dB.
    const wideMin = -127 * 256;

    test('keeps the attenuation, not the fraction', () {
      // 50 % covered the whole range, -63.5 dB; on the -80..0 dB slider that
      // attenuation sits at 20.625 %, not 50 % (-40 dB).
      expect(
        legacyUsbDacVolumeToCurrent(0.5, minRaw: wideMin, maxRaw: 0),
        closeTo(0.20625, 1e-12),
      );
      expect(
        legacyUsbDacVolumeToCurrent(0.6, minRaw: wideMin, maxRaw: 0),
        closeTo(0.365, 1e-12),
      );
    });

    test('is never louder than the level that was saved', () {
      for (var step = 0; step <= 100; step++) {
        final legacy = step / 100;
        final current = legacyUsbDacVolumeToCurrent(
          legacy,
          minRaw: wideMin,
          maxRaw: 0,
        )!;
        final savedRaw = wideMin + legacy * -wideMin;
        final restoredRaw =
            usbDacVolumeFloorRaw + current * -usbDacVolumeFloorRaw;
        expect(
          restoredRaw,
          lessThanOrEqualTo(math.max(savedRaw, usbDacVolumeFloorRaw) + 1e-9),
          reason: 'legacy $legacy',
        );
      }
    });

    test('ends of the slider stay put', () {
      expect(legacyUsbDacVolumeToCurrent(0.0, minRaw: wideMin, maxRaw: 0), 0.0);
      expect(legacyUsbDacVolumeToCurrent(1.0, minRaw: wideMin, maxRaw: 0), 1.0);
    });

    test('a level below the floor becomes the bottom of the slider', () {
      // 20 % was -101.6 dB, quieter than anything the slider now reaches.
      expect(legacyUsbDacVolumeToCurrent(0.2, minRaw: wideMin, maxRaw: 0), 0.0);
    });

    test('a DAC whose range is not wider than the floor is unchanged', () {
      expect(
        legacyUsbDacVolumeToCurrent(0.3, minRaw: -60 * 256, maxRaw: 0),
        closeTo(0.3, 1e-12),
      );
      // Maximum below the floor: the floor does not apply at all.
      expect(
        legacyUsbDacVolumeToCurrent(0.3, minRaw: -120 * 256, maxRaw: -90 * 256),
        closeTo(0.3, 1e-12),
      );
    });

    test('an unusable range or level gives no conversion', () {
      expect(legacyUsbDacVolumeToCurrent(0.5, minRaw: 0, maxRaw: 0), isNull);
      expect(
        legacyUsbDacVolumeToCurrent(double.nan, minRaw: wideMin, maxRaw: 0),
        isNull,
      );
    });
  });

  test('ducking multiplies linear gain, not the slider coordinate', () {
    final hardwareDuck = attenuateSoftwareVolume(1.0, 0.2);
    final softwareDuck = attenuateSoftwareVolume(0.5, 0.2);
    expect(softwareVolumeToDb(hardwareDuck), closeTo(-13.9794, 0.0001));
    expect(softwareVolumeToDb(softwareDuck), closeTo(-33.9794, 0.0001));
    expect(attenuateSoftwareVolume(0.0, 0.2), 0.0);
    expect(attenuateSoftwareVolume(0.1, 0.2), 0.0);
    expect(attenuateSoftwareVolume(2.0, 0.2), closeTo(0.80103, 0.00001));
  });
}
