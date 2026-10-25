import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

class OrbitSettingsScreen extends ConsumerWidget {
  const OrbitSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    return SettingsScaffold(
      title: l10n.englishForFilipino.customizeOrbital,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.geometry),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.radius,
                title: l10n.englishForFilipino.curvature,
                subtitle: l10n.curveOfTheOrbitArcHigher,
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
                title: l10n.englishForFilipino.verticalPosition,
                subtitle: l10n.whereTheFocalSongSitsVertically,
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
                title: l10n.englishForFilipino.horizontalReach,
                subtitle: l10n.howFarTheArcOpensFrom,
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
                title: l10n.englishForFilipino.itemSpacing,
                subtitle: l10n.distanceBetweenSongsAlongTheArc,
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
          SettingsSectionHeader(l10n.englishForFilipino.sizing),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.expand,
                title: l10n.englishForFilipino.cardSize,
                subtitle: l10n.baseAlbumArtSizeForEach,
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
                title: l10n.englishForFilipino.cardWidth,
                subtitle: l10n.howWideEachCardSpansAcross,
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
          SettingsSectionHeader(l10n.englishForFilipino.depth),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.maximize,
                title: l10n.englishForFilipino.selectedSize,
                subtitle: l10n.scaleOfTheCenteredFocusedSong,
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
                title: l10n.englishForFilipino.depth,
                subtitle: l10n.howMuchSideCardsShrinkAway,
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
          SettingsSectionHeader(l10n.englishForFilipino.artResolution),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.imageMinus,
                title: l10n.englishForFilipino.low,
                subtitle: l10n.pixelatedLightestOnMemory,
                selected: prefs.orbitArtResolutionMultiplier == 1.0,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(1.0),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.image,
                title: l10n.englishForFilipino.medium,
                subtitle: l10n.softDetailBalanced,
                selected: prefs.orbitArtResolutionMultiplier == 1.5,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(1.5),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.aperture,
                title: l10n.englishForFilipino.high,
                subtitle: l10n.sharpRecommended,
                selected: prefs.orbitArtResolutionMultiplier == 2.0,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(2.0),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.sparkles,
                title: l10n.englishForFilipino.ultra,
                subtitle: l10n.crispestHeavierDuringFastScrolling,
                selected: prefs.orbitArtResolutionMultiplier == 3.0,
                onTap: () => notifier.setOrbitArtResolutionMultiplier(3.0),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.visuals),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.spline,
                title: l10n.englishForFilipino.showOrbitPath,
                subtitle: l10n.drawTheCurvedArcBehindThe,
                value: prefs.orbitShowPath,
                onChanged: notifier.setOrbitShowPath,
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.circle,
                title: l10n.englishForFilipino.showGlow,
                subtitle: l10n.softHighlightBehindTheSelectedSong,
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
                title: l10n.englishForFilipino.resetToDefaults,
                subtitle: l10n.restoreTheOriginalOrbitalLayout,
                onTap: () {
                  notifier.resetOrbitSettings();
                  ScaffoldMessenger.of(context).showFlickSnackBar(
                    SnackBar(
                      content: Text(l10n.orbitalSettingsReset),
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
