import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/data/database.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/models/playlist.dart';
import 'package:flick/models/song.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/sources/subsonic_service.dart';

class PlaylistImportResult {
  final Playlist playlist;
  final int totalEntries;
  final int importedSongs;
  final int unmatchedEntries;
  final List<String> unmatchedSamples;

  const PlaylistImportResult({
    required this.playlist,
    required this.totalEntries,
    required this.importedSongs,
    required this.unmatchedEntries,
    required this.unmatchedSamples,
  });
}

class PlaylistExportResult {
  final String fileName;
  final int exportedSongs;
  final bool isUtf8;

  const PlaylistExportResult({
    required this.fileName,
    required this.exportedSongs,
    required this.isUtf8,
  });
}

class PlaylistSourceFile {
  final String sourcePath;
  final String? displayName;

  const PlaylistSourceFile({required this.sourcePath, this.displayName});
}

class PlaylistService {
  static const String _playlistsKey = 'playlists';
  static const MethodChannel _storageChannel = MethodChannel(
    'com.mossapps.flick/storage',
  );
  static const List<String> _playlistMimeTypes = [
    'audio/x-mpegurl',
    'application/vnd.apple.mpegurl',
    'application/x-mpegurl',
    'audio/mpegurl',
    'text/plain',
  ];

  List<Playlist> _playlists = [];
  bool _isLoaded = false;
  bool _importInProgress = false;
  SongRepository? _songRepository;
  final SubsonicService? _subsonicService;

  /// Shared instance: playlists live in one place (prefs + memory), and
  /// [SubsonicService] syncs into the same instance the UI reads.
  static PlaylistService instance = PlaylistService();

  PlaylistService({SongRepository? songRepository, SubsonicService? subsonicService})
    : _songRepository = songRepository,
      _subsonicService = subsonicService;

  // ponytail: lazy init so prefs-only paths (mirror sync, tests) never touch Isar.
  SongRepository get _repo => _songRepository ??= SongRepository();

