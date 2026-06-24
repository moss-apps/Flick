import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/utils/uri_display_utils.dart';

import 'permission_service.dart';
import '../data/repositories/folder_repository.dart';
import '../data/entities/folder_entity.dart';
import 'package:flick/core/utils/dev_log.dart';

String normalizeFolderIdentifier(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed != null && parsed.scheme == 'content') {
    final treeSegments = parsed.pathSegments;
    final treeIndex = treeSegments.indexOf('tree');
    if (treeIndex >= 0 && treeIndex + 1 < treeSegments.length) {
      final treeId = decodeUriDisplayComponent(
        treeSegments[treeIndex + 1],
      ).replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/').toLowerCase();
      if (treeId == '/' || treeId.endsWith(':')) {
        return treeId;
      }
      return treeId.replaceFirst(RegExp(r'/+$'), '');
    }
  }

  final normalized = uri
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+'), '/')
      .trim();
  if (normalized == '/') {
    return normalized;
  }
  return normalized.replaceFirst(RegExp(r'/$'), '').toLowerCase();
}

bool isSameOrDescendantFolder(String candidateUri, String rootUri) {
  final candidate = normalizeFolderIdentifier(candidateUri);
  final root = normalizeFolderIdentifier(rootUri);

  if (candidate == root) {
    return true;
  }
  if (root.isEmpty) {
    return false;
  }
  if (root == '/' || root.endsWith(':')) {
    return candidate.startsWith(root);
  }
  return candidate.startsWith('$root/');
}

bool foldersOverlap(String firstUri, String secondUri) {
  return isSameOrDescendantFolder(firstUri, secondUri) ||
      isSameOrDescendantFolder(secondUri, firstUri);
}

/// Represents an audio file discovered during folder scanning.
class AudioFileInfo {
  final String uri;
  final String name;
  final int size;
  final int lastModified;
  final String? mimeType;
  final String extension;
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? trackNumber;
  final int? discNumber;
  final int? duration;
  final String? albumArtPath;
  final String? bitrate;
  final int? bitDepth;
  final int? sampleRate;
  final String? filePath;
  final int? year;
  final int? dateAdded;

  AudioFileInfo({
    required this.uri,
    required this.name,
    required this.size,
    required this.lastModified,
    this.mimeType,
    required this.extension,
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.trackNumber,
    this.discNumber,
    this.duration,
    this.albumArtPath,
    this.bitrate,
    this.bitDepth,
    this.sampleRate,
    this.filePath,
    this.year,
    this.dateAdded,
  });

  factory AudioFileInfo.fromMap(Map<String, dynamic> map) {
    return AudioFileInfo(
      uri: map['uri'] as String,
      name:
          map['name'] as String? ??
          '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      lastModified: (map['lastModified'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String?,
      extension: map['extension'] as String? ?? '',
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      albumArtist: map['albumArtist'] as String?,
      trackNumber: (map['trackNumber'] as num?)?.toInt(),
      discNumber: (map['discNumber'] as num?)?.toInt(),
      duration: map['duration'] != null
          ? (map['duration'] as num).toInt()
          : null,
      albumArtPath: map['albumArtPath'] as String?,
      bitrate: map['bitrate'] as String?,
      bitDepth: (map['bitDepth'] as num?)?.toInt(),
      sampleRate: (map['sampleRate'] as num?)?.toInt(),
      filePath: map['filePath'] as String?,
      year: (map['year'] as num?)?.toInt(),
      dateAdded: (map['dateAdded'] as num?)?.toInt(),
    );
  }
}

class PlaylistFileInfo {
  final String uri;
  final String name;
  final int size;
  final int lastModified;
  final String extension;

  const PlaylistFileInfo({
    required this.uri,
    required this.name,
    required this.size,
    required this.lastModified,
    required this.extension,
  });

  factory PlaylistFileInfo.fromMap(Map<String, dynamic> map) {
    return PlaylistFileInfo(
      uri: map['uri'] as String,
      name: map['name'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      lastModified: (map['lastModified'] as num?)?.toInt() ?? 0,
      extension: map['extension'] as String? ?? '',
    );
  }
}

/// Represents a watched music folder.
/// Resolved storage-volume metadata for a folder URI.
/// Drives scan routing: primary vs removable, MediaStore volume name, mount state.
class StorageVolumeInfo {
  final String? fsPath;
  final String? mediaStoreVolume;
  final bool isRemovable;
  final bool isPrimary;
  final String state;

