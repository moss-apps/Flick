import 'dart:convert';
import 'dart:io';

import 'package:flick/services/apple_music/apple_music_cache.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

http.Response _html(String body, [int status = 200]) =>
    http.Response(body, status, headers: {'content-type': 'text/html'});

Map<String, dynamic> _artistSearchResult({
  required String name,
  required int id,
  String genre = 'Alternative',
}) => {
  'wrapperType': 'artist',
  'artistType': 'Artist',
  'artistName': name,
  'artistLinkUrl': 'https://music.apple.com/us/artist/x/$id?uo=4',
  'artistId': id,
  'primaryGenreName': genre,
};

Map<String, dynamic> _collection({
  required String name,
  required int id,
  String artist = 'Radiohead',
  String? artwork = 'https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg',
  String? viewUrl,
}) => {
  'wrapperType': 'collection',
  'collectionType': 'Album',
  'collectionName': name,
  'artistName': artist,
  'collectionId': id,
  'collectionViewUrl':
      viewUrl ?? 'https://music.apple.com/us/album/$id?uo=4&app=music',
  'artworkUrl100': ?artwork,
  'releaseDate': '1997-05-21T07:00:00Z',
  'primaryGenreName': 'Alternative',
  'trackCount': 12,
};

Map<String, dynamic> _track({
  required String name,
  int? number,
  int? timeMs,
  int id = 1,
}) => {
  'wrapperType': 'track',
  'kind': 'song',
  'trackName': name,
  'artistName': 'Radiohead',
  'collectionName': 'OK Computer',
  'trackId': id,
  'trackNumber': ?number,
  'trackTimeMillis': ?timeMs,
  'trackViewUrl': 'https://music.apple.com/us/song/$id?uo=4',
};

final _artistPageHtml = '''
<!DOCTYPE html><html><head>
<script type="application/ld+json">{"@type":"MusicGroup","name":"Radiohead","description":"Radiohead is an English rock band formed in Abingdon.","image":"https://is1-ssl.mzstatic.com/image/thumb/artist/300x300bb.jpg"}</script>
</head><body>
<section aria-label="Similar Artists"><h2>Similar Artists</h2>
<div>${'padding ' * 30}</div>
<a data-testid="ellipse-lockup__title" href="/us/artist/thom-yorke/1">Thom Yorke</a>
<a data-testid="ellipse-lockup__title">Atoms for Peace</a>
<a data-testid="ellipse-lockup__title">Thom Yorke</a>
<a data-testid="ellipse-lockup__title">Portishead &amp; Friends</a>
<div data-testid="section-container">next section</div>
<a data-testid="ellipse-lockup__title">Should Not Appear</a>
</section>
</body></html>
''';

const _albumNotesHtml =
    '<script id="serialized-server-data">{"data":[{"data":{"sections":[{"items":[{"modalPresentationDescriptor":{"paragraphText":"An album about alienation.\\n\\nRecorded in 1997."}}]}]}}]}</script>';

