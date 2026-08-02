import '../../data/database.dart';
import '../../data/repositories/song_repository.dart';
import '../library_scanner_service.dart' show ScanProgress;
import 'jellyfin_service.dart';
import 'smb_service.dart';
import 'subsonic_service.dart';
import 'upnp_service.dart';
import 'webdav_service.dart';

/// Common surface every network music source implements.
///
/// Each protocol plugs into the same four flows: connectivity test
/// ([ping]), library sync ([syncLibrary]), audio download ([stream]) and
/// cover-art fetch ([getCoverArt]). The [resolveToken] hook turns a typed
/// password into the opaque string stored in [NetworkServerEntity.token] —
/// a local transform for Subsonic/WebDAV, a server round-trip for Jellyfin.
///
/// Song rows produced during sync use a scheme-prefixed [SongEntity.filePath]
/// (`<protocol>://<serverId>/<remoteId>`) so [AlbumArtService] and
/// [RemoteSourceService] can dispatch by `Uri.scheme`.
abstract class NetworkSourceService {
  /// Protocol id stored on the entity and used as the `filePath` URI scheme.
  String get protocol;

  /// Marker scheme prefix stored in [SongEntity.albumArtPath], e.g.
  /// `subsonic-cover://`. The bytes after this prefix are the opaque [marker]
  /// passed back to [getCoverArt].
  String get coverScheme;

  /// Resolve the value to persist in [NetworkServerEntity.token] for a typed
  /// [password]. Returns null when the protocol stores no secret (anonymous
  /// UPnP). May perform a network round-trip (Jellyfin authenticateByName).
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  );

  /// Validate connectivity + stored credentials. Returns false (not throws)
  /// on expected auth/network failures so the edit screen can show a banner.
  Future<bool> ping(NetworkServerEntity server);

  /// Raw cover-art bytes for [marker] (the opaque id/path/url stored after
  /// [coverScheme] in [SongEntity.albumArtPath]).
  Future<List<int>> getCoverArt(NetworkServerEntity server, String marker);

  /// Download (or cache-hit) the audio for [remoteId] into the network cache
  /// and return the local file path. [onProgress] reports 0..1 during a miss.
  Future<String> stream(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
    void Function(double progress)? onProgress,
  });

  /// Pull the full server library into the local DB as [SongEntity]s,
  /// upserting new/changed rows and deleting stale ones, yielding progress.
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server);
}

/// Protocol ids supported by the app.
class NetworkProtocol {
  static const subsonic = 'subsonic';
  static const jellyfin = 'jellyfin';
  static const webdav = 'webdav';
  static const upnp = 'upnp';
  static const smb = 'smb';

  static const all = [subsonic, jellyfin, webdav, upnp, smb];
}

final Map<String, NetworkSourceService> _registry = {};
bool _seeded = false;

void _ensureSeeded() {
  if (_seeded) return;
  _seeded = true;
  for (final s in [
    SubsonicService.instance,
    JellyfinService.instance,
    WebdavService.instance,
    UpnpService.instance,
    SmbService.instance,
  ]) {
    _registry[s.protocol] = s;
  }
}

/// Look up the service for a protocol id. Throws [StateError] for unknown
/// protocols so callers fail loudly instead of silently no-op'ing.
NetworkSourceService networkSourceServiceFor(String protocol) {
  _ensureSeeded();
  final service = _registry[protocol];
  if (service != null) return service;
  throw StateError('Unsupported network protocol: "$protocol"');
}

/// True when a registered service exists for [protocol].
bool isSupportedNetworkProtocol(String? protocol) {
  if (protocol == null) return false;
  _ensureSeeded();
  return _registry.containsKey(protocol);
}

/// Shared sync tail: delete rows that dropped off the server, then stamp
/// [NetworkServerEntity.lastSyncedAt]. Each protocol's `syncLibrary` does its
/// own per-batch upsert during the walk; this closes the loop identically.
Future<void> purgeAndStampNetworkSync(
  NetworkServerEntity server,
  Set<String> syncedRemoteIds,
) async {
  final repo = SongRepository();
  final existing = await repo.getSongsByRemoteServer(server.id);
  final stale = existing
      .where((e) => e.remoteId != null && !syncedRemoteIds.contains(e.remoteId))
      .toList();
  if (stale.isNotEmpty) {
    await repo.deleteSongsByIds(stale.map((e) => e.id).toList());
  }
  await Database.instance.writeTxn(() async {
    final stored = await Database.networkServers.get(server.id);
    if (stored != null) {
      stored.lastSyncedAt = DateTime.now();
      await Database.networkServers.put(stored);
    }
  });
}
