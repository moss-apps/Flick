import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

class VisualizerSettingsScreen extends ConsumerWidget {
  const VisualizerSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final l10n = context.l10n.englishForFilipino;

    return SettingsScaffold(
      title: l10n.englishForFilipino.visualizer,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.visualizer, sectionId: 'visualizer'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.activity,
                title: l10n.englishForFilipino.visualizer,
                subtitle: l10n.showTheAudioVisualizerOffSaves,
                value: prefs.visualizerEnabled,
                onChanged: (value) => notifier.setVisualizerEnabled(value),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.visualizerColors, sectionId: 'visualizerColors'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.image,
                title: l10n.englishForFilipino.albumArt,
                subtitle: l10n.visualizerAlbumColorsDescription,
                selected: prefs.visualizerColorMode == 'album_art',
                onTap: () => notifier.setVisualizerColorMode('album_art'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.rainbow,
                title: l10n.englishForFilipino.visualizerRainbow,
                subtitle: l10n.visualizerRainbowDescription,
                selected: prefs.visualizerColorMode == 'rainbow',
                onTap: () => notifier.setVisualizerColorMode('rainbow'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.contrast,
                title: l10n.englishForFilipino.visualizerMonochrome,
                subtitle: l10n.visualizerMonochromeDescription,
                selected: prefs.visualizerColorMode == 'monochrome',
                onTap: () => notifier.setVisualizerColorMode('monochrome'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.animationStyle, sectionId: 'animationStyle'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.chartBarBig,
                title: l10n.englishForFilipino.bars,
                subtitle: l10n.verticalBarsClassicSpectrumAnalyzer,
                selected: prefs.visualizerAnimationStyle == 'bars',
                onTap: () => notifier.setVisualizerAnimationStyle('bars'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chartBarBig,
                title: l10n.englishForFilipino.visualizerBlocks,
                subtitle: l10n.visualizerBlocksDescription,
                selected: prefs.visualizerAnimationStyle == 'blocks',
                onTap: () => notifier.setVisualizerAnimationStyle('blocks'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.waves,
                title: l10n.englishForFilipino.wave,
                subtitle: l10n.aSmoothContinuousWaveAcrossFrequencies,
                selected: prefs.visualizerAnimationStyle == 'wave',
                onTap: () => notifier.setVisualizerAnimationStyle('wave'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.wand,
                title: l10n.englishForFilipino.curvedWave,
                subtitle: l10n.silkySmoothBZierCurvesFluid,
                selected: prefs.visualizerAnimationStyle == 'curved_wave',
                onTap: () =>
                    notifier.setVisualizerAnimationStyle('curved_wave'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.copy,
                title: l10n.englishForFilipino.mirrored,
                subtitle: l10n.symmetricalBarsMirroredFromTheCenter,
                selected: prefs.visualizerAnimationStyle == 'mirrored',
                onTap: () => notifier.setVisualizerAnimationStyle('mirrored'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.circle,
                title: l10n.englishForFilipino.dots,
                subtitle: l10n.circularDotsRadiusFollowsAmplitude,
                selected: prefs.visualizerAnimationStyle == 'dots',
                onTap: () => notifier.setVisualizerAnimationStyle('dots'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.frequencyFocus, sectionId: 'frequencyFocus'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.equal,
                title: l10n.englishForFilipino.fullSpectrum,
                subtitle: l10n.allFrequenciesEqually,
                selected: prefs.visualizerFrequencyMode == 'full',
                onTap: () => notifier.setVisualizerFrequencyMode('full'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chevronsDown,
                title: l10n.englishForFilipino.bass,
                subtitle: l10n.lowFrequenciesOnly,
                selected: prefs.visualizerFrequencyMode == 'bass',
                onTap: () => notifier.setVisualizerFrequencyMode('bass'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.minus,
                title: l10n.englishForFilipino.mid,
                subtitle: l10n.midFrequenciesOnly,
                selected: prefs.visualizerFrequencyMode == 'mid',
                onTap: () => notifier.setVisualizerFrequencyMode('mid'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chevronsUp,
                title: l10n.englishForFilipino.treble,
                subtitle: l10n.highFrequenciesOnly,
                selected: prefs.visualizerFrequencyMode == 'treble',
                onTap: () => notifier.setVisualizerFrequencyMode('treble'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chevronsDownUp,
                title: l10n.englishForFilipino.bassTreble,
                subtitle: l10n.lowAndHighFrequenciesScoopedMids,
                selected: prefs.visualizerFrequencyMode == 'bass_treble',
                onTap: () => notifier.setVisualizerFrequencyMode('bass_treble'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.movement, sectionId: 'movement'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.zap,
                title: l10n.englishForFilipino.bouncy,
                subtitle: l10n.springPhysicsEnergeticAndReactive,
                selected: prefs.visualizerMovementMode == 'bouncy',
                onTap: () => notifier.setVisualizerMovementMode('bouncy'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.audioLines,
                title: l10n.englishForFilipino.smooth,
                subtitle: l10n.naturalEqualizerFeelResponsiveYetSmooth,
                selected: prefs.visualizerMovementMode == 'smooth',
                onTap: () => notifier.setVisualizerMovementMode('smooth'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.bolt,
                title: l10n.englishForFilipino.snappy,
                subtitle: l10n.fastDirectTrackingImmediateResponse,
                selected: prefs.visualizerMovementMode == 'snappy',
                onTap: () => notifier.setVisualizerMovementMode('snappy'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
