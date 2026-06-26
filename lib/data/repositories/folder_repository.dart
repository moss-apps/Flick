import 'package:isar_community/isar.dart';

import '../database.dart';

/// Repository for folder CRUD operations.
class FolderRepository {
  final Isar _isar;

  FolderRepository({Isar? isar}) : _isar = isar ?? Database.instance;

  /// Get all watched folders.
  Future<List<FolderEntity>> getAllFolders() async {
    return await _isar.folderEntitys.where().findAll();
  }

  /// Get a folder by URI.
  Future<FolderEntity?> getFolderByUri(String uri) async {
    return await _isar.folderEntitys.filter().uriEqualTo(uri).findFirst();
  }

  /// Add or update a folder.
  Future<void> upsertFolder(FolderEntity entity) async {
    await _isar.writeTxn(() async {
      // Check if folder with same URI exists
      final existing = await _isar.folderEntitys
          .filter()
          .uriEqualTo(entity.uri)
          .findFirst();

      if (existing != null) {
        entity.id = existing.id;
      }

      await _isar.folderEntitys.put(entity);
    });
  }

  /// Update the last scanned time and song count for a folder.
  Future<void> updateFolderScanInfo(String uri, int songCount) async {
    await _isar.writeTxn(() async {
      final folder = await _isar.folderEntitys
          .filter()
          .uriEqualTo(uri)
          .findFirst();

      if (folder != null) {
        folder.lastScanned = DateTime.now();
        folder.songCount = songCount;
        await _isar.folderEntitys.put(folder);
      }
    });
  }

  /// Update the mount state of a folder's volume (e.g. USB unplug/replug).
  Future<void> updateFolderVolumeState(String uri, String state) async {
    await _isar.writeTxn(() async {
      final folder = await _isar.folderEntitys
          .filter()
          .uriEqualTo(uri)
          .findFirst();

      if (folder != null) {
        folder.volumeState = state;
        await _isar.folderEntitys.put(folder);
      }
    });
  }

  /// Backfill volume metadata (removable flag, MediaStore volume, state) for a
  /// pre-feature folder. Lazy migration — only the first scan after upgrade.
  Future<void> updateFolderVolumeInfo({
    required String uri,
    required bool? isRemovable,
    required String? mediaStoreVolume,
    required String state,
  }) async {
    await _isar.writeTxn(() async {
      final folder = await _isar.folderEntitys
          .filter()
          .uriEqualTo(uri)
          .findFirst();

      if (folder != null) {
        folder
          ..isRemovable = isRemovable
          ..mediaStoreVolume = mediaStoreVolume
          ..volumeState = state;
        await _isar.folderEntitys.put(folder);
      }
    });
  }

  /// Delete a folder by URI.
  Future<void> deleteFolder(String uri) async {
    await _isar.writeTxn(() async {
      await _isar.folderEntitys.filter().uriEqualTo(uri).deleteAll();
    });
  }

  /// Delete all folders.
  Future<void> deleteAllFolders() async {
    await _isar.writeTxn(() async {
      await _isar.folderEntitys.clear();
    });
  }

  /// Watch for changes in the folders collection.
  Stream<void> watchFolders() {
    return _isar.folderEntitys.watchLazy();
  }
}
