import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/webdav_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}
