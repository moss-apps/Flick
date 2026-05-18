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
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
