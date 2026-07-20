import 'package:flutter/material.dart';

import 'package:flick/widgets/common/cached_image_widget.dart';

/// Apple Music-style hero art: slow Ken Burns pan/zoom with a soft
/// pulsing glow derived from the art's dominant color.
class AnimatedAlbumArt extends StatefulWidget {
  final String? imagePath;
  final String? audioSourcePath;
  final Color? dominantColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AnimatedAlbumArt({
    super.key,
    this.imagePath,
    this.audioSourcePath,
    this.dominantColor,
    this.placeholder,
    this.errorWidget,
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
    )..repeat(reverse: true);
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
    return ClipRect(
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
                child: FractionalTranslation(
                  translation: Offset(0.03 * t, -0.02 * t),
                  child: child,
                ),
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
  }
}
