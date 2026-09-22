import 'package:flutter_test/flutter_test.dart';
import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/services/album_art_service.dart';

SongEntity _song(String path) =>
    SongEntity()
      ..filePath = path
      ..title = 'Title'
      ..artist = 'Artist';

void main() {
  group('isFolderCoverImageName', () {
    test('accepts the classic cover/folder names', () {
      expect(isFolderCoverImageName('cover.jpg'), isTrue);
      expect(isFolderCoverImageName('folder.png'), isTrue);
      expect(isFolderCoverImageName('album.webp'), isTrue);
      expect(isFolderCoverImageName('albumart.jpeg'), isTrue);
      expect(isFolderCoverImageName('front.gif'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isFolderCoverImageName('Cover.JPG'), isTrue);
      expect(isFolderCoverImageName('FOLDER.Png'), isTrue);
    });

    test('accepts suffixed variants', () {
      expect(isFolderCoverImageName('cover.front.jpg'), isTrue);
      expect(isFolderCoverImageName('album.1.png'), isTrue);
    });

    test('rejects non-cover images', () {
      expect(isFolderCoverImageName('back.jpg'), isFalse);
      expect(isFolderCoverImageName('track.jpg'), isFalse);
      expect(isFolderCoverImageName('cover.jpg.bak'), isFalse);
    });

    test('rejects non-image extensions', () {
      expect(isFolderCoverImageName('cover.txt'), isFalse);
      expect(isFolderCoverImageName('cover'), isFalse);
    });
  });

  group('resolveMissingArtwork progress', () {
    test('reports every song, including skipped ones', () async {
      final reported = <(int, int)>[];
      await AlbumArtService.instance.resolveMissingArtwork(
        [
          _song(''),
          _song('https://example.com/stream.flac'),
          _song('http://example.com/stream.flac'),
        ],
        onProgress: (completed, total) => reported.add((completed, total)),
      );

      expect(reported, [(0, 3), (1, 3), (2, 3), (3, 3)]);
    });

    test('reports zero of zero for an empty list', () async {
      final reported = <(int, int)>[];
      await AlbumArtService.instance.resolveMissingArtwork(
        const [],
        onProgress: (completed, total) => reported.add((completed, total)),
      );

      expect(reported, [(0, 0)]);
    });
  });
}
