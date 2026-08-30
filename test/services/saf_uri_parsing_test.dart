import 'package:flick/services/library_scanner_service.dart';
import 'package:test/test.dart';

void main() {
  group('rawPathFromSafUri', () {
    test('maps primary volume document URIs', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://com.android.externalstorage.documents/tree/'
          'primary%3AMusic/document/primary%3AMusic%2Ftrack.dsf',
        ),
        '/storage/emulated/0/Music/track.dsf',
      );
    });

    test('maps removable volume document URIs', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://com.android.externalstorage.documents/tree/'
          '1A2B-3C4D%3AMusic/document/1A2B-3C4D%3AMusic%2FDSD%2Falbum.dff',
        ),
        '/storage/1A2B-3C4D/Music/DSD/album.dff',
      );
    });

    test('decodes nested subdirectories', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://com.android.externalstorage.documents/tree/'
          'primary%3AMusic/document/primary%3AMusic%2FLossless%2Fa.wv',
        ),
        '/storage/emulated/0/Music/Lossless/a.wv',
      );
    });

    test('returns null for non-SAF content URIs', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://media/external/audio/media/42',
        ),
        isNull,
      );
    });

    test('returns null for plain file paths', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          '/storage/emulated/0/Music/track.dsf',
        ),
        isNull,
      );
    });

    test('returns null when document segment is missing', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://com.android.externalstorage.documents/tree/primary%3AMusic',
        ),
        isNull,
      );
    });

    test('returns null when docId has no volume colon', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://com.android.externalstorage.documents/tree/'
          'primary%3AMusic/document/track.dsf',
        ),
        isNull,
      );
    });

    test('returns null when docId colon is at the end', () {
      expect(
        LibraryScannerService.rawPathFromSafUri(
          'content://com.android.externalstorage.documents/tree/'
          'primary%3AMusic/document/primary%3A',
        ),
        isNull,
      );
    });
  });

  group('rawPathFromFileUri', () {
    test('maps file URIs to plain paths', () {
      expect(
        LibraryScannerService.rawPathFromFileUri(
          'file:///storage/emulated/0/Music/track.wv',
        ),
        '/storage/emulated/0/Music/track.wv',
      );
    });

    test('decodes percent-encoded characters', () {
      expect(
        LibraryScannerService.rawPathFromFileUri(
          'file:///storage/emulated/0/Music/Deep%20House/a%20track.dsf',
        ),
        '/storage/emulated/0/Music/Deep House/a track.dsf',
      );
    });

    test('passes plain absolute paths through', () {
      expect(
        LibraryScannerService.rawPathFromFileUri(
          '/storage/1A2B-3C4D/Music/album.dff',
        ),
        '/storage/1A2B-3C4D/Music/album.dff',
      );
    });

    test('returns null for content URIs', () {
      expect(
        LibraryScannerService.rawPathFromFileUri(
          'content://media/external/audio/media/42',
        ),
        isNull,
      );
    });

    test('returns null for relative paths', () {
      expect(
        LibraryScannerService.rawPathFromFileUri('Music/track.wv'),
        isNull,
      );
    });
  });
}
