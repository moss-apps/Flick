import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/settings/widgets/apple_music_settings_tile.dart';
import 'package:flick/features/settings/widgets/lastfm_settings_tile.dart';
import 'package:flick/features/settings/widgets/listenbrainz_settings_tile.dart';
import 'package:flick/features/settings/widgets/settings_info_sheet.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class IntegrationsSettingsScreen extends StatelessWidget {
  const IntegrationsSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: l10n.englishForFilipino.integrations,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsInfoBanner(
            icon: LucideIcons.shieldCheck,
            title: l10n.integrationsPrivacyNoteTitle,
            subtitle: l10n.integrationsPrivacyNoteSubtitle,
            onTap: () => showSettingsInfoSheet(
              context,
              icon: LucideIcons.shieldCheck,
              title: l10n.integrationsPrivacySheetTitle,
              intro: l10n.integrationsPrivacyIntro,
              sections: [
                SettingsInfoSection(
                  heading: l10n.integrationsLastFmHeading,
                  body: l10n.integrationsLastFmBody,
                ),
                SettingsInfoSection(
                  heading: l10n.integrationsListenBrainzHeading,
                  body: l10n.integrationsListenBrainzBody,
                ),
                SettingsInfoSection(
                  heading: l10n.integrationsAppleMusicHeading,
                  body: l10n.integrationsAppleMusicBody,
                ),
                SettingsInfoSection(
                  heading: l10n.integrationsDisconnectHeading,
                  body: l10n.integrationsDisconnectBody,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.integrations, sectionId: 'integrations'),
          const SettingsCard(
            children: [LastFmSettingsTile(), ListenBrainzSettingsTile()],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.metadata, sectionId: 'metadata'),
          const SettingsCard(
            children: [
              AppleMusicSettingsTile(),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
