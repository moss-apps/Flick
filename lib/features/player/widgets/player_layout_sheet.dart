import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class PlayerLayoutSheet extends ConsumerStatefulWidget {
  final PlayerService playerService;
  final PlayerScreenMode initialMode;
  final Future<void> Function(PlayerScreenMode) onModeChanged;
  final Song? song;

  const PlayerLayoutSheet({
    super.key,
    required this.playerService,
    required this.initialMode,
    required this.onModeChanged,
    required this.song,
  });

  static Future<void> show(
    BuildContext context, {
    required PlayerService playerService,
    required PlayerScreenMode currentMode,
    required Future<void> Function(PlayerScreenMode) onModeChanged,
    required Song? song,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlayerLayoutSheet(
        playerService: playerService,
        initialMode: currentMode,
        onModeChanged: onModeChanged,
        song: song,
      ),
    );
  }

  @override
  ConsumerState<PlayerLayoutSheet> createState() => _PlayerLayoutSheetState();
}

class _PlayerLayoutSheetState extends ConsumerState<PlayerLayoutSheet> {
  late PlayerScreenMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final colorMode = ref.watch(albumColorModeProvider);
    final appPrefs = ref.watch(appPreferencesProvider);
    final prefsNotifier = ref.read(appPreferencesProvider.notifier);
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.dashboard_customize_rounded,
                    size: 20,
                    color: context.adaptiveTextSecondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Player Layout',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.adaptiveTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => _showFullScreenPreview(),
                child: Stack(
                  children: [
                    _PlayerLayoutPreview(
                      song: widget.playerService.currentSongNotifier.value,
                      mode: _mode,
                      artworkCardArtworkScale:
                          appPrefs.artworkCardArtworkScale,
                      artworkCardTextScale: appPrefs.artworkCardTextScale,
                      artworkCardVerticalOffset:
                          appPrefs.artworkCardVerticalOffset,
                      artworkCardShowTitle: appPrefs.artworkCardShowTitle,
                      artworkCardShowArtist: appPrefs.artworkCardShowArtist,
                      artworkCardShowAlbum: appPrefs.artworkCardShowAlbum,
                      artworkCardShowFrame: appPrefs.artworkCardShowFrame,
                      immersiveTextScale: appPrefs.immersiveTextScale,
                      immersiveVerticalOffset: appPrefs.immersiveVerticalOffset,
                      immersiveFullViewScale: appPrefs.immersiveFullViewScale,
                      immersiveShowTitle: appPrefs.immersiveShowTitle,
                      immersiveShowArtist: appPrefs.immersiveShowArtist,
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
            ),
            const SizedBox(height: 12),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: AppColors.glassBorder,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlayerLayoutOptionTile(
                      title: PlayerScreenMode.immersive.label,
                      subtitle: PlayerScreenMode.immersive.description,
                      icon: Icons.fit_screen_rounded,
                      isSelected: _mode == PlayerScreenMode.immersive,
                      onTap: () {
                        unawaited(widget.onModeChanged(PlayerScreenMode.immersive));
                        setState(() => _mode = PlayerScreenMode.immersive);
                      },
                    ),
                    const SizedBox(height: 12),
                    _PlayerLayoutOptionTile(
                      title: PlayerScreenMode.artworkCard.label,
                      subtitle: PlayerScreenMode.artworkCard.description,
                      icon: Icons.rounded_corner_rounded,
                      isSelected: _mode == PlayerScreenMode.artworkCard,
                      onTap: () {
                        unawaited(widget.onModeChanged(PlayerScreenMode.artworkCard));
                        setState(() => _mode = PlayerScreenMode.artworkCard);
                      },
                    ),
                    const SizedBox(height: 20),
                    _PlayerCustomizationGroup(
                      title: 'Artwork Card',
                      icon: Icons.rounded_corner_rounded,
                      children: [
                        _PlayerCustomizationSlider(
                          title: 'Artwork size',
                          value: appPrefs.artworkCardArtworkScale,
                          min: 0.8,
                          max: 1.36,
                          divisions: 28,
                          valueLabel:
                              '${(appPrefs.artworkCardArtworkScale * 100).round()}%',
                          onChanged: prefsNotifier.setArtworkCardArtworkScale,
                        ),
                        _PlayerCustomizationSlider(
                          title: 'Text size',
                          value: appPrefs.artworkCardTextScale,
                          min: 0.82,
                          max: 1.2,
                          divisions: 19,
                          valueLabel:
                              '${(appPrefs.artworkCardTextScale * 100).round()}%',
                          onChanged: prefsNotifier.setArtworkCardTextScale,
                        ),
                        _PlayerCustomizationSlider(
                          title: 'Content placement',
                          value: appPrefs.artworkCardVerticalOffset,
                          min: -36,
                          max: 36,
                          divisions: 12,
                          valueLabel: _placementLabel(
                            appPrefs.artworkCardVerticalOffset,
                          ),
                          onChanged: prefsNotifier.setArtworkCardVerticalOffset,
                        ),
                        const SizedBox(height: 6),
                        _PlayerCustomizationToggle(
                          title: 'Show title',
                          value: appPrefs.artworkCardShowTitle,
                          onChanged: prefsNotifier.setArtworkCardShowTitle,
                        ),
                        _PlayerCustomizationToggle(
                          title: 'Show artist',
                          value: appPrefs.artworkCardShowArtist,
                          onChanged: prefsNotifier.setArtworkCardShowArtist,
                        ),
                        _PlayerCustomizationToggle(
                          title: 'Show album',
                          value: appPrefs.artworkCardShowAlbum,
                          onChanged: prefsNotifier.setArtworkCardShowAlbum,
                        ),
                        _PlayerCustomizationToggle(
                          title: 'Show file info',
                          value: appPrefs.artworkCardShowFileInfo,
                          onChanged: prefsNotifier.setArtworkCardShowFileInfo,
                        ),
                        _PlayerCustomizationToggle(
                          title: 'Show frame',
                          value: appPrefs.artworkCardShowFrame,
                          onChanged: prefsNotifier.setArtworkCardShowFrame,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PlayerCustomizationGroup(
                      title: 'Immersive',
                      icon: Icons.fit_screen_rounded,
                      children: [
                        _PlayerCustomizationSlider(
                          title: 'Text size',
                          value: appPrefs.immersiveTextScale,
                          min: 0.82,
                          max: 1.2,
                          divisions: 19,
                          valueLabel:
                              '${(appPrefs.immersiveTextScale * 100).round()}%',
                          onChanged: prefsNotifier.setImmersiveTextScale,
                        ),
                        _PlayerCustomizationSlider(
                          title: 'Text placement',
                          value: appPrefs.immersiveVerticalOffset,
                          min: -36,
                          max: 36,
                          divisions: 12,
                          valueLabel: _placementLabel(
                            appPrefs.immersiveVerticalOffset,
                          ),
                          onChanged: prefsNotifier.setImmersiveVerticalOffset,
                        ),
                        _PlayerCustomizationSlider(
                          title: 'Full-view card size',
                          value: appPrefs.immersiveFullViewScale,
                          min: 0.82,
                          max: 1.18,
                          divisions: 18,
                          valueLabel:
                              '${(appPrefs.immersiveFullViewScale * 100).round()}%',
                          onChanged: prefsNotifier.setImmersiveFullViewScale,
                        ),
                        const SizedBox(height: 6),
                        _PlayerCustomizationToggle(
                          title: 'Show title',
                          value: appPrefs.immersiveShowTitle,
                          onChanged: prefsNotifier.setImmersiveShowTitle,
                        ),
                        _PlayerCustomizationToggle(
                          title: 'Show artist',
                          value: appPrefs.immersiveShowArtist,
                          onChanged: prefsNotifier.setImmersiveShowArtist,
                        ),
                        _PlayerCustomizationToggle(
                          title: 'Show file info',
                          value: appPrefs.immersiveShowFileInfo,
                          onChanged: prefsNotifier.setImmersiveShowFileInfo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PlayerCustomizationGroup(
                      title: 'Quick Actions',
                      icon: Icons.swap_horiz_rounded,
                      children: [
                        _PlayerActionButtonSelector(
                          label: 'Left button',
                          currentValue: PlayerActionButtonX.fromStorageValue(
                            appPrefs.leftActionButton,
                          ),
                          onChanged: (action) {
                            prefsNotifier.setLeftActionButton(
                              action.storageValue,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _PlayerActionButtonSelector(
                          label: 'Right button',
                          currentValue: PlayerActionButtonX.fromStorageValue(
                            appPrefs.rightActionButton,
                          ),
                          onChanged: (action) {
                            prefsNotifier.setRightActionButton(
                              action.storageValue,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 20,
                          color: context.adaptiveTextSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Album Colors',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AlbumColorMode.values.map((mode) {
                        final isSelected = colorMode == mode;
                        return GestureDetector(
                          onTap: () {
                            ref
                                .read(albumColorModeProvider.notifier)
                                .setMode(mode);
                          },
                          child: AnimatedContainer(
                            duration: AppConstants.animationFast,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.14)
                                  : AppColors.glassBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent.withValues(alpha: 0.6)
                                    : AppColors.glassBorder,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontFamily: 'ProductSans',
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : context.adaptiveTextSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPreview() {
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
                return SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _FullScreenPreview(
                          song: widget.playerService.currentSongNotifier.value,
                          mode: _mode,
                          artworkCardArtworkScale:
                              appPrefs.artworkCardArtworkScale,
                          artworkCardTextScale: appPrefs.artworkCardTextScale,
                          artworkCardVerticalOffset:
                              appPrefs.artworkCardVerticalOffset,
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
                                    _mode == PlayerScreenMode.immersive
                                        ? Icons.fit_screen_rounded
                                        : Icons.rounded_corner_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _mode.label,
                                    style: TextStyle(
                                      fontFamily: 'ProductSans',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.72),
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

String _placementLabel(double value) {
  if (value == 0) return 'Center';
  return value < 0 ? '${value.abs().round()} up' : '${value.round()} down';
}
class _PlayerLayoutOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayerLayoutOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.14)
                : AppColors.surfaceLight,
            border: Border.all(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : AppColors.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppColors.accent
                      : context.adaptiveTextSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.adaptiveTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 13,
                        height: 1.4,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.circle_outlined,
                color: isSelected
                    ? AppColors.accent
                    : context.adaptiveTextTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerCustomizationGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _PlayerCustomizationGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.adaptiveTextSecondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PlayerCustomizationToggle extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PlayerCustomizationToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _PlayerCustomizationSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _PlayerCustomizationSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 12,
                  color: context.adaptiveTextSecondary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.glassBorder,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerLayoutPreview extends StatelessWidget {
  final Song? song;
  final PlayerScreenMode mode;
  final double artworkCardArtworkScale;
  final double artworkCardTextScale;
  final double artworkCardVerticalOffset;
  final bool artworkCardShowTitle;
  final bool artworkCardShowArtist;
  final bool artworkCardShowAlbum;
  final bool artworkCardShowFrame;
  final double immersiveTextScale;
  final double immersiveVerticalOffset;
  final double immersiveFullViewScale;
  final bool immersiveShowTitle;
  final bool immersiveShowArtist;

  const _PlayerLayoutPreview({
    required this.song,
    required this.mode,
    required this.artworkCardArtworkScale,
    required this.artworkCardTextScale,
    required this.artworkCardVerticalOffset,
    this.artworkCardShowTitle = true,
    this.artworkCardShowArtist = true,
    this.artworkCardShowAlbum = true,
    this.artworkCardShowFrame = true,
    required this.immersiveTextScale,
    required this.immersiveVerticalOffset,
    required this.immersiveFullViewScale,
    this.immersiveShowTitle = true,
    this.immersiveShowArtist = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 180,
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 14,
              child: Text(
                'Sample preview',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ),
            Positioned.fill(
              top: 28,
              child: mode == PlayerScreenMode.artworkCard
                  ? _buildArtworkCardPreview(context)
                  : _buildImmersivePreview(context),
            ),
          ],
        ),
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
          _PreviewAlbumArt(song: song, size: artSize, radius: 18),
          const SizedBox(height: 12),
          if (artworkCardShowTitle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                song?.title ?? 'Midnight Signal',
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
              song?.artist ?? 'Flick Preview',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 12 * artworkCardTextScale,
                color: Colors.white.withValues(alpha: 0.72),
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
            child: _PreviewAlbumArt(
              song: song,
              size: double.infinity,
              radius: 0,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
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
                          song?.title ?? 'Midnight Signal',
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
                          song?.artist ?? 'Flick Preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 12 * immersiveTextScale,
                            color: Colors.white.withValues(alpha: 0.76),
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
                  child: _PreviewAlbumArt(
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

class _PreviewAlbumArt extends StatelessWidget {
  final Song? song;
  final double size;
  final double radius;

  const _PreviewAlbumArt({
    required this.song,
    required this.size,
    required this.radius,
  });

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
          placeholder: _buildFallback(),
          errorWidget: _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B3D7A), Color(0xFF111111)],
        ),
      ),
      child: Icon(
        LucideIcons.music,
        color: Colors.white.withValues(alpha: 0.62),
        size: size.isFinite ? math.max(18, size * 0.38) : 64,
      ),
    );
  }
}

class _FullScreenPreview extends StatelessWidget {
  final Song? song;
  final PlayerScreenMode mode;
  final double artworkCardArtworkScale;
  final double artworkCardTextScale;
  final double artworkCardVerticalOffset;
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
    this.artworkCardShowFrame = true,
    required this.immersiveTextScale,
    required this.immersiveVerticalOffset,
    required this.immersiveFullViewScale,
    this.immersiveShowTitle = true,
    this.immersiveShowArtist = true,
    this.immersiveShowFileInfo = true,
  });

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
              _PreviewAlbumArt(song: song, size: artSize, radius: 28),
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
                    'FLAC · 24-bit / 96 kHz',
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
            child: _PreviewAlbumArt(
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
                            'FLAC · 24-bit / 96 kHz',
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
                  child: _PreviewAlbumArt(
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

class _PlayerActionButtonSelector extends StatelessWidget {
  final String label;
  final PlayerActionButton currentValue;
  final ValueChanged<PlayerActionButton> onChanged;

  const _PlayerActionButtonSelector({
    required this.label,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.adaptiveTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PlayerActionButton.values.map((action) {
            final isSelected = action == currentValue;
            return GestureDetector(
              onTap: () => onChanged(action),
              child: AnimatedContainer(
                duration: AppConstants.animationFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.18)
                      : AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : AppColors.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action.icon,
                      size: 14,
                      color: isSelected
                          ? AppColors.accent
                          : context.adaptiveTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      action.label,
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppColors.textPrimary
                            : context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
