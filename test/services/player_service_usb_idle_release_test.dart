import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/audio_output_diagnostics.dart';
import 'package:flick/models/playback_state.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/audio_engine_manager.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/rust_audio_engine.dart';
import 'package:flick/services/rust_audio_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _device = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  serial: 'SERIAL',
  deviceName: '/dev/bus/usb/001/002',
);

Uac2DeviceStatus _status({
  required bool hardware,
  required bool control,
  required double volume,
}) => Uac2DeviceStatus(
  device: _device,
  state: Uac2State.connected,
  routeType: Uac2RouteType.externalUsb,
  isExternalRoute: true,
  directUsbRegistered: true,
  volumeMode: !hardware
      ? Uac2VolumeMode.software
      : control
      ? Uac2VolumeMode.hardware
      : Uac2VolumeMode.unavailable,
  hasVolumeControl: !hardware || control,
  volume: volume,
);

const _song = Song(
  id: 'idle-song',
  title: 'Idle Song',
  artist: 'Test Artist',
  duration: Duration(minutes: 5),
  fileType: 'FLAC',
  filePath: '/music/idle-song.flac',
  sampleRate: 96000,
  bitDepth: 24,
);

const _songB = Song(
  id: 'idle-song-b',
  title: 'Idle Song B',
  artist: 'Test Artist',
  duration: Duration(minutes: 4),
  fileType: 'FLAC',
  filePath: '/music/idle-song-b.flac',
  sampleRate: 96000,
  bitDepth: 24,
);

