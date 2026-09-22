import 'package:test/test.dart';

import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/services/audio_preload_service.dart';

void main() {
  group('AudioPreloadService auto suppression', () {
    late AudioPreloadService service;

    setUp(() {
      service = AudioPreloadService();
      service.clearAutoSuppression();
    });

    SongEntity song() => SongEntity()
      ..id = 1
      ..filePath = '/music/track.flac'
      ..title = 'Track'
      ..artist = 'Artist';

    test('starts unsuppressed', () {
      expect(service.isAutoSuppressed, isFalse);
    });

    test('cancel suppresses later auto passes', () async {
      service.cancel();

      expect(service.isAutoSuppressed, isTrue);
      await service.enqueueAutoPreload([song()]);

      expect(service.isRunning, isFalse);
      expect(service.progress.value, isNull);
    });

    test('clearAutoSuppression lifts the block', () {
      service.cancel();
      service.clearAutoSuppression();

      expect(service.isAutoSuppressed, isFalse);
    });

    test('cancel clears visible progress immediately', () {
      service.progress.value = const PreloadProgress(completed: 1, total: 5);

      service.cancel();

      expect(service.progress.value, isNull);
      expect(service.isRunning, isFalse);
    });

    test('cancel while idle is a no-op', () {
      expect(() => service.cancel(), returnsNormally);
      expect(service.progress.value, isNull);
    });
  });

  group('AudioPreloadService.shouldNegativeCache', () {
    test('negative-caches undecodable formats case-insensitively', () {
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.dsf'), isTrue);
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.DSF'), isTrue);
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.dff'), isTrue);
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.WV'), isTrue);
    });

    test('supported formats are not negative-cached', () {
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.flac'), isFalse);
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.mp3'), isFalse);
      expect(AudioPreloadService.shouldNegativeCache('/a/b/track.wav'), isFalse);
    });

    test('malformed paths are not negative-cached', () {
      expect(AudioPreloadService.shouldNegativeCache('noext'), isFalse);
      expect(AudioPreloadService.shouldNegativeCache('trailing.'), isFalse);
      expect(AudioPreloadService.shouldNegativeCache(''), isFalse);
    });
  });
}
