import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/duration_format.dart';
import 'package:flick/services/player_service.dart';

class SleepTimerBottomSheet extends StatelessWidget {
  final PlayerService playerService;
  const SleepTimerBottomSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SleepTimerBottomSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerOptions = [
      (const Duration(minutes: 15), '15 min'),
      (const Duration(minutes: 30), '30 min'),
      (const Duration(minutes: 45), '45 min'),
      (const Duration(hours: 1), '1 hour'),
      (const Duration(hours: 2), '2 hours'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.moonStar,
                    color: AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sleep Timer',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (playerService.isSleepTimerActive)
                TextButton(
                  onPressed: () {
                    playerService.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel Timer',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<Duration?>(
            valueListenable: playerService.sleepTimerRemainingNotifier,
            builder: (context, remaining, _) {
              if (remaining != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.timer,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Stopping in ${formatDuration(remaining)}',
                          style: const TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 14,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: timerOptions.map((option) {
              return GestureDetector(
                onTap: () {
                  playerService.setSleepTimer(option.$1);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    option.$2,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
