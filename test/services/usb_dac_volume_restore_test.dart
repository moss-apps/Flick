import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/services/usb_dac_volume_restore.dart';
import 'package:shared_preferences/shared_preferences.dart';

const device = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  serial: 'SERIAL-A',
  deviceName: '/dev/bus/usb/001/002',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final engine in AudioEnginePreference.values) {
    for (final savedVolume in <double?>[null, 0.27, 0.0, 1.0]) {
      test(
        'restores $savedVolume from ${engine.name} before releasing gain',
        () async {
          final prefs = Uac2PreferencesService();
          await prefs.setAudioEnginePreference(engine);
          if (savedVolume != null) {
            await prefs.setUsbVolumeForDevice(device, savedVolume);
          }
          final restore = UsbDacVolumeRestore();
          var hardwareVolume = 1.0;
          var gainReleased = false;

          await restore.restoreHardwareVolume(
            Uac2PreferencesService.usbDeviceVolumeKey(device),
            loadVolume: () => prefs.getUsbVolumeForDevice(device),
            writeVolume: (volume) async {
              expect(gainReleased, isFalse);
              hardwareVolume = volume;
              return true;
            },
          );
          gainReleased = true;

          expect(hardwareVolume, savedVolume ?? 0.40);
          expect(gainReleased, isTrue);
        },
      );
    }
  }

  test(
    'gain waits for both preferences and a verified hardware write',
    () async {
      final restore = UsbDacVolumeRestore();
      final saved = Completer<double>();
      final written = Completer<bool>();
      final writeStarted = Completer<void>();
      var gainReleased = false;
      final handoff = restore
          .restoreHardwareVolume(
            'dac',
            loadVolume: () => saved.future,
            writeVolume: (volume) {
              expect(volume, 0.4);
              writeStarted.complete();
              return written.future;
            },
          )
          .then((_) => gainReleased = true);

      expect(gainReleased, isFalse);
      saved.complete(0.4);
      await writeStarted.future;
      expect(gainReleased, isFalse);
      written.complete(true);
      await handoff;
      expect(gainReleased, isTrue);
    },
  );

  test(
    'failed hardware restore blocks gain release and allows retry',
    () async {
      final restore = UsbDacVolumeRestore();
      var gainReleased = false;
      final handoff = restore
          .restoreHardwareVolume(
            'dac',
            loadVolume: () async => 0.4,
            writeVolume: (_) async => false,
          )
          .then((_) => gainReleased = true);

      await expectLater(handoff, throwsStateError);
      expect(gainReleased, isFalse);
      await restore.restoreHardwareVolume(
        'dac',
        loadVolume: () async => 0.4,
        writeVolume: (_) async => true,
      );
    },
  );

  test(
    'repeated activation does not overwrite a later DAC knob change',
    () async {
      final restore = UsbDacVolumeRestore();
      var hardwareVolume = 1.0;
      Future<void> activate() => restore.restoreHardwareVolume(
        'dac',
        loadVolume: () async => 0.4,
        writeVolume: (volume) async {
          hardwareVolume = volume;
          return true;
        },
      );

      await activate();
      hardwareVolume = 0.6;
      await activate();
      expect(hardwareVolume, 0.6);
      restore.reset(); // Reconnection restores the remembered startup level.
      await activate();
      expect(hardwareVolume, 0.4);
    },
  );

  test(
    'detach during preference loading prevents a stale hardware write',
    () async {
      final restore = UsbDacVolumeRestore();
      final saved = Completer<double>();
      var writes = 0;
      final handoff = restore.restoreHardwareVolume(
        'dac',
        loadVolume: () => saved.future,
        writeVolume: (_) async {
          writes++;
          return true;
        },
      );

      restore.reset();
      saved.complete(0.4);
      await expectLater(handoff, throwsStateError);
      expect(writes, 0);
    },
  );

  test(
    'transport errors remain volume safety refusals rather than fallback reasons',
    () async {
      final restore = UsbDacVolumeRestore();
      await expectLater(
        restore.restoreHardwareVolume(
          'dac',
          loadVolume: () async => 0.4,
          writeVolume: (_) async =>
              throw StateError('Android direct USB write failed'),
        ),
        throwsA(
          isA<UsbDacVolumeRestoreError>().having(
            (error) => error.message,
            'message',
            startsWith(
              'Failed to restore USB DAC hardware volume before playback',
            ),
          ),
        ),
      );
    },
  );

  for (final invalid in [double.nan, double.infinity, -0.1, 1.1]) {
    test('rejects invalid hardware restore target $invalid', () async {
      final restore = UsbDacVolumeRestore();
      var writes = 0;
      await expectLater(
        restore.restoreHardwareVolume(
          'dac',
          loadVolume: () async => invalid,
          writeVolume: (_) async {
            writes++;
            return true;
          },
        ),
        throwsStateError,
      );
      expect(writes, 0);
    });
  }

  test('restores once per DAC/authority key', () async {
    final restore = UsbDacVolumeRestore();
    final generation = restore.connectionGeneration;
    var calls = 0;

    await restore.runOnce('dac|hardware', (_) async => calls++);
    await restore.runOnce('dac|hardware', (_) async => calls++);

    expect(calls, 1);

    await restore.runOnce('dac|software', (_) async => calls++);
    expect(calls, 2);
    // Concurrent route refreshes must not mistake a tier change for detach.
    expect(restore.connectionGeneration, generation);
    restore.reset();
    expect(restore.connectionGeneration, generation + 1);
  });

  test('coalesces concurrent restores for the same key', () async {
    final restore = UsbDacVolumeRestore();
    final release = Completer<void>();
    var calls = 0;

    Future<void> run() => restore.runOnce('dac|hardware', (_) async {
      calls++;
      await release.future;
    });

    final first = run();
    final second = run();
    expect(calls, 1);
    release.complete();
    await Future.wait([first, second]);

    expect(calls, 1);
  });

  test('a failed restore is retried on the next attempt', () async {
    final restore = UsbDacVolumeRestore();
    var attempts = 0;

    await expectLater(
      restore.runOnce('dac|hardware', (_) async {
        attempts++;
        throw StateError('write failed');
      }),
      throwsStateError,
    );
    await restore.runOnce('dac|hardware', (_) async => attempts++);

    expect(attempts, 2);
  });

  test('reset cancels work waiting on a route change', () async {
    final restore = UsbDacVolumeRestore();
    final started = Completer<void>();
    final release = Completer<void>();

    final future = restore.runOnce('dac|hardware', (ensureCurrent) async {
      started.complete();
      await release.future;
      ensureCurrent();
    });
    await started.future;
    restore.reset();
    release.complete();

    await expectLater(
      future,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('route changed'),
        ),
      ),
    );
  });

  test('reset allows the same key to restore again', () async {
    final restore = UsbDacVolumeRestore();
    var calls = 0;

    await restore.runOnce('dac|hardware', (_) async => calls++);
    restore.reset();
    await restore.runOnce('dac|hardware', (_) async => calls++);

    expect(calls, 2);
  });
}
