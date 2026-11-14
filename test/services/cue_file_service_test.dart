import 'package:flutter_test/flutter_test.dart';

import 'package:flick/services/cue_file_service.dart';

void main() {
  final service = CueFileService();

  group('CueTrack.durationMs', () {
    test('uses the next index for a bounded track', () {
      const track = CueTrack(
        trackNumber: 2,
        title: 'Two',
        performer: 'Artist',
        startOffsetMs: 13000,
        endOffsetMs: 31000,
      );
      expect(track.durationMs(sourceDurationMs: 60000), 18000);
    });

    test('subtracts the final start from the source duration', () {
      const track = CueTrack(
        trackNumber: 3,
        title: 'Three',
        performer: 'Artist',
        startOffsetMs: 31000,
      );
      expect(track.durationMs(sourceDurationMs: 60000), 29000);
      expect(track.durationMs(), 0);
      expect(track.durationMs(sourceDurationMs: 0), 0);
      expect(track.durationMs(sourceDurationMs: 30000), 0);
    });
  });

  group('CueFileService CUE parsing', () {
    test('keeps the first track when it starts at zero', () {
      const cue = '''
PERFORMER "Artist"
TITLE "Album"
FILE "album.flac" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 03:20:00
  TRACK 03 AUDIO
    TITLE "Three"
    INDEX 01 07:10:00
''';

      final sheet = service.parseCueSheet(cue, cueFilePath: '/music/album.cue');

      expect(sheet, isNotNull);
      expect(sheet!.tracks.map((track) => track.trackNumber), [1, 2, 3]);
      expect(sheet.tracks.map((track) => track.title), ['One', 'Two', 'Three']);
      expect(sheet.tracks.map((track) => track.startOffsetMs), [
        0,
        200000,
        430000,
      ]);
      expect(sheet.tracks.map((track) => track.endOffsetMs), [
        200000,
        430000,
        null,
      ]);
    });

    test('keeps a first track that has a pregap index', () {
      const cue = '''
FILE "album.flac" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    INDEX 00 00:00:00
    INDEX 01 00:02:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 00:05:00
''';

      final sheet = service.parseCueSheet(cue, cueFilePath: '/music/album.cue');

      expect(sheet, isNotNull);
      expect(sheet!.tracks.map((track) => track.trackNumber), [1, 2]);
      expect(sheet.tracks.first.startOffsetMs, 2000);
      expect(sheet.tracks.first.endOffsetMs, 5000);
    });

    test('keeps a single-track sheet intact', () {
      const cue = '''
FILE "album.flac" WAVE
  TRACK 01 AUDIO
    TITLE "Only"
    INDEX 01 00:00:00
''';

      final sheet = service.parseCueSheet(cue, cueFilePath: '/music/album.cue');

      expect(sheet, isNotNull);
      expect(sheet!.tracks, hasLength(1));
      expect(sheet.tracks.single.trackNumber, 1);
      expect(sheet.tracks.single.title, 'Only');
      expect(sheet.tracks.single.startOffsetMs, 0);
      expect(sheet.tracks.single.endOffsetMs, isNull);
    });

    test('splits a multi-FILE sheet into one sheet per audio file', () {
      const cue = '''
PERFORMER "Artist"
TITLE "Album"
FILE "disc1/01.flac" WAVE
  TRACK 01 AUDIO
    TITLE "One"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Two"
    INDEX 01 03:20:00
FILE "disc1/02.flac" WAVE
  TRACK 03 AUDIO
    TITLE "Three"
    INDEX 01 00:00:00
''';

      final sheets = service.parseCueSheets(
        cue,
        cueFilePath: '/music/album.cue',
      );

      expect(sheets, hasLength(2));
      expect(sheets.map((sheet) => sheet.audioFile), [
        'disc1/01.flac',
        'disc1/02.flac',
      ]);
      expect(sheets.every((sheet) => sheet.title == 'Album'), isTrue);
      expect(sheets[0].tracks.map((track) => track.trackNumber), [1, 2]);
      expect(sheets[0].tracks.map((track) => track.startOffsetMs), [0, 200000]);
      expect(sheets[0].tracks.first.endOffsetMs, 200000);
      expect(sheets[0].tracks.last.endOffsetMs, isNull);
      expect(sheets[1].tracks.single.title, 'Three');
      expect(sheets[1].tracks.single.startOffsetMs, 0);
      expect(sheets[1].tracks.single.endOffsetMs, isNull);
    });

    test('parseCueSheet keeps the first block for compatibility', () {
      const cue = '''
FILE "one.flac" WAVE
  TRACK 01 AUDIO
    INDEX 01 00:00:00
FILE "two.flac" WAVE
  TRACK 02 AUDIO
    INDEX 01 00:00:00
''';

      final sheet = service.parseCueSheet(cue, cueFilePath: '/music/a.cue');

      expect(sheet?.audioFile, 'one.flac');
      expect(sheet?.tracks.single.trackNumber, 1);
    });

    test('resolves relative audio paths and normalizes separators', () {
      expect(
        service.resolveAudioFilePath('/music/album.cue', 'album.flac'),
        '/music/album.flac',
      );
      expect(
        service.resolveAudioFilePath('/music/album.cue', 'disc1/01.flac'),
        '/music/disc1/01.flac',
      );
      expect(
        service.resolveAudioFilePath('/music/album.cue', r'disc1\01.flac'),
        '/music/disc1/01.flac',
      );
      expect(
        service.resolveAudioFilePath('/music/album.cue', '/sdcard/01.flac'),
        '/sdcard/01.flac',
      );
    });

    test('parses CRLF sheets with a BOM and global metadata', () {
      const cue =
          '\uFEFFPERFORMER "Artist"\r\n'
          'TITLE "Album"\r\n'
          'REM DATE 2024\r\n'
          'REM GENRE "Jazz"\r\n'
          'FILE "album.flac" WAVE\r\n'
          '  TRACK 01 AUDIO\r\n'
          '    TITLE "One"\r\n'
          '    INDEX 01 00:00:00\r\n'
          '  TRACK 02 AUDIO\r\n'
          '    TITLE "Two"\r\n'
          '    INDEX 01 01:00:00\r\n';

      final sheet = service.parseCueSheet(cue, cueFilePath: '/music/album.cue');

      expect(sheet, isNotNull);
      expect(sheet!.performer, 'Artist');
      expect(sheet.title, 'Album');
      expect(sheet.date, '2024');
      expect(sheet.genre, 'Jazz');
      expect(sheet.audioFile, 'album.flac');
      expect(sheet.tracks.map((track) => track.trackNumber), [1, 2]);
    });
  });
}
