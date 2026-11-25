import 'dart:async';

import 'package:flick/core/utils/string_sort_utils.dart';
import 'package:flick/data/repositories/artist_repository.dart';
import 'package:flick/data/repositories/folder_repository.dart';
import 'package:flick/data/repositories/recently_played_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/album_color_mode_preference_service.dart';
import 'package:flick/services/car/car_models.dart';
import 'package:flick/services/color_extraction_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/services/playlist_service.dart';

/// Plays the "most played" and "recently played" lists look back over.
const int kCarHistoryWindow = 2000;

/// Longest list built from history or recency. The car cannot browse more,
/// and `play` of such a list plays exactly this many songs.
const int kCarDerivedListCap = 200;

const int kCarHomeJumpBackIn = 8;
const int kCarHomeRecentlyAdded = 12;
const int kCarHomeMostPlayed = 5;
const int kCarHomePlaylists = 12;

/// Per type, when a search does not say.
const int kCarSearchLimit = 30;

/// A request the library cannot serve. [code] is `bad_args` or `not_found`.
class CarException implements Exception {
  const CarException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CarException($code): $message';
}

/// A watched music folder as the car lists it.
class CarFolder {
  const CarFolder({required this.uri, required this.name});

  final String uri;
  final String name;
}

/// One entry of the play history.
class CarPlayEvent {
  const CarPlayEvent(this.songId, this.playedAt);

  final String songId;
  final DateTime playedAt;
}

/// The complete song list of a collection and the context it plays in.
class CarPlayable {
  const CarPlayable(this.songs, this.context);

  final List<Song> songs;
  final PlaybackContext context;
}

/// The library grouped once: album groups, artists, folders and search text.
///
/// Immutable. [CarLibrary] drops it when the song table changes, so a browse
/// request never rescans the database per tile.
class CarSnapshot {
  CarSnapshot(List<AlbumGroup> groups) : albums = List.unmodifiable(groups);

  /// Album groups in the order the phone lists them (artist, then album).
  final List<AlbumGroup> albums;

  /// Every song, by title like `SongRepository.getAllSongs`.
  late final List<Song> songs = () {
    final all = [for (final group in albums) ...group.songs];
    all.sort((a, b) {
      final byTitle = compareCaseInsensitive(a.title, b.title);
      return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
    });
    return List<Song>.unmodifiable(all);
  }();

  late final Map<String, Song> songsById = {
    for (final song in songs) song.id: song,
  };

  late final Map<String, AlbumGroup> albumsByKey = {
    for (final group in albums) group.key: group,
  };

  late final Map<String, String> albumKeyBySongId = {
    for (final group in albums)
      for (final song in group.songs) song.id: group.key,
  };

  /// Songs by `Song.artist`, each list by album then disc and track.
  late final Map<String, List<Song>> artists = () {
    final grouped = <String, List<Song>>{};
    for (final song in songs) {
      grouped.putIfAbsent(song.artist, () => []).add(song);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: List<Song>.unmodifiable(
          SongRepository.sortSongsByAlbum(entry.value),
        ),
    };
  }();

  late final List<String> artistNames = artists.keys.toList()
    ..sort(compareCaseInsensitive);

  late final Map<String, List<Song>> songsByFolder = () {
    final grouped = <String, List<Song>>{};
    for (final song in songs) {
      final uri = song.folderUri;
      if (uri != null) grouped.putIfAbsent(uri, () => []).add(song);
    }
    return grouped;
  }();

  /// Albums whose newest song was added most recently first. Albums with no
  /// add date are left out.
  late final List<AlbumGroup> recentlyAddedAlbums = () {
    final dated = <(AlbumGroup, DateTime)>[];
    for (final group in albums) {
      DateTime? newest;
      for (final song in group.songs) {
        final added = song.dateAdded;
        if (added != null && (newest == null || added.isAfter(newest))) {
          newest = added;
        }
      }
      if (newest != null) dated.add((group, newest));
    }
    dated.sort((a, b) => b.$2.compareTo(a.$2));
    return List<AlbumGroup>.unmodifiable([for (final e in dated) e.$1]);
  }();

  /// The [kCarDerivedListCap] most recently added songs, newest first.
  late final List<Song> recentlyAddedSongs = () {
    final dated = songs.where((song) => song.dateAdded != null).toList()
      ..sort((a, b) => b.dateAdded!.compareTo(a.dateAdded!));
    return List<Song>.unmodifiable(dated.take(kCarDerivedListCap));
  }();

