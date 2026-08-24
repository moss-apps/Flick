import 'dart:math' show cos, pi, sin, sqrt;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/features/settings/screens/uac2_settings_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/services/android_audio_device_service.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/replaygain_service.dart';
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
          const _ExtendedVolumeSection(),
          const SizedBox(height: AppConstants.spacingLg),
          const _ReplayGainSection(),
          const SizedBox(height: AppConstants.spacingLg),
          const _CrossfadeSection(),
          const SizedBox(height: AppConstants.spacingLg),
          const _CrossfeedSection(),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _ExtendedVolumeSection extends ConsumerWidget {
  const _ExtendedVolumeSection();

  Future<void> _setEnabled(
    WidgetRef ref,
    PlayerService playerService,
    bool value,
  ) async {
    await ref
        .read(appPreferencesProvider.notifier)
        .setExtendedVolumeEnabled(value);
    await playerService.setExtendedVolumeEnabled(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final playerService = ref.read(playerServiceProvider);

    return ListenableBuilder(
      listenable: playerService.extendedVolumeEnabledNotifier,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader('Volume'),
            SettingsCard(
              children: [
                ToggleSetting(
                  icon: LucideIcons.volume2,
                  title: 'Extended Volume',
                  subtitle: 'Boost beyond 100% (up to 200%)',
                  value: prefs.extendedVolumeEnabled,
                  onChanged: (v) => _setEnabled(ref, playerService, v),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// ReplayGain (volume normalization): mode, pre-amp and clipping prevention.
/// Backed by the per-track REPLAYGAIN_* tags read by the library scanner and
/// written by the ReplayGain scan in Library Settings. The Rust engine applies
/// the gain per source; just_audio folds it into the ExoPlayer volume +
/// LoudnessEnhancer boost.
class _ReplayGainSection extends ConsumerWidget {
  const _ReplayGainSection();

  Future<void> _setMode(
    WidgetRef ref,
    PlayerService playerService,
    String mode,
  ) async {
    await ref.read(appPreferencesProvider.notifier).setReplayGainMode(mode);
    await playerService.applyReplayGainFromSettings();
  }

  Future<void> _setPreamp(
    WidgetRef ref,
    PlayerService playerService,
    double value,
  ) async {
    await ref.read(appPreferencesProvider.notifier).setReplayGainPreampDb(value);
    await playerService.applyReplayGainFromSettings();
  }

  Future<void> _setPreventClipping(
    WidgetRef ref,
    PlayerService playerService,
    bool value,
  ) async {
    await ref
        .read(appPreferencesProvider.notifier)
        .setReplayGainPreventClipping(value);
    await playerService.applyReplayGainFromSettings();
  }

  String _preampLabel(double db) {
    if (db == 0.0) return '0 dB';
    return '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final playerService = ref.read(playerServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('ReplayGain'),
        SettingsCard(
          children: [
            SelectionSetting(
              icon: LucideIcons.volumeX,
              title: 'Off',
              subtitle: 'Play at the recorded level',
              selected: prefs.replayGainMode == 'off',
              onTap: () => _setMode(ref, playerService, 'off'),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.music,
              title: 'Track',
              subtitle: 'Normalize each track to match loudness',
              selected: prefs.replayGainMode == 'track',
              onTap: () => _setMode(ref, playerService, 'track'),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.disc3,
              title: 'Album',
              subtitle: 'Keep relative levels inside each album',
              selected: prefs.replayGainMode == 'album',
              onTap: () => _setMode(ref, playerService, 'album'),
            ),
            const SettingsDivider(),
            SliderSetting(
              icon: LucideIcons.gauge,
              title: 'Pre-amp',
              subtitle: 'Fine-tune the overall gain',
              value: prefs.replayGainPreampDb.clamp(
                replayGainPreampMinDb,
                replayGainPreampMaxDb,
              ),
              displayValue: _preampLabel(prefs.replayGainPreampDb),
              min: replayGainPreampMinDb,
              max: replayGainPreampMaxDb,
              divisions: 36,
              onChanged: (v) => _setPreamp(ref, playerService, v),
            ),
            const SettingsDivider(),
            ToggleSetting(
              icon: LucideIcons.shield,
              title: 'Prevent Clipping',
              subtitle:
                  'Limit positive gain so the level never exceeds full scale',
              value: prefs.replayGainPreventClipping,
              onChanged: (v) => _setPreventClipping(ref, playerService, v),
            ),
          ],
        ),
      ],
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
            ListenableBuilder(
              listenable: playerService.initializedPlaybackModeNotifier,
              builder: (context, _) {
                if (playerService.currentEngineType ==
                    AudioEngineType.normalAndroid) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                    vertical: AppConstants.spacingXs,
                  ),
                  child: Text(
                    'Crossfade is most reliable on the Standard engine. '
                    'On the high-quality (Rust) engine it can be unstable — '
                    'switch to Standard for consistent crossfades.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.adaptiveTextTertiary,
                        ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _CrossfeedSection extends ConsumerWidget {
  const _CrossfeedSection();

  static const _levelLabels = <String>[
    'Off',
    'Default',
    'Crossfeed',
    'Crossfeed easy',
  ];

  Future<void> _setLevel(
    WidgetRef ref,
    PlayerService playerService,
    int value,
  ) async {
    await ref.read(appPreferencesProvider.notifier).setCrossfeedLevel(value);
    await playerService.applyCrossfeedSettings();
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
        final controlsEnabled = !locked;

        final disabledHint = is432Hz
            ? 'Turn off 432 Hz tuning to use crossfeed'
            : 'Not available in bit-perfect mode';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionHeader(
              'Crossfeed (BS2B)',
              tag: 'Experimental',
            ),
            SettingsCard(
              children: [
                _CrossfeedLevelPicker(
                  selectedIndex: prefs.crossfeedLevel.clamp(0, 3),
                  enabled: controlsEnabled,
                  onSelect: controlsEnabled
                      ? (i) => _setLevel(ref, playerService, i)
                      : null,
                ),
              ],
            ),
            ListenableBuilder(
              listenable: playerService.initializedPlaybackModeNotifier,
              builder: (context, _) {
                if (playerService.currentEngineType ==
                    AudioEngineType.normalAndroid) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingXs,
                    ),
                    child: Text(
                      'Crossfeed runs on the high-quality (Rust) engine only. '
                      'The Standard engine plays without it.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextTertiary,
                          ),
                    ),
                  );
                }
                if (locked) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingXs,
                    ),
                    child: Text(
                      disabledHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextTertiary,
                          ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }
}

class _CrossfeedLevelPicker extends StatelessWidget {
  const _CrossfeedLevelPicker({
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
              'Level',
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
                i < _CrossfeedSection._levelLabels.length;
                i++
              ) ...[
                if (i > 0) const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: _CurveChip(
                    label: _CrossfeedSection._levelLabels[i],
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

