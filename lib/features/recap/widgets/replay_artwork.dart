import 'package:flutter/material.dart';

import '../../../widgets/common/cached_image_widget.dart';
import '../../../widgets/common/flick_artwork_placeholder.dart';
import 'replay_style.dart';

class ReplayArtwork extends StatelessWidget {
  final String? path;
  final double size;
  final bool useThumbnail;

  const ReplayArtwork({
    super.key,
    this.path,
    required this.size,
    this.useThumbnail = true,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: ReplayStyle.surface,
      child: Center(
        child: FlickArtworkPlaceholder(size: size * 0.35, opacity: 0.8),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedImageWidget(
          imagePath: path,
          useThumbnail: useThumbnail,
          fit: BoxFit.cover,
          placeholder: fallback,
          errorWidget: fallback,
        ),
      ),
    );
  }
}