  late final List<String> _titles = [
    for (final song in songs) song.title.toLowerCase(),
  ];

  late final List<String> _otherFields = [
    for (final song in songs)
      [
        song.artist,
        song.album ?? '',
        song.albumArtist ?? '',
        song.genre ?? '',
        song.year?.toString() ?? '',
      ].join('\n').toLowerCase(),
  ];

  /// Songs matching [query] in title, artist, album, album artist, genre or
  /// year. Title prefix matches come first, then other title matches, then
  /// the rest; each group keeps title order.
  List<Song> searchTracks(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    final prefix = <Song>[];
    final inTitle = <Song>[];
    final elsewhere = <Song>[];
    for (var i = 0; i < songs.length; i++) {
      final title = _titles[i];
      if (title.startsWith(q)) {
        prefix.add(songs[i]);
      } else if (title.contains(q)) {
        inTitle.add(songs[i]);
      } else if (_otherFields[i].contains(q)) {
        elsewhere.add(songs[i]);
      }
    }
    return [...prefix, ...inTitle, ...elsewhere];
  }

  /// Albums whose name or album artist contains [query], name matches first.
  List<AlbumGroup> searchAlbums(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    return _ranked(
      albums,
      q,
      (group) => group.albumName.toLowerCase(),
      (group) => group.albumArtist.toLowerCase(),
    );
  }

  /// Artist names containing [query], prefix matches first.
  List<String> searchArtists(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    return _ranked(artistNames, q, (name) => name.toLowerCase());
  }
}

String _normalize(String query) =>
    query.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

List<T> _ranked<T>(
  Iterable<T> items,
  String q,
  String Function(T) primary, [
  String Function(T)? secondary,
]) {
  final prefix = <T>[];
  final contains = <T>[];
  final other = <T>[];
  for (final item in items) {
    final name = primary(item);
    if (name.startsWith(q)) {
      prefix.add(item);
    } else if (name.contains(q)) {
      contains.add(item);
    } else if (secondary != null && secondary(item).contains(q)) {
      other.add(item);
    }
  }
  return [...prefix, ...contains, ...other];
}

/// Distinct songs from [history], most recent play first.
List<Song> carRecentSongs(CarSnapshot snapshot, List<CarPlayEvent> history) {
  final byRecency = [...history]
    ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  final seen = <String>{};
  final songs = <Song>[];
  for (final event in byRecency) {
    final song = snapshot.songsById[event.songId];
    if (song != null && seen.add(song.id)) songs.add(song);
  }
  return songs;
}

/// Songs ranked by plays in [history]; equal counts keep the more recently
/// played first.
List<Song> carMostPlayedSongs(
  CarSnapshot snapshot,
  List<CarPlayEvent> history,
) {
  final plays = <String, int>{};
  final lastPlayed = <String, DateTime>{};
  for (final event in history) {
    if (!snapshot.songsById.containsKey(event.songId)) continue;
    plays.update(event.songId, (count) => count + 1, ifAbsent: () => 1);
    final last = lastPlayed[event.songId];
    if (last == null || event.playedAt.isAfter(last)) {
      lastPlayed[event.songId] = event.playedAt;
    }
  }
  final ids = plays.keys.toList()
    ..sort((a, b) {
      final byPlays = plays[b]!.compareTo(plays[a]!);
      if (byPlays != 0) return byPlays;
      final byRecency = lastPlayed[b]!.compareTo(lastPlayed[a]!);
      return byRecency != 0 ? byRecency : a.compareTo(b);
    });
  return [for (final id in ids) snapshot.songsById[id]!];
}

/// Distinct albums of [history], most recent play first, at most [max].
///
/// The history records songs, not where they were played from, so playlists
/// cannot appear here.
List<AlbumGroup> carRecentAlbums(
  CarSnapshot snapshot,
  List<CarPlayEvent> history,
  int max,
) {
  final byRecency = [...history]
    ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  final seen = <String>{};
  final albums = <AlbumGroup>[];
  for (final event in byRecency) {
    final key = snapshot.albumKeyBySongId[event.songId];
    final group = key == null ? null : snapshot.albumsByKey[key];
    if (group != null && seen.add(group.key)) {
      albums.add(group);
      if (albums.length >= max) break;
    }
  }
  return albums;
}

