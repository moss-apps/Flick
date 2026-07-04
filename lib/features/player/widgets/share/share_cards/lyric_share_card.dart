import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flick/models/song.dart';

class LyricShareCard extends StatelessWidget {
  final Song song;
  final String? lyricLine;
  final String? albumArtPath;
  final double? fontSizeOverride;

  const LyricShareCard({
    super.key,
    required this.song,
    this.lyricLine,
    this.albumArtPath,
    this.fontSizeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final displayLyric = lyricLine ?? '♪ ♪ ♪';

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (albumArtPath != null)
            Image.file(
              File(albumArtPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackBackground(),
            )
          else
            _fallbackBackground(),
          Container(color: Colors.black.withValues(alpha: 0.55)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: const SizedBox.expand(),
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const metaHeight = 20.0 + 4.0 + 16.0 + 20.0; // title + gap + artist + lyric gap
                const spacerReserve = 24.0;
                final availH = (constraints.maxHeight - metaHeight - spacerReserve)
                    .clamp(0.0, double.infinity);
                final size = fontSizeOverride ??
                    _fitFontSize(displayLyric, constraints.maxWidth, availH);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 3),
                    Text(
                      displayLyric,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      song.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
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

  double _fitFontSize(String text, double width, double maxHeight,
      [double max = 34]) {
    if (text.isEmpty || maxHeight <= 0 || width <= 0) return max;
    const min = 14.0;
    double lo = min, hi = max;
    for (int i = 0; i < 8; i++) {
      final mid = (lo + hi) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: mid,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      if (tp.height <= maxHeight) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  Widget _fallbackBackground() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Center(
      child: Icon(Icons.music_note_rounded, color: Color(0xFF404040), size: 64),
    ),
  );
}
