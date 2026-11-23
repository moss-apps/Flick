import 'package:flick/core/utils/network_source_display.dart';
import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song({String? sourceType, int? remoteServerId}) {
  return Song(
    id: 'song-1',
    title: 'Track',
    artist: 'Artist',
    duration: const Duration(minutes: 3),
    fileType: 'FLAC',
    sourceType: sourceType,
    remoteServerId: remoteServerId,
  );
}

NetworkServerEntity _server({
  required int id,
  required String label,
  required String protocol,
}) {
  return NetworkServerEntity()
    ..id = id
    ..label = label
    ..protocol = protocol
    ..baseUrl = 'https://example.test';
}

void main() {
  group('networkServerDisplayName', () {
    test('returns null for local songs', () {
      expect(networkServerDisplayName(_song(), const []), isNull);
    });

    test('prefers the configured server label', () {
      final servers = [
        _server(id: 1, label: 'Home NAS', protocol: 'subsonic'),
        _server(id: 2, label: 'Bedroom Jellyfin', protocol: 'jellyfin'),
      ];

      expect(
        networkServerDisplayName(
          _song(sourceType: 'jellyfin', remoteServerId: 2),
          servers,
        ),
        'Bedroom Jellyfin',
      );
    });

    test('trims labels and falls back to the protocol name when empty', () {
      final servers = [_server(id: 1, label: '   ', protocol: 'smb')];

      expect(
        networkServerDisplayName(
          _song(sourceType: 'smb', remoteServerId: 1),
          servers,
        ),
        'SMB',
      );
    });

    test('falls back to the protocol when the server record is missing', () {
      expect(
        networkServerDisplayName(
          _song(sourceType: 'jellyfin', remoteServerId: 99),
          const [],
        ),
        'Jellyfin',
      );
    });

    test('still resolves cached network songs while servers load', () {
      expect(
        networkServerDisplayName(
          _song(sourceType: 'webdav', remoteServerId: 3),
          null,
        ),
        'WebDAV',
      );
    });
  });

  group('networkProtocolDisplayName', () {
    test('covers every product protocol', () {
      expect(networkProtocolDisplayName('subsonic'), 'Subsonic');
      expect(networkProtocolDisplayName('jellyfin'), 'Jellyfin');
      expect(networkProtocolDisplayName('webdav'), 'WebDAV');
      expect(networkProtocolDisplayName('upnp'), 'UPnP');
      expect(networkProtocolDisplayName('smb'), 'SMB');
      expect(networkProtocolDisplayName('tidal'), 'Tidal');
      expect(networkProtocolDisplayName(null), isNull);
    });
  });
}
