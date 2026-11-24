import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bundled service marks under `assets/icons/brands/`.
abstract final class BrandAssets {
  static const applemusic = 'assets/icons/brands/applemusic.svg';
  static const discord = 'assets/icons/brands/discord.svg';
  static const dlna = 'assets/icons/brands/dlna.svg';
  static const github = 'assets/icons/brands/github.svg';
  static const jellyfin = 'assets/icons/brands/jellyfin.svg';
  static const lastfm = 'assets/icons/brands/lastfm.svg';
  static const listenbrainz = 'assets/icons/brands/listenbrainz.svg';
  static const subsonic = 'assets/icons/brands/subsonic.png';
  static const tidal = 'assets/icons/brands/tidal.svg';
}

/// Renders a bundled service logo from `assets/icons/brands/`.
///
/// SVGs are drawn through [SvgPicture]; PNGs use [Image.asset]. When [color]
/// is supplied the mark is tinted, which is useful for logos whose official
/// wordmark is black/white on transparent.
class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.asset,
    this.size = 24,
    this.color,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final Color? color;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    final excludeFromSemantics = semanticLabel == null;

    if (asset.toLowerCase().endsWith('.png')) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: fit,
        color: tint,
        colorBlendMode: tint == null ? null : BlendMode.srcIn,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      );
    }

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }
}
