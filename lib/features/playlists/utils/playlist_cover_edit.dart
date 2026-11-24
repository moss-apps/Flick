import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Colour treatment applied on top of a playlist cover crop.
enum PlaylistCoverFilter { original, mono, warm, cool, fade, punch, noir }

/// A 4x5 colour matrix in the same layout as [ColorFilter.matrix].
///
/// Offsets are expressed in 0..255 channel units. The editor uses one matrix
/// for the live preview and the export so both paths produce the same colours.
@immutable
class CoverColorMatrix {
  const CoverColorMatrix(this.values);

  static const CoverColorMatrix identity = CoverColorMatrix(<double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  final List<double> values;

  /// Returns a matrix that applies [inner] first, then this matrix.
  CoverColorMatrix compose(CoverColorMatrix inner) {
    final a = values;
    final b = inner.values;
    final result = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      final rowOffset = row * 5;
      for (var column = 0; column < 4; column++) {
        result[rowOffset + column] =
            a[rowOffset] * b[column] +
            a[rowOffset + 1] * b[5 + column] +
            a[rowOffset + 2] * b[10 + column] +
            a[rowOffset + 3] * b[15 + column];
      }
      result[rowOffset + 4] =
          a[rowOffset] * b[4] +
          a[rowOffset + 1] * b[9] +
          a[rowOffset + 2] * b[14] +
          a[rowOffset + 3] * b[19] +
          a[rowOffset + 4];
    }
    return CoverColorMatrix(result);
  }

  bool get isIdentity {
    for (var i = 0; i < 20; i++) {
      if ((values[i] - identity.values[i]).abs() > 1e-6) return false;
    }
    return true;
  }
}

