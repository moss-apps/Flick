import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Caches file fingerprints (path -> lastModifiedMs) per folder,
/// so re-scans can diff against disk without loading the full song DB.
class FileFingerprintCache {
  final Map<String, Map<String, int>> _cache = {};

  String _keyForFolder(String folderUri) {
    return md5.convert(utf8.encode(folderUri)).toString();
  }

  Future<String> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/flick_fingerprints';
  }

  Future<Map<String, int>?> load(String folderUri) async {
    if (_cache.containsKey(folderUri)) return _cache[folderUri]!;
    try {
      final key = _keyForFolder(folderUri);
      final dir = await _cacheDir();
      final file = File('$dir/$key.json');
      if (!file.existsSync()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final map = <String, int>{};
      for (final entry in json.entries) {
        map[entry.key] = (entry.value as num).toInt();
      }
      _cache[folderUri] = map;
      return map;
    } catch (e) {
      devLog('[FingerprintCache] Load error: $e');
      return null;
    }
  }

  Future<void> save(String folderUri, Map<String, int> fingerprints) async {
    _cache[folderUri] = Map.from(fingerprints);
    try {
      final key = _keyForFolder(folderUri);
      final dir = await _cacheDir();
      final dirEntity = Directory(dir);
      if (!dirEntity.existsSync()) {
        dirEntity.createSync(recursive: true);
      }
      final file = File('$dir/$key.json');
      await file.writeAsString(jsonEncode(fingerprints));
    } catch (e) {
      devLog('[FingerprintCache] Save error: $e');
    }
  }

  Future<void> sync(
    String folderUri,
    Map<String, int> newOrModified,
    List<String> deleted,
  ) async {
    final current = await load(folderUri) ?? {};
    for (final path in deleted) {
      current.remove(path);
    }
    current.addAll(newOrModified);
    await save(folderUri, current);
  }

  /// Clear cache for a specific folder (e.g. when folder is removed).
  Future<void> removeFolder(String folderUri) async {
    _cache.remove(folderUri);
    try {
      final key = _keyForFolder(folderUri);
      final dir = await _cacheDir();
      final file = File('$dir/$key.json');
      if (file.existsSync()) await file.delete();
    } catch (e) {
      devLog('[FingerprintCache] Remove error: $e');
    }
  }
}
