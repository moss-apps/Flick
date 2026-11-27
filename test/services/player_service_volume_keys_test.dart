import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

String? _isarCorePath() {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null && File(override).existsSync()) return override;

  final fileName = switch (Abi.current()) {
    Abi.linuxX64 || Abi.linuxArm || Abi.linuxArm64 => 'libisar.so',
    Abi.macosX64 || Abi.macosArm64 => 'libisar.dylib',
    Abi.windowsX64 => 'isar.dll',
    _ => null,
  };
  if (fileName == null) return null;

  // Isolate.resolvePackageUri is unsupported under `flutter test`, so read
  // the package config that pub already generated instead.
  final packageConfig = File(
    p.join(Directory.current.path, '.dart_tool', 'package_config.json'),
  );
  if (!packageConfig.existsSync()) return null;

  final config =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'];
  if (packages is! List) return null;
  for (final package in packages) {
    if (package is! Map<String, dynamic> ||
        package['name'] != 'isar_community_flutter_libs') {
      continue;
    }
    final rootUri = package['rootUri'];
    if (rootUri is! String) return null;
    final root = Directory.fromUri(packageConfig.uri.resolve(rootUri));
    final path = p.join(root.path, Platform.operatingSystem, fileName);
    return File(path).existsSync() ? path : null;
  }
  return null;
}

const _device = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  serial: 'SERIAL',
  deviceName: '/dev/bus/usb/001/002',
);
const _generation = 41;

Uac2DeviceStatus _status({
  Uac2VolumeMode mode = Uac2VolumeMode.hardware,
  double? volume = 0.5,
  bool? muted,
  bool directUsbRegistered = true,
  bool writable = true,
  int? generation = _generation,
}) => Uac2DeviceStatus(
  device: _device,
  state: Uac2State.connected,
  routeType: Uac2RouteType.externalUsb,
  isExternalRoute: true,
  directUsbRegistered: directUsbRegistered,
  volumeMode: mode,
  hasVolumeControl: true,
  volumeControlWritable: writable,
  hardwareVolumeGeneration: generation,
  volume: volume,
  muted: muted,
);

class _Session extends Fake implements AudioSessionManager {
  _Session(AudioEngineType initial)
    : selectedModeNotifier = ValueNotifier(initial),
      initializedModeNotifier = ValueNotifier(initial);

  @override
  final ValueNotifier<AudioEngineType> selectedModeNotifier;
  @override
  final ValueNotifier<AudioEngineType?> initializedModeNotifier;
  @override
  AudioEngineType get selectedMode => selectedModeNotifier.value;
  @override
  AudioEngineType? get initializedMode => initializedModeNotifier.value;
  @override
  String? get fallbackReason => null;
}

class _Usb extends Fake implements Uac2Service {
  _Usb(this.status);

  Uac2DeviceStatus status;
  Completer<void>? writeGate;
  bool writeSucceeds = true;
  double Function(double)? quantize;
  final writes = <double>[];

  @override
  bool isBitPerfectEnabledSync = false;

  @override
  Uac2DeviceStatus get currentDeviceStatus => status;

  @override
  Future<bool> setVolume(
    double volume, {
    bool persist = true,
    bool hardwareSliderCurve = false,
    int? expectedHardwareGeneration,
  }) async {
    if (hardwareSliderCurve) fail('hardware keys use the full DAC range');
    if (expectedHardwareGeneration != status.hardwareVolumeGeneration) {
      fail('a write reached the wrong DAC claim');
    }
    writes.add(volume);
    await writeGate?.future;
    if (!writeSucceeds ||
        expectedHardwareGeneration != status.hardwareVolumeGeneration) {
      return false;
    }
    status = status.copyWith(volume: quantize?.call(volume) ?? volume);
    return true;
  }

  @override
  Future<bool?> verifyHardwareVolumeHealth() async => true;
}

