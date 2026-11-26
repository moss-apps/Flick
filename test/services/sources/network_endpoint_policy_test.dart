import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/network_credential_store.dart';
import 'package:flick/services/sources/network_endpoint_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

NetworkServerEntity _server({
  String baseUrl = 'https://music.example.com',
  bool allowInsecureHttp = false,
}) {
  return NetworkServerEntity()
    ..id = 1
    ..label = 'Home'
    ..protocol = 'jellyfin'
    ..baseUrl = baseUrl
    ..username = 'demo'
    ..allowInsecureHttp = allowInsecureHttp;
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient({this.body = const Stream<List<int>>.empty()});

  final Stream<List<int>> body;
  http.BaseRequest? captured;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    captured = request;
    return http.StreamedResponse(body, 204);
  }
}

void main() {
  group('requireAllowed', () {
    test('accepts HTTPS', () {
      final uri = NetworkEndpointPolicy.requireAllowed(_server());
      expect(uri.scheme, 'https');
    });

    test('rejects plain HTTP by default', () {
      expect(
        () => NetworkEndpointPolicy.requireAllowed(
          _server(baseUrl: 'http://music.example.com'),
        ),
        throwsA(
          isA<NetworkCredentialException>().having(
            (e) => e.message,
            'message',
            contains('unencrypted HTTP'),
          ),
        ),
      );
    });

    test('allows HTTP only with the explicit opt-in', () {
      final uri = NetworkEndpointPolicy.requireAllowed(
        _server(baseUrl: 'http://music.example.com', allowInsecureHttp: true),
      );
      expect(uri.scheme, 'http');
    });

    test('rejects URL userinfo', () {
      expect(
        () => NetworkEndpointPolicy.requireAllowed(
          _server(baseUrl: 'https://user:pass@music.example.com'),
        ),
        throwsA(
          isA<NetworkCredentialException>().having(
            (e) => e.message,
            'message',
            contains('Remove the username or password'),
          ),
        ),
      );
    });

    test('rejects malformed URLs and unsupported schemes', () {
      expect(
        () =>
            NetworkEndpointPolicy.requireAllowed(_server(baseUrl: 'not a url')),
        throwsA(isA<NetworkCredentialException>()),
      );
      expect(
        () => NetworkEndpointPolicy.requireAllowed(
          _server(baseUrl: 'ftp://music.example.com'),
        ),
        throwsA(
          isA<NetworkCredentialException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported URL scheme'),
          ),
        ),
      );
    });
  });

  test('rejects query and fragment input on credentialed base URLs', () {
    for (final suffix in ['?key=value', '#fragment']) {
      expect(
        () => NetworkEndpointPolicy.requireAllowed(
          _server(baseUrl: 'https://music.example.com/root$suffix'),
        ),
        throwsA(isA<NetworkCredentialException>()),
      );
    }
  });

  test('isInsecureHttp only matches http', () {
    expect(NetworkEndpointPolicy.isInsecureHttp('http://x'), isTrue);
    expect(NetworkEndpointPolicy.isInsecureHttp('https://x'), isFalse);
    expect(NetworkEndpointPolicy.isInsecureHttp('x'), isFalse);
  });

  test('secureClient disables redirects on credentialed requests', () async {
    final inner = _RecordingClient();
    final client = NetworkEndpointPolicy.secureClient(inner);

    final response = await client.get(
      Uri.parse('https://music.example.com/rest/ping'),
    );

    expect(response.statusCode, 204);
    expect(inner.captured, isNotNull);
    expect(inner.captured!.followRedirects, isFalse);
    expect(inner.captured!.maxRedirects, 0);
  });

  test('secureClient strips credentials from streamed body errors', () async {
    final uri = Uri.https('music.example.com', '/rest/stream', {
      't': 'fake-credential',
    });
    final client = NetworkEndpointPolicy.secureClient(
      _RecordingClient(
        body: Stream.error(http.ClientException('Read failed at $uri', uri)),
      ),
    );
    addTearDown(client.close);

    final response = await client.send(http.Request('GET', uri));
    await expectLater(
      response.stream,
      emitsError(
        isA<http.ClientException>()
            .having((e) => e.uri, 'URI', isNull)
            .having((e) => e.message, 'message', 'Network response failed'),
      ),
    );
  });
}
