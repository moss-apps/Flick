import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Centered Flick logo used when album art is missing.
///
/// Used as placeholder/errorWidget inside [CachedImageWidget] fallbacks.
/// The SVG `assets/icons/flicklogo_svg.svg` is white `#F5F5F5` on
/// transparent, so it is rendered on a dark surface and dimmed via
/// [opacity] to match the previous `Icon(..., white 0.48)` look.
class FlickArtworkPlaceholder extends StatelessWidget {
  const FlickArtworkPlaceholder({
    super.key,
    this.size = 48,
    this.opacity = 1.0,
    this.color,
  });

  final double size;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // SVG viewBox is 606×734 (0.826 ratio). Constrain both axes so layout
    // stays square and centered regardless of parent constraints.
    final logo = SvgPicture.asset(
      'assets/icons/flicklogo_svg.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );

    if (opacity >= 1.0) {
      return Center(child: logo);
    }
    return Center(
      child: Opacity(opacity: opacity, child: logo),
    );
  }
}
