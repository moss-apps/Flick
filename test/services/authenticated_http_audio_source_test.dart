// ignore_for_file: experimental_member_use

import 'package:flick/services/authenticated_http_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const url = 'https://music.example.com/track?t=test-hash&s=test-salt';

  test(
    'forwards exact byte ranges and preserves the media type and bytes',
    () async {
      var requests = 0;
      final source = AuthenticatedHttpAudioSource(
        resolve: () async =>
            (url: url, headers: {'Authorization': 'Bearer test-session'}),
        client: MockClient((request) async {
          requests++;
          expect(request.url.toString(), url);
          expect(request.headers['Authorization'], 'Bearer test-session');
          expect(request.headers['Accept-Encoding'], 'identity');
          expect(request.headers['Range'], 'bytes=10-12');
          expect(request.followRedirects, isFalse);
          return http.Response.bytes(
            [4, 5, 6],
            206,
            headers: {
              'content-type': 'audio/flac',
              'content-range': 'bytes 10-12/42',
            },
          );
        }),
      );

      final response = await source.request(10, 13);
      expect(response.offset, 10);
      expect(response.sourceLength, 42);
      expect(response.contentLength, 3);
      expect(response.contentType, 'audio/flac');
      expect(await response.stream.expand((chunk) => chunk).toList(), [
        4,
        5,
        6,
      ]);
      expect(requests, 1);
    },
  );

  test(
    'rejects redirects without exposing the upstream URL or response',
    () async {
      final source = AuthenticatedHttpAudioSource(
        resolve: () async => (url: url, headers: const <String, String>{}),
        client: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          return http.Response(url, 302, headers: {'location': url});
        }),
      );

      await expectLater(
        source.request(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Network audio request failed (HTTP 302)',
          ),
        ),
      );
    },
  );
}
