import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../data/repositories/song_repository.dart';

/// Provider for the SongRepository.
final songRepositoryProvider = Provider<SongRepository>((ref) {
  return SongRepository();
});

/// Sort options for the song list.
enum SongSortOption { albumArtist, title, artist, dateAdded, fileType, folder, year, genre }

/// A group of songs within the same folder.
class FolderGroup {
  final String name;
  final String key;
  final String? folderUri;
  final List<Song> songs;

  const FolderGroup({
    required this.name,
    required this.key,
    this.folderUri,
    required this.songs,
  });
}

/// Filter options for file types.
enum SongFileTypeFilter { all, flac, mp3, wav, aac, ogg, alac }

extension SongFileTypeFilterExtension on SongFileTypeFilter {
  String get displayName {
    switch (this) {
      case SongFileTypeFilter.all:
        return 'All Formats';
      case SongFileTypeFilter.flac:
        return 'FLAC';
      case SongFileTypeFilter.mp3:
        return 'MP3';
      case SongFileTypeFilter.wav:
        return 'WAV';
      case SongFileTypeFilter.aac:
        return 'AAC';
      case SongFileTypeFilter.ogg:
        return 'OGG';
      case SongFileTypeFilter.alac:
        return 'ALAC';
    }
  }

  bool matches(String fileType) {
    if (this == SongFileTypeFilter.all) return true;

    // Normalize file type for comparison (remove dots, convert to uppercase)
    final normalized = fileType.replaceAll('.', '').toUpperCase().trim();
    final filterName = displayName.toUpperCase();

    // Direct match
    if (normalized == filterName) return true;

    // Handle common variations
    switch (this) {
      case SongFileTypeFilter.mp3:
        return normalized == 'MP3' || normalized == 'MPEG';
      case SongFileTypeFilter.aac:
        return normalized == 'AAC' ||
            normalized == 'M4A' ||
            normalized == 'MP4';
      case SongFileTypeFilter.ogg:
        return normalized == 'OGG' ||
            normalized == 'OGX' ||
            normalized == 'OPUS' ||
            normalized == 'VORBIS' ||
            normalized == 'OGA';
      case SongFileTypeFilter.alac:
        return normalized == 'ALAC' || normalized == 'M4A';
      case SongFileTypeFilter.wav:
        return normalized == 'WAV' || normalized == 'WAVE';
      case SongFileTypeFilter.flac:
        return normalized == 'FLAC';
      case SongFileTypeFilter.all:
        return true;
    }
  }
}

/// State for the songs list with sorting.
class SongsState {
  final List<Song> songs;
  final SongSortOption sortOption;
  final SongFileTypeFilter fileTypeFilter;
  final List<Song> sortedSongs;
  final List<FolderGroup> folderGroups;

  const SongsState._({
    required this.songs,
    required this.sortOption,
    required this.fileTypeFilter,
    required this.sortedSongs,
    required this.folderGroups,
  });

  factory SongsState({
    List<Song> songs = const [],
    SongSortOption sortOption = SongSortOption.albumArtist,
    SongFileTypeFilter fileTypeFilter = SongFileTypeFilter.all,
  }) {
    return SongsState._(
      songs: songs,
      sortOption: sortOption,
      fileTypeFilter: fileTypeFilter,
      sortedSongs: _computeSortedSongs(songs, sortOption, fileTypeFilter),
      folderGroups: _computeFolderGroups(songs, sortOption, fileTypeFilter),
    );
  }

  SongsState copyWith({
    List<Song>? songs,
    SongSortOption? sortOption,
    SongFileTypeFilter? fileTypeFilter,
  }) {
    return SongsState(
      songs: songs ?? this.songs,
      sortOption: sortOption ?? this.sortOption,
      fileTypeFilter: fileTypeFilter ?? this.fileTypeFilter,
    );
  }

