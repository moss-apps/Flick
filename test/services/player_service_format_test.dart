import 'package:flick/models/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/android_audio_engine.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/src/rust/api/audio_api.dart' show AudioProbeFormat;

void main() {
  group('canonicalPlaybackFileType', () {
    test('prefers the real file extension over stale stored file type', () {
      expect(
        canonicalPlaybackFileType(
          fileType: 'M4A',
          filePath: '/music/library/example.ogg',
        ),
        'ogg',
      );
    });

    test('normalizes mime-style and ogg-family values', () {
      expect(
        canonicalPlaybackFileType(fileType: 'audio/ogg', filePath: null),
        'ogg',
      );
      expect(
        canonicalPlaybackFileType(fileType: 'audio/mp4', filePath: null),
        'm4a',
      );
      expect(
        canonicalPlaybackFileType(fileType: 'OpUs', filePath: null),
        'opus',
      );
      expect(
        canonicalPlaybackFileType(fileType: '.oga', filePath: null),
        'ogg',
      );
    });
  });

  group('resolveDirectUsbTrackFormat', () {
    const flac = Song(
      id: 'flac',
      title: '24-bit test track',
      artist: 'Test',
      duration: Duration(seconds: 1),
      fileType: 'FLAC',
      sampleRate: 44100,
    );
    const assumed = Uac2AudioFormat(
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
    );

    test('uses the file format instead of a guessed 16-bit depth', () async {
      final result = await resolveDirectUsbTrackFormat(
        flac,
        metadataFormat: assumed,
        probe: () async => const AudioProbeFormat(
          sampleRate: 96000,
          bitsPerSample: 24,
          channels: 2,
        ),
      );
      expect(result?.sampleRate, 96000);
      expect(result?.bitDepth, 24);
      expect(result?.channels, 2);
    });

    test('does not guess when the source has no readable FLAC depth', () async {
      expect(
        await resolveDirectUsbTrackFormat(
          flac,
          metadataFormat: assumed,
          probe: () async => const AudioProbeFormat(
            sampleRate: 44100,
            channels: 2,
          ),
        ),
        isNull,
      );
      expect(
        await resolveDirectUsbTrackFormat(
          flac,
          metadataFormat: assumed,
          probe: () async => null,
        ),
        isNull,
      );
    });

    test('does not probe complete FLAC metadata or DSD transport', () async {
      expect(
        await resolveDirectUsbTrackFormat(
          flac.copyWith(bitDepth: 16),
          metadataFormat: assumed,
          probe: () async => throw StateError('unexpected probe'),
        ),
        same(assumed),
      );
      const dsd = Uac2AudioFormat(
        sampleRate: 176400,
        bitDepth: 24,
        channels: 2,
        isDop: true,
      );
      expect(
        await resolveDirectUsbTrackFormat(
          flac.copyWith(fileType: 'DSF'),
          metadataFormat: dsd,
          probe: () async => throw StateError('unexpected probe'),
        ),
        same(dsd),
      );
    });
  });

  group('shouldOptimisticallySyncSkipForLoopMode', () {
    test('disables optimistic UI skip sync for repeat-one only', () {
      expect(shouldOptimisticallySyncSkipForLoopMode(LoopMode.off), isTrue);
      expect(shouldOptimisticallySyncSkipForLoopMode(LoopMode.all), isTrue);
      expect(shouldOptimisticallySyncSkipForLoopMode(LoopMode.one), isFalse);
    });
  });

  group('shouldHandleManualCompletion', () {
    test('keeps manual completion handling for the Rust backend', () {
      expect(
        shouldHandleManualCompletion(
          usingRustBackend: true,
          loopMode: LoopMode.off,
        ),
        isTrue,
      );
      expect(
        shouldHandleManualCompletion(
          usingRustBackend: true,
          loopMode: LoopMode.one,
        ),
        isTrue,
      );
      expect(
        shouldHandleManualCompletion(
          usingRustBackend: true,
          loopMode: LoopMode.all,
        ),
        isTrue,
      );
    });

    test('lets just_audio own repeat-one and repeat-all completion', () {
      expect(
        shouldHandleManualCompletion(
          usingRustBackend: false,
          loopMode: LoopMode.off,
        ),
        isTrue,
      );
      expect(
        shouldHandleManualCompletion(
          usingRustBackend: false,
          loopMode: LoopMode.one,
        ),
        isFalse,
      );
      expect(
        shouldHandleManualCompletion(
          usingRustBackend: false,
          loopMode: LoopMode.all,
        ),
        isFalse,
      );
    });
  });

  group('shouldUseFastStartCurrentTrackOnly', () {
    test('disables fast-start when repeat-all is active', () {
      expect(
        shouldUseFastStartCurrentTrackOnly(
          allowFastStart: false,
          loadedSingleTrackOnly: false,
          sequenceIsEmpty: true,
          playlistLength: 100,
        ),
        isFalse,
      );
    });

    test('allows fast-start only for large eligible playlists', () {
      expect(
        shouldUseFastStartCurrentTrackOnly(
          allowFastStart: true,
          loadedSingleTrackOnly: false,
          sequenceIsEmpty: true,
          playlistLength: 25,
        ),
        isTrue,
      );

      expect(
        shouldUseFastStartCurrentTrackOnly(
          allowFastStart: true,
          loadedSingleTrackOnly: false,
          sequenceIsEmpty: true,
          playlistLength: 24,
        ),
        isFalse,
      );
    });
  });

  group('shouldExitSingleTrackMode', () {
    test('exits single-track mode once a real playlist is loaded', () {
      expect(
        shouldExitSingleTrackMode(
          loadedSingleTrackOnly: true,
          playerSequenceLength: 2,
        ),
        isTrue,
      );
    });

    test('stays in single-track mode for empty or single-item sequences', () {
      expect(
        shouldExitSingleTrackMode(
          loadedSingleTrackOnly: true,
          playerSequenceLength: 0,
        ),
        isFalse,
      );
      expect(
        shouldExitSingleTrackMode(
          loadedSingleTrackOnly: true,
          playerSequenceLength: 1,
        ),
        isFalse,
      );
      expect(
        shouldExitSingleTrackMode(
          loadedSingleTrackOnly: false,
          playerSequenceLength: 3,
        ),
        isFalse,
      );
    });
  });
}
