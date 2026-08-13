import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/subsonic_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NetworkServerEntity _server() => NetworkServerEntity()
  ..id = 7
  ..label = 'Test'
  ..protocol = 'subsonic'
  ..baseUrl = 'https://music.example.com/subsonic'
  ..username = 'demo'
  ..token = 'c19b2d:26719a1196d2a940705a59634eb18eab';

void main() {
  group('playlist endpoints', () {
    test('getPlaylists parses summaries', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'playlists': {
                'playlist': [
                  {'id': 'pl-1', 'name': 'Driving', 'songCount': 3},
                  {'id': 'pl-2', 'name': 'Focus'},
                ],
              },
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      final playlists = await service.getPlaylists(_server());

      expect(playlists, hasLength(2));
      expect(playlists.first['id'], 'pl-1');
      expect(playlists.first['name'], 'Driving');
    });

    test('getPlaylist returns full song entries', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'playlist': {
                'id': 'pl-1',
                'name': 'Driving',
                'entry': [
                  {'id': 's-1', 'title': 'Midnight', 'artist': 'The Moths'},
                  {'id': 's-2', 'title': 'Dawn', 'artist': 'The Moths'},
                ],
              },
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      final entries = await service.getPlaylist(_server(), 'pl-1');

      expect(captured.path, '/subsonic/rest/getPlaylist.view');
      expect(captured.queryParameters['id'], 'pl-1');
      expect(entries, hasLength(2));
      expect(entries![1]['title'], 'Dawn');
    });

    test('createPlaylist sends name only when creating', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'playlist': {'id': 'pl-9', 'name': 'Fresh'},
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      final created =
          await service.createPlaylist(_server(), name: 'Fresh');

      expect(captured.path, '/subsonic/rest/createPlaylist.view');
      expect(captured.queryParameters['name'], 'Fresh');
      expect(captured.queryParameters.containsKey('playlistId'), isFalse);
      expect(created!['id'], 'pl-9');
    });

    test('createPlaylist full-replace sends repeated songId params', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'subsonic-response': {
              'status': 'ok',
              'playlist': {'id': 'pl-9', 'name': 'Fresh'},
            },
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      await service.createPlaylist(
        _server(),
        playlistId: 'pl-9',
        name: 'Fresh',
        songIds: ['s-1', 's-2', 's-3'],
      );

      expect(captured.queryParameters['playlistId'], 'pl-9');
      expect(captured.queryParametersAll['songId'], ['s-1', 's-2', 's-3']);
    });

    test('updatePlaylist sends playlistId, name and repeated song params',
        () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'subsonic-response': {'status': 'ok'},
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      await service.updatePlaylist(
        _server(),
        'pl-9',
        name: 'Renamed',
        songIdsToAdd: ['s-1', 's-2'],
        songIdsToRemove: ['s-3'],
      );

      expect(captured.path, '/subsonic/rest/updatePlaylist.view');
      expect(captured.queryParameters['playlistId'], 'pl-9');
      expect(captured.queryParameters['name'], 'Renamed');
      expect(captured.queryParametersAll['songIdToAdd'], ['s-1', 's-2']);
      expect(captured.queryParametersAll['songIdToRemove'], ['s-3']);
    });

    test('deletePlaylist sends the playlist id', () async {
      late Uri captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          jsonEncode({
            'subsonic-response': {'status': 'ok'},
          }),
          200,
        );
      });
      final service = SubsonicService.create(client: client);

      await service.deletePlaylist(_server(), 'pl-9');

      expect(captured.path, '/subsonic/rest/deletePlaylist.view');
      expect(captured.queryParameters['id'], 'pl-9');
    });
  });

  group('resolvePlaylistSongIds', () {
    test('maps entries to local ids, skipping unresolvable ones', () {
      final resolved = SubsonicService.resolvePlaylistSongIds(
        [
          (
            remoteId: 'pl-1',
            name: 'A',
            entries: [
              {'id': 's-1'},
              {'id': 's-2'},
              {'id': 's-missing'},
              {'title': 'no id'},
            ],
          ),
          (
            remoteId: 'pl-2',
            name: 'B',
            entries: [
              {'id': 's-3'},
            ],
          ),
        ],
        {'s-1': '11', 's-3': '33'},
      );

      expect(resolved['pl-1'], ['11']);
      expect(resolved['pl-2'], ['33']);
    });

    test('empty playlist produces empty list', () {
      final resolved = SubsonicService.resolvePlaylistSongIds(
        [(remoteId: 'pl-1', name: 'A', entries: const [])],
        {},
      );

      expect(resolved, {'pl-1': const <String>[]});
    });
  });
}
