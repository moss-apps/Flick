import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One labelled paragraph in a settings information sheet.
class SettingsInfoSection {
  const SettingsInfoSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// Explains how a setting or integration handles data. Kept to plain
/// statements about what the app actually does.
Future<void> showSettingsInfoSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String intro,
  required List<SettingsInfoSection> sections,
  bool warning = false,
}) {
  const warningColor = Color(0xFFD4A030);
  final accent = warning ? warningColor : AppColors.textSecondary;

  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => AppBottomSheetSurface(
      maxHeightRatio: 0.88,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(LucideIcons.x, size: 18),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            intro,
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          for (final section in sections) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              section.heading,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.body,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: AppColors.textTertiary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingSm),
        ],
      ),
    ),
  );
}
