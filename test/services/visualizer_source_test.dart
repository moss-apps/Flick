import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/visualizer_service.dart';
import 'package:flick/services/visualizer_source.dart';
import 'package:flick/src/rust/api/visualizer_api.dart';

class _FakePlayer extends Fake implements PlayerService {
  _FakePlayer(this.engine);

  AudioEngineType engine;
  bool dop = false;
  int? sessionId = 42;

  @override
  late final selectedPlaybackModeNotifier = ValueNotifier(engine);

  @override
  final initializedPlaybackModeNotifier = ValueNotifier<AudioEngineType?>(null);

  @override
  final bitPerfectProcessingLockedNotifier = ValueNotifier(false);

  @override
  final isPlayingNotifier = ValueNotifier(true);

  @override
  final currentSongNotifier = ValueNotifier<Song?>(null);

  @override
  AudioEngineType get currentEngineType => engine;

  @override
  bool get isCurrentTrackDoP => dop;

  @override
  int? get androidAudioSessionId => sessionId;

  void changeEngine(AudioEngineType next) {
    engine = next;
    selectedPlaybackModeNotifier.value = next;
  }

  @override
  void dispose() {
    selectedPlaybackModeNotifier.dispose();
    initializedPlaybackModeNotifier.dispose();
    bitPerfectProcessingLockedNotifier.dispose();
    isPlayingNotifier.dispose();
    currentSongNotifier.dispose();
  }
}

class _FakeAndroidService extends VisualizerService {
  final attachCalls = <int>[];
  var detachCalls = 0;
  var attachResult = true;

  @override
  Future<bool> attach(int sessionId) async {
    attachCalls.add(sessionId);
    if (!attachResult) return false;
    barHeightsNotifier.value = List<double>.filled(48, 0.4);
    return true;
  }

  @override
  Future<void> detach() async {
    detachCalls++;
    barHeightsNotifier.value = null;
  }

  @override
  void dispose() {
    barHeightsNotifier.dispose();
  }
}

VisualizerBars _frame(int sequence, {double value = 0.5}) => VisualizerBars(
  bars: Float32List.fromList(List<double>.filled(48, value)),
  sampleRate: 48000,
  sequence: BigInt.from(sequence),
);

