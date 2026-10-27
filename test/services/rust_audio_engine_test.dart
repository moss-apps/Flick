import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/playback_state.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/rust_audio_engine.dart';
import 'package:flick/services/rust_audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

typedef PlayCall = ({String path, double? start, double? end});

class FakeRustAudioService implements RustAudioService {
  @override
  final stateNotifier = ValueNotifier(RustPlaybackState.idle);
  @override
  final positionNotifier = ValueNotifier(Duration.zero);
  @override
  final durationNotifier = ValueNotifier(Duration.zero);
  @override
  final bufferLevelNotifier = ValueNotifier(0.0);

  final plays = <PlayCall>[];
  final httpPlays = <PlayCall>[];
  final seeks = <Duration>[];
  bool failHttp = false;

  @override
  Future<void> play(String path, {double? startSecs, double? endSecs}) async {
    plays.add((path: path, start: startSecs, end: endSecs));
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> playHttp({
    required String url,
    Map<String, String> headers = const {},
    double? startSecs,
    double? endSecs,
  }) async {
    httpPlays.add((path: url, start: startSecs, end: endSecs));
    if (failHttp) throw StateError('HTTP unavailable');
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song track({int? start, int? end}) => Song(
  id: 'cue-${start ?? 'file'}',
  title: 'Track',
  artist: 'Artist',
  duration: const Duration(seconds: 18),
  fileType: 'FLAC',
  filePath: '/music/album.flac',
  startOffsetMs: start,
  endOffsetMs: end,
);

void main() {
  late FakeRustAudioService service;
  late RustAudioEngine engine;

  setUp(() {
    service = FakeRustAudioService();
    engine = RustAudioEngine(
      playbackMode: AudioEngineType.usbDacExperimental,
      rustAudioService: service,
      ensureInitialized: () async {},
      resolvePlaybackPath: (song) async => song.filePath,
      disposeEngine: () async {},
    );
  });

  tearDown(() async {
    await engine.dispose();
    service.stateNotifier.dispose();
    service.positionNotifier.dispose();
    service.durationNotifier.dispose();
    service.bufferLevelNotifier.dispose();
  });

  test(
    'local play forwards first, middle, final and unbounded tracks',
    () async {
      for (final song in [
        track(start: 0, end: 13000),
        track(start: 13000, end: 31000),
        track(start: 31000),
        track(),
      ]) {
        await engine.load(song);
        await engine.play();
      }

      expect(service.plays, [
        (path: '/music/album.flac', start: 0.0, end: 13.0),
        (path: '/music/album.flac', start: 13.0, end: 31.0),
        (path: '/music/album.flac', start: 31.0, end: null),
        (path: '/music/album.flac', start: null, end: null),
      ]);
      expect(service.seeks, isEmpty);
    },
  );

  test('deferred and active seeks remain track-relative', () async {
    await engine.load(track(start: 13000, end: 31000));
    await engine.seek(const Duration(seconds: 2));
    expect(service.seeks, isEmpty);
    await engine.play();
    await engine.seek(const Duration(seconds: 4));

    expect(service.seeks, [
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);
  });

  for (final fallback in [false, true]) {
    test('HTTP play retains bounds with cache fallback=$fallback', () async {
      await engine.dispose();
      service.failHttp = fallback;
      engine = RustAudioEngine(
        playbackMode: AudioEngineType.usbDacExperimental,
        rustAudioService: service,
        ensureInitialized: () async {},
        resolvePlaybackPath: (song) async => song.filePath,
        disposeEngine: () async {},
        resolveHttpSource: (_) async => (
          url: 'https://example.test/album.flac',
          headers: const {'Authorization': 'test'},
        ),
      );
      await engine.load(track(start: 13000, end: 31000));
      await engine.play();

      expect(service.httpPlays.single, (
        path: 'https://example.test/album.flac',
        start: 13.0,
        end: 31.0,
      ));
      expect(
        service.plays,
        fallback
            ? [(path: '/music/album.flac', start: 13.0, end: 31.0)]
            : isEmpty,
      );
    });
  }

  test('native progress and duration stay relative to the CUE track', () async {
    final states = <PlaybackState>[];
    final subscription = engine.playbackStateStream.listen(states.add);
    await engine.load(track(start: 13000, end: 31000));
    service.positionNotifier.value = const Duration(seconds: 3);
    service.durationNotifier.value = const Duration(milliseconds: 18001);
    await Future<void>.delayed(Duration.zero);

    expect(states.last.position, const Duration(seconds: 3));
    expect(states.last.duration, const Duration(milliseconds: 18001));
    await subscription.cancel();
  });
}
