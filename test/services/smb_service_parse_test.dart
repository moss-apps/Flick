import 'package:flutter_test/flutter_test.dart';

import 'package:flick/services/sources/smb_service.dart';

void main() {
  group('SmbService.parseServerUrl', () {
    test('parses host, default port and share', () {
      final s = SmbService.parseServerUrl('smb://nas/music');
      expect(s.host, 'nas');
      expect(s.port, 445);
      expect(s.share, 'music');
      expect(s.rootPath, '');
    });

    test('parses explicit port, root path and percent-encoding', () {
      final s = SmbService.parseServerUrl(
        'smb://nas:1445/My%20Music/Albums/Album%201',
      );
      expect(s.host, 'nas');
      expect(s.port, 1445);
      expect(s.share, 'My Music');
      expect(s.rootPath, 'Albums/Album 1');
    });

    test('strips IPv6 brackets the way Dart does', () {
      final s = SmbService.parseServerUrl('smb://[fd00::1]/music');
      expect(s.host, 'fd00::1');
      expect(s.port, 445);
      expect(s.share, 'music');
    });

    test(
      'decodes percent signs exactly once and accepts Unicode/trailing slash',
      () {
        final s = SmbService.parseServerUrl(
          'smb://nas/Music%25/日本語/100%2520hits/',
        );
        expect(s.share, 'Music%');
        expect(s.rootPath, '日本語/100%20hits');
      },
    );

    test('normalizes Windows UNC paths', () {
      final s = SmbService.parseServerUrl(r'\\nas\music\Albums');
      expect(s.host, 'nas');
      expect(s.share, 'music');
      expect(s.rootPath, 'Albums');
    });

    test('rejects a URL without a share', () {
      expect(
        () => SmbService.parseServerUrl('smb://nas'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a URL without a host', () {
      expect(
        () => SmbService.parseServerUrl('smb:///music'),
        throwsA(isA<FormatException>()),
      );
    });

    for (final url in [
      'smb://private-host:bad/private-share',
      'smb://private-user:private-password@private-host/private-share',
      'smb://private-host:65536/private-share',
      'https://private-host/private-share',
      'smb://private-host/private-share?private-password',
    ]) {
      test('rejects invalid/credential-bearing URL without echoing input', () {
        expect(
          () => SmbService.parseServerUrl(url),
          throwsA(
            isA<FormatException>().having(
              (e) => e.toString(),
              'safe parser message',
              isNot(contains('private-')),
            ),
          ),
        );
      });
    }
  });

  group('SmbService.describePingError', () {
    test('maps an auth failure to credentials guidance', () {
      expect(
        SmbService.describePingError(
          Exception('Authentication failed: STATUS_LOGON_FAILURE'),
        ),
        contains('username or password'),
      );
    });

    test('maps a timeout to address/port guidance', () {
      expect(
        SmbService.describePingError(Exception('Operation timed out')),
        contains('Timed out'),
      );
    });

    test('maps an unknown share to URL guidance', () {
      expect(
        SmbService.describePingError(
          Exception(
            'Protocol error: STATUS_BAD_NETWORK_NAME during TREE_CONNECT',
          ),
        ),
        contains('share'),
      );
    });

    test('never exposes an unrecognized raw error', () {
      expect(
        SmbService.describePingError(Exception('weird transport failure')),
        isNot(contains('weird transport failure')),
      );
    });
  });
}
