import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:flick/features/player/widgets/motion_art_widget.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

/// Apple Music-style hero art: slow Ken Burns pan/zoom with a soft
/// pulsing glow derived from the art's dominant color.
///
/// When [albumName] and [artistName] are supplied (album detail heroes), real
/// Apple Music Motion Art is played instead, falling back to the Ken Burns
/// effect whenever no motion art exists for the album.
class AnimatedAlbumArt extends StatefulWidget {
  final String? imagePath;
  final String? audioSourcePath;
  final Color? dominantColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Album metadata enabling the edition-aware Motion Art lookup.
  final String? albumName;
  final String? artistName;
  final String? representativeSongTitle;

  /// Prefer the portrait motion-art variant (full-bleed backgrounds).
  final bool preferVertical;

  const AnimatedAlbumArt({
    super.key,
    this.imagePath,
    this.audioSourcePath,
    this.dominantColor,
    this.placeholder,
    this.errorWidget,
    this.albumName,
    this.artistName,
    this.representativeSongTitle,
    this.preferVertical = false,
  });

  @override
  State<AnimatedAlbumArt> createState() => _AnimatedAlbumArtState();
}

class _AnimatedAlbumArtState extends State<AnimatedAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    // Deferred so the system reduced-motion flag is available before
    // deciding whether to keep animating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MediaQuery.of(context).disableAnimations) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = CachedImageWidget(
      imagePath: widget.imagePath,
      audioSourcePath: widget.audioSourcePath,
      fit: BoxFit.cover,
      placeholder: widget.placeholder,
      errorWidget: widget.errorWidget,
    );
    final kenBurns = ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          final glow = widget.dominantColor;
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: 1.0 + 0.12 * t,
                child: child,
              ),
              if (glow != null)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 1.2,
                        colors: [
                          glow.withValues(alpha: 0.0),
                          glow.withValues(alpha: 0.12 + 0.18 * t),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: image,
      ),
    );

    final album = widget.albumName?.trim() ?? '';
    final artist = widget.artistName?.trim() ?? '';
    if (album.isEmpty || artist.isEmpty) return kenBurns;

    final motion = MotionArtView(
      title: album,
      album: album,
      artist: artist,
      albumMode: true,
      representativeSongTitle: widget.representativeSongTitle,
      preferVertical: widget.preferVertical,
      fit: widget.preferVertical ? BoxFit.contain : BoxFit.cover,
      enabled: !MediaQuery.of(context).disableAnimations,
      fallback: kenBurns,
    );

    if (!widget.preferVertical) return motion;

    // Portrait art is letterboxed on a tall screen; a blurred, zoomed copy of
    // the same cover fills the exposed edges so there are no black bars.
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Transform.scale(
            scale: 1.2,
            child: CachedImageWidget(
              imagePath: widget.imagePath,
              audioSourcePath: widget.audioSourcePath,
              fit: BoxFit.cover,
              placeholder: widget.placeholder,
              errorWidget: widget.errorWidget,
            ),
          ),
        ),
        motion,
      ],
    );
  }
}