/// Songs of [playlist] in its own order. Ids no longer in the library and
/// repeated ids are skipped, as on the phone.
List<Song> carPlaylistSongs(CarSnapshot snapshot, Playlist playlist) {
  final seen = <String>{};
  final songs = <Song>[];
  for (final id in playlist.songIds) {
    final song = snapshot.songsById[id];
    if (song != null && seen.add(id)) songs.add(song);
  }
  return songs;
}

class _Resolved {
  const _Resolved({
    required this.title,
    required this.songs,
    required this.context,
    this.subtitle,
    this.art,
    this.albums = const [],
  });

  final String title;
  final String? subtitle;
  final String? art;
  final List<Song> songs;
  final List<Map<String, Object?>> albums;
  final PlaybackContext context;
}

/// Answers the car's library questions (`home`, `list`, `collection`,
/// `search`) and resolves a (kind, id) to its complete song list.
///
/// The album and artist grouping is cached and dropped through [invalidate].
/// Playlists, favorites, folders and play history are read on every request:
/// none of them signals a change, and each is cheap.
class CarLibrary {
  CarLibrary({
    Future<List<AlbumGroup>> Function()? loadAlbums,
    Future<List<Playlist>> Function()? loadPlaylists,
    Future<List<CarFolder>> Function()? loadFolders,
    Future<Set<String>> Function()? loadFavoriteIds,
    Future<List<CarPlayEvent>> Function()? loadHistory,
    Future<String?> Function(String artist)? loadArtistArt,
    Future<int?> Function(String? artPath)? loadColor,
  }) : _loadAlbums = loadAlbums ?? _defaultAlbums,
       _loadPlaylists = loadPlaylists ?? _defaultPlaylists,
       _loadFolders = loadFolders ?? _defaultFolders,
       _loadFavoriteIds = loadFavoriteIds ?? _defaultFavoriteIds,
       _loadHistory = loadHistory ?? _defaultHistory,
       _loadArtistArt = loadArtistArt ?? _defaultArtistArt,
       _loadColor = loadColor ?? _defaultColor;

  final Future<List<AlbumGroup>> Function() _loadAlbums;
  final Future<List<Playlist>> Function() _loadPlaylists;
  final Future<List<CarFolder>> Function() _loadFolders;
  final Future<Set<String>> Function() _loadFavoriteIds;
  final Future<List<CarPlayEvent>> Function() _loadHistory;
  final Future<String?> Function(String artist) _loadArtistArt;
  final Future<int?> Function(String? artPath) _loadColor;

  Future<CarSnapshot>? _snapshot;
  final Map<String, Future<String?>> _artistArt = {};

  /// Drops the cached grouping; the next request rebuilds it.
  void invalidate() {
    _snapshot = null;
    _artistArt.clear();
  }

