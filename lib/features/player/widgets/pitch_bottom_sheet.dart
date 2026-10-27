import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/l10n/english_l10n.dart';

class PitchBottomSheet extends StatelessWidget {
  final PlayerService playerService;
  const PitchBottomSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PitchBottomSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppBottomSheetSurface.decoration,
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.music, color: AppColors.accent, size: 24),
              const SizedBox(width: 12),
              Text(
                l10n.pitch,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
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
                      fontFamily: 'GoogleSansFlex',
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
                      fontFamily: 'GoogleSansFlex',
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
                final sign = v > 0 ? '+' : '';
                return Text(
                  v == 0 ? l10n.off : '$sign${l10n.pitchSemitones(v)}',
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
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
