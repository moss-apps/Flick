import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/utils/app_log.dart';
import '../../data/entities/network_server_entity.dart';
import '../../data/entities/song_entity.dart';
import '../../data/repositories/song_repository.dart';
import '../library_scanner_service.dart' show ScanProgress;
import '../network_cache_service.dart';
import '../../src/rust/api/smb_api.dart';
import 'network_source_service.dart';
import 'smb_failure.dart';
import 'package:flick/l10n/l10n.dart';

/// SMB2/3 client backed by the pure-Rust `smb2` crate (via flutter_rust_bridge).
///
/// Auth: NTLM needs the recoverable password, so [NetworkServerEntity.token]
/// stores `base64(password)` (not a hash) — same tradeoff as WebDAV.
///
/// Metadata limitation: SMB exposes only filename + size + mtime. Title is
/// derived from the filename, album from the parent folder, artist from the
/// grandparent (or Unknown). Full tag extraction would require downloading each
/// file. Duration/format are backfilled after a track is cached for playback.
typedef SmbDownloader =
    Stream<SmbProgress> Function({
      required String host,
      required int port,
      required String share,
      required String path,
      required String user,
      required String pass,
      required String destPath,
    });

typedef SmbConnectionTest =
    Future<void> Function({
      required String host,
      required int port,
      required String share,
      required String user,
      required String pass,
      required String rootPath,
    });

class SmbService implements NetworkSourceService {
  SmbService._({
    SongRepository? songRepository,
    NetworkCacheService? networkCache,
    SmbDownloader? downloader,
    SmbConnectionTest? connectionTest,
  }) : _songRepository = songRepository,
       _networkCache = networkCache,
       _downloader = downloader ?? smbDownloadFile,
       _connectionTest = connectionTest ?? smbPing;

  static SmbService instance = SmbService._();

  @visibleForTesting
  factory SmbService.create({
    required NetworkCacheService networkCache,
    required SmbDownloader downloader,
    SmbConnectionTest? connectionTest,
  }) => SmbService._(
    networkCache: networkCache,
    downloader: downloader,
    connectionTest: connectionTest,
  );

  final SmbDownloader _downloader;
  final SmbConnectionTest _connectionTest;
  final _downloads = <(int, String), _SmbDownload>{};

  static const _audioExtensions = {
    'flac',
    'mp3',
    'm4a',
    'wav',
    'ogg',
    'opus',
    'aac',
    'wv',
    'ape',
    'mpc',
    'aiff',
    'dsf',
    'dff',
  };
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'};
  static const _coverNames = ['cover', 'folder', 'album', 'albumart', 'front'];

  SongRepository? _songRepository;
  NetworkCacheService? _networkCache;

  SongRepository get _repo => _songRepository ??= SongRepository();
  NetworkCacheService get _cache => _networkCache ??= NetworkCacheService();

  String? _lastPingError;

  @override
  String? get lastPingError => _lastPingError;

  @override
  String get protocol => NetworkProtocol.smb;

  @override
  String get coverScheme => 'smb-cover://';

