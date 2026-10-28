import 'package:flutter_test/flutter_test.dart';

import 'package:flick/models/album_completeness.dart';
import 'package:flick/models/song.dart';
import 'package:flick/data/repositories/song_repository.dart';

Song _song({
  required int track,
  int? disc = 1,
  int? trackTotal,
  int? discTotal,
}) {
  return Song(
    id: '${disc ?? 1}-$track',
    title: 'Track $track',
    artist: 'Artist',
    album: 'Album',
    duration: const Duration(minutes: 3),
    fileType: 'FLAC',
    trackNumber: track,
    trackTotal: trackTotal,
    discNumber: disc,
    discTotal: discTotal,
  );
}

List<Song> _tracks(
  int count, {
  int disc = 1,
  int? trackTotal,
  int? discTotal,
  int start = 1,
}) {
  return [
    for (var track = start; track < start + count; track++)
      _song(
        track: track,
        disc: disc,
        trackTotal: trackTotal,
        discTotal: discTotal,
      ),
  ];
}

void main() {
  group('AlbumCompleteness.resolve', () {
    test('reports a complete single-disc album from its total tag', () {
      final result = AlbumCompleteness.resolve(_tracks(12, trackTotal: 12));

      expect(result.isComplete, isTrue);
      expect(result.expectedTrackCount, 12);
      expect(result.missingTracks, isEmpty);
      expect(result.missingDiscs, isEmpty);
    });

    test('reports a missing final track', () {
      final result = AlbumCompleteness.resolve(_tracks(11, trackTotal: 12));

      expect(result.isIncomplete, isTrue);
      expect(result.missingTrackNumbers, [12]);
      expect(result.missingTracks.single.discNumber, 1);
    });

    test('reports a missing middle track', () {
      final songs = [
        _song(track: 1, trackTotal: 4),
        _song(track: 2, trackTotal: 4),
        _song(track: 4, trackTotal: 4),
      ];

      final result = AlbumCompleteness.resolve(songs);

      expect(result.isIncomplete, isTrue);
      expect(result.missingTrackNumbers, [3]);
    });

    test('duplicate numbering cannot hide a missing position', () {
      final songs = [
        _song(track: 1, trackTotal: 4),
        _song(track: 2, trackTotal: 4),
        _song(track: 2, trackTotal: 4),
        _song(track: 4, trackTotal: 4),
      ];

      final result = AlbumCompleteness.resolve(songs);

      expect(result.isIncomplete, isTrue);
      expect(result.missingTrackNumbers, [3]);
    });

    test('unknown when total tags are absent', () {
      final result = AlbumCompleteness.resolve(_tracks(5));

      expect(result.isUnknown, isTrue);
    });

    test('unknown when track totals conflict', () {
      final songs = [
        _song(track: 1, trackTotal: 3),
        _song(track: 2, trackTotal: 4),
        _song(track: 3, trackTotal: 3),
      ];

      expect(AlbumCompleteness.resolve(songs).isUnknown, isTrue);
    });

    test('unknown when a track exceeds its declared total', () {
      final result = AlbumCompleteness.resolve(_tracks(4, trackTotal: 3));

      expect(result.isUnknown, isTrue);
    });

    test('unknown when a disc has no total', () {
      final songs = [
        ..._tracks(3, trackTotal: 3, discTotal: 2),
        ..._tracks(3, disc: 2, discTotal: 2),
      ];

      expect(AlbumCompleteness.resolve(songs).isUnknown, isTrue);
    });

    test('unknown when track numbers are absent', () {
      final songs = [
        _song(track: 0, trackTotal: 3),
        _song(track: 2, trackTotal: 3),
      ];

      expect(AlbumCompleteness.resolve(songs).isUnknown, isTrue);
    });

    test('unknown when disc totals conflict', () {
      final songs = [
        ..._tracks(2, trackTotal: 2, discTotal: 2),
        ..._tracks(2, disc: 2, trackTotal: 2, discTotal: 3),
      ];

      expect(AlbumCompleteness.resolve(songs).isUnknown, isTrue);
    });

    test('reports a missing whole disc', () {
      final result = AlbumCompleteness.resolve(
        _tracks(10, trackTotal: 10, discTotal: 2),
      );

      expect(result.isIncomplete, isTrue);
      expect(result.missingDiscs, [2]);
      expect(result.missingTracks, isEmpty);
    });

    test('reports a gap between disc numbers without a disc total', () {
      final songs = [
        ..._tracks(10, trackTotal: 10),
        ..._tracks(10, disc: 3, trackTotal: 10),
      ];

      final result = AlbumCompleteness.resolve(songs);

      expect(result.isIncomplete, isTrue);
      expect(result.missingDiscs, [2]);
    });

    test(
      'complete multi-disc album with per-disc totals and reset numbering',
      () {
        final songs = [
          ..._tracks(10, trackTotal: 10, discTotal: 2),
          ..._tracks(10, disc: 2, trackTotal: 10, discTotal: 2),
        ];

        final result = AlbumCompleteness.resolve(songs);

        expect(result.isComplete, isTrue);
        expect(result.expectedTrackCount, 20);
      },
    );

    test('continuous numbering across discs is ambiguous, not complete', () {
      final songs = [
        ..._tracks(10, trackTotal: 20, discTotal: 2),
        ..._tracks(10, disc: 2, start: 11, trackTotal: 20, discTotal: 2),
      ];

      final result = AlbumCompleteness.resolve(songs);

      expect(result.isUnknown, isTrue);
    });

    test('reports a missing track on the second disc', () {
      final songs = [
        ..._tracks(10, trackTotal: 10, discTotal: 2),
        ..._tracks(9, disc: 2, trackTotal: 10, discTotal: 2),
      ];

      final result = AlbumCompleteness.resolve(songs);

      expect(result.isIncomplete, isTrue);
      expect(result.missingTracks, [
        const AlbumTrackPosition(discNumber: 2, trackNumber: 10),
      ]);
      expect(result.hasDiscSpecificMissingTracks, isTrue);
    });

    test('complementary incomplete discs cannot look album-wide complete', () {
      final songs = [
        ..._tracks(5, trackTotal: 10, discTotal: 2),
        ..._tracks(5, disc: 2, start: 6, trackTotal: 10, discTotal: 2),
      ];
      expect(AlbumCompleteness.resolve(songs).isUnknown, isTrue);
    });

    test('multiple discs need a disc total to certify completion', () {
      final songs = [
        ..._tracks(2, trackTotal: 2),
        ..._tracks(2, disc: 2, trackTotal: 2),
      ];
      expect(AlbumCompleteness.resolve(songs).isUnknown, isTrue);
    });

    test('copies of the same track do not change completeness', () {
      final songs = _tracks(3, trackTotal: 3);
      expect(
        AlbumCompleteness.resolve([...songs, songs.first]).isComplete,
        isTrue,
      );
    });

    test('different titles at the same position suggest mixed editions', () {
      final songs = _tracks(3, trackTotal: 3);
      expect(
        AlbumCompleteness.resolve([
          ...songs,
          songs.first.copyWith(title: 'Bonus track'),
        ]).isUnknown,
        isTrue,
      );
    });

    test('different album artists cannot certify a combined group', () {
      expect(
        AlbumCompleteness.resolve([
          _song(track: 1, trackTotal: 2).copyWith(albumArtist: 'Artist A'),
          _song(track: 2, trackTotal: 2).copyWith(albumArtist: 'Artist B'),
        ]).isUnknown,
        isTrue,
      );
    });

    test('mixed missing and explicit disc numbers stay unknown', () {
      expect(
        AlbumCompleteness.resolve([
          _song(track: 1, disc: null, trackTotal: 2),
          _song(track: 2, trackTotal: 2),
        ]).isUnknown,
        isTrue,
      );
    });

    test(
      'huge, zero, and negative total tags are rejected without allocation',
      () {
        for (final value in [-1, 0, 4294967295]) {
          expect(
            AlbumCompleteness.resolve([
              _song(track: 1, trackTotal: value),
            ]).isUnknown,
            isTrue,
          );
          expect(
            AlbumCompleteness.resolve([
              _song(track: 1, trackTotal: 1, discTotal: value),
            ]).isUnknown,
            isTrue,
          );
        }
      },
    );

    test('an unknown disc cannot bypass the total positions budget', () {
      final result = AlbumCompleteness.resolve([
        _song(track: 1, discTotal: 3),
        _song(track: 1, disc: 2, trackTotal: 6000, discTotal: 3),
        _song(track: 1, disc: 3, trackTotal: 6000, discTotal: 3),
      ]);
      expect(result.isUnknown, isTrue);
    });

    test('missing entire discs have no invented album-wide track count', () {
      final result = AlbumCompleteness.resolve(
        _tracks(3, trackTotal: 3, discTotal: 2),
      );
      expect(result.isIncomplete, isTrue);
      expect(result.expectedTrackCount, isNull);
    });
  });

  group('full-library resolution', () {
    final allSongs = _tracks(3, trackTotal: 3);
    final album = AlbumGroup(
      key: 'Album',
      albumName: 'Album',
      albumArtist: 'Artist',
      songs: allSongs,
    );

    test(
      'a partial search result is resolved using the full library group',
      () {
        expect(
          AlbumCompleteness.resolve(allSongs.take(1)).isIncomplete,
          isTrue,
        );
        final result = SongRepository.resolveAlbumCompleteness(
          [album],
          albumName: ' album ',
          albumArtist: 'ARTIST',
        );
        expect(result.isComplete, isTrue);
      },
    );

    test('missing and ambiguous full album identities stay unknown', () {
      for (final groups in [
        <AlbumGroup>[],
        [album, album],
      ]) {
        expect(
          SongRepository.resolveAlbumCompleteness(
            groups,
            albumName: 'Album',
            albumArtist: 'Artist',
          ).isUnknown,
          isTrue,
        );
      }
      expect(
        SongRepository.resolveAlbumCompleteness(
          [album],
          albumName: 'Album',
          albumArtist: 'Other artist',
        ).isUnknown,
        isTrue,
      );
    });
  });
}
