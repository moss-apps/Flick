import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/song.dart';
import 'package:flick/core/utils/volume_curve.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/uac2_provider.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/rust_audio_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/widgets/uac2/uac2_volume_control.dart';
import 'package:flick/widgets/uac2/usb_bit_perfect_prompt.dart';
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

const _attachedDevice = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  deviceName: '/dev/bus/usb/001/002',
);
const _authorizedDevice = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  serial: 'AUTHORIZED-SERIAL',
  deviceName: '/dev/bus/usb/001/002',
);

Uac2DeviceStatus _status(Uac2DeviceInfo device, {bool hardware = false}) =>
    Uac2DeviceStatus(
      device: device,
      state: Uac2State.connected,
      routeType: Uac2RouteType.externalUsb,
      isExternalRoute: true,
      directUsbRegistered: device.serial != null,
      volumeMode: hardware ? Uac2VolumeMode.hardware : Uac2VolumeMode.software,
      hasVolumeControl: true,
      volume: 1.0,
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
  Future<void> syncRouteSelection({required String reason}) async {
    expect(
      await Uac2PreferencesService().getAudioEnginePreference(),
      AudioEnginePreference.isochronousUsb,
    );
    // Like the real session manager, selection does not attach an engine.
    selectedModeNotifier.value = AudioEngineType.usbDacExperimental;
  }
}

class _Usb extends Fake implements Uac2Service {
  _Usb({this.hardware = false});

  bool hardware;
  Completer<void>? permission;
  Completer<void>? volumeWrite;
  Completer<bool?>? healthCheck;
  bool activationSucceeds = true;
  bool volumeWriteSucceeds = true;
  bool volumeWritable = true;
  bool hardwareHealthy = true;
  double initialHardwareVolume = 1.0;
  final writes = <double>[];
  int refreshes = 0;
  Uac2DeviceStatus status = _status(_attachedDevice);

  @override
  bool isBitPerfectEnabledSync = false;
  @override
  Uac2DeviceStatus get currentDeviceStatus => status;

  @override
  Future<bool> setBitPerfectEnabled(bool enabled, {bool persist = true}) async {
    await permission?.future;
    if (!activationSucceeds) return false;
    isBitPerfectEnabledSync = enabled;
    status = _status(_authorizedDevice, hardware: hardware).copyWith(
      volumeControlWritable: volumeWritable,
      volume: initialHardwareVolume,
    );
    return true;
  }

  @override
  Future<void> refreshAndroidRouteStatus({
    Uac2AudioFormat? formatOverride,
    bool? isPlaying,
    bool? hasActiveSong,
  }) async {
    refreshes++;
  }

  @override
  Future<bool> setVolume(double volume, {bool persist = true}) async {
    writes.add(volume);
    await volumeWrite?.future;
    if (!volumeWriteSucceeds) return false;
    status = status.copyWith(volume: volume);
    if (persist) {
      await Uac2PreferencesService().setUsbVolumeForDevice(
        status.device,
        volume,
        authority: UsbVolumeAuthority.hardware,
      );
    }
    return true;
  }

  @override
  Future<bool?> verifyHardwareVolumeHealth() async =>
      healthCheck == null ? hardwareHealthy : await healthCheck!.future;
}

class _Rust extends Fake implements RustAudioService {
  final commands = <Object>[];
  Completer<void>? pauseCompletion;
  bool pauseFails = false;
  bool stopFails = false;

  @override
  bool get isInitialized => true;

  @override
  Future<void> setVolume(double volume) async => commands.add(volume);

  @override
  Future<void> pause() async {
    commands.add('pause');
    await pauseCompletion?.future;
    if (pauseFails) throw StateError('pause failed');
  }

  @override
  Future<void> stop() async {
    commands.add('stop');
    if (stopFails) throw StateError('stop failed');
  }
}

const _song = Song(
  id: 'pcm',
  title: 'PCM',
  artist: 'Test',
  duration: Duration(minutes: 1),
  fileType: 'FLAC',
  filePath: '/music/test.flac',
);

class _Status extends Uac2DeviceStatusNotifier {
  @override
  Uac2DeviceStatus build() => _status(_attachedDevice);
}

