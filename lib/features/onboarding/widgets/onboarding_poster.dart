import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/recap/widgets/replay_style.dart';

import 'onboarding_graphics.dart';

/// Onboarding inherits Replay's actual colors, not a parallel approximation.
class OnboardingPosterColors {
  const OnboardingPosterColors(this.background, this.foreground, this.accent);

  final Color background;
  final Color foreground;
  final Color accent;

  static const _pages = [
    OnboardingPosterColors(
      ReplayStyle.acid,
      ReplayStyle.ink,
      ReplayStyle.signal,
    ),
    OnboardingPosterColors(
      ReplayStyle.ink,
      ReplayStyle.paper,
      ReplayStyle.acid,
    ),
    OnboardingPosterColors(
      ReplayStyle.paper,
      ReplayStyle.ink,
      ReplayStyle.signal,
    ),
    OnboardingPosterColors(
      ReplayStyle.signal,
      ReplayStyle.ink,
      ReplayStyle.acid,
    ),
    OnboardingPosterColors(
      ReplayStyle.ink,
      ReplayStyle.paper,
      ReplayStyle.acid,
    ),
  ];

  static OnboardingPosterColors forPage(int index) => _pages[index];

  Color get button =>
      background == ReplayStyle.ink ? ReplayStyle.acid : ReplayStyle.ink;
  Color get onButton =>
      background == ReplayStyle.ink ? ReplayStyle.ink : background;
}

class OnboardingPoster extends StatelessWidget {
  const OnboardingPoster({
    super.key,
    required this.index,
    required this.title,
    required this.description,
    required this.active,
  });

  final int index;
  final String title;
  final String description;
  final bool active;

  TextStyle _fitHeading(BuildContext context, TextStyle style, double width) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    TextStyle atSize(double size) =>
        style.copyWith(fontSize: size, letterSpacing: -size * 0.035);
    bool fits(TextStyle candidate) {
      painter.text = TextSpan(text: title, style: candidate);
      painter.layout();
      // Flutter's intrinsic width respects localized word/line boundaries.
      return painter.minIntrinsicWidth <= width - 1;
    }

    try {
      if (fits(style)) return style;
      var low = 16.0;
      var high = style.fontSize!;
      // Measure with the actual TextScaler, including Android's nonlinear scale.
      for (var i = 0; i < 8; i++) {
        final mid = (low + high) / 2;
        if (fits(atSize(mid))) {
          low = mid;
        } else {
          high = mid;
        }
      }
      return atSize(low);
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OnboardingPosterColors.forPage(index);
    return ColoredBox(
      color: colors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 620 &&
                  constraints.maxWidth > constraints.maxHeight;
              final enlargedText =
                  MediaQuery.textScalerOf(context).scale(16) > 21;
              final width = wide
                  ? (constraints.maxWidth - 80) / 2
                  : constraints.maxWidth - 48;
              // Start with a reading tier for enlarged text, then measure its
              // words. TextScaler still applies to every copy block.
              final fontSize = (width * (enlargedText ? 0.115 : 0.17)).clamp(
                enlargedText ? 30.0 : 44.0,
                enlargedText ? 44.0 : (width >= 600 ? 96.0 : 72.0),
              );
              final displayStyle = TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontFamilyFallback: AppTheme.fontFamilyFallback,
                color: colors.foreground,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -fontSize * 0.035,
              );
              final heading = Semantics(
                header: true,
                child: Text(
                  title,
                  style: enlargedText
                      ? _fitHeading(context, displayStyle, width)
                      : displayStyle,
                ),
              );
              final body = Text(
                description,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontFamilyFallback: AppTheme.fontFamilyFallback,
                  color: colors.foreground,
                  fontSize: 16,
                  height: 1.5,
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [heading, const SizedBox(height: 20), body],
              );
              final graphic = OnboardingGraphic(
                index: index,
                active: active,
                foreground: colors.foreground,
                accent: colors.accent,
                background: colors.background,
              );

              if (wide) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 32),
                          Expanded(
                            child: SizedBox(
                              height: constraints.maxHeight.clamp(200, 400),
                              child: graphic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final art = SizedBox(
                height: (constraints.maxHeight * 0.44).clamp(
                  176,
                  constraints.maxWidth >= 620 ? 520 : 300,
                ),
                width: double.infinity,
                child: graphic,
              );
              // Change the poster's hierarchy, not just its accent and icon.
              final blocks = switch (index) {
                0 || 3 => [heading, art, body],
                1 || 4 => [art, copy],
                _ => [copy, art],
              };
              return SingleChildScrollView(
                key: PageStorageKey('onboarding-poster-$index'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < blocks.length; i++) ...[
                          if (i > 0) const SizedBox(height: 24),
                          blocks[i],
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
