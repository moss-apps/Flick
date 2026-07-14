import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
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
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
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
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: speeds.map((speed) {
                  final isSelected = speed == currentSpeed;
                  return GestureDetector(
                    onTap: () {
                      playerService.setPlaybackSpeed(speed);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: AppConstants.animationFast,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.glassBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
