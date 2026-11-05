/// User-selectable visible sizes for the player progress bar.
class ProgressBarSizes {
  static const double defaultWaveformHeight = 60;
  static const double minWaveformHeight = 24;
  static const double maxWaveformHeight = 96;
  static const double waveformHeightStep = 4;

  static const double defaultLineThickness = 3;
  static const double minLineThickness = 1;
  static const double maxLineThickness = 12;

  /// The seekbars keep this much vertical room for touch even when the
  /// visible waveform bars or line stroke are smaller.
  static const double minimumTouchTarget = 48;

  static const ProgressBarSizes defaults = ProgressBarSizes(
    waveformHeight: defaultWaveformHeight,
    lineThickness: defaultLineThickness,
  );

  const ProgressBarSizes({
    required this.waveformHeight,
    required this.lineThickness,
  });

  final double waveformHeight;
  final double lineThickness;

  static double clampWaveformHeight(double value) {
    return value.clamp(minWaveformHeight, maxWaveformHeight).toDouble();
  }

  static double clampLineThickness(double value) {
    return value.clamp(minLineThickness, maxLineThickness).toDouble();
  }

  ProgressBarSizes copyWith({double? waveformHeight, double? lineThickness}) {
    return ProgressBarSizes(
      waveformHeight: waveformHeight ?? this.waveformHeight,
      lineThickness: lineThickness ?? this.lineThickness,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProgressBarSizes &&
        other.waveformHeight == waveformHeight &&
        other.lineThickness == lineThickness;
  }

  @override
  int get hashCode => Object.hash(waveformHeight, lineThickness);
}
