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
