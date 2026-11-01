import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_service.dart';

VolumeTier tier({
  bool bitPerfectPath = true,
  bool directUsb = false,
  Uac2VolumeMode? mode,
  bool hwFailed = false,
  bool dop = false,
  bool autoSwitch = false,
  bool passthrough = true,
  bool rust = true,
}) => determineVolumeTier(
  isBitPerfectVolumePath: bitPerfectPath,
  volumeMode: mode,
  hwVolumeFailed: hwFailed,
  isDoP: dop,
  autoSwitchDsdForVolume: autoSwitch,
  isPassthrough: passthrough,
  usingRustBackend: rust,
  isDirectUsbPath: directUsb,
);

void main() {
  group('determineVolumeTier', () {
    test('non-bit-perfect path maps Rust to software, else system', () {
      expect(tier(bitPerfectPath: false, rust: true), VolumeTier.software);
      expect(tier(bitPerfectPath: false, rust: false), VolumeTier.system);
    });

    test('hardware mode is trusted unless the lie-detector fired', () {
      expect(tier(mode: Uac2VolumeMode.hardware), VolumeTier.hardware);
      expect(
        tier(mode: Uac2VolumeMode.hardware, hwFailed: true),
        VolumeTier.unavailable,
      );
    });

    test('no DAC hardware volume: DSP path keeps software gain', () {
      expect(
        tier(mode: Uac2VolumeMode.software, passthrough: false),
        VolumeTier.software,
      );
      expect(
        tier(mode: Uac2VolumeMode.unavailable, passthrough: false),
        VolumeTier.software,
      );
    });

    test('bit-perfect passthrough with no hardware volume is unavailable', () {
      expect(tier(mode: Uac2VolumeMode.software), VolumeTier.unavailable);
      expect(tier(mode: Uac2VolumeMode.unavailable), VolumeTier.unavailable);
      expect(tier(mode: null), VolumeTier.unavailable);
    });

    test('DoP requires hardware volume or the PCM auto-switch', () {
      expect(
        tier(dop: true, mode: Uac2VolumeMode.hardware),
        VolumeTier.hardware,
      );
      expect(
        tier(dop: true, mode: Uac2VolumeMode.software),
        VolumeTier.unavailable,
      );
      expect(
        tier(dop: true, mode: Uac2VolumeMode.software, autoSwitch: true),
        VolumeTier.software,
      );
    });

    test(
      'direct USB keeps DAC hardware authority with PCM bit-perfect off',
      () {
        expect(
          tier(
            bitPerfectPath: false,
            directUsb: true,
            mode: Uac2VolumeMode.hardware,
          ),
          VolumeTier.hardware,
        );
        // The grant is scoped to direct USB: a stale hardware mode on another
        // engine must not steal authority from the software/DSP path.
        expect(
          tier(
            bitPerfectPath: false,
            directUsb: false,
            mode: Uac2VolumeMode.hardware,
          ),
          VolumeTier.software,
        );
      },
    );

    test('direct USB falls back to engine gain without trusted hardware', () {
      expect(
        tier(
          bitPerfectPath: false,
          directUsb: true,
          mode: Uac2VolumeMode.software,
        ),
        VolumeTier.software,
      );
      expect(
        tier(
          bitPerfectPath: false,
          directUsb: true,
          mode: Uac2VolumeMode.hardware,
          hwFailed: true,
        ),
        VolumeTier.software,
      );
      expect(
        tier(bitPerfectPath: false, directUsb: true, mode: null, rust: false),
        VolumeTier.system,
      );
    });

    test('wire DSD stays protected with PCM bit-perfect disabled', () {
      expect(tier(bitPerfectPath: false, dop: true), VolumeTier.unavailable);
      expect(
        tier(bitPerfectPath: false, dop: true, mode: Uac2VolumeMode.hardware),
        VolumeTier.hardware,
      );
      expect(
        tier(bitPerfectPath: false, dop: true, mode: Uac2VolumeMode.hardware,
            hwFailed: true),
        VolumeTier.unavailable,
      );
    });
  });
}
