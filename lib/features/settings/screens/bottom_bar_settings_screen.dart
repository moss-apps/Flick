import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/widgets/navigation/flick_nav_bar.dart';

class BottomBarSettingsScreen extends ConsumerWidget {
  const BottomBarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(navBarConfigProvider);
    final appPreferences = ref.watch(appPreferencesProvider);
    final enabled = config.enabledButtons;
    final enabledCount = enabled.length;
    final disabled = NavBarButton.values.where((b) => !enabled.contains(b)).toList();

    return SettingsScaffold(
      title: 'Bottom Bar',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Mini Player'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.audioLines,
                title: 'Visualizer',
                subtitle: 'Swipe to show or hide the visualizer',
                selected: appPreferences.miniPlayerSwipeAction == 'visualizer',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setMiniPlayerSwipeAction('visualizer');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.skipForward,
                title: 'Switch Songs',
                subtitle: 'Swipe left/right to skip tracks',
                selected: appPreferences.miniPlayerSwipeAction == 'switchSongs',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setMiniPlayerSwipeAction('switchSongs');
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Auto Collapse'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.timer,
                title: 'Auto Collapse',
                subtitle:
                    'Hide navigation buttons after being idle',
                value: appPreferences.bottomBarAutoCollapseEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setBottomBarAutoCollapseEnabled(value);
                },
              ),
              if (appPreferences.bottomBarAutoCollapseEnabled) ...[
                const SettingsDivider(),
                SliderSetting(
                  icon: LucideIcons.clock,
                  title: 'Collapse After',
                  subtitle:
                      'Seconds of inactivity before collapsing',
                  value: appPreferences.bottomBarAutoCollapseSeconds.toDouble(),
                  displayValue:
                      '${appPreferences.bottomBarAutoCollapseSeconds}s',
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (value) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setBottomBarAutoCollapseSeconds(value.round());
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Buttons'),
          Container(
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.glassBorder, width: 1),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  child: child,
                );
              },
              itemCount: enabled.length,
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(navBarConfigProvider.notifier)
                    .reorderButtons(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final button = enabled[index];
                final isOnly = enabledCount == 1;
                return Column(
                  key: ValueKey(button),
                  children: [
                    if (index > 0) const SettingsDivider(),
                    Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              right: 4,
                              top: 8,
                              bottom: 8,
                            ),
                            child: Icon(
                              LucideIcons.gripVertical,
                              color: AppColors.textSecondary.withValues(alpha: 0.4),
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ToggleSetting(
                            icon: button.icon,
                            title: button.label,
                            subtitle: 'Show the ${button.label} tab in the bottom bar',
                            value: true,
                            onChanged: isOnly
                                ? (_) {}
                                : (_) {
                                    ref
                                        .read(navBarConfigProvider.notifier)
                                        .toggleButton(button);
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          if (disabled.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingLg),
            const SettingsSectionHeader('Disabled'),
            SettingsCard(
              children: [
                for (int i = 0; i < disabled.length; i++) ...[
                  if (i > 0) const SettingsDivider(),
                  ToggleSetting(
                    icon: disabled[i].icon,
                    title: disabled[i].label,
                    subtitle:
                    'Enable to show the ${disabled[i].label} tab in the bottom bar',
                    value: false,
                    onChanged: (_) {
                      ref
                          .read(navBarConfigProvider.notifier)
                          .toggleButton(disabled[i]);
                    },
                  ),
                ],
              ],
            ),
          ],
          if (enabledCount > 4) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.28)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Text(
                      'Having more than 4 buttons may cause text labels to compress. Consider reducing the button spacing below.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Appearance'),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.ruler,
                title: 'Bar Height',
                subtitle: 'Adjust the size of the bottom bar',
                value: config.barSizeFactor,
                displayValue: '${config.barSizeFactor.toStringAsFixed(1)}x',
                min: 0.6,
                max: 1.4,
                divisions: 8,
                onChanged: (value) {
                  ref
                      .read(navBarConfigProvider.notifier)
                      .setBarSizeFactor(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.space,
                title: 'Button Spacing',
                subtitle: 'Adjust spacing between buttons',
                value: config.buttonSpacingFactor,
                displayValue: '${config.buttonSpacingFactor.toStringAsFixed(1)}x',
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (value) {
                  ref
                      .read(navBarConfigProvider.notifier)
                      .setButtonSpacingFactor(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.maximize,
                title: 'Icon Size',
                subtitle: 'Adjust the size of the icons',
                value: config.iconSizeFactor,
                displayValue: '${config.iconSizeFactor.toStringAsFixed(1)}x',
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (value) {
                  ref
                      .read(navBarConfigProvider.notifier)
                      .setIconSizeFactor(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.type,
                title: 'Show Labels',
                subtitle: 'Display text labels below icons',
                value: config.showLabels,
                onChanged: (value) {
                  ref
                      .read(navBarConfigProvider.notifier)
                      .setShowLabels(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Preview'),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: Container(
              color: AppColors.surface.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AbsorbPointer(
                child: FlickNavBar(
                  currentIndex: config.orderedButtons.first.pageIndex,
                  config: config,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }

}