void main() {
  group('source resolution', () {
    test('maps every engine and DSD path to the right source', () {
      final player = _FakePlayer(AudioEngineType.rustOboe);
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: _FakeAndroidService(),
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      expect(controller.mode, VisualizerSourceMode.rustFft);

      player.changeEngine(AudioEngineType.normalAndroid);
      expect(controller.mode, VisualizerSourceMode.android);

      player.changeEngine(AudioEngineType.usbDacExperimental);
      expect(controller.mode, VisualizerSourceMode.unavailable);

      player.changeEngine(AudioEngineType.dapInternalHighRes);
      expect(controller.mode, VisualizerSourceMode.unavailable);

      player.engine = AudioEngineType.rustOboe;
      player.dop = true;
      player.changeEngine(AudioEngineType.rustOboe);
      expect(controller.mode, VisualizerSourceMode.dsdUnavailable);
    });
  });

  group('High Quality rust source', () {
    test('polls bars, activates and releases the PCM tap', () async {
      final player = _FakePlayer(AudioEngineType.rustOboe);
      final activeCalls = <bool>[];
      var sequence = 0;
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: _FakeAndroidService(),
        rustGetBars: () async => _frame(++sequence),
        rustSetActive: ({required bool active}) async {
          activeCalls.add(active);
          return true;
        },
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      controller.acquire();
      await pumpEventQueue();

      expect(activeCalls, [true]);
      expect(controller.bars, isNotNull);
      expect(controller.bars, hasLength(48));
      final firstSequence = sequence;

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(sequence, greaterThan(firstSequence));

      controller.release();
      await pumpEventQueue();

      expect(activeCalls, [true, false]);
      expect(controller.bars, isNull);
    });

    test('does not start while playback is paused', () async {
      final player = _FakePlayer(AudioEngineType.rustOboe);
      player.isPlayingNotifier.value = false;
      final activeCalls = <bool>[];
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: _FakeAndroidService(),
        rustGetBars: () async => _frame(1),
        rustSetActive: ({required bool active}) async {
          activeCalls.add(active);
          return true;
        },
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      controller.acquire();
      await pumpEventQueue();
      expect(activeCalls, isEmpty);

      player.isPlayingNotifier.value = true;
      await pumpEventQueue();
      expect(activeCalls, [true]);
    });
  });

  group('Standard Android source', () {
    test(
      'attaches with the session id and detaches on engine change',
      () async {
        final player = _FakePlayer(AudioEngineType.normalAndroid);
        final android = _FakeAndroidService();
        final controller = VisualizerSourceController(
          playerService: player,
          androidService: android,
          androidPlatform: true,
          permissionResolver: ({required bool request}) async => true,
        );
        addTearDown(() {
          controller.dispose();
          player.dispose();
        });

        expect(await controller.prepare(), isTrue);
        expect(controller.isAvailable, isTrue);

        controller.acquire();
        await pumpEventQueue();

        expect(android.attachCalls, [42]);
        expect(controller.bars, isNotNull);

        android.barHeightsNotifier.value = List<double>.filled(48, 0.8);
        expect(controller.bars!.first, closeTo(0.8, 1e-9));

        player.changeEngine(AudioEngineType.rustOboe);
        await pumpEventQueue();

        expect(controller.mode, VisualizerSourceMode.rustFft);
        expect(android.detachCalls, greaterThan(0));
        expect(controller.bars, isNull);
      },
    );

    test('stays unavailable when permission is denied', () async {
      final player = _FakePlayer(AudioEngineType.normalAndroid);
      final android = _FakeAndroidService();
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: android,
        androidPlatform: true,
        permissionResolver: ({required bool request}) async => false,
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      expect(await controller.prepare(), isFalse);
      expect(controller.isAvailable, isFalse);
      controller.acquire();
      await pumpEventQueue();
      expect(android.attachCalls, isEmpty);
      expect(controller.bars, isNull);
    });

    test('attaches after permission is granted later', () async {
      final player = _FakePlayer(AudioEngineType.normalAndroid);
      final android = _FakeAndroidService();
      var granted = false;
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: android,
        androidPlatform: true,
        permissionResolver: ({required bool request}) async => granted,
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      expect(await controller.prepare(), isFalse);
      controller.acquire();
      await pumpEventQueue();
      expect(android.attachCalls, isEmpty);

      granted = true;
      expect(await controller.prepare(), isTrue);
      await pumpEventQueue();

      expect(android.attachCalls, [42]);
      expect(controller.bars, isNotNull);
    });

    test('reports unavailable when the native attach fails', () async {
      final player = _FakePlayer(AudioEngineType.normalAndroid);
      final android = _FakeAndroidService()..attachResult = false;
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: android,
        androidPlatform: true,
        permissionResolver: ({required bool request}) async => true,
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      await controller.prepare();
      controller.acquire();
      await pumpEventQueue();

      expect(android.attachCalls, [42]);
      expect(controller.bars, isNull);
    });

    test('never touches Android capture for the Rust engine', () async {
      final player = _FakePlayer(AudioEngineType.rustOboe);
      final android = _FakeAndroidService();
      final controller = VisualizerSourceController(
        playerService: player,
        androidService: android,
        androidPlatform: true,
        rustGetBars: () async => _frame(1),
        rustSetActive: ({required bool active}) async => true,
      );
      addTearDown(() {
        controller.dispose();
        player.dispose();
      });

      controller.acquire();
      await pumpEventQueue();

      expect(android.attachCalls, isEmpty);
      expect(controller.mode, VisualizerSourceMode.rustFft);
    });
  });
}