AudioOutputDiagnostics _diagnostics({
  AudioPathManagement path = AudioPathManagement.directUsbExperimental,
}) {
  return AudioOutputDiagnostics(
    selectedMode: AudioEngineType.usbDacExperimental,
    initializedMode: AudioEngineType.usbDacExperimental,
    detectedDap: false,
    detectedDapBrand: null,
    pathManagement: path,
    outputStrategyLabel: 'USB direct',
    capabilityStateLabel: 'Verified USB direct',
    backendDescription: 'Rust engine via libusb direct USB (verified)',
    routeType: 'usb',
    routeLabel: 'USB DAC',
    outputDeviceLabel: 'Test DAC',
    isMixerManaged: false,
    audioFocusHeld: true,
    directUsbRegistered: true,
    usbInterfaceClaimed: true,
    usbStreamStable: true,
    trackSampleRate: 96000,
    requestedOutputSampleRate: 96000,
    reportedOutputSampleRate: 96000,
    resamplerActive: false,
    passthroughAllowed: true,
    activeOutputSignature: 'android-uac2:1.2',
    verificationReason: null,
    fallbackReason: null,
    capabilityFlags: AudioCapabilityFlags(
      supportsExclusiveUsbOwnership: true,
      supportsDirectSampleRateSwitching: true,
      supportsVerifiedBitPerfect: true,
      supportsAndroidManagedHighResOnly: false,
      supportsInternalDapPathOnly: false,
    ),
  );
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

class _Session extends Fake implements AudioSessionManager {
  _Session()
    : selectedModeNotifier = ValueNotifier(AudioEngineType.usbDacExperimental),
      initializedModeNotifier = ValueNotifier(
        AudioEngineType.usbDacExperimental,
      );

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
  Future<void> syncRouteSelection({required String reason}) async {}

  @override
  Future<void> switchMode(
    AudioEngineType mode, {
    bool initializeNewEngine = false,
    String reason = 'manual switch',
  }) async {
    selectedModeNotifier.value = mode;
    if (initializeNewEngine) initializedModeNotifier.value = mode;
  }
}

/// Native engine stand-in that records the order of every call that matters.
class _Rust extends Fake implements RustAudioService {
  _Rust(this.events);

  final List<String> events;
  void Function()? onPrepare;
  void Function()? onRelease;
  @override
  final stateNotifier = ValueNotifier(RustPlaybackState.idle);
  @override
  final positionNotifier = ValueNotifier(Duration.zero);
  @override
  final durationNotifier = ValueNotifier(Duration.zero);
  @override
  final bufferLevelNotifier = ValueNotifier(0.0);
  @override
  String? currentPath;

  // The processing policy needs the real engine plugins; reopen still prepares
  // the engine first, which is what these tests pin.
  @override
  bool get isInitialized => false;

  @override
  Future<void> prepareEngine({int? preferredSampleRate}) async {
    events.add('prepareEngine');
    onPrepare?.call();
  }

  @override
  Future<void> releaseEngine() async {
    events.add('releaseEngine');
    stateNotifier.value = RustPlaybackState.idle;
    onRelease?.call();
  }

  @override
  Future<void> play(String path, {double? startSecs, double? endSecs}) async {
    events.add('play');
    currentPath = path;
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> seek(Duration position) async {
    events.add('seek:${position.inSeconds}');
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    stateNotifier.value = RustPlaybackState.paused;
  }

  @override
  Future<void> resume() async {
    events.add('resume');
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    stateNotifier.value = RustPlaybackState.stopped;
  }
}

class _Usb extends Fake implements Uac2Service {
  _Usb(this.events, {required this.hardware});

  final List<String> events;
  final bool hardware;
  final detached = StreamController<void>.broadcast();

  /// The DAC's volume control is only discovered while the stream is open.
  bool control = true;
  double volume = 0.4;

  @override
  Uac2DeviceStatus get currentDeviceStatus =>
      _status(hardware: hardware, control: control, volume: volume);
  @override
  bool isBitPerfectEnabledSync = false;
  @override
  Stream<void> get deviceDetachedEvents => detached.stream;

  @override
  Future<bool> setBitPerfectEnabled(bool enabled, {bool persist = true}) async {
    isBitPerfectEnabledSync = enabled;
    return true;
  }

  @override
  Future<void> refreshAndroidRouteStatus({
    Uac2AudioFormat? formatOverride,
    bool? isPlaying,
    bool? hasActiveSong,
  }) async {
    events.add('refreshRoute');
  }

  @override
  Future<bool> setVolume(double volume, {bool persist = true}) async {
    events.add('setVolume:$volume');
    this.volume = volume;
    return true;
  }

  @override
  Future<bool?> verifyHardwareVolumeHealth() async => true;

  @override
  Future<Map<String, dynamic>?> getAndroidPlaybackDebugState() async => null;
}

/// Hands engine calls straight to the real [RustAudioEngine].
class _Manager extends Fake implements AudioEngineManager {
  _Manager(this.engine);

  final RustAudioEngine engine;
  @override
  bool hasAttachedEngine = true;
  @override
  AudioEngineType? get activeEngineType => AudioEngineType.usbDacExperimental;
  @override
  bool get canResumeCurrentTrack => true;
  @override
  PlaybackState? get latestState => PlaybackState(
    currentTrack: _song,
    isPlaying: false,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
    duration: _song.duration,
    engine: AudioEngineType.usbDacExperimental,
  );

  @override
  Future<void> pause() => engine.pause();
  @override
  Future<void> play() => engine.play();
  @override
  Future<void> stop() => engine.stop();
  @override
  Future<void> seek(Duration position) => engine.seek(position);
  @override
  Future<void> detachEngine({bool disposeCurrent = true}) async {
    hasAttachedEngine = false;
  }
}

class _Fixture {
  _Fixture({bool hardware = false}) {
    usb = _Usb(events, hardware: hardware);
    rust = _Rust(events)
      ..onRelease = (() => usb.control = false)
      ..onPrepare = (() => usb.control = true);
    session = _Session();
    engine = RustAudioEngine(
      playbackMode: AudioEngineType.usbDacExperimental,
      rustAudioService: rust,
      ensureInitialized: () async {},
      resolvePlaybackPath: (song) async => song.filePath,
      disposeEngine: () async {},
    );
    player = PlayerService.forTesting(
      sessionManager: session,
      uac2Service: usb,
      rustAudioService: rust,
      playbackManager: _Manager(engine),
      directUsb: true,
    );
    player.attachRustEngineForTesting(engine);
    addTearDown(player.stopPositionSaveTimerForTesting);
    addTearDown(session.selectedModeNotifier.dispose);
    addTearDown(session.initializedModeNotifier.dispose);
    addTearDown(usb.detached.close);
  }

  final events = <String>[];
  late final _Usb usb;
  late final _Rust rust;
  late final _Session session;
  late final RustAudioEngine engine;
  late final PlayerService player;

  /// Ends a test: no countdown, checkpoint or DAC health timer may outlive it.
  Future<void> finish() async {
    player.isPlayingNotifier.value = true;
    player.stopPositionSaveTimerForTesting();
    session.initializedModeNotifier.value = AudioEngineType.normalAndroid;
    await player.reconcileVolumeForTesting();
  }

  /// Plays [_song] natively, then pauses it at [position] like the UI does.
  Future<void> pauseAt(Duration position, {Song song = _song}) async {
    await engine.load(song);
    await engine.play();
    rust.positionNotifier.value = position;
    player.currentSongNotifier.value = song;
    player.positionNotifier.value = position;
    player.isPlayingNotifier.value = true;
    await player.pause();
    player.audioOutputDiagnosticsNotifier.value = _diagnostics();
    events.clear();
  }

  bool get released => player.isUsbEngineIdleReleased;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp('flick_usb_idle');
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the delay is 30 seconds', () {
    expect(PlayerService.usbIdleReleaseDelay, const Duration(seconds: 30));
  });

  group('timer', () {
    testWidgets('closes the stream only after 30 s of continuous pause', (
      tester,
    ) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));
      expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);

      await tester.pump(const Duration(seconds: 29, milliseconds: 900));
      expect(f.released, isFalse);
      expect(f.events, isEmpty);

      await tester.pump(const Duration(milliseconds: 200));
      expect(f.released, isTrue);
      expect(f.events, ['releaseEngine']);
      expect(f.player.isUsbIdleReleaseTimerArmed, isFalse);
      // The paused UI state is untouched, and a refresh keeps the last report.
      final report = f.player.audioOutputDiagnosticsNotifier.value;
      await f.player.refreshAudioOutputDiagnosticsForTesting();
      expect(f.player.audioOutputDiagnosticsNotifier.value, same(report));
      expect(f.player.currentSongNotifier.value, _song);
      expect(f.player.isPlayingNotifier.value, isFalse);
      expect(f.player.positionNotifier.value, const Duration(seconds: 42));
      expect(
        f.player.audioOutputDiagnosticsNotifier.value?.pathManagement,
        AudioPathManagement.directUsbExperimental,
      );
    });

    testWidgets('play cancels it and the next pause counts from zero', (
      tester,
    ) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));

      await tester.pump(const Duration(seconds: 20));
      f.player.isPlayingNotifier.value = true;
      expect(f.player.isUsbIdleReleaseTimerArmed, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(f.released, isFalse);
      expect(f.events, isEmpty);

      f.player.isPlayingNotifier.value = false;
      expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);
      await tester.pump(const Duration(seconds: 29));
      expect(f.released, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(f.released, isTrue);
    });

    testWidgets('a track change restarts the countdown', (tester) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));

      await tester.pump(const Duration(seconds: 20));
      f.player.currentSongNotifier.value = _songB;
      await tester.pump(const Duration(seconds: 20));
      expect(f.released, isFalse);
      expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);

      await tester.pump(const Duration(seconds: 11));
      expect(f.released, isTrue);
    });

    testWidgets('stop cancels it', (tester) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));
      expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);

      await f.player.stopPlaybackForTesting();

      expect(f.player.isUsbIdleReleaseTimerArmed, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(f.released, isFalse);
      expect(f.events, isNot(contains('releaseEngine')));
    });

    testWidgets('an engine switch cancels it', (tester) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));
      expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);

      await f.player.detachEngineForTesting();

      expect(f.player.isUsbIdleReleaseTimerArmed, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(f.released, isFalse);
    });

    testWidgets('unplugging the DAC cancels it and forgets a released stream', (
      tester,
    ) async {
      final f = _Fixture();
      f.player.watchUsbDacDisconnectsForTesting();
      await f.pauseAt(const Duration(seconds: 42));
      expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);

      f.usb.detached.add(null);
      await tester.pump();
      expect(f.player.isUsbIdleReleaseTimerArmed, isFalse);
      await tester.pump(const Duration(seconds: 60));
      expect(f.released, isFalse);

      // Pause again, release, then unplug while released.
      f.player.isPlayingNotifier.value = true;
      f.player.isPlayingNotifier.value = false;
      await tester.pump(const Duration(seconds: 31));
      expect(f.released, isTrue);
      f.usb.detached.add(null);
      await tester.pump();
      expect(f.released, isFalse);
    });

    testWidgets('only a direct USB stream that is natively paused is closed', (
      tester,
    ) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));

      f.player.audioOutputDiagnosticsNotifier.value = _diagnostics(
        path: AudioPathManagement.androidManagedLowLatency,
      );
      await tester.pump(const Duration(seconds: 31));
      expect(f.released, isFalse);
      expect(f.events, isEmpty);

      // Native engine stopped (queue ended) rather than paused.
      f.player.audioOutputDiagnosticsNotifier.value = _diagnostics();
      f.rust.stateNotifier.value = RustPlaybackState.stopped;
      f.player.isPlayingNotifier.value = true;
      f.player.isPlayingNotifier.value = false;
      await tester.pump(const Duration(seconds: 31));
      expect(f.released, isFalse);
      expect(f.events, isEmpty);
    });
  });

  group('resume', () {
    testWidgets(
      'reopens the stream first and continues at the paused position',
      (tester) async {
        final f = _Fixture();
        await f.pauseAt(const Duration(seconds: 42));
        await tester.pump(const Duration(seconds: 31));
        expect(f.released, isTrue);
        f.events.clear();

        await f.player.resume();

        expect(f.released, isFalse);
        expect(f.events.first, 'prepareEngine');
        // Reopened before the DAC volume checks, then a fresh play + seek back.
        expect(
          f.events.indexOf('prepareEngine'),
          lessThan(f.events.indexOf('play')),
        );
        expect(
          f.events,
          containsAllInOrder(['prepareEngine', 'play', 'seek:42']),
        );
        expect(f.events, isNot(contains('resume')));
        expect(f.engine.isOutputReleased, isFalse);
        f.player.isPlayingNotifier.value = true; // The state stream does this.
        expect(f.player.isUsbIdleReleaseTimerArmed, isFalse);
        await f.finish();
      },
    );

    testWidgets('a pause shorter than the delay resumes natively', (
      tester,
    ) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));
      await tester.pump(const Duration(seconds: 10));

      await f.player.resume();

      expect(f.events, contains('resume'));
      expect(f.events, isNot(contains('prepareEngine')));
      expect(f.events, isNot(contains('play')));
      await f.finish();
    });

    testWidgets('a seek while released waits for play and does not reopen', (
      tester,
    ) async {
      final f = _Fixture();
      await f.pauseAt(const Duration(seconds: 42));
      await tester.pump(const Duration(seconds: 31));
      f.events.clear();

      await f.player.seek(const Duration(seconds: 90));

      expect(f.events, isEmpty);
      expect(f.released, isTrue);
      expect(f.player.isPlayingNotifier.value, isFalse);

      await f.player.resume();

      expect(
        f.events,
        containsAllInOrder(['prepareEngine', 'play', 'seek:90']),
      );
      await f.finish();
    });
  });

  group('volume authority', () {
    // Verified hardware volume, as after the pre-playback restore.
    Future<_Fixture> hardwareFixture() async {
      final f = _Fixture(hardware: true);
      expect(await f.player.enableUsbDacBitPerfect(), isTrue);
      await f.player.reconcileVolumeForTesting();
      expect(f.player.volumeTierNotifier.value, VolumeTier.hardware);
      return f;
    }

    testWidgets(
      'losing the DAC control on a live stream is still a safety block',
      (tester) async {
        final f = await hardwareFixture();
        await f.pauseAt(const Duration(seconds: 42));

        f.usb.control = false;
        await f.player.reconcileVolumeForTesting();

        expect(f.player.usbVolumeSafetyBlockedNotifier.value, isTrue);
        await f.finish();
      },
    );

    testWidgets('a released stream keeps its volume authority and DAC level', (
      tester,
    ) async {
      final f = await hardwareFixture();
      await f.pauseAt(const Duration(seconds: 42));
      await tester.pump(const Duration(seconds: 31));
      expect(f.released, isTrue);
      expect(f.usb.control, isFalse); // The stream took the control with it.

      await f.player.reconcileVolumeForTesting();
      await f.player.reconcileVolumeForTesting();
      f.events.clear();
      await f.player.restoreUsbVolumeForTesting(); // Waits for the stream.
      expect(f.events, isEmpty);

      expect(f.player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(f.player.volumeTierNotifier.value, VolumeTier.hardware);
      expect(f.player.isHardwareVolumeAuthority, isTrue);
      expect(f.player.isVolumeAvailable, isTrue);

      await f.player.resume();

      // Reopen reads the DAC's level again; nothing writes it.
      expect(f.usb.control, isTrue);
      expect(f.events.where((e) => e.startsWith('setVolume')), isEmpty);
      expect(f.player.usbVolumeSafetyBlockedNotifier.value, isFalse);
      expect(f.player.volumeTierNotifier.value, VolumeTier.hardware);
      f.player.isPlayingNotifier.value = true;
      await f.finish();
    });

    testWidgets(
      'a volume change while released reopens first, then goes idle again',
      (tester) async {
        final f = await hardwareFixture();
        await f.pauseAt(const Duration(seconds: 42));
        await tester.pump(const Duration(seconds: 31));
        expect(f.released, isTrue);
        f.events.clear();

        await f.player.setVolume(0.3);

        expect(f.released, isFalse);
        expect(
          f.events.indexOf('prepareEngine'),
          lessThan(f.events.indexOf('setVolume:0.3')),
        );
        expect(f.usb.volume, 0.3);
        expect(f.player.usbVolumeSafetyBlockedNotifier.value, isFalse);
        // Still paused: the stream closes again after another quiet 30 s.
        expect(f.player.isUsbIdleReleaseTimerArmed, isTrue);
        f.player.audioOutputDiagnosticsNotifier.value = _diagnostics();
        // The silently reopened engine has no source, so it is not "paused".
        expect(f.rust.stateNotifier.value, RustPlaybackState.idle);
        await tester.pump(const Duration(seconds: 31));
        expect(f.released, isTrue);
        expect(f.events.where((e) => e == 'releaseEngine'), hasLength(1));
        await f.finish();
      },
    );
  });
}
