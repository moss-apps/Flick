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

  group('relativeFolderPathFor', () {
    test('records nested folders relative to the removable scan root', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/1A2B-3C4D/Music',
          '/storage/1A2B-3C4D/Music/Albums/Album/CD1/track.flac',
        ),
        'Albums/Album/CD1',
      );
    });

    test('records an empty path for files directly under the root', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/1A2B-3C4D/Music',
          '/storage/1A2B-3C4D/Music/track.flac',
        ),
        '',
      );
    });

    test('unwraps file URIs and percent-decodes them', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/emulated/0/Music',
          'file:///storage/emulated/0/Music/Deep%20House/track.dsf',
        ),
        'Deep House',
      );
    });

    test('tolerates a trailing slash on the scan root', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/emulated/0/Music/',
          '/storage/emulated/0/Music/Album/track.flac',
        ),
        'Album',
      );
    });

    test('normalizes backslash separators', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/Music',
          r'/storage/Music\Album\track.flac',
        ),
        'Album',
      );
    });

    test('returns null for a file on another volume', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/1A2B-3C4D/Music',
          '/storage/emulated/0/Music/Album/track.flac',
        ),
        isNull,
      );
    });

    test('does not match a sibling directory with a shared prefix', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/Music',
          '/storage/Music2/Album/track.flac',
        ),
        isNull,
      );
    });

    test('returns null for content URIs', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/emulated/0/Music',
          'content://provider/document/track-id',
        ),
        isNull,
      );
    });

    test('returns null when the file path is unknown', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/emulated/0/Music',
          null,
        ),
        isNull,
      );
    });

    test('records the whole-volume root correctly', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage/1A2B-3C4D',
          '/storage/1A2B-3C4D/Music/Album/track.flac',
        ),
        'Music/Album',
      );
    });

    test('uses the actual mount path instead of a volume convention', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/mnt/media_rw/1A2B-3C4D/Music',
          '/mnt/media_rw/1A2B-3C4D/Music/Album/track.flac',
        ),
        'Album',
      );
    });

    test('accepts a file URI scan root and preserves on-disk names', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          'file:///storage/1A2B-3C4D/My%20Music',
          '/storage/1A2B-3C4D/My Music/日本語/100% Hits/track.flac',
        ),
        '日本語/100% Hits',
      );
    });

    test('normalizes duplicate path separators', () {
      expect(
        LibraryScannerService.relativeFolderPathFor(
          '/storage//Music///',
          '/storage/Music//Album///Disc 1/track.flac',
        ),
        'Album/Disc 1',
      );
    });
  });
}
