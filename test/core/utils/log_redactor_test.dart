import 'package:flick/core/utils/log_redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts URL query secrets but keeps the keys', () {
    final out = redactSensitiveLogText(
      'GET https://music.example.com/rest/ping.view?u=demo&t=abc123&s=salt42',
    );

    expect(out, contains('u=demo'));
    expect(out, contains('t=<redacted>'));
    expect(out, contains('s=<redacted>'));
    expect(out, isNot(contains('abc123')));
    expect(out, isNot(contains('salt42')));
  });

  test('redacts Authorization scheme values', () {
    final out = redactSensitiveLogText(
      'Authorization: Bearer header.payload.signature\n'
      'Authorization: Basic dXNlcjpwYXNz\n'
      'Authorization: Token listenbrainz-test',
    );

    expect(out, contains('Bearer <redacted>'));
    expect(out, contains('Basic <redacted>'));
    expect(out, contains('Token <redacted>'));
    expect(out, isNot(contains('header.payload.signature')));
    expect(out, isNot(contains('dXNlcjpwYXNz')));
    expect(out, isNot(contains('listenbrainz-test')));
  });

  test('redacts JSON credential fields but keeps structure', () {
    final out = redactSensitiveLogText(
      '{"access_token":"acc-1","refresh_token":"ref-1","user":"demo"}',
    );

    expect(
      out,
      '{"access_token":"<redacted>","refresh_token":"<redacted>",'
      '"user":"demo"}',
    );
  });

  test('redacts bare key=value secrets', () {
    final out = redactSensitiveLogText(
      'password=hunter2 next token=abc, session_key=xyz',
    );

    expect(out, contains('password=<redacted>'));
    expect(out, contains('token=<redacted>'));
    expect(out, contains('session_key=<redacted>'));
    expect(out, isNot(contains('hunter2')));
    expect(out, isNot(contains('abc')));
    expect(out, isNot(contains('xyz')));
  });

  test('scrubs legacy sign-in logs and escaped credential values', () {
    const oldMessages = [
      '[LastFm] getTokenAndLaunchAuth: Token received: testPrefix...',
      '[LastFm] getTokenAndLaunchAuth: Auth URL: '
          'https://www.last.fm/api/auth/?api_key=testKey&token=testAuth',
      '[LastFm] _completeAuth: ERROR - provider response with testBody',
      '[Tidal] browser launch failed: https://link.tidal.com/TESTCODE',
      '[Tidal] POST https://auth.tidal.com/v1/oauth2/token -> '
          'HTTP 400: response with testBody',
      r'{"password":"example\"quoted","status":"ok"}',
    ];

    final sanitized = oldMessages.map(redactSensitiveLogText).toList();
    expect(sanitized, [
      '[LastFm] getTokenAndLaunchAuth: Token received: <redacted>',
      '[LastFm] getTokenAndLaunchAuth: Auth URL: '
          'https://www.last.fm/api/auth/?api_key=<redacted>&token=<redacted>',
      '[LastFm] _completeAuth: ERROR - <redacted>',
      '[Tidal] browser launch failed: link.tidal.com/<redacted>',
      '[Tidal] POST https://auth.tidal.com/v1/oauth2/token -> '
          'HTTP 400: <redacted>',
      '{"password":"<redacted>","status":"ok"}',
    ]);
    expect(sanitized.map(redactSensitiveLogText), sanitized);
  });

  test('leaves non-secret text untouched', () {
    expect(
      redactSensitiveLogText('Scanning library: 128 songs'),
      'Scanning library: 128 songs',
    );
    expect(redactSensitiveLogText('safe=ok'), 'safe=ok');
  });

  test('returns empty input unchanged', () {
    expect(redactSensitiveLogText(''), '');
  });
}