  Future<CarSnapshot> snapshot() {
    final existing = _snapshot;
    if (existing != null) return existing;
    final future = _loadAlbums().then(CarSnapshot.new);
    _snapshot = future;
    // A failed load must not be cached; callers still see the error.
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_snapshot, future)) _snapshot = null;
      },
    );
    return future;
  }

  // ---------------------------------------------------------------- queries

  Future<Map<String, Object?>> home({Song? resume, int queueCount = 0}) async {
    final snap = await snapshot();
    final (playlists, favoriteIds, history, folders) = await (
      _loadPlaylists(),
      _loadFavoriteIds(),
      _loadHistory(),
      _loadFolders(),
    ).wait;

    final favorites = _favoriteSongs(snap, favoriteIds);
    final listedFolders = _listedFolders(snap, folders);
    return {
      'resume': resume == null ? null : carTrackMap(resume),
      'jumpBackIn': [
        for (final group in carRecentAlbums(snap, history, kCarHomeJumpBackIn))
          _albumCollection(group),
      ],
      'recentlyAdded': [
        for (final group in snap.recentlyAddedAlbums.take(
          kCarHomeRecentlyAdded,
        ))
          _albumCollection(group),
      ],
      'mostPlayed': [
        for (final song in carMostPlayedSongs(
          snap,
          history,
        ).take(kCarHomeMostPlayed))
          carTrackMap(song),
      ],
      'playlists': [
        for (final playlist in playlists.take(kCarHomePlaylists))
          _playlistCollection(snap, playlist),
      ],
      'counts': {
        'songs': snap.songs.length,
        'albums': snap.albums.length,
        'artists': snap.artistNames.length,
        'playlists': playlists.length,
        'favorites': favorites.length,
        'folders': listedFolders.length,
      },
      'queueCount': queueCount,
    };
  }

  /// `kind`: albums, artists, playlists, folders or recentlyAdded (albums).
  Future<Map<String, Object?>> list(String kind, {Object? limit}) async {
    final cap = carLimit(limit);
    final snap = await snapshot();
    switch (kind) {
      case 'albums':
        return {
          'items': [
            for (final group in snap.albums.take(cap)) _albumCollection(group),
          ],
          'total': snap.albums.length,
        };
      case 'recentlyAdded':
        return {
          'items': [
            for (final group in snap.recentlyAddedAlbums.take(cap))
              _albumCollection(group),
          ],
          'total': snap.recentlyAddedAlbums.length,
        };
      case 'artists':
        return {
          'items': await Future.wait([
            for (final name in snap.artistNames.take(cap))
              _artistCollection(snap, name),
          ]),
          'total': snap.artistNames.length,
        };
      case 'playlists':
        final playlists = await _loadPlaylists();
        return {
          'items': [
            for (final playlist in playlists.take(cap))
              _playlistCollection(snap, playlist),
          ],
          'total': playlists.length,
        };
      case 'folders':
        final folders = _listedFolders(snap, await _loadFolders());
        return {
          'items': [
            for (final folder in folders.take(cap))
              _folderCollection(snap, folder),
          ],
          'total': folders.length,
        };
    }
    throw CarException('bad_args', 'Unknown list kind "$kind"');
  }

  Future<Map<String, Object?>> collection(
    String kind,
    String id, {
    Object? limit,
  }) async {
    final cap = carLimit(limit);
    final resolved = await _resolve(kind, id);
    final isAlbum = kind == CarKind.album;
    final quality = carCommonQuality(resolved.songs);
    final color = resolved.art == null ? null : await _loadColor(resolved.art);
    return {
      'title': resolved.title,
      if (resolved.subtitle != null && resolved.subtitle!.isNotEmpty)
        'subtitle': resolved.subtitle,
      if (resolved.art != null && resolved.art!.isNotEmpty) 'art': resolved.art,
      'quality': ?quality,
      'tracks': [
        for (final song in resolved.songs.take(cap))
          carTrackMap(song, trackNo: isAlbum ? carTrackNumber(song) : null),
      ],
      'albums': resolved.albums.take(cap).toList(),
      'total': resolved.songs.length,
      'color': ?color,
    };
  }

  Future<Map<String, Object?>> search(String query, {Object? limit}) async {
    final cap = carLimit(limit, fallback: kCarSearchLimit);
    final snap = await snapshot();
    final playlists = await _loadPlaylists();
    final q = _normalize(query);
    final matchingPlaylists = q.isEmpty
        ? const <Playlist>[]
        : _ranked(playlists, q, (playlist) => playlist.name.toLowerCase());
    return {
      'tracks': [
        for (final song in snap.searchTracks(query).take(cap))
          carTrackMap(song),
      ],
      'albums': [
        for (final group in snap.searchAlbums(query).take(cap))
          _albumCollection(group),
      ],
      'artists': await Future.wait([
        for (final name in snap.searchArtists(query).take(cap))
          _artistCollection(snap, name),
      ]),
      'playlists': [
        for (final playlist in matchingPlaylists.take(cap))
          _playlistCollection(snap, playlist),
      ],
    };
  }

  // ------------------------------------------------------------- resolution

  /// The complete song list of a collection, for `play` and `enqueue`.
  Future<CarPlayable> resolve(String kind, String id) async {
    final resolved = await _resolve(kind, id);
    return CarPlayable(resolved.songs, resolved.context);
  }

  /// Best match for a spoken [query]: an artist, album or playlist named
  /// exactly like it, else the songs that match it. Null when nothing does.
  Future<CarPlayable?> resolveVoice(String query) async {
    final q = _normalize(query);
    if (q.isEmpty) return null;
    final snap = await snapshot();

    for (final name in snap.artistNames) {
      if (_normalize(name) == q) return resolve(CarKind.artist, name);
    }
    for (final group in snap.albums) {
      if (_normalize(group.albumName) == q) {
        return resolve(CarKind.album, group.key);
      }
    }
    for (final playlist in await _loadPlaylists()) {
      if (_normalize(playlist.name) == q) {
        return resolve(CarKind.playlist, playlist.id);
      }
    }

    final tracks = snap.searchTracks(query);
    if (tracks.isEmpty) return null;
    return CarPlayable(tracks, _syntheticContext(CarKind.search));
  }

  Future<_Resolved> _resolve(String kind, String id) async {
    final snap = await snapshot();
    switch (kind) {
      case CarKind.album:
        final group = snap.albumsByKey[id];
        if (group == null) throw _notFound(kind, id);
        return _Resolved(
          title: group.albumName,
          subtitle: group.albumArtist,
          art: carFirstArt(group.songs),
          songs: group.songs,
          context: PlaybackContext(
            source: PlaybackSource.album,
            sourceId: group.albumName,
            sourceName: group.albumName,
          ),
        );
      case CarKind.artist:
        final songs = snap.artists[id];
        if (songs == null) throw _notFound(kind, id);
        final albumKeys = <String>{};
        for (final song in songs) {
          final key = snap.albumKeyBySongId[song.id];
          if (key != null) albumKeys.add(key);
        }
        return _Resolved(
          title: carArtistName(id),
          art: await _artistArtFor(id, songs),
          songs: songs,
          albums: [
            for (final key in albumKeys)
              if (snap.albumsByKey[key] != null)
                _albumCollection(snap.albumsByKey[key]!),
          ],
          context: PlaybackContext(
            source: PlaybackSource.artist,
            sourceId: id,
            sourceName: id,
          ),
        );
      case CarKind.playlist:
        final playlist = (await _loadPlaylists())
            .where((candidate) => candidate.id == id)
            .firstOrNull;
        if (playlist == null) throw _notFound(kind, id);
        final songs = carPlaylistSongs(snap, playlist);
        return _Resolved(
          title: playlist.name,
          art: _playlistArt(playlist, songs),
          songs: songs,
          context: PlaybackContext(
            source: PlaybackSource.playlist,
            sourceId: playlist.id,
            sourceName: playlist.name,
          ),
        );
      case CarKind.folder:
        final songs = snap.songsByFolder[id];
        if (songs == null || songs.isEmpty) throw _notFound(kind, id);
        final folder = (await _loadFolders())
            .where((candidate) => candidate.uri == id)
            .firstOrNull;
        final name = folder?.name ?? _folderNameFromUri(id);
        return _Resolved(
          title: name,
          art: carFirstArt(songs),
          songs: songs,
          context: PlaybackContext(
            source: PlaybackSource.folder,
            sourceId: id,
            sourceName: name,
          ),
        );
      case CarKind.songs:
        return _Resolved(
          title: l10n.allSongs,
          art: carFirstArt(snap.songs),
          songs: snap.songs,
          context: _syntheticContext(kind),
        );
      case CarKind.favorites:
        final songs = _favoriteSongs(snap, await _loadFavoriteIds());
        return _Resolved(
          title: l10n.favorites,
          art: carFirstArt(songs),
          songs: songs,
          context: _syntheticContext(kind),
        );
      case CarKind.recentlyAdded:
        final songs = snap.recentlyAddedSongs;
        return _Resolved(
          title: l10n.recentlyAdded,
          art: carFirstArt(songs),
          songs: songs,
          context: _syntheticContext(kind),
        );
      case CarKind.mostPlayed:
        final songs = carMostPlayedSongs(
          snap,
          await _loadHistory(),
        ).take(kCarDerivedListCap).toList();
        return _Resolved(
          title: l10n.mostPlayed,
          art: carFirstArt(songs),
          songs: songs,
          context: _syntheticContext(kind),
        );
      case CarKind.recentlyPlayed:
        final songs = carRecentSongs(
          snap,
          await _loadHistory(),
        ).take(kCarDerivedListCap).toList();
        return _Resolved(
          title: l10n.recentlyPlayed,
          art: carFirstArt(songs),
          songs: songs,
          context: _syntheticContext(kind),
        );
      case CarKind.search:
        final songs = snap.searchTracks(id);
        return _Resolved(
          title: l10n.searchResults,
          art: carFirstArt(songs),
          songs: songs,
          context: _syntheticContext(kind),
        );
    }
    throw CarException('bad_args', 'Unknown collection kind "$kind"');
  }

  // ---------------------------------------------------------------- helpers

  CarException _notFound(String kind, String id) =>
      CarException('not_found', 'No $kind "$id"');

  /// Lists that are not an album, artist, playlist or folder play as a
  /// generic context named after the list.
  PlaybackContext _syntheticContext(String kind) {
    final name = switch (kind) {
      CarKind.songs => l10n.allSongs,
      CarKind.favorites => l10n.favorites,
      CarKind.recentlyAdded => l10n.recentlyAdded,
      CarKind.mostPlayed => l10n.mostPlayed,
      CarKind.recentlyPlayed => l10n.recentlyPlayed,
      _ => l10n.searchResults,
    };
    return PlaybackContext(
      source: PlaybackSource.allSongs,
      sourceId: kind,
      sourceName: name,
    );
  }

  List<Song> _favoriteSongs(CarSnapshot snap, Set<String> ids) => ids.isEmpty
      ? const []
      : [
          for (final song in snap.songs)
            if (ids.contains(song.id)) song,
        ];

  /// Watched folders that hold at least one song; an empty one would open a
  /// dead end.
  List<CarFolder> _listedFolders(CarSnapshot snap, List<CarFolder> folders) => [
    for (final folder in folders)
      if (snap.songsByFolder[folder.uri]?.isNotEmpty ?? false) folder,
  ];

  String _folderNameFromUri(String uri) =>
      Uri.tryParse(uri)?.pathSegments.lastOrNull ?? uri;

  Map<String, Object?> _albumCollection(AlbumGroup group) {
    return carCollectionMap(
      kind: CarKind.album,
      id: group.key,
      title: group.albumName,
      subtitle: group.albumArtist,
      art: carFirstArt(group.songs),
      count: group.songs.length,
      quality: carCommonQuality(group.songs),
    );
  }

  Future<Map<String, Object?>> _artistCollection(
    CarSnapshot snap,
    String name,
  ) async {
    final songs = snap.artists[name] ?? const <Song>[];
    return carCollectionMap(
      kind: CarKind.artist,
      id: name,
      title: carArtistName(name),
      art: await _artistArtFor(name, songs),
      count: songs.length,
    );
  }

  Map<String, Object?> _playlistCollection(
    CarSnapshot snap,
    Playlist playlist,
  ) {
    final songs = carPlaylistSongs(snap, playlist);
    return carCollectionMap(
      kind: CarKind.playlist,
      id: playlist.id,
      title: playlist.name,
      art: _playlistArt(playlist, songs),
      count: songs.length,
    );
  }

  Map<String, Object?> _folderCollection(CarSnapshot snap, CarFolder folder) {
    final songs = snap.songsByFolder[folder.uri] ?? const <Song>[];
    return carCollectionMap(
      kind: CarKind.folder,
      id: folder.uri,
      title: folder.name,
      art: carFirstArt(songs),
      count: songs.length,
    );
  }

  String? _playlistArt(Playlist playlist, List<Song> songs) {
    final cover = playlist.coverPath;
    return cover != null && cover.isNotEmpty ? cover : carFirstArt(songs);
  }

  /// The artist's own picture, else the first cover among their songs.
  Future<String?> _artistArtFor(String name, List<Song> songs) async {
    final own = await (_artistArt[name] ??= _loadArtistArt(
      name,
    ).catchError((Object _) => null));
    return own != null && own.isNotEmpty ? own : carFirstArt(songs);
  }
}

