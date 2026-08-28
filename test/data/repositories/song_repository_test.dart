import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song({required String artist, String? albumArtist}) => Song(
  id: artist,
  title: 'T',
  artist: artist,
  albumArtist: albumArtist,
  duration: Duration(seconds: 1),
  fileType: 'FLAC',
);

void main() {
  group('SongRepository.albumArtistForSong', () {
    test('literal Various Artists tag falls back to per-track artist', () {
      expect(
        SongRepository.albumArtistForSong(
          _song(artist: 'Kendrick Lamar', albumArtist: 'Various Artists'),
        ),
        'Kendrick Lamar',
      );
    });

    test('Various Artists track artist keeps the tag', () {
      expect(
        SongRepository.albumArtistForSong(
          _song(artist: 'Various Artists', albumArtist: 'various artists'),
        ),
        'various artists',
      );
    });

    test('real albumArtist tag is untouched', () {
      expect(
        SongRepository.albumArtistForSong(
          _song(artist: 'Kendrick Lamar', albumArtist: 'ScHoolboy Q'),
        ),
        'ScHoolboy Q',
      );
    });
  });

  group('SongRepository.resolveGroupArtist', () {
    test('single artist stays as-is', () {
      expect(SongRepository.resolveGroupArtist({'Pink Floyd'}), 'Pink Floyd');
    });

    test('distinct albumArtists resolve to comma-joined names (untagged comp)',
        () {
      expect(
        SongRepository.resolveGroupArtist({'A Tribe Called Quest', 'De La Soul'}),
        'A Tribe Called Quest, De La Soul',
      );
    });

    test('Various Artists tag stays stable when mixed with poisoned values',
        () {
      expect(
        SongRepository.resolveGroupArtist(
          {'Various Artists', 'Kanye West', 'Jay‑Z'},
        ),
        'Various Artists',
      );
    });

    test('empty/blank values fall back to Unknown Artist', () {
      expect(SongRepository.resolveGroupArtist({''}), 'Unknown Artist');
      expect(SongRepository.resolveGroupArtist(<String>{}), 'Unknown Artist');
    });
  });
}
