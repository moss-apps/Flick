import 'dart:io';

import 'package:flick/core/constants/metadata_constants.dart';
import 'package:flick/data/entities/folder_entity.dart';
import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/data/repositories/folder_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:flick/services/playlist_service.dart';
import 'package:flick/src/rust/api/scanner.dart';
import 'package:flick/src/rust/frb_generated.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storage = MethodChannel('com.mossapps.flick/storage');
const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
const _provider = 'content://com.android.externalstorage.documents';
const _root = '$_provider/tree/primary%3AMusic';
const _albumUri = '$_root/document/primary%3AMusic%2Falbum.flac';
const _cueUri = '$_root/document/primary%3AMusic%2Falbum.cue';
const _rawRoot = '/storage/emulated/0/Music';
const _rawAlbum = '$_rawRoot/album.flac';
const _rawSong = '$_rawRoot/track.flac';
const _songUri = '$_root/document/primary%3AMusic%2Ftrack.flac';
const _size = 1000000;
const _timestamp = 1700000000000;

Map<String, Object> _listing({
  bool accessible = true,
  bool complete = true,
  List<Map<String, Object>> files = const [],
}) => {'rootAccessible': accessible, 'complete': complete, 'files': files};

Map<String, Object> _file(String uri, String name) => {
  'uri': uri,
  'name': name,
  'extension': name.split('.').last,
  'size': _size,
  'lastModified': _timestamp,
  'relativeFolderPath': '',
};

Map<String, Object> _indexedTrack(String path, {int mediaId = 1}) => {
  ..._file(
    'content://media/external/audio/media/$mediaId',
    path.split('/').last,
  ),
  'filePath': path,
  'duration': 60000,
  'sampleRate': 96000,
  'bitDepth': 24,
  'bitrate': '900000',
  'metadataRead': true,
};

FolderEntity _folder(String uri, String name) => FolderEntity()
  ..uri = uri
  ..displayName = name
  ..dateAdded = DateTime(2025)
  ..mediaStoreVolume = 'external'
  ..volumeState = 'mounted';

SongEntity _song(int id, String path, {int? offset}) => SongEntity()
  ..id = id
  ..filePath = path
  ..mediaStoreUri = path.startsWith('content://') ? path : null
  ..folderUri = _root
  ..startOffsetMs = offset
  ..title = 'Edited $id'
  ..artist = 'Artist'
  ..hasLocalEdits = true
  ..dateAdded = DateTime(2025)
  ..lastModified = DateTime.fromMillisecondsSinceEpoch(_timestamp)
  ..fileSize = _size
  ..fileType = 'FLAC'
  ..durationMs = 60000
  ..sampleRate = 96000
  ..bitrate = 900
  ..metadataComplete = true
  ..metadataVersion = kCurrentTrackMetadataVersion;

class _Songs implements SongRepository {
  _Songs(List<SongEntity> songs)
    : rows = {for (final song in songs) song.id: song};

  final Map<int, SongEntity> rows;
  final deleted = <int>[];
  var _nextId = 100;

  @override
  Future<List<SongEntity>> getSongEntitiesByFolder(String folderUri) async =>
      rows.values.where((song) => song.folderUri == folderUri).toList();

  @override
  Future<int> countSongsInFolder(String folderUri) async =>
      (await getSongEntitiesByFolder(folderUri)).length;

  @override
  Future<int> getSongCount() async => rows.length;

  @override
  Future<void> upsertSongs(List<SongEntity> entities) async {
    for (final entity in entities) {
      for (final song in rows.values) {
        if (song.filePath == entity.filePath &&
            song.startOffsetMs == entity.startOffsetMs) {
          entity.id = song.id;
          break;
        }
      }
      if (entity.id == SongEntity().id) entity.id = _nextId++;
      rows[entity.id] = entity;
    }
  }

