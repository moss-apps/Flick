import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/adaptive_layout.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/features/settings/widgets/orbit_preview.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

enum _OrbitLayoutProfile { portrait, landscape }

class OrbitSettingsScreen extends ConsumerStatefulWidget {
  const OrbitSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  ConsumerState<OrbitSettingsScreen> createState() =>
      _OrbitSettingsScreenState();
}

class _OrbitSettingsScreenState extends ConsumerState<OrbitSettingsScreen> {
  _OrbitLayoutProfile _profile = _OrbitLayoutProfile.portrait;
  bool _profileInitialized = false;

  bool get _landscape => _profile == _OrbitLayoutProfile.landscape;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileInitialized) return;
    _profileInitialized = true;
    _profile = AdaptiveLayout.isWide(MediaQuery.sizeOf(context))
        ? _OrbitLayoutProfile.landscape
        : _OrbitLayoutProfile.portrait;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);

    final radiusRatio = _landscape
        ? prefs.orbitLandscapeRadiusRatio
        : prefs.orbitRadiusRatio;
    final centerYRatio = _landscape
        ? prefs.orbitLandscapeCenterYRatio
        : prefs.orbitCenterYRatio;
    final itemSpacing = _landscape
        ? prefs.orbitLandscapeItemSpacing
        : prefs.orbitItemSpacing;
    final selectedScale = _landscape
        ? prefs.orbitLandscapeSelectedScale
        : prefs.orbitSelectedScale;
    final depth = _landscape ? prefs.orbitLandscapeDepth : prefs.orbitDepth;
    final visibleItems = _landscape
        ? prefs.orbitLandscapeVisibleItems
        : prefs.orbitVisibleItems;
    final cardWidthRatio = _landscape
        ? prefs.orbitLandscapeCardWidthRatio
        : prefs.orbitCardWidthRatio;

    return SettingsScaffold(
      title: l10n.englishForFilipino.customizeOrbital,
      initialSection: widget.initialSection,
      pinnedHeader: OrbitPreview(landscape: _landscape),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(
            l10n.englishForFilipino.orbitLayoutProfile,
            sectionId: 'orbitLayoutProfile',
          ),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.rectangleVertical,
                title: l10n.englishForFilipino.portrait,
                subtitle: l10n.orbitPortraitHint,
                selected: !_landscape,
                onTap: () {
                  setState(() => _profile = _OrbitLayoutProfile.portrait);
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.rectangleHorizontal,
                title: l10n.englishForFilipino.landscape,
                subtitle: l10n.orbitLandscapeHint,
                selected: _landscape,
                onTap: () {
                  setState(() => _profile = _OrbitLayoutProfile.landscape);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsCard(
            children: [
              InfoSetting(
                icon: LucideIcons.panelTop,
                title: l10n.englishForFilipino.orbitHeaderBoundaryTitle,
                subtitle: l10n.englishForFilipino.orbitHeaderBoundaryBody,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(
            l10n.englishForFilipino.geometry,
            sectionId: 'geometry',
          ),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.radius,
                title: l10n.englishForFilipino.curvature,
                subtitle: l10n.curveOfTheOrbitArcHigher,
                value: radiusRatio,
                displayValue: radiusRatio.toStringAsFixed(2),
                min: 0.5,
                max: 2.0,
                divisions: 30,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeRadiusRatio
                    : notifier.setOrbitRadiusRatio,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.moveVertical,
                title: l10n.englishForFilipino.verticalPosition,
                subtitle: l10n.whereTheFocalSongSitsVertically,
                value: centerYRatio,
                displayValue: '${(centerYRatio * 100).round()}%',
                min: 0.30,
                max: 0.60,
                divisions: 30,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeCenterYRatio
                    : notifier.setOrbitCenterYRatio,
              ),
              if (!_landscape) ...[
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
              ],
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.ruler,
                title: l10n.englishForFilipino.itemSpacing,
                subtitle: l10n.distanceBetweenSongsAlongTheArc,
                value: itemSpacing,
                displayValue: itemSpacing.toStringAsFixed(2),
                min: 0.15,
                max: 0.50,
                divisions: 35,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeItemSpacing
                    : notifier.setOrbitItemSpacing,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(
            l10n.englishForFilipino.sizing,
            sectionId: 'sizing',
          ),
          SettingsCard(
            children: [
              if (!_landscape) ...[
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
              ],
              SliderSetting(
                icon: LucideIcons.arrowLeftRight,
                title: l10n.englishForFilipino.cardWidth,
                subtitle: l10n.howWideEachCardSpansAcross,
                value: cardWidthRatio,
                displayValue: '${(cardWidthRatio * 100).round()}%',
                min: 0.5,
                max: 0.85,
                divisions: 35,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeCardWidthRatio
                    : notifier.setOrbitCardWidthRatio,
              ),
              const SettingsDivider(),
              _VisibleItemsRow(
                value: visibleItems,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeVisibleItems
                    : notifier.setOrbitVisibleItems,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(
            l10n.englishForFilipino.depth,
            sectionId: 'depth',
          ),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.maximize,
                title: l10n.englishForFilipino.selectedSize,
                subtitle: l10n.scaleOfTheCenteredFocusedSong,
                value: selectedScale,
                displayValue: selectedScale.toStringAsFixed(2),
                min: 1.0,
                max: 1.8,
                divisions: 16,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeSelectedScale
                    : notifier.setOrbitSelectedScale,
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.chevronsDown,
                title: l10n.englishForFilipino.depth,
                subtitle: l10n.howMuchSideCardsShrinkAway,
                value: depth,
                displayValue: '${(depth * 100).round()}%',
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: _landscape
                    ? notifier.setOrbitLandscapeDepth
                    : notifier.setOrbitDepth,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(
            l10n.englishForFilipino.artResolution,
            tag: l10n.englishForFilipino.orbitSharedVisuals,
            sectionId: 'artResolution',
          ),
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
          SettingsSectionHeader(
            l10n.englishForFilipino.visuals,
            tag: l10n.englishForFilipino.orbitSharedVisuals,
            sectionId: 'visuals',
          ),
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
                subtitle: l10n.restoreThisProfilesOrbitLayout,
                onTap: () {
                  final landscape = _landscape;
                  notifier.resetOrbitLayout(landscape: landscape);
                  ScaffoldMessenger.of(context).showFlickSnackBar(
                    SnackBar(
                      content: Text(
                        landscape
                            ? l10n.landscapeLayoutReset
                            : l10n.portraitLayoutReset,
                      ),
                      duration: const Duration(seconds: 2),
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
