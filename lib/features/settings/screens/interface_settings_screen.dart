import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/features/settings/screens/bottom_bar_settings_screen.dart';
import 'package:flick/features/settings/screens/visualizer_settings_screen.dart';

class InterfaceSettingsScreen extends ConsumerWidget {
  const InterfaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPreferences = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: 'Interface',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Interface'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.activity,
                title: 'Animations',
                subtitle: 'Enable animated transitions and effects',
                value: appPreferences.animationsEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setAnimationsEnabled(value);
                  AppConstants.setAnimationsEnabled(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.vibrate,
                title: 'Haptic Feedback',
                subtitle: 'Enable vibration on interactions',
                value: appPreferences.hapticsEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setHapticsEnabled(value);
                  AppHaptics.setEnabled(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.arrowLeftRight,
                title: 'Swipe Actions',
                subtitle: 'Swipe songs left to queue or right to favorite',
                value: appPreferences.swipeActionsEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setSwipeActionsEnabled(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.keyboard,
                title: 'Auto-Focus Search',
                subtitle: 'Automatically open keyboard when switching to search',
                value: appPreferences.autoFocusSearch,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setAutoFocusSearch(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.layoutGrid,
                title: 'Library Glance Card',
                subtitle: 'Show the "at a glance" summary on Artists/Albums',
                value: !appPreferences.glanceCardHidden,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setGlanceCardHidden(!value);
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.navigation,
                title: 'Bottom Bar',
                subtitle: 'Customize which tabs appear and their size',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BottomBarSettingsScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.audioLines,
                title: 'Visualizer',
                subtitle: 'Animation style and frequency focus',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VisualizerSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Refresh Rate'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.smartphone,
                title: 'Adaptive',
                subtitle: 'Let the system decide — best battery life',
                selected: appPreferences.refreshRateMode == 'adaptive',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setRefreshRateMode('adaptive');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.gauge,
                title: 'Standard (60Hz)',
                subtitle: 'Cap at 60Hz — balanced smoothness and battery',
                selected: appPreferences.refreshRateMode == 'standard',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setRefreshRateMode('standard');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.zap,
                title: 'High (120Hz)',
                subtitle: 'Maximum smoothness — uses more battery',
                selected: appPreferences.refreshRateMode == 'high',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setRefreshRateMode('high');
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Search Playback'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.listMusic,
                title: 'Search Results',
                subtitle: 'Continue through the search results',
                selected: appPreferences.searchPlaybackMode == 'results',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setSearchPlaybackMode('results');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.library,
                title: 'Full Library',
                subtitle: 'Continue through your entire library',
                selected: appPreferences.searchPlaybackMode == 'library',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setSearchPlaybackMode('library');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.listPlus,
                title: 'Active Queue',
                subtitle:
                    'Insert into the current queue, fall back to results',
                selected: appPreferences.searchPlaybackMode == 'queue',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setSearchPlaybackMode('queue');
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Favorite Removal'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.arrowLeftRight,
                title: 'Swipe',
                subtitle: 'Swipe left to unfavorite a song',
                selected: appPreferences.favoriteRemovalMode == 'swipe',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setFavoriteRemovalMode('swipe');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.mousePointerClick,
                title: 'Long Press',
                subtitle: 'Hold a song to unfavorite',
                selected: appPreferences.favoriteRemovalMode == 'longpress',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setFavoriteRemovalMode('longpress');
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
