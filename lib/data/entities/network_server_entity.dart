import 'package:isar_community/isar.dart';

part 'network_server_entity.g.dart';

/// Configured self-hosted music server (Subsonic / WebDAV / Jellyfin).
@collection
class NetworkServerEntity {
  Id id = Isar.autoIncrement;

  /// Display name shown in the Network Sources settings screen.
  late String label;

  /// Protocol: 'subsonic' | 'webdav' | 'jellyfin' (SMB/UPnP deferred).
  late String protocol;

  /// Base URL of the server, e.g. https://music.example.com/subsonic.
  late String baseUrl;

  /// User name used for authentication.
  String? username;

  /// Secret, never plaintext: Subsonic stores the salt+md5 hex form
  /// (`salt:md5hex`), Jellyfin stores the server-issued token, WebDAV the
  /// bearer token.
  String? token;

  /// Last time a library sync (metadata fetch) succeeded for this server.
  DateTime? lastSyncedAt;
}
