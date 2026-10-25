import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';

import 'package:flick/l10n/settings_l10n.dart';
String _placementLabel(double value) {
  if (value == 0) return l10n.center;
  return value < 0 ? l10n.up(value.abs().round()) : l10n.down(value.round());
}

String _percentLabel(double value) =>
    '${(value * 100).round()}%';

class PlayerLayoutSettingsScreen extends ConsumerWidget {
  const PlayerLayoutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPrefs = ref.watch(appPreferencesProvider);
    final playerScreenMode = ref.watch(playerScreenModeProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.playerLayout,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showFullScreenPreview(context, ref),
            child: Stack(
              children: [
                _LayoutPreview(
                  song: ref.watch(currentSongProvider),
                  mode: playerScreenMode,
                  artworkCardArtworkScale: appPrefs.artworkCardArtworkScale,
                  artworkCardTextScale: appPrefs.artworkCardTextScale,
                  artworkCardVerticalOffset: appPrefs.artworkCardVerticalOffset,
                  artworkCardArtworkOffset: appPrefs.artworkCardArtworkOffset,
                  artworkCardShowTitle: appPrefs.artworkCardShowTitle,
                  artworkCardShowArtist: appPrefs.artworkCardShowArtist,
                  artworkCardShowAlbum: appPrefs.artworkCardShowAlbum,
                  artworkCardShowFileInfo: appPrefs.artworkCardShowFileInfo,
                  artworkCardShowFrame: appPrefs.artworkCardShowFrame,
                  immersiveTextScale: appPrefs.immersiveTextScale,
                  immersiveVerticalOffset: appPrefs.immersiveVerticalOffset,
                  immersiveFullViewScale: appPrefs.immersiveFullViewScale,
                  immersiveShowTitle: appPrefs.immersiveShowTitle,
                  immersiveShowArtist: appPrefs.immersiveShowArtist,
                  immersiveShowFileInfo: appPrefs.immersiveShowFileInfo,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.englishForFilipino.fullscreen,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.layoutMode),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: Icons.fit_screen_rounded,
                title: PlayerScreenMode.immersive.labelFor(l10n.englishForFilipino),
                subtitle: PlayerScreenMode.immersive.description,
                selected: playerScreenMode == PlayerScreenMode.immersive,
                onTap: () {
                  ref
                      .read(playerScreenModeProvider.notifier)
                      .setMode(PlayerScreenMode.immersive);
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.rounded_corner_rounded,
                title: PlayerScreenMode.artworkCard.labelFor(l10n.englishForFilipino),
                subtitle: PlayerScreenMode.artworkCard.description,
                selected: playerScreenMode == PlayerScreenMode.artworkCard,
                onTap: () {
                  ref
                      .read(playerScreenModeProvider.notifier)
                      .setMode(PlayerScreenMode.artworkCard);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.immersive),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.type,
                title: l10n.englishForFilipino.textSize2,
                subtitle: l10n.adjustMetadataTextSizeInImmersive,
                value: appPrefs.immersiveTextScale,
                displayValue: _percentLabel(appPrefs.immersiveTextScale),
                min: 0.82,
                max: 1.2,
                divisions: 19,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveTextScale(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.arrowUpDown,
                title: l10n.englishForFilipino.textPlacement2,
                subtitle: l10n.shiftMetadataTextUpOrDown,
                value: appPrefs.immersiveVerticalOffset,
                displayValue: _placementLabel(appPrefs.immersiveVerticalOffset),
                min: -36,
                max: 36,
                divisions: 12,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveVerticalOffset(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.maximize,
                title: l10n.englishForFilipino.fullViewCardSize2,
                subtitle: l10n.scaleTheFullViewAlbumArt,
                value: appPrefs.immersiveFullViewScale,
                displayValue: _percentLabel(appPrefs.immersiveFullViewScale),
                min: 0.82,
                max: 1.18,
                divisions: 18,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveFullViewScale(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: l10n.englishForFilipino.showTitle2,
                subtitle: l10n.displayTheTrackTitleInImmersive,
                value: appPrefs.immersiveShowTitle,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveShowTitle(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.mic,
                title: l10n.englishForFilipino.showArtist2,
                subtitle: l10n.displayTheArtistNameInImmersive,
                value: appPrefs.immersiveShowArtist,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveShowArtist(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.info,
                title: l10n.englishForFilipino.showFileInfo2,
                subtitle: l10n.displayFileFormatAndBitrateIn,
                value: appPrefs.immersiveShowFileInfo,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setImmersiveShowFileInfo(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.clock,
                title: l10n.englishForFilipino.autoFullView,
                subtitle: l10n.autoShowFullViewAfterInactivity,
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
          SettingsSectionHeader(l10n.englishForFilipino.artworkCard),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.rectangleHorizontal,
                title: l10n.englishForFilipino.artworkSize2,
                subtitle: l10n.scaleTheAlbumArtCard,
                value: appPrefs.artworkCardArtworkScale,
                displayValue: _percentLabel(appPrefs.artworkCardArtworkScale),
                min: 0.8,
                max: 1.36,
                divisions: 28,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardArtworkScale(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.type,
                title: l10n.englishForFilipino.textSize2,
                subtitle: l10n.adjustMetadataTextSizeInArtwork,
                value: appPrefs.artworkCardTextScale,
                displayValue: _percentLabel(appPrefs.artworkCardTextScale),
                min: 0.82,
                max: 1.2,
                divisions: 19,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardTextScale(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.arrowUpDown,
                title: l10n.englishForFilipino.contentPlacement2,
                subtitle: l10n.shiftOnlyTheSongDetailsUp,
                value: appPrefs.artworkCardVerticalOffset,
                displayValue:
                    _placementLabel(appPrefs.artworkCardVerticalOffset),
                min: -36,
                max: 36,
                divisions: 12,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardVerticalOffset(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.moveVertical,
                title: l10n.englishForFilipino.artworkPlacement2,
                subtitle: l10n.shiftOnlyTheAlbumArtUp,
                value: appPrefs.artworkCardArtworkOffset,
                displayValue:
                    _placementLabel(appPrefs.artworkCardArtworkOffset),
                min: -48,
                max: 48,
                divisions: 16,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardArtworkOffset(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: l10n.englishForFilipino.showTitle2,
                subtitle: l10n.displayTheTrackTitleInArtwork,
                value: appPrefs.artworkCardShowTitle,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardShowTitle(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.mic,
                title: l10n.englishForFilipino.showArtist2,
                subtitle: l10n.displayTheArtistNameInArtwork,
                value: appPrefs.artworkCardShowArtist,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardShowArtist(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.disc,
                title: l10n.englishForFilipino.showAlbum2,
                subtitle: l10n.displayTheAlbumNameInArtwork,
                value: appPrefs.artworkCardShowAlbum,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardShowAlbum(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.info,
                title: l10n.englishForFilipino.showFileInfo2,
                subtitle:
                    l10n.displayFileFormatAndBitrateIn2,
                value: appPrefs.artworkCardShowFileInfo,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardShowFileInfo(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.frame,
                title: l10n.englishForFilipino.showFrame2,
                subtitle: l10n.showTheGlassFrameAroundAlbum,
                value: appPrefs.artworkCardShowFrame,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardShowFrame(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.shieldCheck,
                title: l10n.englishForFilipino.bitPerfectCapsule,
                subtitle:
                    l10n.replaceAlbumNameWithAVerified,
                value: appPrefs.replaceAlbumWithBitPerfectCapsule,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setReplaceAlbumWithBitPerfectCapsule(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.quickActions),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: Icons.arrow_upward_rounded,
                title: l10n.englishForFilipino.leftTopButton,
                subtitle: PlayerActionButtonX.fromStorageValue(
                  appPrefs.leftTopActionButton,
                ).labelFor(l10n.englishForFilipino),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ActionButtonPickerScreen(
                        title: l10n.englishForFilipino.leftTopButton,
                        currentValue: PlayerActionButtonX.fromStorageValue(
                          appPrefs.leftTopActionButton,
                        ),
                        onSelected: (action) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setLeftTopActionButton(action.storageValue);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: Icons.arrow_back_rounded,
                title: l10n.englishForFilipino.leftBottomButton,
                subtitle: PlayerActionButtonX.fromStorageValue(
                  appPrefs.leftActionButton,
                ).labelFor(l10n.englishForFilipino),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ActionButtonPickerScreen(
                        title: l10n.englishForFilipino.leftBottomButton,
                        currentValue: PlayerActionButtonX.fromStorageValue(
                          appPrefs.leftActionButton,
                        ),
                        onSelected: (action) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setLeftActionButton(action.storageValue);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: Icons.arrow_upward_rounded,
                title: l10n.englishForFilipino.rightTopButton,
                subtitle: PlayerActionButtonX.fromStorageValue(
                  appPrefs.rightTopActionButton,
                ).labelFor(l10n.englishForFilipino),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ActionButtonPickerScreen(
                        title: l10n.englishForFilipino.rightTopButton,
                        currentValue: PlayerActionButtonX.fromStorageValue(
                          appPrefs.rightTopActionButton,
                        ),
                        onSelected: (action) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setRightTopActionButton(action.storageValue);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: Icons.arrow_forward_rounded,
                title: l10n.englishForFilipino.rightBottomButton,
                subtitle: PlayerActionButtonX.fromStorageValue(
                  appPrefs.rightActionButton,
                ).labelFor(l10n.englishForFilipino),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ActionButtonPickerScreen(
                        title: l10n.englishForFilipino.rightBottomButton,
                        currentValue: PlayerActionButtonX.fromStorageValue(
                          appPrefs.rightActionButton,
                        ),
                        onSelected: (action) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setRightActionButton(action.storageValue);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }

  void _showFullScreenPreview(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.88),
        transitionDuration: AppConstants.animationNormal,
        reverseTransitionDuration: AppConstants.animationNormal,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Consumer(
              builder: (context, ref, _) {
                final appPrefs = ref.watch(appPreferencesProvider);
                final mode = ref.watch(playerScreenModeProvider);
                return SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _FullScreenPreview(
                          song: ref.watch(currentSongProvider),
                          mode: mode,
                          artworkCardArtworkScale:
                              appPrefs.artworkCardArtworkScale,
                          artworkCardTextScale: appPrefs.artworkCardTextScale,
                          artworkCardVerticalOffset:
                              appPrefs.artworkCardVerticalOffset,
                          artworkCardArtworkOffset:
                              appPrefs.artworkCardArtworkOffset,
                          artworkCardShowTitle: appPrefs.artworkCardShowTitle,
                          artworkCardShowArtist: appPrefs.artworkCardShowArtist,
                          artworkCardShowAlbum: appPrefs.artworkCardShowAlbum,
                          artworkCardShowFileInfo:
                              appPrefs.artworkCardShowFileInfo,
                          artworkCardShowFrame: appPrefs.artworkCardShowFrame,
                          immersiveTextScale: appPrefs.immersiveTextScale,
                          immersiveVerticalOffset:
                              appPrefs.immersiveVerticalOffset,
                          immersiveFullViewScale:
                              appPrefs.immersiveFullViewScale,
                          immersiveShowTitle: appPrefs.immersiveShowTitle,
                          immersiveShowArtist: appPrefs.immersiveShowArtist,
                          immersiveShowFileInfo:
                              appPrefs.immersiveShowFileInfo,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    mode == PlayerScreenMode.immersive
                                        ? Icons.fit_screen_rounded
                                        : Icons.rounded_corner_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    mode.labelFor(l10n.englishForFilipino),
                                    style: TextStyle(
                                      fontFamily: 'GoogleSansFlex',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _fileInfoLabel(Song? song) {
  if (song == null) return '';
  final type = song.fileType;
  final res = song.resolution;
  if (res != null && res.isNotEmpty) return '$type  $res';
  return type;
}

class _LayoutPreview extends StatelessWidget {
  const _LayoutPreview({
    required this.song,
    required this.mode,
    required this.artworkCardArtworkScale,
    required this.artworkCardTextScale,
    required this.artworkCardVerticalOffset,
    required this.artworkCardArtworkOffset,
    required this.artworkCardShowTitle,
    required this.artworkCardShowArtist,
    required this.artworkCardShowAlbum,
    required this.artworkCardShowFileInfo,
    required this.artworkCardShowFrame,
    required this.immersiveTextScale,
    required this.immersiveVerticalOffset,
    required this.immersiveFullViewScale,
    required this.immersiveShowTitle,
    required this.immersiveShowArtist,
    required this.immersiveShowFileInfo,
  });

  final Song? song;
  final PlayerScreenMode mode;
  final double artworkCardArtworkScale;
  final double artworkCardTextScale;
  final double artworkCardVerticalOffset;
  final double artworkCardArtworkOffset;
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFileInfo;
  final bool artworkCardShowFrame;
  final double immersiveTextScale;
  final double immersiveVerticalOffset;
  final double immersiveFullViewScale;
  final bool immersiveShowTitle;
  final bool immersiveShowArtist;
  final bool immersiveShowFileInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.preview_rounded,
                  size: 16,
                  color: context.adaptiveTextTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.englishForFilipino.livePreview,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF232323),
                  Color(0xFF121212),
                  Color(0xFF2A1A3A),
                ],
              ),
            ),
            child: Stack(
              children: [
                if (song == null)
                  Center(
                    child: Text(
                      l10n.noSongPlaying,
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 14,
                        color: Color(0xFF888888),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: mode == PlayerScreenMode.artworkCard
                        ? _buildArtworkCardPreview(context)
                        : _buildImmersivePreview(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkCardPreview(BuildContext context) {
    final artSize = 70.0 * artworkCardArtworkScale;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, artworkCardArtworkOffset * 0.45),
          child: _AlbumArtThumb(song: song, size: artSize, radius: 18),
        ),
        const SizedBox(height: 10),
        Transform.translate(
          offset: Offset(0, artworkCardVerticalOffset * 0.45),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (artworkCardShowTitle)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    song?.title ?? l10n.unknown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 17 * artworkCardTextScale,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (artworkCardShowTitle && artworkCardShowArtist)
                const SizedBox(height: 4),
              if (artworkCardShowArtist)
                Text(
                  song?.artist ?? l10n.unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 12 * artworkCardTextScale,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              if (artworkCardShowAlbum) ...[
                if ((artworkCardShowTitle || artworkCardShowArtist))
                  const SizedBox(height: 2),
                Text(
                  song?.album ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 11 * artworkCardTextScale,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
              if (artworkCardShowFileInfo && song != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _fileInfoLabel(song),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImmersivePreview(BuildContext context) {
    final artSize = 38.0 * immersiveFullViewScale;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.28,
            child: _AlbumArtThumb(
              song: song,
              size: double.infinity,
              radius: 0,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Transform.translate(
            offset: Offset(0, immersiveVerticalOffset * 0.45),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.all(7 * immersiveFullViewScale),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: _AlbumArtThumb(
                    song: song,
                    size: artSize,
                    radius: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (immersiveShowTitle)
                        Text(
                          song?.title ?? l10n.unknown,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 18 * immersiveTextScale,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            color: Colors.white,
                          ),
                        ),
                      if (immersiveShowTitle && immersiveShowArtist)
                        const SizedBox(height: 5),
                      if (immersiveShowArtist)
                        Text(
                          song?.artist ?? l10n.unknownArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 12 * immersiveTextScale,
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                      if (immersiveShowFileInfo && song != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _fileInfoLabel(song),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'GoogleSansFlex',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumArtThumb extends StatelessWidget {
  const _AlbumArtThumb({
    required this.song,
    required this.size,
    required this.radius,
  });

  final Song? song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedImageWidget(
          imagePath: song?.albumArt,
          audioSourcePath: song?.filePath,
          fit: BoxFit.cover,
          placeholder: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4B3D7A), Color(0xFF111111)],
              ),
            ),
            child: const Center(
              child: FlickArtworkPlaceholder(size: 36, opacity: 0.9),
            ),
          ),
          errorWidget: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4B3D7A), Color(0xFF111111)],
              ),
            ),
            child: const Center(
              child: FlickArtworkPlaceholder(size: 36, opacity: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtonPickerScreen extends ConsumerWidget {
  const _ActionButtonPickerScreen({
    required this.title,
    required this.currentValue,
    required this.onSelected,
  });

  final String title;
  final PlayerActionButton currentValue;
  final ValueChanged<PlayerActionButton> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsScaffold(
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.chooseAction),
          SettingsCard(
            children: PlayerActionButton.values.fold<List<Widget>>(
              [],
              (list, action) {
                if (list.isNotEmpty) {
                  list.add(const SettingsDivider());
                }
                list.add(
                  SelectionSetting(
                    icon: action.icon,
                    title: action.labelFor(l10n.englishForFilipino),
                    subtitle: '',
                    selected: action == currentValue,
                    onTap: () {
                      onSelected(action);
                      Navigator.of(context).pop();
                    },
                  ),
                );
                return list;
              },
            ),
          ),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _FullScreenPreview extends StatelessWidget {
  const _FullScreenPreview({
    required this.song,
    required this.mode,
    required this.artworkCardArtworkScale,
    required this.artworkCardTextScale,
    required this.artworkCardVerticalOffset,
    required this.artworkCardArtworkOffset,
    this.artworkCardShowTitle = true,
    this.artworkCardShowArtist = true,
    this.artworkCardShowAlbum = true,
    this.artworkCardShowFileInfo = true,
    this.artworkCardShowFrame = true,
    required this.immersiveTextScale,
    required this.immersiveVerticalOffset,
    required this.immersiveFullViewScale,
    this.immersiveShowTitle = true,
    this.immersiveShowArtist = true,
    this.immersiveShowFileInfo = true,
  });

  final Song? song;
  final PlayerScreenMode mode;
  final double artworkCardArtworkScale;
  final double artworkCardTextScale;
  final double artworkCardVerticalOffset;
  final double artworkCardArtworkOffset;
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFileInfo;
  final bool artworkCardShowFrame;
  final double immersiveTextScale;
  final double immersiveVerticalOffset;
  final double immersiveFullViewScale;
  final bool immersiveShowTitle;
  final bool immersiveShowArtist;
  final bool immersiveShowFileInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF232323),
            AppColors.background,
            AppColors.accent.withValues(alpha: 0.28),
          ],
        ),
      ),
      child: mode == PlayerScreenMode.artworkCard
          ? _buildArtworkCardFullScreen(context)
          : _buildImmersiveFullScreen(context),
    );
  }

  Widget _buildArtworkCardFullScreen(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final artSize =
            (maxWidth * 0.68).clamp(180.0, 380.0) * artworkCardArtworkScale;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, artworkCardArtworkOffset * 1.0),
              child: _AlbumArtThumb(song: song, size: artSize, radius: 28),
            ),
            const SizedBox(height: 24),
            Transform.translate(
              offset: Offset(0, artworkCardVerticalOffset * 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (artworkCardShowTitle)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        song?.title ?? l10n.midnightSignal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlex',
                          fontSize: 28 * artworkCardTextScale,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (artworkCardShowTitle && artworkCardShowArtist)
                    const SizedBox(height: 8),
                  if (artworkCardShowArtist)
                    Text(
                      song?.artist ?? l10n.flickPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 17 * artworkCardTextScale,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  if (artworkCardShowArtist && artworkCardShowAlbum)
                    const SizedBox(height: 6),
                  if (artworkCardShowAlbum)
                    Text(
                      song?.album ?? l10n.mirrorTest,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 14 * artworkCardTextScale,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  if (artworkCardShowFileInfo)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _fileInfoLabel(song),
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlex',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImmersiveFullScreen(BuildContext context) {
    final artSize = 64.0 * immersiveFullViewScale;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.32,
            child: _AlbumArtThumb(
              song: song,
              size: double.infinity,
              radius: 0,
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: Transform.translate(
            offset: Offset(0, immersiveVerticalOffset * 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.all(10 * immersiveFullViewScale),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: _AlbumArtThumb(
                    song: song,
                    size: artSize,
                    radius: 16,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (immersiveShowTitle)
                        Text(
                          song?.title ?? l10n.midnightSignal,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 32 * immersiveTextScale,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            color: Colors.white,
                          ),
                        ),
                      if (immersiveShowTitle && immersiveShowArtist)
                        const SizedBox(height: 8),
                      if (immersiveShowArtist)
                        Text(
                          song?.artist ?? l10n.flickPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 18 * immersiveTextScale,
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                      if (immersiveShowFileInfo)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _fileInfoLabel(song),
                            style: TextStyle(
                              fontFamily: 'GoogleSansFlex',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
