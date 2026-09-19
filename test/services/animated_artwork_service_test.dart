import 'dart:convert';
import 'dart:io';

import 'package:flick/services/motion_art/animated_artwork_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

http.Response _motion(String id, String name, String artist) => _json({
  'name': name,
  'artist': artist,
  'albumId': id,
  'static': 'https://cdn.example/$id.jpg',
  'animated': 'https://cdn.example/$id.m3u8',
});

http.Response _staticOnly(String id, String name, String artist) => _json({
  'name': name,
  'artist': artist,
  'albumId': id,
  'static': 'https://cdn.example/$id.jpg',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('motion_art_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => cacheDir.path,
        );
  });

  tearDown(() async {
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  group('AnimatedArtworkService album resolution', () {
    test('recovers motion art from a track-name text result (DRIVE)', () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        final url = request.url;
        if (url.host == 'itunes.apple.com') {
          // The real album search returns nothing for "Tiësto DRIVE".
          return _json({'resultCount': 0, 'results': []});
        }
        if (url.host == 'artwork.boidu.dev') {
          final id = url.queryParameters['id'] ?? '';
          if (id.isEmpty) {
            // boidu's song search labels the right collection "All Nighter".
            return _json({
              'name': 'All Nighter',
              'artist': 'Tiësto',
              'albumId': '1652508659',
              'animated': 'https://cdn.example/drive.m3u8',
            });
          }
          if (id == '1652508659') {
            return _motion(id, 'DRIVE', 'Tiësto');
          }
        }
        return _json({'error': 'unexpected $url'}, 500);
      });

      final service = AnimatedArtworkService.create(client: client);
      final art = await service.getAnimatedArtworkForAlbum(
        albumName: 'DRIVE',
        artist: 'Tiësto',
        representativeSongTitle: '10:35',
      );

      expect(art, isNotNull);
      expect(art!.name, 'DRIVE');
      expect(art.albumId, '1652508659');
      expect(art.hasMotion, isTrue);

      final boidu = requests
          .where((u) => u.host == 'artwork.boidu.dev')
          .toList();
      expect(boidu.map((u) => u.queryParameters['s']), ['DRIVE', null]);
      expect(boidu.map((u) => u.queryParameters['id']), [null, '1652508659']);
    });

    test('probes song-search candidates until one has motion', () async {
      final boiduIds = <String?>[];
      final client = MockClient((request) async {
        final url = request.url;
        if (url.host == 'itunes.apple.com') {
          if (url.queryParameters['entity'] == 'song') {
            return _json({
              'resultCount': 2,
              'results': [
                {
                  'wrapperType': 'track',
                  'collectionId': 1690274141,
                  'collectionName': 'DRIVE',
                  'artistName': 'Tiësto & Tate McRae',
                  'trackName': '10:35',
                },
                {
                  'wrapperType': 'track',
                  'collectionId': 1652508659,
                  'collectionName': 'DRIVE',
                  'artistName': 'Tiësto',
                  'trackName': '10:35',
                },
              ],
            });
          }
          return _json({'resultCount': 0, 'results': []});
        }
        if (url.host == 'artwork.boidu.dev') {
          final id = url.queryParameters['id'];
          if (id != null) {
            boiduIds.add(id);
            // The edition the file's tags point at is static-only.
            return id == '1652508659'
                ? _motion(id, 'DRIVE', 'Tiësto')
                : _staticOnly(id, 'DRIVE', 'Tiësto');
          }
        }
        return _json({'error': 'unexpected $url'}, 500);
      });

      final service = AnimatedArtworkService.create(client: client);
      final art = await service.getAnimatedArtworkForAlbum(
        albumName: 'DRIVE',
        artist: 'Tiësto',
        representativeSongTitle: '10:35',
      );

      expect(boiduIds, ['1690274141', '1652508659']);
      expect(art, isNotNull);
      expect(art!.albumId, '1652508659');
    });

    test('stops at the first album-search candidate with motion', () async {
      final entities = <String?>[];
      final client = MockClient((request) async {
        final url = request.url;
        if (url.host == 'itunes.apple.com') {
          entities.add(url.queryParameters['entity']);
          return _json({
            'resultCount': 1,
            'results': [
              {
                'collectionId': 555,
                'collectionName': 'DRIVE',
                'artistName': 'Tiësto',
              },
            ],
          });
        }
        if (url.host == 'artwork.boidu.dev' &&
            url.queryParameters['id'] == '555') {
          return _motion('555', 'DRIVE', 'Tiësto');
        }
        return _json({'error': 'unexpected $url'}, 500);
      });

      final service = AnimatedArtworkService.create(client: client);
      final art = await service.getAnimatedArtworkForAlbum(
        albumName: 'DRIVE',
        artist: 'Tiësto',
        representativeSongTitle: '10:35',
      );

      expect(entities, ['album']);
      expect(art, isNotNull);
      expect(art!.albumId, '555');
    });

    test('rejects a text result whose canonical id is another album', () async {
      final client = MockClient((request) async {
        final url = request.url;
        if (url.host == 'itunes.apple.com') {
          return _json({'resultCount': 0, 'results': []});
        }
        if (url.host == 'artwork.boidu.dev') {
          final id = url.queryParameters['id'] ?? '';
          if (id == '777') {
            return _motion(id, 'Gamma', 'Someone');
          }
          // Track-name echo for an unrelated collection.
          return _json({
            'name': 'Beta Track',
            'artist': 'Someone',
            'albumId': '777',
            'animated': 'https://cdn.example/beta.m3u8',
          });
        }
        return _json({'error': 'unexpected $url'}, 500);
      });

      final service = AnimatedArtworkService.create(client: client);
      final art = await service.getAnimatedArtworkForAlbum(
        albumName: 'Alpha',
        artist: 'Someone',
      );

      expect(art, isNull);
    });

    test('retries the text search with the primary artist', () async {
      final textArtists = <String?>[];
      final boiduIds = <String?>[];
      final client = MockClient((request) async {
        final url = request.url;
        if (url.host == 'itunes.apple.com') {
          return _json({'resultCount': 0, 'results': []});
        }
        if (url.host == 'artwork.boidu.dev') {
          final id = url.queryParameters['id'];
          if (id == null) {
            final artist = url.queryParameters['a'];
            textArtists.add(artist);
            if (artist == 'Tiësto & Tate McRae') {
              // boidu matches the collab credit to Tate McRae's catalog.
              return _json({
                'name': 'greedy',
                'artist': 'Tate McRae',
                'albumId': '1716102849',
                'animated': 'https://cdn.example/greedy.m3u8',
              });
            }
            return _json({
              'name': 'All Nighter',
              'artist': 'Tiësto',
              'albumId': '1652508659',
              'animated': 'https://cdn.example/drive.m3u8',
            });
          }
          boiduIds.add(id);
          if (id == '1716102849') {
            return _motion(id, 'THINK LATER', 'Tate McRae');
          }
          if (id == '1652508659') {
            return _motion(id, 'DRIVE', 'Tiësto');
          }
        }
        return _json({'error': 'unexpected $url'}, 500);
      });

      final service = AnimatedArtworkService.create(client: client);
      final art = await service.getAnimatedArtworkForAlbum(
        albumName: 'DRIVE',
        artist: 'Tiësto & Tate McRae',
        representativeSongTitle: '10:35',
      );

      expect(textArtists, ['Tiësto & Tate McRae', 'Tiësto']);
      expect(boiduIds, ['1716102849', '1652508659']);
      expect(art, isNotNull);
      expect(art!.name, 'DRIVE');
      expect(art.albumId, '1652508659');
    });
  });
}