  const StorageVolumeInfo({
    this.fsPath,
    this.mediaStoreVolume,
    this.isRemovable = false,
    this.isPrimary = false,
    this.state = 'unknown',
  });

  bool get isMounted => state == 'mounted';

  factory StorageVolumeInfo.fromMap(Map<String, dynamic> map) {
    return StorageVolumeInfo(
      fsPath: map['fsPath'] as String?,
      mediaStoreVolume: map['mediaStoreVolume'] as String?,
      isRemovable: map['isRemovable'] as bool? ?? false,
      isPrimary: map['isPrimary'] as bool? ?? false,
      state: map['state'] as String? ?? 'unknown',
    );
  }
}

class MusicFolder {
  final String uri;
  final String displayName;
  final DateTime dateAdded;
  final bool? isRemovable;
  final String? mediaStoreVolume;
  final String? volumeState;

  MusicFolder({
    required this.uri,
    required this.displayName,
    required this.dateAdded,
    this.isRemovable,
    this.mediaStoreVolume,
    this.volumeState,
  });

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'displayName': displayName,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
        if (isRemovable != null) 'isRemovable': isRemovable,
        if (mediaStoreVolume != null) 'mediaStoreVolume': mediaStoreVolume,
        if (volumeState != null) 'volumeState': volumeState,
      };

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(
      uri: json['uri'] as String,
      displayName: decodeUriDisplayComponent(json['displayName'] as String),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(json['dateAdded'] as int),
      isRemovable: json['isRemovable'] as bool?,
      mediaStoreVolume: json['mediaStoreVolume'] as String?,
      volumeState: json['volumeState'] as String?,
    );
  }
}

/// Exception thrown when trying to add a folder that already exists.
class FolderAlreadyExistsException implements Exception {
  final String message;
  FolderAlreadyExistsException(this.message);
  @override
  String toString() => message;
}

/// Service for managing music folders and their contents.
class MusicFolderService {
  static const _channel = MethodChannel('com.mossapps.flick/storage');
  static const _mediastoreEventChannel = EventChannel('com.mossapps.flick/mediastore_events');
  static const _prefKey = 'music_folders';

  final PermissionService _permissionService;

  MusicFolderService({PermissionService? permissionService})
    : _permissionService = permissionService ?? PermissionService();

  /// Add a new music folder using the system folder picker.
  /// Returns the added folder, or null if cancelled.
  /// Throws [FolderAlreadyExistsException] if the folder is already added.
  Future<MusicFolder?> addFolder() async {
    // Open folder picker
    final uri = await _permissionService.openFolderPicker();
    if (uri == null) return null;

    // Check if folder already exists
    final existingFolders = await getSavedFolders();
    for (final folder in existingFolders) {
      if (folder.uri == uri) {
        throw FolderAlreadyExistsException(
          'This folder has already been added',
        );
      }
      if (foldersOverlap(folder.uri, uri)) {
        throw FolderAlreadyExistsException(
          'This folder overlaps with "${folder.displayName}". Keep only one root to avoid duplicate scans.',
        );
      }
    }

    // Take persistable permission
    final success = await _permissionService.takePersistablePermission(uri);
    if (!success) {
      throw StorageException('Failed to persist folder access');
    }

    // Get display name
    final displayName = await _getDisplayName(uri) ?? 'Unknown Folder';

    // Resolve storage-volume info (path + MediaStore volume + removable flag).
    final storageInfo = await resolveStorageInfo(uri);

    // Create folder object
    final folder = MusicFolder(
      uri: uri,
      displayName: displayName,
      dateAdded: DateTime.now(),
      isRemovable: storageInfo.isRemovable,
      mediaStoreVolume: storageInfo.mediaStoreVolume,
      volumeState: storageInfo.state,
    );

    // Save to preferences AND database
    await _saveFolderToPrefs(folder);
    await _saveFolderToDatabase(folder);

    return folder;
  }

  /// Remove a music folder and release its permission.
  Future<void> removeFolder(String uri) async {
    // Release permission
    await _permissionService.releasePersistablePermission(uri);

    // Remove from preferences AND database
    await _removeFolderFromPrefs(uri);
    await _removeFolderFromDatabase(uri);
  }

  /// Get all saved music folders.
  Future<List<MusicFolder>> getSavedFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getStringList(_prefKey) ?? [];

    // Overlay live volume state from the DB; prefs only captures add-time
    // state, while the scanner updates isRemovable/volumeState in the entity.
    final entities = {
      for (final e in await FolderRepository().getAllFolders()) e.uri: e,
    };

