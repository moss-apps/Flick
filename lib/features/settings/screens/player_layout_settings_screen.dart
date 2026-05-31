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

String _placementLabel(double value) {
  if (value == 0) return 'Center';
  return value < 0 ? '${value.abs().round()} up' : '${value.round()} down';
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
      title: 'Player Layout',
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
                  artworkCardShowTitle: appPrefs.artworkCardShowTitle,
                  artworkCardShowArtist: appPrefs.artworkCardShowArtist,
                  artworkCardShowAlbum: appPrefs.artworkCardShowAlbum,
                  artworkCardShowFileInfo: appPrefs.artworkCardShowFileInfo,
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
                          'Fullscreen',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
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
          const SettingsSectionHeader('Layout Mode'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: Icons.fit_screen_rounded,
                title: PlayerScreenMode.immersive.label,
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
                title: PlayerScreenMode.artworkCard.label,
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
          const SettingsSectionHeader('Immersive'),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.type,
                title: 'Text Size',
                subtitle: 'Adjust metadata text size in immersive mode',
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
                title: 'Text Placement',
                subtitle: 'Shift metadata text up or down',
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
                title: 'Full-view Card Size',
                subtitle: 'Scale the full-view album art card',
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
                title: 'Show Title',
                subtitle: 'Display the track title in immersive mode',
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
                title: 'Show Artist',
                subtitle: 'Display the artist name in immersive mode',
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
                title: 'Show File Info',
                subtitle: 'Display file format and bitrate in immersive mode',
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
                title: 'Auto Full View',
                subtitle: 'Auto-show full view after inactivity',
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
          const SettingsSectionHeader('Artwork Card'),
          SettingsCard(
            children: [
              SliderSetting(
                icon: LucideIcons.rectangleHorizontal,
                title: 'Artwork Size',
                subtitle: 'Scale the album art card',
                value: appPrefs.artworkCardArtworkScale,
                displayValue: _percentLabel(appPrefs.artworkCardArtworkScale),
                min: 0.8,
                max: 1.18,
                divisions: 19,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardArtworkScale(value);
                },
              ),
              const SettingsDivider(),
              SliderSetting(
                icon: LucideIcons.type,
                title: 'Text Size',
                subtitle: 'Adjust metadata text size in artwork card mode',
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
                title: 'Content Placement',
                subtitle: 'Shift the card and text up or down',
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
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: 'Show Title',
                subtitle: 'Display the track title in artwork card mode',
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
                title: 'Show Artist',
                subtitle: 'Display the artist name in artwork card mode',
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
                title: 'Show Album',
                subtitle: 'Display the album name in artwork card mode',
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
                title: 'Show File Info',
                subtitle:
                    'Display file format and bitrate in artwork card mode',
                value: appPrefs.artworkCardShowFileInfo,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setArtworkCardShowFileInfo(value);
                },
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.shieldCheck,
                title: 'Bit-Perfect Capsule',
                subtitle:
                    'Replace album name with a verified bit-perfect capsule '
                    'when streaming bit-perfect',
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
          const SettingsSectionHeader('Quick Actions'),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: Icons.arrow_back_rounded,
                title: 'Left Button',
                subtitle: PlayerActionButtonX.fromStorageValue(
                  appPrefs.leftActionButton,
                ).label,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ActionButtonPickerScreen(
                        title: 'Left Button',
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
                icon: Icons.arrow_forward_rounded,
                title: 'Right Button',
                subtitle: PlayerActionButtonX.fromStorageValue(
                  appPrefs.rightActionButton,
                ).label,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ActionButtonPickerScreen(
                        title: 'Right Button',
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
                          artworkCardShowTitle: appPrefs.artworkCardShowTitle,
                          artworkCardShowArtist: appPrefs.artworkCardShowArtist,
                          artworkCardShowAlbum: appPrefs.artworkCardShowAlbum,
                          artworkCardShowFileInfo:
                              appPrefs.artworkCardShowFileInfo,
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
                                    mode.label,
                                    style: TextStyle(
                                      fontFamily: 'ProductSans',
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
    required this.artworkCardShowTitle,
    required this.artworkCardShowArtist,
    required this.artworkCardShowAlbum,
    required this.artworkCardShowFileInfo,
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
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFileInfo;
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
                  'Live Preview',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
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
                  const Center(
                    child: Text(
                      'No song playing',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
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
    return Transform.translate(
      offset: Offset(0, artworkCardVerticalOffset * 0.45),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AlbumArtThumb(song: song, size: artSize, radius: 18),
          const SizedBox(height: 10),
          if (artworkCardShowTitle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                song?.title ?? 'Unknown',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ProductSans',
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
              song?.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ProductSans',
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
                fontFamily: 'ProductSans',
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
                  fontFamily: 'ProductSans',
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ),
        ],
      ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (immersiveShowTitle)
                        Text(
                          song?.title ?? 'Unknown',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
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
                          song?.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
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
                              fontFamily: 'ProductSans',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
            child: const Icon(
              Icons.music_note_rounded,
              color: Color(0xFF555555),
              size: 32,
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
            child: const Icon(
              Icons.music_note_rounded,
              color: Color(0xFF555555),
              size: 32,
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
          const SettingsSectionHeader('Choose Action'),
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
                    title: action.label,
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
    this.artworkCardShowTitle = true,
    this.artworkCardShowArtist = true,
    this.artworkCardShowAlbum = true,
    this.artworkCardShowFileInfo = true,
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
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFileInfo;
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
        return Transform.translate(
          offset: Offset(0, artworkCardVerticalOffset * 1.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AlbumArtThumb(song: song, size: artSize, radius: 28),
              const SizedBox(height: 24),
              if (artworkCardShowTitle)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    song?.title ?? 'Midnight Signal',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
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
                  song?.artist ?? 'Flick Preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 17 * artworkCardTextScale,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              if (artworkCardShowArtist && artworkCardShowAlbum)
                const SizedBox(height: 6),
              if (artworkCardShowAlbum)
                Text(
                  song?.album ?? 'Mirror Test',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
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
                      fontFamily: 'ProductSans',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (immersiveShowTitle)
                        Text(
                          song?.title ?? 'Midnight Signal',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
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
                          song?.artist ?? 'Flick Preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
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
                              fontFamily: 'ProductSans',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
