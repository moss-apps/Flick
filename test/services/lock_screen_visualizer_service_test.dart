import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/lock_screen_visualizer_service.dart';
import 'package:flick/services/visualizer_source.dart';

class _Source extends VisualizerSource {
  @override
  VisualizerSourceMode mode = VisualizerSourceMode.rustFft;
  @override
  List<double>? bars;
  @override
  bool isAvailable = true;
  @override
  bool needsPermission = false;
  int acquired = 0;
  int released = 0;
  int prepared = 0;
  bool permissionResult = true;
  Future<bool> Function()? prepareOverride;

  @override
  Future<bool> prepare() async {
    prepared++;
    if (prepareOverride != null) return prepareOverride!();
    return permissionResult;
  }

  @override
  void acquire() {
    acquired++;
  }

  @override
  void release() {
    released++;
  }

  void emit() => notifyListeners();
}

const _song = Song(
  id: '1',
  title: 'Title',
  artist: 'Artist',
  duration: Duration(minutes: 3),
  fileType: 'FLAC',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.mossapps.flick/lock_screen_visualizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Source source;
  late ValueNotifier<bool> playing;
  late ValueNotifier<Song?> song;
  late LockScreenVisualizerService service;
  late List<MethodCall> calls;
  var canOpen = true;

  Future<void> native(String method, [Object? data]) async {
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, data)),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> visible({bool shown = true, bool motion = true}) =>
      native('visibility', {'visible': shown, 'motionAllowed': motion});

  setUp(() {
    calls = [];
    canOpen = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'canOpen' => canOpen,
        'open' => true,
        _ => null,
      };
    });
    source = _Source();
    playing = ValueNotifier(true);
    song = ValueNotifier(_song);
    service = LockScreenVisualizerService(
      source: source,
      isPlaying: playing,
      currentSong: song,
    );
  });

  tearDown(() {
    service.dispose();
    source.dispose();
    playing.dispose();
    song.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('off by default and independent from the in-app visualizer', () async {
    service.configure(const AppPreferences());
    await visible();
    expect(await service.open(), isFalse);
    expect(source.acquired, 0);
    service.configure(
      const AppPreferences(
        lockScreenVisualizerEnabled: true,
        visualizerEnabled: false,
      ),
    );
    expect(source.acquired, 1);
    expect(source.prepared, 0); // A visibility callback never prompts.
  });

  test(
    'explicit open prepares only while unlocked; enabling never opens',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      expect(calls.where((call) => call.method == 'open'), isEmpty);
      canOpen = false;
      expect(await service.open(), isFalse);
      expect(source.prepared, 0);
      canOpen = true;
      expect(await service.open(), isTrue);
      expect(source.prepared, 1);
      expect(source.acquired, 0); // Wait for native visibility.
    },
  );

  test('denied permission never opens the native screen', () async {
    service.configure(const AppPreferences(lockScreenVisualizerEnabled: true));
    source.permissionResult = false;
    expect(await service.open(), isFalse);
    expect(calls.where((call) => call.method == 'open'), isEmpty);
    expect(source.acquired, 0);
  });

  test(
    'preparation failure is recoverable and clears the opening guard',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      source.prepareOverride = () async =>
          throw PlatformException(code: 'permission');
      expect(await service.open(), isFalse);
      source.prepareOverride = null;
      expect(await service.open(), isTrue);
    },
  );

  test(
    'dispose during permission resolution cannot launch or acquire',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      final permission = Completer<bool>();
      source.prepareOverride = () => permission.future;
      final opening = service.open();
      await Future<void>.delayed(Duration.zero);
      expect(await service.open(), isFalse);
      service.dispose();
      permission.complete(true);
      expect(await opening, isFalse);
      expect(calls.where((call) => call.method == 'open'), isEmpty);
      expect(source.acquired, 0);
    },
  );

  test(
    'real frames do not resend configuration and all immersive preferences pass through',
    () async {
      service.configure(
        const AppPreferences(
          lockScreenVisualizerEnabled: true,
          visualizerColorMode: 'rainbow',
          visualizerAnimationStyle: 'blocks',
          visualizerFrequencyMode: 'bass_treble',
          visualizerMovementMode: 'smooth',
        ),
      );
      await visible();
      final state =
          calls.lastWhere((call) => call.method == 'state').arguments as Map;
      expect(state.containsKey('title'), isFalse);
      expect(state.containsKey('artist'), isFalse);
      expect(state.containsKey('playLabel'), isFalse);
      expect(state['colorMode'], 'rainbow');
      expect(state['animationStyle'], 'blocks');
      expect(state['frequencyMode'], 'bass_treble');
      expect(state['movementMode'], 'smooth');
      expect(state['live'], isTrue);
      expect(state['animate'], isTrue);
      final metadataCount = calls
          .where((call) => call.method == 'state')
          .length;
      for (var i = 0; i < 20; i++) {
        source.bars = List.filled(48, i / 20);
        source.emit();
      }
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.where((call) => call.method == 'state').length,
        metadataCount,
      );
      playing.value = false;
      await Future<void>.delayed(Duration.zero);
      final paused =
          calls.lastWhere((call) => call.method == 'state').arguments as Map;
      expect(paused['live'], isFalse);
      expect(paused['animate'], isTrue); // Ease out, without keeping capture.
      expect(source.released, 1);
      expect(
        calls.lastWhere((call) => call.method == 'bars').arguments,
        isNull,
      );
    },
  );

  test('source frames while hidden do not republish state', () async {
    service.configure(
      const AppPreferences(
        lockScreenVisualizerEnabled: true,
        simulatedAodEnabled: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final stateCount = calls.where((call) => call.method == 'state').length;
    for (var i = 0; i < 20; i++) {
      source.bars = List.filled(48, i / 20);
      source.emit();
    }
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((call) => call.method == 'state').length, stateCount);
    expect(calls.where((call) => call.method == 'bars'), isEmpty);
    expect(source.acquired, 0);
  });

  test(
    'capture follows visible, awake, playing, motion and track state',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      expect(source.acquired, 0);
      await visible();
      await visible();
      expect(source.acquired, 1);
      await visible(shown: false);
      expect(source.released, 1);
      await visible();
      expect(source.acquired, 2);
      playing.value = false;
      expect(source.released, 2);
      playing.value = true;
      expect(source.acquired, 3);
      await visible(motion: false);
      expect(source.released, 3);
      await visible();
      service.configure(
        const AppPreferences(
          lockScreenVisualizerEnabled: true,
          animationsEnabled: false,
        ),
      );
      expect(source.released, 4);
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      song.value = null;
      expect(source.released, 5);
    },
  );

  test(
    'unsupported route or DSD releases without changing audio or prompting',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      await visible();
      source.mode = VisualizerSourceMode.unavailable;
      source.isAvailable = false;
      source.emit();
      expect(source.released, 1);
      source.mode = VisualizerSourceMode.dsdUnavailable;
      source.emit();
      expect(source.acquired, 1);
      expect(source.prepared, 0);
      source.mode = VisualizerSourceMode.android;
      source.needsPermission = true;
      source.emit();
      expect(source.acquired, 1);
      expect(source.prepared, 0);
      source.isAvailable = true;
      source.needsPermission = false;
      source.emit();
      expect(source.acquired, 2);
    },
  );

  test(
    'sends real bars only while visible and exposes no playback commands',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      await native('togglePlayPause');
      expect(source.acquired, 0);
      await visible();
      await native('togglePlayPause');
      expect(source.acquired, 1);
      source.bars = List.filled(48, 0.4);
      source.emit();
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.lastWhere((call) => call.method == 'bars').arguments,
        List.filled(48, 0.4),
      );
      await visible(shown: false);
      final barsCount = calls.where((call) => call.method == 'bars').length;
      source.emit();
      await native('togglePlayPause');
      expect(calls.where((call) => call.method == 'bars').length, barsCount);
      expect(source.released, 1);
    },
  );

  test(
    'simulated AOD arms without prompting and publishes state while hidden',
    () async {
      service.configure(
        const AppPreferences(
          lockScreenVisualizerEnabled: true,
          simulatedAodEnabled: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      Map<Object?, Object?> lastConfigure() =>
          calls.lastWhere((call) => call.method == 'configure').arguments
              as Map;
      Map<Object?, Object?> lastState() =>
          calls.lastWhere((call) => call.method == 'state').arguments as Map;

      expect(lastConfigure()['enabled'], isTrue);
      expect(lastConfigure()['simulatedAod'], isTrue);
      expect(lastConfigure()['armed'], isTrue);
      expect(lastState()['live'], isFalse);
      expect(lastState()['playing'], isTrue);
      expect(lastState()['supported'], isTrue);
      expect(source.acquired, 0);
      expect(source.prepared, 0);

      playing.value = false;
      await Future<void>.delayed(Duration.zero);
      expect(lastConfigure()['armed'], isFalse);
      expect(lastState()['playing'], isFalse);

      playing.value = true;
      source.mode = VisualizerSourceMode.android;
      source.needsPermission = true;
      source.isAvailable = false;
      source.emit();
      await Future<void>.delayed(Duration.zero);
      expect(lastConfigure()['armed'], isFalse);
      expect(source.prepared, 0);

      source.needsPermission = false;
      source.isAvailable = true;
      source.emit();
      await Future<void>.delayed(Duration.zero);
      expect(lastConfigure()['armed'], isTrue);

      service.configure(
        const AppPreferences(
          lockScreenVisualizerEnabled: true,
          simulatedAodEnabled: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(lastConfigure()['simulatedAod'], isFalse);
      expect(lastConfigure()['armed'], isFalse);
      expect(source.prepared, 0);
    },
  );

  test(
    'disable and dispose each release their own source reference once',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      await visible();
      service.configure(const AppPreferences());
      expect(source.released, 1);
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      expect(source.acquired, 2);
      service.dispose();
      service.dispose();
      expect(source.released, 2);
      source.emit();
      expect(source.acquired, 2);
    },
  );

  test(
    'drops intermediate frames instead of queuing channel traffic',
    () async {
      service.configure(
        const AppPreferences(lockScreenVisualizerEnabled: true),
      );
      await visible();
      final blocked = Completer<Object?>();
      var frames = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'bars' && ++frames == 1) return blocked.future;
        return null;
      });
      source.bars = List.filled(48, 0.1);
      source.emit();
      await Future<void>.delayed(Duration.zero);
      for (var i = 2; i <= 9; i++) {
        source.bars = List.filled(48, i / 10);
        source.emit();
      }
      expect(frames, 1);
      blocked.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(frames, 2);
      expect(calls.last.arguments, List.filled(48, 0.9));
    },
  );
}
