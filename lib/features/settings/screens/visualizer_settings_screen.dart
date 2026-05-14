import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class VisualizerSettingsScreen extends ConsumerWidget {
  const VisualizerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    return SettingsScaffold(
      title: 'Visualizer',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Animation Style'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.chartBarBig,
                title: 'Bars',
                subtitle: 'Vertical bars — classic spectrum analyzer',
                selected: prefs.visualizerAnimationStyle == 'bars',
                onTap: () => notifier.setVisualizerAnimationStyle('bars'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.waves,
                title: 'Wave',
                subtitle: 'A smooth continuous wave across frequencies',
                selected: prefs.visualizerAnimationStyle == 'wave',
                onTap: () => notifier.setVisualizerAnimationStyle('wave'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.copy,
                title: 'Mirrored',
                subtitle: 'Symmetrical bars mirrored from the center',
                selected: prefs.visualizerAnimationStyle == 'mirrored',
                onTap: () => notifier.setVisualizerAnimationStyle('mirrored'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.circle,
                title: 'Dots',
                subtitle: 'Circular dots — radius follows amplitude',
                selected: prefs.visualizerAnimationStyle == 'dots',
                onTap: () => notifier.setVisualizerAnimationStyle('dots'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Frequency Focus'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.equal,
                title: 'Full Spectrum',
                subtitle: 'All frequencies equally',
                selected: prefs.visualizerFrequencyMode == 'full',
                onTap: () => notifier.setVisualizerFrequencyMode('full'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chevronsDown,
                title: 'Bass',
                subtitle: 'Low frequencies only',
                selected: prefs.visualizerFrequencyMode == 'bass',
                onTap: () => notifier.setVisualizerFrequencyMode('bass'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.minus,
                title: 'Mid',
                subtitle: 'Mid frequencies only',
                selected: prefs.visualizerFrequencyMode == 'mid',
                onTap: () => notifier.setVisualizerFrequencyMode('mid'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chevronsUp,
                title: 'Treble',
                subtitle: 'High frequencies only',
                selected: prefs.visualizerFrequencyMode == 'treble',
                onTap: () => notifier.setVisualizerFrequencyMode('treble'),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.chevronsDownUp,
                title: 'Bass + Treble',
                subtitle: 'Low and high frequencies, scooped mids',
                selected: prefs.visualizerFrequencyMode == 'bass_treble',
                onTap: () => notifier.setVisualizerFrequencyMode('bass_treble'),
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