PlayerService _player(AudioEngineType initial, _Usb usb, {_Rust? rust}) {
  final session = _Session(initial);
  final player = PlayerService.forTesting(
    sessionManager: session,
    uac2Service: usb,
    rustAudioService: rust,
    directUsb: rust != null,
  );
  player.usingRustBackendNotifier.value = rust != null;
  addTearDown(session.selectedModeNotifier.dispose);
  addTearDown(session.initializedModeNotifier.dispose);
  addTearDown(player.currentVolumeNotifier.dispose);
  addTearDown(player.volumeTierNotifier.dispose);
  addTearDown(player.usbVolumeSafetyBlockedNotifier.dispose);
  addTearDown(player.usingRustBackendNotifier.dispose);
  addTearDown(() async {
    session.initializedModeNotifier.value = AudioEngineType.normalAndroid;
    await player
        .reconcileVolumeForTesting(); // Cancel the hardware health timer.
  });
  return player;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp('flick_usb_volume');
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

  for (final initial in [
    AudioEngineType.normalAndroid,
    AudioEngineType.rustOboe,
  ]) {
    for (final saved in <double?>[null, 0.27, 0.0, 1.0]) {
      test(
        'idle ${initial.name} restores $saved without first playback',
        () async {
          final prefs = Uac2PreferencesService();
          await prefs.setAudioEnginePreference(
            initial == AudioEngineType.normalAndroid
                ? AudioEnginePreference.exoPlayer
                : AudioEnginePreference.rustOboe,
          );
          if (saved != null) {
            await prefs.setUsbVolumeForDevice(_authorizedDevice, saved);
          }
          final usb = _Usb();
          final player = _player(initial, usb);
          expect(player.currentVolume, 1.0);

          expect(await player.enableUsbDacBitPerfect(), isTrue);

          expect(player.currentVolume, saved ?? 0.4);
          expect(player.currentVolumeNotifier.value, saved ?? 0.4);
          expect(player.currentEngineType, initial); // No engine/track started.
          expect(player.currentSongNotifier.value, isNull);
          expect(player.isPlayingNotifier.value, isFalse);
          expect(usb.refreshes, 1);
          expect(
            usb.writes,
            isEmpty,
          ); // Shared Android volume is not DAC volume.
        },
      );
    }

    testWidgets('${initial.name} auto-engage shows 40% before first play', (
      tester,
    ) async {
      await Uac2PreferencesService().setAudioEnginePreference(
        initial == AudioEngineType.normalAndroid
            ? AudioEnginePreference.exoPlayer
            : AudioEnginePreference.rustOboe,
      );
      final usb = _Usb()..permission = Completer<void>();
      final player = _player(initial, usb);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerServiceProvider.overrideWithValue(player),
            uac2ServiceProvider.overrideWithValue(usb),
            uac2DeviceStatusProvider.overrideWith(_Status.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [UsbBitPerfectPrompt(), Uac2VolumeControl()],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 1.0);
      expect(player.currentSongNotifier.value, isNull);

      usb.permission!.complete(); // Accept Android's exclusive USB prompt.
      await tester.pumpAndSettle();

      expect(player.currentVolume, 0.4);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.4);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(player.currentEngineType, initial);
      expect(player.currentSongNotifier.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test(
    'idle handoff verifies hardware volume before reporting success',
    () async {
      final usb = _Usb(hardware: true);
      final player = _player(AudioEngineType.normalAndroid, usb);

      expect(await player.enableUsbDacBitPerfect(), isTrue);
      expect(usb.writes, [0.4]);
      expect(usb.status.volume, 0.4);
      expect(player.currentVolume, 0.4);
    },
  );

  test(
    'idle handoff does not report success when a hardware restore fails',
    () async {
      final usb = _Usb(hardware: true)..volumeWriteSucceeds = false;
      final player = _player(AudioEngineType.rustOboe, usb);

      expect(await player.enableUsbDacBitPerfect(), isFalse);
      expect(usb.writes, [0.4]);
      expect(player.isPlayingNotifier.value, isFalse);
    },
  );

  test(
    'failed USB activation does not publish a fictitious 40% volume',
    () async {
      final usb = _Usb()..activationSucceeds = false;
      final player = _player(AudioEngineType.normalAndroid, usb);

      expect(await player.enableUsbDacBitPerfect(), isFalse);
      expect(player.currentVolume, 1.0);
      expect(usb.refreshes, 0);
      expect(usb.writes, isEmpty);
    },
  );

  test(
    'legacy volume automatically restores the low hardware default',
    () async {
      final prefs = Uac2PreferencesService();
      await prefs.setUsbVolumeForDevice(_authorizedDevice, 0.5);
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );

      expect(await player.enableUsbDacBitPerfect(), isTrue);
      expect(usb.writes, [0.4]);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(rust.commands, isEmpty);
      await player.restoreUsbVolumeForTesting();
      expect(rust.commands, [1.0]);
      expect(
        player.isPlayingNotifier.value,
        isFalse,
      ); // Restore does not start audio.
      final saved = await prefs.getUsbVolumeSettingsForDevice(
        _authorizedDevice,
      );
      expect(saved.hardware, 0.4);
      expect(saved.software, 0.5);
      expect(usb.writes, [0.4]); // Healthy resume leaves the DAC level alone.
    },
  );

  test(
    'failed hardware write pauses without software fallback or preference corruption',
    () async {
      final prefs = Uac2PreferencesService();
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      usb.isBitPerfectEnabledSync = false;
      await player.setVolume(0.2);
      rust.commands.clear();
      usb.volumeWriteSucceeds = false;

      await player.setVolume(0.8);
      expect(rust.commands, ['pause']); // No setVolume(0.8), no unity release.
      expect(player.currentVolume, 0.2);
      expect(usb.status.volume, 0.2);
      expect(
        player.volumeTierNotifier.value,
        VolumeTier.hardware,
      ); // Allow retry.
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      final saved = await prefs.getUsbVolumeSettingsForDevice(
        _authorizedDevice,
      );
      expect(saved.hardware, 0.2);
      expect(saved.software, 0.4);
      await player.reconcileVolumeForTesting();
      expect(rust.commands, ['pause']);
      await expectLater(player.restoreUsbVolumeForTesting(), throwsStateError);
      expect(rust.commands, [
        'pause',
      ]); // An actual write failure stays stopped.
      usb.volumeWriteSucceeds = true;
      await player.restoreUsbVolumeForTesting();
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(rust.commands, ['pause', 1.0]);
      expect(usb.writes, [0.4, 0.2, 0.8, 0.2, 0.2]);
      expect(player.currentVolume, 0.2);
      expect(player.isPlayingNotifier.value, isFalse);
    },
  );

  for (final level in [0.0, 0.08, 0.4]) {
    test('legacy restore keeps an already-low DAC level of $level', () async {
      final prefs = Uac2PreferencesService();
      await prefs.setUsbVolumeForDevice(_authorizedDevice, 0.6);
      final usb = _Usb(hardware: true)..initialHardwareVolume = level;
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );

      expect(await player.enableUsbDacBitPerfect(), isTrue);
      expect(usb.writes, [
        level,
      ]); // Same-level write verifies the low readback.
      await player.restoreUsbVolumeForTesting();
      expect(player.currentVolume, level);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(rust.commands, [1.0]);
      final saved = await prefs.getUsbVolumeSettingsForDevice(
        _authorizedDevice,
      );
      expect(saved.hardware, level);
      expect(saved.software, 0.6); // Never convert software units to hardware.
    });
  }

  test(
    'a lower DAC readback wins over a higher remembered hardware level',
    () async {
      final prefs = Uac2PreferencesService();
      await prefs.setUsbVolumeForDevice(
        _authorizedDevice,
        0.8,
        authority: UsbVolumeAuthority.hardware,
      );
      final usb = _Usb(hardware: true)..initialHardwareVolume = 0.1;
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: _Rust(),
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      expect(usb.writes, isEmpty);
      expect(player.currentVolume, 0.1);
      expect(
        (await prefs.getUsbVolumeSettingsForDevice(_authorizedDevice)).hardware,
        0.1,
      );
    },
  );

  test('healthy playback is not capped at the low recovery default', () async {
    final usb = _Usb(hardware: true);
    final rust = _Rust();
    final player = _player(AudioEngineType.usbDacExperimental, usb, rust: rust);
    expect(await player.enableUsbDacBitPerfect(), isTrue);
    await player.setVolume(0.8);
    await player.restoreUsbVolumeForTesting();
    expect(usb.writes, [0.4, 0.8]);
    expect(player.currentVolume, 0.8);
    expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
  });

  test(
    'Play retries after a readback failure despite a cached successful restore',
    () async {
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      await player.restoreUsbVolumeForTesting();
      usb.volumeWriteSucceeds = false;
      await player.setVolume(0.7);
      usb.status = usb.status.copyWith(volume: 0.05);
      usb.volumeWriteSucceeds = true;
      rust.commands.clear();

      await player.restoreUsbVolumeForTesting(); // No slider gesture.
      expect(usb.writes, [0.4, 0.7, 0.05]);
      expect(player.currentVolume, 0.05);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(rust.commands, [1.0]);
      await player.restoreUsbVolumeForTesting();
      expect(usb.writes, [0.4, 0.7, 0.05]);
    },
  );

  test(
    'automatic recovery waits for a pending safety pause before its write',
    () async {
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      rust.pauseCompletion = Completer<void>();
      usb.volumeWriteSucceeds = false;
      final failure = player.setVolume(0.8);
      await Future<void>.delayed(Duration.zero);
      usb.volumeWriteSucceeds = true;
      final retry = player.restoreUsbVolumeForTesting();
      await Future<void>.delayed(Duration.zero);
      expect(usb.writes, [0.4, 0.8]);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      rust.pauseCompletion!.complete();
      await Future.wait([failure, retry]);
      expect(usb.writes, [0.4, 0.8, 0.4]);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(player.isPlayingNotifier.value, isFalse);
    },
  );

  test(
    'an unapproved hardware slider choice pauses before releasing engine gain',
    () async {
      final usb = _Usb(hardware: true)
        ..status = _status(_authorizedDevice, hardware: true);
      final rust = _Rust()..pauseCompletion = Completer<void>();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      player.currentSongNotifier.value = _song;

      final write = player.setVolume(0.1);
      await Future<void>.delayed(Duration.zero);
      expect(rust.commands, ['pause']);
      expect(usb.writes, isEmpty);
      rust.pauseCompletion!.complete();
      await write;
      expect(usb.writes, [0.1]);
      expect(rust.commands, ['pause', 1.0]);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
    },
  );

  test(
    'read-only hardware cannot bypass the pre-playback safety barrier',
    () async {
      final usb = _Usb(hardware: true)..volumeWritable = false;
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isFalse);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      expect(usb.writes, isEmpty);
      expect(rust.commands, ['pause']);
    },
  );

  test(
    'processing preferences keep a safety refusal handled and paused',
    () async {
      final usb = _Usb(hardware: true)..volumeWriteSucceeds = false;
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isFalse);
      await player.applyCrossfeedSettings();
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      expect(rust.commands, ['pause']);
      expect(usb.writes, [0.4, 0.4]);
    },
  );

  testWidgets(
    'hardware readback failure pauses without reinterpreting its level',
    (tester) async {
      final usb = _Usb(hardware: true)..hardwareHealthy = false;
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      usb.isBitPerfectEnabledSync = false;
      await player.reconcileVolumeForTesting();
      rust.commands.clear();
      await tester.pump(const Duration(seconds: 5));
      expect(rust.commands, ['pause']);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      expect(player.currentVolume, 0.4);
      expect(player.volumeTierNotifier.value, VolumeTier.hardware);
    },
  );

  testWidgets(
    'stale health failure cannot block a newer verified slider choice',
    (tester) async {
      final usb = _Usb(hardware: true)..healthCheck = Completer<bool?>();
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      await player.reconcileVolumeForTesting();
      await tester.pump(const Duration(seconds: 5));
      await player.setVolume(0.1);
      rust.commands.clear();
      usb.healthCheck!.complete(false);
      await tester.pump();
      expect(rust.commands, isEmpty);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(player.currentVolume, 0.1);
      // Widget-test invariants run before addTearDown cancels service timers.
      usb.status = _status(_authorizedDevice);
      await player.reconcileVolumeForTesting();
    },
  );

  testWidgets(
    'stale health failure cannot relatch a verified automatic recovery',
    (tester) async {
      final usb = _Usb(hardware: true)..healthCheck = Completer<bool?>();
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      await player.restoreUsbVolumeForTesting();
      await tester.pump(const Duration(seconds: 5)); // Hold a health readback.
      usb.volumeWriteSucceeds = false;
      await player.setVolume(0.8);
      usb.volumeWriteSucceeds = true;
      await player.restoreUsbVolumeForTesting();
      rust.commands.clear();
      usb.healthCheck!.complete(false);
      await tester.pump();
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(rust.commands, isEmpty);
      usb.status = _status(_authorizedDevice);
      await player.reconcileVolumeForTesting(); // Cancel the periodic timer.
    },
  );

  test(
    'hardware discovered after software playback recovers on Play without a slider gesture',
    () async {
      final prefs = Uac2PreferencesService();
      await prefs.setUsbVolumeForDevice(
        _authorizedDevice,
        0.5,
        authority: UsbVolumeAuthority.software,
      );
      await prefs.setUsbVolumeForDevice(
        _authorizedDevice,
        0.3,
        authority: UsbVolumeAuthority.hardware,
      );
      final usb = _Usb();
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      usb.isBitPerfectEnabledSync = false;
      player.currentSongNotifier.value = _song;
      await player.reconcileVolumeForTesting();
      expect(rust.commands, [0.5]);
      usb.hardware = true;
      usb.status = _status(
        _authorizedDevice,
        hardware: true,
      ).copyWith(volume: 0.6);
      await player.reconcileVolumeForTesting();
      expect(rust.commands, [
        0.5,
        'pause',
      ]); // Never strip the -20 dB attenuation live.
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      expect(usb.writes, isEmpty);
      await player.restoreUsbVolumeForTesting();
      expect(rust.commands, [0.5, 'pause', 1.0]);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(usb.writes, [0.3]);
      expect(
        (await prefs.getUsbVolumeSettingsForDevice(_authorizedDevice)).hardware,
        0.3,
      );
    },
  );

  for (final authorityLost in [false, true]) {
    test(
      'handoff rechecks the DAC after pausing (authorityLost=$authorityLost)',
      () async {
        await Uac2PreferencesService().setUsbVolumeForDevice(
          _authorizedDevice,
          0.5,
          authority: UsbVolumeAuthority.software,
        );
        final usb = _Usb();
        final rust = _Rust();
        final player = _player(
          AudioEngineType.usbDacExperimental,
          usb,
          rust: rust,
        );
        expect(await player.enableUsbDacBitPerfect(), isTrue);
        usb.isBitPerfectEnabledSync = false;
        player.currentSongNotifier.value = _song;
        await player.reconcileVolumeForTesting();
        usb.status = _status(
          _authorizedDevice,
          hardware: true,
        ).copyWith(volume: 0.6);
        rust.pauseCompletion = Completer<void>();

        final retry = player.restoreUsbVolumeForTesting();
        final refused = authorityLost
            ? expectLater(retry, throwsStateError)
            : null;
        await Future<void>.delayed(Duration.zero);
        expect(rust.commands, [0.5, 'pause']);
        expect(usb.writes, isEmpty);

        usb.status = _status(
          _authorizedDevice,
          hardware: !authorityLost,
        ).copyWith(volume: 0.05);
        rust.pauseCompletion!.complete();
        if (refused != null) {
          await refused;
        } else {
          await retry;
        }
        expect(usb.writes, authorityLost ? isEmpty : [0.05]);
        expect(player.usbVolumeSafetyBlockedNotifier.value, authorityLost);
        expect(
          rust.commands,
          authorityLost ? [0.5, 'pause'] : [0.5, 'pause', 1.0],
        );
        expect(player.isPlayingNotifier.value, isFalse);
      },
    );
  }

  test(
    'recovery waits for the safety pause before changing DAC gain',
    () async {
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      rust.commands.clear();
      usb.writes.clear();
      usb.volumeWriteSucceeds = false;
      rust.pauseCompletion = Completer<void>();
      final failure = player.setVolume(0.8);
      await Future<void>.delayed(Duration.zero);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);

      usb.volumeWriteSucceeds = true;
      final recovery = player.setVolume(0.1);
      await Future<void>.delayed(Duration.zero);
      expect(usb.writes, [0.8]);
      expect(rust.commands, ['pause']);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);

      rust.pauseCompletion!.complete();
      await Future.wait([failure, recovery]);
      expect(usb.writes, [0.8, 0.1]);
      expect(rust.commands, ['pause', 1.0]);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(player.isPlayingNotifier.value, isFalse);
    },
  );

  for (final stopFails in [false, true]) {
    test(
      'a failed pause stops the transport before recovery (stopFails=$stopFails)',
      () async {
        final usb = _Usb(hardware: true);
        final rust = _Rust()
          ..pauseFails = true
          ..stopFails = stopFails;
        final player = _player(
          AudioEngineType.usbDacExperimental,
          usb,
          rust: rust,
        );
        expect(await player.enableUsbDacBitPerfect(), isTrue);
        rust.commands.clear();
        usb.writes.clear();
        usb.volumeWriteSucceeds = false;
        await player.setVolume(0.8);
        expect(rust.commands, ['pause', 'stop']);
        usb.volumeWriteSucceeds = true;
        await player.setVolume(0.1);
        expect(usb.writes, stopFails ? [0.8] : [0.8, 0.1]);
        expect(player.usbVolumeSafetyBlockedNotifier.value, stopFails);
      },
    );
  }

  test('a late hardware write cannot approve a different DAC', () async {
    final usb = _Usb(hardware: true);
    final rust = _Rust();
    final player = _player(AudioEngineType.usbDacExperimental, usb, rust: rust);
    expect(await player.enableUsbDacBitPerfect(), isTrue);
    rust.commands.clear();
    usb.volumeWrite = Completer<void>();
    final write = player.setVolume(0.8);
    await Future<void>.delayed(Duration.zero);
    usb.status = _status(_attachedDevice, hardware: true);
    usb.volumeWrite!.complete();
    await write;
    expect(player.currentVolume, 0.4);
    expect(rust.commands, isEmpty);
    await player.reconcileVolumeForTesting();
    expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
    expect(rust.commands, ['pause']);
  });

  test(
    'hardware loss stays stopped rather than using the hardware percentage as software',
    () async {
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
      );
      expect(await player.enableUsbDacBitPerfect(), isTrue);
      usb.isBitPerfectEnabledSync = false;
      await player.reconcileVolumeForTesting();
      rust.commands.clear();
      usb.status = _status(_authorizedDevice);
      await player.reconcileVolumeForTesting();
      expect(rust.commands, ['pause']);
      await player.setVolume(0.7);
      expect(rust.commands, ['pause']);
      expect(player.currentVolume, 0.4);
    },
  );

  for (final hardware in [false, true]) {
    test(
      'duck persists across reconciliation and slider changes (hardware=$hardware)',
      () async {
        final usb = _Usb(hardware: hardware);
        final rust = _Rust();
        final player = _player(
          AudioEngineType.usbDacExperimental,
          usb,
          rust: rust,
        );
        expect(await player.enableUsbDacBitPerfect(), isTrue);
        usb.isBitPerfectEnabledSync = false;
        await player.setVolume(0.5);
        rust.commands.clear();
        await player.setDuckedForTesting(true);
        await player.reconcileVolumeForTesting();
        final expected = hardware ? -13.9794 : -33.9794;
        for (final command in rust.commands) {
          expect(
            softwareVolumeToDb(command as double),
            closeTo(expected, 0.0001),
          );
        }
        await player.setVolume(0.7);
        final changed = hardware ? 1.0 : 0.7;
        expect(
          rust.commands.last,
          closeTo(attenuateSoftwareVolume(changed, 0.2), 1e-9),
        );
        await player.setDuckedForTesting(false);
        expect(rust.commands.last, changed);
        expect(player.currentVolume, 0.7);
      },
    );
  }

  for (final fileType in ['DSF', 'DFF']) {
    test(
      '$fileType wire DSD never receives duck gain and stops on hardware failure',
      () async {
        final usb = _Usb(hardware: true);
        final rust = _Rust();
        final player = _player(
          AudioEngineType.usbDacExperimental,
          usb,
          rust: rust,
        );
        expect(await player.enableUsbDacBitPerfect(), isTrue);
        player.currentSongNotifier.value = Song(
          id: 'dsd',
          title: 'DSD',
          artist: 'Test',
          duration: const Duration(minutes: 1),
          fileType: fileType,
        );
        await player.setDuckedForTesting(true);
        await player.reconcileVolumeForTesting();
        expect(rust.commands, [1.0, 1.0]);
        usb.volumeWriteSucceeds = false;
        await player.setVolume(0.8);
        expect(rust.commands, [1.0, 1.0, 'pause']);
        expect(player.currentVolume, 0.4);
        expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
        usb.volumeWriteSucceeds = true;
        await player.restoreUsbVolumeForTesting();
        expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
        expect(rust.commands, [1.0, 1.0, 'pause', 1.0]);
      },
    );
  }
}
