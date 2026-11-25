import 'package:flutter_test/flutter_test.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/playback_context.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/car/car_library.dart';
import 'package:flick/services/car/car_models.dart';

Song song(
  String id, {
  String? title,
  String artist = 'Artist',
  String? album,
  String? albumArtist,
  String fileType = 'FLAC',
  int? bitDepth = 16,
  int? sampleRate = 44100,
  String? art,
  int? trackNumber,
  int? discNumber,
  String? folderUri,
  DateTime? added,
  String? genre,
  int? year,
}) => Song(
  id: id,
  title: title ?? 'Song $id',
  artist: artist,
  album: album,
  albumArtist: albumArtist,
  albumArt: art,
  duration: const Duration(minutes: 3),
  fileType: fileType,
  bitDepth: bitDepth,
  sampleRate: sampleRate,
  trackNumber: trackNumber,
  discNumber: discNumber,
  folderUri: folderUri,
  dateAdded: added,
  genre: genre,
  year: year,
);

AlbumGroup albumGroup(String name, String artist, List<Song> songs) =>
    AlbumGroup(key: name, albumName: name, albumArtist: artist, songs: songs);

Playlist playlist(String id, String name, List<String> ids, {String? cover}) =>
    Playlist(
      id: id,
      name: name,
      songIds: ids,
      createdAt: DateTime(2025),
      coverPath: cover,
    );

/// A small library:
///  Kind of Blue (Miles Davis, 24/192): kb1 kb2 kb3, art
///  Blue Train (John Coltrane, 16/44.1 and one 24/96): bt1 bt2 bt3
///  Loose (no album): lo1
class Fixture {
  Fixture({
    List<AlbumGroup>? albums,
    this.playlists = const [],
    this.folders = const [],
    this.favoriteIds = const {},
    this.history = const [],
    this.artistArt = const {},
  }) : albums = albums ?? defaultAlbums() {
    library = CarLibrary(
      loadAlbums: () async {
        albumLoads++;
        return this.albums;
      },
      loadPlaylists: () async => playlists,
      loadFolders: () async => folders,
      loadFavoriteIds: () async => favoriteIds,
      loadHistory: () async => history,
      loadArtistArt: (name) async => artistArt[name],
      loadColor: (art) async => art == null ? null : 0xFF336699,
    );
  }

  static List<AlbumGroup> defaultAlbums() => [
    albumGroup('Blue Train', 'John Coltrane', [
      song(
        'bt1',
        title: 'Blue Train',
        artist: 'John Coltrane',
        album: 'Blue Train',
        trackNumber: 1,
        folderUri: 'saf://music',
        added: DateTime(2025, 3, 1),
      ),
      song(
        'bt2',
        title: 'Moment\'s Notice',
        artist: 'John Coltrane',
        album: 'Blue Train',
        trackNumber: 2,
        folderUri: 'saf://music',
        added: DateTime(2025, 3, 1),
      ),
      song(
        'bt3',
        title: 'Locomotion',
        artist: 'John Coltrane',
        album: 'Blue Train',
        trackNumber: 3,
        bitDepth: 24,
        sampleRate: 96000,
        folderUri: 'saf://music',
        added: DateTime(2025, 3, 1),
      ),
    ]),
    albumGroup('Kind of Blue', 'Miles Davis', [
      song(
        'kb1',
        title: 'So What',
        artist: 'Miles Davis',
        album: 'Kind of Blue',
        trackNumber: 1,
        bitDepth: 24,
        sampleRate: 192000,
        art: '/art/kob.jpg',
        folderUri: 'saf://music',
        added: DateTime(2025, 6, 1),
        genre: 'Jazz',
        year: 1959,
      ),
      song(
        'kb2',
        title: 'Freddie Freeloader',
        artist: 'Miles Davis',
        album: 'Kind of Blue',
        trackNumber: 2,
        bitDepth: 24,
        sampleRate: 192000,
        art: '/art/kob.jpg',
        folderUri: 'saf://music',
        added: DateTime(2025, 6, 2),
        genre: 'Jazz',
        year: 1959,
      ),
      song(
        'kb3',
        title: 'Blue in Green',
        artist: 'Miles Davis',
        album: 'Kind of Blue',
        trackNumber: 3,
        bitDepth: 24,
        sampleRate: 192000,
        art: '/art/kob.jpg',
        folderUri: 'saf://music',
        added: DateTime(2025, 6, 3),
        genre: 'Jazz',
        year: 1959,
      ),
    ]),
    albumGroup('Unknown Album', 'Nobody', [
      song(
        'lo1',
        title: 'Loose',
        artist: 'Nobody',
        fileType: 'MP3',
        bitDepth: null,
        sampleRate: null,
      ),
    ]),
  ];

