import 'dart:io';
import 'package:flick/widgets/common/flick_snackbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/song_view_mode.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/features/settings/screens/orbit_settings_screen.dart';
import 'package:flick/l10n/settings_l10n.dart';

class PlaybackDisplaySettingsScreen extends ConsumerWidget {
  const PlaybackDisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsViewMode = ref.watch(songsViewModeProvider);
    final navBarAlwaysVisible = ref.watch(navBarAlwaysVisibleProvider);
    final appPrefs = ref.watch(appPreferencesProvider);
    final playerService = ref.read(playerServiceProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.playbackDisplay,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.playback),
          SettingsCard(
            children: [
              _GaplessPlaybackTile(playerService: playerService),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.music,
                title: l10n.englishForFilipino.keepPlayingOnQuit,
                subtitle: appPrefs.keepPlayingOnQuit
                    ? l10n.playbackContinuesWhenTheAppIs
                    : l10n.playbackStopsWhenTheAppIs,
                value: appPrefs.keepPlayingOnQuit,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setKeepPlayingOnQuit(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.shieldCheck,
                title: l10n.englishForFilipino.backgroundPlaybackAnchor,
                subtitle: appPrefs.priorityAnchorEnabled
                    ? l10n.keepsBitPerfectAudioAliveIn
                    : l10n.mayStopInTheBackgroundOn,
                value: appPrefs.priorityAnchorEnabled,
                onChanged: (value) {
                  playerService.setPriorityAnchorEnabled(value);
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setPriorityAnchorEnabled(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.clapperboard,
                title: l10n.englishForFilipino.motionArtInBitPerfect,
                subtitle: appPrefs.motionArtDuringBitPerfect
                    ? l10n.motionArtPlaysDuringBitPerfect
                    : l10n.motionArtIsReplacedWhileBit,
                value: appPrefs.motionArtDuringBitPerfect,
                onChanged: (value) {
                  playerService.setMotionArtDuringBitPerfect(value);
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setMotionArtDuringBitPerfect(value);
                },
              ),
              const SettingsDivider(),
              if (Platform.isAndroid) ...[
                _DuckOnInterruptionTile(playerService: playerService),
                const SettingsDivider(),
              ],
              ToggleSetting(
                icon: LucideIcons.pictureInPicture2,
                title: l10n.englishForFilipino.floatingMiniPlayer,
                subtitle: appPrefs.floatingPlayerEnabled
                    ? l10n.aDraggableOverlayShowsWhileUsing
                    : l10n.showASystemOverlayMiniPlayer,
                value: appPrefs.floatingPlayerEnabled,
                onChanged: (value) => _onFloatingPlayerToggled(
                  context,
                  ref,
                  playerService,
                  value,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.display),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.disc,
                title: l10n.englishForFilipino.songViewOrbital,
                subtitle: l10n.useTheOrbitalSongsBrowser,
                selected: songsViewMode == SongViewMode.orbit,
                onTap: () {
                  ref
                      .read(songsViewModeProvider.notifier)
                      .setMode(SongViewMode.orbit);
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: LucideIcons.list,
                title: l10n.englishForFilipino.songViewList,
                subtitle: l10n.useTheListSongsBrowser,
                selected: songsViewMode == SongViewMode.list,
                onTap: () {
                  ref
                      .read(songsViewModeProvider.notifier)
                      .setMode(SongViewMode.list);
                },
              ),
              if (songsViewMode == SongViewMode.orbit) ...[
                const SettingsDivider(),
                NavigationSetting(
                  icon: LucideIcons.slidersHorizontal,
                  title: l10n.englishForFilipino.customizeOrbital,
                  subtitle: l10n.curvatureSizingDepthAndVisuals,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OrbitSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.panelBottom,
                title: l10n.englishForFilipino.bottomBarAlwaysVisible,
                subtitle: l10n.keepMiniPlayerAndNavVisible,
                value: navBarAlwaysVisible,
                onChanged: (value) {
                  ref
                      .read(navBarAlwaysVisibleProvider.notifier)
                      .setAlwaysVisible(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.circleDot,
                title: l10n.englishForFilipino.floatingIsland,
                subtitle: appPrefs.floatingIslandEnabled
                    ? l10n.showTheFloatingMiniPlayerPill
                    : l10n.hideTheFloatingMiniPlayerPill,
                value: appPrefs.floatingIslandEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setFloatingIslandEnabled(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.maximize,
                title: l10n.englishForFilipino.immersiveFullViewTimer,
                subtitle:
                    l10n.autoShowTheSpotifyStyleImmersive,
                value: appPrefs.immersiveAutoFullViewSeconds.toDouble(),
                displayValue: appPrefs.immersiveAutoFullViewSeconds == 0
                    ? l10n.off
                    : '${appPrefs.immersiveAutoFullViewSeconds}s',
                min: 0,
                max: 15,
                divisions: 15,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveAutoFullViewSeconds(value.round());
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.fastIndexScrolling),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.arrowUpDown,
                title: l10n.englishForFilipino.fastIndexScrolling,
                subtitle: l10n.alphabeticalIndexRailOnTheSongs,
                value: appPrefs.fastIndexEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setFastIndexEnabled(value);
                },
              ),
              if (appPrefs.fastIndexEnabled) ...[
                const SettingsDivider(),
                SliderSetting(
                  icon: LucideIcons.clock,
                  title: l10n.englishForFilipino.autoHideTimeout,
                  subtitle: l10n.hideTheIndexRailAfterInactivity,
                  value: appPrefs.fastIndexTimeoutSeconds.toDouble(),
                  displayValue: '${appPrefs.fastIndexTimeoutSeconds}s',
                  min: 2,
                  max: 10,
                  divisions: 8,
                  onChanged: (value) {
                    ref
                        .read(appPreferencesProvider.notifier)
                        .setFastIndexTimeoutSeconds(value.round());
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          // Bottom padding for nav bar
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _DuckOnInterruptionTile extends StatelessWidget {
  const _DuckOnInterruptionTile({required this.playerService});

  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerService.duckOnInterruptionNotifier,
      builder: (context, _) {
        final duck = playerService.duckOnInterruptionNotifier.value;
        return ToggleSetting(
          icon: LucideIcons.bellOff,
          title: l10n.englishForFilipino.duckOnNotifications,
          subtitle: duck
              ? l10n.volumeDipsWhileNotificationSoundsPlay
              : l10n.playbackPausesWhileNotificationSoundsPlay,
          value: duck,
          onChanged: (value) => playerService.setDuckOnInterruption(value),
        );
      },
    );
  }
}

class _GaplessPlaybackTile extends StatelessWidget {
  const _GaplessPlaybackTile({required this.playerService});

  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        playerService.gaplessPlaybackEnabledNotifier,
        playerService.bitPerfectProcessingLockedNotifier,
      ]),
      builder: (context, _) {
        final enabled = playerService.gaplessPlaybackEnabledNotifier.value;
        final isBitPerfect = playerService.isBitPerfectModeEnabled;
        return ToggleSetting(
          icon: LucideIcons.repeat,
          title: l10n.englishForFilipino.gaplessPlayback,
          subtitle: isBitPerfect
              ? l10n.disabledInBitPerfectMode
              : l10n.seamlessTransitionBetweenTracks,
          value: enabled,
          onChanged: (value) => playerService.setGaplessPlaybackEnabled(value),
        );
      },
    );
  }
}

Future<void> _onFloatingPlayerToggled(
  BuildContext context,
  WidgetRef ref,
  PlayerService playerService,
  bool value,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (value) {
    final canShow = await playerService.canShowFloatingPlayer();
    if (!canShow) {
      final granted = await playerService.requestFloatingPlayerPermission();
      if (!granted) {
        messenger.showFlickSnackBar(
          SnackBar(
            content: Text(
              l10n.overlayPermissionIsRequiredToShow,
            ),
          ),
        );
        return;
      }
    }
    await playerService.setFloatingPlayerEnabled(true);
    ref.read(appPreferencesProvider.notifier).setFloatingPlayerEnabled(true);
  } else {
    await playerService.setFloatingPlayerEnabled(false);
    ref.read(appPreferencesProvider.notifier).setFloatingPlayerEnabled(false);
  }
}
