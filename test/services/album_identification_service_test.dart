import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flick/models/song.dart';
import 'package:flick/services/apple_music/album_identification_service.dart';
import 'package:flick/services/apple_music/apple_music_cache.dart';
import 'package:flick/services/apple_music/apple_music_metadata_service.dart';

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

Song _song(
  String name,
  int seconds, {
  String path = '/storage/emulated/0/Music/Portishead/Dummy',
  int? startOffsetMs,
}) => Song(
  id: name,
  title: name,
  artist: 'Unknown Artist',
  album: 'Unknown Album',
  duration: Duration(seconds: seconds),
  fileType: 'WAV',
  filePath: '$path/$name.wav',
  startOffsetMs: startOffsetMs,
);

Map<String, dynamic> _collection(String id, String name) => {
  'wrapperType': 'collection',
  'collectionType': 'Album',
  'collectionId': int.parse(id),
  'collectionName': name,
  'artistName': 'Portishead',
  'collectionViewUrl': 'https://music.apple.com/us/album/$id',
  'artworkUrl100': 'https://is1-ssl.mzstatic.com/image/thumb/x/100x100bb.jpg',
  'releaseDate': '1994-08-22T07:00:00Z',
  'primaryGenreName': 'Electronic',
  'trackCount': 11,
};

Map<String, dynamic> _track(String name, int seconds, int number) => {
  'wrapperType': 'track',
  'kind': 'song',
  'trackId': number,
  'trackName': name,
  'artistName': 'Portishead',
  'trackNumber': number,
  'discNumber': 1,
  'trackTimeMillis': seconds * 1000,
};

AlbumIdentificationService _service(
  MockClient client,
  Directory cacheDir,
) => AlbumIdentificationService.create(
  metadata: AppleMusicMetadataService.create(
    client: client,
    cache: AppleMusicCache.forDirectory(cacheDir),
  ),
);

void main() {
  late Directory cacheDir;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('apple_music_identify');
  });

  tearDown(() {
    if (cacheDir.existsSync()) {
      cacheDir.deleteSync(recursive: true);
    }
  });

  test('deriveFolderSeeds reads artist and album from parent folders', () {
    final seeds = AlbumIdentificationService.deriveFolderSeeds([
      _song('Mysterons', 240),
    ]);
    expect(seeds.artist, 'Portishead');
    expect(seeds.album, 'Dummy');
  });

  test('deriveFolderSeeds skips generic folder names', () {
    final seeds = AlbumIdentificationService.deriveFolderSeeds([
      _song('Track 01', 240, path: '/storage/emulated/0/Music'),
    ]);
    expect(seeds.artist, isEmpty);
    expect(seeds.album, isEmpty);
  });

  test('isUnknownName treats placeholders as missing', () {
    expect(AlbumIdentificationService.isUnknownName('Unknown Artist'), isTrue);
    expect(AlbumIdentificationService.isUnknownName('Unknown Album'), isTrue);
    expect(AlbumIdentificationService.isUnknownName(''), isTrue);
    expect(AlbumIdentificationService.isUnknownName('Portishead'), isFalse);
  });

  test('findCandidates ranks duration-matched release first', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        return _json({
          'resultCount': 2,
          'results': [
            _collection('11', 'Dummy (Live)'),
            _collection('10', 'Dummy'),
          ],
        });
      }
      if (request.url.path == '/lookup') {
        final id = request.url.queryParameters['id'];
        if (id == '10') {
          return _json({
            'resultCount': 2,
            'results': [
              _track('Mysterons', 240, 1),
              _track('Sour Times', 250, 2),
            ],
          });
        }
        return _json({
          'resultCount': 2,
          'results': [
            _track('Mysterons (Live)', 310, 1),
            _track('Sour Times (Live)', 330, 2),
          ],
        });
      }
      return _json({}, 404);
    });

    final service = _service(client, cacheDir);
    final songs = [_song('Mysterons', 240), _song('Sour Times', 250)];
    final candidates = await service.findCandidates(songs: songs);

    expect(candidates, isNotEmpty);
    final best = candidates.first;
    expect(best.match.collectionId, '10');
    expect(best.matchedCount, 2);
    expect(best.nameMatchCount, 2);
    expect(best.confidence, 1.0);
    expect(best.suggestions.first.track?.trackNumber, 1);
    expect(best.suggestions[1].track?.trackName, 'Sour Times');
  });

  test('findCandidates uses folder seeds when tags are placeholders', () async {
    final requestedTerms = <String>[];
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        requestedTerms.add(request.url.queryParameters['term'] ?? '');
        return _json({
          'resultCount': 1,
          'results': [_collection('10', 'Dummy')],
        });
      }
      if (request.url.path == '/lookup') {
        return _json({
          'resultCount': 1,
          'results': [_track('Mysterons', 240, 1)],
        });
      }
      return _json({}, 404);
    });

    final service = _service(client, cacheDir);
    final candidates = await service.findCandidates(
      songs: [_song('Mysterons', 240)],
      artist: 'Unknown Artist',
      album: 'Unknown Album',
    );

    expect(requestedTerms.single, 'Portishead Dummy');
    expect(candidates.single.match.name, 'Dummy');
  });

  test('findCandidates skips CUE tracks and reports no overflow', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/search') {
        return _json({
          'resultCount': 1,
          'results': [_collection('10', 'Dummy')],
        });
      }
      if (request.url.path == '/lookup') {
        return _json({
          'resultCount': 1,
          'results': [_track('Mysterons', 240, 1)],
        });
      }
      return _json({}, 404);
    });

    final service = _service(client, cacheDir);
    final candidates = await service.findCandidates(
      songs: [
        _song('Mysterons', 240),
        _song('Cue Track', 240, startOffsetMs: 12000),
      ],
    );

    expect(candidates.single.suggestions.length, 1);
    expect(candidates.single.matchedCount, 1);
    expect(candidates.single.confidence, 1.0);
  });

  test('findCandidates returns empty when the search fails', () async {
    final client = MockClient((request) async => _json({}, 500));
    final service = _service(client, cacheDir);

    final candidates = await service.findCandidates(
      songs: [_song('Mysterons', 240)],
    );
    expect(candidates, isEmpty);
  });
}