  final List<AlbumGroup> albums;
  final List<Playlist> playlists;
  final List<CarFolder> folders;
  final Set<String> favoriteIds;
  final List<CarPlayEvent> history;
  final Map<String, String?> artistArt;
  int albumLoads = 0;
  late final CarLibrary library;
}

List<String> ids(Object? tracks) => [
  for (final t in tracks! as List) (t as Map)['id'] as String,
];

void main() {
  group('snapshot cache', () {
    test('builds once for many requests', () async {
      final f = Fixture();
      await f.library.list('albums');
      await f.library.list('artists');
      await f.library.collection(CarKind.songs, '');
      expect(f.albumLoads, 1);
    });

    test('concurrent first requests share one load', () async {
      final f = Fixture();
      await Future.wait([
        f.library.list('albums'),
        f.library.list('artists'),
        f.library.search('blue'),
      ]);
      expect(f.albumLoads, 1);
    });

    test('invalidate drops it', () async {
      final f = Fixture();
      await f.library.list('albums');
      f.library.invalidate();
      await f.library.list('albums');
      expect(f.albumLoads, 2);
    });

    test('a failed load is not cached', () async {
      var attempts = 0;
      final library = CarLibrary(
        loadAlbums: () async {
          attempts++;
          if (attempts == 1) throw StateError('db not ready');
          return Fixture.defaultAlbums();
        },
        loadPlaylists: () async => const [],
        loadFolders: () async => const [],
        loadFavoriteIds: () async => const {},
        loadHistory: () async => const [],
        loadArtistArt: (_) async => null,
      );
      await expectLater(library.list('albums'), throwsStateError);
      final result = await library.list('albums');
      expect(result['total'], 3);
      expect(attempts, 2);
    });
  });

  group('list', () {
    test('albums keep the phone order and report the full total', () async {
      final f = Fixture();
      final result = await f.library.list('albums');
      final items = result['items']! as List;
      expect(
        [for (final i in items) (i as Map)['id']],
        ['Blue Train', 'Kind of Blue', 'Unknown Album'],
      );
      expect(result['total'], 3);
    });

    test('album item shape', () async {
      final f = Fixture();
      final result = await f.library.list('albums');
      final kob = (result['items']! as List)[1] as Map;
      expect(kob, {
        'kind': 'album',
        'id': 'Kind of Blue',
        'title': 'Kind of Blue',
        'subtitle': 'Miles Davis',
        'art': '/art/kob.jpg',
        'count': 3,
        'quality': '24/192 FLAC',
      });
    });

    test('an album with mixed quality has no quality label', () async {
      final f = Fixture();
      final result = await f.library.list('albums');
      final blueTrain = (result['items']! as List).first as Map;
      expect(blueTrain.containsKey('quality'), isFalse);
    });

    test('the limit caps the items but not the total', () async {
      final f = Fixture();
      final result = await f.library.list('albums', limit: 2);
      expect(result['items'], hasLength(2));
      expect(result['total'], 3);
    });

    test(
      'artists are sorted by name and use own art, else a song cover',
      () async {
        final f = Fixture(artistArt: {'John Coltrane': '/art/coltrane.jpg'});
        final result = await f.library.list('artists');
        final items = (result['items']! as List).cast<Map>();
        expect(
          [for (final i in items) i['id']],
          ['John Coltrane', 'Miles Davis', 'Nobody'],
        );
        expect(items[0]['art'], '/art/coltrane.jpg');
        expect(items[1]['art'], '/art/kob.jpg');
        expect(items[2].containsKey('art'), isFalse);
        expect(items[0]['kind'], 'artist');
        expect(items[0]['count'], 3);
      },
    );

    test('artist art lookups are cached until invalidated', () async {
      var lookups = 0;
      final library = CarLibrary(
        loadAlbums: () async => Fixture.defaultAlbums(),
        loadPlaylists: () async => const [],
        loadFolders: () async => const [],
        loadFavoriteIds: () async => const {},
        loadHistory: () async => const [],
        loadArtistArt: (_) async {
          lookups++;
          return null;
        },
      );
      await library.list('artists');
      await library.list('artists');
      expect(lookups, 3);
      library.invalidate();
      await library.list('artists');
      expect(lookups, 6);
    });

    test('playlists use their cover, else the first song cover', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'Late night', ['kb2', 'bt1'], cover: '/cover.jpg'),
          playlist('p2', 'Coltrane first', ['bt1', 'kb1']),
        ],
      );
      final result = await f.library.list('playlists');
      final items = (result['items']! as List).cast<Map>();
      expect(items[0]['art'], '/cover.jpg');
      expect(items[0]['count'], 2);
      expect(items[1]['art'], '/art/kob.jpg');
      expect(result['total'], 2);
    });

    test('a playlist counts only songs still in the library', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'Gone', ['kb1', 'deleted', 'kb1', 'kb2']),
        ],
      );
      final result = await f.library.list('playlists');
      expect(((result['items']! as List).first as Map)['count'], 2);
    });

    test('folders list only those that hold songs', () async {
      final f = Fixture(
        folders: const [
          CarFolder(uri: 'saf://music', name: 'Music'),
          CarFolder(uri: 'saf://empty', name: 'Empty'),
        ],
      );
      final result = await f.library.list('folders');
      final items = (result['items']! as List).cast<Map>();
      expect(items, hasLength(1));
      expect(items.single['kind'], 'folder');
      expect(items.single['id'], 'saf://music');
      expect(items.single['title'], 'Music');
      expect(items.single['count'], 6);
      expect(result['total'], 1);
    });

    test('recentlyAdded lists albums, newest first', () async {
      final f = Fixture();
      final result = await f.library.list('recentlyAdded');
      final items = (result['items']! as List).cast<Map>();
      // Unknown Album has no add date and is left out.
      expect([for (final i in items) i['id']], ['Kind of Blue', 'Blue Train']);
      expect(items.first['kind'], 'album');
      expect(result['total'], 2);
    });

    test('an unknown kind is a bad request', () async {
      final f = Fixture();
      await expectLater(
        f.library.list('genres'),
        throwsA(isA<CarException>().having((e) => e.code, 'code', 'bad_args')),
      );
    });

    test('with no limit given the list is capped at 300', () async {
      final songs = [
        for (var i = 0; i < 450; i++)
          song('s$i', album: 'Album $i', art: '/a$i.jpg'),
      ];
      final library = CarLibrary(
        loadAlbums: () async => [
          for (final s in songs) albumGroup(s.album!, 'Artist', [s]),
        ],
        loadPlaylists: () async => const [],
        loadFolders: () async => const [],
        loadFavoriteIds: () async => const {},
        loadHistory: () async => const [],
        loadArtistArt: (_) async => null,
      );
      final result = await library.list('albums');
      expect(result['items'], hasLength(300));
      expect(result['total'], 450);
    });
  });

  group('collection', () {
    test('album: ordered tracks with trackNo, subtitle and quality', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.album, 'Kind of Blue');
      expect(result['title'], 'Kind of Blue');
      expect(result['subtitle'], 'Miles Davis');
      expect(result['art'], '/art/kob.jpg');
      expect(result['quality'], '24/192 FLAC');
      expect(result['total'], 3);
      expect(result['albums'], isEmpty);
      final tracks = (result['tracks']! as List).cast<Map>();
      expect(ids(tracks), ['kb1', 'kb2', 'kb3']);
      expect([for (final t in tracks) t['trackNo']], [1, 2, 3]);
      expect(tracks.first['quality'], '24/192 FLAC');
    });

    test('album with mixed quality has no collection quality', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.album, 'Blue Train');
      expect(result.containsKey('quality'), isFalse);
    });

    test('the limit caps the tracks, total stays complete', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.songs, '', limit: 2);
      expect(result['tracks'], hasLength(2));
      expect(result['total'], 7);
    });

    test('a dominant colour is included when the art has one', () async {
      final f = Fixture();
      final withArt = await f.library.collection(CarKind.album, 'Kind of Blue');
      expect(withArt['color'], 0xFF336699);
      final noArt = await f.library.collection(CarKind.album, 'Unknown Album');
      expect(noArt.containsKey('color'), isFalse);
    });

    test('non-album kinds carry no trackNo', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.songs, '');
      for (final track in (result['tracks']! as List).cast<Map>()) {
        expect(track.containsKey('trackNo'), isFalse);
      }
    });

    test('artist: that artist\'s albums plus all their tracks', () async {
      final f = Fixture(artistArt: {'Miles Davis': '/art/miles.jpg'});
      final result = await f.library.collection(CarKind.artist, 'Miles Davis');
      expect(result['title'], 'Miles Davis');
      expect(result['art'], '/art/miles.jpg');
      expect(result['total'], 3);
      expect(ids(result['tracks']), ['kb1', 'kb2', 'kb3']);
      final albums = (result['albums']! as List).cast<Map>();
      expect(albums, hasLength(1));
      expect(albums.single['id'], 'Kind of Blue');
      expect(albums.single['kind'], 'album');
    });

    test('artist art falls back to a song cover', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.artist, 'Miles Davis');
      expect(result['art'], '/art/kob.jpg');
    });

    test('playlist keeps its own order and skips missing songs', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'Mix', ['kb3', 'gone', 'bt1', 'kb3']),
        ],
      );
      final result = await f.library.collection(CarKind.playlist, 'p1');
      expect(result['title'], 'Mix');
      expect(ids(result['tracks']), ['kb3', 'bt1']);
      expect(result['total'], 2);
    });

    test('folder: its songs, named by the folder', () async {
      final f = Fixture(
        folders: const [CarFolder(uri: 'saf://music', name: 'Music')],
      );
      final result = await f.library.collection(CarKind.folder, 'saf://music');
      expect(result['title'], 'Music');
      expect(result['total'], 6);
    });

    test('songs are by title', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.songs, '');
      expect((result['tracks']! as List).first, containsPair('id', 'kb3'));
      // Blue in Green, Blue Train, Freddie Freeloader, Locomotion, Loose...
      expect(ids(result['tracks']).take(2), ['kb3', 'bt1']);
    });

    test('favorites are the favorite ids that are still songs', () async {
      final f = Fixture(favoriteIds: {'kb1', 'bt2', 'removed'});
      final result = await f.library.collection(CarKind.favorites, '');
      expect(ids(result['tracks']).toSet(), {'kb1', 'bt2'});
      expect(result['total'], 2);
    });

    test('no favorites is an empty collection, not an error', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.favorites, '');
      expect(result['tracks'], isEmpty);
      expect(result['total'], 0);
    });

    test('recentlyAdded songs are newest first', () async {
      final f = Fixture();
      final result = await f.library.collection(CarKind.recentlyAdded, '');
      expect(ids(result['tracks']).take(3), ['kb3', 'kb2', 'kb1']);
      // The song with no add date is not part of it.
      expect(ids(result['tracks']), isNot(contains('lo1')));
    });

    test('unknown ids are not found', () async {
      final f = Fixture();
      for (final call in [
        () => f.library.collection(CarKind.album, 'Nope'),
        () => f.library.collection(CarKind.artist, 'Nope'),
        () => f.library.collection(CarKind.playlist, 'Nope'),
        () => f.library.collection(CarKind.folder, 'saf://nope'),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<CarException>().having((e) => e.code, 'code', 'not_found'),
          ),
        );
      }
    });

    test('an unknown kind is a bad request', () async {
      final f = Fixture();
      await expectLater(
        f.library.collection('genre', 'Jazz'),
        throwsA(isA<CarException>().having((e) => e.code, 'code', 'bad_args')),
      );
    });
  });

  group('resolve (kind, id) to the complete list and its context', () {
    test(
      'album plays the whole album in track order with album context',
      () async {
        final f = Fixture();
        final playable = await f.library.resolve(CarKind.album, 'Kind of Blue');
        expect(playable.songs.map((s) => s.id), ['kb1', 'kb2', 'kb3']);
        expect(playable.context.source, PlaybackSource.album);
        expect(playable.context.sourceId, 'Kind of Blue');
        expect(playable.context.sourceName, 'Kind of Blue');
      },
    );

    test('is not cut by any page limit', () async {
      final songs = [for (var i = 0; i < 500; i++) song('s$i', album: 'Big')];
      final library = CarLibrary(
        loadAlbums: () async => [albumGroup('Big', 'Artist', songs)],
        loadPlaylists: () async => const [],
        loadFolders: () async => const [],
        loadFavoriteIds: () async => const {},
        loadHistory: () async => const [],
        loadArtistArt: (_) async => null,
      );
      final page = await library.collection(CarKind.album, 'Big', limit: 300);
      expect(page['tracks'], hasLength(300));
      final playable = await library.resolve(CarKind.album, 'Big');
      expect(playable.songs, hasLength(500));
    });

    test('artist, playlist and folder contexts', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'Mix', ['kb1']),
        ],
        folders: const [CarFolder(uri: 'saf://music', name: 'Music')],
      );
      final artist = await f.library.resolve(CarKind.artist, 'Miles Davis');
      expect(artist.context.source, PlaybackSource.artist);
      expect(artist.context.sourceId, 'Miles Davis');

      final pl = await f.library.resolve(CarKind.playlist, 'p1');
      expect(pl.context.source, PlaybackSource.playlist);
      expect(pl.context.sourceId, 'p1');
      expect(pl.context.sourceName, 'Mix');

      final folder = await f.library.resolve(CarKind.folder, 'saf://music');
      expect(folder.context.source, PlaybackSource.folder);
      expect(folder.context.sourceId, 'saf://music');
      expect(folder.context.sourceName, 'Music');
    });

    test('lists without an owner play as a named generic context', () async {
      final f = Fixture(favoriteIds: {'kb1'});
      final songs = await f.library.resolve(CarKind.songs, '');
      expect(songs.songs, hasLength(7));
      expect(songs.context.source, PlaybackSource.allSongs);
      expect(songs.context.sourceId, 'songs');
      expect(songs.context.sourceName, isNotEmpty);

      final favorites = await f.library.resolve(CarKind.favorites, '');
      expect(favorites.songs.map((s) => s.id), ['kb1']);
      expect(favorites.context.sourceId, 'favorites');
    });

    test('search resolves to every match, not a page of them', () async {
      final f = Fixture();
      final playable = await f.library.resolve(CarKind.search, 'blue');
      expect(playable.songs.map((s) => s.id).toSet(), {
        'kb1',
        'kb2',
        'kb3',
        'bt1',
        'bt2',
        'bt3',
      });
      expect(playable.context.sourceId, 'search');
    });

    test('an empty folder is not found', () async {
      final f = Fixture(
        folders: const [CarFolder(uri: 'saf://empty', name: 'Empty')],
      );
      await expectLater(
        f.library.resolve(CarKind.folder, 'saf://empty'),
        throwsA(isA<CarException>()),
      );
    });
  });

  group('search', () {
    test('result shape: tracks, albums, artists, playlists', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'Blue hour', ['kb1']),
        ],
      );
      final result = await f.library.search('blue');
      expect(result.keys.toSet(), {'tracks', 'albums', 'artists', 'playlists'});
      expect(ids(result['tracks']).toSet(), {
        'kb1',
        'kb2',
        'kb3',
        'bt1',
        'bt2',
        'bt3',
      });
      expect(
        [for (final a in (result['albums']! as List).cast<Map>()) a['id']],
        ['Blue Train', 'Kind of Blue'],
      );
      expect(result['artists'], isEmpty);
      expect(((result['playlists']! as List).single as Map)['id'], 'p1');
    });

    test('title prefix matches rank before other matches', () async {
      final f = Fixture();
      final result = await f.library.search('blue');
      final tracks = ids(result['tracks']);
      // "Blue in Green" and "Blue Train" start with it; the rest match the
      // album name only.
      expect(tracks.take(2).toSet(), {'kb3', 'bt1'});
    });

    test('matches artist, album artist and genre too', () async {
      final f = Fixture();
      expect(ids((await f.library.search('coltrane'))['tracks']).toSet(), {
        'bt1',
        'bt2',
        'bt3',
      });
      expect(ids((await f.library.search('jazz'))['tracks']).toSet(), {
        'kb1',
        'kb2',
        'kb3',
      });
      expect(ids((await f.library.search('1959'))['tracks']).toSet(), {
        'kb1',
        'kb2',
        'kb3',
      });
    });

    test('is case and spacing insensitive', () async {
      final f = Fixture();
      final result = await f.library.search('  MILES   davis ');
      expect(ids(result['tracks']).toSet(), {'kb1', 'kb2', 'kb3'});
      expect(
        [for (final a in (result['artists']! as List).cast<Map>()) a['id']],
        ['Miles Davis'],
      );
    });

    test('artist results carry kind artist', () async {
      final f = Fixture();
      final result = await f.library.search('miles');
      final artist = (result['artists']! as List).single as Map;
      expect(artist['kind'], 'artist');
      expect(artist['title'], 'Miles Davis');
    });

    test('the limit applies per type', () async {
      final f = Fixture();
      final result = await f.library.search('blue', limit: 2);
      expect(result['tracks'], hasLength(2));
      expect(result['albums'], hasLength(2));
    });

    test('with no limit given each type is capped at 30', () async {
      final songs = [
        for (var i = 0; i < 80; i++)
          song('s$i', title: 'Needle $i', album: 'Haystack $i', artist: 'A$i'),
      ];
      final library = CarLibrary(
        loadAlbums: () async => [
          for (final s in songs) albumGroup(s.album!, 'Artist', [s]),
        ],
        loadPlaylists: () async => const [],
        loadFolders: () async => const [],
        loadFavoriteIds: () async => const {},
        loadHistory: () async => const [],
        loadArtistArt: (_) async => null,
      );
      final result = await library.search('needle');
      expect(result['tracks'], hasLength(30));
      expect(result['albums'], isEmpty);
      final byArtist = await library.search('a');
      expect(byArtist['artists'], hasLength(30));
    });

    test('an empty query finds nothing', () async {
      final f = Fixture();
      final result = await f.library.search('   ');
      expect(result['tracks'], isEmpty);
      expect(result['albums'], isEmpty);
      expect(result['artists'], isEmpty);
      expect(result['playlists'], isEmpty);
    });
  });

  group('resolveVoice', () {
    test('an exact artist plays the artist', () async {
      final f = Fixture();
      final playable = await f.library.resolveVoice('miles davis');
      expect(playable!.context.source, PlaybackSource.artist);
      expect(playable.songs, hasLength(3));
    });

    test('an exact album plays the album', () async {
      final f = Fixture();
      final playable = await f.library.resolveVoice('Kind of Blue');
      expect(playable!.context.source, PlaybackSource.album);
      expect(playable.songs.first.id, 'kb1');
    });

    test('an exact playlist plays the playlist', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'Late Night', ['kb2']),
        ],
      );
      final playable = await f.library.resolveVoice('late night');
      expect(playable!.context.source, PlaybackSource.playlist);
      expect(playable.songs.single.id, 'kb2');
    });

    test('otherwise the matching songs play as search results', () async {
      final f = Fixture();
      final playable = await f.library.resolveVoice('freddie');
      expect(playable!.songs.single.id, 'kb2');
      expect(playable.context.sourceId, 'search');
    });

    test('no match is null', () async {
      final f = Fixture();
      expect(await f.library.resolveVoice('zzzzzz'), isNull);
      expect(await f.library.resolveVoice(' '), isNull);
    });
  });

  group('history lists', () {
    final events = [
      CarPlayEvent('kb1', DateTime(2025, 7, 1, 10)),
      CarPlayEvent('bt1', DateTime(2025, 7, 1, 11)),
      CarPlayEvent('kb2', DateTime(2025, 7, 1, 12)),
      CarPlayEvent('kb1', DateTime(2025, 7, 1, 13)),
      CarPlayEvent('kb1', DateTime(2025, 7, 1, 14)),
      CarPlayEvent('missing', DateTime(2025, 7, 1, 15)),
    ];

    test('jump back in: distinct albums, most recent play first', () async {
      final f = Fixture(history: events);
      final home = await f.library.home();
      final jump = (home['jumpBackIn']! as List).cast<Map>();
      expect([for (final a in jump) a['id']], ['Kind of Blue', 'Blue Train']);
      expect(jump.first['kind'], 'album');
    });

    test('jump back in is capped at 8', () async {
      final albums = [
        for (var i = 0; i < 12; i++)
          albumGroup('Album $i', 'Artist', [song('s$i', album: 'Album $i')]),
      ];
      final history = [
        for (var i = 0; i < 12; i++)
          CarPlayEvent('s$i', DateTime(2025, 1, 1, i)),
      ];
      final f = Fixture(albums: albums, history: history);
      final home = await f.library.home();
      final jump = (home['jumpBackIn']! as List).cast<Map>();
      expect(jump, hasLength(8));
      expect(jump.first['id'], 'Album 11');
    });

    test('most played ranks by plays, then by recency', () async {
      final f = Fixture(history: events);
      final result = await f.library.collection(CarKind.mostPlayed, '');
      // kb1 x3, then kb2 (12:00) before bt1 (11:00), one play each.
      expect(ids(result['tracks']), ['kb1', 'kb2', 'bt1']);
    });

    test('recently played is distinct, most recent first', () async {
      final f = Fixture(history: events);
      final result = await f.library.collection(CarKind.recentlyPlayed, '');
      expect(ids(result['tracks']), ['kb1', 'kb2', 'bt1']);
    });

    test('home most played is capped at 5', () async {
      final songs = [for (var i = 0; i < 9; i++) song('s$i', album: 'A')];
      final history = [
        for (var i = 0; i < 9; i++)
          CarPlayEvent('s$i', DateTime(2025, 1, 1, i)),
      ];
      final f = Fixture(
        albums: [albumGroup('A', 'Artist', songs)],
        history: history,
      );
      final home = await f.library.home();
      expect(home['mostPlayed'], hasLength(5));
    });

    test('derived lists are bounded for play', () async {
      final songs = [for (var i = 0; i < 250; i++) song('s$i', album: 'A')];
      final history = [
        for (var i = 0; i < 250; i++)
          CarPlayEvent('s$i', DateTime(2025, 1, 1).add(Duration(minutes: i))),
      ];
      final f = Fixture(
        albums: [albumGroup('A', 'Artist', songs)],
        history: history,
      );
      final playable = await f.library.resolve(CarKind.recentlyPlayed, '');
      expect(playable.songs, hasLength(kCarDerivedListCap));
    });
  });

  group('home', () {
    test('has every contract key', () async {
      final f = Fixture();
      final home = await f.library.home();
      expect(home.keys.toSet(), {
        'resume',
        'jumpBackIn',
        'recentlyAdded',
        'mostPlayed',
        'playlists',
        'counts',
        'queueCount',
      });
      expect(home['resume'], isNull);
      expect(home['queueCount'], 0);
    });

    test('counts', () async {
      final f = Fixture(
        playlists: [
          playlist('p1', 'A', ['kb1']),
          playlist('p2', 'B', []),
        ],
        folders: const [
          CarFolder(uri: 'saf://music', name: 'Music'),
          CarFolder(uri: 'saf://empty', name: 'Empty'),
        ],
        favoriteIds: {'kb1', 'bt1', 'removed'},
      );
      final home = await f.library.home();
      expect(home['counts'], {
        'songs': 7,
        'albums': 3,
        'artists': 3,
        'playlists': 2,
        'favorites': 2,
        'folders': 1,
      });
    });

    test('resume is the current song as a track', () async {
      final f = Fixture();
      final current = f.albums[1].songs.first;
      final home = await f.library.home(resume: current, queueCount: 14);
      expect((home['resume']! as Map)['id'], 'kb1');
      expect((home['resume']! as Map)['quality'], '24/192 FLAC');
      expect(home['queueCount'], 14);
    });

    test('recently added is at most 12 albums, newest first', () async {
      final albums = [
        for (var i = 0; i < 20; i++)
          albumGroup('Album $i', 'Artist', [
            song('s$i', album: 'Album $i', added: DateTime(2025, 1, 1 + i)),
          ]),
      ];
      final f = Fixture(albums: albums);
      final home = await f.library.home();
      final recent = (home['recentlyAdded']! as List).cast<Map>();
      expect(recent, hasLength(12));
      expect(recent.first['id'], 'Album 19');
    });

    test('playlists are at most 12', () async {
      final f = Fixture(
        playlists: [
          for (var i = 0; i < 15; i++) playlist('p$i', 'List $i', ['kb1']),
        ],
      );
      final home = await f.library.home();
      expect(home['playlists'], hasLength(12));
      expect((home['counts']! as Map)['playlists'], 15);
    });

    test('an empty library answers with zero counts', () async {
      final f = Fixture(albums: const []);
      final home = await f.library.home();
      expect((home['counts']! as Map)['songs'], 0);
      expect(home['recentlyAdded'], isEmpty);
      expect(home['jumpBackIn'], isEmpty);
    });
  });
}
