import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum SearchCategory {
  songs,
  artists,
  albums,
  albumArtists,
  folders,
  year,
  playlists,
}

extension SearchCategoryX on SearchCategory {
  String get label {
    switch (this) {
      case SearchCategory.songs:
        return 'Songs';
      case SearchCategory.artists:
        return 'Artists';
      case SearchCategory.albums:
        return 'Albums';
      case SearchCategory.albumArtists:
        return 'Album Artists';
      case SearchCategory.folders:
        return 'Folders';
      case SearchCategory.year:
        return 'Year';
      case SearchCategory.playlists:
        return 'Playlists';
    }
  }

  String get storageKey => name;

  IconData get icon {
    switch (this) {
      case SearchCategory.songs:
        return LucideIcons.music;
      case SearchCategory.artists:
        return LucideIcons.mic;
      case SearchCategory.albums:
        return LucideIcons.disc3;
      case SearchCategory.albumArtists:
        return LucideIcons.users;
      case SearchCategory.folders:
        return LucideIcons.folder;
      case SearchCategory.year:
        return LucideIcons.calendar;
      case SearchCategory.playlists:
        return LucideIcons.listMusic;
    }
  }

  static SearchCategory? fromStorageKey(String key) {
    for (final v in SearchCategory.values) {
      if (v.name == key) return v;
    }
    return null;
  }
}
