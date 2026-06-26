import 'package:flick/services/music_folder_service.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeFolderIdentifier', () {
    test('handles percent-encoded Chinese tree URI', () {
      // 音乐 = %E9%9F%B3%E4%B9%90, %3A = ':', %2F = '/'
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2F%E9%9F%B3%E4%B9%90';
      final id = normalizeFolderIdentifier(uri);
      expect(id, 'primary:music/音乐');
    });

    test('does not throw on a stray percent sign (partial SAF encoding)', () {
      // Simulates a buggy SAF provider: a bare '%' not followed by hex.
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2F50%love';
      expect(() => normalizeFolderIdentifier(uri), returnsNormally);
      expect(
        normalizeFolderIdentifier(uri),
        contains('primary:music/'),
      );
    });

    test('raw non-ASCII tree id decodes without throwing', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary:Music/音乐';
      expect(() => normalizeFolderIdentifier(uri), returnsNormally);
    });
  });

  group('foldersOverlap', () {
    test('detects overlapping Chinese-named roots', () {
      const root =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2F%E9%9F%B3%E4%B9%90';
      const child =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2F%E9%9F%B3%E4%B9%90%2Fsub';
      expect(foldersOverlap(root, child), isTrue);
    });

    test('rejects unrelated roots', () {
      const a =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2F%E9%9F%B3%E4%B9%90';
      const b =
          'content://com.android.externalstorage.documents/tree/primary%3AMusic%2Fpop';
      expect(foldersOverlap(a, b), isFalse);
    });

    test('distinct removable USB volumes do not overlap', () {
      const driveA =
          'content://com.android.externalstorage.documents/tree/1234-5678:';
      const driveB =
          'content://com.android.externalstorage.documents/tree/ABCD-1234:';
      expect(foldersOverlap(driveA, driveB), isFalse);
    });

    test('USB root and its subfolder overlap', () {
      const root =
          'content://com.android.externalstorage.documents/tree/1234-5678:';
      const child =
          'content://com.android.externalstorage.documents/tree/1234-5678%3AMusic';
      expect(foldersOverlap(root, child), isTrue);
    });
  });

  group('normalizeFolderIdentifier (removable)', () {
    test('normalizes a USB volume root', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/1234-5678:';
      expect(normalizeFolderIdentifier(uri), '1234-5678:');
    });
  });

  group('MusicFolder storage fields', () {
    test('toJson includes new fields when set', () {
      final folder = MusicFolder(
        uri: 'content://com.android.externalstorage.documents/tree/1234-5678:',
        displayName: 'My USB',
        dateAdded: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        isRemovable: true,
        mediaStoreVolume: '1234-5678',
        volumeState: 'mounted',
      );
      final json = folder.toJson();
      expect(json['isRemovable'], true);
      expect(json['mediaStoreVolume'], '1234-5678');
      expect(json['volumeState'], 'mounted');
    });

    test('toJson omits new fields when null', () {
      final folder = MusicFolder(
        uri: 'u',
        displayName: 'd',
        dateAdded: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final json = folder.toJson();
      expect(json.containsKey('isRemovable'), isFalse);
      expect(json.containsKey('mediaStoreVolume'), isFalse);
      expect(json.containsKey('volumeState'), isFalse);
    });

    test('fromJson round-trips all fields', () {
      final original = MusicFolder(
        uri: 'content://com.android.externalstorage.documents/tree/1234-5678:',
        displayName: 'My USB',
        dateAdded: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        isRemovable: true,
        mediaStoreVolume: '1234-5678',
        volumeState: 'unmounted',
      );
      final restored = MusicFolder.fromJson(original.toJson());
      expect(restored.isRemovable, true);
      expect(restored.mediaStoreVolume, '1234-5678');
      expect(restored.volumeState, 'unmounted');
      expect(restored.uri, original.uri);
    });
  });

  group('StorageVolumeInfo', () {
    test('isMounted is true only for "mounted" state', () {
      expect(
        const StorageVolumeInfo(state: 'mounted').isMounted,
        isTrue,
      );
      expect(
        const StorageVolumeInfo(state: 'unmounted').isMounted,
        isFalse,
      );
      expect(const StorageVolumeInfo().isMounted, isFalse);
    });

    test('fromMap maps all fields with safe defaults', () {
      final info = StorageVolumeInfo.fromMap({
        'fsPath': '/storage/1234-5678',
        'mediaStoreVolume': '1234-5678',
        'isRemovable': true,
        'isPrimary': false,
        'state': 'mounted',
      });
      expect(info.fsPath, '/storage/1234-5678');
      expect(info.mediaStoreVolume, '1234-5678');
      expect(info.isRemovable, isTrue);
      expect(info.isPrimary, isFalse);
      expect(info.isMounted, isTrue);

      final empty = StorageVolumeInfo.fromMap({});
      expect(empty.fsPath, isNull);
      expect(empty.isRemovable, isFalse);
      expect(empty.isPrimary, isFalse);
      expect(empty.state, 'unknown');
    });
  });
}
