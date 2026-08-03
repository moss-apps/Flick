import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/player_service.dart';

class VolumeBottomSheet extends StatelessWidget {
  final PlayerService playerService;
  const VolumeBottomSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => VolumeBottomSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialVolume = playerService.currentVolume;
    final isAvailable = playerService.isVolumeAvailable;
    double currentVolume = initialVolume;
    return StatefulBuilder(
      builder: (context, setSheetState) {
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
                  Icon(
                    currentVolume > 0
                        ? LucideIcons.volume2
                        : LucideIcons.volumeX,
                    color: AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Volume',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(currentVolume * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    LucideIcons.volume1,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  Expanded(
                    child: Slider(
                      value: currentVolume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      label: '${(currentVolume * 100).round()}%',
                      onChanged: isAvailable
                          ? (value) {
                              setSheetState(() {
                                currentVolume = value;
                              });
                            }
                          : null,
                      onChangeEnd: isAvailable
                          ? (value) async {
                              await playerService.setVolume(value);
                            }
                          : null,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.textTertiary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  Icon(
                    LucideIcons.volume2,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
              if (!isAvailable) ...[
                const SizedBox(height: 8),
                const Text(
                  'Volume is fixed while bit-perfect passthrough is active and this DAC has no hardware volume control.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
