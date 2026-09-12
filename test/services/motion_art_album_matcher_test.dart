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
