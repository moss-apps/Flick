import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/duration_format.dart';
import 'package:flick/services/player_service.dart';

class SleepTimerBottomSheet extends StatefulWidget {
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
  State<SleepTimerBottomSheet> createState() => _SleepTimerBottomSheetState();
}

class _SleepTimerBottomSheetState extends State<SleepTimerBottomSheet> {
  static const _min = 5.0;
  static const _max = 120.0;
  static const _step = 5.0;
  double _value = 30.0;

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
              if (widget.playerService.isSleepTimerActive)
                TextButton(
                  onPressed: () {
                    widget.playerService.cancelSleepTimer();
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
            valueListenable: widget.playerService.sleepTimerRemainingNotifier,
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
          Row(
            children: [
              const SizedBox(width: 4),
              Text(
                '${_min.round()}m',
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _value,
                  min: _min,
                  max: _max,
                  divisions: ((_max - _min) / _step).round(),
                  activeColor: AppColors.accent,
                  inactiveColor: AppColors.glassBorder,
                  onChanged: (v) {
                    setState(() {
                      _value = (v / _step).round() * _step;
                    });
                  },
                  onChangeEnd: (v) {
                    final minutes = (v / _step).round() * _step;
                    widget.playerService
                        .setSleepTimer(Duration(minutes: minutes.toInt()));
                    Navigator.pop(context);
                  },
                ),
              ),
              Text(
                '${_max.round()}m',
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          Center(
            child: Text(
              '${_value.round()} min',
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
