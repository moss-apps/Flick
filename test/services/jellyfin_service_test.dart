import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/jellyfin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

NetworkServerEntity _server({String? token}) {
  final entity = NetworkServerEntity()
    ..id = 3
    ..label = 'Jf'
    ..protocol = 'jellyfin'
    ..baseUrl = 'https://jf.example.com'
    ..username = 'demo'
    ..token = token;
  return entity;
}

void main() {
  group('auth', () {
    test('resolveToken posts AuthenticateByName and stores JSON credentials',
        () async {
      late String capturedBody;
      late Map<String, String> capturedHeaders;
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedBody = request.body;
        capturedHeaders = request.headers;
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'User': {'Id': 'user-1', 'Name': 'demo'},
            'AccessToken': 'tok-xyz',
          }),
          200,
        );
      });
      final service = JellyfinService.create(client: client);

      final token = await service.resolveToken(_server(), 'hunter2');

      expect(token, isNotNull);
      final decoded = jsonDecode(token!) as Map<String, dynamic>;
      expect(decoded['userId'], 'user-1');
      expect(decoded['token'], 'tok-xyz');

      expect(capturedUri.path, '/Users/AuthenticateByName');
      expect(capturedUri.toString(), startsWith('https://jf.example.com'));
      final sent = jsonDecode(capturedBody) as Map<String, dynamic>;
      expect(sent['Username'], 'demo');
      expect(sent['Pw'], 'hunter2');
      final auth = capturedHeaders['Authorization']!;
      expect(auth, contains('MediaBrowser'));
      expect(auth, contains('Client="flick"'));
      // The auth-exchange request must NOT carry an access token.
      expect(auth, isNot(contains('Token=')));
    });

    test('ping sends stored access token and returns true on 200', () async {
      late String capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'] ?? '';
        expect(request.url.path, '/system/Info');
        return http.Response('{}', 200);
      });
      final service = JellyfinService.create(client: client);

      final ok = await service.ping(_server(
        token: jsonEncode({'userId': 'user-1', 'token': 'tok-xyz'}),
      ));

      expect(ok, isTrue);
      expect(capturedAuth, contains('Token="tok-xyz"'));
    });

    test('ping returns false when no token is stored', () async {
      final client = MockClient((request) async => http.Response('{}', 200));
      final service = JellyfinService.create(client: client);
      expect(await service.ping(_server(token: null)), isFalse);
    });
  });
}
