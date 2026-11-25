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
  final seekPlayAttempts = <int>[];
  @override
  String? currentPath;
  bool failHttp = false;
  bool failPlay = false;
  int resumes = 0;
  int _activePlayAttempt = 0;

  @override
  Future<void> pause() async {
    stateNotifier.value = RustPlaybackState.paused;
  }

  @override
  Future<void> resume() async {
    resumes++;
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> play(String path, {double? startSecs, double? endSecs}) async {
    plays.add((path: path, start: startSecs, end: endSecs));
    if (failPlay) throw StateError('Play unavailable');
    currentPath = path;
    _activePlayAttempt = plays.length + httpPlays.length;
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
    _activePlayAttempt = plays.length + httpPlays.length;
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    seekPlayAttempts.add(_activePlayAttempt);
  }

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

  for (final sameTrack in [false, true]) {
    test('staged seek waits for the new play, same track=$sameTrack', () async {
      final first = track();
      await engine.load(first);
      await engine.play();
      service.positionNotifier.value = const Duration(seconds: 7);

      final second = sameTrack ? first : track(start: 13000, end: 31000);
      await engine.load(second);
      const target = Duration(seconds: 2);
      await engine.seek(target);
      expect(service.seeks, isEmpty);

      service.failPlay = true;
      await expectLater(engine.play(), throwsStateError);
      expect(service.seeks, isEmpty);

      service.failPlay = false;
      await engine.play();
      expect(service.plays, hasLength(3));
      expect(service.seeks, [target]);
      expect(service.seekPlayAttempts, [3]);
    });
  }

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

  test('track switch during playback restores the playing UI state', () async {
    final states = <PlaybackState>[];
    final subscription = engine.playbackStateStream.listen(states.add);
    await engine.load(track());
    await engine.play();
    await Future<void>.delayed(Duration.zero);
    expect(states.last.isPlaying, isTrue);

    // Loading a selection is not playback: the previous track is still
    // audible until the native engine accepts the switch.
    await engine.load(track(start: 13000, end: 31000));
    await Future<void>.delayed(Duration.zero);
    expect(states.last.isPlaying, isTrue);
    expect(states.last.currentTrack?.id, 'cue-file');
    await engine.play();
    await Future<void>.delayed(Duration.zero);

    expect(service.stateNotifier.value, RustPlaybackState.playing);
    expect(states.last.isPlaying, isTrue);
    expect(states.last.currentTrack?.id, 'cue-13000');
    await subscription.cancel();
  });

  test('failed play keeps the previous track visible and retry succeeds', () async {
    final states = <PlaybackState>[];
    final subscription = engine.playbackStateStream.listen(states.add);
    final first = track();
    final second = track(start: 13000, end: 31000);
    await engine.load(first);
    await engine.play();
    await Future<void>.delayed(Duration.zero);
    expect(states.last.currentTrack?.id, first.id);

    service.failPlay = true;
    await engine.load(second);
    await expectLater(engine.play(), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(states.last.currentTrack?.id, first.id);
    expect(states.last.isPlaying, isTrue);
    expect(states.last.duration, first.duration);

    service.failPlay = false;
    await engine.play();
    await Future<void>.delayed(Duration.zero);
    expect(states.last.currentTrack?.id, second.id);
    expect(states.last.isPlaying, isTrue);
    expect(service.plays, hasLength(3));
    await subscription.cancel();
  });

  group('managed audio focus', () {
    late bool granted;
    late int requests;
    late bool useHttp;

    setUp(() async {
      await engine.dispose();
      granted = true;
      requests = 0;
      useHttp = true;
      engine = RustAudioEngine(
        playbackMode: AudioEngineType.rustOboe,
        rustAudioService: service,
        ensureInitialized: () async {},
        resolvePlaybackPath: (song) async => song.filePath,
        resolveHttpSource: (_) async {
          if (!useHttp) return null;
          return (
            url: 'https://example.test/album.flac',
            headers: const <String, String>{},
          );
        },
        disposeEngine: () async {},
        requestAudioFocus: () async {
          requests++;
          expect(service.stateNotifier.value, isNot(RustPlaybackState.playing));
          return granted;
        },
      );
    });

    test('play without a source does not acquire focus', () async {
      await expectLater(engine.play(), throwsStateError);
      expect(requests, 0);
    });

    for (final http in [false, true]) {
      test(
        'loading does not acquire focus and denied play can be retried, HTTP=$http',
        () async {
          useHttp = http;
          await engine.load(track());
          expect(requests, 0);
          granted = false;
          await engine.play();
          expect(service.plays, isEmpty);
          expect(service.httpPlays, isEmpty);
          expect(service.resumes, 0);

          granted = true;
          await engine.play();
          expect(requests, 2);
          expect(service.httpPlays, http ? hasLength(1) : isEmpty);
          expect(service.plays, http ? isEmpty : hasLength(1));
        },
      );
    }

    test(
      'every resume reacquires focus without reloading or seeking',
      () async {
        await engine.load(track());
        await engine.play();
        service.positionNotifier.value = const Duration(seconds: 7);
        await engine.pause();
        granted = false;
        await engine.play();
        expect(service.resumes, 0);
        expect(service.stateNotifier.value, RustPlaybackState.paused);

        granted = true;
        await engine.play();
        expect(requests, 3);
        expect(service.resumes, 1);
        expect(service.httpPlays, hasLength(1));
        expect(service.seeks, isEmpty);
        expect(service.positionNotifier.value, const Duration(seconds: 7));
      },
    );

    test('a fresh track on a reused engine also requests focus', () async {
      await engine.load(track());
      await engine.play();
      await engine.pause();
      await engine.load(track(start: 13000, end: 31000));
      await engine.play();
      expect(requests, 2);
      expect(service.httpPlays, hasLength(2));
      expect(service.resumes, 0);
    });
  });
}
