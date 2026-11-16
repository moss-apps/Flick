import 'package:flick/services/rust_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RustAudioService event polling cadence', () {
    test('keeps 50ms polling while the pipeline is active', () {
      for (final state in [
        RustPlaybackState.playing,
        RustPlaybackState.buffering,
        RustPlaybackState.crossfading,
      ]) {
        expect(
          RustAudioService.eventPollIntervalForState(state),
          const Duration(milliseconds: 50),
          reason: '$state should poll events at 50ms',
        );
      }
    });

    test('backs off to 500ms when playback is inactive', () {
      for (final state in [
        RustPlaybackState.paused,
        RustPlaybackState.idle,
        RustPlaybackState.stopped,
      ]) {
        expect(
          RustAudioService.eventPollIntervalForState(state),
          const Duration(milliseconds: 500),
          reason: '$state should poll events at 500ms',
        );
      }
    });
  });

  group('RustAudioService state refresh fallback', () {
    test('waits for the slow interval before rereading engine state', () {
      expect(
        RustAudioService.isStateRefreshFallbackDue(Duration.zero),
        isFalse,
      );
      expect(
        RustAudioService.isStateRefreshFallbackDue(
          const Duration(milliseconds: 1999),
        ),
        isFalse,
      );
      expect(
        RustAudioService.isStateRefreshFallbackDue(const Duration(seconds: 2)),
        isTrue,
      );
    });

    test('is slower than every event polling cadence', () {
      for (final state in RustPlaybackState.values) {
        expect(
          RustAudioService.isStateRefreshFallbackDue(
            RustAudioService.eventPollIntervalForState(state),
          ),
          isFalse,
          reason: '$state event polling must not trigger the fallback',
        );
      }
    });
  });
}
