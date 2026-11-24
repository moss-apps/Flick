import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flick/models/song.dart';

class SolidColorShareCard extends StatelessWidget {
  final Song song;
  final Color? dominantColor;
  final String? albumArtPath;

  /// Optional reframed square for the foreground cover. The blurred backdrop
  /// keeps using [albumArtPath] so only the subject is affected by the edit.
  final String? coverArtPath;
  final double textScale;

  const SolidColorShareCard({
    super.key,
    required this.song,
    this.dominantColor,
    this.albumArtPath,
    this.coverArtPath,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = dominantColor ?? const Color(0xFF1A1A1A);
    final brighter = HSLColor.fromColor(bgColor).withLightness(0.35).toColor();
    final darker = HSLColor.fromColor(bgColor).withLightness(0.08).toColor();
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
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [brighter, darker],
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [brighter, darker],
                ),
              ),
            ),
          Container(color: Colors.black.withValues(alpha: 0.5)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: const SizedBox.expand(),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brighter.withValues(alpha: 0.6),
                  darker.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
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
                              width: 140,
                              height: 140,
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
                                  color: Colors.white.withValues(alpha: 0.7),
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
    width: 140,
    height: 140,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const FlickArtworkPlaceholder(size: 62, opacity: 0.9),
  );
}
