import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/metadata_editor_service.dart';
import 'package:flick/src/rust/api/metadata_editor.dart' as rust_metadata;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.mossapps.flick/storage');
  const contentUri =
      'content://com.android.externalstorage.documents/tree/primary%3AMusic/'
      'document/primary%3AMusic%2Ftrack.flac';
  const treeUri =
      'content://com.android.externalstorage.documents/tree/primary%3AMusic';

  final en = lookupAppLocalizations(const Locale('en'));

  late Directory tempDir;
  late List<MethodCall> channelCalls;
  late Future<Object?> Function(MethodCall call) onChannelCall;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flick-metadata-editor-');
    channelCalls = [];
    onChannelCall = (call) async {
      fail('Unexpected storage channel call: ${call.method}');
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          channelCalls.add(call);
          return onChannelCall(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File stagedFile(String name) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync([1, 2, 3]);
    return file;
  }

  Song songFor(String filePath, {String? folderUri}) {
    return Song(
      id: '1',
      title: 'Blank Space',
      artist: 'Taylor Swift',
      duration: const Duration(minutes: 4),
      fileType: 'FLAC',
      filePath: filePath,
      folderUri: folderUri,
    );
  }

  const fields = rust_metadata.TagEditFields(
    title: 'New Title',
    artist: 'New Artist',
    album: 'New Album',
    albumArtist: 'New Album Artist',
    genre: 'Rock',
    year: 2026,
    trackNumber: 1,
    discNumber: 1,
  );

  const readBack = rust_metadata.TagReadResult(
    title: 'New Title',
    artist: 'New Artist',
    album: 'New Album',
    albumArtist: 'New Album Artist',
    genre: 'Rock',
    year: 2026,
    trackNumber: 1,
    discNumber: 1,
  );

  test(
    'edits a content URI through staging and writes the bytes back',
    () async {
      final editStage = stagedFile('edit.flac');
      final verifyStage = stagedFile('verify.flac');
      var stageCalls = 0;

      onChannelCall = (call) async {
        switch (call.method) {
          case 'stageContentUriForEdit':
            final args = call.arguments as Map;
            expect(args['uri'], contentUri);
            expect(args['extensionHint'], 'flac');
            return stageCalls++ == 0
                ? {'path': editStage.path, 'reason': null}
                : {'path': verifyStage.path, 'reason': null};
          case 'writeBytesToContentUri':
            final args = call.arguments as Map;
            expect(args['uri'], contentUri);
            expect(args['tempFilePath'], editStage.path);
            return {'success': true, 'reason': 'ok'};
          default:
            fail('Unexpected storage channel call: ${call.method}');
        }
      };

      final writtenTo = <String>[];
      final persisted = <String>[];
      final service = MetadataEditorService.forTesting(
        readTagFile: (path) async {
          expect(path, verifyStage.path);
          return readBack;
        },
        writeTagFile: (path, editFields) async {
          expect(editFields, fields);
          writtenTo.add(path);
          return const rust_metadata.TagWriteResult(success: true);
        },
        persistMetadata: (path, editFields) async => persisted.add(path),
      );

      final result = await service.writeTags(
        songFor(contentUri, folderUri: treeUri),
        fields,
      );

      expect(result.outcome, MetadataWriteOutcome.verified);
      expect(writtenTo, [editStage.path]);
      expect(persisted, [contentUri]);
      expect(stageCalls, 2);
      expect(editStage.existsSync(), isFalse);
      expect(verifyStage.existsSync(), isFalse);
      expect(channelCalls.map((call) => call.method), [
        'stageContentUriForEdit',
        'writeBytesToContentUri',
        'stageContentUriForEdit',
      ]);
    },
  );

  test(
    'write-back without permission keeps the DB untouched and says why',
    () async {
      final editStage = stagedFile('edit.flac');
      var stageCalls = 0;

      onChannelCall = (call) async {
        switch (call.method) {
          case 'stageContentUriForEdit':
            stageCalls++;
            return {'path': editStage.path, 'reason': null};
          case 'writeBytesToContentUri':
            return {'success': false, 'reason': 'no_access'};
          default:
            fail('Unexpected storage channel call: ${call.method}');
        }
      };

      var readCalls = 0;
      final persisted = <String>[];
      final service = MetadataEditorService.forTesting(
        readTagFile: (path) async {
          readCalls++;
          return readBack;
        },
        writeTagFile: (path, editFields) async =>
            const rust_metadata.TagWriteResult(success: true),
        persistMetadata: (path, editFields) async => persisted.add(path),
      );

      final result = await service.writeTags(
        songFor(contentUri, folderUri: treeUri),
        fields,
      );

      expect(result.outcome, MetadataWriteOutcome.failed);
      expect(result.message, en.flickNoLongerHasPermissionToEditThisFile);
      expect(stageCalls, 1);
      expect(readCalls, 0);
      expect(persisted, isEmpty);
      expect(editStage.existsSync(), isFalse);
    },
  );

  test('a missing content URI reports a moved-or-deleted file', () async {
    onChannelCall = (call) async {
      expect(call.method, 'stageContentUriForEdit');
      return {'path': null, 'reason': 'not_found'};
    };

    var writeCalls = 0;
    final service = MetadataEditorService.forTesting(
      readTagFile: (path) async => readBack,
      writeTagFile: (path, editFields) async {
        writeCalls++;
        return const rust_metadata.TagWriteResult(success: true);
      },
      persistMetadata: (path, editFields) async {},
    );

    final result = await service.writeTags(
      songFor(contentUri, folderUri: treeUri),
      fields,
    );

    expect(result.outcome, MetadataWriteOutcome.failed);
    expect(result.message, en.fileIsNoLongerAvailable);
    expect(writeCalls, 0);
  });

  test(
    'file:// paths are normalized before reaching the Rust tagger',
    () async {
      const fileUri = 'file:///storage/emulated/0/Music/track.flac';
      final writtenTo = <String>[];
      final persisted = <String>[];

      final service = MetadataEditorService.forTesting(
        readTagFile: (path) async => readBack,
        writeTagFile: (path, editFields) async {
          writtenTo.add(path);
          return const rust_metadata.TagWriteResult(success: true);
        },
        persistMetadata: (path, editFields) async => persisted.add(path),
      );

      final result = await service.writeTags(songFor(fileUri), fields);

      expect(result.outcome, MetadataWriteOutcome.verified);
      expect(writtenTo, ['/storage/emulated/0/Music/track.flac']);
      // The DB row is keyed by the original URI, not the normalized path.
      expect(persisted, [fileUri]);
      expect(channelCalls, isEmpty);
    },
  );

  test(
    'a direct ENOENT failure gets a clear message instead of os error 2',
    () async {
      final service = MetadataEditorService.forTesting(
        readTagFile: (path) async => readBack,
        writeTagFile: (path, editFields) async =>
            const rust_metadata.TagWriteResult(
              success: false,
              error:
                  'Failed to open file: No such file or directory (os error 2)',
            ),
        persistMetadata: (path, editFields) async {},
      );

      final result = await service.writeTags(
        songFor('/storage/emulated/0/Music/missing.flac'),
        fields,
      );

      expect(result.outcome, MetadataWriteOutcome.failed);
      expect(result.message, en.fileIsNoLongerAvailable);
      expect(result.message, isNot(contains('os error 2')));
      expect(channelCalls, isEmpty);
    },
  );

  test(
    'a thrown direct write still attempts the SAF fallback and keeps the URI key',
    () async {
      const path = '/storage/emulated/0/Music/track.flac';
      const fileUri = 'file://$path';
      final editStage = stagedFile('saf-edit.flac');
      final persisted = <String>[];

      onChannelCall = (call) async {
        expect(call.method, 'writeFileBytesViaSaf');
        final args = call.arguments as Map;
        expect(args['folderTreeUri'], treeUri);
        expect(args['filePath'], path);
        expect(args['tempFilePath'], editStage.path);
        return true;
      };

      final service = MetadataEditorService.forTesting(
        readTagFile: (readPath) async {
          expect(readPath, path);
          return readBack;
        },
        writeTagFile: (path, editFields) async {
          throw Exception('direct write denied');
        },
        writeTagFileToTemp: (path, editFields, tempDirPath) async {
          expect(path, '/storage/emulated/0/Music/track.flac');
          expect(tempDirPath, '${tempDir.path}/metadata_edits');
          return rust_metadata.TagWriteResult(
            success: true,
            tempPath: editStage.path,
          );
        },
        persistMetadata: (path, editFields) async => persisted.add(path),
        temporaryDirectory: () async => tempDir,
      );

      final result = await service.writeTags(
        songFor(fileUri, folderUri: treeUri),
        fields,
      );

      expect(result.outcome, MetadataWriteOutcome.verified);
      expect(persisted, [fileUri]);
      expect(editStage.existsSync(), isFalse);
      expect(channelCalls.single.method, 'writeFileBytesViaSaf');
    },
  );

  test('a direct permission failure falls back to SAF', () async {
    const path = '/storage/emulated/0/Music/track.flac';
    final editStage = stagedFile('saf-denied.flac');
    final persisted = <String>[];

    onChannelCall = (call) async {
      expect(call.method, 'writeFileBytesViaSaf');
      final args = call.arguments as Map;
      expect(args['filePath'], path);
      expect(args['tempFilePath'], editStage.path);
      return true;
    };

    final service = MetadataEditorService.forTesting(
      readTagFile: (readPath) async => readBack,
      writeTagFile: (path, editFields) async =>
          const rust_metadata.TagWriteResult(
            success: false,
            error: 'Failed to open file: Permission denied (os error 13)',
          ),
      writeTagFileToTemp: (path, editFields, tempDirPath) async =>
          rust_metadata.TagWriteResult(success: true, tempPath: editStage.path),
      persistMetadata: (path, editFields) async => persisted.add(path),
      temporaryDirectory: () async => tempDir,
    );

    final result = await service.writeTags(
      songFor(path, folderUri: treeUri),
      fields,
    );

    expect(result.outcome, MetadataWriteOutcome.verified);
    expect(persisted, [path]);
    expect(editStage.existsSync(), isFalse);
    expect(channelCalls.single.method, 'writeFileBytesViaSaf');
  });

  test(
    'readTags stages a content URI into cache and removes the copy',
    () async {
      final readStage = stagedFile('read.flac');

      onChannelCall = (call) async {
        expect(call.method, 'stageContentUriForEdit');
        return {'path': readStage.path, 'reason': null};
      };

      final service = MetadataEditorService.forTesting(
        readTagFile: (path) async {
          expect(path, readStage.path);
          return readBack;
        },
      );

      final result = await service.readTags(contentUri);

      expect(result, readBack);
      expect(readStage.existsSync(), isFalse);
      expect(channelCalls.single.method, 'stageContentUriForEdit');
    },
  );
}
