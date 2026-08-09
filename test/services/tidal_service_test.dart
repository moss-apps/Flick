import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/tidal_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NetworkServerEntity _server({String? token}) {
  return NetworkServerEntity()
    ..id = 9
    ..label = 'Tidal'
    ..protocol = 'tidal'
    ..baseUrl = TidalService.tidalBaseUrl
    ..username = null
    ..token = token;
}

/// A far-future token blob so [TidalService._ensureValidToken] skips refresh
/// (and therefore skips the DB write inside [_persist]).
String _validToken() => jsonEncode({
      'access_token': 'acc-xyz',
      'refresh_token': 'ref-xyz',
      'user_id': 'user-1',
      'country_code': 'NO',
      'expires_at_ms':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    });

void main() {
  group('buildSongEntity', () {
    test('maps a Tidal track to a SongEntity with tidal:// path + cover marker',
        () {
      final server = _server();
      final track = {
        'id': 1234567,
        'title': 'Nightcall',
        'duration': 250,
        'trackNumber': 1,
        'volumeNumber': 1,
        'artists': [
          {'name': 'Kavinsky'}
        ],
        'album': {
          'title': 'OutRun',
          'releaseDate': '2013-02-25',
          'cover': '1bce0bf4-a3b9-4c0a-9f2e-1234567890ab',
          'artist': {'name': 'Kavinsky'},
        },
        'audioQuality': 'LOSSLESS',
      };

      final entity = TidalService.buildSongEntity(server, track);

      expect(entity, isNotNull);
      expect(entity!.filePath, 'tidal://9/1234567');
      expect(entity.title, 'Nightcall');
      expect(entity.artist, 'Kavinsky');
      expect(entity.album, 'OutRun');
      expect(entity.albumArtist, 'Kavinsky');
      expect(entity.durationMs, 250000); // seconds -> milliseconds
      expect(entity.trackNumber, 1);
      expect(entity.discNumber, 1);
      expect(entity.year, 2013);
      expect(entity.fileType, 'flac');
      expect(entity.albumArtPath, 'tidal-cover://1bce0bf4-a3b9-4c0a-9f2e-1234567890ab');
      expect(entity.sourceType, 'tidal');
      expect(entity.remoteId, '1234567');
      expect(entity.remoteServerId, 9);
    });

    test('returns null when the track has no id', () {
      expect(TidalService.buildSongEntity(_server(), {'title': 'x'}), isNull);
    });
  });

  group('coverUrl', () {
    test('slashes the hyphen-stripped uuid into a resources.tidal.com jpg', () {
      final url = TidalService.coverUrl('1bce0bf4-a3b9-4c0a', size: 640);
      expect(
        url,
        'https://resources.tidal.com/images/1b/ce/0bf4a3b94c0a/640x640.jpg',
      );
    });

    test('returns empty for a too-short id', () {
      expect(TidalService.coverUrl('ab'), '');
    });
  });

  group('extFromMime', () {
    test('maps flac / m4a / mp3', () {
      expect(TidalService.extFromMime('audio/flac'), 'flac');
      expect(TidalService.extFromMime('audio/mp4'), 'm4a');
      expect(TidalService.extFromMime('audio/mpeg'), 'mp3');
      expect(TidalService.extFromMime('audio/atmos'), isNull);
    });
  });

  group('resolveToken (device flow)', () {
    test('posts device_authorization, opens browser, polls until access_token',
        () async {
      var tokenCalls = 0;
      Uri? openedUrl;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/device_authorization')) {
          return http.Response(
            jsonEncode({
              'deviceCode': 'dev-1',
              'userCode': 'AB12CD',
              'verificationUriComplete':
                  'https://tidal.com/activate?code=AB12CD',
              'interval': 0,
              'expiresIn': 60,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/sessions')) {
          return http.Response(
            jsonEncode({'userId': 'user-1', 'countryCode': 'NO'}),
            200,
          );
        }
        if (request.url.path.endsWith('/token')) {
          tokenCalls++;
          if (tokenCalls == 1) {
            // Still waiting for the user to authorize.
            return http.Response(
              jsonEncode({'error': 'authorization_pending'}),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'access_token': 'acc-1',
              'refresh_token': 'ref-1',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('', 404);
      });

      final service = TidalService.create(
        client: client,
        urlOpener: (url) async {
          openedUrl = url;
          return true;
        },
      );

      final token = await service.resolveToken(_server(), '');

      expect(token, isNotNull);
      final decoded = jsonDecode(token!) as Map<String, dynamic>;
      expect(decoded['access_token'], 'acc-1');
      expect(decoded['refresh_token'], 'ref-1');
      expect(decoded['user_id'], 'user-1');
      expect(openedUrl?.toString(),
          'https://tidal.com/activate?code=AB12CD');
      expect(tokenCalls, 2);
    });

    test('throws when the browser cannot open', () async {
      final client = MockClient((request) async => http.Response(
          jsonEncode({
            'deviceCode': 'dev-1',
            'verificationUriComplete': 'https://tidal.com/activate',
            'interval': 0,
            'expiresIn': 60,
          }),
          200));
      final service = TidalService.create(
        client: client,
        urlOpener: (_) async => false,
      );
      expect(
        () => service.resolveToken(_server(), ''),
        throwsA(isA<TidalException>()),
      );
    });

    test('catches a launcher exception and surfaces the link (not the crash)',
        () async {
      final client = MockClient((request) async => http.Response(
          jsonEncode({
            'deviceCode': 'dev-1',
            'verificationUriComplete': 'https://link.tidal.com/AB12CD',
            'interval': 0,
            'expiresIn': 60,
          }),
          200));
      // The launcher throws (e.g. Android ACTIVITY_NOT_FOUND PlatformException).
      final service = TidalService.create(
        client: client,
        urlOpener: (_) async => throw Exception('ACTIVITY_NOT_FOUND'),
      );

      String? message;
      try {
        await service.resolveToken(_server(), '');
      } on TidalException catch (e) {
        message = e.message;
      }

      expect(message, isNotNull);
      expect(message, contains('https://link.tidal.com/AB12CD'));
      expect(message!.contains('ACTIVITY_NOT_FOUND'), isFalse);
    });

    test('signIn keeps polling after launch failure and reports the link',
        () async {
      var tokenCalls = 0;
      String? reportedLink;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/device_authorization')) {
          return http.Response(
            jsonEncode({
              'deviceCode': 'dev-1',
              'verificationUriComplete': 'https://link.tidal.com/ZZ',
              'interval': 0,
              'expiresIn': 60,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/sessions')) {
          return http.Response(
            jsonEncode({'userId': 'u', 'countryCode': 'US'}),
            200,
          );
        }
        if (request.url.path.endsWith('/token')) {
          tokenCalls++;
          if (tokenCalls == 1) {
            return http.Response(
              jsonEncode({'error': 'authorization_pending'}),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'access_token': 'a',
              'refresh_token': 'r',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('', 404);
      });
      final service = TidalService.create(
        client: client,
        urlOpener: (_) async => throw Exception('ACTIVITY_NOT_FOUND'),
      );

      final token = await service.signIn(
        onVerificationLink: (uri) => reportedLink = uri,
      );

      expect(reportedLink, 'https://link.tidal.com/ZZ');
      expect(tokenCalls, 2); // one pending, then success
      final decoded = jsonDecode(token!) as Map<String, dynamic>;
      expect(decoded['access_token'], 'a');
    });

    test('shows a friendly error (no raw body/URL) on invalid_client', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/device_authorization')) {
          return http.Response(
            jsonEncode({
              'error': 'invalid_client',
              'error_description': 'Invalid client id',
            }),
            401,
          );
        }
        return http.Response('', 404);
      });
      final service = TidalService.create(
        client: client,
        urlOpener: (_) async => true,
      );

      String? message;
      try {
        await service.resolveToken(_server(), '');
      } on TidalException catch (e) {
        message = e.message;
      }

      expect(message, isNotNull);
      expect(message, contains('rejected'));
      // The raw OAuth error code + endpoint must NOT leak into the UI message.
      expect(message!.contains('invalid_client'), isFalse);
      expect(message.contains('POST http'), isFalse);
      expect(message.contains('auth.tidal.com'), isFalse);
    });
  });

  group('streamDescriptor', () {
    test('decodes a NONE-encryption bts manifest to the CDN url', () async {
      final manifest = base64Encode(utf8.encode(jsonEncode({
        'mimeType': 'audio/flac',
        'codecs': 'flac',
        'encryptionType': 'NONE',
        'urls': ['https://cdn.tidal.com/track/flac/abc'],
      })));
      final client = MockClient((request) async {
        expect(request.url.path, contains('/playbackinfopostpaywall'));
        expect(
          request.headers['Authorization'],
          'Bearer acc-xyz',
        );
        return http.Response(
          jsonEncode({
            'manifest': manifest,
            'manifestMimeType': 'application/vnd.tidal.bts',
            'assetPresentation': 'FULL',
          }),
          200,
        );
      });
      final service = TidalService.create(client: client);

      final desc = await service.streamDescriptor(
        _server(token: _validToken()),
        '1234567',
      );

      expect(desc, isNotNull);
      expect(desc!.url, 'https://cdn.tidal.com/track/flac/abc');
      expect(desc.headers, isEmpty);
    });

    test('throws a clear error for encrypted (MQA/HiRes) content', () async {
      final manifest = base64Encode(utf8.encode(jsonEncode({
        'mimeType': 'audio/flac',
        'encryptionType': 'OLD',
        'keyId': 'k1',
        'urls': ['https://cdn.tidal.com/enc'],
      })));
      final client = MockClient((request) async => http.Response(
          jsonEncode({
            'manifest': manifest,
            'manifestMimeType': 'application/vnd.tidal.bts',
          }),
          200));
      final service = TidalService.create(client: client);

      expect(
        () => service.streamDescriptor(_server(token: _validToken()), '1'),
        throwsA(isA<TidalException>()),
      );
    });
  });

  group('ping', () {
    test('returns false when no token is stored', () async {
      final service =
          TidalService.create(client: MockClient((_) async => http.Response('{}', 200)));
      expect(await service.ping(_server(token: null)), isFalse);
    });
  });
}
