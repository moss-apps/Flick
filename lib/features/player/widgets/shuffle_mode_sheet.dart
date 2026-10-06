import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/shuffle_mode.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

import 'package:flick/l10n/l10n.dart';
class ShuffleModeSheet extends StatelessWidget {
  final PlayerService playerService;

  const ShuffleModeSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return GlassBottomSheet.show(
      context: context,
      title: l10n.shuffleMode,
      content: ShuffleModeSheet(playerService: playerService),
    );
  }

  IconData _iconFor(ShuffleMode mode) => switch (mode) {
    ShuffleMode.off => LucideIcons.shuffle,
    ShuffleMode.songs => LucideIcons.shuffle,
    ShuffleMode.songsAndCategories => LucideIcons.shuffle,
    ShuffleMode.categories => LucideIcons.layers,
    ShuffleMode.random => LucideIcons.dices,
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShuffleMode>(
      valueListenable: playerService.shuffleModeNotifier,
      builder: (context, current, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: ShuffleMode.values.map((mode) {
            final selected = mode == current;
            return _ModeTile(
              icon: _iconFor(mode),
              label: mode.label,
              description: mode.description,
              selected: selected,
              onTap: () {
                playerService.setShuffleMode(mode);
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
