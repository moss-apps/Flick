import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'replay_card_options.dart';
import 'replay_style.dart';

class ReplayCardSurface extends StatelessWidget {
  final ReplayCardPalette palette;
  final ReplayCardOptions options;
  final Widget child;
  final String? backgroundPath;
  final double radius;

  const ReplayCardSurface({
    super.key,
    required this.palette,
    required this.options,
    required this.child,
    this.backgroundPath,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AnimatedContainer(
        duration: ReplayStyle.duration(context),
        decoration: BoxDecoration(
          color: palette.background,
          border: options.surfaceDetail
              ? Border.all(color: palette.foreground.withValues(alpha: 0.075))
              : null,
          borderRadius: BorderRadius.circular(radius),
          gradient: options.surfaceDetail
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.background, palette.shadedBackground],
                )
              : null,
        ),
        child: Stack(
          children: [
            if (backgroundPath != null) ...[
              Positioned.fill(
                child: backgroundPath!.startsWith('http')
                    ? Image.network(
                        backgroundPath!,
                        fit: BoxFit.cover,
                        alignment: options.photoAlignment,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: palette.background),
                      )
                    : Image.file(
                        File(backgroundPath!),
                        fit: BoxFit.cover,
                        alignment: options.photoAlignment,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: palette.background),
                      ),
              ),
              // A white source photo is the worst case; this scrim still
              // leaves readable text without erasing the chosen image.
              const Positioned.fill(
                child: ColoredBox(color: Color(0xB8000000)),
              ),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class ReplayBrand extends StatelessWidget {
  final Color color;
  final double fontSize;

  const ReplayBrand({super.key, required this.color, this.fontSize = 16});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: SvgPicture.asset(
          'assets/icons/flicklogo_svg.svg',
          width: 16,
          height: 20,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          'Flick Replay',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class ReplaySignature extends StatelessWidget {
  final Color color;
  const ReplaySignature({super.key, required this.color});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
      ],
    ),
  );
}
