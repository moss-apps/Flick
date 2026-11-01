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
