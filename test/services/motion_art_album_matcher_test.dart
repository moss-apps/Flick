import 'package:flick/services/motion_art/motion_art_album_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MotionArtAlbumMatcher.normalize', () {
    test('lowercases, strips punctuation and accents', () {
      expect(MotionArtAlbumMatcher.normalize('Beyoncé — Renaissance!'),
          'beyonce renaissance');
      expect(MotionArtAlbumMatcher.normalize("Taylor's Version"),
          'taylor s version');
    });
  });

  group('MotionArtAlbumMatcher.baseName', () {
    test('drops parenthetical edition suffixes', () {
      expect(
        MotionArtAlbumMatcher.baseName("Fearless (Taylor's Version)"),
        'fearless',
      );
      expect(
        MotionArtAlbumMatcher.baseName('1989 (Deluxe Edition)'),
        '1989',
      );
    });

    test('drops trailing edition words', () {
      expect(MotionArtAlbumMatcher.baseName('Fearless Deluxe'), 'fearless');
    });
  });

  group('MotionArtAlbumMatcher.editionTokens', () {
    test('detects the Taylor Version phrase', () {
      expect(
        MotionArtAlbumMatcher.editionTokens("Fearless (Taylor's Version)"),
        contains('taylor s version'),
      );
    });

    test('detects deluxe/remastered', () {
      expect(
        MotionArtAlbumMatcher.editionTokens('Abbey Road (Remastered)'),
        contains('remastered'),
      );
    });

    test('returns empty for a plain album', () {
      expect(MotionArtAlbumMatcher.editionTokens('Random Access Memories'),
          isEmpty);
    });
  });

  group('MotionArtAlbumMatcher.nameMatchesAlbum', () {
    test('rejects the original when Taylor Version is requested', () {
      expect(
        MotionArtAlbumMatcher.nameMatchesAlbum(
          requested: "Fearless (Taylor's Version)",
          candidate: 'Fearless',
        ),
        isFalse,
      );
    });

    test('accepts the matching edition', () {
      expect(
        MotionArtAlbumMatcher.nameMatchesAlbum(
          requested: "Fearless (Taylor's Version)",
          candidate: "Fearless (Taylor's Version)",
        ),
        isTrue,
      );
    });

    test('plain request accepts any edition of the same base album', () {
      expect(
        MotionArtAlbumMatcher.nameMatchesAlbum(
          requested: '1989',
          candidate: '1989 (Deluxe)',
        ),
        isTrue,
      );
    });

    test('rejects a different album entirely', () {
      expect(
        MotionArtAlbumMatcher.nameMatchesAlbum(
          requested: 'Red',
          candidate: '1989',
        ),
        isFalse,
      );
    });
  });

  group('MotionArtAlbumMatcher.pickCollectionId', () {
    test('prefers the requested edition over the original', () {
      final id = MotionArtAlbumMatcher.pickCollectionId(
        album: "Fearless (Taylor's Version)",
        artist: 'Taylor Swift',
        results: const [
          {
            'collectionId': 1440924803,
            'collectionName': 'Fearless',
            'artistName': 'Taylor Swift',
          },
          {
            'collectionId': 1552791073,
            'collectionName': "Fearless (Taylor's Version)",
            'artistName': 'Taylor Swift',
          },
        ],
      );
      expect(id, '1552791073');
    });

    test('plain request prefers the original over an edition', () {
      final id = MotionArtAlbumMatcher.pickCollectionId(
        album: 'Fearless',
        artist: 'Taylor Swift',
        results: const [
          {
            'collectionId': 1552791073,
            'collectionName': "Fearless (Taylor's Version)",
            'artistName': 'Taylor Swift',
          },
          {
            'collectionId': 1440924803,
            'collectionName': 'Fearless',
            'artistName': 'Taylor Swift',
          },
        ],
      );
      expect(id, '1440924803');
    });

    test('ignores results by another artist', () {
      final id = MotionArtAlbumMatcher.pickCollectionId(
        album: 'Thriller',
        artist: 'Michael Jackson',
        results: const [
          {
            'collectionId': 1,
            'collectionName': 'Thriller',
            'artistName': 'Someone Else',
          },
        ],
      );
      expect(id, isNull);
    });
  });

  group('MotionArtAlbumMatcher.rankCollectionIds', () {
    test('returns every matching edition best-first, deduped', () {
      final ids = MotionArtAlbumMatcher.rankCollectionIds(
        album: "Fearless (Taylor's Version)",
        artist: 'Taylor Swift',
        results: const [
          {
            'collectionId': 1440924803,
            'collectionName': 'Fearless',
            'artistName': 'Taylor Swift',
          },
          {
            'collectionId': 1552791073,
            'collectionName': "Fearless (Taylor's Version)",
            'artistName': 'Taylor Swift',
          },
          {
            'collectionId': 1552791073,
            'collectionName': "Fearless (Taylor's Version)",
            'artistName': 'Taylor Swift',
          },
          {
            'collectionId': 1,
            'collectionName': "Fearless (Taylor's Version)",
            'artistName': 'Someone Else',
          },
        ],
      );
      expect(ids, ['1552791073', '1440924803']);
    });

    test('plain request keeps the original ahead of extra editions', () {
      final ids = MotionArtAlbumMatcher.rankCollectionIds(
        album: 'Fearless',
        artist: 'Taylor Swift',
        results: const [
          {
            'collectionId': 1552791073,
            'collectionName': "Fearless (Taylor's Version)",
            'artistName': 'Taylor Swift',
          },
          {
            'collectionId': 1440924803,
            'collectionName': 'Fearless',
            'artistName': 'Taylor Swift',
          },
        ],
      );
      expect(ids, ['1440924803', '1552791073']);
    });
  });

  group('MotionArtAlbumMatcher.rankCollectionIdsFromSongs', () {
    const songs = [
      {
        'collectionId': 111,
        'collectionName': 'DRIVE',
        'artistName': 'Tiësto',
        'trackName': 'All Nighter',
      },
      {
        'collectionId': 222,
        'collectionName': 'DRIVE',
        'artistName': 'Tiësto',
        'trackName': '10:35',
      },
      {
        'collectionId': 111,
        'collectionName': 'DRIVE',
        'artistName': 'Tiësto',
        'trackName': 'All Nighter',
      },
      {
        'collectionId': 333,
        'collectionName': 'Other Album',
        'artistName': 'Tiësto',
        'trackName': '10:35',
      },
      {
        'collectionId': 444,
        'collectionName': 'DRIVE',
        'artistName': 'Someone Else',
        'trackName': '10:35',
      },
    ];

    test('prefers the collection holding the representative song', () {
      final ids = MotionArtAlbumMatcher.rankCollectionIdsFromSongs(
        album: 'DRIVE',
        artist: 'Tiësto & Tate McRae',
        representativeSongTitle: '10:35',
        results: songs,
      );
      expect(ids, ['222', '111']);
    });

    test('keeps result order without a representative song', () {
      final ids = MotionArtAlbumMatcher.rankCollectionIdsFromSongs(
        album: 'DRIVE',
        artist: 'Tiësto',
        results: songs,
      );
      expect(ids, ['111', '222']);
    });
  });

  group('MotionArtAlbumMatcher.artistVariants', () {
    test('appends the primary artist for collab credits', () {
      expect(MotionArtAlbumMatcher.artistVariants('Tiësto & Tate McRae'), [
        'Tiësto & Tate McRae',
        'Tiësto',
      ]);
      expect(MotionArtAlbumMatcher.artistVariants('Tiësto feat. Ava Max'), [
        'Tiësto feat. Ava Max',
        'Tiësto',
      ]);
      expect(MotionArtAlbumMatcher.artistVariants('Ariana Grande, Doja Cat'), [
        'Ariana Grande, Doja Cat',
        'Ariana Grande',
      ]);
    });

    test('keeps single artists unchanged', () {
      expect(MotionArtAlbumMatcher.artistVariants('Tiësto'), ['Tiësto']);
      expect(MotionArtAlbumMatcher.artistVariants('X Ambassadors'), [
        'X Ambassadors',
      ]);
      expect(MotionArtAlbumMatcher.artistVariants('  '), isEmpty);
    });
  });

  group('MotionArtAlbumMatcher.artistMatches', () {
    test('matches identical and prefixed names', () {
      expect(
        MotionArtAlbumMatcher.artistMatches('Taylor Swift', 'Taylor Swift'),
        isTrue,
      );
      expect(
        MotionArtAlbumMatcher.artistMatches(
          'Taylor Swift',
          'Taylor Swift feat. Brendon Urie',
        ),
        isTrue,
      );
    });

    test('rejects unrelated artists', () {
      expect(
        MotionArtAlbumMatcher.artistMatches('Taylor Swift', 'Drake'),
        isFalse,
      );
    });
  });
}
