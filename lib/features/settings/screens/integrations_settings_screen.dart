import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/settings/widgets/lastfm_settings_tile.dart';
import 'package:flick/features/settings/widgets/listenbrainz_settings_tile.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class IntegrationsSettingsScreen extends StatelessWidget {
  const IntegrationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Integrations',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Integrations'),
          const SettingsCard(
            children: [LastFmSettingsTile(), ListenBrainzSettingsTile()],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
