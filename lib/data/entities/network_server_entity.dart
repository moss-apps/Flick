import 'package:isar_community/isar.dart';

part 'network_server_entity.g.dart';

/// Configured self-hosted music server (Subsonic / WebDAV / Jellyfin).
@collection
class NetworkServerEntity {
  Id id = Isar.autoIncrement;

  /// Display name shown in the Network Sources settings screen.
  late String label;

  /// Protocol: 'subsonic' | 'webdav' | 'jellyfin' | 'tidal' (SMB/UPnP too).
  late String protocol;

  /// Base URL of the server, e.g. https://music.example.com/subsonic.
  late String baseUrl;

  /// User name used for authentication.
  String? username;

  /// Explicit opt-in for sending credentials over plain HTTP. HTTPS is the
  /// default; users can enable this for a trusted LAN endpoint.
  bool allowInsecureHttp = false;

  /// Non-secret reference into the Android Keystore-backed credential store.
  /// The actual protocol token/password is never written to Isar.
  String? credentialRef;

  /// Legacy secret column. Read only by [NetworkCredentialMigration] to move
  /// existing installs into secure storage, then cleared. New code must use
  /// [credentialRef] and `NetworkCredentialStore`.
  String? token;

  /// Last time a library sync (metadata fetch) succeeded for this server.
  DateTime? lastSyncedAt;
}
