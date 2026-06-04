import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/features/whats_new/data/changelog_data.dart';
import 'package:flick/providers/whats_new_provider.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

class WhatsNewBottomSheet extends ConsumerWidget {
  const WhatsNewBottomSheet({super.key, this.entry});

  /// When `null`, falls back to the current version's changelog from the
  /// provider state. Pass an explicit entry to display any version.
  final ChangelogEntry? entry;

  static Future<T?> show<T>(BuildContext context, {ChangelogEntry? entry}) {
    return GlassBottomSheet.show<T>(
      context: context,
      title: "What's New",
      maxHeightRatio: 0.85,
      content: WhatsNewBottomSheet(entry: entry),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: 1,
            ),
            minimumSize: const Size(0, 16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Got it',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedEntry = entry ?? ref.watch(whatsNewProvider).currentEntry;
    if (resolvedEntry == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingLg),
        child: Text(
          'No changelog notes for this version yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.adaptiveTextSecondary,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        _VersionHeader(entry: resolvedEntry),
        const SizedBox(height: AppConstants.spacingMd),
        for (var i = 0; i < resolvedEntry.sections.length; i++) ...[
          _SectionBlock(section: resolvedEntry.sections[i]),
          if (i != resolvedEntry.sections.length - 1)
            const SizedBox(height: AppConstants.spacingLg),
        ],
        const SizedBox(height: AppConstants.spacingSm),
      ],
    );
  }
}

class _VersionHeader extends StatelessWidget {
  const _VersionHeader({required this.entry});

  final ChangelogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.18),
            AppColors.accentDim.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(
              LucideIcons.sparkles,
              color: context.adaptiveTextPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${entry.version}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.date,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final ChangelogSection section;

  @override
  Widget build(BuildContext context) {
    final hasSubsections = section.subsections.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.adaptiveTextPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        if (hasSubsections)
          ...section.subsections.expand(
            (sub) => [
              if (sub.title != null) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppConstants.spacingXs,
                    bottom: AppConstants.spacingXxs,
                  ),
                  child: Text(
                    sub.title!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.adaptiveTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...sub.bullets.map((b) => _BulletRow(bullet: b)),
              ] else
                ...sub.bullets.map((b) => _BulletRow(bullet: b)),
            ],
          )
        else
          ...section.bullets.map((b) => _BulletRow(bullet: b)),
      ],
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.bullet});

  final String bullet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spacingXxs,
        bottom: AppConstants.spacingXxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.adaptiveTextTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: _RichBullet(
              text: bullet,
              baseColor: context.adaptiveTextSecondary,
              boldColor: context.adaptiveTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a bullet line, styling any `**...**` spans as bold.
class _RichBullet extends StatelessWidget {
  const _RichBullet({
    required this.text,
    required this.baseColor,
    required this.boldColor,
  });

  final String text;
  final Color baseColor;
  final Color boldColor;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: baseColor, height: 1.45);
    if (baseStyle == null) return Text(text);
    final spans = _parseBoldSpans(text, baseStyle, boldColor);
    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  static List<InlineSpan> _parseBoldSpans(
    String input,
    TextStyle baseStyle,
    Color boldColor,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: baseStyle.copyWith(
            color: boldColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: input));
    }
    return spans;
  }
}
