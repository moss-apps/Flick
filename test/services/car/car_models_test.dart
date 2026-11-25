import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/car/car_models.dart';
import 'package:flick/services/player_service.dart';

Song song(
  String id, {
  String title = 'Title',
  String artist = 'Artist',
  String? album,
  String fileType = 'FLAC',
  int? bitDepth,
  int? sampleRate,
  String? art,
  int? trackNumber,
  int seconds = 180,
  String? filePath,
}) => Song(
  id: id,
  title: title,
  artist: artist,
  album: album,
  albumArt: art,
  duration: Duration(seconds: seconds),
  fileType: fileType,
  bitDepth: bitDepth,
  sampleRate: sampleRate,
  trackNumber: trackNumber,
  filePath: filePath,
);

void main() {
  group('carQualityLabel', () {
    test('PCM with bit depth and rate reads depth/kHz type', () {
      expect(
        carQualityLabel(song('1', bitDepth: 24, sampleRate: 96000)),
        '24/96 FLAC',
      );
      expect(
        carQualityLabel(song('1', bitDepth: 16, sampleRate: 48000)),
        '16/48 FLAC',
      );
    });

    test('keeps the decimal in 44.1 and the other fractional rates', () {
      expect(
        carQualityLabel(song('1', bitDepth: 16, sampleRate: 44100)),
        '16/44.1 FLAC',
      );
      expect(
        carQualityLabel(song('1', bitDepth: 24, sampleRate: 88200)),
        '24/88.2 FLAC',
      );
      expect(
        carQualityLabel(song('1', bitDepth: 24, sampleRate: 176400)),
        '24/176.4 FLAC',
      );
      expect(
        carQualityLabel(song('1', bitDepth: 24, sampleRate: 352800)),
        '24/352.8 FLAC',
      );
    });

    test('a whole kHz never shows a trailing .0', () {
      expect(
        carQualityLabel(song('1', bitDepth: 24, sampleRate: 192000)),
        '24/192 FLAC',
      );
    });

    test('DSD rates', () {
      Song dsd(int rate) => song(
        'd',
        fileType: 'DSF',
        sampleRate: rate,
        bitDepth: 1,
        filePath: '/m/a.dsf',
      );
      expect(carQualityLabel(dsd(2822400)), 'DSD64');
      expect(carQualityLabel(dsd(5644800)), 'DSD128');
      expect(carQualityLabel(dsd(11289600)), 'DSD256');
      expect(carQualityLabel(dsd(22579200)), 'DSD512');
    });

    test('DSD wins over bit depth and rate', () {
      final label = carQualityLabel(
        song('d', fileType: 'DFF', sampleRate: 5644800, bitDepth: 1),
      );
      expect(label, 'DSD128');
    });

    test('falls back to the file type without depth or rate', () {
      expect(carQualityLabel(song('1', fileType: 'MP3')), 'MP3');
      expect(
        carQualityLabel(song('1', fileType: 'MP3', sampleRate: 44100)),
        'MP3',
      );
      expect(carQualityLabel(song('1', fileType: 'AAC', bitDepth: 16)), 'AAC');
    });

    test('null when nothing is known', () {
      expect(carQualityLabel(song('1', fileType: 'unknown')), isNull);
      expect(carQualityLabel(song('1', fileType: 'UNKNOWN')), isNull);
      expect(carQualityLabel(song('1', fileType: '  ')), isNull);
    });

    test('depth and rate without a file type still read as a pair', () {
      expect(
        carQualityLabel(
          song('1', fileType: '', bitDepth: 24, sampleRate: 96000),
        ),
        '24/96',
      );
    });
  });

  group('carCommonQuality', () {
    final flac96 = song('a', bitDepth: 24, sampleRate: 96000);
    final flac96b = song('b', bitDepth: 24, sampleRate: 96000);
    final cd = song('c', bitDepth: 16, sampleRate: 44100);

    test('shared label', () {
      expect(carCommonQuality([flac96, flac96b]), '24/96 FLAC');
    });

    test('differing labels give null', () {
      expect(carCommonQuality([flac96, cd]), isNull);
    });

    test('one unknown track gives null', () {
      expect(
        carCommonQuality([flac96, song('u', fileType: 'unknown')]),
        isNull,
      );
    });

    test('empty gives null', () {
      expect(carCommonQuality(const []), isNull);
    });
  });

  group('map shapes', () {
    test('track map has exactly the contract keys', () {
      final map = carTrackMap(
        song(
          '7',
          title: 'So What',
          artist: 'Miles Davis',
          album: 'Kind of Blue',
          art: '/art/kob.jpg',
          bitDepth: 24,
          sampleRate: 192000,
          seconds: 562,
        ),
        trackNo: 1,
      );
      expect(map, {
        'id': '7',
        'title': 'So What',
        'artist': 'Miles Davis',
        'album': 'Kind of Blue',
        'art': '/art/kob.jpg',
        'durationMs': 562000,
        'quality': '24/192 FLAC',
        'trackNo': 1,
      });
    });

    test('optional track keys are omitted, not null', () {
      final map = carTrackMap(song('7', fileType: 'unknown'));
      expect(map.containsKey('art'), isFalse);
      expect(map.containsKey('quality'), isFalse);
      expect(map.containsKey('trackNo'), isFalse);
      expect(map['album'], '');
      expect(map['durationMs'], 180000);
    });

    test('a blank artist reads as the unknown artist', () {
      expect(carTrackMap(song('7', artist: ' '))['artist'], isNotEmpty);
    });

    test('collection map', () {
      expect(
        carCollectionMap(
          kind: CarKind.album,
          id: 'Kind of Blue',
          title: 'Kind of Blue',
          subtitle: 'Miles Davis',
          art: '/a.jpg',
          count: 5,
          quality: '24/192 FLAC',
        ),
        {
          'kind': 'album',
          'id': 'Kind of Blue',
          'title': 'Kind of Blue',
          'subtitle': 'Miles Davis',
          'art': '/a.jpg',
          'count': 5,
          'quality': '24/192 FLAC',
        },
      );
    });

    test('collection map omits empty optional keys', () {
      final map = carCollectionMap(
        kind: CarKind.playlist,
        id: 'p1',
        title: 'Mix',
        subtitle: '',
        art: '',
      );
      expect(map, {'kind': 'playlist', 'id': 'p1', 'title': 'Mix'});
    });

    test('track number is the tag only when it is a real number', () {
      expect(carTrackNumber(song('1', trackNumber: 4)), 4);
      expect(carTrackNumber(song('1', trackNumber: 0)), isNull);
      expect(carTrackNumber(song('1')), isNull);
    });
  });

  group('carLimit', () {
    test('uses the requested limit', () {
      expect(carLimit(50), 50);
      expect(carLimit(300), 300);
    });

    test('absent or invalid falls back', () {
      expect(carLimit(null), 300);
      expect(carLimit(0), 300);
      expect(carLimit(-5), 300);
      expect(carLimit('x'), 300);
      expect(carLimit(null, fallback: 100), 100);
    });

    test('is bounded above', () {
      expect(carLimit(100000), 1000);
      expect(carLimit(100000, max: 50), 50);
    });
  });

  group('LoopMode.sessionRepeat', () {
    test('maps every mode', () {
      expect(LoopMode.off.sessionRepeat, 'off');
      expect(LoopMode.one.sessionRepeat, 'one');
      expect(LoopMode.all.sessionRepeat, 'all');
      expect(LoopMode.stopAfterCurrent.sessionRepeat, 'off');
      expect(LoopMode.advanceAlbum.sessionRepeat, 'all');
      expect(LoopMode.advanceArtist.sessionRepeat, 'all');
      expect(LoopMode.advanceFolder.sessionRepeat, 'all');
      expect(LoopMode.advancePlaylist.sessionRepeat, 'all');
    });
  });

  group('CarUpcoming.split', () {
    final a = song('a');
    final b = song('b');
    final c = song('c');
    final d = song('d');
    final e = song('e');

    test('queued songs sit at the head of upNext and are not repeated', () {
      // The user queued b and c; upNext is the playlist after the current
      // song, so it already holds them first.
      final upcoming = CarUpcoming.split(
        upNext: [b, c, d, e],
        queued: [true, true, false, false],
        manualQueue: [b, c],
      );
      expect(upcoming.fromYou.map((s) => s.id), ['b', 'c']);
      expect(upcoming.fromContext.map((s) => s.id), ['d', 'e']);
      expect(upcoming.total, 4);
      expect(upcoming.fromManualQueue, isFalse);
      expect(upcoming.order, [0, 1, 2, 3]);
    });

    test('a song both queued and later in the context shows once per slot', () {
      final queuedA = song('a');
      final upcoming = CarUpcoming.split(
        upNext: [queuedA, b, a],
        queued: [true, false, false],
        manualQueue: [queuedA],
      );
      expect(upcoming.fromYou.map((s) => s.id), ['a']);
      expect(upcoming.fromContext.map((s) => s.id), ['b', 'a']);
      expect(upcoming.order, [0, 1, 2]);
    });

    test('no queue puts everything in context', () {
      final upcoming = CarUpcoming.split(
        upNext: [a, b],
        queued: [false, false],
      );
      expect(upcoming.fromYou, isEmpty);
      expect(upcoming.fromContext.map((s) => s.id), ['a', 'b']);
    });

    test(
      'a queued song moved into the list keeps its section and its slot',
      () {
        final upcoming = CarUpcoming.split(
          upNext: [a, b, c, d],
          queued: [false, true, false, true],
          manualQueue: [b, d],
        );
        expect(upcoming.fromYou.map((s) => s.id), ['b', 'd']);
        expect(upcoming.fromContext.map((s) => s.id), ['a', 'c']);
        // Rows are fromYou then fromContext; each maps to its own upNext index.
        expect(upcoming.order, [1, 3, 0, 2]);
      },
    );

    test('a short flag list counts the rest as context', () {
      final upcoming = CarUpcoming.split(upNext: [a, b, c], queued: [true]);
      expect(upcoming.fromYou.map((s) => s.id), ['a']);
      expect(upcoming.fromContext.map((s) => s.id), ['b', 'c']);
    });

    test('with nothing loaded the manual queue is the whole list', () {
      final upcoming = CarUpcoming.split(
        upNext: const [],
        queued: const [],
        manualQueue: [a, b],
      );
      expect(upcoming.fromManualQueue, isTrue);
      expect(upcoming.fromYou.map((s) => s.id), ['a', 'b']);
      expect(upcoming.fromContext, isEmpty);
      expect(upcoming.order, [0, 1]);
    });

    test('empty everything', () {
      final upcoming = CarUpcoming.split(upNext: const [], queued: const []);
      expect(upcoming.total, 0);
      expect(upcoming.order, isEmpty);
    });
  });

  group('carJumpRow', () {
    final upcoming = CarUpcoming.split(
      upNext: [song('a'), song('b'), song('c'), song('d')],
      queued: [true, true, false, false],
    );

    test('you rows are the first rows', () {
      expect(carJumpRow(upcoming, 'you', 0), 0);
      expect(carJumpRow(upcoming, 'you', 1), 1);
    });

    test('context rows follow the you rows', () {
      expect(carJumpRow(upcoming, 'context', 0), 2);
      expect(carJumpRow(upcoming, 'context', 1), 3);
    });

    test('out of range and unknown sections are rejected', () {
      expect(carJumpRow(upcoming, 'you', 2), isNull);
      expect(carJumpRow(upcoming, 'context', 2), isNull);
      expect(carJumpRow(upcoming, 'you', -1), isNull);
      expect(carJumpRow(upcoming, 'later', 0), isNull);
    });
  });

  group('carQueueMap', () {
    CarUpcoming upcoming(int you, int context) => CarUpcoming.split(
      upNext: [
        for (var i = 0; i < you; i++) song('y$i'),
        for (var i = 0; i < context; i++) song('c$i'),
      ],
      queued: [for (var i = 0; i < you + context; i++) i < you],
    );

    Map<String, Object?> map(
      CarUpcoming u, {
      int limit = 100,
      PlaybackContext context = PlaybackContext.unknown,
    }) => carQueueMap(
      current: song('now', title: 'Now'),
      upcoming: u,
      limit: limit,
      context: context,
      shuffle: true,
      loop: 'one',
    );

    test('shape', () {
      final result = map(
        upcoming(1, 1),
        context: const PlaybackContext(
          source: PlaybackSource.album,
          sourceId: 'Kind of Blue',
          sourceName: 'Kind of Blue',
        ),
      );
      expect(result.keys.toSet(), {
        'current',
        'fromYou',
        'fromContext',
        'contextName',
        'shuffle',
        'loop',
      });
      expect((result['current']! as Map)['title'], 'Now');
      expect(result['contextName'], 'Kind of Blue');
      expect(result['shuffle'], true);
      expect(result['loop'], 'one');
    });

    test('no current song and no context', () {
      final result = carQueueMap(
        current: null,
        upcoming: upcoming(0, 0),
        limit: 100,
        context: PlaybackContext.unknown,
        shuffle: false,
        loop: 'off',
      );
      expect(result['current'], isNull);
      expect(result.containsKey('contextName'), isFalse);
      expect(result['fromYou'], isEmpty);
      expect(result['fromContext'], isEmpty);
    });

    test('an unknown context hides its name even when one is set', () {
      final result = map(
        upcoming(0, 1),
        context: const PlaybackContext(
          source: PlaybackSource.unknown,
          sourceName: 'x',
        ),
      );
      expect(result.containsKey('contextName'), isFalse);
    });

    test('the limit caps both sections together, you first', () {
      final result = map(upcoming(3, 10), limit: 5);
      expect((result['fromYou']! as List), hasLength(3));
      expect((result['fromContext']! as List), hasLength(2));
    });

    test('the limit can be used up by the user queue alone', () {
      final result = map(upcoming(8, 10), limit: 5);
      expect((result['fromYou']! as List), hasLength(5));
      expect((result['fromContext']! as List), isEmpty);
    });
  });

  group('carStartSong', () {
    final songs = [song('a'), song('b'), song('c')];

    test('starts at the requested track', () {
      expect(carStartSong(songs, trackId: 'b').id, 'b');
      expect(carStartSong(songs, trackId: 'b', shuffle: true).id, 'b');
    });

    test('an unknown track falls back to the first', () {
      expect(carStartSong(songs, trackId: 'zzz').id, 'a');
    });

    test('shuffle picks within the list', () {
      final seen = <String>{};
      final random = math.Random(3);
      for (var i = 0; i < 40; i++) {
        seen.add(carStartSong(songs, shuffle: true, random: random).id);
      }
      expect(seen, {'a', 'b', 'c'});
    });

    test('no shuffle starts at the first song', () {
      expect(carStartSong(songs).id, 'a');
    });
  });
}
