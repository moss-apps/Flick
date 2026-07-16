import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class OrbitSettingsScreen extends ConsumerWidget {
  const OrbitSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    return SettingsScaffold(
      title: 'Customize Orbital',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Geometry'),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.radius,
                title: 'Curvature',
                subtitle: 'Curve of the orbit arc — higher is gentler',
                value: prefs.orbitRadiusRatio,
                displayValue: prefs.orbitRadiusRatio.toStringAsFixed(2),
                min: 0.5,
                max: 2.0,
                divisions: 30,
                onChanged: notifier.setOrbitRadiusRatio,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.moveVertical,
                title: 'Vertical Position',
                subtitle: 'Where the focal song sits vertically',
                value: prefs.orbitCenterYRatio,
                displayValue: '${(prefs.orbitCenterYRatio * 100).round()}%',
                min: 0.30,
                max: 0.60,
                divisions: 30,
                onChanged: notifier.setOrbitCenterYRatio,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.moveHorizontal,
                title: 'Horizontal Reach',
                subtitle: 'How far the arc opens from the left edge',
                value: prefs.orbitCenterOffsetRatio,
                displayValue: prefs.orbitCenterOffsetRatio.toStringAsFixed(2),
                min: -1.0,
                max: 0.0,
                divisions: 20,
                onChanged: notifier.setOrbitCenterOffsetRatio,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.ruler,
                title: 'Item Spacing',
                subtitle: 'Distance between songs along the arc',
                value: prefs.orbitItemSpacing,
                displayValue: prefs.orbitItemSpacing.toStringAsFixed(2),
                min: 0.15,
                max: 0.50,
                divisions: 35,
                onChanged: notifier.setOrbitItemSpacing,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Sizing'),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.expand,
                title: 'Card Size',
                subtitle: 'Base album-art size for each song card',
                value: prefs.orbitCardArtSize,
                displayValue: '${prefs.orbitCardArtSize.round()}px',
                min: 48,
                max: 120,
                divisions: 72,
                onChanged: notifier.setOrbitCardArtSize,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.arrowLeftRight,
                title: 'Card Width',
                subtitle: 'How wide each card spans across the screen',
                value: prefs.orbitCardWidthRatio,
                displayValue: '${(prefs.orbitCardWidthRatio * 100).round()}%',
                min: 0.5,
                max: 0.85,
                divisions: 35,
                onChanged: notifier.setOrbitCardWidthRatio,
              ),
              const SettingsDivider(),
              _VisibleItemsRow(
                value: prefs.orbitVisibleItems,
                onChanged: notifier.setOrbitVisibleItems,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Depth'),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.maximize,
                title: 'Selected Size',
                subtitle: 'Scale of the centered, focused song card',
                value: prefs.orbitSelectedScale,
                displayValue: prefs.orbitSelectedScale.toStringAsFixed(2),
                min: 1.0,
                max: 1.8,
                divisions: 16,
                onChanged: notifier.setOrbitSelectedScale,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.chevronsDown,
                title: 'Depth',
                subtitle: 'How much side cards shrink away from center',
                value: prefs.orbitDepth,
                displayValue: '${(prefs.orbitDepth * 100).round()}%',
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: notifier.setOrbitDepth,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Art Resolution'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.imageMinus,
                title: 'Low',
                subtitle: 'Pixelated — lightest on memory',
                selected: prefs.orbitArtResolutionMultiplier == 1.0,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(1.0),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.image,
                title: 'Medium',
                subtitle: 'Soft detail, balanced',
                selected: prefs.orbitArtResolutionMultiplier == 1.5,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(1.5),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.aperture,
                title: 'High',
                subtitle: 'Sharp (recommended)',
                selected: prefs.orbitArtResolutionMultiplier == 2.0,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(2.0),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.sparkles,
                title: 'Ultra',
                subtitle: 'Crispest — heavier during fast scrolling',
                selected: prefs.orbitArtResolutionMultiplier == 3.0,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(3.0),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Visuals'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.spline,
                title: 'Show Orbit Path',
                subtitle: 'Draw the curved arc behind the songs',
                value: prefs.orbitShowPath,
                onChanged: notifier.setOrbitShowPath,
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.circle,
                title: 'Show Glow',
                subtitle: 'Soft highlight behind the selected song',
                value: prefs.orbitShowGlow,
                onChanged: notifier.setOrbitShowGlow,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.refreshCw,
                title: 'Reset to Defaults',
                subtitle: 'Restore the original orbital layout',
                onTap: () {
                  notifier.resetOrbitSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Orbital settings reset'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
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

class _VisibleItemsRow extends StatelessWidget {
  const _VisibleItemsRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [3, 5, 7, 9];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingMd,
        AppConstants.spacingSm,
      ),
      child: Wrap(
        spacing: AppConstants.spacingSm,
        children: _options.map((count) {
          final selected = count == value;
          return ChoiceChip(
            label: Text('$count'),
            selected: selected,
            onSelected: selected ? null : (_) => onChanged(count),
          );
        }).toList(),
      ),
    );
  }
}
