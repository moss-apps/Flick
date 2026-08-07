import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/data/entities/song_entity.dart';
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

// Recorded-cassette responses. Two albums, three tracks, covering: per-song
// coverArt override, album-level coverArt fallback, and a hi-res DSF track.
Map<String, dynamic> _albumListResponse() => {
      'subsonic-response': {
        'status': 'ok',
        'albumList2': {
          'album': [
            {
              'id': 'al-1',
              'album': 'Nightshift',
              'artist': 'The Moths',
              'coverArt': 'al-1',
              'year': 2021,
            },
            {
              'id': 'al-2',
              'album': 'Drift',
              'artist': 'Solo',
              'coverArt': 'al-2',
              'year': 2023,
            },
          ],
        },
      },
    };

Map<String, dynamic> _albumResponse(String albumId) {
  if (albumId == 'al-1') {
    return {
      'subsonic-response': {
        'status': 'ok',
        'album': {
          'song': [
            {
              'id': 's-1',
              'title': 'Midnight',
              'artist': 'The Moths',
              'album': 'Nightshift',
              'albumArtist': 'The Moths',
              'track': 1,
              'duration': 245,
              'size': 12345678,
              'suffix': 'flac',
              'bitRate': 954,
              'sampleRate': 44100,
              'coverArt': 'al-1',
            },
            {
              'id': 's-2',
              'title': 'Dawn',
              'artist': 'The Moths',
              'track': 2,
              'duration': 200,
              'suffix': 'flac',
              'sampleRate': 96000,
            },
          ],
        },
      },
    };
  }
  return {
    'subsonic-response': {
      'status': 'ok',
      'album': {
        'song': [
          {
            'id': 's-3',
            'title': 'Drift',
            'artist': 'Solo',
            'duration': 300,
            'suffix': 'dsf',
            'sampleRate': 2822400,
          },
        ],
      },
    },
  };
}

void main() {
  test('scan traversal produces SongEntitys tagged subsonic with remoteId',
      () async {
    final albumListCalls = <Uri>[];
    final albumCalls = <String>[];
    final client = MockClient((request) async {
      final method = request.url.pathSegments.last;
      if (method == 'getAlbumList2.view') {
        albumListCalls.add(request.url);
        return http.Response(jsonEncode(_albumListResponse()), 200);
      }
      if (method == 'getAlbum.view') {
        albumCalls.add(request.url.queryParameters['id']!);
        return http.Response(
          jsonEncode(_albumResponse(request.url.queryParameters['id']!)),
          200,
        );
      }
      return http.Response('', 404);
    });
    final service = SubsonicService.create(client: client);
    final server = _server();

    // Drive the real scan traversal the same way syncLibrary does: album list,
    // then per-album songs, then map through the shared builder.
    final albums = await service.getAlbumList2(server);
    final songs = <SongEntity>[];
    for (final album in albums) {
      final rawSongs = await service.getAlbum(server, album['id'] as String);
      songs.addAll(rawSongs.map((s) => SubsonicService.buildSongEntity(
            server,
            s,
            albumName: album['album'] as String?,
            albumArtist: album['artist'] as String?,
            coverArt: album['coverArt'] as String?,
            year: (album['year'] as num?)?.toInt(),
          )));
    }

    // Traversal: one album-list page (short page stops pagination), two albums.
    expect(albumListCalls, hasLength(1));
    expect(albumCalls, ['al-1', 'al-2']);
    expect(songs, hasLength(3));

    // Every scanned song is tagged for the network source path.
    for (final s in songs) {
      expect(s.sourceType, 'subsonic');
      expect(s.remoteServerId, 7);
      expect(s.remoteId, isNotNull);
      expect(s.filePath, startsWith('subsonic://7/'));
      expect(s.metadataComplete, isTrue);
    }

    // Per-song coverArt wins; missing falls back to the album's coverArt.
    final s1 = songs.firstWhere((e) => e.remoteId == 's-1');
    expect(s1.title, 'Midnight');
    expect(s1.album, 'Nightshift');
    expect(s1.albumArtist, 'The Moths');
    expect(s1.durationMs, 245000);
    expect(s1.sampleRate, 44100);
    expect(s1.fileType, 'flac');
    expect(s1.bitrate, 954);
    expect(s1.trackNumber, 1);
    expect(s1.year, 2021);
    expect(s1.filePath, 'subsonic://7/s-1');
    expect(s1.albumArtPath, 'subsonic-cover://al-1');

    // s-2 has no own coverArt → album coverArt al-1 is inherited.
    final s2 = songs.firstWhere((e) => e.remoteId == 's-2');
    expect(s2.sampleRate, 96000);
    expect(s2.albumArtPath, 'subsonic-cover://al-1');

    // Hi-res DSF track from the second album inherits that album's metadata.
    final s3 = songs.firstWhere((e) => e.remoteId == 's-3');
    expect(s3.album, 'Drift');
    expect(s3.albumArtist, 'Solo');
    expect(s3.fileType, 'dsf');
    expect(s3.sampleRate, 2822400);
    expect(s3.year, 2023);
    expect(s3.albumArtPath, 'subsonic-cover://al-2');

    // Composite-key uniqueness: filePaths are distinct across albums.
    expect(songs.map((e) => e.filePath).toSet().length, songs.length);
  });
}
