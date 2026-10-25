import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/progress_bar_style.dart';
import 'package:flick/models/song_tile_thumbnail_mode.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

import 'package:flick/l10n/settings_l10n.dart';
class UiCustomizationSettingsScreen extends ConsumerWidget {
  const UiCustomizationSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPreferences = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.uiCustomization,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.homeScreenSections, sectionId: 'homeScreenSections'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.zap,
                title: l10n.englishForFilipino.quickAccess,
                subtitle: l10n.showTheGridOfShortcutCards,
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
                title: l10n.englishForFilipino.madeForYou,
                subtitle: l10n.showSmartMixesGeneratedFromYour,
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
                title: l10n.englishForFilipino.artistsInRotation,
                subtitle: l10n.showRecentlyPlayedArtistsOnThe,
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
                title: l10n.englishForFilipino.recentlyPlayed,
                subtitle: l10n.showYourRecentListeningHistoryOn,
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
                title: l10n.englishForFilipino.yourPlaylists,
                subtitle: l10n.showPlaylistPreviewsOnTheHome,
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
                title: l10n.englishForFilipino.browseMore,
                subtitle: l10n.showTheBrowseChipsForLibrary,
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
                title: l10n.englishForFilipino.engineSelector,
                subtitle: l10n.showTheAudioEnginePickerCard,
                value: appPreferences.showEngineSelector,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowEngineSelector(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.volume2,
                title: l10n.englishForFilipino.usbVolumeOnHome,
                subtitle: l10n.showTheUsbVolumeBarOn,
                value: appPreferences.showUsbVolumeOnMenu,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowUsbVolumeOnMenu(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.slidersHorizontal,
                title: l10n.englishForFilipino.usbVolumeInSettings,
                subtitle: l10n.showTheUsbVolumeBarOn2,
                value: appPreferences.showUsbVolumeOnSettings,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowUsbVolumeOnSettings(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.detailScreens, sectionId: 'detailScreens'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.disc3,
                title: l10n.englishForFilipino.moreFromArtist2,
                subtitle: l10n.showRelatedAlbumsOnAlbumPages,
                value: appPreferences.showMoreFromArtist,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowMoreFromArtist(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.users,
                title: l10n.englishForFilipino.moreArtists2,
                subtitle: l10n.showOtherArtistsOnAlbumPages,
                value: appPreferences.showMoreArtists,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setShowMoreArtists(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.sparkles,
                title: l10n.englishForFilipino.animatedAlbumArt,
                subtitle:
                    l10n.appleMusicMotionArtOnAlbums,
                value: appPreferences.animatedAlbumArt,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setAnimatedAlbumArt(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.image,
                title: l10n.englishForFilipino.expandedHeaderArt,
                subtitle:
                    l10n.showMoreArtByFadingOnly,
                value: appPreferences.detailHeaderArtExpanded,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setDetailHeaderArtExpanded(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.alignCenter,
                title: l10n.englishForFilipino.centeredHeaderTitle,
                subtitle: l10n.centerTheTitleAndInfoIn,
                value: appPreferences.detailHeaderCenteredTitle,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setDetailHeaderCenteredTitle(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.trackThumbnails, sectionId: 'trackThumbnails'),
          SettingsCard(
            children: SongTileThumbnailMode.values.map((mode) {
              final isSelected =
                  appPreferences.songTileThumbnailMode == mode.storageValue;
              final icon = switch (mode) {
                SongTileThumbnailMode.artwork => LucideIcons.image,
                SongTileThumbnailMode.trackNumber => LucideIcons.hash,
                SongTileThumbnailMode.trackNumberOnArt => LucideIcons.layers,
              };
              return Column(
                children: [
                  if (mode != SongTileThumbnailMode.values.first)
                    const SettingsDivider(),
                  SelectionSetting(
                    icon: icon,
                    title: mode.labelFor(l10n.englishForFilipino),
                    subtitle: mode.description,
                    selected: isSelected,
                    onTap: () {
                      ref
                          .read(appPreferencesProvider.notifier)
                          .setSongTileThumbnailMode(mode.storageValue);
                    },
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.progressBar, sectionId: 'progressBar'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.audioWaveform,
                title: ProgressBarStyle.waveform.labelFor(l10n.englishForFilipino),
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
                title: ProgressBarStyle.line.labelFor(l10n.englishForFilipino),
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
          SettingsSectionHeader(l10n.englishForFilipino.albumColors, sectionId: 'albumColors'),
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
                    title: mode.labelFor(l10n.englishForFilipino),
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
