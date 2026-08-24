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

  const SolidColorShareCard({
    super.key,
    required this.song,
    this.dominantColor,
    this.albumArtPath,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = dominantColor ?? const Color(0xFF1A1A1A);
    final brighter = HSLColor.fromColor(bgColor).withLightness(0.35).toColor();
    final darker = HSLColor.fromColor(bgColor).withLightness(0.08).toColor();

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
            child: Column(
              children: [
                const Spacer(flex: 2),
                if (albumArtPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: Image.file(
                        File(albumArtPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _artPlaceholder(),
                      ),
                    ),
                  )
                else
                  _artPlaceholder(),
                const SizedBox(height: 24),
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
              ],
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
