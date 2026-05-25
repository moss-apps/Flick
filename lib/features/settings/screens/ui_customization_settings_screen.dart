import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/progress_bar_style.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class UiCustomizationSettingsScreen extends ConsumerWidget {
  const UiCustomizationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPreferences = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: 'UI Customization',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Home Screen Sections'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.zap,
                title: 'Quick Access',
                subtitle: 'Show the grid of shortcut cards on the home screen',
                value: appPreferences.showQuickAccess,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowQuickAccess(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.sparkles,
                title: 'Made For You',
                subtitle: 'Show smart mixes generated from your listening habits',
                value: appPreferences.showSmartMixes,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowSmartMixes(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.users,
                title: 'Artists In Rotation',
                subtitle: 'Show recently played artists on the home screen',
                value: appPreferences.showRecentArtists,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowRecentArtists(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.clock3,
                title: 'Recently Played',
                subtitle: 'Show your recent listening history on the home screen',
                value: appPreferences.showRecentTracks,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowRecentTracks(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.listMusic,
                title: 'Your Playlists',
                subtitle: 'Show playlist previews on the home screen',
                value: appPreferences.showPlaylistPreviews,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowPlaylistPreviews(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.compass,
                title: 'Browse More',
                subtitle: 'Show the browse chips for library sections on the home screen',
                value: appPreferences.showBrowseMore,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowBrowseMore(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.audioLines,
                title: 'Engine Selector',
                subtitle: 'Show the audio engine picker card on the home screen',
                value: appPreferences.showEngineSelector,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowEngineSelector(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Progress Bar'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.audioWaveform,
                title: ProgressBarStyle.waveform.label,
                subtitle: ProgressBarStyle.waveform.description,
                selected: ref.watch(progressBarStyleProvider) ==
                    ProgressBarStyle.waveform,
                onTap: () {
                  ref
                      .read(progressBarStyleProvider.notifier)
                      .setStyle(ProgressBarStyle.waveform);
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.minus,
                title: ProgressBarStyle.line.label,
                subtitle: ProgressBarStyle.line.description,
                selected: ref.watch(progressBarStyleProvider) ==
                    ProgressBarStyle.line,
                onTap: () {
                  ref
                      .read(progressBarStyleProvider.notifier)
                      .setStyle(ProgressBarStyle.line);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Album Colors'),
          SettingsCard(
            children: AlbumColorMode.values.map((mode) {
              final isSelected =
                  ref.watch(albumColorModeProvider) == mode;
              return Column(
                children: [
                  if (mode != AlbumColorMode.values.first)
                    const SettingsDivider(),
                  SelectionSetting(
                    icon: LucideIcons.palette,
                    title: mode.label,
                    subtitle: mode.description,
                    selected: isSelected,
                    onTap: () {
                      ref
                          .read(albumColorModeProvider.notifier)
                          .setMode(mode);
                    },
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