void main() {
  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('apple_music_test_');
  });

  tearDown(() async {
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  AppleMusicMetadataService serviceWith(MockClient client) =>
      AppleMusicMetadataService.create(
        client: client,
        cache: AppleMusicCache.forDirectory(cacheDir),
      );

  group('resolveArtist', () {
    test('prefers an exact normalized name match', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'itunes.apple.com') {
          return _json({
            'resultCount': 2,
            'results': [
              _artistSearchResult(name: 'Radiohead Tribute Co.', id: 1),
              _artistSearchResult(name: 'radiohead', id: 657515),
            ],
          });
        }
        return _json({}, 404);
      });

      final artist = await serviceWith(client).resolveArtist('Radiohead');

      expect(artist, isNotNull);
      expect(artist!.artistId, '657515');
      expect(artist.name, 'radiohead');
      expect(artist.genre, 'Alternative');
      expect(artist.url, 'https://music.apple.com/us/artist/x/657515');
    });

    test('falls back to iTunes relevance order', () async {
      final client = MockClient(
        (request) async => _json({
          'resultCount': 1,
          'results': [_artistSearchResult(name: 'Stereolab Tribute', id: 9)],
        }),
      );

      final artist = await serviceWith(client).resolveArtist('Stereolab');

      expect(artist!.artistId, '9');
    });

    test('caches negative results without a second request', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _json({'resultCount': 0, 'results': []});
      });

      final service = serviceWith(client);
      expect(await service.resolveArtist('Nobody'), isNull);
      expect(await service.resolveArtist('Nobody'), isNull);
      expect(calls, 1);
    });

    test('does not persist a transient failure and retries on a fresh cache', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) return _json({}, 500);
        return _json({
          'resultCount': 1,
          'results': [_artistSearchResult(name: 'Boards of Canada', id: 7)],
        });
      });

      final first = serviceWith(client);
      expect(await first.resolveArtist('Boards of Canada'), isNull);
      expect(await first.resolveArtist('Boards of Canada'), isNull);
      expect(calls, 1);

      final second = serviceWith(client);
      expect(await second.resolveArtist('Boards of Canada'), isNotNull);
      expect(calls, 2);
    });

    test('reads a cached artist from disk on a fresh cache', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _json({
          'resultCount': 1,
          'results': [_artistSearchResult(name: 'Aphex Twin', id: 42)],
        });
      });

      final first = serviceWith(client);
      expect((await first.resolveArtist('Aphex Twin'))?.artistId, '42');

      final second = serviceWith(client);
      final cached = await second.resolveArtist('Aphex Twin');

      expect(cached?.artistId, '42');
      expect(calls, 1);
    });
  });

  group('getArtistInfo', () {
    test('parses biography, image and similar artists', () async {
      final client = MockClient((request) async => _html(_artistPageHtml));

      final info = await serviceWith(client).getArtistInfo('657515');

      expect(info, isNotNull);
      expect(info!.name, 'Radiohead');
      expect(info.biography, contains('English rock band'));
      expect(info.imageUrl, contains('1500x1500bb.jpg'));
      expect(info.storefront, 'us');
      expect(info.url, 'https://music.apple.com/us/artist/-/657515');
      expect(
        info.similarArtists.map((artist) => artist.name),
        ['Thom Yorke', 'Atoms for Peace', 'Portishead & Friends'],
      );
    });

    test('falls back to og:image and og:description', () async {
      const page = '''
<html><head>
<meta property="og:title" content="Portishead">
<meta property="og:description" content="Trip hop trio from Bristol.">
<meta property="og:image" content="https://is1-ssl.mzstatic.com/image/thumb/x/60x60bb.jpg">
</head><body></body></html>''';
      final client = MockClient((request) async => _html(page));

      final info = await serviceWith(client).getArtistInfo('1');

      expect(info!.name, 'Portishead');
      expect(info.biography, 'Trip hop trio from Bristol.');
      expect(info.imageUrl, contains('1500x1500bb.jpg'));
    });

    test('discards Apple Music placeholder biography and image', () async {
      const page = '''
<html><head>
<script type="application/ld+json">{"@type":"MusicGroup","name":"X","description":"Listen to music by X on Apple Music.","image":"https://music.apple.com/assets/meta/apple-music.png"}</script>
</head><body></body></html>''';
      final client = MockClient((request) async => _html(page));

      final info = await serviceWith(client).getArtistInfo('1');

      expect(info!.biography, isNull);
      expect(info.imageUrl, isNull);
    });

    test('returns null on a 404 without caching a transient failure', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _html('not found', 404);
      });

      final service = serviceWith(client);
      expect(await service.getArtistInfo('999'), isNull);
      expect(await service.getArtistInfo('999'), isNull);
      expect(calls, 1);
    });
  });

  group('getTopSongs', () {
    test('filters to tracks and maps fields', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'itunes.apple.com');
        expect(request.url.path, '/lookup');
        expect(request.url.queryParameters['sort'], 'popular');
        return _json({
          'resultCount': 3,
          'results': [
            _artistSearchResult(name: 'Radiohead', id: 657515),
            _track(name: ' Paranoid Android ', number: 2, timeMs: 383000),
            _track(name: 'Creep', number: 1, timeMs: 238000, id: 2),
          ],
        });
      });

      final songs = await serviceWith(client).getTopSongs('657515', limit: 2);

      expect(songs, hasLength(2));
      expect(songs.first.trackName, 'Paranoid Android');
      expect(songs.first.durationMs, 383000);
      expect(songs.last.trackName, 'Creep');
    });
  });

  group('resolveAlbum', () {
    test('matches exact name before base name', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['entity'] == 'musicArtist') {
          return _json({
            'resultCount': 1,
            'results': [_artistSearchResult(name: 'Radiohead', id: 657515)],
          });
        }
        return _json({
          'resultCount': 3,
          'results': [
            _collection(name: 'In Rainbows (Disk 2)', id: 1),
            _collection(name: 'in rainbows', id: 2),
            _collection(name: 'In Rainbows', id: 3),
          ],
        });
      });

      final match = await serviceWith(
        client,
      ).resolveAlbum(album: 'In Rainbows', artist: 'Radiohead');

      expect(match!.collectionId, '2');
    });

    test('matches by base name and strips tracking from the url', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['entity'] == 'musicArtist') {
          return _json({
            'resultCount': 1,
            'results': [_artistSearchResult(name: 'Radiohead', id: 657515)],
          });
        }
        return _json({
          'resultCount': 1,
          'results': [_collection(name: 'Kid A (Special Edition)', id: 5)],
        });
      });

      final match = await serviceWith(
        client,
      ).resolveAlbum(album: 'Kid A', artist: 'Radiohead');

      expect(match!.collectionId, '5');
      expect(match.url, 'https://music.apple.com/us/album/5');
      expect(match.artworkUrl, contains('1500x1500bb.jpg'));
      expect(match.releaseDate, '1997-05-21');
      expect(match.trackCount, 12);
    });

    test('matches by containment when both base names are long', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['entity'] == 'musicArtist') {
          return _json({
            'resultCount': 1,
            'results': [_artistSearchResult(name: 'Radiohead', id: 657515)],
          });
        }
        return _json({
          'resultCount': 1,
          'results': [_collection(name: 'OK Computer OKNOTOK 1997 2017', id: 8)],
        });
      });

      final match = await serviceWith(
        client,
      ).resolveAlbum(album: 'OK Computer', artist: 'Radiohead');

      expect(match!.collectionId, '8');
    });

    test('returns null when no collection is close enough', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['entity'] == 'musicArtist') {
          return _json({
            'resultCount': 1,
            'results': [_artistSearchResult(name: 'Radiohead', id: 657515)],
          });
        }
        return _json({
          'resultCount': 1,
          'results': [_collection(name: 'Completely Different', id: 9)],
        });
      });

      expect(
        await serviceWith(
          client,
        ).resolveAlbum(album: 'Kid A', artist: 'Radiohead'),
        isNull,
      );
    });
  });

  group('getAlbumInfo', () {
    test('parses serialized server data paragraphs', () async {
      final client = MockClient(
        (request) async => _html(
          '<html><head></head><body>$_albumNotesHtml</body></html>',
        ),
      );

      final info = await serviceWith(client).getAlbumInfo(
        collectionId: '1097861387',
        collectionUrl: 'https://music.apple.com/us/album/ok-computer/1097861387',
      );

      expect(info!.notes, 'An album about alienation.\n\nRecorded in 1997.');
      expect(info.url, contains('us/album/ok-computer/1097861387'));
    });

    test('falls back to the us storefront when notes are missing', () async {
      final requested = <String>[];
      final client = MockClient((request) async {
        requested.add(request.url.toString());
        if (request.url.path.startsWith('/gb/')) {
          return _html('<html><body>no notes here</body></html>');
        }
        return _html('<html><body>$_albumNotesHtml</body></html>');
      });

      final info = await serviceWith(client).getAlbumInfo(
        collectionId: '1097861387',
        collectionUrl: 'https://music.apple.com/gb/album/ok-computer/1097861387',
        storefront: 'gb',
      );

      expect(info!.notes, isNotNull);
      expect(info.url, contains('/gb/album/'));
      expect(requested, hasLength(2));
      expect(requested.first, contains('/gb/album/'));
      expect(requested.last, contains('/us/album/'));
    });

    test('caches the no-notes outcome after a successful fetch', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _html('<html><body>nothing</body></html>');
      });

      final service = serviceWith(client);
      final first = await service.getAlbumInfo(
        collectionId: '1',
        collectionUrl: 'https://music.apple.com/us/album/x/1',
      );
      final second = await service.getAlbumInfo(
        collectionId: '1',
        collectionUrl: 'https://music.apple.com/us/album/x/1',
      );

      expect(first!.notes, isNull);
      expect(second!.notes, isNull);
      expect(calls, 1);
    });
  });

  group('getAlbumTracks', () {
    test('maps track numbers, discs and durations', () async {
      final client = MockClient(
        (request) async => _json({
          'resultCount': 2,
          'results': [
            _track(name: 'Airbag', number: 1, timeMs: 284000, id: 11),
            _track(name: 'Paranoid Android', number: 2, timeMs: 383000, id: 12),
          ],
        }),
      );

      final tracks = await serviceWith(client).getAlbumTracks('1097861387');

      expect(tracks, hasLength(2));
      expect(tracks.first.trackName, 'Airbag');
      expect(tracks.first.trackNumber, 1);
      expect(tracks.last.durationMs, 383000);
      expect(tracks.last.url, 'https://music.apple.com/us/song/12');
    });
  });

  group('artworkUrl', () {
    test('rewrites the square size token', () {
      expect(
        AppleMusicMetadataService.artworkUrl(
          'https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg',
          1500,
        ),
        'https://is1-ssl.mzstatic.com/image/thumb/x/1500x1500bb.jpg',
      );
      expect(
        AppleMusicMetadataService.artworkUrl(
          'https://is1-ssl.mzstatic.com/image/thumb/y/60x60bb.png',
          300,
        ),
        'https://is1-ssl.mzstatic.com/image/thumb/y/300x300bb.png',
      );
      expect(AppleMusicMetadataService.artworkUrl(null, 300), isNull);
      expect(AppleMusicMetadataService.artworkUrl('  ', 300), isNull);
    });
  });

  group('throttling', () {
    test('treats a 429 with Retry-After as transient', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _json({}, 429);
      });

      final service = serviceWith(client);
      expect(await service.resolveArtist('Radiohead'), isNull);
      expect(await service.resolveArtist('Radiohead'), isNull);
      expect(calls, 1);
    });
  });
}
