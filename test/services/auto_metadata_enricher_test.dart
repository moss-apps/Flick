import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/apple_music/album_identification_service.dart';
import 'package:flick/services/apple_music/apple_music_cache.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';
import 'package:flick/services/apple_music/auto_metadata_enricher.dart';

http.Response _json(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Song _song(
  String name,
  int seconds, {
  String artist = 'Unknown Artist',
  String album = 'Unknown Album',
}) => Song(
  id: name,
  title: name,
  artist: artist,
  album: album,
  duration: Duration(seconds: seconds),
  fileType: 'WAV',
  filePath: '/storage/emulated/0/Music/Portishead/Dummy/$name.wav',
);

Map<String, dynamic> _collection(int id, String name) => {
  'wrapperType': 'collection',
  'collectionType': 'Album',
  'collectionName': name,
  'artistName': 'Portishead',
  'collectionId': id,
  'collectionViewUrl': 'https://music.apple.com/us/album/$id',
  'releaseDate': '1994-08-22T07:00:00Z',
  'primaryGenreName': 'Trip Hop',
  'trackCount': 2,
};

Map<String, dynamic> _track(String name, int seconds, int number) => {
  'wrapperType': 'track',
  'kind': 'song',
  'trackName': name,
  'artistName': 'Portishead',
  'collectionName': 'Dummy',
  'trackId': number,
  'trackNumber': number,
  'discNumber': 1,
  'trackTimeMillis': seconds * 1000,
};

class _RecordingRepository implements SongRepository {
  final List<String> updatedFiles = [];
  final Map<String, String> titles = {};

  @override
  Future<void> updateSongMetadata(
    String filePath, {
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    int? trackNumber,
    int? discNumber,
    int? year,
    String? genre,
  }) async {
    updatedFiles.add(filePath);
    if (title != null) titles[filePath] = title;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _RecordingRepository repository;

  AutoMetadataEnricher enricherWith(MockClient client) {
    final identification = AlbumIdentificationService.create(
      metadata: AppleMusicMetadataService.create(
        client: client,
        cache: AppleMusicCache.forDirectory(tempDir),
      ),
      repository: repository,
    );
    return AutoMetadataEnricher.create(identification: identification);
  }

  MockClient exactMatchClient({void Function()? onSearch}) =>
      MockClient((request) async {
        if (request.url.path == '/search') {
          onSearch?.call();
          return _json({
            'resultCount': 1,
            'results': [_collection(10, 'Dummy')],
          });
        }
        if (request.url.path == '/lookup') {
          return _json({
            'resultCount': 2,
            'results': [
              _track('Mysterons', 300, 1),
              _track('Sour Times', 240, 2),
            ],
          });
        }
        return _json({'resultCount': 0, 'results': []});
      });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'apple_music_auto_enrich': true});
    tempDir = await Directory.systemTemp.createTemp('apple_music_enricher_test');
    repository = _RecordingRepository();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('applies an exact seed match and updates every file', () async {
    final enricher = enricherWith(exactMatchClient());
    final summary = await enricher.enrichMissing([
      _song('01', 300),
      _song('02', 240),
    ]);

    expect(summary.groupsConsidered, 1);
    expect(summary.groupsApplied, 1);
    expect(summary.groupsQueued, 0);
    expect(summary.songsUpdated, 2);
    expect(repository.updatedFiles, hasLength(2));
    expect(repository.titles['/storage/emulated/0/Music/Portishead/Dummy/01.wav'], 'Mysterons');
    expect(repository.titles['/storage/emulated/0/Music/Portishead/Dummy/02.wav'], 'Sour Times');
  });

  test('queues ambiguous releases instead of applying them', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        return _json({
          'resultCount': 1,
          'results': [_collection(11, 'Dummy (Live)')],
        });
      }
      if (request.url.path == '/lookup') {
        return _json({
          'resultCount': 2,
          'results': [
            _track('Mysterons', 300, 1),
            _track('Sour Times', 240, 2),
          ],
        });
      }
      return _json({'resultCount': 0, 'results': []});
    });
    final enricher = enricherWith(client);
    final summary = await enricher.enrichMissing([_song('01', 300)]);

    expect(summary.groupsApplied, 0);
    expect(summary.groupsQueued, 1);
    expect(repository.updatedFiles, isEmpty);
  });

  test('skips folders whose tags are complete', () async {
    var searches = 0;
    final enricher = enricherWith(exactMatchClient(onSearch: () => searches++));
    final summary = await enricher.enrichMissing([
      _song('01', 300, artist: 'Portishead', album: 'Dummy'),
      _song('02', 240, artist: 'Portishead', album: 'Dummy'),
    ]);

    expect(summary.groupsConsidered, 0);
    expect(searches, 0);
    expect(repository.updatedFiles, isEmpty);
  });

  test('does nothing when the setting is off', () async {
    SharedPreferences.setMockInitialValues({'apple_music_auto_enrich': false});
    var searches = 0;
    final enricher = enricherWith(exactMatchClient(onSearch: () => searches++));
    final summary = await enricher.enrichMissing([_song('01', 300)]);

    expect(summary.groupsConsidered, 0);
    expect(searches, 0);
  });
}