CoverColorMatrix _channelGains(double red, double green, double blue) {
  return CoverColorMatrix(<double>[
    red,
    0,
    0,
    0,
    0,
    0,
    green,
    0,
    0,
    0,
    0,
    0,
    blue,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

CoverColorMatrix _contrastScale(double scale) {
  final offset = 128.0 * (1 - scale);
  return CoverColorMatrix(<double>[
    scale,
    0,
    0,
    0,
    offset,
    0,
    scale,
    0,
    0,
    offset,
    0,
    0,
    scale,
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ]);
}

CoverColorMatrix _brightnessOffset(double offset) {
  return CoverColorMatrix(<double>[
    1,
    0,
    0,
    0,
    offset,
    0,
    1,
    0,
    0,
    offset,
    0,
    0,
    1,
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ]);
}

CoverColorMatrix _saturationScale(double scale) {
  // Rec. 709 luma weights, matching how the eye perceives desaturation.
  const lumaRed = 0.2126;
  const lumaGreen = 0.7152;
  const lumaBlue = 0.0722;
  final inverse = 1 - scale;
  final red = lumaRed * inverse;
  final green = lumaGreen * inverse;
  final blue = lumaBlue * inverse;
  return CoverColorMatrix(<double>[
    red + scale,
    green,
    blue,
    0,
    0,
    red,
    green + scale,
    blue,
    0,
    0,
    red,
    green,
    blue + scale,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

final CoverColorMatrix _monoMatrix = _saturationScale(
  0,
).compose(_contrastScale(1.08));

final CoverColorMatrix _warmMatrix = _channelGains(
  1.06,
  1.01,
  0.94,
).compose(_saturationScale(1.04));

final CoverColorMatrix _coolMatrix = _channelGains(
  0.94,
  1.0,
  1.06,
).compose(_saturationScale(1.04));

final CoverColorMatrix _fadeMatrix = _saturationScale(
  0.82,
).compose(_brightnessOffset(10).compose(_contrastScale(0.88)));

final CoverColorMatrix _punchMatrix = _saturationScale(
  1.18,
).compose(_contrastScale(1.12));

final CoverColorMatrix _noirMatrix = _saturationScale(
  0,
).compose(_brightnessOffset(-6).compose(_contrastScale(1.2)));

/// Immutable state of the playlist cover editor.
///
/// Orientation is represented as a rotation followed by a horizontal mirror:
/// `display = rotate(quarterTurns) * flipHorizontal(mirrored)`. Crop geometry
/// is always expressed in the oriented image's coordinate space.
@immutable
class PlaylistCoverEdit {
  const PlaylistCoverEdit({
    this.quarterTurns = 0,
    this.mirrored = false,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.vignette = 0,
    this.filter = PlaylistCoverFilter.original,
  }) : assert(quarterTurns >= 0 && quarterTurns < 4),
       assert(brightness >= -1 && brightness <= 1),
       assert(contrast >= -1 && contrast <= 1),
       assert(saturation >= -1 && saturation <= 1),
       assert(warmth >= -1 && warmth <= 1),
       assert(vignette >= 0 && vignette <= 1);

  final int quarterTurns;
  final bool mirrored;
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;
  final double vignette;
  final PlaylistCoverFilter filter;

  bool get hasEdits =>
      quarterTurns != 0 ||
      mirrored ||
      brightness != 0 ||
      contrast != 0 ||
      saturation != 0 ||
      warmth != 0 ||
      vignette != 0 ||
      filter != PlaylistCoverFilter.original;

  Size orientedSize(Size source) =>
      quarterTurns.isOdd ? Size(source.height, source.width) : source;

  /// Matrix for the manual sliders, before the selected filter.
  CoverColorMatrix get manualColorMatrix {
    var matrix = CoverColorMatrix.identity;
    if (warmth != 0) {
      matrix = _channelGains(
        1 + 0.12 * warmth,
        1,
        1 - 0.12 * warmth,
      ).compose(matrix);
    }
    if (contrast != 0) {
      matrix = _contrastScale(1 + 0.5 * contrast).compose(matrix);
    }
    if (brightness != 0) {
      matrix = _brightnessOffset(0.18 * 255 * brightness).compose(matrix);
    }
    if (saturation != 0) {
      matrix = _saturationScale(1 + saturation).compose(matrix);
    }
    return matrix;
  }

  /// Filter first, then the manual adjustments, so a preset is a starting point
  /// rather than a reset of the sliders.
  CoverColorMatrix get colorMatrix => manualColorMatrix.compose(filter.matrix);

  PlaylistCoverEdit copyWith({
    int? quarterTurns,
    bool? mirrored,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? vignette,
    PlaylistCoverFilter? filter,
  }) {
    return PlaylistCoverEdit(
      quarterTurns: quarterTurns ?? this.quarterTurns,
      mirrored: mirrored ?? this.mirrored,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      warmth: warmth ?? this.warmth,
      vignette: vignette ?? this.vignette,
      filter: filter ?? this.filter,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaylistCoverEdit &&
            quarterTurns == other.quarterTurns &&
            mirrored == other.mirrored &&
            brightness == other.brightness &&
            contrast == other.contrast &&
            saturation == other.saturation &&
            warmth == other.warmth &&
            vignette == other.vignette &&
            filter == other.filter;
  }

  @override
  int get hashCode => Object.hash(
    quarterTurns,
    mirrored,
    brightness,
    contrast,
    saturation,
    warmth,
    vignette,
    filter,
  );

  PlaylistCoverEdit rotateClockwise() =>
      copyWith(quarterTurns: (quarterTurns + 1) % 4);

  PlaylistCoverEdit rotateCounterClockwise() =>
      copyWith(quarterTurns: (quarterTurns + 3) % 4);

  PlaylistCoverEdit flipHorizontal() =>
      copyWith(quarterTurns: (4 - quarterTurns) % 4, mirrored: !mirrored);

  PlaylistCoverEdit flipVertical() =>
      copyWith(quarterTurns: (2 - quarterTurns + 4) % 4, mirrored: !mirrored);
}

extension PlaylistCoverFilterMatrix on PlaylistCoverFilter {
  CoverColorMatrix get matrix => switch (this) {
    PlaylistCoverFilter.original => CoverColorMatrix.identity,
    PlaylistCoverFilter.mono => _monoMatrix,
    PlaylistCoverFilter.warm => _warmMatrix,
    PlaylistCoverFilter.cool => _coolMatrix,
    PlaylistCoverFilter.fade => _fadeMatrix,
    PlaylistCoverFilter.punch => _punchMatrix,
    PlaylistCoverFilter.noir => _noirMatrix,
  };
}
