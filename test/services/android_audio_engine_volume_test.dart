import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/android_audio_engine.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

class _Player extends Fake implements just_audio.AudioPlayer {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final volumes = <double>[];
  Completer<void>? playCompletion;
  Completer<void>? sourcePreparation;
  bool failSourcePreparation = false;
  double _volume = 1.0;
  bool _playing = false;

  @override
  double get volume => _volume;
  @override
  bool get playing => _playing;
  @override
  double get speed => 1.0;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedPosition => Duration.zero;
  @override
  Duration get duration => const Duration(seconds: 3);
  @override
  int get currentIndex => 0;
  @override
  List<just_audio.IndexedAudioSource> get sequence => const [];

  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<just_audio.PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<just_audio.PlaybackEvent> get playbackEventStream =>
      const Stream.empty();
  @override
  Stream<just_audio.SequenceState> get sequenceStateStream =>
      const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<just_audio.ProcessingState> get processingStateStream =>
      const Stream.empty();
  @override
  Stream<just_audio.PlayerException> get errorStream => const Stream.empty();

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    _volume = volume;
  }

  @override
  Future<Duration?> setAudioSource(
    just_audio.AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    await sourcePreparation?.future;
    if (failSourcePreparation) throw StateError('source preparation failed');
    return duration;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setLoopMode(just_audio.LoopMode mode) async {}
  @override
  Future<void> play() {
    _playing = true;
    return playCompletion?.future ?? Future<void>.value();
  }

  @override
  Future<void> pause() async => _playing = false;
  @override
  Future<void> stop() async => _playing = false;
  @override
  Future<void> dispose() async {
    if (!positions.isClosed) await positions.close();
  }
}

const _firstSong = Song(
  id: 'first',
  title: 'First',
  artist: 'Test',
  duration: Duration(seconds: 3),
  filePath: '/first.flac',
  fileType: 'FLAC',
);
const _secondSong = Song(
  id: 'second',
  title: 'Second',
  artist: 'Test',
  duration: Duration(seconds: 3),
  filePath: '/second.flac',
  fileType: 'FLAC',
);

({
  AndroidAudioEngine engine,
  _Player first,
  _Player second,
  List<just_audio.AudioPlayer> active,
})
_fixture({double initialVolume = 0.8}) {
  final first = _Player();
  final second = _Player();
  final active = <just_audio.AudioPlayer>[];
  final engine = AndroidAudioEngine(
    playerProvider: () async => first,
    secondaryPlayerProvider: () async => second,
    sourcesBuilder: () async =>
        just_audio.AudioSource.uri(Uri.file('/first.flac')),
    sourceBuilder: (song) async =>
        just_audio.AudioSource.uri(Uri.file(song.filePath!)),
    playlistProvider: () => const [_firstSong, _secondSong],
    configurePlayer: (player) => player.setVolume(initialVolume),
    disposeEngine: () async {
      await first.dispose();
      await second.dispose();
    },
    shouldSuppressTrackSync: () => false,
    shouldIgnoreTrack: (_) => false,
    shouldFastStartCurrentTrackOnly: () => false,
    crossfadeConfigProvider: () => const AndroidCrossfadeConfig(
      enabled: true,
      durationSecs: 1.0,
      curve: AndroidCrossfadeCurve.equalPower,
    ),
    onNextSong: () => _secondSong,
    onActivePlayerChanged: active.add,
  );
  return (engine: engine, first: first, second: second, active: active);
}

void main() {
  testWidgets('safety gain controls both slots and survives every ramp tick', (
    tester,
  ) async {
    final f = _fixture();
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    expect(f.active.last, same(f.second));

    await f.engine.setVolume(0.25);
    for (var tick = 0; tick < 50; tick++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(f.first.volume, lessThanOrEqualTo(0.25));
      expect(f.second.volume, lessThanOrEqualTo(0.25));
    }
    expect(f.second.volume, closeTo(0.25, 1e-9));
    expect(f.first.playing, isFalse);

    // After the fade, only the new active slot should receive user gain.
    await f.engine.setVolume(0.1);
    expect(f.second.volume, 0.1);
    expect(f.active, [f.first, f.second]);
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('muted playback never becomes full-scale when a fade starts', (
    tester,
  ) async {
    final f = _fixture(initialVolume: 0.0);
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(f.first.volume, 0.0);
    expect(f.second.volume, 0.0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(f.second.volume, 0.0);
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('muting a paused fade survives resume and cancellation', (
    tester,
  ) async {
    final f = _fixture();
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await f.engine.pause();
    await f.engine.setVolume(0.0);
    await f.engine.play();
    await tester.pump(const Duration(milliseconds: 200));
    expect(f.first.volume, 0.0);
    expect(f.second.volume, 0.0);
    await f.engine.seek(Duration.zero);
    expect(f.second.volume, 0.0);
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('resume does not wait for either player to finish playback', (
    tester,
  ) async {
    final f = _fixture();
    f.first.playCompletion = Completer<void>();
    f.second.playCompletion = Completer<void>();
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await f.engine.pause();
    await f.engine.setVolume(0.25);

    var resumed = false;
    final resume = f.engine.play().then((_) => resumed = true);
    await tester.pump();
    expect(resumed, isTrue);
    await resume;
    await tester.pump(const Duration(milliseconds: 800));
    expect(f.second.volume, 0.25);
    expect(f.first.playing, isFalse);
    f.first.playCompletion!.complete();
    f.second.playCompletion!.complete();
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('a safety pause during source preparation is not undone', (
    tester,
  ) async {
    final f = _fixture();
    f.second.sourcePreparation = Completer<void>();
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    expect(f.active.last, same(f.first));
    await f.engine.pause();
    await f.engine.setVolume(0.0);
    f.second.sourcePreparation!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(f.first.playing, isFalse);
    expect(f.second.playing, isFalse);

    await f.engine.play();
    await tester.pump(const Duration(seconds: 1));
    expect(f.second.volume, 0.0);
    expect(f.first.volume, 0.0);
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('cancelling a preparing fade cannot restart its incoming slot', (
    tester,
  ) async {
    final f = _fixture();
    f.second.sourcePreparation = Completer<void>();
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    await f.engine.seek(Duration.zero);
    f.second.sourcePreparation!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(f.active.last, same(f.first));
    expect(f.second.playing, isFalse);
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('resuming during preparation does not ramp the wrong slots', (
    tester,
  ) async {
    final f = _fixture();
    f.second.sourcePreparation = Completer<void>();
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    await f.engine.pause();
    await f.engine.setVolume(0.25);
    await f.engine.play();
    await tester.pump(const Duration(milliseconds: 200));
    expect(f.second.playing, isFalse);
    expect(f.first.volume, 0.25);

    f.second.sourcePreparation!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(f.second.volume, 0.25);
    expect(f.first.playing, isFalse);
    await tester.runAsync(f.engine.dispose);
  });

  testWidgets('a failed fade preparation cannot restore unity over mute', (
    tester,
  ) async {
    final f = _fixture(initialVolume: 0.0);
    f.second.failSourcePreparation = true;
    await f.engine.load(_firstSong);
    await f.engine.play();
    f.first.positions.add(const Duration(milliseconds: 2400));
    await tester.pump();
    expect(f.active.last, same(f.first));
    expect(f.first.volume, 0.0);
    expect(f.second.playing, isFalse);
    await tester.runAsync(f.engine.dispose);
  });
}
