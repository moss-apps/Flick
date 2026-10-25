import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/mini_player_config.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/providers/mini_player_config_provider.dart';
import 'package:flick/widgets/common/mini_player_bar.dart';
import 'package:flick/widgets/navigation/flick_nav_bar.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

class MiniPlayerCustomization extends ConsumerWidget {
  const MiniPlayerCustomization({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(miniPlayerConfigProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(miniPlayerConfigProvider.notifier);

    Widget slider(
      String title,
      String subtitle,
      double value,
      double min,
      double max,
      int divisions,
      String display,
      MiniPlayerConfig Function(MiniPlayerConfig, double) change,
    ) => SliderSetting(
      icon: LucideIcons.ruler,
      title: title,
      subtitle: subtitle,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      displayValue: display,
      onChanged: (value) => notifier.update((config) => change(config, value)),
    );

    Widget toggle(
      String title,
      String subtitle,
      IconData icon,
      bool value,
      MiniPlayerConfig Function(MiniPlayerConfig, bool) change,
    ) => ToggleSetting(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: (value) => notifier.update((config) => change(config, value)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(l10n.englishForFilipino.preview),
        const MiniPlayerPreview(),
        const SizedBox(height: AppConstants.spacingLg),
        SettingsSectionHeader(l10n.englishForFilipino.miniPlayerLayout),
        SettingsCard(
          children: [
            ToggleSetting(
              icon: LucideIcons.split,
              title: l10n.englishForFilipino.separateFromNavBar,
              subtitle: l10n.showTheMiniPlayerAsIts,
              value: prefs.separateMiniPlayerFromNavBar,
              onChanged: (value) => ref
                  .read(appPreferencesProvider.notifier)
                  .setSeparateMiniPlayerFromNavBar(value),
            ),
            const SettingsDivider(),
            if (prefs.separateMiniPlayerFromNavBar) ...[
              _Choices<MiniPlayerWidthMode>(
                title: l10n.englishForFilipino.width,
                value: config.widthMode,
                options: {
                  MiniPlayerWidthMode.matchNavigation: l10n.englishForFilipino.matchNavigation,
                  MiniPlayerWidthMode.custom: l10n.englishForFilipino.custom,
                },
                onChanged: (value) =>
                    notifier.update((c) => c.copyWith(widthMode: value)),
              ),
              if (config.widthMode == MiniPlayerWidthMode.custom)
                slider(
                  l10n.customWidth,
                  l10n.centeredWidensToFitYourControls,
                  config.widthFraction,
                  0.7,
                  1,
                  30,
                  '${(config.widthFraction * 100).round()}%',
                  (c, value) => c.copyWith(widthFraction: value),
                ),
              const SettingsDivider(),
              slider(
                l10n.gapAboveNavigation,
                l10n.spaceBetweenTheTwoBars,
                config.navigationGap,
                0,
                24,
                24,
                l10n.dp(config.navigationGap.round()),
                (c, value) => c.copyWith(navigationGap: value),
              ),
              const SettingsDivider(),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                child: Text(
                  l10n.separateTheMiniPlayerToCustomize,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ),
              const SettingsDivider(),
            ],
            slider(
              l10n.miniPlayerHeight,
              l10n.growsFurtherIfLargerSystemText,
              config.height,
              48,
              88,
              40,
              l10n.dp2(config.height.round()),
              (c, value) => c.copyWith(height: value),
            ),
            const SettingsDivider(),
            slider(
              l10n.cornerRadius,
              l10n.fromSquareCornersToARounded,
              config.cornerRadius,
              0,
              32,
              32,
              l10n.dp3(config.cornerRadius.round()),
              (c, value) => c.copyWith(cornerRadius: value),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingLg),
        SettingsSectionHeader(l10n.englishForFilipino.contentControls),
        SettingsCard(
          children: [
            toggle(
              l10n.albumArtwork,
              l10n.shownWhenThereIsRoomBeside,
              LucideIcons.image,
              config.showArtwork,
              (c, value) => c.copyWith(showArtwork: value),
            ),
            const SettingsDivider(),
            toggle(
              l10n.artist,
              l10n.showTheArtistBelowTheSong,
              LucideIcons.type,
              config.showArtist,
              (c, value) => c.copyWith(showArtist: value),
            ),
            const SettingsDivider(),
            toggle(
              l10n.progress,
              l10n.showAThinPlaybackProgressLine,
              LucideIcons.timer,
              config.showProgress,
              (c, value) => c.copyWith(showProgress: value),
            ),
            const SettingsDivider(),
            toggle(
              l10n.previousSong2,
              l10n.addAPreviousTrackButton,
              LucideIcons.skipBack,
              config.showPrevious,
              (c, value) => c.copyWith(showPrevious: value),
            ),
            const SettingsDivider(),
            toggle(
              l10n.nextSong2,
              l10n.addANextTrackButton,
              LucideIcons.skipForward,
              config.showNext,
              (c, value) => c.copyWith(showNext: value),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingLg),
        SettingsSectionHeader(l10n.englishForFilipino.miniPlayerAppearance),
        SettingsCard(
          children: [
            slider(
              l10n.backgroundOpacity,
              l10n.adjustTheMiniPlayerSurface,
              config.backgroundOpacity,
              0,
              1,
              100,
              '${(config.backgroundOpacity * 100).round()}%',
              (c, value) => c.copyWith(backgroundOpacity: value),
            ),
            const SettingsDivider(),
            toggle(
              l10n.border,
              l10n.outlineTheMiniPlayer,
              LucideIcons.square,
              config.showBorder,
              (c, value) => c.copyWith(showBorder: value),
            ),
            const SettingsDivider(),
            _Choices<MiniPlayerShadow>(
              title: l10n.englishForFilipino.shadow,
              value: config.shadow,
              options: {
                MiniPlayerShadow.off: l10n.englishForFilipino.off,
                MiniPlayerShadow.subtle: l10n.englishForFilipino.subtle,
                MiniPlayerShadow.strong: l10n.strong,
              },
              onChanged: (value) =>
                  notifier.update((c) => c.copyWith(shadow: value)),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingLg),
        SettingsSectionHeader(l10n.englishForFilipino.textGestures),
        SettingsCard(
          children: [
            slider(
              l10n.textSize2,
              l10n.alsoRespectsYourSystemTextSize,
              config.textScale,
              0.85,
              1.3,
              45,
              '${(config.textScale * 100).round()}%',
              (c, value) => c.copyWith(textScale: value),
            ),
            const SettingsDivider(),
            _Choices<MiniPlayerTitleMode>(
              title: l10n.englishForFilipino.longSongTitles,
              value: config.titleMode,
              options: {
                MiniPlayerTitleMode.truncate: l10n.englishForFilipino.truncate,
                MiniPlayerTitleMode.scroll: l10n.englishForFilipino.scroll,
              },
              subtitle: l10n.scrollingPausesWhenReducedMotionIs,
              onChanged: (value) =>
                  notifier.update((c) => c.copyWith(titleMode: value)),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.audioLines,
              title: l10n.englishForFilipino.visualizer,
              subtitle: l10n.swipeToShowOrHideThe,
              selected: prefs.miniPlayerSwipeAction == 'visualizer',
              onTap: () => ref
                  .read(appPreferencesProvider.notifier)
                  .setMiniPlayerSwipeAction('visualizer'),
            ),
            const SettingsDivider(),
            SelectionSetting(
              icon: LucideIcons.skipForward,
              title: l10n.englishForFilipino.switchSongs,
              subtitle: l10n.swipeLeftRightToSkipTracks,
              selected: prefs.miniPlayerSwipeAction == 'switchSongs',
              onTap: () => ref
                  .read(appPreferencesProvider.notifier)
                  .setMiniPlayerSwipeAction('switchSongs'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        TextButton.icon(
          icon: const Icon(LucideIcons.rotateCcw, size: 18),
          label: Text(l10n.resetMiniPlayerToDefaults),
          onPressed: () async {
            await Future.wait([
              notifier.reset(),
              ref
                  .read(appPreferencesProvider.notifier)
                  .setSeparateMiniPlayerFromNavBar(false),
              ref
                  .read(appPreferencesProvider.notifier)
                  .setMiniPlayerSwipeAction('visualizer'),
            ]);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showFlickSnackBar(
                SnackBar(content: Text(l10n.miniPlayerDefaultsRestored)),
              );
            }
          },
        ),
      ],
    );
  }
}

class MiniPlayerPreview extends ConsumerStatefulWidget {
  const MiniPlayerPreview({super.key});

  @override
  ConsumerState<MiniPlayerPreview> createState() => _MiniPlayerPreviewState();
}

class _MiniPlayerPreviewState extends ConsumerState<MiniPlayerPreview> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navBarConfigProvider);
    final mini = ref.watch(miniPlayerConfigProvider);
    final separated = ref.watch(
      appPreferencesProvider.select(
        (prefs) => prefs.separateMiniPlayerFromNavBar,
      ),
    );
    final song = ref.watch(currentSongProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.englishForFilipino.expanded),
              selected: !_collapsed,
              onSelected: (_) => setState(() => _collapsed = false),
            ),
            ChoiceChip(
              label: Text(l10n.englishForFilipino.collapsed),
              selected: _collapsed,
              onSelected: (_) => setState(() => _collapsed = true),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: ExcludeSemantics(
              child: AbsorbPointer(
                child: HeroMode(
                  enabled: false,
                  child: FlickNavBar(
                    currentIndex: nav.orderedButtons.first.pageIndex,
                    config: nav,
                    onTap: (_) {},
                    collapsed: _collapsed,
                    showMiniPlayer: true,
                    separateMiniPlayer: separated,
                    miniPlayerWidget: MiniPlayerBar(
                      config: mini,
                      separated: separated,
                      collapsed: _collapsed,
                      songId: song?.id ?? 'preview',
                      title:
                          song?.title ?? l10n.aSongWithALongTitle,
                      artist: song?.artist ?? l10n.sampleArtist,
                      albumArt: song?.albumArt,
                      audioSourcePath: song?.filePath,
                      progress: 0.42,
                      enableHero: false,
                      onPlayPause: () {},
                      onPrevious: () {},
                      onNext: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Text(
          song == null
              ? l10n.sampleSongPreviewOnly
              : l10n.currentSongPreviewOnly,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.adaptiveTextSecondary),
        ),
      ],
    );
  }
}

class _Choices<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _Choices({
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppConstants.spacingLg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: context.adaptiveTextPrimary),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppConstants.spacingSm),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in options.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: value == option.key,
                onSelected: (_) => onChanged(option.key),
              ),
          ],
        ),
      ],
    ),
  );
}
