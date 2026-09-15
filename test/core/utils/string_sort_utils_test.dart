import 'package:flick/core/utils/string_sort_utils.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(
  String id,
  String title,
  String artist, {
  String? album,
  String? albumArtist,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    duration: const Duration(minutes: 3),
    fileType: 'FLAC',
  );
}

void main() {
  group('compareCaseInsensitive', () {
    test('lowercase names interleave with uppercase', () {
      final names = ['Webinar', "death's dynamic shroud", 'Zebra', 'aphex twin'];
      final sorted = names..sort(compareCaseInsensitive);
      expect(sorted, [
        'aphex twin',
        "death's dynamic shroud",
        'Webinar',
        'Zebra',
      ]);
    });

    test('case-insensitive ties break deterministically', () {
      expect(compareCaseInsensitive('Alpha', 'alpha') < 0, isTrue);
      expect(compareCaseInsensitive('alpha', 'Alpha') > 0, isTrue);
      expect(compareCaseInsensitive('same', 'same'), 0);
    });
  });

  group('SongsState.computeSortedSongs', () {
    test('artist sort is case-insensitive', () {
      final songs = [
        _song('w', 'Track W', 'Webinar'),
        _song('d', 'Track D', "death's dynamic shroud"),
        _song('z', 'Track Z', 'Zebra'),
      ];
      final sorted = SongsState.computeSortedSongs(
        songs,
        SongSortOption.artist,
        SongFileTypeFilter.all,
      );
      expect(sorted.map((s) => s.id).toList(), ['d', 'w', 'z']);
    });

    test('title sort is case-insensitive', () {
      final songs = [
        _song('1', 'zulu', 'A'),
        _song('2', 'Alpha', 'A'),
        _song('3', 'mike', 'A'),
      ];
      final sorted = SongsState.computeSortedSongs(
        songs,
        SongSortOption.title,
        SongFileTypeFilter.all,
      );
      expect(sorted.map((s) => s.id).toList(), ['2', '3', '1']);
    });

    test('albumArtist sort is case-insensitive with album tiebreak', () {
      final songs = [
        _song('1', 't1', 'X', album: 'Gamma', albumArtist: 'webinar'),
        _song('2', 't2', 'X', album: 'beta', albumArtist: 'Aphex Twin'),
        _song('3', 't3', 'X', album: 'Delta', albumArtist: 'Webinar'),
      ];
      final sorted = SongsState.computeSortedSongs(
        songs,
        SongSortOption.albumArtist,
        SongFileTypeFilter.all,
      );
      expect(sorted.map((s) => s.id).toList(), ['2', '3', '1']);
    });

    test('album sort is case-insensitive', () {
      final songs = [
        _song('1', 't1', 'X', album: 'omega'),
        _song('2', 't2', 'X', album: 'Alpha'),
        _song('3', 't3', 'X', album: 'Beta'),
      ];
      final sorted = SongsState.computeSortedSongs(
        songs,
        SongSortOption.album,
        SongFileTypeFilter.all,
      );
      expect(sorted.map((s) => s.id).toList(), ['2', '3', '1']);
    });
  });

  group('SongRepository.sortSongsByAlbum', () {
    test('album groups sort case-insensitively', () {
      final songs = [
        _song('1', 't1', 'X', album: 'zebra'),
        _song('2', 't2', 'X', album: 'alpha'),
        _song('3', 't3', 'X', album: 'Beta'),
      ];
      final sorted = SongRepository.sortSongsByAlbum(songs);
      expect(sorted.map((s) => s.id).toList(), ['2', '3', '1']);
    });
  });
}
