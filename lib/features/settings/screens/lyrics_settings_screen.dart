import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/app_preferences_provider.dart';

class LyricsSettingsScreen extends ConsumerWidget {
  const LyricsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPrefs = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: 'Lyrics',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Saving'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: 'Match Audio Filename',
                subtitle:
                    'Use the current audio file\'s name when saving lyrics internally',
                value: appPrefs.lyricsMatchAudioFilename,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsMatchAudioFilename(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Display'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: Icons.format_align_left_rounded,
                title: 'Left',
                subtitle: 'Align lyric text to the left edge',
                selected: appPrefs.lyricsTextAlign == 'left',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsTextAlign('left');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.format_align_center_rounded,
                title: 'Center',
                subtitle: 'Align lyric text to the center',
                selected: appPrefs.lyricsTextAlign == 'center',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsTextAlign('center');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.format_align_right_rounded,
                title: 'Right',
                subtitle: 'Align lyric text to the right edge',
                selected: appPrefs.lyricsTextAlign == 'right',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsTextAlign('right');
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
