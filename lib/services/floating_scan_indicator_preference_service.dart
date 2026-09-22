import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/floating_scan_indicator_side.dart';

class FloatingScanIndicatorPreferenceService {
  static const _sideKey = 'floating_scan_indicator_side';
  static const _yFractionKey = 'floating_scan_indicator_y_fraction';

  Future<FloatingScanIndicatorSide> getSide() async {
    final prefs = await SharedPreferences.getInstance();
    return FloatingScanIndicatorSideX.fromStorageValue(
      prefs.getString(_sideKey),
    );
  }

  Future<void> setSide(FloatingScanIndicatorSide side) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sideKey, side.storageValue);
  }

  Future<double?> getYFraction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_yFractionKey);
  }

  Future<void> setYFraction(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_yFractionKey, value);
  }
}