  @override
  Future<void> deleteSongsByIds(List<int> ids) async {
    deleted.addAll(ids);
    rows.removeWhere((id, _) => ids.contains(id));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Folders implements FolderRepository {
  _Folders(this.rows);

  final List<FolderEntity> rows;

  @override
  Future<List<FolderEntity>> getAllFolders() async => rows;

  @override
  Future<FolderEntity?> getFolderByUri(String uri) async =>
      rows.where((folder) => folder.uri == uri).firstOrNull;

  @override
  Future<void> updateFolderScanInfo(String uri, int songCount) async {
    (await getFolderByUri(uri))?.songCount = songCount;
  }

  @override
  Future<void> updateFolderVolumeState(String uri, String state) async {
    (await getFolderByUri(uri))?.volumeState = state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playlists implements PlaylistService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScannerApi implements RustLibApi {
  _ScannerApi({this.scan, this.extract});

  final Stream<ScanChunk> Function(String, Map<String, int>)? scan;
  final Future<AudioFileMetadata?> Function(String)? extract;

  @override
  Stream<ScanChunk> crateApiScannerScanMusicLibrary({
    required String rootPath,
    required Map<String, int> knownFiles,
    required ScanOptions scanOptions,
  }) => scan!(rootPath, knownFiles);

  @override
  Future<AudioFileMetadata?> crateApiScannerExtractFileMetadata({
    required String path,
  }) => extract!(path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    messenger.setMockMethodCallHandler(_storage, null);
    messenger.setMockMethodCallHandler(_permissions, null);
  });

  LibraryScannerService scanner(_Songs songs, {List<FolderEntity>? folders}) =>
      LibraryScannerService(
        songRepository: songs,
        folderRepository: _Folders(folders ?? [_folder(_root, 'Music')]),
        playlistService: _Playlists(),
        isAndroid: true,
      );

  void useStorage({
    required Object Function(String) list,
    bool allFilesAccess = false,
    String? fsPath,
    String? Function()? resolvePath,
    int sdkInt = 34,
    Object? Function(MethodCall)? mediaStore,
    Object? Function(MethodCall)? extra,
  }) {
    messenger.setMockMethodCallHandler(_storage, (call) async {
      final uri = call.arguments is Map
          ? call.arguments['uri'] as String?
          : null;
      if (call.method == 'resolveStorageInfo') {
        final removable = uri!.contains('1234-5678');
        return {
          'sdkInt': sdkInt,
          'fsPath': removable
              ? '/storage/1234-5678/Music'
              : (resolvePath != null ? resolvePath() : fsPath ?? _rawRoot),
          'state': removable ? 'mounted_ro' : 'mounted',
          'isRemovable': removable,
          'allFilesAccess': allFilesAccess,
        };
      }
      if (call.method == 'listAudioFiles') return list(uri!);
      // Scoped tests default to an unindexed folder: MediaStore returns
      // nothing and the scanner degrades to the SAF tree.
      if (call.method == 'queryMediaStoreAudio') {
        return mediaStore?.call(call) ?? const <Map<String, Object?>>[];
      }
      if (call.method == 'queryMediaStoreNonAudio') {
        return const <Map<String, Object?>>[];
      }
      if (extra != null) return extra(call);
      throw UnimplementedError(call.method);
    });
  }

  for (final (action, refresh, allFiles) in [
    ('rescan', false, false),
    ('startup refresh', true, false),
    ('startup refresh with All Files Access', true, true),
  ]) {
    for (final (accessible, complete) in [
      (false, false),
      (true, false),
      (true, true),
    ]) {
      final listing = !accessible
          ? 'inaccessible'
          : complete
          ? 'empty'
          : 'partial';
      test('$action: $listing tree and two CUE offsets', () async {
        useStorage(
          list: (_) => _listing(accessible: accessible, complete: complete),
          allFilesAccess: allFiles,
        );
        final songs = _Songs([
          _song(10, _albumUri, offset: 0),
          _song(11, _albumUri, offset: 60000),
          _song(12, _rawSong),
        ]);
        final service = scanner(songs);

        if (refresh) {
          await service.refreshDeletions();
        } else {
          final progress = await service.scanFolder(_root, 'Music').last;
          expect(progress.unavailable, !complete);
          expect(progress.deletedSongs, complete ? 2 : 0);
        }
        expect(
          songs.rows.keys,
          unorderedEquals(complete ? [12] : [10, 11, 12]),
        );
        expect(songs.deleted, unorderedEquals(complete ? [10, 11] : []));
      });
    }
  }

  test(
    'scoped scan migrates CUE offsets and preserves edits during parsing',
    () async {
      useStorage(
        list: (_) => _listing(
          files: [_file(_albumUri, 'album.flac'), _file(_cueUri, 'album.cue')],
        ),
        extra: (call) => switch (call.method) {
          'readTextDocument' =>
            '''
FILE "album.flac" WAVE
  TRACK 01 AUDIO
    TITLE "Original first"
    INDEX 01 00:00:00
  TRACK 02 AUDIO
    TITLE "Original second"
    INDEX 01 01:00:00
''',
          'fetchAudioMetadata' => [
            {
              ..._file(_albumUri, 'album.flac'),
              'duration': 120000,
              'sampleRate': 96000,
              'bitDepth': 24,
              'bitrate': '900000',
              'trackTotal': 2,
              'discTotal': 1,
              'metadataRead': true,
            },
          ],
          _ => throw UnimplementedError(call.method),
        },
      );
      final songs = _Songs([
        _song(10, _rawAlbum, offset: 0),
        _song(11, _rawAlbum, offset: 60000),
      ]);
      final service = scanner(songs);
      final result = await service.scanFolder(_root, 'Music').last;
      await service.awaitArtworkBackfill(_root);

      expect(result.unavailable, isFalse);
      expect(songs.rows.keys, unorderedEquals([10, 11]));
      expect(songs.deleted, isEmpty);
      for (final row in songs.rows.values) {
        expect(row.filePath, _albumUri);
        expect(row.title, 'Edited ${row.id}');
        expect(row.hasLocalEdits, isTrue);
        expect(row.mediaStoreUri, _albumUri);
      }
      expect(songs.rows[10]!.endOffsetMs, 60000);
    },
  );

  test('an unreadable CUE sheet does not replace either track', () async {
    var triedToReadCue = false;
    useStorage(
      list: (_) => _listing(
        files: [_file(_albumUri, 'album.flac'), _file(_cueUri, 'album.cue')],
      ),
      extra: (call) {
        expect(call.method, 'readTextDocument');
        expect(call.arguments, containsPair('uri', _cueUri));
        triedToReadCue = true;
        return null;
      },
    );
    final songs = _Songs([
      _song(10, _albumUri, offset: 0),
      _song(11, _albumUri, offset: 60000),
    ]);
    final result = await scanner(songs).scanFolder(_root, 'Music').last;

    expect(triedToReadCue, isTrue);
    expect(result.unavailable, isTrue);
    expect(songs.rows.keys, unorderedEquals([10, 11]));
    expect(songs.deleted, isEmpty);
  });

  test(
    'All Files Access migrates confirmed SAF paths without replacing IDs',
    () async {
      final cache = await Directory.systemTemp.createTemp('flick-scan-test-');
      addTearDown(() => cache.delete(recursive: true));
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(pathProvider, (_) async => cache.path);
      addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));
      useStorage(
        allFilesAccess: true,
        list: (_) => throw StateError('Expected Rust, not SAF'),
      );
      var nativeScanRan = false;
      RustLib.initMock(
        api: _ScannerApi(
          scan: (root, known) async* {
            nativeScanRan = true;
            expect(root, _rawRoot);
            expect(known, isEmpty);
            yield ScanChunk(
              newOrModified: [
                for (final path in [_rawAlbum, _rawSong])
                  AudioFileMetadata(
                    path: path,
                    title: 'Original tag',
                    format: 'flac',
                    lastModified: _timestamp,
                    fileSize: BigInt.from(_size),
                  ),
              ],
              deletedPaths: const [],
              totalFiles: 2,
              filesWalked: 2,
              filesProcessed: 2,
              isComplete: true,
            );
          },
        ),
      );
      addTearDown(RustLib.dispose);
      final songs = _Songs([
        _song(10, _albumUri, offset: 0),
        _song(11, _albumUri, offset: 60000),
        _song(12, _songUri),
      ]);
      final service = scanner(
        songs,
        folders: [_folder(_root, 'Music')..useDeepScan = true],
      );
      final result = await service.scanFolder(_root, 'Music').last;
      await service.awaitArtworkBackfill(_root);

      expect(nativeScanRan, isTrue);
      expect(result.scanEngine, 'Rust deep scan');
      expect(result.unavailable, isFalse);
      expect(songs.rows.keys, unorderedEquals([10, 11, 12]));
      expect(songs.deleted, isEmpty);
      for (final row in songs.rows.values) {
        expect(row.filePath, row.id == 12 ? _rawSong : _rawAlbum);
        expect(row.title, 'Edited ${row.id}');
        expect(row.hasLocalEdits, isTrue);
      }
    },
  );

  test(
    'Android 11+ scoped folder follows Deep Scan: off MediaStore, on SAF',
    () async {
      var mediaStoreQueries = 0;
      var safWalks = 0;
      useStorage(
        list: (_) {
          safWalks++;
          return _listing(files: [_file(_songUri, 'track.flac')]);
        },
        mediaStore: (call) {
          mediaStoreQueries++;
          return [_indexedTrack(_rawSong)];
        },
      );

      final folder = _folder(_root, 'Music');
      final songs = _Songs([_song(20, _rawSong)]);
      final service = scanner(songs, folders: [folder]);

      final normal = await service.scanFolder(_root, 'Music').last;
      await service.awaitArtworkBackfill(_root);
      expect(normal.scanEngine, 'MediaStore');
      expect(mediaStoreQueries, 1);
      expect(safWalks, 0);
      expect(songs.rows[20]!.filePath, _rawSong);

      folder.useDeepScan = true;
      final deep = await service.scanFolder(_root, 'Music').last;
      await service.awaitArtworkBackfill(_root);
      expect(deep.scanEngine, 'SAF');
      expect(safWalks, greaterThan(0));
      expect(mediaStoreQueries, 1);
      expect(songs.rows[20]!.filePath, _songUri);
    },
  );

  for (final (sdkInt, permission, grant) in [
    (32, Permission.storage, true),
    (34, Permission.audio, true),
    (34, Permission.audio, false),
  ]) {
    test('manual scan on API $sdkInt with permission grant=$grant', () async {
      var granted = false;
      var requests = 0;
      var queries = 0;
      messenger.setMockMethodCallHandler(_permissions, (call) async {
        if (call.method == 'checkPermissionStatus') {
          expect(call.arguments, permission.value);
          return PermissionStatus.denied.index;
        }
        expect(call.method, 'requestPermissions');
        expect(call.arguments, [permission.value]);
        requests++;
        granted = grant;
        final status = grant
            ? PermissionStatus.granted
            : PermissionStatus.denied;
        return {permission.value: status.index};
      });
      useStorage(
        sdkInt: sdkInt,
        resolvePath: () => granted ? _rawRoot : null,
        list: (_) => _listing(),
        mediaStore: (_) {
          queries++;
          expect(granted, isTrue);
          return [_indexedTrack(_rawSong)];
        },
      );
      final service = scanner(_Songs([_song(20, _rawSong)]));

      final result = await service
          .scanFolder(_root, 'Music', promptForMediaAccess: true)
          .last;
      await service.awaitArtworkBackfill(_root);

      expect(requests, 1);
      expect(queries, grant ? 1 : 0);
      expect(result.scanEngine, grant ? 'MediaStore' : 'SAF (instant)');
    });
  }

  test('background scans never prompt for media access', () async {
    var permissionCalls = 0;
    messenger.setMockMethodCallHandler(_permissions, (_) async {
      permissionCalls++;
      return PermissionStatus.denied.index;
    });
    useStorage(list: (_) => _listing());
    final service = scanner(_Songs([]));

    await service.scanAllFolders().last;
    await service.awaitAllArtworkBackfill();

    expect(permissionCalls, 0);
  });

  test('manual Rescan All requests media access once', () async {
    const sd = '$_provider/tree/1234-5678%3AMusic';
    var requests = 0;
    var queries = 0;
    messenger.setMockMethodCallHandler(_permissions, (call) async {
      if (call.method == 'checkPermissionStatus') {
        return PermissionStatus.denied.index;
      }
      requests++;
      return {Permission.audio.value: PermissionStatus.denied.index};
    });
    useStorage(
      list: (_) => _listing(),
      mediaStore: (_) {
        queries++;
        return [];
      },
    );
    final service = scanner(
      _Songs([]),
      folders: [_folder(_root, 'Music'), _folder(sd, 'SD card')],
    );
    await service.scanAllFolders(promptForMediaAccess: true).last;
    await service.awaitAllArtworkBackfill();
    expect(requests, 1);
    expect(queries, 0);
  });

  test('MediaStore retains rows if the SAF root differs', () async {
    const otherRoot = '/storage/emulated/0/OtherMusic';
    const indexed = '$otherRoot/indexed.flac';
    const unindexed = '$otherRoot/unindexed.flac';
    var safWalks = 0;

    useStorage(
      fsPath: otherRoot,
      list: (_) {
        safWalks++;
        return _listing();
      },
      mediaStore: (_) => [_indexedTrack(indexed)],
    );
    final songs = _Songs([_song(30, indexed), _song(31, unindexed)]);
    final service = scanner(songs);

    final result = await service.scanFolder(_root, 'Music').last;
    await service.awaitArtworkBackfill(_root);

    expect(result.scanEngine, 'MediaStore');
    expect(safWalks, 0);
    expect(songs.rows.keys, unorderedEquals([30, 31]));
    expect(songs.deleted, isEmpty);
  });

  for (final (label, accessible, complete) in [
    ('inaccessible', false, false),
    ('partial', true, false),
    ('complete', true, true),
  ]) {
    test('MediaStore deletion with a $label SAF tree', () async {
      const missing = '$_rawRoot/missing.flac';
      var safWalks = 0;
      useStorage(
        mediaStore: (_) => [_indexedTrack(_rawAlbum)],
        list: (_) {
          safWalks++;
          return _listing(
            accessible: accessible,
            complete: complete,
            files: accessible ? [_file(_songUri, 'track.flac')] : [],
          );
        },
        extra: (call) => throw StateError('Unexpected ${call.method}'),
      );
      final songs = _Songs([
        _song(30, _rawAlbum),
        _song(31, Uri.file(_rawSong).toString()),
        _song(32, missing),
      ]);
      final service = scanner(songs);

      final result = await service.scanFolder(_root, 'Music').last;
      await service.awaitArtworkBackfill(_root);

      expect(result.scanEngine, 'MediaStore');
      expect(safWalks, 1);
      expect(songs.rows.containsKey(31), isTrue);
      expect(songs.deleted, complete ? [32] : isEmpty);
    });
  }

  test('MediaStore query errors fall back without pruning rows', () async {
    useStorage(
      mediaStore: (_) => throw PlatformException(code: 'MEDIASTORE_ERROR'),
      list: (_) => _listing(accessible: false, complete: false),
    );
    final songs = _Songs([_song(40, _rawSong)]);
    final service = scanner(songs);

    final result = await service.scanFolder(_root, 'Music').last;
    await service.awaitArtworkBackfill(_root);

    expect(result.unavailable, isTrue);
    expect(songs.rows.keys, [40]);
    expect(songs.deleted, isEmpty);
  });

  test(
    'Rescan All reports lost access and still scans a read-only SD card',
    () async {
      const sd = '$_provider/tree/1234-5678%3AMusic';
      final sdFolder = _folder(sd, 'SD card');
      final listed = <String>[];
      useStorage(
        list: (uri) {
          listed.add(uri);
          return _listing(accessible: uri == sd, complete: uri == sd);
        },
      );
      final songs = _Songs([_song(10, _songUri)]);
      final service = scanner(
        songs,
        folders: [_folder(_root, 'Music'), sdFolder],
      );
      final result = await service.scanAllFolders().last;

      expect(listed, unorderedEquals([_root, sd]));
      expect(sdFolder.volumeState, 'mounted_ro');
      expect(result.isComplete, isTrue);
      expect(result.unavailable, isTrue);
      final snapshots = {
        for (final folder in result.folders!) folder.displayName: folder,
      };
      expect(snapshots['Music']!.unavailable, isTrue);
      expect(
        snapshots['Music']!.unavailableMessage,
        l10n.folderAccessLostReselect,
      );
      expect(snapshots['SD card']!.unavailable, isFalse);
      expect(songs.rows.keys, [10]);
    },
  );

  for (final throws in [false, true]) {
    test(
      'DSD metadata stages the document after a raw ${throws ? 'error' : 'miss'}',
      () async {
        const uri = '$_root/document/primary%3AMusic%2Ftrack.dsf';
        const raw = '$_rawRoot/track.dsf';
        const staged = '/cache/track.dsf';
        final attempts = <String>[];
        Object? stagingArgs;
        useStorage(
          list: (_) => throw StateError('Unexpected SAF listing'),
          extra: (call) {
            expect(call.method, 'cacheUriForPlayback');
            stagingArgs = call.arguments;
            return staged;
          },
        );
        RustLib.initMock(
          api: _ScannerApi(
            extract: (path) async {
              attempts.add(path);
              if (path == raw) {
                if (throws) {
                  throw FileSystemException('Permission denied', path);
                }
                return null;
              }
              return AudioFileMetadata(
                path: path,
                format: 'dsf',
                lastModified: _timestamp,
                fileSize: BigInt.from(_size),
              );
            },
          ),
        );
        addTearDown(RustLib.dispose);

        final result = await scanner(_Songs([])).extractRustMetadataForUri(uri);
        expect(attempts, [raw, staged]);
        expect(stagingArgs, containsPair('uri', uri));
        expect(stagingArgs, containsPair('extensionHint', 'dsf'));
        expect(stagingArgs, containsPair('maxSizeBytes', 256 * 1024 * 1024));
        expect(result?.path, staged);
      },
    );
  }
}
