import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/app_log.dart';
import '../../data/database.dart';
import '../../data/repositories/song_repository.dart';
import '../../models/playlist.dart';
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import '../playlist_service.dart';
import 'network_source_service.dart';

/// Subsonic API client (JSON variant, no transcoding params).
///
/// Auth: Subsonic token auth, `t = md5(password + salt)`, `s = salt`.
/// The stored server token is the `salt:md5hex` pair, so the plaintext
/// password is never persisted or transmitted.
class SubsonicService implements NetworkSourceService {
  SubsonicService._({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    PlaylistService? playlistService,
  })  : _client = client ?? http.Client(),
        _songRepository = songRepository,
        _networkCache = networkCache,
        _playlistService = playlistService;

  /// Singleton used by the app.
  static SubsonicService instance = SubsonicService._();

  /// Test seam: build an isolated instance with mocked dependencies.
  @visibleForTesting
  static SubsonicService create({
    http.Client? client,
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    PlaylistService? playlistService,
  }) {
    return SubsonicService._(
      client: client,
      songRepository: songRepository,
      networkCache: networkCache,
      playlistService: playlistService,
    );
  }

  static const String _clientName = 'flick';
  static const String _apiVersion = '1.16.1';
  static const int _pageSize = 500;

  @override
  String get protocol => NetworkProtocol.subsonic;

  @override
  String get coverScheme => networkCoverArtScheme;

  @override
  Future<String?> resolveToken(NetworkServerEntity server, String password) async {
    // Local transform: salt + md5, no round-trip. The [server] is ignored.
    return buildToken(password);
  }

  final http.Client _client;

  // Lazy: only sync/stream touch these, keep HTTP-only tests DB-free.
  // ponytail: lazy init, eager if tests start needing injection everywhere
  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;
  PlaylistService? _playlistService;

  SongRepository get _repo => _songRepository ??= SongRepository();

  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  PlaylistService get _playlists =>
      _playlistService ??= PlaylistService.instance;

  // --- Auth ---------------------------------------------------------------

  /// Build the shared auth query params. Throws if the server has no token
  /// stored (i.e. it was never saved through the settings screen).
  Map<String, String> _authParams(NetworkServerEntity server) {
    final stored = server.token;
    if (stored == null || !stored.contains(':')) {
      throw StateError('Server "${server.label}" has no stored credentials');
    }
    final separator = stored.indexOf(':');
    return {
      'u': server.username ?? '',
      't': stored.substring(separator + 1),
      's': stored.substring(0, separator),
      'v': _apiVersion,
      'c': _clientName,
      'f': 'json',
    };
  }

  /// Compute the stored `salt:md5hex` token for [password].
  /// Spec-correct order: md5(password + salt); salt must be >= 6 chars.
  static String buildToken(String password, {String? salt}) {
    final finalSalt = salt ?? _generateSalt();
    final digest = md5.convert(utf8.encode('$password$finalSalt'));
    return '$finalSalt:${digest.toString()}';
  }

