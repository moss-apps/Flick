import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';

class MinimalShareCard extends StatelessWidget {
  final Song song;
  final String? albumArtPath;

  /// Optional reframed square for the foreground cover. The blurred backdrop
  /// keeps using [albumArtPath] so only the subject is affected by the edit.
  final String? coverArtPath;
  final double textScale;

  const MinimalShareCard({
    super.key,
    required this.song,
    this.albumArtPath,
    this.coverArtPath,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final coverPath = coverArtPath ?? albumArtPath;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (albumArtPath != null)
            Image.file(
              File(albumArtPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.background),
            )
          else
            Container(color: AppColors.background),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: const SizedBox.expand(),
          ),
          Container(color: AppColors.background.withValues(alpha: 0.75)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    coverPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: Image.file(
                                File(coverPath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _artPlaceholder(),
                              ),
                            ),
                          )
                        : _artPlaceholder(),
                    const SizedBox(height: 20),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18 * textScale,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                song.artist,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14 * textScale,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: SvgPicture.asset(
              'assets/icons/flicklogo_svg.svg',
              width: 56,
              height: 20,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.45),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _artPlaceholder() => Container(
    width: 160,
    height: 160,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const FlickArtworkPlaceholder(size: 52, opacity: 0.9),
  );
}
