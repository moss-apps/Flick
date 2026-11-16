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
}
