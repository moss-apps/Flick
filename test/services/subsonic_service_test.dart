import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/subsonic_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NetworkServerEntity _server({String? token}) {
  final entity = NetworkServerEntity()
    ..id = 7
    ..label = 'Test'
    ..protocol = 'subsonic'
    ..baseUrl = 'https://music.example.com/subsonic'
    ..username = 'demo'
    ..token = token;
  return entity;
}

void main() {
  group('auth', () {
    test('buildToken matches the spec known-answer vector', () {
      // subsonic.org: password "sesame", salt "c19b2d"
      // t = md5(password + salt) = md5("sesamec19b2d")
      expect(
        SubsonicService.buildToken('sesame', salt: 'c19b2d'),
        'c19b2d:26719a1196d2a940705a59634eb18eab',
      );
    });

    test('request carries u/t/s/v/c/f params', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({'subsonic-response': {'status': 'ok'}}),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      final ok = await service.ping(_server(
        token: 'c19b2d:26719a1196d2a940705a59634eb18eab',
      ));

      expect(ok, isTrue);
      expect(captured.path, '/subsonic/rest/ping.view');
      expect(captured.queryParameters['u'], 'demo');
      expect(captured.queryParameters['t'], '26719a1196d2a940705a59634eb18eab');
      expect(captured.queryParameters['s'], 'c19b2d');
      expect(captured.queryParameters['v'], isNotEmpty);
      expect(captured.queryParameters['c'], 'flick');
      expect(captured.queryParameters['f'], 'json');
    });

    test('ping returns false on error status', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'failed',
              'error': {'code': 40, 'message': 'Wrong username or password'},
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      expect(
        await service.ping(_server(token: 'c19b2d:26719a1196d2a940705a59634eb18eab')),
        isFalse,
      );
    });
  });

  group('library', () {
    test('getAlbum maps song fields to an entity', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'album': {
                'song': [
                  {
                    'id': 'song-42',
                    'title': 'Midnight',
                    'artist': 'The Moths',
                    'album': 'Nightshift',
                    'albumArtist': 'The Moths',
                    'track': 3,
                    'duration': 245,
                    'size': 12345678,
                    'suffix': 'flac',
                    'bitRate': 954,
                    'sampleRate': 44100,
                    'coverArt': 'al-9',
                  },
                ],
              },
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      final songs = await service.getAlbum(_server(
        token: 'c19b2d:26719a1196d2a940705a59634eb18eab',
      ), 'al-9');

      expect(songs, hasLength(1));
      final song = songs.first;
      expect(song['id'], 'song-42');
      expect(song['title'], 'Midnight');
      expect(song['duration'], 245);
      expect(song['suffix'], 'flac');
    });

    test('getAlbumList2 paginates until a short page', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final offset = int.parse(request.url.queryParameters['offset']!);
        final count = offset == 0 ? 500 : 2;
        final albums = List.generate(count, (i) {
          final n = offset + i;
          return {'id': 'al-$n', 'album': 'Album $n', 'artist': 'Artist $n'};
        });
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'albumList2': {'album': albums},
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      final albums = await service.getAlbumList2(_server(
        token: 'c19b2d:26719a1196d2a940705a59634eb18eab',
      ));

      expect(calls, 2);
      expect(albums, hasLength(502));
      expect(albums.last['id'], 'al-501');
    });

    test('getAlbum tolerates double-valued numeric fields', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'album': {
                'song': [
                  {
                    'id': 'song-99',
                    'title': 'Drift',
                    'duration': 245.0,
                    'track': 7.0,
                    'size': 9999999.0,
                    'suffix': 'flac',
                    'bitRate': 954.0,
                    'sampleRate': 44100.0,
                  },
                ],
              },
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      // No throw — doubles are accepted and mapped to ints downstream.
      final songs = await service.getAlbum(_server(
        token: 'c19b2d:26719a1196d2a940705a59634eb18eab',
      ), 'al-1');

      expect(songs, hasLength(1));
      expect(songs.first['duration'], 245.0);
    });
  });
}
