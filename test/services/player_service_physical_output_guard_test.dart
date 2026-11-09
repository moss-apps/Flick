import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/services/android_audio_engine.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/rust_audio_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';
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

AndroidPlaybackDeviceInfo _wiredOutput([String id = 'wired-1']) =>
    AndroidPlaybackDeviceInfo(
      hasUsbDac: false,
      hasAttachedUac2Device: false,
      manufacturer: 'Test',
      model: 'Phone',
      routeType: 'wired',
      routeLabel: 'USB-C Earphones',
      hasWiredAudioRoute: true,
      physicalOutputType: 'wired',
      physicalOutputId: id,
      physicalOutputLabel: 'USB-C Earphones',
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
}

class _Usb extends Fake implements Uac2Service {
  _Usb({bool hardware = false})
    : status = _status(_authorizedDevice, hardware: hardware);

  Uac2DeviceStatus status;
  bool volumeWriteSucceeds = true;
  bool muteWriteSucceeds = true;
  bool ignoreMuteWrite = false;
  final writes = <double>[];
  final muteWrites = <bool>[];

  @override
  bool isBitPerfectEnabledSync = false;
  @override
  Uac2DeviceStatus get currentDeviceStatus => status;

  @override
  Future<void> refreshAndroidRouteStatus({
    Uac2AudioFormat? formatOverride,
    bool? isPlaying,
    bool? hasActiveSong,
  }) async {}

  @override
  Future<bool> setVolume(double volume, {bool persist = true}) async {
    writes.add(volume);
    if (!volumeWriteSucceeds) return false;
    status = status.copyWith(volume: volume);
    return true;
  }

  @override
  Future<bool> setMute(bool muted) async {
    muteWrites.add(muted);
    if (!muteWriteSucceeds) return false;
    if (!ignoreMuteWrite) status = status.copyWith(muted: muted);
    return true;
  }
}

class _Rust extends Fake implements RustAudioService {
  final commands = <Object>[];
  bool failVolumeWrite = false;
  bool failPause = false;
  Completer<void>? volumeWrite;
  double appliedVolume = 1.0;

  @override
  bool get isInitialized => true;

  @override
  Future<void> setVolume(double volume) async {
    commands.add(volume);
    await volumeWrite?.future;
    if (failVolumeWrite) throw StateError('volume write failed');
    appliedVolume = volume;
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    if (failPause) throw StateError('pause failed');
  }

  @override
  Future<void> stop() async => commands.add('stop');
}

class _Android extends Fake implements AndroidAudioEngine {
  final volumes = <double>[];

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);
}

