import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/utils/uri_display_utils.dart';
import 'package:flick/providers/songs_provider.dart';

void main() {
  group('URI display decoding', () {
    test('decodes encoded spaces for display labels', () {
      expect(decodeUriDisplayComponent('24K%20Magic'), '24K Magic');
    });

    test('decodes double-encoded SAF folder segments', () {
      expect(
        decodeUriDisplayComponent('primary%3AMusic%2F24K%2520Magic'),
        'primary:Music/24K Magic',
      );
    });

    test('keeps malformed percent text instead of throwing', () {
      expect(decodeUriDisplayComponent('100% Real'), '100% Real');
    });
  });

  group('SongsState folder names', () {
    test('folderDisplayName decodes encoded folder uri segment', () {
      expect(
        SongsState.folderDisplayName(
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2F24K%2520Magic',
          null,
        ),
        '24K Magic',
      );
    });

    test('extractRelativeSubfolder decodes nested folder names', () {
      expect(
        SongsState.extractRelativeSubfolder(
          'content://provider/tree/primary%3AMusic',
          'content://provider/tree/primary%3AMusic/document/primary%3AMusic%2F24K%2520Magic%2FTrack.flac',
        ),
        '24K Magic',
      );
    });

    test('extractRelativeSubfolder keeps deeper nested folder hierarchy', () {
      expect(
        SongsState.extractRelativeSubfolder(
          'content://provider/tree/primary%3AMusic',
          'content://provider/tree/primary%3AMusic/document/primary%3AMusic%2F24K%2520Magic%2FDisc%25201%2FTrack.flac',
        ),
        '24K Magic/Disc 1',
      );
    });
  });

  group('SongFileTypeFilter.ogg', () {
    test('matches ogg container formats and opus streams', () {
      expect(SongFileTypeFilter.ogg.matches('OGG'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('ogx'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('OpUs'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('vorbis'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('oga'), isTrue);
    });

    test('does not match unrelated formats', () {
      expect(SongFileTypeFilter.ogg.matches('FLAC'), isFalse);
      expect(SongFileTypeFilter.ogg.matches('M4A'), isFalse);
    });
  });
}
