import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/adaptive_colors.dart';
import 'package:flick/core/theme/app_colors.dart';

/// Shared detail-screen header: full-bleed art fading into the page
/// background at the bottom, with the title block overlaid on the gradient.
class DetailHeader extends StatelessWidget {
  final bool expanded;
  final bool centeredTitle;
  final Widget Function(BuildContext context) artBuilder;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final String? meta;
  final bool lossless;
  final Color fadeTo;
  final VoidCallback onBack;

  const DetailHeader({
    super.key,
    required this.expanded,
    required this.centeredTitle,
    required this.artBuilder,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.fadeTo,
    required this.onBack,
    this.subtitleMaxLines = 1,
    this.lossless = false,
  });

  double _resolveHeight(BuildContext context) {
    if (!expanded) return 300;
    return (MediaQuery.of(context).size.height * 0.55).clamp(360.0, 560.0);
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = expanded
        ? [
            Colors.transparent,
            Colors.transparent,
            fadeTo.withValues(alpha: 0.9),
            fadeTo,
          ]
        : [Colors.transparent, fadeTo.withValues(alpha: 0.8), fadeTo];
    final align = centeredTitle
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centeredTitle ? TextAlign.center : TextAlign.start;

    // ponytail: solid base + 1px overlap seal; same-color adjacent paints hairline otherwise
    return SliverToBoxAdapter(
      child: SizedBox(
        height: _resolveHeight(context),
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ColoredBox(color: fadeTo),
            artBuilder(context),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                  stops: expanded
                      ? const [0.0, 0.55, 0.85, 1.0]
                      : const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: 3,
              child: ColoredBox(color: fadeTo),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppConstants.glassBlurSigma,
                    sigmaY: AppConstants.glassBlurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.glassBackgroundStrong,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: IconButton(
                      icon: Icon(
                        LucideIcons.chevronLeft,
                        color: context.adaptiveTextPrimary,
                      ),
                      onPressed: onBack,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppConstants.spacingLg,
              right: AppConstants.spacingLg,
              bottom: 4,
              child: Column(
                crossAxisAlignment: align,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: context.adaptiveTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: textAlign,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.adaptiveTextSecondary,
                      ),
                      textAlign: textAlign,
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                if (meta != null || lossless) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (meta != null) TextSpan(text: meta),
                        if (meta != null && lossless)
                          const TextSpan(text: ' · '),
                        if (lossless) ...[
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              LucideIcons.audioWaveform,
                              size: 14,
                              color: context.adaptiveTextSecondary,
                            ),
                          ),
                          const TextSpan(text: ' Lossless'),
                        ],
                      ],
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
                    textAlign: textAlign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliced action capsule for detail screens: one pill split into
/// favorite / shuffle / play / queue / more segments on the
/// dominant-color gradient.
class DetailActionCapsule extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShuffle;
  final VoidCallback onPlay;
  final VoidCallback onQueue;
  final VoidCallback onMore;
  final Color? primaryColor;

  const DetailActionCapsule({
    super.key,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onShuffle,
    required this.onPlay,
    required this.onQueue,
    required this.onMore,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? AppColors.accent;
    final fg = AdaptiveColors.textPrimaryOn(color);
    final divider = fg.withValues(alpha: 0.28);

    Widget segment({
      required String tooltip,
      required Widget child,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Tooltip(message: tooltip, child: child),
          ),
        ),
      );
    }

    Widget slice() {
      return SizedBox(
        width: 1,
        height: 26,
        child: ColoredBox(color: divider),
      );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.18)!, color],
            ),
          ),
          child: Row(
            children: [
              segment(
                tooltip: isFavorite ? 'Remove from favorites' : 'Favorite all',
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
                  color: fg,
                  size: 21,
                ),
                onTap: onToggleFavorite,
              ),
              slice(),
              segment(
                tooltip: 'Shuffle',
                child: Icon(LucideIcons.shuffle, color: fg, size: 21),
                onTap: onShuffle,
              ),
              slice(),
              segment(
                tooltip: 'Play',
                child: Icon(LucideIcons.play, color: fg, size: 24),
                onTap: onPlay,
              ),
              slice(),
              segment(
                tooltip: 'Queue',
                child: Icon(LucideIcons.listMusic, color: fg, size: 21),
                onTap: onQueue,
              ),
              slice(),
              segment(
                tooltip: 'More',
                child: Icon(
                  LucideIcons.ellipsisVertical,
                  color: fg,
                  size: 21,
                ),
                onTap: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item shown in [DetailMoreSheet].
class DetailMoreSheetItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DetailMoreSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Shared overflow bottom sheet for the detail screens' more segment.
class DetailMoreSheet extends StatelessWidget {
  final List<DetailMoreSheetItem> items;

  const DetailMoreSheet({super.key, required this.items});

  static Future<void> show(
    BuildContext context, {
    required List<DetailMoreSheetItem> items,
  }) {
    return showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DetailMoreSheet(items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'More',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            ListTile(
              leading: Icon(
                item.icon,
                color: context.adaptiveTextSecondary,
                size: 22,
              ),
              title: Text(
                item.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.adaptiveTextPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                item.onTap();
              },
            ),
        ],
      ),
    );
  }
}
