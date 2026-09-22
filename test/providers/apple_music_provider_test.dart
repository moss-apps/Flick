import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flick/providers/apple_music_provider.dart';
import 'package:flick/services/apple_music/apple_music_cache.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _artistResult() => {
  'wrapperType': 'artist',
  'artistType': 'Artist',
  'artistName': 'Portishead',
  'artistLinkUrl': 'https://music.apple.com/us/artist/portishead/1?uo=4',
  'artistId': 1,
  'primaryGenreName': 'Electronic',
};

Map<String, dynamic> _trackResult(String name) => {
  'wrapperType': 'track',
  'kind': 'song',
  'trackName': name,
  'artistName': 'Portishead',
  'collectionName': 'Dummy',
  'trackId': 1,
  'trackTimeMillis': 240000,
};

Map<String, dynamic> _albumResult() => {
  'wrapperType': 'collection',
  'collectionType': 'Album',
  'collectionName': 'Dummy',
  'artistName': 'Portishead',
  'collectionId': 10,
  'collectionViewUrl': 'https://music.apple.com/us/album/10?uo=4&app=music',
  'artworkUrl100': 'https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg',
  'releaseDate': '1994-08-22T07:00:00Z',
  'primaryGenreName': 'Electronic',
  'trackCount': 11,
};

const _albumNotesHtml =
    '<script id="serialized-server-data">{"data":[{"data":{"sections":[{"items":[{"modalPresentationDescriptor":{"paragraphText":"A trip hop landmark."}}]}]}}]}</script>';

void main() {
  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('apple_music_provider_');
  });

  tearDown(() async {
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  ProviderContainer containerWith(MockClient client) {
    final service = AppleMusicMetadataService.create(
      client: client,
      cache: AppleMusicCache.forDirectory(cacheDir),
    );
    return ProviderContainer(
      overrides: [
        appleMusicMetadataServiceProvider.overrideWithValue(service),
      ],
    );
  }

  test('build loads artist and top songs', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        return _json({
          'resultCount': 1,
          'results': [_artistResult()],
        });
      }
      if (request.url.path == '/lookup') {
        return _json({
          'resultCount': 1,
          'results': [_trackResult('Glory Box')],
        });
      }
      return _json({}, 404);
    });
    final container = containerWith(client);
    addTearDown(container.dispose);

    final provider = appleMusicArtistProvider('Portishead');
    final sub = container.listen(provider, (_, __) {});
    addTearDown(sub.close);

    final data = await container.read(provider.future);
    expect(data?.artist.artistId, '1');
    expect(data?.topSongs.single.trackName, 'Glory Box');
  });

  test('refresh bypasses the cache and updates the value', () async {
    var searchCalls = 0;
    var trackName = 'Glory Box';
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        searchCalls++;
        return _json({
          'resultCount': 1,
          'results': [_artistResult()],
        });
      }
      if (request.url.path == '/lookup') {
        return _json({
          'resultCount': 1,
          'results': [_trackResult(trackName)],
        });
      }
      return _json({}, 404);
    });
    final container = containerWith(client);
    addTearDown(container.dispose);

    final provider = appleMusicArtistProvider('Portishead');
    final sub = container.listen(provider, (_, __) {});
    addTearDown(sub.close);

    await container.read(provider.future);
    expect(searchCalls, 1);

    trackName = 'Sour Times';
    await container.read(provider.notifier).refresh();

    expect(searchCalls, 2);
    expect(
      container.read(provider).value?.topSongs.single.trackName,
      'Sour Times',
    );

    await container.read(provider.future);
    expect(searchCalls, 2);
  });

  test('refresh failure keeps the previous value', () async {
    var fail = false;
    final client = MockClient((request) async {
      if (fail) return _json({}, 500);
      if (request.url.path == '/search') {
        return _json({
          'resultCount': 1,
          'results': [_artistResult()],
        });
      }
      if (request.url.path == '/lookup') {
        return _json({
          'resultCount': 1,
          'results': [_trackResult('Glory Box')],
        });
      }
      return _json({}, 404);
    });
    final container = containerWith(client);
    addTearDown(container.dispose);

    final provider = appleMusicArtistProvider('Portishead');
    final sub = container.listen(provider, (_, __) {});
    addTearDown(sub.close);

    await container.read(provider.future);

    fail = true;
    final updated = await container.read(provider.notifier).refresh();

    expect(updated, isFalse);
    expect(container.read(provider).hasError, isFalse);
    expect(
      container.read(provider).value?.topSongs.single.trackName,
      'Glory Box',
    );
  });

  test('album build resolves match, notes and tracks', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        return _json({
          'resultCount': 1,
          'results': [_artistResult()],
        });
      }
      if (request.url.path == '/lookup') {
        final entity = request.url.queryParameters['entity'];
        if (entity == 'album') {
          return _json({
            'resultCount': 1,
            'results': [_albumResult()],
          });
        }
        return _json({
          'resultCount': 1,
          'results': [_trackResult('Mysterons')],
        });
      }
      if (request.url.host == 'music.apple.com') {
        return http.Response(
          _albumNotesHtml,
          200,
          headers: {'content-type': 'text/html'},
        );
      }
      return _json({}, 404);
    });
    final container = containerWith(client);
    addTearDown(container.dispose);

    final provider = appleMusicAlbumProvider(('Dummy', 'Portishead'));
    final sub = container.listen(provider, (_, __) {});
    addTearDown(sub.close);

    final data = await container.read(provider.future);
    expect(data?.match.collectionId, '10');
    expect(data?.notes, 'A trip hop landmark.');
    expect(data?.tracks.single.trackName, 'Mysterons');
  });
}