    final folders = <MusicFolder>[];
    for (final json in foldersJson) {
      try {
        final map = _parseJsonString(json);
        final folder = MusicFolder.fromJson(map);
        final entity = entities[folder.uri];
        if (entity != null) {
          folders.add(
            MusicFolder(
              uri: folder.uri,
              displayName: folder.displayName,
              dateAdded: folder.dateAdded,
              isRemovable: entity.isRemovable ?? folder.isRemovable,
              mediaStoreVolume:
                  entity.mediaStoreVolume ?? folder.mediaStoreVolume,
              volumeState: entity.volumeState ?? folder.volumeState,
            ),
          );
        } else {
          folders.add(folder);
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    return folders;
  }

  /// Scan a folder for audio files (Fast Scan - no metadata).
  /// Returns a list of discovered audio files with basic info.
  Future<List<AudioFileInfo>> scanFolder(
    String folderUri, {
    bool filterNonMusicFilesAndFolders = true,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<List<dynamic>>('listAudioFiles', {
            'uri': folderUri,
            'filterNonMusicFilesAndFolders': filterNonMusicFilesAndFolders,
          });

      if (result == null) return [];

      return result
          .cast<Map<dynamic, dynamic>>()
          .map((map) => AudioFileInfo.fromMap(map.cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      throw StorageException('Failed to scan folder: ${e.message}');
    }
  }

  Future<List<PlaylistFileInfo>> scanPlaylistFiles(
    String folderUri, {
    bool filterNonMusicFilesAndFolders = true,
  }) async {
    try {
      final result = await _channel
          .invokeMethod<List<dynamic>>('listPlaylistFiles', {
            'uri': folderUri,
            'filterNonMusicFilesAndFolders': filterNonMusicFilesAndFolders,
          });

      if (result == null) return [];

      return result
          .cast<Map<dynamic, dynamic>>()
          .map((map) => PlaylistFileInfo.fromMap(map.cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      throw StorageException('Failed to scan playlists: ${e.message}');
    }
  }

  /// Fetch rich metadata for a list of audio file URIs.
  Future<List<AudioFileInfo>> fetchMetadata(List<String> uris) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'fetchAudioMetadata',
        {'uris': uris},
      );

      if (result == null) return [];

      return result
          .cast<Map<dynamic, dynamic>>()
          .map((map) => AudioFileInfo.fromMap(map.cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      throw StorageException('Failed to fetch metadata: ${e.message}');
    }
  }

  Future<Uint8List?> fetchEmbeddedArtwork(String uri) async {
    try {
      return await _channel.invokeMethod<Uint8List>('fetchEmbeddedArtwork', {
        'uri': uri,
      });
    } on PlatformException catch (e) {
      throw StorageException('Failed to fetch album art: ${e.message}');
    }
  }

  /// Scan all saved folders for audio files.
  Stream<AudioFileInfo> scanAllFolders() async* {
    final folders = await getSavedFolders();
    final scheduledRoots = <String>{};
    for (final folder in folders) {
      final normalized = normalizeFolderIdentifier(folder.uri);
      final overlapsExisting = scheduledRoots.any(
        (root) =>
            isSameOrDescendantFolder(normalized, root) ||
            isSameOrDescendantFolder(root, normalized),
      );
      if (overlapsExisting) {
        continue;
      }
      scheduledRoots.add(normalized);
      final files = await scanFolder(folder.uri);
      for (final file in files) {
        yield file;
      }
    }
  }

  Future<String?> _getDisplayName(String uri) async {
    try {
      return await _channel.invokeMethod<String>('getDocumentDisplayName', {
        'uri': uri,
      });
    } catch (e) {
      return null;
    }
  }

  Future<String?> getDocumentDisplayName(String uri) {
    return _getDisplayName(uri);
  }

  Future<String?> resolveFilesystemPath(String uri) async {
    try {
      if (!uri.startsWith('content://')) {
        return uri;
      }

      return await _channel.invokeMethod<String>('resolveTreeUriToPath', {
        'uri': uri,
      });
    } catch (e) {
      return null;
    }
  }

  /// Resolves storage-volume metadata for a folder URI: filesystem path (if
  /// readable), MediaStore volume name, and whether it's removable (USB/SD).
  /// Used to route scans to the right strategy and target the correct
  /// MediaStore volume for external drives.
  Future<StorageVolumeInfo> resolveStorageInfo(String uri) async {
    try {
      if (!uri.startsWith('content://')) {
        return StorageVolumeInfo(fsPath: uri, isPrimary: true, state: 'mounted');
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'resolveStorageInfo',
        {'uri': uri},
      );
      if (result == null) {
        return const StorageVolumeInfo();
      }
      return StorageVolumeInfo.fromMap(result.cast<String, dynamic>());
    } catch (e) {
      return const StorageVolumeInfo();
    }
  }

  Future<List<AudioFileInfo>> queryMediaStoreAudio(
    List<String> folderPaths, {
    String? volumeName,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'queryMediaStoreAudio',
        {'folderPaths': folderPaths, 'volumeName': volumeName},
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((map) => AudioFileInfo.fromMap(map.cast<String, dynamic>()))
          .toList();
    } on PlatformException catch (e) {
      throw StorageException('Failed to query MediaStore: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> queryMediaStoreNonAudio(
    List<String> folderPaths, {
    String? volumeName,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'queryMediaStoreNonAudio',
        {'folderPaths': folderPaths, 'volumeName': volumeName},
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((map) => map.cast<String, dynamic>())
          .toList();
    } on PlatformException catch (e) {
      throw StorageException('Failed to query MediaStore non-audio: ${e.message}');
    }
  }

  Future<List<String>> queryMediaStoreDeletions(
    List<String> filePaths, {
    String? volumeName,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'queryMediaStoreDeletions',
        {'filePaths': filePaths, 'volumeName': volumeName},
      );
      if (result == null) return [];
      return result.cast<String>();
    } on PlatformException catch (e) {
      throw StorageException('Failed to check MediaStore deletions: ${e.message}');
    }
  }

  Stream<Map<String, dynamic>> get mediaStoreChanges {
    return _mediastoreEventChannel.receiveBroadcastStream().map(
      (event) => (event as Map<dynamic, dynamic>).cast<String, dynamic>(),
    );
  }

  Future<void> _saveFolderToPrefs(MusicFolder folder) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getStringList(_prefKey) ?? [];

    // Check if folder already exists
    final existingIndex = foldersJson.indexWhere((json) {
      try {
        final map = _parseJsonString(json);
        return map['uri'] == folder.uri;
      } catch (e) {
        return false;
      }
    });

    final folderJson = _toJsonString(folder.toJson());

    if (existingIndex >= 0) {
      foldersJson[existingIndex] = folderJson;
    } else {
      foldersJson.add(folderJson);
    }

    await prefs.setStringList(_prefKey, foldersJson);
  }

  Future<void> _removeFolderFromPrefs(String uri) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = prefs.getStringList(_prefKey) ?? [];

    foldersJson.removeWhere((json) {
      try {
        final map = _parseJsonString(json);
        return map['uri'] == uri;
      } catch (e) {
        return false;
      }
    });

    await prefs.setStringList(_prefKey, foldersJson);
  }

  // dart:convert handles booleans, nullables, and proper backslash escaping
  // (the prior hand-rolled code only escaped `"` and couldn't parse bool/null).
  String _toJsonString(Map<String, dynamic> map) => jsonEncode(map);

  Map<String, dynamic> _parseJsonString(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  Future<void> _saveFolderToDatabase(MusicFolder folder) async {
    final repository = FolderRepository();
    final entity = FolderEntity()
      ..uri = folder.uri
      ..displayName = folder.displayName
      ..dateAdded = folder.dateAdded
      ..songCount = 0
      ..isRemovable = folder.isRemovable
      ..mediaStoreVolume = folder.mediaStoreVolume
      ..volumeState = folder.volumeState;
    await repository.upsertFolder(entity);
  }

  Future<void> _removeFolderFromDatabase(String uri) async {
    final repository = FolderRepository();
    await repository.deleteFolder(uri);
  }

  static Future<bool> deleteDocument({
    required String folderTreeUri,
    required String filePath,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('deleteDocument', {
        'folderTreeUri': folderTreeUri,
        'filePath': filePath,
      }) ?? false;
    } catch (e) {
      devLog('deleteDocument failed: $e');
      return false;
    }
  }

  static Future<bool> removeFromMediaStore(String filePath) async {
    try {
      return await _channel.invokeMethod<bool>('removeFromMediaStore', {
        'filePath': filePath,
      }) ?? false;
    } catch (e) {
      devLog('removeFromMediaStore failed: $e');
      return false;
    }
  }
}
