import 'package:flick/core/constants/metadata_constants.dart';
import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flutter_test/flutter_test.dart';

AudioFileInfo _metadata({bool read = true, int? tracks, int? discs}) {
  return AudioFileInfo(
    uri: '/music/track.flac',
    name: 'track.flac',
    size: 1,
    lastModified: 0,
    extension: 'flac',
    metadataRead: read,
    trackTotal: tracks,
    discTotal: discs,
  );
}

void main() {
  test('existing unchanged rows are eligible for one totals backfill', () {
    final song = SongEntity()..metadataComplete = true;
    expect(LibraryScannerService.needsMetadataBackfill([song]), isTrue);
    LibraryScannerService.applyTrackTotals(
      song,
      _metadata(tracks: 12, discs: 2),
    );
    expect(song.trackTotal, 12);
    expect(song.discTotal, 2);
    expect(song.metadataVersion, kCurrentTrackMetadataVersion);
    expect(LibraryScannerService.needsMetadataBackfill([song]), isFalse);
  });

  test(
    'ignored rows are not mistaken for the retained backfill population',
    () {
      final retained = SongEntity();
      final ignored = SongEntity();
      expect(
        LibraryScannerService.needsMetadataBackfill(
          [retained, ignored],
          excludedSongs: [ignored],
        ),
        isTrue,
      );
      retained.metadataVersion = kCurrentTrackMetadataVersion;
      expect(
        LibraryScannerService.needsMetadataBackfill(
          [retained, ignored],
          excludedSongs: [ignored],
        ),
        isFalse,
      );
    },
  );

  test(
    'a successful no-total read clears stale totals and finishes backfill',
    () {
      final song = SongEntity()
        ..trackTotal = 12
        ..discTotal = 2;
      LibraryScannerService.applyTrackTotals(song, _metadata());
      expect(song.trackTotal, isNull);
      expect(song.discTotal, isNull);
      expect(LibraryScannerService.needsMetadataBackfill([song]), isFalse);
    },
  );

  test('failed reads remain retryable and do not overwrite cached values', () {
    final song = SongEntity()..trackTotal = 12;
    LibraryScannerService.applyTrackTotals(song, _metadata(read: false));
    expect(song.trackTotal, 12);
    expect(LibraryScannerService.needsMetadataBackfill([song]), isTrue);
  });

  test('backfill preserves local edits including track and disc numbering', () {
    final song = SongEntity()
      ..title = 'Edited title'
      ..artist = 'Edited artist'
      ..album = 'Edited album'
      ..hasLocalEdits = true
      ..trackNumber = 7
      ..discNumber = 2;
    LibraryScannerService.applyTrackTotals(
      song,
      _metadata(tracks: 12, discs: 3),
    );
    expect(song.title, 'Edited title');
    expect(song.artist, 'Edited artist');
    expect(song.album, 'Edited album');
    expect(song.hasLocalEdits, isTrue);
    expect(song.trackNumber, 7);
    expect(song.discNumber, 2);
  });

  test(
    'Android map distinguishes discovery, failed reads, and successful reads',
    () {
      final map = <String, dynamic>{'uri': '/music/track.flac'};
      expect(AudioFileInfo.fromMap(map).metadataRead, isFalse);
      expect(
        AudioFileInfo.fromMap({...map, 'metadataRead': false}).metadataRead,
        isFalse,
      );
      final result = AudioFileInfo.fromMap({
        ...map,
        'metadataRead': true,
        'trackTotal': 12,
        'discTotal': 2,
      });
      expect(result.metadataRead, isTrue);
      expect(result.trackTotal, 12);
      expect(result.discTotal, 2);
    },
  );
}
