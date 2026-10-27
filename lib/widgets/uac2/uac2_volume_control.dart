import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/services/player_service.dart' show VolumeTier;
import 'package:flick/l10n/l10n.dart';

/// Convert a linear volume (0.0–1.0) to decibels using the same
/// exponential curve as the Rust audio engine (≈ -60 dB to 0 dB).
String _volumeToDb(double volume) {
  if (volume <= 0.0) return '-∞';
  if (volume >= 1.0) return '0.0';
  final db = 60.0 * (volume - 1.0);
  return db.toStringAsFixed(1);
}

class Uac2VolumeControl extends ConsumerStatefulWidget {
  final bool useGradientBackground;
  final List<Color>? gradientColors;

  const Uac2VolumeControl({
    super.key,
    this.useGradientBackground = false,
    this.gradientColors,
  });

  @override
  ConsumerState<Uac2VolumeControl> createState() => _Uac2VolumeControlState();
}

class _Uac2VolumeControlState extends ConsumerState<Uac2VolumeControl> {
  bool _muteUpdateInFlight = false;

  /// Volume level to restore when unmuting via button.
  double _preMuteVolume = 1.0;

  /// Optimistic volume while the user is dragging the slider.
  double? _draggingVolume;

  /// Called on every slider tick during drag — optimistic UI only, no platform call.
  void _onSliderChanged(double volume) {
    setState(() => _draggingVolume = volume);
  }

  /// Called when the user lifts the finger — commits the value to the
  /// platform. PlayerService.setVolume is the single entry point; it routes
  /// to the DAC Feature Unit (hardware), the engine (software/DSP) or drops
  /// the write when volume is unavailable (bit-perfect passthrough).
  Future<void> _onSliderChangeEnd(double volume) async {
    setState(() => _draggingVolume = null);

    final playerService = ref.read(playerServiceProvider);
    final hardwareAuthority = playerService.isHardwareVolumeAuthority;
    if (!hardwareAuthority &&
        volume == 0.0 &&
        playerService.currentVolume > 0.0) {
      _preMuteVolume = playerService.currentVolume.clamp(0.01, 1.0);
    }
    // Hardware volume and mute are independent. Moving the slider must not
    // unmute the DAC (especially after a failed or ignored volume write).
    await playerService.setVolume(volume);
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final playerService = ref.read(playerServiceProvider);
    setState(() => _muteUpdateInFlight = true);
    try {
      if (playerService.isHardwareVolumeAuthority) {
        final muted = ref.read(uac2DeviceStatusProvider)?.muted;
        if (muted != null) {
          // Mute must not overwrite the DAC's independent volume level.
          await ref.read(uac2DeviceStatusProvider.notifier).setMute(!muted);
        }
      } else if (playerService.currentVolume > 0.0) {
        _preMuteVolume = playerService.currentVolume.clamp(0.01, 1.0);
        await playerService.setVolume(0.0);
      } else {
        await playerService.setVolume(_preMuteVolume);
      }
    } finally {
      if (mounted) setState(() => _muteUpdateInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceStatus = ref.watch(uac2DeviceStatusProvider);

    if (deviceStatus == null || deviceStatus.state == Uac2State.idle) {
      return const SizedBox.shrink();
    }

    final tier = ref.watch(volumeTierProvider);
    final isAvailable = tier != VolumeTier.unavailable;
    final playerVolume = ref.watch(playerVolumeProvider);
    final hardwareAuthority = tier == VolumeTier.hardware;
    final effectiveVolume = isAvailable
        ? (_draggingVolume ??
                  (hardwareAuthority
                      ? (deviceStatus.volume ?? playerVolume)
                      : playerVolume))
              .clamp(0.0, 1.0)
        : 1.0;
    final effectiveMuted = hardwareAuthority
        ? deviceStatus.muted == true
        : playerVolume <= 0.0;
    final volumeControlWritable =
        (!hardwareAuthority || deviceStatus.volumeControlWritable) &&
        isAvailable &&
        !_muteUpdateInFlight;
    final muteControlWritable =
        volumeControlWritable &&
        (!hardwareAuthority || deviceStatus.muted != null);
    // The engine's dB curve is not the DAC Feature Unit's attenuation range.
    final showDb = tier == VolumeTier.software;
    final volumeLabel = !isAvailable
        ? l10n.unavailable2
        : showDb
        ? l10n.db15(
            (effectiveVolume * 100).round(),
            _volumeToDb(effectiveVolume),
          )
        : '${(effectiveVolume * 100).round()}%';

    final useGradient = widget.useGradientBackground;
    final gradientColors =
        widget.gradientColors ??
        const [Color(0xFF194B68), Color(0xFF0C1624), Color(0xFF1D2A19)];
    final labelColor = useGradient ? Colors.white : context.adaptiveTextPrimary;
    final subLabelColor = useGradient
        ? Colors.white.withValues(alpha: 0.7)
        : context.adaptiveTextSecondary;
    final tertiaryColor = useGradient
        ? Colors.white.withValues(alpha: 0.5)
        : context.adaptiveTextTertiary;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
                stops: const [0.0, 0.56, 1.0],
              )
            : null,
        color: useGradient ? null : AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: useGradient
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.volume2, color: subLabelColor, size: 20),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hardwareAuthority
                          ? (deviceStatus.isExternalRoute
                                ? l10n.usbRouteVolume
                                : l10n.deviceDacVolume)
                          : l10n.volume,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((deviceStatus.routeLabel?.isNotEmpty ?? false))
                      Text(
                        deviceStatus.routeLabel!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tertiaryColor),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  effectiveMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                  size: 20,
                ),
                onPressed: muteControlWritable ? _toggleMute : null,
                color: effectiveMuted ? Colors.red.shade400 : subLabelColor,
                tooltip: effectiveMuted ? l10n.unmute : l10n.mute,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: [
              Icon(LucideIcons.volume1, color: tertiaryColor, size: 16),
              Expanded(
                child: Slider(
                  value: effectiveVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  label: volumeLabel,
                  semanticFormatterCallback: !isAvailable
                      ? (_) => l10n.unavailable2
                      : null,
                  onChanged: volumeControlWritable ? _onSliderChanged : null,
                  onChangeEnd: volumeControlWritable
                      ? _onSliderChangeEnd
                      : null,
                  activeColor: AppColors.accent,
                  inactiveColor: useGradient
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.textTertiary.withValues(alpha: 0.3),
                ),
              ),
              Icon(LucideIcons.volume2, color: tertiaryColor, size: 16),
              const SizedBox(width: AppConstants.spacingSm),
              SizedBox(
                width: showDb ? 82 : 40,
                child: Text(
                  !isAvailable ? '—' : volumeLabel,
                  semanticsLabel: volumeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: subLabelColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (!isAvailable) ...[
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              l10n.englishForFilipino.volumeIsFixedWhileBitPerfect2,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tertiaryColor),
            ),
          ] else if (hardwareAuthority &&
              !deviceStatus.volumeControlWritable) ...[
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              l10n.hardwareVolumeIsDetectedButWrites,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tertiaryColor),
            ),
          ],
        ],
      ),
    );
  }
}
