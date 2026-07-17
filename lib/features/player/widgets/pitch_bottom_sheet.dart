import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/player_service.dart';

class PitchBottomSheet extends StatelessWidget {
  final PlayerService playerService;
  const PitchBottomSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PitchBottomSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(LucideIcons.music, color: AppColors.accent, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Pitch',
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
            valueListenable: playerService.pitchSemitonesNotifier,
            builder: (context, semitones, _) {
              return Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    '−12',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: semitones,
                      min: -12,
                      max: 12,
                      divisions: 24,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.glassBorder,
                      onChanged: (v) {
                        playerService.setPitchSemitones(v.roundToDouble());
                      },
                    ),
                  ),
                  Text(
                    '+12',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
          Center(
            child: ValueListenableBuilder<double>(
              valueListenable: playerService.pitchSemitonesNotifier,
              builder: (context, semitones, _) {
                final v = semitones.round();
                return Text(
                  v == 0 ? 'Off' : '${v > 0 ? "+" : ""}$v semitones',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: v == 0 ? AppColors.textSecondary : AppColors.accent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
