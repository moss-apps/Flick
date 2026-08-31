import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/songs_provider.dart';
import 'search_category.dart';

class GlobalSearchResults {
  final String query;
  final List<Song> songs;
  final List<MapEntry<String, List<Song>>> artists;
  final List<AlbumGroup> albums;
  final List<MapEntry<String, List<Song>>> albumArtists;
  final List<FolderGroup> folders;
  final List<Song> yearMatches;
  final List<Playlist> playlists;

  const GlobalSearchResults({
    required this.query,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.albumArtists = const [],
    this.folders = const [],
    this.yearMatches = const [],
    this.playlists = const [],
  });

  static const empty = GlobalSearchResults(query: '');

  bool get isEmpty =>
      songs.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      albumArtists.isEmpty &&
      folders.isEmpty &&
      yearMatches.isEmpty &&
      playlists.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int countFor(SearchCategory category) {
    switch (category) {
      case SearchCategory.songs:
        return songs.length;
      case SearchCategory.artists:
        return artists.length;
      case SearchCategory.albums:
        return albums.length;
      case SearchCategory.albumArtists:
        return albumArtists.length;
      case SearchCategory.folders:
        return folders.length;
      case SearchCategory.year:
        return yearMatches.length;
      case SearchCategory.playlists:
        return playlists.length;
    }
  }

  int get totalCount =>
      songs.length +
      artists.length +
      albums.length +
      albumArtists.length +
      folders.length +
      yearMatches.length +
      playlists.length;

  Map<SearchCategory, int> get counts => {
        for (final c in SearchCategory.values) c: countFor(c),
      };

  bool hasResultsFor(SearchCategory category) => countFor(category) > 0;
}
