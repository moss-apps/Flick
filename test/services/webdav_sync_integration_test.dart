import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/data/database.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/services/network_cache_service.dart';
import 'package:flick/services/sources/webdav_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

const _serverId = 42;

typedef _Entry = ({String href, bool collection, int? size});

String _multistatus(List<_Entry> entries) {
  final buffer = StringBuffer('<?xml version="1.0"?>')
    ..write('<D:multistatus xmlns:D="DAV:">');
  for (final e in entries) {
    final type = e.collection
        ? '<D:resourcetype><D:collection/></D:resourcetype>'
        : '<D:resourcetype/>';
    final length =
        e.size == null ? '' : '<D:getcontentlength>${e.size}</D:getcontentlength>';
    buffer.write('<D:response><D:href>${e.href}</D:href>'
        '<D:propstat><D:prop>$type$length</D:prop></D:propstat></D:response>');
  }
  buffer.write('</D:multistatus>');
  return buffer.toString();
}

const _Entry _rootSelf =
    (href: '/music/', collection: true, size: null);
const _Entry _albumSelf =
    (href: '/music/Album%20One/', collection: true, size: null);
const _Entry _japanese = (
  href: '/music/%E7%85%A7%E4%BA%95%E9%A0%86%E6%94%BF%20-%20Delirious.flac',
  collection: false,
  size: 111,
);
const _Entry _percent =
    (href: '/music/100%25%20Real.flac', collection: false, size: 222);
const _Entry _what =
    (href: '/music/Album%20One/What%3F.flac', collection: false, size: 333);
const _Entry _cover =
    (href: '/music/Album%20One/cover.jpg', collection: false, size: 444);

String? _isarCorePath() {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null && File(override).existsSync()) return override;

  final abi = Abi.current();
  final fileName = switch (abi) {
    Abi.linuxX64 ||
    Abi.linuxArm ||
    Abi.linuxArm64 =>
      'libisar.so',
    Abi.macosX64 || Abi.macosArm64 => 'libisar.dylib',
    Abi.windowsX64 => 'isar.dll',
    _ => null,
  };
  if (fileName == null) return null;
  final platformDir = Platform.operatingSystem;

  final pubCache = Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['HOME'] ?? '', '.pub-cache');
  final hosted = Directory(p.join(pubCache, 'hosted', 'pub.dev'));
  if (!hosted.existsSync()) return null;

  final candidates = hosted
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .where((name) => name.startsWith('isar_community_flutter_libs-'))
      .toList()
    ..sort();
  for (final name in candidates.reversed) {
    final path = p.join(hosted.path, name, platformDir, fileName);
    if (File(path).existsSync()) return path;
  }
  return null;
}

