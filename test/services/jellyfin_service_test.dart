import 'dart:convert';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/jellyfin_password_store.dart';
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

class _FakePasswordStore extends JellyfinPasswordStore {
  _FakePasswordStore(this.passwords);

  final Map<int, String> passwords;

  @override
  Future<String?> read(int serverId) async => passwords[serverId];

  @override
  Future<void> write(int serverId, String password) async {
    passwords[serverId] = password;
  }

  @override
  Future<void> delete(int serverId) async {
    passwords.remove(serverId);
  }
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

  group('re-auth on 401', () {
    test('ping exchanges stored password for a fresh token and retries',
        () async {
      final calls = <String>[];
      final persisted = <String>[];
      final client = MockClient((request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          calls.add('auth:${request.body}');
          return http.Response(
            jsonEncode({
              'User': {'Id': 'user-1'},
              'AccessToken': 'tok-fresh',
            }),
            200,
          );
        }
        final token = request.headers['Authorization'] ?? '';
        if (token.contains('tok-dead')) {
          calls.add('info:dead');
          return http.Response('', 401);
        }
        calls.add('info:fresh');
        return http.Response('{}', 200);
      });
      final server = _server(
        token: jsonEncode({'userId': 'user-1', 'token': 'tok-dead'}),
      );
      final store = _FakePasswordStore({3: 'hunter2'});
      final service = JellyfinService.create(
        client: client,
        passwordStore: store,
        persistToken: (s, token) async => persisted.add(token),
      );

      final ok = await service.ping(server);

      expect(ok, isTrue);
      expect(calls, ['info:dead', 'auth:{"Username":"demo","Pw":"hunter2"}', 'info:fresh']);
      expect(persisted, hasLength(1));
      final decoded = jsonDecode(persisted.single) as Map<String, dynamic>;
      expect(decoded['token'], 'tok-fresh');
      // In-memory entity carries the fresh token so the sync keeps going.
      expect(server.token, persisted.single);
    });

    test('ping stays false on 401 when no password is stored', () async {
      var infoCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          fail('must not attempt re-auth without a stored password');
        }
        infoCalls++;
        return http.Response('', 401);
      });
      final service = JellyfinService.create(
        client: client,
        passwordStore: _FakePasswordStore({}),
      );

      final ok = await service.ping(_server(
        token: jsonEncode({'userId': 'user-1', 'token': 'tok-dead'}),
      ));

      expect(ok, isFalse);
      expect(infoCalls, 1);
    });

    test('ping stays false when the password exchange is rejected', () async {
      var infoCalls = 0;
      var authCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          authCalls++;
          return http.Response('', 401);
        }
        infoCalls++;
        return http.Response('', 401);
      });
      final service = JellyfinService.create(
        client: client,
        passwordStore: _FakePasswordStore({3: 'wrong-pass'}),
      );

      final ok = await service.ping(_server(
        token: jsonEncode({'userId': 'user-1', 'token': 'tok-dead'}),
      ));

      expect(ok, isFalse);
      // One dead-token call, one rejected exchange, no retry after failure.
      expect(infoCalls, 1);
      expect(authCalls, 1);
    });
  });

  group('password store', () {
    test('persistPassword writes and forgetPassword deletes', () async {
      final store = _FakePasswordStore({});
      final service = JellyfinService.create(passwordStore: store);

      await service.persistPassword(_server(), 'hunter2');
      expect(store.passwords[3], 'hunter2');

      await service.forgetPassword(3);
      expect(store.passwords, isEmpty);
    });
  });
}
