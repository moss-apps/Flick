import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/features/settings/screens/uac2_settings_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() =>
      _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends ConsumerState<AudioSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AndroidAudioDeviceService.instance.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Audio',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Audio'),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.usb,
                title: 'USB Audio (UAC2)',
                subtitle: 'Configure USB DAC/AMP devices',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Uac2SettingsScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.slidersHorizontal,
                title: 'Equalizer',
                subtitle: 'Adjust audio frequencies',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EqualizerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Bluetooth Audio'),
          SettingsCard(
            children: [
              ValueListenableBuilder<AndroidPlaybackDeviceInfo>(
                valueListenable:
                    AndroidAudioDeviceService.instance.deviceInfoNotifier,
                builder: (context, deviceInfo, _) {
                  return _BluetoothCodecInfo(deviceInfo: deviceInfo);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const _CrossfadeSection(),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _CrossfadeSection extends ConsumerWidget {
  const _CrossfadeSection();

  static const _curveLabels = <String>[
    'Equal Power',
    'Linear',
    'Square Root',
    'S-Curve',
  ];

  Future<void> _setEnabled(
    WidgetRef ref,
    PlayerService playerService,
    bool value,
  ) async {
    final prefs = ref.read(appPreferencesProvider);
    await ref.read(appPreferencesProvider.notifier).setCrossfadeEnabled(value);
    await playerService.applyCrossfadeSettings(
      enabled: value,
      durationSecs: prefs.crossfadeDurationSecs,
    );
  }

  Future<void> _setDuration(
    WidgetRef ref,
    PlayerService playerService,
    double value,
  ) async {
    final prefs = ref.read(appPreferencesProvider);
    await ref
        .read(appPreferencesProvider.notifier)
        .setCrossfadeDurationSecs(value);
    await playerService.applyCrossfadeSettings(
      enabled: prefs.crossfadeEnabled,
      durationSecs: value,
    );
  }

  Future<void> _setCurve(
    WidgetRef ref,
    PlayerService playerService,
    int index,
  ) async {
    final prefs = ref.read(appPreferencesProvider);
    await ref
        .read(appPreferencesProvider.notifier)
        .setCrossfadeCurveIndex(index);
    await playerService.applyCrossfadeSettings(
      enabled: prefs.crossfadeEnabled,
      durationSecs: prefs.crossfadeDurationSecs,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final playerService = ref.read(playerServiceProvider);

    return ListenableBuilder(
      listenable: playerService.bitPerfectProcessingLockedNotifier,
      builder: (context, _) {
        final locked = playerService.bitPerfectProcessingLockedNotifier.value;
        final is432Hz = Uac2PreferencesService.is432HzTuningEnabledSync;
        final effectiveEnabled = !locked && prefs.crossfadeEnabled;
        final controlsEnabled = !locked;

        final disabledHint = is432Hz
            ? 'Turn off 432 Hz tuning to use crossfade'
            : 'Not available in bit-perfect mode';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader('Crossfade', tag: 'Experimental'),
            SettingsCard(
              children: [
                ToggleSetting(
                  icon: LucideIcons.shuffle,
                  title: 'Crossfade',
                  subtitle: locked
                      ? disabledHint
                      : 'Overlap the end of a track with the next',
                  value: effectiveEnabled,
                  onChanged: locked
                      ? (_) {}
                      : (v) => _setEnabled(ref, playerService, v),
                ),
                const SettingsDivider(),
                SliderSetting(
                  icon: LucideIcons.timer,
                  title: 'Duration',
                  subtitle: 'Length of the overlap',
                  value: prefs.crossfadeDurationSecs.clamp(0.5, 12.0),
                  displayValue:
                      '${prefs.crossfadeDurationSecs.toStringAsFixed(1)} s',
                  min: 0.5,
                  max: 12.0,
                  divisions: 23,
                  onChanged: controlsEnabled
                      ? (v) => _setDuration(ref, playerService, v)
                      : null,
                ),
                const SettingsDivider(),
                _CrossfadeCurvePicker(
                  selectedIndex: prefs.crossfadeCurveIndex,
                  enabled: controlsEnabled,
                  onSelect: controlsEnabled
                      ? (i) => _setCurve(ref, playerService, i)
                      : null,
                ),
                const SettingsDivider(),
                _CrossfadePreview(
                  curveIndex: prefs.crossfadeCurveIndex,
                  curveName: _curveLabels[prefs.crossfadeCurveIndex],
                  durationSecs: prefs.crossfadeDurationSecs,
                  enabled: effectiveEnabled,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CrossfadeCurvePicker extends StatelessWidget {
  const _CrossfadeCurvePicker({
    required this.selectedIndex,
    required this.enabled,
    this.onSelect,
  });

  final int selectedIndex;
  final bool enabled;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppConstants.spacingXs),
            child: Text(
              'Curve',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: enabled
                    ? context.adaptiveTextPrimary
                    : context.adaptiveTextTertiary,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            children: [
              for (
                var i = 0;
                i < _CrossfadeSection._curveLabels.length;
                i++
              ) ...[
                if (i > 0) const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: _CurveChip(
                    label: _CrossfadeSection._curveLabels[i],
                    selected: i == selectedIndex,
                    enabled: enabled,
                    onTap: enabled ? () => onSelect?.call(i) : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CurveChip extends StatelessWidget {
  const _CurveChip({
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animationFast,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.textPrimary.withValues(alpha: 0.12)
                : AppColors.glassBackgroundStrong,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            border: Border.all(
              color: selected
                  ? AppColors.textPrimary.withValues(alpha: 0.6)
                  : AppColors.glassBorder,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? context.adaptiveTextPrimary
                  : context.adaptiveTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossfadePreview extends StatelessWidget {
  const _CrossfadePreview({
    required this.curveIndex,
    required this.curveName,
    required this.durationSecs,
    required this.enabled,
  });

  final int curveIndex;
  final String curveName;
  final double durationSecs;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: enabled
                      ? context.adaptiveTextPrimary
                      : context.adaptiveTextTertiary,
                ),
              ),
              const Spacer(),
              Text(
                curveName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.adaptiveTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            child: Container(
              height: 100,
              width: double.infinity,
              color: AppColors.glassBackgroundStrong,
              child: CustomPaint(
                painter: _CrossfadeCurvePainter(
                  curveIndex: curveIndex,
                  trackAColor: AppColors.textPrimary.withValues(
                    alpha: enabled ? 0.18 : 0.07,
                  ),
                  trackBColor: AppColors.textSecondary.withValues(
                    alpha: enabled ? 0.30 : 0.12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
              Text(
                '${durationSecs.toStringAsFixed(1)} s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrossfadeCurvePainter extends CustomPainter {
  _CrossfadeCurvePainter({
    required this.curveIndex,
    required this.trackAColor,
    required this.trackBColor,
  });

  final int curveIndex;
  final Color trackAColor;
  final Color trackBColor;

  (double, double) _gains(double t) {
    switch (curveIndex) {
      case 0: // Equal power
        final angle = t * pi / 2;
        return (cos(angle), sin(angle));
      case 1: // Linear
        return (1.0 - t, t);
      case 2: // Square root
        return (sqrt(1.0 - t), sqrt(t));
      case 3: // S-Curve (smoothstep)
        final s = t * t * (3.0 - 2.0 * t);
        return (1.0 - s, s);
      default:
        return (1.0 - t, t);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    const steps = 60;

    final pathA = Path()..moveTo(0, midY);
    final pathB = Path()..moveTo(0, midY);

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final (gainA, gainB) = _gains(t);
      final x = t * size.width;
      pathA.lineTo(x, midY - gainA * midY);
      pathB.lineTo(x, midY + gainB * midY);
    }

    pathA
      ..lineTo(size.width, midY)
      ..close();
    pathB
      ..lineTo(size.width, midY)
      ..close();

    canvas
      ..drawPath(pathA, Paint()..color = trackAColor)
      ..drawPath(pathB, Paint()..color = trackBColor);

    // Centre reference line.
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossfadeCurvePainter oldDelegate) {
    return oldDelegate.curveIndex != curveIndex ||
        oldDelegate.trackAColor != trackAColor ||
        oldDelegate.trackBColor != trackBColor;
  }
}

class _BluetoothCodecInfo extends StatelessWidget {
  const _BluetoothCodecInfo({required this.deviceInfo});

  final AndroidPlaybackDeviceInfo deviceInfo;

  @override
  Widget build(BuildContext context) {
    final currentRouteLabel = deviceInfo.isBluetoothRoute
        ? 'Current route: ${deviceInfo.routeSummary}. Android is handling codec negotiation right now.'
        : 'When you play over Bluetooth, Android negotiates the codec with your headphones or speaker.';

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.glassBackgroundStrong,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(
                  LucideIcons.bluetooth,
                  color: context.adaptiveTextSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth codec info',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentRouteLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.adaptiveTextTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: const [
              _CodecChip('SBC'),
              _CodecChip('AAC'),
              _CodecChip('aptX'),
              _CodecChip('aptX HD'),
              _CodecChip('aptX Adaptive'),
              _CodecChip('LDAC'),
              _CodecChip('LC3'),
              _CodecChip('LHDC'),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            'Flick does not force Bluetooth codecs itself. The active codec depends on Android, your phone, your headset, signal quality, and any Bluetooth developer settings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'If you want to prefer AAC, SBC, aptX, LDAC, or another supported codec, change it in Android Bluetooth settings or Developer Options when your device allows it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodecChip extends StatelessWidget {
  const _CodecChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusRound),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.adaptiveTextSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