// -------------------------------------------------------- default data sources

Future<List<AlbumGroup>> _defaultAlbums() => SongRepository().getAlbumGroups();

Future<List<Playlist>> _defaultPlaylists() =>
    PlaylistService.instance.getPlaylists();

Future<List<CarFolder>> _defaultFolders() async {
  final entities = await FolderRepository().getAllFolders();
  return [
    for (final entity in entities)
      CarFolder(uri: entity.uri, name: entity.displayName),
  ];
}

/// A fresh service per read: each instance caches the ids it first loaded.
Future<Set<String>> _defaultFavoriteIds() async {
  final songs = await FavoritesService().getFavorites();
  return {for (final song in songs) song.id};
}

Future<List<CarPlayEvent>> _defaultHistory() async {
  final entries = await RecentlyPlayedRepository().getRecentHistory(
    limit: kCarHistoryWindow,
  );
  return [
    for (final entry in entries) CarPlayEvent(entry.song.id, entry.playedAt),
  ];
}

Future<String?> _defaultArtistArt(String name) async =>
    (await ArtistRepository().getByName(name))?.artPath;

/// The colour the notification already uses for this cover, honouring the
/// album-colour mode. Never delays an answer for long.
Future<int?> _defaultColor(String? artPath) async {
  if (artPath == null || artPath.isEmpty) return null;
  try {
    final mode = await AlbumColorModePreferenceService().getMode();
    if (mode == AlbumColorMode.off) return null;
    final color = await ColorExtractionService()
        .extractDominantColor(artPath)
        .timeout(const Duration(milliseconds: 400));
    return color?.toARGB32();
  } catch (_) {
    return null;
  }
}
