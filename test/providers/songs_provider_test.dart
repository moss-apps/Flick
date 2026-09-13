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
    test('matches ogg container formats', () {
      expect(SongFileTypeFilter.ogg.matches('OGG'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('ogx'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('vorbis'), isTrue);
      expect(SongFileTypeFilter.ogg.matches('oga'), isTrue);
    });

    test('does not match unrelated formats', () {
      expect(SongFileTypeFilter.ogg.matches('FLAC'), isFalse);
      expect(SongFileTypeFilter.ogg.matches('M4A'), isFalse);
      expect(SongFileTypeFilter.ogg.matches('OpUs'), isFalse);
    });
  });

  group('SongFileTypeFilter extension coverage', () {
    const supportedExtensions = {
      'mp3',
      'flac',
      'ogg',
      'oga',
      'ogx',
      'opus',
      'm4a',
      'wav',
      'aif',
      'aiff',
      'alac',
      'aac',
      'dsf',
      'dff',
      'wv',
    };

    test('every supported extension is matched by a filter', () {
      for (final extension in supportedExtensions) {
        final matched = SongFileTypeFilter.values.any(
          (filter) => filter.matches(extension),
        );
        expect(matched, isTrue, reason: 'no filter matches .$extension');
      }
    });

    test('opus filter matches opus streams only', () {
      expect(SongFileTypeFilter.opus.matches('opus'), isTrue);
      expect(SongFileTypeFilter.opus.matches('OPUS'), isTrue);
      expect(SongFileTypeFilter.opus.matches('spx'), isTrue);
      expect(SongFileTypeFilter.opus.matches('ogg'), isFalse);
    });

    test('aiff filter matches aiff and aif', () {
      expect(SongFileTypeFilter.aiff.matches('aiff'), isTrue);
      expect(SongFileTypeFilter.aiff.matches('AIF'), isTrue);
      expect(SongFileTypeFilter.aiff.matches('wav'), isFalse);
    });

    test('wavpack filter matches wv but not wv-dsd', () {
      expect(SongFileTypeFilter.wavpack.matches('wv'), isTrue);
      expect(SongFileTypeFilter.wavpack.matches('wavpack'), isTrue);
      expect(SongFileTypeFilter.wavpack.matches('wv-dsd'), isFalse);
      expect(SongFileTypeFilter.dsd.matches('wv-dsd'), isTrue);
      expect(SongFileTypeFilter.dsd.matches('dsf'), isTrue);
      expect(SongFileTypeFilter.dsd.matches('dff'), isTrue);
    });

    test('all filter matches any extension', () {
      expect(SongFileTypeFilter.all.matches('anything'), isTrue);
    });
  });
}
