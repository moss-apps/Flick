import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/models/song_view_mode.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class PlaybackDisplaySettingsScreen extends ConsumerWidget {
  const PlaybackDisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsViewMode = ref.watch(songsViewModeProvider);
    final navBarAlwaysVisible = ref.watch(navBarAlwaysVisibleProvider);
    final appPrefs = ref.watch(appPreferencesProvider);
    final playerService = ref.read(playerServiceProvider);

    return SettingsScaffold(
      title: 'Playback & Display',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Playback'),
          SettingsCard(
            children: [
              _GaplessPlaybackTile(playerService: playerService),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.music,
                title: 'Keep Playing on Quit',
                subtitle: appPrefs.keepPlayingOnQuit
                    ? 'Playback continues when the app is swiped away'
                    : 'Playback stops when the app is swiped away',
                value: appPrefs.keepPlayingOnQuit,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setKeepPlayingOnQuit(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.pictureInPicture2,
                title: 'Floating Mini-Player',
                subtitle: appPrefs.floatingPlayerEnabled
                    ? 'A draggable overlay shows while using other apps'
                    : 'Show a system overlay mini-player over other apps',
                value: appPrefs.floatingPlayerEnabled,
                onChanged: (value) => _onFloatingPlayerToggled(
                  context,
                  ref,
                  playerService,
                  value,
                ),
              ),
              const SettingsDivider(),
              _WrapAroundQueueTile(playerService: playerService),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Display'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: LucideIcons.disc,
                title: 'Song View: Orbital',
                subtitle: 'Use the orbital songs browser',
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
                title: 'Song View: List',
                subtitle: 'Use the list songs browser',
                selected: songsViewMode == SongViewMode.list,
                onTap: () {
                  ref
                      .read(songsViewModeProvider.notifier)
                      .setMode(SongViewMode.list);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.panelBottom,
                title: 'Bottom Bar Always Visible',
                subtitle: 'Keep mini player and nav visible',
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
                title: 'Floating Island',
                subtitle: appPrefs.floatingIslandEnabled
                    ? 'Show the floating mini-player pill on screens'
                    : 'Hide the floating mini-player pill',
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
                title: 'Immersive Full View Timer',
                subtitle:
                    'Auto-show the Spotify-style immersive full view after inactivity',
                value: appPrefs.immersiveAutoFullViewSeconds.toDouble(),
                displayValue: appPrefs.immersiveAutoFullViewSeconds == 0
                    ? 'Off'
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
          const SettingsSectionHeader('Fast Index Scrolling'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.arrowUpDown,
                title: 'Fast Index Scrolling',
                subtitle: 'Alphabetical index rail on the songs screen',
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
                  title: 'Auto-hide Timeout',
                  subtitle: 'Hide the index rail after inactivity',
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

class _WrapAroundQueueTile extends StatelessWidget {
  const _WrapAroundQueueTile({required this.playerService});

  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerService.wrapAroundQueueNotifier,
      builder: (context, _) {
        final enabled = playerService.wrapAroundQueueNotifier.value;
        return ToggleSetting(
          icon: LucideIcons.refreshCw,
          title: 'Wrap-around Queue',
          subtitle: enabled
              ? 'Songs before the tapped track queue at the end'
              : 'Stop at the end of the current list',
          value: enabled,
          onChanged: (value) => playerService.setWrapAroundQueue(value),
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
          title: 'Gapless Playback',
          subtitle: isBitPerfect
              ? 'Disabled in bit-perfect mode'
              : 'Seamless transition between tracks',
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
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Overlay permission is required to show the floating player',
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
