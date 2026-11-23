import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/album_color_mode.dart';

class AlbumColorModePreferenceService {
  static const _key = 'album_color_mode';
  static const _vibrantDefaultMigrationKey =
      'album_color_mode_vibrant_default_migrated';

  Future<AlbumColorMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateToVibrantDefault(prefs);
    return AlbumColorModeX.fromStorageValue(prefs.getString(_key));
  }

  Future<void> setMode(AlbumColorMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.storageValue);
  }

  /// Makes [AlbumColorMode.vibrant] the shipped default.
  ///
  /// New installations have no stored mode, and installations upgrading from
  /// a build where `off` was the default still have `off` persisted. Both are
  /// rewritten to `vibrant` exactly once. An explicit `off` chosen after this
  /// migration is kept, as are stored `subtle`, `moderate`, and `vibrant`.
  Future<void> migrateToVibrantDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateToVibrantDefault(prefs);
  }

  Future<void> _migrateToVibrantDefault(SharedPreferences prefs) async {
    if (prefs.getBool(_vibrantDefaultMigrationKey) == true) return;
    final stored = prefs.getString(_key);
    if (stored == null ||
        AlbumColorModeX.fromStorageValue(stored) == AlbumColorMode.off) {
      await prefs.setString(_key, AlbumColorMode.vibrant.storageValue);
    }
    await prefs.setBool(_vibrantDefaultMigrationKey, true);
  }
}