  SubsonicService get _subsonic => _subsonicService ?? SubsonicService.instance;

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_playlistsKey);

    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      _playlists = jsonList
          .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    _isLoaded = true;
  }

  Future<List<Playlist>> getPlaylists() async {
    await _ensureLoaded();
    return List.from(_playlists);
  }

  Future<Playlist?> getPlaylist(String id) async {
    await _ensureLoaded();
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String _normalizeName(String name) => name.trim().toLowerCase();

  bool _playlistNameExists(String name, {String? excludeId}) {
    final normalizedName = _normalizeName(name);
    return _playlists.any(
      (playlist) =>
          playlist.id != excludeId &&
          _normalizeName(playlist.name) == normalizedName,
    );
  }

  /// Create a playlist. With [serverId] set, the playlist is created on that
  /// Subsonic server first and a local mirror is stored; otherwise it's a
  /// purely local playlist (as before).
  Future<Playlist?> createPlaylist(String name, {int? serverId}) async {
    await _ensureLoaded();
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) return null;

    if (serverId != null) {
      final server = await Database.networkServers.get(serverId);
      if (server == null) return null;
      try {
        final created = await _subsonic.createPlaylist(server, name: trimmedName);
        final remoteId = created?['id']?.toString();
        if (remoteId == null) return null;
        return await upsertNetworkPlaylist(
          serverId: serverId,
          remoteId: remoteId,
          name: trimmedName,
        );
      } catch (e) {
        devLog('[PlaylistService] Remote create failed: $e');
        return null;
      }
    }

    if (_playlistNameExists(trimmedName)) return null;

    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: trimmedName,
      createdAt: DateTime.now(),
    );

    _playlists.add(playlist);
    await _savePlaylists();

    return playlist;
  }

  Future<Playlist?> updatePlaylist(Playlist playlist) async {
    await _ensureLoaded();

    final index = _playlists.indexWhere((p) => p.id == playlist.id);
    if (index == -1) return null;

    final trimmedName = playlist.name.trim();
    if (trimmedName.isEmpty ||
        (!playlist.isNetworkSource &&
            _playlistNameExists(trimmedName, excludeId: playlist.id))) {
      return null;
    }

    if (playlist.isNetworkSource) {
      final server = await _networkServerFor(playlist);
      if (server == null) return null;
      try {
        await _subsonic.updatePlaylist(
          server,
          playlist.networkRemoteId!,
          name: trimmedName,
        );
      } catch (e) {
        devLog('[PlaylistService] Remote rename failed: $e');
        return null;
      }
    }

    final updated = playlist.copyWith(
      name: trimmedName,
      updatedAt: DateTime.now(),
    );
    _playlists[index] = updated;
    await _savePlaylists();

    return updated;
  }

  Future<bool> deletePlaylist(String id) async {
    await _ensureLoaded();

    Playlist? playlist;
    for (final p in _playlists) {
      if (p.id == id) {
        playlist = p;
        break;
      }
    }
    if (playlist == null) return false;

    if (playlist.isNetworkSource) {
      final server = await _networkServerFor(playlist);
      if (server == null) return false;
      try {
        await _subsonic.deletePlaylist(server, playlist.networkRemoteId!);
      } catch (e) {
        devLog('[PlaylistService] Remote delete failed: $e');
        return false;
      }
    }

    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    return true;
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    await _ensureLoaded();

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    if (playlist.songIds.contains(songId)) return true;

    if (playlist.isNetworkSource) {
      final remoteId = await _remoteIdForSong(playlist, songId);
      if (remoteId == null) return false;
      final server = await _networkServerFor(playlist);
      if (server == null) return false;
      try {
        await _subsonic.updatePlaylist(
          server,
          playlist.networkRemoteId!,
          songIdsToAdd: [remoteId],
        );
      } catch (e) {
        devLog('[PlaylistService] Remote add failed: $e');
        return false;
      }
    }

    final updated = playlist.copyWith(
      songIds: [...playlist.songIds, songId],
      updatedAt: DateTime.now(),
    );

    _playlists[index] = updated;
    await _savePlaylists();

    return true;
  }

  Future<bool> reorderSongs(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    await _ensureLoaded();

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];
    final songIds = List<String>.from(playlist.songIds);
    var adjustedNew = newIndex;
    if (oldIndex < adjustedNew) adjustedNew -= 1;
    final item = songIds.removeAt(oldIndex);
    songIds.insert(adjustedNew, item);

    if (playlist.isNetworkSource) {
      final server = await _networkServerFor(playlist);
      if (server == null) return false;
      final songs = await _repo.getAllSongs();
      final byId = {for (final s in songs) s.id: s};
      final remoteIds = <String>[];
      var resolvable = true;
      for (final id in songIds) {
        final song = byId[id];
        if (song == null ||
            song.remoteId == null ||
            song.remoteServerId != playlist.networkServerId) {
          resolvable = false;
          break;
        }
        remoteIds.add(song.remoteId!);
      }
      if (!resolvable) return false;
      try {
        // Subsonic has no reorder call; full-replace the server playlist.
        await _subsonic.createPlaylist(
          server,
          playlistId: playlist.networkRemoteId,
          name: playlist.name,
          songIds: remoteIds,
        );
      } catch (e) {
        devLog('[PlaylistService] Remote reorder failed: $e');
        return false;
      }
    }

    final updated = playlist.copyWith(
      songIds: songIds,
      updatedAt: DateTime.now(),
    );

    _playlists[index] = updated;
    await _savePlaylists();

    return true;
  }

  Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    await _ensureLoaded();

    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) return false;

    final playlist = _playlists[index];

    if (playlist.isNetworkSource) {
      final remoteId = await _remoteIdForSong(playlist, songId);
      if (remoteId == null) return false;
      final server = await _networkServerFor(playlist);
      if (server == null) return false;
      try {
        await _subsonic.updatePlaylist(
          server,
          playlist.networkRemoteId!,
          songIdsToRemove: [remoteId],
        );
      } catch (e) {
        devLog('[PlaylistService] Remote remove failed: $e');
        return false;
      }
    }

    final updated = playlist.copyWith(
      songIds: playlist.songIds.where((id) => id != songId).toList(),
      updatedAt: DateTime.now(),
    );

    _playlists[index] = updated;
    await _savePlaylists();

    return true;
  }

  // --- Network (Subsonic) playlist mirrors ---------------------------------

  /// Idempotently upsert a server playlist mirror keyed by sourcePath
  /// `subsonic://<serverId>/<remoteId>`. [saveAfter] skips the prefs write
  /// so bulk syncs can persist once at the end.
  Future<Playlist> upsertNetworkPlaylist({
    required int serverId,
    required String remoteId,
    required String name,
    List<String> songIds = const [],
    bool saveAfter = true,
  }) async {
    await _ensureLoaded();
    final sourcePath = '${Playlist.networkSourceScheme}://$serverId/$remoteId';
    final now = DateTime.now();
    final existing = _findPlaylistBySourcePath(sourcePath);

    late final Playlist playlist;
    if (existing != null) {
      playlist = existing.copyWith(
        name: name,
        songIds: songIds,
        updatedAt: now,
        sourcePath: sourcePath,
      );
      final index = _playlists.indexWhere((item) => item.id == existing.id);
      if (index >= 0) {
        _playlists[index] = playlist;
      }
    } else {
      playlist = Playlist(
        id: '${Playlist.networkSourceScheme}:$serverId:$remoteId',
        name: name,
        songIds: songIds,
        createdAt: now,
        updatedAt: now,
        sourcePath: sourcePath,
      );
      _playlists.add(playlist);
    }

    if (saveAfter) {
      await _savePlaylists();
    }
    return playlist;
  }

  /// Remove mirrors for [serverId] whose sourcePath is not in [keepPaths].
  Future<void> removeStaleNetworkPlaylists(
    String serverId,
    Set<String> keepPaths,
  ) async {
    await _ensureLoaded();
    final prefix = '${Playlist.networkSourceScheme}://$serverId/';
    final before = _playlists.length;
    _playlists.removeWhere(
      (p) =>
          p.sourcePath != null &&
          p.sourcePath!.startsWith(prefix) &&
          !keepPaths.contains(p.sourcePath),
    );
    if (_playlists.length != before) {
      await _savePlaylists();
    }
  }

  /// Purge every mirror owned by [serverId] (used when a server is removed).
  Future<void> removeNetworkPlaylistsForServer(String serverId) async {
    await removeStaleNetworkPlaylists(serverId, const {});
  }

  /// Write the in-memory playlists to prefs (used after bulk syncs).
  Future<void> persist() => _savePlaylists();

  Future<NetworkServerEntity?> _networkServerFor(Playlist playlist) async {
    final serverId = playlist.networkServerId;
    if (serverId == null) return null;
    return Database.networkServers.get(serverId);
  }

  /// The remote song id for [songId], only when the song belongs to the same
  /// server as [playlist]. Null when untranslatable (local song, other server,
  /// or unknown id).
  Future<String?> _remoteIdForSong(Playlist playlist, String songId) async {
    final songs = await _repo.getAllSongs();
    for (final song in songs) {
      if (song.id == songId) {
        if (song.remoteId != null &&
            song.remoteServerId == playlist.networkServerId) {
          return song.remoteId;
        }
        return null;
      }
    }
    return null;
  }

  Future<PlaylistImportResult?> importM3uPlaylist() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Playlist import is currently supported on Android only.',
      );
    }

    if (_importInProgress) return null;
    _importInProgress = true;

    try {
      final uri = await _storageChannel.invokeMethod<String>('openDocument', {
        'mimeTypes': _playlistMimeTypes,
      });
      devLog('[PlaylistService] Selected URI: $uri');
      if (uri == null || uri.trim().isEmpty) return null;

      final parsedUri = Uri.tryParse(uri);
      if (parsedUri == null || parsedUri.scheme != 'content') {
        throw FormatException('Invalid document URI returned: $uri');
      }

      final content = await _storageChannel.invokeMethod<String>(
        'readTextDocument',
        {'uri': uri},
      );
      devLog('[PlaylistService] Content length: ${content?.length ?? 0}');
      if (content == null || content.trim().isEmpty) {
        throw const FormatException('Selected playlist file is empty');
      }

      final displayName = await _storageChannel.invokeMethod<String>(
        'getDocumentDisplayName',
        {'uri': uri},
      );
      devLog('[PlaylistService] Display name: $displayName');

      return await _upsertPlaylistFromSource(
        PlaylistSourceFile(sourcePath: uri, displayName: displayName),
        content: content,
      );
    } catch (e, st) {
      devLog('[PlaylistService] Import error: $e');
      devLog('[PlaylistService] Import stack: $st');
      rethrow;
    } finally {
      _importInProgress = false;
    }
  }

  Future<List<PlaylistImportResult>> syncPlaylistsFromSources(
    List<PlaylistSourceFile> sources,
  ) async {
    await _ensureLoaded();
    if (sources.isEmpty) return const [];

    final lookup = await _buildSongLookup();
    final results = <PlaylistImportResult>[];

    for (final source in sources) {
      try {
        final content = await _readPlaylistSource(source.sourcePath);
        if (content.trim().isEmpty) {
          continue;
        }

        final imported = await _upsertPlaylistFromSource(
          source,
          content: content,
          songLookup: lookup,
          saveAfter: false,
        );
        if (imported != null) {
          results.add(imported);
        }
      } catch (e, st) {
        devLog(
          '[PlaylistService] Failed to sync playlist source "${source.sourcePath}": $e',
        );
        devLog('[PlaylistService] Playlist sync stack: $st');
      }
    }

    if (results.isNotEmpty) {
      await _savePlaylists();
    }

    return results;
  }

  Future<PlaylistImportResult?> _upsertPlaylistFromSource(
    PlaylistSourceFile source, {
    required String content,
    _SongLookup? songLookup,
    bool saveAfter = true,
  }) async {
    await _ensureLoaded();

    final baseName = _extractPlaylistNameFromFilename(
      source.displayName ?? _extractPlaylistNameLabel(source.sourcePath),
    );
    final existing = _findPlaylistBySourcePath(source.sourcePath);
    final playlistName = await _nextAvailablePlaylistName(
      baseName,
      excludeId: existing?.id,
    );
    devLog('[PlaylistService] Playlist name: $playlistName');

    final entries = _parseM3uEntries(content);
    devLog('[PlaylistService] Parsed ${entries.length} entries');
    final lookup = songLookup ?? await _buildSongLookup();
    final resolved = _resolveSongIdsWithLookup(entries, lookup);
    devLog(
      '[PlaylistService] Resolved ${resolved.ids.length} songs, ${resolved.unmatchedEntries.length} unmatched',
    );

    final now = DateTime.now();
    late final Playlist playlist;
    if (existing != null) {
      final updated = existing.copyWith(
        name: playlistName,
        songIds: resolved.ids,
        updatedAt: now,
        sourcePath: source.sourcePath,
      );
      final index = _playlists.indexWhere((item) => item.id == existing.id);
      if (index >= 0) {
        _playlists[index] = updated;
      }
      playlist = updated;
    } else {
      playlist = Playlist(
        id: now.millisecondsSinceEpoch.toString(),
        name: playlistName,
        songIds: resolved.ids,
        createdAt: now,
        updatedAt: now,
        sourcePath: source.sourcePath,
      );
      _playlists.add(playlist);
    }

    if (saveAfter) {
      await _savePlaylists();
    }

    return PlaylistImportResult(
      playlist: playlist,
      totalEntries: entries.length,
      importedSongs: resolved.ids.length,
      unmatchedEntries: resolved.unmatchedEntries.length,
      unmatchedSamples: resolved.unmatchedEntries.take(5).toList(),
    );
  }

  Future<PlaylistExportResult?> exportPlaylistAsM3u(
    String playlistId, {
    required bool utf8,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Playlist export is currently supported on Android only.',
      );
    }

    await _ensureLoaded();
    final playlist = await getPlaylist(playlistId);
    if (playlist == null) {
      throw StateError('Playlist not found');
    }

    final extension = utf8 ? 'm3u8' : 'm3u';
    final fileName = '${_sanitizeFileName(playlist.name)}.$extension';
    final documentUri = await _storageChannel.invokeMethod<String>(
      'createDocument',
      {
        'fileName': fileName,
        'mimeType': utf8 ? 'application/vnd.apple.mpegurl' : 'audio/x-mpegurl',
      },
    );
    if (documentUri == null || documentUri.trim().isEmpty) return null;

    final orderedSongs = await _getOrderedSongs(playlist.songIds);
    final content = _buildM3uContent(orderedSongs);
    final success = await _storageChannel.invokeMethod<bool>(
      'writeTextDocument',
      {'uri': documentUri, 'content': content},
    );
    if (success != true) {
      throw const FileSystemException('Failed to write playlist file');
    }

    return PlaylistExportResult(
      fileName: fileName,
      exportedSongs: orderedSongs.length,
      isUtf8: utf8,
    );
  }

  Future<List<Song>> _getOrderedSongs(List<String> songIds) async {
    if (songIds.isEmpty) return [];

    final songs = await _repo.getAllSongs();
    final byId = {for (final song in songs) song.id: song};

    final ordered = <Song>[];
    for (final id in songIds) {
      final song = byId[id];
      if (song != null && song.filePath != null && song.filePath!.isNotEmpty) {
        ordered.add(song);
      }
    }
    return ordered;
  }

  String _buildM3uContent(List<Song> songs) {
    final buffer = StringBuffer()..writeln('#EXTM3U');

    for (final song in songs) {
      final seconds = song.duration.inSeconds;
      final artist = song.artist.trim().isEmpty
          ? 'Unknown Artist'
          : song.artist;
      final title = song.title.trim().isEmpty ? 'Unknown Title' : song.title;

      buffer.writeln('#EXTINF:$seconds,$artist - $title');
      buffer.writeln(song.filePath);
    }

    return buffer.toString();
  }

  Future<String> _nextAvailablePlaylistName(
    String baseName, {
    String? excludeId,
  }) async {
    await _ensureLoaded();
    final trimmed = baseName.trim().isEmpty
        ? 'Imported Playlist'
        : baseName.trim();

    if (!_playlistNameExists(trimmed, excludeId: excludeId)) return trimmed;

    var index = 2;
    while (_playlistNameExists('$trimmed ($index)', excludeId: excludeId)) {
      index += 1;
    }
    return '$trimmed ($index)';
  }

  String _extractPlaylistNameFromFilename(String? name) {
    if (name == null || name.trim().isEmpty) return 'Imported Playlist';
    final trimmed = name.trim();
    final withoutExt = trimmed.replaceFirst(
      RegExp(r'\.(m3u8|m3u)$', caseSensitive: false),
      '',
    );
    return withoutExt.isEmpty ? 'Imported Playlist' : withoutExt;
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) return 'playlist';
    return sanitized;
  }

  List<_M3uEntry> _parseM3uEntries(String content) {
    final sanitizedContent = content.replaceAll('\u0000', '');
    final lines = sanitizedContent.split(RegExp(r'\r\n?|\n'));
    final entries = <_M3uEntry>[];
    String? pendingExtInf;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('\uFEFF')) {
        line = line.substring(1).trim();
      }

      if (line.startsWith('#EXTINF:')) {
        pendingExtInf = _extractExtInfTitle(line);
        continue;
      }

      if (line.startsWith('#')) continue;

      entries.add(
        _M3uEntry(
          pathOrUri: _stripWrappingQuotes(line),
          extInfTitle: pendingExtInf,
        ),
      );
      pendingExtInf = null;
    }

    return entries;
  }

  String? _extractExtInfTitle(String line) {
    final commaIndex = line.indexOf(',');
    if (commaIndex == -1 || commaIndex >= line.length - 1) return null;
    final value = line.substring(commaIndex + 1).trim();
    return value.isEmpty ? null : value;
  }

  Future<_SongLookup> _buildSongLookup() async {
    final songs = await _repo.getAllSongs();
    final byPath = <String, List<Song>>{};
    final byFileName = <String, List<Song>>{};

    for (final song in songs) {
      final filePath = song.filePath;
      if (filePath == null || filePath.trim().isEmpty) continue;

      try {
        for (final key in _pathLookupKeys(filePath)) {
          byPath.putIfAbsent(key, () => []).add(song);
        }
        final fileName = _extractFileName(filePath);
        if (fileName.isNotEmpty) {
          byFileName.putIfAbsent(fileName, () => []).add(song);
        }
      } catch (e, st) {
        devLog(
          '[PlaylistService] Skipping song during import matching: path="$filePath", error=$e',
        );
        devLog('[PlaylistService] Song matching stack: $st');
      }
    }

    return _SongLookup(byPath: byPath, byFileName: byFileName);
  }

  _ResolvedM3uImport _resolveSongIdsWithLookup(
    List<_M3uEntry> entries,
    _SongLookup lookup,
  ) {
    if (entries.isEmpty) {
      return const _ResolvedM3uImport(ids: [], unmatchedEntries: []);
    }

    final ids = <String>[];
    final seen = <String>{};
    final unmatched = <String>[];

    for (final entry in entries) {
      try {
        final pathCandidates = <Song>{};
        for (final key in _pathLookupKeys(entry.pathOrUri)) {
          final matches = lookup.byPath[key];
          if (matches != null) {
            pathCandidates.addAll(matches);
          }
        }

        Song? match = _pickBestCandidate(
          pathCandidates.toList(),
          entry.extInfTitle,
        );
        if (match == null) {
          final candidates =
              lookup.byFileName[_extractFileName(entry.pathOrUri)] ?? [];
          match = _pickBestCandidate(candidates, entry.extInfTitle);
        }

        if (match == null) {
          unmatched.add(entry.pathOrUri);
          continue;
        }

        if (seen.add(match.id)) {
          ids.add(match.id);
        }
      } catch (e, st) {
        devLog(
          '[PlaylistService] Failed to resolve playlist entry: "${entry.pathOrUri}", error=$e',
        );
        devLog('[PlaylistService] Entry matching stack: $st');
        unmatched.add(entry.pathOrUri);
      }
    }

    return _ResolvedM3uImport(ids: ids, unmatchedEntries: unmatched);
  }

  Playlist? _findPlaylistBySourcePath(String sourcePath) {
    try {
      return _playlists.firstWhere(
        (playlist) => playlist.sourcePath == sourcePath,
      );
    } catch (_) {
      return null;
    }
  }

  Song? _pickBestCandidate(List<Song> candidates, String? extInfTitle) {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    if (extInfTitle == null || extInfTitle.trim().isEmpty) return null;

    final normalizedExt = _normalizeSearchText(extInfTitle);
    for (final candidate in candidates) {
      final combined = _normalizeSearchText(
        '${candidate.artist} - ${candidate.title}',
      );
      if (combined == normalizedExt || combined.contains(normalizedExt)) {
        return candidate;
      }
    }

    // EXTINF often has "Artist - Title", but some lists contain only title.
    final titleOnly = normalizedExt.contains('-')
        ? normalizedExt.split('-').last.trim()
        : normalizedExt;
    for (final candidate in candidates) {
      final songTitle = _normalizeSearchText(candidate.title);
      if (songTitle == titleOnly || songTitle.contains(titleOnly)) {
        return candidate;
      }
    }

    return null;
  }

  String _normalizePath(String value) {
    var normalized = _stripWrappingQuotes(value.trim());
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1);
    }

    normalized = normalized.replaceAll('\\', '/');
    normalized = normalized.split('#').first;
    normalized = normalized.split('?').first;

    final uri = _tryParseUri(normalized);
    if (uri != null && uri.scheme == 'file') {
      try {
        normalized = uri.toFilePath();
      } catch (_) {
        normalized = uri.path;
      }
      normalized = normalized.replaceAll('\\', '/');
    } else {
      normalized = _decodeUriSafely(normalized);
    }

    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized.toLowerCase();
  }

  String _extractFileName(String value) {
    var normalized = _stripWrappingQuotes(value.trim());
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1);
    }

    final uri = _tryParseUri(normalized);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      normalized = uri.pathSegments.last;
    } else {
      normalized = normalized.replaceAll('\\', '/');
      final index = normalized.lastIndexOf('/');
      if (index >= 0 && index < normalized.length - 1) {
        normalized = normalized.substring(index + 1);
      }
    }

    normalized = _decodeUriSafely(normalized);
    normalized = normalized.replaceAll('\\', '/');

    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < normalized.length - 1) {
      normalized = normalized.substring(slashIndex + 1);
    }

    final colonIndex = normalized.lastIndexOf(':');
    if (colonIndex >= 0 && colonIndex < normalized.length - 1) {
      normalized = normalized.substring(colonIndex + 1);
    }

    return normalized.toLowerCase().trim();
  }

  List<String> _pathLookupKeys(String value) {
    final keys = <String>{};

    void addKey(String candidate) {
      final normalized = _normalizePath(candidate);
      if (normalized.isEmpty) return;

      keys.add(normalized);
      final segments = normalized
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();
      for (var count = 2; count <= 4; count += 1) {
        if (segments.length < count) continue;
        keys.add(segments.sublist(segments.length - count).join('/'));
      }
    }

    addKey(value);

    final decodedDocumentPath = _extractDocumentPath(value);
    if (decodedDocumentPath != null && decodedDocumentPath.isNotEmpty) {
      addKey(decodedDocumentPath);
    }

    return keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  }

  String? _extractDocumentPath(String value) {
    final uri = _tryParseUri(value.trim());
    if (uri == null) return null;

    if (uri.scheme == 'file') {
      try {
        return uri.toFilePath();
      } catch (_) {
        return uri.path;
      }
    }

    if (uri.pathSegments.isEmpty) return null;

    final decoded = _decodeUriSafely(uri.pathSegments.last);
    final colonIndex = decoded.indexOf(':');
    if (colonIndex >= 0 && colonIndex < decoded.length - 1) {
      return decoded.substring(colonIndex + 1);
    }

    return decoded;
  }

  String _stripWrappingQuotes(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 2) return trimmed;

    final startsWithDouble = trimmed.startsWith('"') && trimmed.endsWith('"');
    final startsWithSingle = trimmed.startsWith("'") && trimmed.endsWith("'");
    if (!startsWithDouble && !startsWithSingle) {
      return trimmed;
    }

    return trimmed.substring(1, trimmed.length - 1).trim();
  }

  Uri? _tryParseUri(String value) {
    try {
      final uri = Uri.parse(value);
      const allowedSchemes = {'file', 'content', 'http', 'https'};
      if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
        return null;
      }
      return uri;
    } on FormatException catch (e) {
      devLog('[PlaylistService] URI parse error for "$value": $e');
      return null;
    }
  }

  String _decodeUriSafely(String value) {
    if (!value.contains('%')) return value;
    try {
      return Uri.decodeFull(value);
    } on FormatException catch (e) {
      devLog('[PlaylistService] URI decode error for "$value": $e');
      return value;
    } on ArgumentError {
      // Raw UTF-8 (non-percent-encoded) input — Uri.decodeFull rejects it.
      return value;
    }
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
  }

  String _extractPlaylistNameLabel(String value) {
    final trimmed = _stripWrappingQuotes(value.trim());
    if (trimmed.isEmpty) return 'Imported Playlist';

    final uri = _tryParseUri(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return _decodeUriSafely(uri.pathSegments.last);
    }

    final normalized = trimmed.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index >= 0 && index < normalized.length - 1) {
      return normalized.substring(index + 1);
    }
    return normalized;
  }

  Future<String> _readPlaylistSource(String sourcePath) async {
    final uri = Uri.tryParse(sourcePath);
    if (uri != null && uri.scheme == 'content') {
      final content = await _storageChannel.invokeMethod<String>(
        'readTextDocument',
        {'uri': sourcePath},
      );
      if (content == null) {
        throw const FormatException('Selected playlist file is empty');
      }
      return content;
    }

    return File(sourcePath).readAsString();
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_playlistsKey, jsonString);
  }

  Future<void> clearAll() async {
    _playlists.clear();
    await _savePlaylists();
  }
}

class _M3uEntry {
  final String pathOrUri;
  final String? extInfTitle;

  const _M3uEntry({required this.pathOrUri, this.extInfTitle});
}

class _ResolvedM3uImport {
  final List<String> ids;
  final List<String> unmatchedEntries;

  const _ResolvedM3uImport({required this.ids, required this.unmatchedEntries});
}

class _SongLookup {
  final Map<String, List<Song>> byPath;
  final Map<String, List<Song>> byFileName;

  const _SongLookup({required this.byPath, required this.byFileName});
}