PlayerService _player(
  _Usb usb, {
  AudioEngineType engine = AudioEngineType.usbDacExperimental,
  bool directUsb = true,
}) {
  final session = _Session(engine);
  final player = PlayerService.forTesting(
    sessionManager: session,
    uac2Service: usb,
    directUsb: directUsb,
  );
  addTearDown(session.selectedModeNotifier.dispose);
  addTearDown(session.initializedModeNotifier.dispose);
  addTearDown(player.currentVolumeNotifier.dispose);
  addTearDown(player.volumeTierNotifier.dispose);
  addTearDown(player.usbVolumeSafetyBlockedNotifier.dispose);
  addTearDown(player.volumeKeyFeedbackNotifier.dispose);
  addTearDown(() async {
    // Leaving the hardware tier cancels the DAC health timer.
    session.initializedModeNotifier.value = AudioEngineType.normalAndroid;
    await player.reconcileVolumeForTesting();
  });
  return player;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp('flick_volume_keys');
    final corePath = _isarCorePath();
    if (corePath == null) {
      fail('isar core library not found; set ISAR_CORE_LIB');
    }
    Isar.initializeIsarCore(libraries: {Abi.current(): corePath});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => databaseDir.path,
        );
    await Database.init();
  });

  tearDownAll(() async {
    await Database.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await databaseDir.delete(recursive: true);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('stepDacVolume', () {
    test('moves one sixteenth per press', () {
      expect(stepDacVolume(0.5, 1), 0.5 + 1 / 16);
      expect(stepDacVolume(0.5, -1), 0.5 - 1 / 16);
      expect(dacVolumeKeySteps, 16);
    });

    test('spans the whole range in sixteen presses', () {
      var level = 0.0;
      for (var press = 0; press < dacVolumeKeySteps; press++) {
        level = stepDacVolume(level, 1);
      }
      expect(level, 1.0);
      for (var press = 0; press < dacVolumeKeySteps; press++) {
        level = stepDacVolume(level, -1);
      }
      expect(level, 0.0);
    });

    test('stops at the ends of the range', () {
      expect(stepDacVolume(1.0, 1), 1.0);
      expect(stepDacVolume(0.99, 1), 1.0);
      expect(stepDacVolume(0.0, -1), 0.0);
      expect(stepDacVolume(0.01, -1), 0.0);
    });

    test(
      'steps relative to the verified level, without snapping to a grid',
      () {
        // A level just under a 1/16 boundary must still climb on every press.
        var level = 0.5599;
        for (var press = 0; press < 3; press++) {
          final next = stepDacVolume(level, 1);
          expect(next, greaterThan(level));
          level = next;
        }
      },
    );

    test('ignores a zero direction and a non-finite level', () {
      expect(stepDacVolume(0.4, 0), 0.4);
      expect(stepDacVolume(double.nan, 1).isNaN, isTrue);
    });
  });

  group('shouldRouteVolumeKeysToDac', () {
    bool route({
      VolumeTier tier = VolumeTier.hardware,
      bool directUsb = true,
      bool casting = false,
    }) => shouldRouteVolumeKeysToDac(
      tier: tier,
      isDirectUsbPath: directUsb,
      isCasting: casting,
    );

    test('only a direct USB DAC with hardware volume takes the keys', () {
      expect(route(), isTrue);
    });

    test('every other tier keeps the system volume', () {
      expect(route(tier: VolumeTier.software), isFalse);
      expect(route(tier: VolumeTier.system), isFalse);
      expect(route(tier: VolumeTier.unavailable), isFalse);
    });

    test('no direct USB path keeps the system volume', () {
      expect(route(directUsb: false), isFalse);
    });

    test('casting keeps the cast target volume', () {
      expect(route(casting: true), isFalse);
    });
  });

  group('PlayerService volume keys', () {
    final nativeCalls = <MethodCall>[];

    setUp(() {
      nativeCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.mossapps.flick/player'),
            (call) async {
              nativeCalls.add(call);
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.mossapps.flick/player'),
            null,
          );
    });

    test('a press steps the DAC through the normal volume path', () async {
      final usb = _Usb(_status(volume: 0.5));
      final player = _player(usb);
      expect(player.dacVolumeKeysActive, isTrue);

      await player.stepDacVolumeFromKey(1, generation: _generation);

      expect(usb.writes, [0.5 + 1 / 16]);
      expect(player.currentVolume, 0.5 + 1 / 16);
      expect(player.volumeKeyFeedbackNotifier.value?.level, 0.5 + 1 / 16);

      await player.stepDacVolumeFromKey(-1, generation: _generation);
      await player.stepDacVolumeFromKey(-1, generation: _generation);

      expect(usb.writes.last, closeTo(0.5 - 1 / 16, 1e-9));
    });

    test('repeated presses reach the next coarse hardware step', () async {
      final usb = _Usb(_status())
        ..quantize = (value) => (value * 4).round() / 4;
      final player = _player(usb);

      await player.stepDacVolumeFromKey(1, generation: _generation);
      expect(usb.status.volume, 0.5);
      expect(player.volumeKeyFeedbackNotifier.value?.level, 0.5);
      await player.stepDacVolumeFromKey(1, generation: _generation);

      expect(usb.writes, [0.5625, 0.625]);
      expect(usb.status.volume, 0.75);
      expect(player.volumeKeyFeedbackNotifier.value?.level, 0.75);
    });

    test(
      'a held key builds on the pending level while a write is slow',
      () async {
        final usb = _Usb(_status(volume: 0.5))..writeGate = Completer<void>();
        final player = _player(usb);

        final first = player.stepDacVolumeFromKey(1, generation: _generation);
        final repeat = player.stepDacVolumeFromKey(1, generation: _generation);
        final repeatAgain = player.stepDacVolumeFromKey(
          1,
          generation: _generation,
        );
        await Future<void>.delayed(Duration.zero);
        expect(usb.writes, [0.5 + 1 / 16]); // One write in flight.

        usb.writeGate!.complete();
        await Future.wait([first, repeat, repeatAgain]);

        expect(usb.writes.length, 2); // Repeats coalesced into one more write.
        expect(usb.writes.last, closeTo(0.5 + 3 / 16, 1e-9));
        expect(usb.status.volume, closeTo(0.5 + 3 / 16, 1e-9));
      },
    );

    test(
      'pressing at the top of the range does not write to the DAC',
      () async {
        final usb = _Usb(_status(volume: 1.0));
        final player = _player(usb);

        await player.stepDacVolumeFromKey(1, generation: _generation);

        expect(usb.writes, isEmpty);
        expect(player.volumeKeyFeedbackNotifier.value?.level, 1.0);
      },
    );

    test('a refused write does not show an unverified level', () async {
      final usb = _Usb(_status(volume: 0.5))..writeSucceeds = false;
      final player = _player(usb);

      await player.stepDacVolumeFromKey(1, generation: _generation);

      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      expect(player.volumeKeyFeedbackNotifier.value, isNull);
    });

    test('feedback reports a muted DAC', () async {
      final usb = _Usb(_status(volume: 0.5, muted: true));
      final player = _player(usb);

      await player.stepDacVolumeFromKey(1, generation: _generation);

      expect(player.volumeKeyFeedbackNotifier.value?.muted, isTrue);
    });

    test(
      'without hardware volume authority the keys do nothing here',
      () async {
        final software = _Usb(_status(mode: Uac2VolumeMode.software));
        final softwarePlayer = _player(software);
        expect(softwarePlayer.dacVolumeKeysActive, isFalse);
        await softwarePlayer.stepDacVolumeFromKey(1, generation: _generation);
        expect(software.writes, isEmpty);
        expect(softwarePlayer.volumeKeyFeedbackNotifier.value, isNull);

        final notDirect = _Usb(_status());
        final standardPlayer = _player(
          notDirect,
          engine: AudioEngineType.normalAndroid,
          directUsb: false,
        );
        expect(standardPlayer.dacVolumeKeysActive, isFalse);
        await standardPlayer.stepDacVolumeFromKey(-1, generation: _generation);
        expect(notDirect.writes, isEmpty);
      },
    );

    test('the media session volume panel sets an absolute DAC level', () async {
      final usb = _Usb(_status(volume: 0.5));
      final player = _player(usb);

      await player.setDacVolumeFromSession(0.8, generation: _generation);

      expect(usb.writes, [0.8]);
      expect(player.currentVolume, 0.8);
      expect(player.volumeKeyFeedbackNotifier.value, isNull);
    });

    test('a dragged panel slider keeps only the latest level', () async {
      final usb = _Usb(_status(volume: 0.5))..writeGate = Completer<void>();
      final player = _player(usb);

      final drags = [
        player.setDacVolumeFromSession(0.6, generation: _generation),
        player.setDacVolumeFromSession(0.7, generation: _generation),
        player.setDacVolumeFromSession(0.9, generation: _generation),
      ];
      usb.writeGate!.complete();
      await Future.wait(drags);

      expect(usb.writes, [0.6, 0.9]);
      expect(player.currentVolume, 0.9);
    });

    test('a stale media session cannot move the DAC', () async {
      final usb = _Usb(_status(mode: Uac2VolumeMode.software, volume: 0.5));
      final player = _player(usb);

      await player.setDacVolumeFromSession(0.9, generation: _generation);
      await player.setDacVolumeFromSession(double.nan, generation: _generation);

      expect(usb.writes, isEmpty);
    });

    test('queued keys stop when the DAC loses its registration', () async {
      final usb = _Usb(_status())..writeGate = Completer<void>();
      final player = _player(usb);

      final first = player.stepDacVolumeFromKey(1, generation: _generation);
      final queued = player.setDacVolumeFromSession(
        0.9,
        generation: _generation,
      );
      await Future<void>.delayed(Duration.zero);
      expect(usb.writes, [0.5625]);

      usb.status = _status(directUsbRegistered: false);
      usb.writeGate!.complete();
      await Future.wait([first, queued]);

      expect(usb.writes, [0.5625]);
      expect(player.volumeKeyFeedbackNotifier.value, isNull);
    });

    test('native is told when the DAC takes and gives back the keys', () async {
      final usb = _Usb(_status(volume: 0.4));
      final player = _player(usb);

      player.syncDacVolumeKeysForTesting();
      player.syncDacVolumeKeysForTesting(); // Unchanged: not sent again.
      await Future<void>.delayed(Duration.zero);
      expect(nativeCalls.map((c) => c.method), ['updateDacVolume']);
      expect(nativeCalls.single.arguments, {
        'generation': _generation,
        'volume': 40,
      });

      // The DAC stops being the authority (software tier): keys and session
      // volume go back to the system.
      usb.status = _status(mode: Uac2VolumeMode.software, volume: 0.4);
      player.syncDacVolumeKeysForTesting();
      await Future<void>.delayed(Duration.zero);
      expect(nativeCalls.length, 2);
      expect(nativeCalls.last.arguments, {'generation': null});
    });

    test('an unverified or unclaimed DAC does not capture the keys', () async {
      final usb = _Usb(_status());
      final player = _player(usb);
      for (final status in [
        _status(directUsbRegistered: false),
        _status(writable: false),
        _status(volume: null),
        _status(volume: double.nan),
        _status(generation: null),
      ]) {
        usb.status = status;
        expect(player.dacVolumeKeysActive, isFalse);
        await player.stepDacVolumeFromKey(1, generation: _generation);
      }
      expect(usb.writes, isEmpty);
    });

    test(
      'pending repeats cannot reach a replacement at the same USB path',
      () async {
        final usb = _Usb(_status())..writeGate = Completer<void>();
        final player = _player(usb);
        final first = player.stepDacVolumeFromKey(1, generation: _generation);
        final repeat = player.stepDacVolumeFromKey(1, generation: _generation);
        await Future<void>.delayed(Duration.zero);
        expect(usb.writes, [0.5 + 1 / 16]);

        usb.status = _status(generation: _generation + 1, volume: 0.25);
        usb.writeGate!.complete();
        await Future.wait([first, repeat]);
        await player.setDacVolumeFromSession(0.9, generation: _generation);
        await player.stepDacVolumeFromKey(1, generation: _generation);
        expect(usb.writes, [0.5 + 1 / 16]);
        expect(usb.status.volume, 0.25);
        expect(player.volumeKeyFeedbackNotifier.value, isNull);

        await player.stepDacVolumeFromKey(
          -1,
          generation: _generation + 1,
          showFeedback: false,
        );
        expect(usb.writes.last, 0.25 - 1 / 16);
        expect(player.volumeKeyFeedbackNotifier.value, isNull);
      },
    );

    test(
      'native gets the new claim even when its volume is unchanged',
      () async {
        final usb = _Usb(_status());
        final player = _player(usb);
        player.syncDacVolumeKeysForTesting();

        usb.status = _status(generation: _generation + 1);
        player.syncDacVolumeKeysForTesting();
        await Future<void>.delayed(Duration.zero);

        expect(nativeCalls.last.arguments, {
          'generation': _generation + 1,
          'volume': 50,
        });
      },
    );
  });
}