PlayerService _player(
  AudioEngineType initial,
  _Usb usb, {
  _Rust? rust,
  _Android? android,
  bool directUsb = false,
  _Session? sessionOverride,
}) {
  final session = sessionOverride ?? _Session(initial);
  final player = PlayerService.forTesting(
    sessionManager: session,
    uac2Service: usb,
    rustAudioService: rust,
    androidAudioEngine: android,
    directUsb: directUsb,
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
    await player.reconcileVolumeForTesting();
  });
  return player;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp(
      'flick_physical_output',
    );
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

  test('wired output lowers the system tier once and never raises', () async {
    final player = _player(AudioEngineType.normalAndroid, _Usb());
    expect(player.currentVolume, 1.0);

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    expect(player.currentVolume, 0.25);
    expect(player.volumeTierNotifier.value, VolumeTier.system);

    await player.setVolume(0.8);
    expect(player.currentVolume, 0.8);

    // A repeated AudioDeviceCallback for the same connection must not undo
    // the user's adjustment.
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    expect(player.currentVolume, 0.8);
  });

  test('a different physical output applies the ceiling again', () async {
    final player = _player(AudioEngineType.normalAndroid, _Usb());
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    await player.setVolume(0.9);

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput('wired-2'));

    expect(player.currentVolume, 0.25);
  });

  test('physical output removal lets the same connection re-apply', () async {
    final player = _player(AudioEngineType.normalAndroid, _Usb());
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    await player.setVolume(0.7);

    await player.handlePlaybackDeviceInfoForTesting(
      const AndroidPlaybackDeviceInfo(
        hasUsbDac: false,
        hasAttachedUac2Device: false,
        manufacturer: 'Test',
        model: 'Phone',
        routeType: 'internal',
        routeLabel: 'Built-in output',
      ),
    );
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    expect(player.currentVolume, 0.25);
  });

  test('unknown refresh does not re-lower the current connection', () async {
    final player = _player(AudioEngineType.normalAndroid, _Usb());
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    await player.setVolume(0.7);

    await player.handlePlaybackDeviceInfoForTesting(
      AndroidPlaybackDeviceInfo.unknown,
    );
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    expect(player.currentVolume, 0.7);
  });

  test('muted or already-lower volume is never raised', () async {
    final player = _player(AudioEngineType.normalAndroid, _Usb());
    await player.setVolume(0.0);

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    expect(player.currentVolume, 0.0);
  });

  test('Rust software tier receives the safety ceiling exactly once', () async {
    final rust = _Rust();
    final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    expect(player.currentVolume, 0.25);
    expect(player.volumeTierNotifier.value, VolumeTier.software);
    expect(rust.commands, [0.25]);

    await player.setVolume(0.9);
    expect(player.currentVolume, 0.9);
    expect(rust.commands, [0.25, 0.9]);

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    expect(rust.commands, [0.25, 0.9]);
  });

  test(
    'direct USB keeps its verified hardware restore, not a software cap',
    () async {
      final usb = _Usb(hardware: true);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.usbDacExperimental,
        usb,
        rust: rust,
        directUsb: true,
      );

      await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

      expect(usb.writes, [0.4]);
      expect(player.currentVolume, 0.4);
      expect(rust.commands, isEmpty);
    },
  );

  test('direct USB handoff keeps the software safety attenuation', () async {
    await Uac2PreferencesService().setUsbVolumeForDevice(
      _authorizedDevice,
      0.8,
      authority: UsbVolumeAuthority.hardware,
    );
    final session = _Session(AudioEngineType.normalAndroid);
    final usb = _Usb(hardware: true);
    final player = _player(
      AudioEngineType.normalAndroid,
      usb,
      sessionOverride: session,
      directUsb: true,
    );

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    expect(player.currentVolume, 0.25);

    // The user grants USB access on the same physical connection.
    session.selectedModeNotifier.value = AudioEngineType.usbDacExperimental;
    session.initializedModeNotifier.value = AudioEngineType.usbDacExperimental;
    await player.restoreUsbVolumeForTesting();

    // A remembered 80% DAC level must not undo the 25% app attenuation;
    // the verified hardware restore takes the low 40% first-use ceiling.
    expect(usb.writes, [0.4]);
    expect(player.currentVolume, 0.4);
  });

  for (final volume in [0.0, 0.1, 1.0]) {
    test('software USB handoff preserves guarded volume $volume', () async {
      await Uac2PreferencesService().setUsbVolumeForDevice(
        _authorizedDevice,
        0.8,
        authority: UsbVolumeAuthority.software,
      );
      final session = _Session(AudioEngineType.rustOboe);
      final rust = _Rust();
      final player = _player(
        AudioEngineType.rustOboe,
        _Usb(),
        rust: rust,
        sessionOverride: session,
        directUsb: true,
      );
      await player.setVolume(volume);
      await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
      final guarded = player.currentVolume;

      session.selectedModeNotifier.value = AudioEngineType.usbDacExperimental;
      session.initializedModeNotifier.value =
          AudioEngineType.usbDacExperimental;
      await player.restoreUsbVolumeForTesting();

      expect(player.currentVolume, guarded);
      expect(rust.appliedVolume, guarded);
      final saved = await Uac2PreferencesService()
          .getUsbVolumeSettingsForDevice(_authorizedDevice);
      expect(saved.software, 0.8); // The one-shot ceiling is not a preference.
    });
  }

  test('hardware USB handoff preserves the app mute', () async {
    final session = _Session(AudioEngineType.rustOboe);
    final usb = _Usb(hardware: true);
    final rust = _Rust();
    final player = _player(
      AudioEngineType.rustOboe,
      usb,
      rust: rust,
      sessionOverride: session,
      directUsb: true,
    );
    await player.setVolume(0.0);
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    session.selectedModeNotifier.value = AudioEngineType.usbDacExperimental;
    session.initializedModeNotifier.value = AudioEngineType.usbDacExperimental;
    await player.restoreUsbVolumeForTesting();

    expect(usb.writes, [0.0]);
    expect(usb.status.volume, 0.0);
    expect(usb.muteWrites, [true]);
    expect(usb.status.muted, isTrue);
    expect(player.currentVolume, 0.0);
    // Hardware mute is verified before releasing software attenuation.
    expect(rust.commands, contains('pause'));
    expect(rust.appliedVolume, 1.0);
  });

  for (final ignored in [false, true]) {
    test('unverified hardware mute stays paused (ignored=$ignored)', () async {
      final session = _Session(AudioEngineType.rustOboe);
      final usb = _Usb(hardware: true)
        ..muteWriteSucceeds = ignored
        ..ignoreMuteWrite = ignored;
      final rust = _Rust();
      final player = _player(
        AudioEngineType.rustOboe,
        usb,
        rust: rust,
        sessionOverride: session,
        directUsb: true,
      );
      await player.setVolume(0.0);
      await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
      session.selectedModeNotifier.value = AudioEngineType.usbDacExperimental;
      session.initializedModeNotifier.value =
          AudioEngineType.usbDacExperimental;

      await expectLater(player.restoreUsbVolumeForTesting(), throwsStateError);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isTrue);
      expect(rust.commands, contains('pause'));
      expect(rust.commands, isNot(contains(1.0)));

      usb.muteWriteSucceeds = true;
      usb.ignoreMuteWrite = false;
      await player.restoreUsbVolumeForTesting();
      expect(usb.status.muted, isTrue);
      expect(player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(rust.appliedVolume, 1.0);
    });
  }

  test('system guard writes through the crossfade-owning engine', () async {
    final android = _Android();
    final player = _player(
      AudioEngineType.normalAndroid,
      _Usb(),
      android: android,
    );

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    expect(android.volumes, [0.25]);
    await player.setVolume(0.8);
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    expect(android.volumes, [0.25, 0.8]);
  });

  test('failed safety write pauses and retries the same connection', () async {
    final rust = _Rust()..failVolumeWrite = true;
    final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);
    player.isPlayingNotifier.value = true;

    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());

    expect(player.currentVolume, 1.0); // Do not advertise an unapplied gain.
    expect(rust.appliedVolume, 1.0);
    expect(rust.commands, [0.25, 'pause']);
    expect(player.isPlayingNotifier.value, isFalse);
    rust.failVolumeWrite = false;
    await player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    expect(rust.commands, [0.25, 'pause', 0.25]);
    expect(player.currentVolume, 0.25);
    expect(rust.appliedVolume, 0.25);
  });

  test('duplicate notifications await the in-flight safety write', () async {
    final rust = _Rust()..volumeWrite = Completer<void>();
    final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);
    var secondCompleted = false;
    final first = player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    final second = player
        .handlePlaybackDeviceInfoForTesting(_wiredOutput())
        .then((_) => secondCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(secondCompleted, isFalse);
    expect(rust.commands, [0.25]);

    rust.volumeWrite!.complete();
    await Future.wait([first, second]);
    expect(player.currentVolume, 0.25);
  });

  test(
    'background reconciliation cannot undo a pending safety write',
    () async {
      final rust = _Rust()..volumeWrite = Completer<void>();
      final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);
      final guard = player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
      final reconcile = player.reconcileVolumeForTesting();
      await Future<void>.delayed(Duration.zero);
      expect(rust.commands, [0.25]);

      rust.volumeWrite!.complete();
      await Future.wait([guard, reconcile]);
      expect(rust.commands, [0.25, 0.25]);
      expect(rust.appliedVolume, 0.25);
      expect(player.currentVolume, 0.25);
    },
  );

  test('Play stays blocked on failure and retries before continuing', () async {
    final rust = _Rust()
      ..failVolumeWrite = true
      ..failPause = true;
    final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);

    await expectLater(
      player.ensurePhysicalOutputVolumeForTesting(_wiredOutput()),
      throwsStateError,
    );
    expect(rust.commands, [0.25, 'pause', 'stop']);
    expect(player.currentVolume, 1.0);

    rust.failVolumeWrite = false;
    await player.ensurePhysicalOutputVolumeForTesting(_wiredOutput());
    expect(rust.commands, [0.25, 'pause', 'stop', 0.25]);
    expect(rust.appliedVolume, 0.25);
    expect(player.isPlayingNotifier.value, isFalse);
  });

  test('a hardware-to-normal engine change rechecks the output', () async {
    final session = _Session(AudioEngineType.usbDacExperimental);
    final android = _Android();
    final usb = _Usb(hardware: true);
    final player = _player(
      AudioEngineType.usbDacExperimental,
      usb,
      android: android,
      directUsb: true,
      sessionOverride: session,
    );
    await player.ensurePhysicalOutputVolumeForTesting(_wiredOutput());
    expect(usb.writes, [0.4]);
    expect(android.volumes, isEmpty);

    session.selectedModeNotifier.value = AudioEngineType.normalAndroid;
    session.initializedModeNotifier.value = AudioEngineType.normalAndroid;
    await player.ensurePhysicalOutputVolumeForTesting(_wiredOutput());
    expect(android.volumes, [0.25]);
    expect(player.currentVolume, 0.25);
  });

  test('user mute follows rather than races the safety write', () async {
    final rust = _Rust()..volumeWrite = Completer<void>();
    final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);
    final guard = player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    final mute = player.setVolume(0.0);
    await Future<void>.delayed(Duration.zero);
    expect(rust.commands, [0.25]);

    rust.volumeWrite!.complete();
    await Future.wait([guard, mute]);
    expect(rust.commands, [0.25, 0.0]);
    expect(player.currentVolume, 0.0);
    expect(rust.appliedVolume, 0.0);
  });

  test('replacement output and mute wait for the previous write', () async {
    final rust = _Rust()..volumeWrite = Completer<void>();
    final player = _player(AudioEngineType.rustOboe, _Usb(), rust: rust);
    final first = player.handlePlaybackDeviceInfoForTesting(_wiredOutput());
    final second = player.handlePlaybackDeviceInfoForTesting(
      _wiredOutput('wired-2'),
    );
    final mute = player.setVolume(0.0);
    await Future<void>.delayed(Duration.zero);
    expect(rust.commands, [0.25]);

    rust.volumeWrite!.complete();
    await Future.wait([first, second, mute]);
    expect(rust.commands, [0.25, 0.25, 0.0]);
    expect(player.currentVolume, 0.0);
    expect(rust.appliedVolume, 0.0);
  });

  test('one USB connection survives Android route-id changes', () async {
    const connectionId = '/dev/bus/usb/001/002';
    AndroidPlaybackDeviceInfo output(String routeId, String routeType) =>
        AndroidPlaybackDeviceInfo.fromMap({
          'hasUsbDac': true,
          'hasAttachedUac2Device': true,
          'physicalOutputType': 'usb',
          'physicalOutputId': routeId,
          'physicalOutputConnectionId': connectionId,
          'physicalOutputLabel': 'Test DAC',
          'routeType': routeType,
        });
    final player = _player(AudioEngineType.normalAndroid, _Usb());
    await player.handlePlaybackDeviceInfoForTesting(
      output(connectionId, 'internal'),
    );
    await player.setVolume(0.8);
    await player.handlePlaybackDeviceInfoForTesting(output('42', 'usb'));
    expect(player.currentVolume, 0.8);
    await player.handlePlaybackDeviceInfoForTesting(
      output(connectionId, 'internal'),
    );
    expect(player.currentVolume, 0.8);
  });
}
