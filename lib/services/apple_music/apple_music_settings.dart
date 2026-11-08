import 'package:shared_preferences/shared_preferences.dart';

class AppleMusicSettings {
  static const _keyAutoEnrich = 'apple_music_auto_enrich';
  static const _keyPageInfo = 'apple_music_page_info_enabled';

  Future<bool> autoEnrichEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoEnrich) ?? false;
  }

  Future<void> setAutoEnrichEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoEnrich, value);
  }

  /// Whether artist and album pages may fetch Apple Music page information
  /// (biographies, similar artists, top songs, album notes, and portraits).
  Future<bool> pageInfoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPageInfo) ?? true;
  }

  Future<void> setPageInfoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPageInfo, value);
  }
}
