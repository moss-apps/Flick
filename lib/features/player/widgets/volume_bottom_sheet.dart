import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/l10n/l10n.dart';

class VolumeBottomSheet extends StatelessWidget {
  final PlayerService playerService;
  const VolumeBottomSheet({super.key, required this.playerService});

  static Future<void> show(BuildContext context, PlayerService playerService) {
    return showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => VolumeBottomSheet(playerService: playerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        playerService.volumeTierNotifier,
        playerService.currentVolumeNotifier,
      ]),
      builder: (context, _) => _buildVolumeSheet(
        context,
        playerService.volumeTierNotifier.value,
      ),
    );
  }

  Widget _buildVolumeSheet(BuildContext context, VolumeTier tier) {
    final maxVolume = playerService.maxVolume;
    final initialVolume = playerService.currentVolume.clamp(0.0, maxVolume);
    final isAvailable = tier != VolumeTier.unavailable;
    double currentVolume = initialVolume;
    return StatefulBuilder(
      builder: (context, setSheetState) {
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
                  Icon(
                    currentVolume > 0
                        ? LucideIcons.volume2
                        : LucideIcons.volumeX,
                    color: AppColors.accent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.volume,
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isAvailable ? '${(currentVolume * 100).round()}%' : '—',
                    semanticsLabel: isAvailable ? null : l10n.unavailable2,
                    style: const TextStyle(
                      fontFamily: 'GoogleSansFlex',
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
                      value: isAvailable ? currentVolume : 1.0,
                      min: 0.0,
                      max: maxVolume,
                      divisions: (maxVolume * 100).round(),
                      label: isAvailable
                          ? '${(currentVolume * 100).round()}%'
                          : l10n.unavailable2,
                      semanticFormatterCallback: !isAvailable
                          ? (_) => l10n.unavailable2
                          : null,
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
                              if (context.mounted) {
                                setSheetState(() {
                                  currentVolume = playerService.currentVolume
                                      .clamp(0.0, maxVolume);
                                });
                              }
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
                Text(
                  l10n.volumeIsFixedWhileBitPerfect,
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
