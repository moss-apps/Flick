import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

class LoopModeSheet extends StatelessWidget {
  final PlayerService playerService;

  const LoopModeSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return GlassBottomSheet.show(
      context: context,
      title: 'Repeat Mode',
      content: LoopModeSheet(playerService: playerService),
    );
  }

  static IconData iconFor(LoopMode mode) => switch (mode) {
    LoopMode.off => LucideIcons.repeat,
    LoopMode.one => LucideIcons.repeat1,
    LoopMode.all => LucideIcons.repeat,
    LoopMode.advanceList => LucideIcons.listEnd,
    LoopMode.stopAfterCurrent => LucideIcons.circleStop,
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LoopMode>(
      valueListenable: playerService.loopModeNotifier,
      builder: (context, current, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: LoopMode.values.map((mode) {
            final selected = mode == current;
            return _ModeTile(
              icon: iconFor(mode),
              label: mode.label,
              description: mode.description,
              selected: selected,
              onTap: () {
                playerService.setLoopMode(mode);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          decoration: selected
              ? BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  LucideIcons.check,
                  size: 18,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
