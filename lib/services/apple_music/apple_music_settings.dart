import 'package:shared_preferences/shared_preferences.dart';

class AppleMusicSettings {
  static const _keyAutoEnrich = 'apple_music_auto_enrich';

  Future<bool> autoEnrichEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoEnrich) ?? false;
  }

  Future<void> setAutoEnrichEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoEnrich, value);
  }
}
