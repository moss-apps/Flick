import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/milestone_service.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/features/settings/widgets/language_settings_card.dart';
import 'package:flick/features/settings/screens/bottom_bar_settings_screen.dart';
import 'package:flick/features/settings/screens/visualizer_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';

class InterfaceSettingsScreen extends ConsumerWidget {
  const InterfaceSettingsScreen({super.key});

  Future<void> _confirmResetStreak(BuildContext context) async {
    final confirmed = await FlickDialogs.confirm(
      context,
      title: l10n.resetStreakData,
      message:
          l10n.thisClearsYourCurrentDayStreak,
      confirmLabel: l10n.reset,
      destructive: true,
    );
    if (confirmed) {
      await MilestoneService().clearStreakData();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPreferences = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: l10n.interfaceLabel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(context.l10n.language),
          const LanguageSettingsCard(),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.interfaceLabel),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.activity,
                title: l10n.animations,
                subtitle: l10n.enableAnimatedTransitionsAndEffects,
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
                title: l10n.hapticFeedback,
                subtitle: l10n.enableVibrationOnInteractions,
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
                icon: LucideIcons.wifiOff,
                title: context.l10n.connectionNotices,
                subtitle: context.l10n.connectionNoticesDescription,
                value: appPreferences.connectionNoticesEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setConnectionNoticesEnabled(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.arrowLeftRight,
                title: l10n.swipeActions,
                subtitle: l10n.swipeSongsLeftToQueueOr,
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
                title: l10n.autoFocusSearch,
                subtitle: l10n.automaticallyOpenKeyboardWhenSwitchingTo,
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
                title: l10n.libraryGlanceCard,
                subtitle: l10n.showTheAtAGlanceSummary,
                value: !appPreferences.glanceCardHidden,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setGlanceCardHidden(!value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.flame,
                title: l10n.dayStreaks,
                subtitle: l10n.trackConsecutiveListeningDaysAndShow,
                value: appPreferences.streaksEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setStreaksEnabled(value);
                },
              ),
              const SettingsDivider(),
              ActionButton(
                icon: LucideIcons.trash2,
                title: l10n.resetStreakData2,
                subtitle: l10n.clearTheCounterAndAnyUnlocked,
                onTap: () => _confirmResetStreak(context),
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.navigation,
                title: l10n.bottomBar,
                subtitle: l10n.customizeWhichTabsAppearAndTheir,
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
                title: l10n.visualizer,
                subtitle: l10n.animationStyleAndFrequencyFocus,
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
          SettingsSectionHeader(l10n.refreshRate),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.smartphone,
                title: l10n.adaptive,
                subtitle: l10n.letTheSystemDecideBestBattery,
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
                title: l10n.standard60hz,
                subtitle: l10n.capAt60hzBalancedSmoothnessAnd,
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
                title: l10n.high120hz,
                subtitle: l10n.maximumSmoothnessUsesMoreBattery,
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
          SettingsSectionHeader(l10n.searchPlayback),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.listMusic,
                title: l10n.searchResults,
                subtitle: l10n.continueThroughTheSearchResults,
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
                title: l10n.fullLibrary,
                subtitle: l10n.continueThroughYourEntireLibrary,
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
                title: l10n.activeQueue,
                subtitle: l10n.insertIntoTheCurrentQueueFallBackToResults,
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
          SettingsSectionHeader(l10n.favoriteRemoval),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.arrowLeftRight,
                title: l10n.swipe,
                subtitle: l10n.swipeLeftToUnfavoriteASong,
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
                title: l10n.longPress,
                subtitle: l10n.holdASongToUnfavorite,
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
