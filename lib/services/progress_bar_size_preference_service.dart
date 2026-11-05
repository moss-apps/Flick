import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/progress_bar_size.dart';

class ProgressBarSizePreferenceService {
  static const waveformHeightKey = 'progress_bar_waveform_height';
  static const lineThicknessKey = 'progress_bar_line_thickness';

  Future<ProgressBarSizes> getSizes() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressBarSizes(
      waveformHeight: ProgressBarSizes.clampWaveformHeight(
        prefs.getDouble(waveformHeightKey) ??
            ProgressBarSizes.defaultWaveformHeight,
      ),
      lineThickness: ProgressBarSizes.clampLineThickness(
        prefs.getDouble(lineThicknessKey) ??
            ProgressBarSizes.defaultLineThickness,
      ),
    );
  }

  Future<void> setSizes(ProgressBarSizes sizes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      waveformHeightKey,
      ProgressBarSizes.clampWaveformHeight(sizes.waveformHeight),
    );
    await prefs.setDouble(
      lineThicknessKey,
      ProgressBarSizes.clampLineThickness(sizes.lineThickness),
    );
  }
}
