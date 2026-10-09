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
          Exception('Protocol error: STATUS_BAD_NETWORK_NAME during TREE_CONNECT'),
        ),
        contains('share'),
      );
    });

    test('keeps an unrecognized error as-is', () {
      expect(
        SmbService.describePingError(Exception('weird transport failure')),
        contains('weird transport failure'),
      );
    });
  });
}