void main() async {
  final corePath = _isarCorePath();
  late Directory tempDir;
  late Isar isar;

  if (corePath != null) {
    Isar.initializeIsarCore(libraries: {Abi.current(): corePath});
    tempDir = await Directory.systemTemp.createTemp('flick_webdav_sync');
    isar = await Isar.open(
      [
        SongEntitySchema,
        FolderEntitySchema,
        RecentlyPlayedEntitySchema,
        ArtistEntitySchema,
        SongAudioCacheEntitySchema,
        NetworkServerEntitySchema,
      ],
      directory: tempDir.path,
      name: 'webdav_sync_test',
    );
  }

  setUp(() async {
    if (corePath == null) return;
    await isar.writeTxn(() => isar.clear());
  });

  tearDownAll(() async {
    if (corePath == null) return;
    await isar.close();
    await tempDir.delete(recursive: true);
  });

  NetworkServerEntity server() {
    final entity = NetworkServerEntity()
      ..id = _serverId
      ..label = 'Test Dav'
      ..protocol = 'webdav'
      ..baseUrl = 'https://dav.example.com/music'
      ..username = 'alice'
      ..token = base64Encode(utf8.encode('secret'));
    return entity;
  }

  MockClient fixtureClient({
    required List<_Entry> rootEntries,
    required List<int> coverBytes,
  }) {
    return MockClient((request) async {
      final path = request.url.pathSegments
          .where((segment) => segment.isNotEmpty)
          .join('/');
      if (request.method == 'PROPFIND') {
        if (path == 'music') {
          return http.Response(_multistatus([_rootSelf, ...rootEntries]), 207);
        }
        if (path == 'music/Album One') {
          return http.Response(_multistatus([_albumSelf, _cover, _what]), 207);
        }
        return http.Response('Not Found', 404);
      }
      if (request.method == 'GET' && path == 'music/Album One/cover.jpg') {
        return http.Response.bytes(coverBytes, 200);
      }
      if (request.method == 'GET') {
        return http.Response.bytes([7, 7, 7, 7], 200);
      }
      return http.Response('Not Found', 404);
    });
  }

  WebdavService service(MockClient client, Directory cacheDir) =>
      WebdavService.create(
        client: client,
        songRepository: SongRepository(isar: isar),
        networkCache: NetworkCacheService(rootDirectory: cacheDir),
      );

  test(
    'syncLibrary imports non-ASCII and special-char names (regression #255)',
    () async {
      final rootEntries = <_Entry>[_albumSelf, _japanese, _percent];
      final client = fixtureClient(rootEntries: rootEntries, coverBytes: [1]);
      final cacheDir = Directory(p.join(tempDir.path, 'cache'));
      final dav = service(client, cacheDir);

      final stale = SongEntity()
        ..filePath = 'webdav://$_serverId/%2Fmusic%2Fstale.flac'
        ..title = 'stale'
        ..artist = 'nobody'
        ..sourceType = 'webdav'
        ..remoteId = '%2Fmusic%2Fstale.flac'
        ..remoteServerId = _serverId
        ..dateAdded = DateTime.now()
        ..lastModified = DateTime.now();
      await isar.writeTxn(() => isar.songEntitys.put(stale));
      await isar.writeTxn(() => isar.networkServerEntitys.put(server()));

      final progress = await dav.syncLibrary(server()).toList();
      expect(progress.last.isComplete, isTrue);
      expect(progress.last.songsFound, 3);

      final songs = await SongRepository(isar: isar)
          .getSongsByRemoteServer(_serverId);
      expect(songs.map((s) => s.title), containsAll(['照井順政 - Delirious', '100% Real', 'What?']));
      expect(songs.any((s) => s.title == 'stale'), isFalse);

      final japanese =
          songs.firstWhere((s) => s.title == '照井順政 - Delirious');
      expect(japanese.album, 'music');
      expect(japanese.fileType, 'flac');
      expect(japanese.fileSize, 111);

      final what = songs.firstWhere((s) => s.title == 'What?');
      expect(what.album, 'Album One');
      expect(what.albumArtPath, isNotNull);
      expect(what.albumArtPath, startsWith('webdav-cover://'));

      final marker = what.albumArtPath!.substring('webdav-cover://'.length);
      expect(await dav.getCoverArt(server(), marker), [1]);

      final stored = await isar.networkServerEntitys.get(_serverId);
      expect(stored!.lastSyncedAt, isNotNull);

      final cached =
          await dav.stream(server(), japanese.remoteId!, extension: 'flac');
      expect(await File(cached).readAsBytes(), [7, 7, 7, 7]);

      rootEntries.remove(_percent);
      final second = await dav.syncLibrary(server()).toList();
      expect(second.last.songsFound, 2);
      final afterSecond = await SongRepository(isar: isar)
          .getSongsByRemoteServer(_serverId);
      expect(afterSecond.map((s) => s.title),
          containsAll(['照井順政 - Delirious', 'What?']));
      expect(afterSecond.any((s) => s.title == '100% Real'), isFalse);
    },
    skip: corePath == null ? 'Isar core library not found' : false,
  );
}
