import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/album_art_service.dart';

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
}