  static List<Song> _computeSortedSongs(
    List<Song> songs,
    SongSortOption sortOption,
    SongFileTypeFilter fileTypeFilter,
  ) {
    var result = List<Song>.from(songs);

    if (fileTypeFilter != SongFileTypeFilter.all) {
      result = result
          .where((song) => fileTypeFilter.matches(song.fileType))
          .toList();
    }

    switch (sortOption) {
      case SongSortOption.albumArtist:
        result.sort((a, b) {
          final artistA = a.albumArtist ?? a.artist;
          final artistB = b.albumArtist ?? b.artist;
          final artistCompare = artistA.compareTo(artistB);
          if (artistCompare != 0) return artistCompare;
          final albumCompare = (a.album ?? '').compareTo(b.album ?? '');
          if (albumCompare != 0) return albumCompare;

          final discA = (a.discNumber != null && a.discNumber! > 0)
              ? a.discNumber!
              : 1;
          final discB = (b.discNumber != null && b.discNumber! > 0)
              ? b.discNumber!
              : 1;
          final discCompare = discA.compareTo(discB);
          if (discCompare != 0) return discCompare;

          final trackA = (a.trackNumber != null && a.trackNumber! > 0)
              ? a.trackNumber
              : null;
          final trackB = (b.trackNumber != null && b.trackNumber! > 0)
              ? b.trackNumber
              : null;
          final hasTrackA = trackA != null;
          final hasTrackB = trackB != null;
          if (hasTrackA && hasTrackB) {
            final trackCompare = trackA.compareTo(trackB);
            if (trackCompare != 0) return trackCompare;
          } else if (hasTrackA != hasTrackB) {
            return hasTrackA ? -1 : 1;
          }

          return a.title.compareTo(b.title);
        });
      case SongSortOption.title:
        result.sort((a, b) => a.title.compareTo(b.title));
      case SongSortOption.artist:
        result.sort((a, b) => a.artist.compareTo(b.artist));
      case SongSortOption.dateAdded:
        result.sort((a, b) {
          final dateA = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
      case SongSortOption.fileType:
        result.sort((a, b) => a.fileType.compareTo(b.fileType));
      case SongSortOption.folder:
        result.sort((a, b) {
          final folderA = extractRelativeSubfolder(a.folderUri, a.filePath);
          final folderB = extractRelativeSubfolder(b.folderUri, b.filePath);
          final folderCompare = folderA.compareTo(folderB);
          if (folderCompare != 0) return folderCompare;
          return a.title.compareTo(b.title);
        });
      case SongSortOption.year:
        result.sort((a, b) {
          final yearA = a.year ?? 0;
          final yearB = b.year ?? 0;
          final yearCompare = yearB.compareTo(yearA);
          if (yearCompare != 0) return yearCompare;
          return a.title.compareTo(b.title);
        });
      case SongSortOption.genre:
        result.sort((a, b) {
          final genreA = a.genre?.trim().isNotEmpty == true ? a.genre!.trim() : '\u{10FFFF}';
          final genreB = b.genre?.trim().isNotEmpty == true ? b.genre!.trim() : '\u{10FFFF}';
          final genreCompare = genreA.compareTo(genreB);
          if (genreCompare != 0) return genreCompare;
          return a.title.compareTo(b.title);
        });
    }
    return result;
  }

  static List<FolderGroup> _computeFolderGroups(
    List<Song> songs,
    SongSortOption sortOption,
    SongFileTypeFilter fileTypeFilter,
  ) {
    if (sortOption != SongSortOption.folder) return [];

    var result = List<Song>.from(songs);

    if (fileTypeFilter != SongFileTypeFilter.all) {
      result = result
          .where((song) => fileTypeFilter.matches(song.fileType))
          .toList();
    }

    final groups = <String, FolderGroup>{};
    for (final song in result) {
      final subfolder = extractRelativeSubfolder(song.folderUri, song.filePath);
      final key = subfolder.isEmpty ? (song.folderUri ?? '__root__') : subfolder;
      final displayName = subfolder.isEmpty
          ? folderDisplayName(song.folderUri, song.filePath)
          : subfolder.split('/').where((p) => p.isNotEmpty).last;
      groups.putIfAbsent(
        key,
        () => FolderGroup(
          name: displayName,
          key: key,
          folderUri: song.folderUri,
          songs: [],
        ),
      );
      groups[key]!.songs.add(song);
    }

    final sorted = groups.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  static String extractRelativeSubfolder(
    String? folderUri,
    String? filePath,
  ) {
    if (folderUri == null || folderUri.isEmpty) return '';
    if (filePath == null || filePath.isEmpty) return '';
    final base = folderUri.endsWith('/')
        ? folderUri.substring(0, folderUri.length - 1)
        : folderUri;
    final uriBase = Uri.tryParse('$base/');
    if (uriBase == null) return '';
    final fileUri = Uri.tryParse(filePath);
    if (fileUri == null) return '';
    final relative = uriBase.path.isNotEmpty
        ? fileUri.path.replaceFirst(uriBase.path, '')
        : fileUri.path;
    final withoutRoot = relative.startsWith('/') ? relative.substring(1) : relative;
    final parts = withoutRoot.split('/');
    if (parts.length >= 2) return parts.sublist(0, parts.length - 1).join('/');
    return '';
  }

  static String folderDisplayName(
    String? folderUri,
    String? filePath,
  ) {
    if (folderUri == null || folderUri.isEmpty) {
      if (filePath == null) return '';
      final uri = Uri.tryParse(filePath);
      if (uri == null) return filePath;
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        return segments[segments.length - 2];
      }
      return filePath;
    }
    final uri = Uri.tryParse(folderUri);
    if (uri == null) return folderUri;
    final segments =
        uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : folderUri;
  }
}

/// AsyncNotifier for managing the songs list.
/// Uses autoDispose to clean up when not being watched.
class SongsNotifier extends AsyncNotifier<SongsState> {
  static const _sortOptionKey = 'songs_sort_option';
  static const _fileTypeFilterKey = 'songs_file_type_filter';
  StreamSubscription<void>? _watchSubscription;
  SongSortOption _sortOption = SongSortOption.albumArtist;
  SongFileTypeFilter _fileTypeFilter = SongFileTypeFilter.all;

  @override
  Future<SongsState> build() async {
    final repository = ref.watch(songRepositoryProvider);

    _sortOption = await _loadSortOption();
    _fileTypeFilter = await _loadFileTypeFilter();

    _watchSubscription?.cancel();
    _watchSubscription = repository.watchSongs().listen((_) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _watchSubscription?.cancel();
    });

    final songs = await repository.getAllSongs();
    return SongsState(
      songs: songs,
      sortOption: _sortOption,
      fileTypeFilter: _fileTypeFilter,
    );
  }

  void setSortOption(SongSortOption option) {
    _sortOption = option;
    _saveSortOption(option);
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(sortOption: option));
    }
  }

  void setFileTypeFilter(SongFileTypeFilter filter) {
    _fileTypeFilter = filter;
    _saveFileTypeFilter(filter);
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(fileTypeFilter: filter));
    }
  }

  Future<SongSortOption> _loadSortOption() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_sortOptionKey);
    if (value == null) return SongSortOption.albumArtist;
    return SongSortOption.values.firstWhere(
      (opt) => opt.name == value,
      orElse: () => SongSortOption.albumArtist,
    );
  }

  Future<SongFileTypeFilter> _loadFileTypeFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_fileTypeFilterKey);
    if (value == null) return SongFileTypeFilter.all;
    return SongFileTypeFilter.values.firstWhere(
      (f) => f.name == value,
      orElse: () => SongFileTypeFilter.all,
    );
  }

  Future<void> _saveSortOption(SongSortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOptionKey, option.name);
  }

  Future<void> _saveFileTypeFilter(SongFileTypeFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fileTypeFilterKey, filter.name);
  }

  /// Force refresh the songs list.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Main songs provider with async data loading.
final songsProvider =
    AsyncNotifierProvider.autoDispose<SongsNotifier, SongsState>(
      SongsNotifier.new,
    );

/// Convenience provider for just the sorted song list.
final sortedSongsProvider = Provider.autoDispose<AsyncValue<List<Song>>>((ref) {
  return ref.watch(songsProvider).whenData((state) => state.sortedSongs);
});

/// Song count provider.
final songCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(songsProvider).value?.songs.length ?? 0;
});

// ============================================================================
// Album and Artist grouping providers
// ============================================================================

/// Songs grouped by album.
final songsByAlbumProvider = FutureProvider.autoDispose<List<AlbumGroup>>((
  ref,
) async {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getAlbumGroups();
});

/// Songs grouped by artist.
final songsByArtistProvider =
    FutureProvider.autoDispose<Map<String, List<Song>>>((ref) async {
      final repository = ref.watch(songRepositoryProvider);
      return repository.getSongsByArtist();
    });

// ============================================================================
// Search provider
// ============================================================================

/// Notifier for search query state.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Search query state provider.
final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

/// Filtered songs based on search query.
final searchResultsProvider = FutureProvider.autoDispose<List<Song>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final repository = ref.watch(songRepositoryProvider);
  return repository.searchSongs(query);
});
