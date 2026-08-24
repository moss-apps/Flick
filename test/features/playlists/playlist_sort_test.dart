import 'package:flick/features/playlists/widgets/playlist_sort_bottom_sheet.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(String id, String title, String artist) => Song(
  id: id,
  title: title,
  artist: artist,
  duration: const Duration(minutes: 3),
  fileType: 'FLAC',
);

Playlist _playlist({
  required List<String> songIds,
  Map<String, DateTime> songAddedAt = const {},
}) {
  return Playlist(
    id: 'p1',
    name: 'Test',
    songIds: songIds,
    createdAt: DateTime(2024),
    songAddedAt: songAddedAt,
  );
}

List<String> _sorted(Playlist playlist, PlaylistSortOption option) {
  final songs = [
    for (final id in playlist.songIds) _song(id, 'Title $id', 'Artist $id'),
  ];
  return sortPlaylistSongs(
    songs: songs,
    playlist: playlist,
    option: option,
  ).map((s) => s.id).toList();
}

void main() {
  final playlist = _playlist(
    songIds: ['a', 'b', 'c', 'd', 'e'],
    songAddedAt: {
      'a': DateTime(2024, 1, 1),
      'c': DateTime(2024, 3, 1),
      'e': DateTime(2024, 2, 1),
    },
  );

  group('sortPlaylistSongs', () {
    test('manual keeps playlist order', () {
      expect(_sorted(playlist, PlaylistSortOption.manual), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
    });

    test(
      'dateAddedNewest puts dated songs first, undated by index desc at the end',
      () {
        expect(_sorted(playlist, PlaylistSortOption.dateAddedNewest), [
          'c',
          'e',
          'a',
          'd',
          'b',
        ]);
      },
    );

    test(
      'dateAddedOldest puts undated (legacy) first, then dated ascending',
      () {
        expect(_sorted(playlist, PlaylistSortOption.dateAddedOldest), [
          'b',
          'd',
          'a',
          'e',
          'c',
        ]);
      },
    );

    test('dateAddedNewest ties break by descending add order', () {
      final tied = _playlist(
        songIds: ['a', 'b', 'c'],
        songAddedAt: {
          'a': DateTime(2024, 1, 1),
          'b': DateTime(2024, 1, 1),
          'c': DateTime(2024, 1, 1),
        },
      );
      expect(_sorted(tied, PlaylistSortOption.dateAddedNewest), [
        'c',
        'b',
        'a',
      ]);
    });

    test(
      'legacy playlist without timestamps reverses add order for newest-first',
      () {
        final legacy = _playlist(songIds: ['a', 'b', 'c']);
        expect(_sorted(legacy, PlaylistSortOption.dateAddedNewest), [
          'c',
          'b',
          'a',
        ]);
        expect(_sorted(legacy, PlaylistSortOption.dateAddedOldest), [
          'a',
          'b',
          'c',
        ]);
      },
    );

    test('title and artist sort alphabetically, case-insensitively', () {
      final songs = [
        _song('z', 'Zulu', 'Alpha'),
        _song('a', 'alpha', 'Omega'),
        _song('m', 'Mike', 'mike'),
      ];
      final p = Playlist(
        id: 'p1',
        name: 'Test',
        songIds: ['z', 'a', 'm'],
        createdAt: DateTime(2024),
      );
      expect(
        sortPlaylistSongs(
          songs: songs,
          playlist: p,
          option: PlaylistSortOption.title,
        ).map((s) => s.id).toList(),
        ['a', 'm', 'z'],
      );
      expect(
        sortPlaylistSongs(
          songs: songs,
          playlist: p,
          option: PlaylistSortOption.artist,
        ).map((s) => s.id).toList(),
        ['z', 'm', 'a'],
      );
    });

    test('title ties break by original playlist position', () {
      final songs = [
        _song('a', 'Same', 'X'),
        _song('b', 'Same', 'X'),
        _song('c', 'Same', 'X'),
      ];
      final p = Playlist(
        id: 'p1',
        name: 'Test',
        songIds: ['a', 'b', 'c'],
        createdAt: DateTime(2024),
      );
      expect(
        sortPlaylistSongs(
          songs: songs,
          playlist: p,
          option: PlaylistSortOption.title,
        ).map((s) => s.id).toList(),
        ['a', 'b', 'c'],
      );
    });
  });
}
