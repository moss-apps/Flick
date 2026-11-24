import 'package:flick/data/entities/song_entity.dart';
import 'package:flick/services/library_scanner_service.dart';
import 'package:test/test.dart';

void main() {
  group('chooseAndroidScanEngine', () {
    test('Deep Scan off uses MediaStore even with All Files Access', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: false,
          isRemovable: false,
        ),
        'mediaStore',
      );
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: false,
          isRemovable: true,
        ),
        'mediaStore',
      );
    });

    test('Deep Scan on uses Rust wherever it can read a path', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: false,
        ),
        'rust',
      );
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: true,
        ),
        'rust',
      );
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: false,
        ),
        'rust',
      );
    });

    test('All Files Access without a readable path falls back to SAF', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: false,
          useDeepScan: false,
          isRemovable: true,
        ),
        'saf',
      );
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: true,
          hasReadableFsPath: false,
          useDeepScan: true,
          isRemovable: false,
        ),
        'saf',
      );
    });

    test('Deep Scan on removable prefers MediaStore', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: true,
        ),
        'mediaStore',
      );
    });

    test('a scan without a readable path uses SAF', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: false,
          useDeepScan: false,
          isRemovable: false,
        ),
        'saf',
      );
    });

    // Regression: the same indexed internal Music folder on Android 11+
    // scoped storage must follow the toggle. Off -> MediaStore (the user's
    // report: forcing SAF made the switch a no-op); on -> SAF because only
    // the picker grant is readable to Rust there.
    test('Android 11+ scoped folder: off uses MediaStore, on uses SAF', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: false,
          isRemovable: false,
          scopedTreeRequired: true,
        ),
        'mediaStore',
      );
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: false,
          scopedTreeRequired: true,
        ),
        'saf',
      );
    });

    test('scoped deep scan on removable prefers the indexed volume', () {
      expect(
        LibraryScannerService.chooseAndroidScanEngine(
          allFilesAccess: false,
          hasReadableFsPath: true,
          useDeepScan: true,
          isRemovable: true,
          scopedTreeRequired: true,
        ),
        'mediaStore',
      );
    });

    test(
      'All Files Access plus Deep Scan still prefers Rust in scoped mode',
      () {
        expect(
          LibraryScannerService.chooseAndroidScanEngine(
            allFilesAccess: true,
            hasReadableFsPath: true,
            useDeepScan: true,
            isRemovable: false,
            scopedTreeRequired: true,
          ),
          'rust',
        );
        expect(
          LibraryScannerService.chooseAndroidScanEngine(
            allFilesAccess: true,
            hasReadableFsPath: true,
            useDeepScan: false,
            isRemovable: false,
            scopedTreeRequired: true,
          ),
          'mediaStore',
        );
      },
    );
  });

  group('migrateRawRowsToSafUris', () {
    const safUri =
        'content://com.android.externalstorage.documents/tree/primary%3AMusic/'
        'document/primary%3AMusic%2FAlbum%2Ftrack.flac';

    SongEntity song(
      int id,
      String filePath, {
      int? startOffsetMs,
      bool hasLocalEdits = false,
    }) => SongEntity()
      ..id = id
      ..filePath = filePath
      ..startOffsetMs = startOffsetMs
      ..title = 'Track $id'
      ..artist = 'Artist'
      ..relativeFolderPath = 'Old'
      ..hasLocalEdits = hasLocalEdits;

    test('rewrites raw rows in place and keeps identity and edits', () {
      final raw = song(7, '/storage/emulated/0/Music/Album/track.flac',
          hasLocalEdits: true);

      final migrated = LibraryScannerService.migrateRawRowsToSafUris(
        songs: [raw],
        safUriByRawPath: {'/storage/emulated/0/Music/Album/track.flac': safUri},
        relativeFolderPathByUri: {safUri: 'Album'},
      );

      expect(migrated, [raw]);
      expect(raw.id, 7);
      expect(raw.filePath, safUri);
      expect(raw.mediaStoreUri, safUri);
      expect(raw.relativeFolderPath, 'Album');
      expect(raw.hasLocalEdits, isTrue);
      expect(raw.title, 'Track 7');
    });

    test('matches file:// rows produced by MediaStore DSD reconciliation', () {
      final raw = song(8, 'file:///storage/emulated/0/Music/Album/track.dsf');

      final migrated = LibraryScannerService.migrateRawRowsToSafUris(
        songs: [raw],
        safUriByRawPath: {
          'file:///storage/emulated/0/Music/Album/track.dsf': safUri,
        },
        relativeFolderPathByUri: const {},
      );

      expect(migrated, [raw]);
      expect(raw.filePath, safUri);
      expect(raw.relativeFolderPath, 'Old');
    });

    test('migrates CUE offsets without replacing an occupied offset', () {
      final cue = song(
        9,
        '/storage/emulated/0/Music/Album/track.flac',
        startOffsetMs: 1200,
      );
      final excluded = song(10, '/storage/emulated/0/Music/Album/b.flac');
      final alreadyMapped = song(11, safUri, startOffsetMs: 2400);
      final unknown = song(12, '/storage/emulated/0/Music/other.flac');
      final duplicateOffset = song(
        13,
        '/storage/emulated/0/Music/Album/track.flac',
        startOffsetMs: 2400,
      );

      final migrated = LibraryScannerService.migrateRawRowsToSafUris(
        songs: [cue, excluded, alreadyMapped, unknown, duplicateOffset],
        safUriByRawPath: {
          '/storage/emulated/0/Music/Album/track.flac': safUri,
          '/storage/emulated/0/Music/Album/b.flac': safUri,
        },
        relativeFolderPathByUri: {safUri: 'Album'},
        excludedIds: {10},
      );

      expect(migrated, [cue]);
      expect(cue.filePath, safUri);
      expect(cue.startOffsetMs, 1200);
      expect(cue.id, 9);
      expect(duplicateOffset.filePath, '/storage/emulated/0/Music/Album/track.flac');
      expect(excluded.filePath, '/storage/emulated/0/Music/Album/b.flac');
      expect(alreadyMapped.filePath, safUri);
      expect(unknown.filePath, '/storage/emulated/0/Music/other.flac');
    });
  });

  group('shouldRustRetryMetadata', () {
    test('wavpack and dsd always retry through the rust parsers', () {
      for (final ext in ['wv', 'dsf', 'dff']) {
        expect(
          LibraryScannerService.shouldRustRetryMetadata(
            extension: ext,
            hasMetadata: true,
            hasSampleRate: true,
            hasDuration: true,
          ),
          isTrue,
          reason: ext,
        );
      }
    });

    test('flac without a sample rate retries (hi-res retriever failure)', () {
      expect(
        LibraryScannerService.shouldRustRetryMetadata(
          extension: 'flac',
          hasMetadata: true,
          hasSampleRate: false,
          hasDuration: true,
        ),
        isTrue,
      );
    });

    test('flac without a duration retries', () {
      expect(
        LibraryScannerService.shouldRustRetryMetadata(
          extension: 'flac',
          hasMetadata: true,
          hasSampleRate: true,
          hasDuration: false,
        ),
        isTrue,
      );
    });

    test('missing retriever row retries for any extension', () {
      expect(
        LibraryScannerService.shouldRustRetryMetadata(
          extension: 'm4a',
          hasMetadata: false,
          hasSampleRate: false,
          hasDuration: false,
        ),
        isTrue,
      );
    });

    test('solved stream layout does not retry', () {
      expect(
        LibraryScannerService.shouldRustRetryMetadata(
          extension: 'flac',
          hasMetadata: true,
          hasSampleRate: true,
          hasDuration: true,
        ),
        isFalse,
      );
    });

    test('missing bit depth alone does not retry (lossy codecs)', () {
      expect(
        LibraryScannerService.shouldRustRetryMetadata(
          extension: 'mp3',
          hasMetadata: true,
          hasSampleRate: true,
          hasDuration: true,
        ),
        isFalse,
      );
    });

    test('extension-less content uris still retry when unsolved', () {
      expect(
        LibraryScannerService.shouldRustRetryMetadata(
          extension: '',
          hasMetadata: true,
          hasSampleRate: false,
          hasDuration: true,
        ),
        isTrue,
      );
    });
  });
}
