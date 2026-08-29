import 'package:test/test.dart';

import 'package:flick/services/audio_preload_service.dart';

void main() {
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
