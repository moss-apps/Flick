import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/player_service.dart';

class SpeedBottomSheet extends StatelessWidget {
  final PlayerService playerService;
  const SpeedBottomSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SpeedBottomSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    const min = 0.5;
    const max = 2.0;
    const step = 0.25;
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
            children: [
              const Icon(
                LucideIcons.gauge,
                color: AppColors.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Playback Speed',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<double>(
            valueListenable: playerService.playbackSpeedNotifier,
            builder: (context, currentSpeed, _) {
              return Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Text(
                        '${min}x',
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: currentSpeed,
                          min: min,
                          max: max,
                          divisions: ((max - min) / step).round(),
                          activeColor: AppColors.accent,
                          inactiveColor: AppColors.glassBorder,
                          onChanged: playerService.setPlaybackSpeed,
                        ),
                      ),
                      Text(
                        '${max}x',
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  Text(
                    '${currentSpeed}x',
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
