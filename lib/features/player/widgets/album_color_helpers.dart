import 'package:flutter/material.dart';

const Color _darkBase = Color(0xFF121212);

Color albumSurface(Color albumColor, double blend) =>
    Color.lerp(_darkBase, albumColor, blend)!;

Color albumAccent(Color albumColor, double blend) {
  final hsl = HSLColor.fromColor(albumColor);
  return hsl
      .withSaturation((hsl.saturation * 0.7).clamp(0.3, 0.8))
      .withLightness(0.65)
      .toColor()
      .withValues(alpha: (blend + 0.3).clamp(0.0, 1.0));
}