  // --- Auth + URL parsing -------------------------------------------------

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    // NTLM needs the recoverable password.
    return password.isEmpty ? null : base64Encode(utf8.encode(password));
  }

  String _password(NetworkServerEntity server) {
    if (server.token == null || server.token!.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(server.token!));
    } catch (_) {
      return '';
    }
  }

  ({String host, int port, String share, String rootPath}) _parseServer(
    NetworkServerEntity server,
  ) => parseServerUrl(server.baseUrl);

  /// Parse a saved server URL into host/port/share/root. Accepts both
  /// `smb://host/share/path` and the Windows form `\\host\share\path`.
  /// Throws [FormatException] with user-facing text when the host or share is
  /// missing; the edit screen shows it in the failure banner.
  static ({String host, int port, String share, String rootPath})
  parseServerUrl(String url) {
    var source = url.trim();
    if (source.startsWith(r'\\')) {
      source = 'smb://${source.substring(2).replaceAll(r'\', '/')}';
    }
    // Uri's FormatException can echo the entire input (including credentials).
    // Replace it rather than forwarding parser text to a banner or scan log.
    late Uri uri;
    late List<String> segments;
    late int port;
    try {
      uri = Uri.parse(source);
      segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      port = uri.hasPort ? uri.port : 445;
    } on FormatException {
      throw _SmbUrlException(l10n.smbInvalidServerUrl);
    }
    if (uri.scheme != 'smb' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        port < 1 ||
        port > 65535) {
      throw _SmbUrlException(l10n.smbInvalidServerUrl);
    }
    if (uri.host.isEmpty) {
      throw _SmbUrlException(l10n.smbMissingServerAddress);
    }
    if (segments.isEmpty) {
      throw _SmbUrlException(l10n.smbMissingShareName);
    }
    return (
      host: uri.host,
      port: port,
      share: segments.first,
      rootPath: segments.length > 1 ? segments.skip(1).join('/') : '',
    );
  }

  // --- ping ---------------------------------------------------------------

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    _lastPingError = null;
    final clock = Stopwatch()..start();
    try {
      final s = _parseServer(server);
      await _connectionTest(
        host: s.host,
        port: s.port,
        share: s.share,
        user: server.username ?? '',
        pass: _password(server),
        rootPath: s.rootPath,
      );
      AppLog.instance.add(
        'SMB stage=root result=ok elapsed_ms=${clock.elapsedMilliseconds}',
      );
      return true;
    } catch (e) {
      _lastPingError = e is _SmbUrlException ? e.message : describePingError(e);
      final failure = e is FormatException
          ? const SmbFailure('url', 'protocol')
          : SmbFailure.from(e, stage: 'connect');
      AppLog.instance.add(
        '$failure result=failed elapsed_ms=${clock.elapsedMilliseconds}',
      );
      return false;
    }
  }

  /// Turn a native error into safe, actionable guidance (never raw text).
  static String describePingError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('authentication failed') ||
        lower.contains('logon_failure')) {
      return l10n.smbAuthFailed;
    }
    if (lower.contains('bad_network_name') ||
        lower.contains('name_not_found')) {
      return l10n.smbShareNotFound;
    }
    if (lower.contains('access_denied') || lower.contains('access denied')) {
      return l10n.smbAccessDenied;
    }
    if (lower.contains('lookup') ||
        lower.contains('resolve') ||
        lower.contains('name or service not known')) {
      return l10n.smbHostNotResolved;
    }
    if (lower.contains('timed out')) {
      return l10n.smbTimedOut;
    }
    if (lower.contains('connection refused')) {
      return l10n.smbConnectionRefused;
    }
    if (lower.contains('could not connect') ||
        lower.contains('unreachable') ||
        lower.contains('no route')) {
      return l10n.smbCouldNotReach;
    }
    if (lower.contains('server stopped answering') ||
        lower.contains('unresponsive')) {
      return l10n.smbServerUnresponsive;
    }
    return SmbFailure.from(error, stage: 'connect').message;
  }

  // --- Cover art + stream -------------------------------------------------

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    final path = utf8.decode(base64Decode(marker));
    final s = _parseServer(server);
    return await smbReadFile(
      host: s.host,
      port: s.port,
      share: s.share,
      path: path,
      user: server.username ?? '',
      pass: _password(server),
    );
  }

  @override
  Future<String> stream(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
    void Function(double progress)? onProgress,
  }) async {
    // Playback, prefetch and gapless preparation must share a single writer.
    final key = (server.id, remoteId);
    final job = _downloads.putIfAbsent(key, () => _SmbDownload());
    if (onProgress != null) job.listeners.add(onProgress);
    // Tie map cleanup to the transfer itself, not to whichever caller happens
    // to stop waiting first. A caller can bail out (e.g. a UI progress
    // callback throws, or the screen is disposed) while the shared transfer is
    // still running; dropping the map entry there would let the next caller
    // start a second download for the same file.
    job.future ??= _download(server, remoteId, extension, job).whenComplete(() {
      if (identical(_downloads[key], job)) _downloads.remove(key);
    });
    try {
      final progress = job.progress;
      if (onProgress != null && progress != null) {
        _notifyProgress(onProgress, progress);
      }
      return await job.future!;
    } finally {
      if (onProgress != null) job.listeners.remove(onProgress);
    }
  }

  /// Progress callbacks belong to the UI, never to the transfer. Letting one
  /// throw would abort the shared download and delete a file other callers are
  /// waiting on.
  void _notifyProgress(void Function(double) listener, double progress) {
    try {
      listener(progress);
    } catch (_) {
      /* A broken progress listener must not fail playback. */
    }
  }

  Future<String> _download(
    NetworkServerEntity server,
    String remoteId,
    String? extension,
    _SmbDownload job,
  ) async {
    // Old versions wrote interrupted transfers to the final filename. A new
    // SMB-only key bypasses those entries without wiping other protocols/data.
    final cacheId = 'smb-v2:$remoteId';
    // Callers may omit the extension (prefetch) or pass a different case.
    // Derive it from the remote name so every caller resolves the same file.
    final cacheExtension = _cacheExtension(extension, remoteId);
    String? destPath;
    final clock = Stopwatch()..start();
    var received = 0;
    var total = 0;
    try {
      final cached = await _cache.getPath(
        server.id,
        cacheId,
        extension: cacheExtension,
      );
      if (cached != null) return cached;
      final s = _parseServer(server);
      destPath = await _cache.pathFor(
        server.id,
        cacheId,
        extension: cacheExtension,
      );
      var complete = false;
      await for (final p in _downloader(
        host: s.host,
        port: s.port,
        share: s.share,
        path: remoteId,
        user: server.username ?? '',
        pass: _password(server),
        destPath: destPath,
      )) {
        received = p.received.toInt();
        total = p.total.toInt();
        if (complete || received < 0 || received > total) {
          throw const SmbFailure('download', 'incomplete');
        }
        complete = p.isComplete && received == total && total > 0;
        if (total > 0) {
          job.progress = received / total;
          for (final listener in List.of(job.listeners)) {
            _notifyProgress(listener, job.progress!);
          }
        }
      }
      if (!complete || await File(destPath).length() != total) {
        throw const SmbFailure('download', 'incomplete');
      }
      // The download is already complete and playable. Cache accounting is
      // best-effort: a failure to evict old entries must not turn a successful
      // transfer into a failed playback.
      try {
        await _cache.completeDownload(destPath);
      } catch (_) {
        AppLog.instance.add('SMB stage=cache code=storage result=failed');
      }
      AppLog.instance.add(
        'SMB stage=download result=ok received=$received total=$total elapsed_ms=${clock.elapsedMilliseconds}',
      );
      return destPath;
    } catch (e) {
      if (destPath != null) {
        try {
          final file = File(destPath);
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          /* Best effort: native staging already isolates partials. */
        }
      }
      final failure = e is FileSystemException
          ? const SmbFailure('cache', 'storage')
          : SmbFailure.from(e);
      AppLog.instance.add(
        '$failure result=failed received=$received total=$total elapsed_ms=${clock.elapsedMilliseconds}',
      );
      throw failure;
    }
  }

  @override
  Future<({String url, Map<String, String> headers})?> streamDescriptor(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
  }) async => null;

  // --- Library walk -------------------------------------------------------

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    final s = _parseServer(server);
    final user = server.username ?? '';
    final pass = _password(server);

    // Remember the sizes of already-listed rows so a replaced file invalidates
    // its cached bytes as well as its metadata. SMB listings expose size only.
    final previousSizes = <String, int>{};
    for (final song in await _repo.getSongsByRemoteServer(server.id)) {
      final remoteId = song.remoteId;
      final size = song.fileSize;
      if (remoteId != null && size != null) previousSizes[remoteId] = size;
    }

    // Collect file entries grouped by parent directory (for per-folder
    // cover/audio classification), yielding progress as the walk streams in.
    final byDir = <String, List<SmbEntry>>{};
    var totalEntries = 0;
    Object? walkError;
    StackTrace? walkStackTrace;
    try {
      await for (final entry in smbListShare(
        host: s.host,
        port: s.port,
        share: s.share,
        user: user,
        pass: pass,
        rootPath: s.rootPath,
      )) {
        totalEntries++;
        if (!entry.isDir) {
          final parent = _parentDir(entry.path);
          (byDir[parent] ??= <SmbEntry>[]).add(entry);
        }
        if (totalEntries % 500 == 0) {
          yield ScanProgress(
            songsFound: 0,
            totalFiles: totalEntries,
            filesProcessed: totalEntries,
            phase: 'Syncing ${server.label}',
            currentFile: entry.name,
          );
        }
      }
    } catch (e, stackTrace) {
      // A connection drop halfway through the tree must not throw away the
      // entries already collected. Import them below, but never purge rows we
      // simply did not reach, then surface the incomplete scan to the caller.
      walkError = e;
      walkStackTrace = stackTrace;
      final failure = SmbFailure.from(e);
      AppLog.instance.add('$failure result=partial entries=$totalEntries');
    }

    final syncedRemoteIds = <String>{};
    var songsFound = 0;
    for (final dirPath in byDir.keys) {
      final entries = byDir[dirPath]!;
      String? coverPath;
      final songEntries = <SmbEntry>[];
      for (final e in entries) {
        if (_isCoverName(e.name)) {
          coverPath ??= e.path;
        } else if (_isAudio(e.name)) {
          songEntries.add(e);
        }
      }
      if (songEntries.isEmpty) continue;

      final album = _lastPathSegment(dirPath);
      final artist = _grandparentSegment(dirPath);
      final entities = songEntries
          .map(
            (e) => _songEntity(
              server: server,
              entry: e,
              remoteId: e.path,
              album: album,
              artist: artist,
              coverPath: coverPath,
            ),
          )
          .toList();
      // Drop bytes cached for a file whose size changed so playback cannot
      // serve the previous version. Do this before persisting the new size:
      // if the process stops in between, the next sync still sees the old
      // listing size and repeats the cleanup instead of accepting stale bytes.
      for (final e in songEntries) {
        final previous = previousSizes[e.path];
        if (previous != null && previous != e.size.toInt()) {
          try {
            await _cache.remove(server.id, 'smb-v2:${e.path}');
          } catch (_) {
            AppLog.instance.add('SMB stage=cache code=storage result=failed');
          }
        }
      }
      await _repo.upsertSmbSongs(entities);
      syncedRemoteIds.addAll(entities.map((e) => e.remoteId!));
      songsFound += entities.length;
    }

    if (walkError != null) {
      // Imported rows stay; no purge or lastSyncedAt stamp for an incomplete
      // walk, because unseen files are not stale.
      Error.throwWithStackTrace(walkError, walkStackTrace!);
    }

    await purgeAndStampNetworkSync(server, syncedRemoteIds);

    yield ScanProgress(
      songsFound: songsFound,
      totalFiles: totalEntries,
      filesProcessed: totalEntries,
      phase: 'Syncing ${server.label}',
      isComplete: true,
    );
  }

  SongEntity _songEntity({
    required NetworkServerEntity server,
    required SmbEntry entry,
    required String remoteId,
    required String album,
    required String artist,
    required String? coverPath,
  }) {
    final fileName = entry.name;
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot + 1).toLowerCase() : null;
    return SongEntity()
      ..filePath = '${NetworkProtocol.smb}://${server.id}/$remoteId'
      ..title = baseName.replaceAll(RegExp(r'^\d+[.\-\s]+'), '')
      ..artist = artist
      ..album = album.isEmpty ? null : album
      ..fileSize = entry.size.toInt()
      ..fileType = ext
      ..albumArtPath = coverPath != null
          ? '$coverScheme${base64Encode(utf8.encode(coverPath))}'
          : null
      ..sourceType = NetworkProtocol.smb
      ..remoteId = remoteId
      ..remoteServerId = server.id
      ..metadataComplete = true
      ..dateAdded = DateTime.now()
      ..lastModified = DateTime.now();
  }

  String _parentDir(String path) {
    final slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(0, slash) : '';
  }

  bool _isAudio(String name) {
    final ext = _extension(name);
    return ext != null && _audioExtensions.contains(ext);
  }

  bool _isCoverName(String name) {
    final ext = _extension(name);
    if (ext == null || !_imageExtensions.contains(ext)) return false;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0
        ? name.substring(0, dot).toLowerCase()
        : name.toLowerCase();
    return _coverNames.any((c) => stem == c || stem.startsWith('$c.'));
  }

  String? _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  /// Prefer the caller's extension, but normalize it and fall back to the
  /// remote filename. This keeps `.bin` out of the cache when a caller omits
  /// the hint, and lets callers that pass `FLAC` share the file cached as
  /// `flac` instead of downloading it twice.
  String? _cacheExtension(String? extension, String remoteId) {
    String? clean(String? value) {
      var candidate = value?.trim().toLowerCase();
      if (candidate == null) return null;
      candidate = candidate.replaceFirst(RegExp(r'^\.+'), '');
      if (candidate.isEmpty ||
          candidate == 'unknown' ||
          !RegExp(r'^[a-z0-9]+$').hasMatch(candidate)) {
        return null;
      }
      return candidate;
    }

    final provided = clean(extension);
    if (provided != null) return provided;
    final slash = remoteId.lastIndexOf('/');
    final name = slash >= 0 ? remoteId.substring(slash + 1) : remoteId;
    return clean(_extension(name));
  }

  String _lastPathSegment(String path) {
    var p = path;
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    final slash = p.lastIndexOf('/');
    return slash >= 0 ? p.substring(slash + 1) : p;
  }

  String _grandparentSegment(String path) {
    var p = path;
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    final slash = p.lastIndexOf('/');
    if (slash <= 0) return 'Unknown';
    final parent = p.substring(0, slash);
    final artist = _lastPathSegment(parent);
    return artist.isEmpty ? 'Unknown' : artist;
  }
}

class _SmbDownload {
  Future<String>? future;
  double? progress;
  final listeners = <void Function(double)>[];
}

/// Only constructed with fixed localized copy, never with parser/native text.
class _SmbUrlException extends FormatException {
  _SmbUrlException(super.message);
}
