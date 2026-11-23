import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/sources/network_source_service.dart';

/// Human-readable fallback name for a network protocol.
///
/// These are product names, not translatable UI copy. The configured server
/// label is always preferred; this only covers rows whose server record is
/// missing (for example after a partial restore).
String? networkProtocolDisplayName(String? protocol) {
  switch (protocol) {
    case NetworkProtocol.subsonic:
      return 'Subsonic';
    case NetworkProtocol.jellyfin:
      return 'Jellyfin';
    case NetworkProtocol.webdav:
      return 'WebDAV';
    case NetworkProtocol.upnp:
      return 'UPnP';
    case NetworkProtocol.smb:
      return 'SMB';
    case NetworkProtocol.tidal:
      return 'Tidal';
    default:
      return null;
  }
}

/// The display name of the server a [song] was imported from.
///
/// Resolves the configured label through [Song.remoteServerId] so cached
/// network songs keep their source name while offline. Returns null for local
/// songs and for network songs with no resolvable source.
String? networkServerDisplayName(
  Song song,
  Iterable<NetworkServerEntity>? servers,
) {
  final serverId = song.remoteServerId;
  if (serverId != null && servers != null) {
    for (final server in servers) {
      if (server.id != serverId) continue;
      final label = server.label.trim();
      if (label.isNotEmpty) return label;
      return networkProtocolDisplayName(server.protocol) ?? server.protocol;
    }
  }

  final protocolName = networkProtocolDisplayName(song.sourceType);
  if (protocolName != null) return protocolName;
  return song.sourceType;
}
