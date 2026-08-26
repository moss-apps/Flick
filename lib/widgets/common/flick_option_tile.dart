import 'package:flick/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';

/// Selectable option tile for Flick dialogs: title, optional description,
/// and a check mark when selected.
class FlickOptionTile extends StatelessWidget {
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const FlickOptionTile({
    super.key,
    required this.title,
    this.description,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.1)
                : AppColors.glassBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: AppConstants.spacingXxs),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected)
                _checkIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkIcon() =>
      const Icon(Icons.check_circle, color: AppColors.accent, size: 20);
}
