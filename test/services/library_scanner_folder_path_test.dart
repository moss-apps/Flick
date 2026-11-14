import 'package:flick/core/constants/metadata_constants.dart';
import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/data/repositories/folder_repository.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:flick/services/music_folder_service.dart';
import 'package:flick/services/playlist_service.dart';
import 'package:flick/src/rust/api/scanner.dart';
import 'package:flick/src/rust/frb_generated.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSongRepository implements SongRepository {
  final List<SongEntity> songs;
  final List<int> updatedIds = [];
  final List<int> deletedIds = [];

  _RecordingSongRepository(this.songs);

  @override
  Future<List<SongEntity>> getSongEntitiesByFolder(String folderUri) async =>
      songs;

  @override
  Future<void> upsertSongs(List<SongEntity> entities) async {
    updatedIds.addAll(entities.map((song) => song.id));
  }

  @override
  Future<void> deleteSongsByIds(List<int> ids) async {
    deletedIds.addAll(ids);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedFolderRepository implements FolderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedPlaylistService implements PlaylistService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScanBoundaryApi implements RustLibApi {
  final void Function() onScan;

  _ScanBoundaryApi(this.onScan);

  @override
  Stream<ScanChunk> crateApiScannerScanMusicLibrary({
    required String rootPath,
    required Map<String, int> knownFiles,
    required ScanOptions scanOptions,
  }) {
    expect(scanOptions.forceFullRescan, isFalse);
    onScan();
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SongEntity _song(
  int id,
  String filePath, {
  String? relativeFolderPath,
  bool hasLocalEdits = false,
}) => SongEntity()
  ..id = id
  ..filePath = filePath
  ..title = 'Track $id'
  ..artist = 'Artist'
  ..dateAdded = DateTime(2026, 1, 1)
  ..relativeFolderPath = relativeFolderPath
  ..hasLocalEdits = hasLocalEdits;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('folderPathBackfillFor', () {
    test('repairs unchanged legacy rows without touching ids or edits', () {
      final legacy = _song(
        7,
        '/storage/Music/Album/track.flac',
        hasLocalEdits: true,
      );
      final correct = _song(
        8,
        '/storage/Music/Other/track.flac',
        relativeFolderPath: 'Other',
      );

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [legacy, correct],
        expectedByFilePath: {
          legacy.filePath: 'Album',
          correct.filePath: 'Other',
        },
      );

      expect(batch, [legacy]);
      expect(legacy.relativeFolderPath, 'Album');
      expect(legacy.id, 7);
      expect(legacy.hasLocalEdits, isTrue);
      expect(legacy.title, 'Track 7');
      expect(correct.relativeFolderPath, 'Other');
    });

    test('repairs a stale recorded path', () {
      final renamed = _song(
        9,
        '/storage/Music/NewName/track.flac',
        relativeFolderPath: 'OldName',
      );

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [renamed],
        expectedByFilePath: {renamed.filePath: 'NewName'},
      );

      expect(batch, [renamed]);
      expect(renamed.relativeFolderPath, 'NewName');
    });

    test('records the empty path for files at the scan root', () {
      final rootLevel = _song(10, '/storage/Music/track.flac');

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [rootLevel],
        expectedByFilePath: {rootLevel.filePath: ''},
      );

      expect(batch, [rootLevel]);
      expect(rootLevel.relativeFolderPath, '');
    });

    test('skips rows removed by scan filters', () {
      final filtered = _song(11, '/storage/Music/Short/track.flac');

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [filtered],
        expectedByFilePath: {filtered.filePath: 'Short'},
        excludedIds: {11},
      );

      expect(batch, isEmpty);
      expect(filtered.relativeFolderPath, isNull);
    });

    test('leaves rows outside the scanned set unresolved', () {
      final unknown = _song(12, '/storage/Other/track.flac');

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [unknown],
        expectedByFilePath: const {},
      );

      expect(batch, isEmpty);
      expect(unknown.relativeFolderPath, isNull);
    });

    test('repairs a legacy file URI using its confirmed MediaStore alias', () {
      const mediaStoreUri = 'content://media/external/audio/media/123';
      final legacy = _song(14, 'file:///storage/Music/Album/track.flac')
        ..mediaStoreUri = mediaStoreUri;

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [legacy],
        expectedByFilePath: {mediaStoreUri: 'Album'},
      );

      expect(batch, [legacy]);
      expect(legacy.relativeFolderPath, 'Album');
      expect(legacy.id, 14);
    });

    test('repairs legacy rows keyed directly by a MediaStore URI', () {
      const mediaStoreUri = 'content://media/external/audio/media/124';
      final legacy = _song(15, mediaStoreUri);

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [legacy],
        expectedByFilePath: {mediaStoreUri: 'Album'},
      );

      expect(batch, [legacy]);
      expect(legacy.relativeFolderPath, 'Album');
    });

    test('prefers the discovered file path over a MediaStore alias', () {
      const mediaStoreUri = 'content://media/external/audio/media/125';
      final legacy = _song(16, '/storage/Music/Album/track.flac')
        ..mediaStoreUri = mediaStoreUri;

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [legacy],
        expectedByFilePath: {legacy.filePath: 'Album', mediaStoreUri: 'Other'},
      );

      expect(batch, [legacy]);
      expect(legacy.relativeFolderPath, 'Album');
    });

    test('is a no-op when every recorded path is current', () {
      final current = _song(
        13,
        '/storage/Music/Album/track.flac',
        relativeFolderPath: 'Album',
      );

      final batch = LibraryScannerService.folderPathBackfillFor(
        songs: [current],
        expectedByFilePath: {current.filePath: 'Album'},
      );

      expect(batch, isEmpty);
    });
  });

  test(
    'Rust backfills every unchanged CUE row before the incremental scan',
    () async {
      SharedPreferences.setMockInitialValues({
        'library_scan_ignore_small_tracks': true,
      });
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProvider, (_) async => '/tmp/opencode');
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProvider, null);
      });

      const root = '/storage/1234-5678/Music';
      const audioPath = '$root/Albums/Disc 1/image.flac';
      final cueTracks = [
        for (var i = 0; i < 3; i++)
          _song(20 + i, audioPath, hasLocalEdits: true)
            ..folderUri = root
            ..startOffsetMs = i * 60000
            ..metadataVersion = kCurrentTrackMetadataVersion,
      ];
      final filtered = _song(30, '$root/Short/track.flac')
        ..folderUri = root
        ..fileSize = 100;
      final repository = _RecordingSongRepository([...cueTracks, filtered]);
      final scanner = LibraryScannerService(
        songRepository: repository,
        folderRepository: _UnusedFolderRepository(),
        musicFolderService: MusicFolderService(),
        playlistService: _UnusedPlaylistService(),
      );
      var scanStarted = false;
      RustLib.initMock(
        api: _ScanBoundaryApi(() {
          scanStarted = true;
          // Stop at the native boundary: only the pre-scan backfill is under test.
          scanner.cancelScan();
        }),
      );
      addTearDown(RustLib.dispose);

      await scanner.scanFolder(root, 'SD Music').drain<void>();

      expect(scanStarted, isTrue);
      expect(repository.updatedIds, unorderedEquals([20, 21, 22]));
      expect(repository.deletedIds, [30]);
      for (final track in cueTracks) {
        expect(track.relativeFolderPath, 'Albums/Disc 1');
        expect(track.title, 'Track ${track.id}');
        expect(track.hasLocalEdits, isTrue);
      }
      expect(filtered.relativeFolderPath, isNull);
    },
  );
}
