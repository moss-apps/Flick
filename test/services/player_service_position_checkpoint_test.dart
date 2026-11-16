import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/playback_state.dart';
import 'package:flick/models/song.dart';
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

  @override
  void clearFallbackReason() {}

  @override
  Future<void> switchMode(
    AudioEngineType mode, {
    bool initializeNewEngine = false,
    String reason = 'manual switch',
  }) async {
    selectedModeNotifier.value = mode;
    if (initializeNewEngine) {
      initializedModeNotifier.value = mode;
    }
  }
}

class _Manager extends Fake implements AudioEngineManager {
  @override
  AudioEngineType? get activeEngineType => null;
  @override
  bool hasAttachedEngine = true;
  @override
  PlaybackState? get latestState => null;
  @override
  bool get canResumeCurrentTrack => false;
  final calls = <String>[];

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> playTrack(
    Song track, {
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    calls.add('playTrack');
  }
}

class _Usb extends Fake implements Uac2Service {
  @override
  Uac2DeviceStatus? get currentDeviceStatus => null;
  @override
  bool get isBitPerfectEnabledSync => false;
}

class _Android extends Fake implements AndroidAudioEngine {}

const _song = Song(
  id: 'checkpoint-song',
  title: 'Checkpoint Song',
  artist: 'Test Artist',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
  filePath: '/tmp/checkpoint-song.flac',
  sampleRate: 44100,
  bitDepth: 16,
);

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

Future<int?> _savedPositionMs() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('last_played_position_ms');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;
  late _Manager manager;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp('flick_checkpoints');
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    manager = _Manager();
  });

  PlayerService createPlayer() {
    final session = _Session(AudioEngineType.normalAndroid);
    final player = PlayerService.forTesting(
      sessionManager: session,
      uac2Service: _Usb(),
      playbackManager: manager,
      androidAudioEngine: _Android(),
      audioSessionActivation: (active) async => true,
    );
    player.currentSongNotifier.value = _song;
    addTearDown(player.stopPositionSaveTimerForTesting);
    addTearDown(session.selectedModeNotifier.dispose);
    addTearDown(session.initializedModeNotifier.dispose);
    addTearDown(player.isPlayingNotifier.dispose);
    addTearDown(player.currentSongNotifier.dispose);
    addTearDown(player.positionNotifier.dispose);
    return player;
  }

  testWidgets('checkpoints continue while playing', (tester) async {
    final player = createPlayer();
    player.isPlayingNotifier.value = true;
    player.positionNotifier.value = const Duration(milliseconds: 12345);

    try {
      player.startPositionSaveTimerForTesting();
      expect(player.isPositionSaveTimerRunning, isTrue);

      await tester.pump(const Duration(seconds: 5));

      expect(await _savedPositionMs(), 12345);
    } finally {
      player.stopPositionSaveTimerForTesting();
    }
  });

  testWidgets('checkpoint tick stops itself when playback is paused', (
    tester,
  ) async {
    final player = createPlayer();
    player.isPlayingNotifier.value = false;
    player.positionNotifier.value = const Duration(milliseconds: 33000);

    try {
      player.startPositionSaveTimerForTesting();
      expect(player.isPositionSaveTimerRunning, isTrue);

      await tester.pump(const Duration(seconds: 5));

      expect(player.isPositionSaveTimerRunning, isFalse);
      expect(await _savedPositionMs(), isNull);
    } finally {
      player.stopPositionSaveTimerForTesting();
    }
  });

  testWidgets('pause saves once and stops checkpoints', (tester) async {
    final player = createPlayer();
    player.isPlayingNotifier.value = true;
    player.positionNotifier.value = const Duration(milliseconds: 42000);
    player.startPositionSaveTimerForTesting();

    await player.pause();

    expect(player.isPositionSaveTimerRunning, isFalse);
    expect(await _savedPositionMs(), 42000);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('last_played_was_playing'), isFalse);

    player.positionNotifier.value = const Duration(milliseconds: 99000);
    await tester.pump(const Duration(seconds: 10));
    expect(await _savedPositionMs(), 42000);

    // Lifecycle persistence still works while paused.
    player.positionNotifier.value = const Duration(milliseconds: 77000);
    await player.persistLastPlayed();
    expect(await _savedPositionMs(), 77000);
  });

  testWidgets('resume restarts checkpoints', (tester) async {
    final player = createPlayer();
    player.isPlayingNotifier.value = true;
    player.positionNotifier.value = const Duration(milliseconds: 42000);
    player.startPositionSaveTimerForTesting();
    await player.pause();
    expect(player.isPositionSaveTimerRunning, isFalse);

    player.positionNotifier.value = const Duration(milliseconds: 50000);
    await player.resume();
    player.isPlayingNotifier.value = true;

    try {
      expect(player.isPositionSaveTimerRunning, isTrue);
      await tester.pump(const Duration(seconds: 5));
      expect(await _savedPositionMs(), 50000);
    } finally {
      player.stopPositionSaveTimerForTesting();
    }
  });

  testWidgets('external pause stops checkpoints and saves once', (
    tester,
  ) async {
    final player = createPlayer();
    player.isPlayingNotifier.value = true;
    player.positionNotifier.value = const Duration(milliseconds: 21000);
    player.startPositionSaveTimerForTesting();

    try {
      player.syncPositionSaveTimerForTesting(
        isPlaying: false,
        wasPlaying: true,
      );
      expect(player.isPositionSaveTimerRunning, isFalse);
      await tester.pump();
      expect(await _savedPositionMs(), 21000);

      player.syncPositionSaveTimerForTesting(
        isPlaying: true,
        wasPlaying: false,
      );
      expect(player.isPositionSaveTimerRunning, isTrue);
    } finally {
      player.stopPositionSaveTimerForTesting();
    }
  });
}
