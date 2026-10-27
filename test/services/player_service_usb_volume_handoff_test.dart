import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/providers/uac2_provider.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/widgets/uac2/uac2_volume_control.dart';
import 'package:flick/widgets/uac2/usb_bit_perfect_prompt.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> _isarCorePath() async {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null && File(override).existsSync()) return override;

  final package = await Isolate.resolvePackageUri(
    Uri.parse('package:isar_community_flutter_libs/'),
  );
  if (package == null) return null;
  final path = File.fromUri(package.resolve('linux/libisar.so'));
  return path.existsSync() ? path.path : null;
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

  final bool hardware;
  Completer<void>? permission;
  bool activationSucceeds = true;
  bool volumeWriteSucceeds = true;
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
    status = _status(_authorizedDevice, hardware: hardware);
    return true;
  }

  @override
  Future<void> refreshAndroidRouteStatus({
    Uac2AudioFormat? formatOverride,
    bool? isPlaying,
    bool? hasActiveSong,
  }) async {
    refreshes++;
    expect(isPlaying, isFalse);
    expect(hasActiveSong, isFalse);
  }

  @override
  Future<bool> setVolume(double volume, {bool persist = true}) async {
    writes.add(volume);
    expect(persist, isFalse);
    if (!volumeWriteSucceeds) return false;
    status = status.copyWith(volume: volume);
    return true;
  }
}

class _Status extends Uac2DeviceStatusNotifier {
  @override
  Uac2DeviceStatus build() => _status(_attachedDevice);
}

PlayerService _player(AudioEngineType initial, _Usb usb) {
  final session = _Session(initial);
  final player = PlayerService.forTesting(
    sessionManager: session,
    uac2Service: usb,
  );
  addTearDown(session.selectedModeNotifier.dispose);
  addTearDown(session.initializedModeNotifier.dispose);
  addTearDown(player.currentVolumeNotifier.dispose);
  addTearDown(player.volumeTierNotifier.dispose);
  return player;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;

  setUpAll(() async {
    final corePath = await _isarCorePath();
    if (corePath == null) {
      fail('isar core library not found; set ISAR_CORE_LIB');
    }
    Isar.initializeIsarCore(libraries: {Abi.current(): corePath});
    databaseDir = await Directory.systemTemp.createTemp('flick_usb_volume');
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
}
