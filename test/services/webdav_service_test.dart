import 'dart:convert';
import 'dart:io';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/network_cache_service.dart';
import 'package:flick/services/sources/webdav_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

const _multistatus = '<?xml version="1.0"?>'
    '<D:multistatus xmlns:D="DAV:">'
    '<D:response>'
    '<D:href>/music/</D:href>'
    '<D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>'
    '</D:response>'
    '<D:response>'
    '<D:href>/music/Album%20One/</D:href>'
    '<D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat>'
    '</D:response>'
    '<D:response>'
    '<D:href>/music/song.flac</D:href>'
    '<D:propstat><D:prop><D:resourcetype/><D:getcontentlength>9876</D:getcontentlength></D:prop></D:propstat>'
    '</D:response>'
    '</D:multistatus>';

NetworkServerEntity _server({String? token}) {
  final entity = NetworkServerEntity()
    ..id = 5
    ..label = 'Dav'
    ..protocol = 'webdav'
    ..baseUrl = 'https://dav.example.com/music'
    ..username = 'alice'
    ..token = token;
  return entity;
}

void main() {
  group('auth', () {
    test('resolveToken stores base64(password)', () async {
      final client = MockClient((request) async => http.Response('', 200));
      final service = WebdavService.create(client: client);

      final token = await service.resolveToken(_server(), 'secret');

      expect(token, base64Encode(utf8.encode('secret')));
      expect(utf8.decode(base64Decode(token!)), 'secret');
    });

    test('ping sends HTTP Basic over PROPFIND and accepts 207', () async {
      late String capturedAuth;
      late String capturedDepth;
      late String capturedMethod;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'] ?? '';
        capturedDepth = request.headers['Depth'] ?? '';
        capturedMethod = request.method;
        return http.Response(_multistatus, 207);
      });
      final service = WebdavService.create(client: client);

      // token = base64('secret'); expected Basic = base64('alice:secret')
      final server = _server(token: base64Encode(utf8.encode('secret')));
      final ok = await service.ping(server);

      expect(ok, isTrue);
      expect(capturedMethod, 'PROPFIND');
      expect(capturedDepth, '0');
      expect(
        capturedAuth,
        'Basic ${base64Encode(utf8.encode('alice:secret'))}',
      );
    });
  });

  group('parse', () {
    test('multistatus splits collections from files and skips self', () {
      final entries =
          WebdavService.parseMultistatusForTest(_multistatus, '/music/');

      expect(entries, hasLength(2));
      expect(entries[0].href, '/music/Album One/');
      expect(entries[0].isCollection, isTrue);
      expect(entries[1].href, '/music/song.flac');
      expect(entries[1].isCollection, isFalse);
      expect(entries[1].size, 9876);
    });

    test('isAudioPath detects audio extensions', () {
      expect(WebdavService.isAudioPath('/a/b.flac'), isTrue);
      expect(WebdavService.isAudioPath('/a/b.mp3'), isTrue);
      expect(WebdavService.isAudioPath('/a/b.M4A'), isTrue);
      expect(WebdavService.isAudioPath('/a/cover.jpg'), isFalse);
      expect(WebdavService.isAudioPath('/a/notes.txt'), isFalse);
    });

    test('isCoverPath matches known cover stems with image extensions', () {
      expect(WebdavService.isCoverPath('/a/cover.jpg'), isTrue);
      expect(WebdavService.isCoverPath('/a/folder.png'), isTrue);
      expect(WebdavService.isCoverPath('/a/album.large.jpeg'), isTrue);
      // Image ext but not a cover stem.
      expect(WebdavService.isCoverPath('/a/track.jpg'), isFalse);
      // Cover stem but not an image ext.
      expect(WebdavService.isCoverPath('/a/cover.flac'), isFalse);
    });
  });

  // Regression for issue #255: hrefs were decoded twice. The second decode ran
  // during classification (outside the per-dir try/catch) and threw
  // `Invalid argument(s): Illegal percent encoding in URL` on the first
  // non-ASCII or literal-`%` file, aborting the whole sync.
  group('parse special characters (regression #255)', () {
    test('decodes non-ASCII, percent, hash and question mark hrefs', () {
      const body = '<?xml version="1.0"?>'
          '<D:multistatus xmlns:D="DAV:">'
          '<D:response><D:href>/music/</D:href>'
          '<D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat></D:response>'
          '<D:response><D:href>/music/%E7%85%A7%E4%BA%95%E9%A0%86%E6%94%BF%20-%20Delirious.flac</D:href>'
          '<D:propstat><D:prop><D:resourcetype/><D:getcontentlength>11</D:getcontentlength></D:prop></D:propstat></D:response>'
          '<D:response><D:href>/music/100%25%20Real.flac</D:href>'
          '<D:propstat><D:prop><D:resourcetype/></D:prop></D:propstat></D:response>'
          '<D:response><D:href>/music/Album%20%231/</D:href>'
          '<D:propstat><D:prop><D:resourcetype><D:collection/></D:resourcetype></D:prop></D:propstat></D:response>'
          '<D:response><D:href>/music/What%3F.flac</D:href>'
          '<D:propstat><D:prop><D:resourcetype/></D:prop></D:propstat></D:response>'
          '</D:multistatus>';

      final entries = WebdavService.parseMultistatusForTest(body, '/music/');

      expect(entries.map((e) => e.href), [
        '/music/照井順政 - Delirious.flac',
        '/music/100% Real.flac',
        '/music/Album #1/',
        '/music/What?.flac',
      ]);
    });

    test('tolerates raw non-conformant UTF-8 hrefs', () {
      const body = '<D:multistatus xmlns:D="DAV:">'
          '<D:response><D:href>/music/照井順政 - Delirious.flac</D:href>'
          '<D:propstat><D:prop><D:resourcetype/></D:prop></D:propstat></D:response>'
          '</D:multistatus>';

      final entries = WebdavService.parseMultistatusForTest(body, '/music/');

      expect(entries.single.href, '/music/照井順政 - Delirious.flac');
    });

    test('classification accepts already-decoded special names', () {
      expect(WebdavService.isAudioPath('/music/照井順政 - Delirious.flac'),
          isTrue);
      expect(WebdavService.isAudioPath('/music/100% Real.flac'), isTrue);
      expect(WebdavService.isAudioPath('/music/What?.flac'), isTrue);
      expect(WebdavService.isCoverPath('/music/Album #1/cover.jpg'), isTrue);
    });
  });

  group('request URLs', () {
    NetworkServerEntity server() => _server();

    test('streamDescriptor re-encodes without fragment/query corruption',
        () async {
      final service = WebdavService.create(
        client: MockClient((request) async => http.Response('', 200)),
      );
      final remoteId =
          Uri.encodeComponent('/music/Album #1/What?.flac');

      final descriptor = await service.streamDescriptor(server(), remoteId,
          extension: 'flac');

      final uri = Uri.parse(descriptor!.url);
      expect(uri.pathSegments.join('/'), 'music/Album #1/What?.flac');
      expect(uri.fragment, isEmpty);
      expect(uri.hasQuery, isFalse);
    });

    test('getCoverArt requests the re-encoded path', () async {
      late Uri captured;
      final service = WebdavService.create(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      final marker = base64Encode(utf8.encode('/music/Album #1/cover.jpg'));

      final bytes = await service.getCoverArt(server(), marker);

      expect(captured.pathSegments.join('/'), 'music/Album #1/cover.jpg');
      expect(captured.fragment, isEmpty);
      expect(captured.hasQuery, isFalse);
      expect(bytes, [1, 2, 3]);
    });

    test('stream downloads non-ASCII remoteId into the cache', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('webdav_stream_test');
      addTearDown(() => tempDir.delete(recursive: true));
      late Uri captured;
      final service = WebdavService.create(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response.bytes([9, 9], 200);
        }),
        networkCache: NetworkCacheService(
          rootDirectory: Directory(p.join(tempDir.path, 'cache')),
        ),
      );
      final remoteId =
          Uri.encodeComponent('/music/照井順政 - Delirious.flac');

      final path =
          await service.stream(server(), remoteId, extension: 'flac');

      expect(captured.pathSegments.join('/'), 'music/照井順政 - Delirious.flac');
      expect(await File(path).readAsBytes(), [9, 9]);
    });
  });
}