  static String _generateSalt() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Uri _endpoint(NetworkServerEntity server, String method,
      [Map<String, dynamic> extra = const {}]) {
    final base = server.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/rest/$method.view').replace(
      queryParameters: {..._authParams(server), ...extra},
    );
  }

  Future<Map<String, dynamic>> _getJson(
    NetworkServerEntity server,
    String method, {
    Map<String, dynamic> extra = const {},
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = _endpoint(server, method, extra);
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw SubsonicNetworkException('HTTP ${response.statusCode} for $method');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final payload = body['subsonic-response'] as Map<String, dynamic>;
    if (payload['status'] != 'ok') {
      final error = payload['error'] as Map<String, dynamic>?;
      throw SubsonicNetworkException(
        error?['message'] as String? ?? 'Subsonic error for $method',
        code: error?['code'] as int?,
      );
    }
    return payload;
  }

  // --- API ----------------------------------------------------------------

  /// Test connectivity + credentials. Returns true when the server responds
  /// with status ok.
  @override
  Future<bool> ping(NetworkServerEntity server) async {
    try {
      await _getJson(server, 'ping');
      return true;
    } catch (e) {
      AppLog.instance.add('Subsonic ping failed: $e');
      return false;
    }
  }

  /// All albums from getAlbumList2, paginated over the whole library.
  Future<List<Map<String, dynamic>>> getAlbumList2(
    NetworkServerEntity server,
  ) async {
    final albums = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final payload = await _getJson(server, 'getAlbumList2', extra: {
        'type': 'alphabeticalByName',
        'size': '$_pageSize',
        'offset': '$offset',
      });
      final list =
          ((payload['albumList2'] as Map<String, dynamic>?)?['album']
                  as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const [];
      albums.addAll(list);
      if (list.length < _pageSize) break;
      offset += list.length;
    }
    return albums;
  }

  /// Songs inside a single album.
  Future<List<Map<String, dynamic>>> getAlbum(
    NetworkServerEntity server,
    String albumId,
  ) async {
    final payload =
        await _getJson(server, 'getAlbum', extra: {'id': albumId});
    return ((payload['album'] as Map<String, dynamic>?)?['song']
            as List<dynamic>?)
        ?.cast<Map<String, dynamic>>() ??
        const [];
  }

  // --- Playlists ----------------------------------------------------------

  /// Server-side playlist summaries (Navidrome exposes its .m3u/.m3u8 files
  /// through this endpoint).
  Future<List<Map<String, dynamic>>> getPlaylists(
    NetworkServerEntity server,
  ) async {
    final payload = await _getJson(server, 'getPlaylists');
    return ((payload['playlists'] as Map<String, dynamic>?)?['playlist']
            as List<dynamic>?)
        ?.cast<Map<String, dynamic>>() ??
        const [];
  }

  /// Full song entries inside one playlist, or null when the playlist is
  /// gone. Entries are complete song objects (same shape as getAlbum).
  Future<List<Map<String, dynamic>>?> getPlaylist(
    NetworkServerEntity server,
    String playlistId,
  ) async {
    final payload =
        await _getJson(server, 'getPlaylist', extra: {'id': playlistId});
    final playlist = payload['playlist'] as Map<String, dynamic>?;
    return (playlist?['entry'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
  }

  /// Create a playlist, or replace an existing one's contents when
  /// [playlistId] is given. Returns the created/updated playlist summary.
  Future<Map<String, dynamic>?> createPlaylist(
    NetworkServerEntity server, {
    String? name,
    String? playlistId,
    List<String>? songIds,
  }) async {
    final payload = await _getJson(server, 'createPlaylist', extra: {
      if (name != null) 'name': name,
      if (playlistId != null) 'playlistId': playlistId,
      if (songIds != null && songIds.isNotEmpty) 'songId': songIds,
    });
    return payload['playlist'] as Map<String, dynamic>?;
  }

  Future<void> updatePlaylist(
    NetworkServerEntity server,
    String playlistId, {
    String? name,
    List<String>? songIdsToAdd,
    List<String>? songIdsToRemove,
  }) async {
    await _getJson(server, 'updatePlaylist', extra: {
      'playlistId': playlistId,
      if (name != null) 'name': name,
      if (songIdsToAdd != null && songIdsToAdd.isNotEmpty)
        'songIdToAdd': songIdsToAdd,
      if (songIdsToRemove != null && songIdsToRemove.isNotEmpty)
        'songIdToRemove': songIdsToRemove,
    });
  }

  Future<void> deletePlaylist(NetworkServerEntity server, String playlistId) async {
    await _getJson(server, 'deletePlaylist', extra: {'id': playlistId});
  }

  /// Raw cover art bytes for [coverArtId] (the value of a song's `coverArt`
  /// attribute, e.g. "al-123").
  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String coverArtId,
  ) async {
    final uri = _endpoint(server, 'getCoverArt', {'id': coverArtId});
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw SubsonicNetworkException(
          'HTTP ${response.statusCode} for getCoverArt');
    }
    return response.bodyBytes;
  }

  /// Stream a song's audio at original quality: no maxBitRate/format params
  /// so the server returns the stored file, not a transcode. Writes the bytes
  /// into the network cache and returns the local path. When [onProgress] is
  /// given it is called with 0..1 as bytes arrive (streamed download).
  @override
  Future<String> stream(
    NetworkServerEntity server,
    String songId, {
    String? extension,
    void Function(double progress)? onProgress,
  }) async {
    final cached = await _cache.getPath(server.id, songId,
        extension: extension);
    if (cached != null) return cached;

    final uri = _endpoint(server, 'stream', {'id': songId});
    final request = http.Request('GET', uri);
    final response = await _client
        .send(request)
        .timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw SubsonicNetworkException(
          'HTTP ${response.statusCode} for stream');
    }
    final total = response.contentLength;
    final builder = BytesBuilder();
    var received = 0;
    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      if (onProgress != null && total != null && total > 0) {
        onProgress(received / total);
      }
    }
    return _cache.stash(server.id, songId, builder.takeBytes(),
        extension: extension);
  }

  @override
  Future<({String url, Map<String, String> headers})?> streamDescriptor(
    NetworkServerEntity server,
    String songId, {
    String? extension,
  }) async {
    // ponytail: Subsonic auth is entirely URL-embedded (u/p/t+s query params),
    // so headers are empty. Range support is universal across servers.
    return (url: _endpoint(server, 'stream', {'id': songId}).toString(), headers: const <String, String>{});
  }

  // --- Library sync -------------------------------------------------------

  /// Pull the full server library into the local DB as SongEntitys.
  ///
  /// Upserts every song (composite-key match on the synthetic filePath),
  /// deletes rows that no longer exist on the server, then stamps
  /// [NetworkServerEntity.lastSyncedAt].
  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final albums = await getAlbumList2(server);
    final syncedRemoteIds = <String>{};

    var songsFound = 0;
    var filesProcessed = 0;
    for (final album in albums) {
      final albumName = album['album'] as String? ?? '';
      final albumArtist = album['artist'] as String? ?? '';
      final coverArt = album['coverArt'] as String?;
      final year = _toInt(album['year']);

      try {
        final rawSongs = await getAlbum(server, album['id'] as String);
        final entities = rawSongs
            .map((s) => buildSongEntity(server, s,
                albumName: albumName,
                albumArtist: albumArtist,
                coverArt: coverArt,
                year: year))
            .toList();
        await _repo.upsertSongs(entities);
        syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));

        songsFound += entities.length;
      } catch (e) {
        // One bad album shouldn't abort the whole sync: log and move on.
        AppLog.instance.add(
          'Subsonic sync skipped album "$albumName" on ${server.label}: $e',
        );
      }

      filesProcessed++;
      yield ScanProgress(
        songsFound: songsFound,
        totalFiles: albums.length,
        filesProcessed: filesProcessed,
        phase: 'Syncing ${server.label}',
        currentFile: albumName,
      );
    }

    await _purgeStale(server, syncedRemoteIds);

    try {
      await syncPlaylists(server);
    } catch (e) {
      AppLog.instance.add(
        'Subsonic playlist sync failed on ${server.label}: $e',
      );
    }

    await Database.instance.writeTxn(() async {
      final stored = await Database.networkServers.get(server.id);
      if (stored != null) {
        stored.lastSyncedAt = DateTime.now();
        await Database.networkServers.put(stored);
      }
    });

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: albums.length,
      filesProcessed: filesProcessed,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  Future<void> _purgeStale(NetworkServerEntity server, Set<String> syncedIds) async {
    final existing = await _repo.getSongsByRemoteServer(server.id);
    final stale = existing.where((e) => !syncedIds.contains(e.remoteId)).toList();
    if (stale.isEmpty) return;
    await _repo.deleteSongsByIds(stale.map((e) => e.id).toList());
  }

  /// Pull server-side playlists into local [Playlist] mirrors keyed by
  /// `subsonic://<serverId>/<remotePlaylistId>` source paths. Songs referenced
  /// by playlists but missing locally are upserted from the entry metadata so
  /// playlists stay playable. Mirrors of playlists deleted on the server are
  /// removed. Returns the number of playlists synced.
  Future<int> syncPlaylists(NetworkServerEntity server) async {
    final summaries = await getPlaylists(server);
    final playlists = <({String remoteId, String name, List<Map<String, dynamic>> entries})>[];
    for (final summary in summaries) {
      final remoteId = summary['id']?.toString();
      if (remoteId == null) continue;
      try {
        final entries = await getPlaylist(server, remoteId) ?? const [];
        playlists.add((
          remoteId: remoteId,
          name: summary['name'] as String? ?? 'Playlist',
          entries: entries,
        ));
      } catch (e) {
        AppLog.instance.add(
          'Subsonic playlist "$remoteId" skipped on ${server.label}: $e',
        );
      }
    }

    // Resolve every entry to a local song row, upserting the missing ones.
    final byRemote = <String, String>{
      for (final e in await _repo.getSongsByRemoteServer(server.id))
        if (e.remoteId != null) e.remoteId!: e.id.toString(),
    };
    final missing = <String, Map<String, dynamic>>{};
    for (final p in playlists) {
      for (final entry in p.entries) {
        final id = entry['id']?.toString();
        if (id != null && !byRemote.containsKey(id)) {
          missing[id] = entry;
        }
      }
    }
    if (missing.isNotEmpty) {
      final entities = [
        for (final m in missing.entries) buildSongEntity(server, m.value),
      ];
      await _repo.upsertSongs(entities);
      for (final e in entities) {
        if (e.remoteId != null) byRemote[e.remoteId!] = e.id.toString();
      }
    }

    final songIdsByPlaylist = resolvePlaylistSongIds(playlists, byRemote);
    final syncedPaths = <String>{};
    for (final p in playlists) {
      await _playlists.upsertNetworkPlaylist(
        serverId: server.id,
        remoteId: p.remoteId,
        name: p.name,
        songIds: songIdsByPlaylist[p.remoteId] ?? const [],
        saveAfter: false,
      );
      syncedPaths.add(
        '${Playlist.networkSourceScheme}://${server.id}/${p.remoteId}',
      );
    }
    if (syncedPaths.isNotEmpty) {
      await _playlists.persist();
    }
    await _playlists.removeStaleNetworkPlaylists('${server.id}', syncedPaths);
    return playlists.length;
  }

  /// Pure mapping from raw playlist entries to local song ids. Playlists with
  /// unresolvable entries are skipped per-song (never fail the whole pull).
  @visibleForTesting
  static Map<String, List<String>> resolvePlaylistSongIds(
    List<({String remoteId, String name, List<Map<String, dynamic>> entries})>
        playlists,
    Map<String, String> remoteIdToLocalId,
  ) {
    final result = <String, List<String>>{};
    for (final p in playlists) {
      final ids = <String>[];
      for (final entry in p.entries) {
        final id = entry['id']?.toString();
        if (id == null) continue;
        final localId = remoteIdToLocalId[id];
        if (localId == null) continue;
        ids.add(localId);
      }
      result[p.remoteId] = ids;
    }
    return result;
  }

  /// Map a raw Subsonic song map to a [SongEntity] tagged
  /// `sourceType = 'subsonic'` with a synthetic `subsonic://<serverId>/<remoteId>`
  /// filePath and a `subsonic-cover://<id>` album-art marker. Pure: no instance
  /// state, so [SubsonicService.syncLibrary] and tests share one mapping.
  @visibleForTesting
  static SongEntity buildSongEntity(
    NetworkServerEntity server,
    Map<String, dynamic> s, {
    String? albumName,
    String? albumArtist,
    String? coverArt,
    int? year,
  }) {
    final remoteId = s['id'] as String;
    final songCoverArt = s['coverArt'] as String? ?? coverArt;
    final durationSec = _toInt(s['duration']);
    return SongEntity()
      ..filePath = 'subsonic://${server.id}/$remoteId'
      ..title = (s['title'] as String?) ?? 'Unknown'
      ..artist = (s['artist'] as String?) ?? 'Unknown'
      ..album = albumName ?? (s['album'] as String?)
      ..albumArtist = albumArtist ?? (s['albumArtist'] as String?)
      ..durationMs = durationSec != null ? durationSec * 1000 : null
      ..trackNumber = _toInt(s['track'])
      ..discNumber = _toInt(s['discNumber'])
      ..year = year ?? _toInt(s['year'])
      ..genre = s['genre'] as String?
      ..fileSize = _toInt(s['size'])
      ..fileType = s['suffix'] as String?
      ..bitrate = _toInt(s['bitRate'])
      ..sampleRate = _toInt(s['sampleRate'])
      ..albumArtPath =
          songCoverArt != null ? 'subsonic-cover://$songCoverArt' : null
      ..sourceType = 'subsonic'
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }
}

/// Tolerant int cast: accepts JSON int or double, null stays null.
/// ponytail: Subsonic spec says these are integers, but some servers emit
/// floats; this keeps a single off-spec field from aborting the whole sync.
int? _toInt(dynamic v) => v == null ? null : (v as num).toInt();

/// Marker scheme for network cover art ids stored in [SongEntity.albumArtPath].
const String networkCoverArtScheme = 'subsonic-cover://';

class SubsonicNetworkException implements Exception {
  final String message;
  final int? code;

  SubsonicNetworkException(this.message, {this.code});

  @override
  String toString() => 'Subsonic error $code: $message';
}
