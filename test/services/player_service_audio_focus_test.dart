import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/services/android_audio_engine.dart';
import 'package:flick/services/audio_engine_manager.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session extends Fake implements AudioSessionManager {
  _Session(AudioEngineType mode)
    : selectedModeNotifier = ValueNotifier(mode),
      initializedModeNotifier = ValueNotifier(mode);

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

class _Manager extends Fake implements AudioEngineManager {
  @override
  AudioEngineType? get activeEngineType => null;
  @override
  bool hasAttachedEngine = true;
  final calls = <String>[];
  Completer<void>? pauseCompletion;

  @override
  Future<void> pause() async {
    calls.add('pause');
    await pauseCompletion?.future;
    calls.add('paused');
  }
}

class _Usb extends Fake implements Uac2Service {
  @override
  Uac2DeviceStatus? get currentDeviceStatus => null;
  @override
  bool get isBitPerfectEnabledSync => false;
}

class _Android extends Fake implements AndroidAudioEngine {
  final volumes = <double>[];

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }
}

String _isarCorePath() {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null) return override;
  final config = File('.dart_tool/package_config.json').absolute;
  final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
  final package = packages.firstWhere(
    (dynamic item) => item['name'] == 'isar_community_flutter_libs',
  );
  final root = config.uri.resolve(package['rootUri'] as String);
  final library = switch (Abi.current()) {
    Abi.linuxX64 || Abi.linuxArm || Abi.linuxArm64 => 'linux/libisar.so',
    Abi.macosX64 || Abi.macosArm64 => 'macos/libisar.dylib',
    Abi.windowsX64 => 'windows/isar.dll',
    _ => throw UnsupportedError('Set ISAR_CORE_LIB for ${Abi.current()}'),
  };
  return Directory.fromUri(root).uri.resolve(library).toFilePath();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;
  late _Manager manager;
  late _Android android;
  late PlayerService player;
  late List<bool> focus;
  late int resumes;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp('flick_audio_focus');
    Isar.initializeIsarCore(libraries: {Abi.current(): _isarCorePath()});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => databaseDir.path,
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

  void createPlayer(AudioEngineType mode) {
    final session = _Session(mode);
    player = PlayerService.forTesting(
      sessionManager: session,
      uac2Service: _Usb(),
      playbackManager: manager,
      androidAudioEngine: android,
      interruptionResumer: () async {
        resumes++;
        player.isPlayingNotifier.value = true;
      },
      audioSessionActivation: (active) async {
        focus.add(active);
        manager.calls.add('focus:$active');
        return true;
      },
    );
    player.isPlayingNotifier.value = true;
    addTearDown(session.selectedModeNotifier.dispose);
    addTearDown(session.initializedModeNotifier.dispose);
    addTearDown(player.isPlayingNotifier.dispose);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    manager = _Manager();
    android = _Android();
    focus = [];
    resumes = 0;
  });

  for (final mode in [
    AudioEngineType.rustOboe,
    AudioEngineType.normalAndroid,
  ]) {
    test(
      'user pause releases focus only after $mode output has paused',
      () async {
        createPlayer(mode);
        manager.pauseCompletion = Completer<void>();
        final pause = player.pause();
        await Future<void>.delayed(Duration.zero);
        expect(player.isPlayingNotifier.value, isFalse);
        expect(focus, isEmpty);
        manager.pauseCompletion!.complete();
        await pause;
        expect(manager.calls, ['pause', 'paused', 'focus:false']);
      },
    );
  }

  test(
    'manual pause releases managed focus even without an attached engine',
    () async {
      createPlayer(AudioEngineType.rustOboe);
      manager.hasAttachedEngine = false;
      await player.pause();
      expect(focus, [false]);
      expect(manager.calls, ['focus:false']);
    },
  );

  test(
    'direct USB pause does not abandon its separately owned focus',
    () async {
      createPlayer(AudioEngineType.usbDacExperimental);
      await player.pause();
      expect(manager.calls, ['pause', 'paused']);
      expect(focus, isEmpty);
    },
  );

  test(
    'temporary interruption pauses output without abandoning focus',
    () async {
      createPlayer(AudioEngineType.rustOboe);
      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(manager.calls, ['pause', 'paused']);
      expect(focus, isEmpty);
    },
  );

  test('manual pause cancels queued interruption resume', () async {
    createPlayer(AudioEngineType.rustOboe);
    manager.pauseCompletion = Completer<void>();
    final interrupted = player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(true, AudioInterruptionType.pause),
    );
    final regained = player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    final manual = player.pause();
    manager.pauseCompletion!.complete();
    await Future.wait([interrupted, regained, manual]);
    expect(player.isPlayingNotifier.value, isFalse);
    expect(resumes, 0);
    expect(manager.calls, [
      'pause',
      'paused',
      'pause',
      'paused',
      'focus:false',
    ]);
  });

  test(
    'temporary interruption still automatically resumes when allowed',
    () async {
      createPlayer(AudioEngineType.rustOboe);
      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(resumes, 1);
      expect(player.isPlayingNotifier.value, isTrue);
      expect(focus, isEmpty);
    },
  );

  test('permanent focus loss never automatically resumes', () async {
    createPlayer(AudioEngineType.rustOboe);
    await player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(true, AudioInterruptionType.unknown),
    );
    await player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(false, AudioInterruptionType.unknown),
    );
    expect(resumes, 0);
    expect(player.isPlayingNotifier.value, isFalse);
  });

  test(
    'notification ducking keeps playback and focus, then restores gain',
    () async {
      createPlayer(AudioEngineType.normalAndroid);
      player.currentVolumeNotifier.value = 0.6;
      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      expect(android.volumes.single, closeTo(0.12, 0.00001));
      expect(player.isPlayingNotifier.value, isTrue);
      expect(manager.calls, isEmpty);
      expect(focus, isEmpty);

      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(android.volumes.last, 0.6);
      expect(player.isPlayingNotifier.value, isTrue);
      expect(resumes, 0);
      expect(focus, isEmpty);
    },
  );

  test(
    'manual pause during ducking restores gain without auto-resume',
    () async {
      createPlayer(AudioEngineType.normalAndroid);
      player.currentVolumeNotifier.value = 0.6;
      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      await player.pause();
      await player.handleAudioInterruptionForTesting(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(android.volumes, hasLength(2));
      expect(android.volumes.first, closeTo(0.12, 0.00001));
      expect(android.volumes.last, 0.6);
      expect(focus, [false]);
      expect(resumes, 0);
      expect(player.isPlayingNotifier.value, isFalse);
    },
  );

  test('a stale duck-end event cannot lift a newer interruption', () async {
    createPlayer(AudioEngineType.normalAndroid);
    player.currentVolumeNotifier.value = 0.6;
    await player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(true, AudioInterruptionType.duck),
    );
    final oldEnd = player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(false, AudioInterruptionType.duck),
    );
    final newBegin = player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(true, AudioInterruptionType.duck),
    );
    await Future.wait([oldEnd, newBegin]);
    expect(android.volumes, hasLength(1));
    expect(android.volumes.single, closeTo(0.12, 0.00001));

    await player.handleAudioInterruptionForTesting(
      AudioInterruptionEvent(false, AudioInterruptionType.duck),
    );
    expect(android.volumes.last, 0.6);
    expect(focus, isEmpty);
  });
}
