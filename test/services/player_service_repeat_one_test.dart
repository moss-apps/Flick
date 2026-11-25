import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/data/database.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/audio_engine_manager.dart';
import 'package:flick/services/audio_session_manager.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/rust_audio_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/src/rust/audio/source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session extends Fake implements AudioSessionManager {
  @override
  final selectedModeNotifier = ValueNotifier(AudioEngineType.rustOboe);
  @override
  final initializedModeNotifier = ValueNotifier<AudioEngineType?>(
    AudioEngineType.rustOboe,
  );
  @override
  AudioEngineType get selectedMode => selectedModeNotifier.value;
  @override
  AudioEngineType? get initializedMode => initializedModeNotifier.value;
  @override
  String? get fallbackReason => null;
  @override
  void clearFallbackReason() {}
  @override
  void dispose() {
    selectedModeNotifier.dispose();
    initializedModeNotifier.dispose();
  }

  @override
  Future<void> switchMode(
    AudioEngineType mode, {
    bool initializeNewEngine = false,
    String reason = 'manual switch',
  }) async {}
}

class _Usb extends Fake implements Uac2Service {
  @override
  final bitPerfectEnabledNotifier = ValueNotifier(false);
  @override
  final dapBitPerfectEnabledNotifier = ValueNotifier(false);
  @override
  Uac2DeviceStatus? get currentDeviceStatus => null;
  @override
  bool get isBitPerfectEnabledSync => false;
}

class _Rust extends Fake implements RustAudioService {
  @override
  final crossfadeEnabledNotifier = ValueNotifier(true);
  @override
  final crossfadeDurationNotifier = ValueNotifier(4.0);
  @override
  bool get isInitialized => false;
  @override
  SourceIdentity? currentSource;
  @override
  BigInt? acceptedPlaybackId;

  @override
  void acceptNativeHandoff(BigInt playbackId) {
    acceptedPlaybackId = playbackId;
  }

  @override
  Future<void> stop() async {}
}

class _Manager extends Fake implements AudioEngineManager {
  final plays = <Song>[];
  final handoffs = <Song>[];
  late void Function(Song) onPlay;

  @override
  AudioEngineType get activeEngineType => AudioEngineType.rustOboe;

  @override
  Future<void> playTrack(
    Song track, {
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    expect(initialPosition, Duration.zero);
    plays.add(track);
    onPlay(track);
  }

  @override
  void updateTrack(Song track) => handoffs.add(track);

  @override
  Future<void> dispose() async {}
}

const _first = Song(
  id: 'first',
  title: 'First',
  artist: 'Test',
  duration: Duration(seconds: 13),
  fileType: 'FLAC',
  filePath: '/music/album.flac',
  startOffsetMs: 0,
  endOffsetMs: 13000,
);

const _second = Song(
  id: 'second',
  title: 'Second',
  artist: 'Test',
  duration: Duration(seconds: 18),
  fileType: 'FLAC',
  filePath: '/music/album.flac',
  startOffsetMs: 13000,
  endOffsetMs: 31000,
);

SourceIdentity _source(Song track, int id) => SourceIdentity(
  path: track.filePath!,
  range: PlaybackRange(
    startSecs: track.startOffsetMs! / 1000,
    endSecs: track.endOffsetMs! / 1000,
  ),
  playbackId: BigInt.from(id),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory databaseDir;
  late PlayerService player;
  late _Rust rust;
  late _Manager manager;
  late _Usb usb;
  late int playbackId;

  setUpAll(() async {
    databaseDir = await Directory.systemTemp.createTemp('flick_repeat_one');
    Isar.initializeIsarCore(libraries: {Abi.current(): _isarCorePath()});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    const playerChannel = MethodChannel('com.mossapps.flick/player');
    const overlay = MethodChannel('com.mossapps.flick/overlay');
    messenger.setMockMethodCallHandler(
      pathProvider,
      (_) async => databaseDir.path,
    );
    messenger.setMockMethodCallHandler(playerChannel, (_) async => null);
    messenger.setMockMethodCallHandler(overlay, (_) async => null);
    addTearDown(() async {
      await Database.close();
      messenger.setMockMethodCallHandler(pathProvider, null);
      messenger.setMockMethodCallHandler(playerChannel, null);
      messenger.setMockMethodCallHandler(overlay, null);
      await databaseDir.delete(recursive: true);
    });
    await Database.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rust = _Rust();
    manager = _Manager();
    usb = _Usb();
    playbackId = 2;
    player = PlayerService.forTesting(
      sessionManager: _Session(),
      uac2Service: usb,
      rustAudioService: rust,
      playbackManager: manager,
    );
    player.usingRustBackendNotifier.value = true;
    player.setPlaybackContextForTesting([_first, _second]);
    player.currentSongNotifier.value = _first;
    rust.currentSource = _source(_first, 1);
    rust.acceptedPlaybackId = rust.currentSource!.playbackId;
    manager.onPlay = (song) {
      rust.currentSource = _source(song, ++playbackId);
      rust.acceptedPlaybackId = rust.currentSource!.playbackId;
      player.currentSongNotifier.value = song;
    };
  });

  tearDown(() {
    player.dispose();
    rust.crossfadeEnabledNotifier.dispose();
    rust.crossfadeDurationNotifier.dispose();
    usb.bitPerfectEnabledNotifier.dispose();
    usb.dapBitPerfectEnabledNotifier.dispose();
  });

  test('late EOF cannot restart a new play of the same CUE range', () async {
    await player.setLoopMode(LoopMode.one);
    final outgoing = rust.currentSource!;

    final replay = player.play(_first);
    final lateEof = player.handleRustTrackEnded(outgoing, null);
    await replay;
    await lateEof;
    expect(manager.plays, [_first]);

    final replayed = rust.currentSource!;
    expect(replayed.path, outgoing.path);
    expect(replayed.range, outgoing.range);
    expect(replayed.playbackId, isNot(outgoing.playbackId));

    rust.currentSource = null;
    await player.handleRustTrackEnded(replayed, null);
    expect(manager.plays, [_first, _first]);
    await player.play(_second);
    await player.play(_first);
    expect(manager.plays, [_first, _first, _second, _first]);
    expect(player.currentSongNotifier.value, _first);
  });

  for (final fadeEventDelivered in [true, false]) {
    test(
      'Repeat One follows the fade handoff, early event=$fadeEventDelivered',
      () async {
        final outgoing = rust.currentSource!;
        final incoming = _source(_second, 2);
        rust.currentSource = incoming;
        if (fadeEventDelivered) {
          await player.handleRustCrossfadeStarted(outgoing, incoming);
          expect(player.currentSongNotifier.value, _second);
        }

        await player.setLoopMode(LoopMode.one);
        await player.handleRustTrackEnded(outgoing, incoming.playbackId);
        expect(manager.handoffs, [_second]);
        expect(manager.plays, isEmpty);
        expect(player.currentSongNotifier.value, _second);

        rust.currentSource = null;
        await player.handleRustTrackEnded(incoming, null);
        expect(manager.plays, [_second]);
      },
    );
  }
}
