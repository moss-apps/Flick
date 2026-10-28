import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/album_completeness.dart';

/// Tag-based status for a full library album, not an online edition match.
/// Completeness copy intentionally stays English in the Taglish UI.
class AlbumCompletenessStatusWidget extends StatelessWidget {
  final AlbumCompleteness completeness;

  const AlbumCompletenessStatusWidget({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    // Complete albums use the inline header badge, never a separate capsule.
    if (completeness.isComplete) return const SizedBox.shrink();
    final l10n = context.l10n.englishForFilipino;
    const color = AppColors.error;
    final details = <String>[
      if (completeness.missingDiscs.isNotEmpty)
        l10n.albumMissingDiscNumbers(_format(completeness.missingDiscs)),
      if (completeness.missingTracks.isNotEmpty)
        if (completeness.hasDiscSpecificMissingTracks)
          l10n.albumMissingPositions(_format(completeness.missingTracks))
        else
          l10n.albumMissingTrackNumbers(
            _format(completeness.missingTrackNumbers),
          ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingSm,
        AppConstants.spacingLg,
        0,
      ),
      child: completeness.isUnknown
          ? Container(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.glassBackgroundStrong,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 16,
                    color: context.adaptiveTextSecondary,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Expanded(
                    child: Text(
                      l10n.albumCompletenessUnknown,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppConstants.spacingXs,
                  runSpacing: AppConstants.spacingXs,
                  children: [
                    _StatusPill(
                      color: color,
                      icon: LucideIcons.triangleAlert,
                      label: l10n.albumIncompleteShort,
                    ),
                    if (completeness.missingTracks.isNotEmpty)
                      _StatusPill(
                        color: color,
                        icon: LucideIcons.music4,
                        label: l10n.albumMissingTracks(
                          completeness.missingTracks.length,
                        ),
                      ),
                    if (completeness.missingDiscs.isNotEmpty)
                      _StatusPill(
                        color: color,
                        icon: LucideIcons.disc3,
                        label: l10n.albumMissingDiscs(
                          completeness.missingDiscs.length,
                        ),
                      ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingXs),
                  Text(
                    details.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  String _format(Iterable<Object> values) {
    final shown = values.take(12).join(', ');
    return values.length > 12 ? '$shown…' : shown;
  }
}

/// Verified-complete indicator in the album header's metadata line.
class AlbumVerifiedBadge extends StatelessWidget {
  final AlbumCompleteness completeness;

  const AlbumVerifiedBadge({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    if (!completeness.isComplete) return const SizedBox.shrink();
    final l10n = context.l10n.englishForFilipino;
    return Tooltip(
      message: l10n.albumComplete,
      excludeFromSemantics: true,
      child: Semantics(
        label: l10n.albumComplete,
        child: TextButton(
          onPressed: () => _showVerificationSheet(context),
          style: TextButton.styleFrom(
            foregroundColor: context.adaptiveTextTertiary,
            textStyle: Theme.of(context).textTheme.bodySmall,
            // Keep the badge on the same text line as the lossless indicator.
            // A 48dp minimum height would inflate the header's metadata row.
            minimumSize: const Size(48, 0),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.badgeCheck,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppConstants.spacingXxs),
                Text(l10n.albumCompleteShort),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVerificationSheet(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppConstants.animationNormal,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final l10n = context.l10n.englishForFilipino;
        return SafeArea(
          child: Dialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.all(AppConstants.spacingMd),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              side: BorderSide(color: AppColors.glassBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingLg,
                      AppConstants.spacingSm,
                      AppConstants.spacingSm,
                      0,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.badgeCheck,
                          color: AppColors.success,
                          size: 22,
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l10n.albumCompleteTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingXxs),
                        IconButton(
                          tooltip: l10n.close,
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(LucideIcons.x, size: 20),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingLg,
                        AppConstants.spacingSm,
                        AppConstants.spacingLg,
                        AppConstants.spacingLg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.albumCompleteExplanation,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          Text(
                            l10n.albumCompleteVerificationNote,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact artwork indicator. Unknown results deliberately have no badge.
class AlbumCompletenessBadge extends StatelessWidget {
  final AlbumCompleteness completeness;

  const AlbumCompletenessBadge({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    if (completeness.isUnknown) return const SizedBox.shrink();
    final l10n = context.l10n.englishForFilipino;
    final color = completeness.isComplete ? AppColors.success : AppColors.error;
    final label = completeness.isComplete
        ? l10n.albumCompleteShort
        : l10n.albumIncompleteShort;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        label: label,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Icon(
            completeness.isComplete
                ? LucideIcons.circleCheck
                : LucideIcons.triangleAlert,
            size: 14,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatusPill({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppConstants.spacingXxs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
