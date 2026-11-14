import 'package:flutter_test/flutter_test.dart';

import 'package:flick/services/library_scanner_service.dart';

void main() {
  const albumDir = '/storage/1234-5678/Music/Album';
  const files = {
    albumDir: {
      '01 - one.flac': '$albumDir/01 - One.flac',
      '02 - two.flac': '$albumDir/02 - Two.flac',
    },
  };

  group('LibraryScannerService.resolveCueAudioPath', () {
    test('resolves an exact basename', () {
      expect(
        LibraryScannerService.resolveCueAudioPath(
          cuePath: '$albumDir/album.cue',
          audioFile: '01 - One.flac',
          audioFilesByDir: files,
        ),
        '$albumDir/01 - One.flac',
      );
    });

    test('resolves a stale extension through a unique stem', () {
      expect(
        LibraryScannerService.resolveCueAudioPath(
          cuePath: '$albumDir/album.cue',
          audioFile: '01 - One.wav',
          audioFilesByDir: files,
        ),
        '$albumDir/01 - One.flac',
      );
    });

    test('resolves a relative subdirectory', () {
      const nested = {
        '$albumDir/disc1': {'01.flac': '$albumDir/disc1/01.flac'},
      };
      expect(
        LibraryScannerService.resolveCueAudioPath(
          cuePath: '$albumDir/album.cue',
          audioFile: 'disc1/01.flac',
          audioFilesByDir: nested,
        ),
        '$albumDir/disc1/01.flac',
      );
    });

    test('refuses to guess between multiple same-stem files', () {
      const ambiguous = {
        albumDir: {
          '01 - one.flac': '$albumDir/01 - One.flac',
          '01 - one.wav': '$albumDir/01 - One.wav',
        },
      };
      expect(
        LibraryScannerService.resolveCueAudioPath(
          cuePath: '$albumDir/album.cue',
          audioFile: '01 - One.ape',
          audioFilesByDir: ambiguous,
        ),
        isNull,
      );
    });

    test('returns null when the referenced file is absent', () {
      expect(
        LibraryScannerService.resolveCueAudioPath(
          cuePath: '$albumDir/album.cue',
          audioFile: 'missing.flac',
          audioFilesByDir: files,
        ),
        isNull,
      );
    });
  });
}
