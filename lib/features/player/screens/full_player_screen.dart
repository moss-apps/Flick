import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/navigation_helper.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/albums/screens/album_detail_screen.dart';
import 'package:flick/features/artists/screens/artist_detail_screen.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/features/player/widgets/share/share_bottom_sheet.dart';
import 'package:flick/features/songs/screens/metadata_editor_screen.dart';
import 'package:flick/features/songs/widgets/album_art_picker_bottom_sheet.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/external_playback_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/providers/rating_provider.dart';
import 'package:flick/providers/songs_provider.dart';
import 'package:flick/features/player/widgets/rating_button.dart';
import 'package:flick/services/player_screen_mode_preference_service.dart';
import 'package:flick/providers/album_color_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/features/player/widgets/bit_perfect_capsule.dart';
import 'package:flick/features/player/widgets/bit_perfect_indicator.dart';
import 'package:flick/features/player/widgets/lyrics_editor_bottom_sheet.dart';
import 'package:flick/features/player/widgets/online_lyrics_search_sheet.dart';
import 'package:flick/features/player/widgets/line_seek_bar.dart';
import 'package:flick/features/player/widgets/waveform_seek_bar.dart';
import 'package:flick/models/progress_bar_style.dart';
import 'package:flick/providers/progress_bar_style_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/widgets/uac2/uac2_error_notification.dart';
import 'package:flick/widgets/uac2/iso_volume_popup.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/providers/providers.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  final Object heroTag;
  const FullPlayerScreen({super.key, this.heroTag = 'album_art_hero'});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with TickerProviderStateMixin {
  final PlayerService _playerService = PlayerService();
  final ExternalPlaybackService _externalPlaybackService =
      ExternalPlaybackService();
  final FavoritesService _favoritesService = FavoritesService();
  final LyricsService _lyricsService = LyricsService();
  final PlayerScreenModePreferenceService _playerScreenModePreferenceService =
      PlayerScreenModePreferenceService();
  final SongRepository _songRepository = SongRepository();
  static const String _topBarTextFontFamily = 'ProductSans';
  static const FontWeight _topBarTextFontWeight = FontWeight.w500;

  // Animation controller for drag offset (replaces setState)
  late AnimationController _dragController;

  // Track current drag offset (updated directly, no setState)
  double _dragOffset = 0.0;

  // Last drag update time for throttling
  DateTime _lastDragUpdate = DateTime.now();

  // Notifier for throttled position – only _WaveformLayer listens, so no setState needed.
  late final ValueNotifier<Duration> _throttledPositionNotifier;
  Timer? _positionThrottleTimer;
  String? _cachedTopBarText;
  double? _cachedTopBarFontSize;
  double _cachedTopBarTextWidth = 0;
  bool _isLyricsMode = false;
  bool _isVisualizationMode = false;
  bool _isImmersiveFullView = false;
  int _songTransitionDirection = 1;
  PlayerScreenMode _playerScreenMode = PlayerScreenMode.immersive;
  int _immersiveAutoFullViewDelaySeconds = 0;
  Timer? _immersiveFullViewTimer;
  final GlobalKey _usbVolumeButtonKey = GlobalKey();
  VoidCallback? _dismissVolumePopup;

  @override
  void initState() {
    super.initState();
    _immersiveAutoFullViewDelaySeconds = ref
        .read(appPreferencesProvider)
        .immersiveAutoFullViewSeconds;

    // Initialize drag animation controller for smooth return animation
    _dragController = AnimationController(
      vsync: this,
      duration: AppConstants.animationFast,
      lowerBound: 0.0,
      upperBound: 1000.0, // Max drag distance
    );
    _dragController.value = 0.0;

    // Initialize notifier with current position
    _throttledPositionNotifier = ValueNotifier(
      _playerService.positionNotifier.value,
    );
    // Throttled position tick: only mutates the notifier – never calls setState.
    _positionThrottleTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (mounted) {
        final newPosition = _playerService.positionNotifier.value;
        if (_throttledPositionNotifier.value != newPosition) {
          _throttledPositionNotifier.value = newPosition;
        }
      }
    });

    _playerService.currentSongNotifier.addListener(_handleCurrentSongChanged);
    _playerService.favoriteNotificationToggleNotifier.addListener(
      _handleFavoriteToggledFromNotification,
    );
    _updateTopBarTextMeasurement(_playerService.currentSongNotifier.value);
    _loadPlayerScreenMode();
    _refreshImmersiveFullViewTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTopBarTextMeasurement(_playerService.currentSongNotifier.value);
  }

  @override
  void dispose() {
    _playerService.currentSongNotifier.removeListener(
      _handleCurrentSongChanged,
    );
    _playerService.favoriteNotificationToggleNotifier.removeListener(
      _handleFavoriteToggledFromNotification,
    );
    _positionThrottleTimer?.cancel();
    _immersiveFullViewTimer?.cancel();
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    _throttledPositionNotifier.dispose();
    _dragController.dispose();
    super.dispose();
  }

  void _handleCurrentSongChanged() {
    if (_playerService.currentSongNotifier.value == null) {
      return;
    }
    if (_isImmersiveFullView) {
      setState(() {
        _isImmersiveFullView = false;
      });
    }
    _updateTopBarTextMeasurement(_playerService.currentSongNotifier.value);
    _refreshImmersiveFullViewTimer();
  }

  void _handleFavoriteToggledFromNotification() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPlayerScreenMode() async {
    final mode = await _playerScreenModePreferenceService.getMode();
    if (!mounted) return;
    if (_playerScreenMode != mode) {
      setState(() {
        _playerScreenMode = mode;
        if (mode != PlayerScreenMode.immersive) {
          _isImmersiveFullView = false;
        }
      });
    }
    _refreshImmersiveFullViewTimer();
  }

  Future<void> _setPlayerScreenMode(PlayerScreenMode mode) async {
    if (_playerScreenMode == mode) return;
    setState(() {
      _playerScreenMode = mode;
      if (mode != PlayerScreenMode.immersive) {
        _isImmersiveFullView = false;
      }
    });
    _refreshImmersiveFullViewTimer();
    await _playerScreenModePreferenceService.setMode(mode);
  }

  bool get _canUseImmersiveFullView =>
      _playerScreenMode == PlayerScreenMode.immersive && !_isLyricsMode;

  void _refreshImmersiveFullViewTimer() {
    _immersiveFullViewTimer?.cancel();
    if (!_canUseImmersiveFullView ||
        _isImmersiveFullView ||
        _immersiveAutoFullViewDelaySeconds <= 0) {
      return;
    }

    _immersiveFullViewTimer = Timer(
      Duration(seconds: _immersiveAutoFullViewDelaySeconds),
      () {
        if (!mounted || !_canUseImmersiveFullView || _isImmersiveFullView) {
          return;
        }
        setState(() {
          _isImmersiveFullView = true;
        });
      },
    );
  }

  void _setImmersiveAutoFullViewDelaySeconds(int value) {
    if (_immersiveAutoFullViewDelaySeconds == value) return;
    _immersiveAutoFullViewDelaySeconds = value;
    _refreshImmersiveFullViewTimer();
  }

  void _setLyricsMode(bool value) {
    final nextVisualizationMode = value ? false : _isVisualizationMode;
    final nextImmersiveFullView = value ? false : _isImmersiveFullView;
    if (_isLyricsMode == value &&
        _isVisualizationMode == nextVisualizationMode &&
        _isImmersiveFullView == nextImmersiveFullView) {
      return;
    }

    setState(() {
      _isLyricsMode = value;
      _isVisualizationMode = nextVisualizationMode;
      _isImmersiveFullView = nextImmersiveFullView;
    });
    _refreshImmersiveFullViewTimer();
  }

  void _setVisualizationMode(bool value) {
    final nextLyricsMode = value ? false : _isLyricsMode;
    if (_isVisualizationMode == value && _isLyricsMode == nextLyricsMode) {
      return;
    }

    setState(() {
      _isVisualizationMode = value;
      _isLyricsMode = nextLyricsMode;
    });
    _refreshImmersiveFullViewTimer();
  }

  void _handleImmersiveSceneTap() {
    if (_playerScreenMode != PlayerScreenMode.immersive) return;
    if (_isLyricsMode) return;

    setState(() {
      _isImmersiveFullView = !_isImmersiveFullView;
    });
    _refreshImmersiveFullViewTimer();
  }

  Future<void> _animateToNextSong() async {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    _songTransitionDirection = 1;
    await _playerService.next();
  }

  Future<void> _animateToPreviousSong() async {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    _songTransitionDirection = -1;
    await _playerService.previous();
  }

  void _updateTopBarTextMeasurement(Song? song) {
    if (!mounted || song == null) return;

    final text = '${song.title} - ${song.artist}';
    final fontSize = context.responsiveText(
      context.responsive(13.0, 14.0, 15.0),
    );

    if (_cachedTopBarText == text && _cachedTopBarFontSize == fontSize) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _topBarTextFontFamily,
          fontSize: fontSize,
          fontWeight: _topBarTextFontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    _cachedTopBarText = text;
    _cachedTopBarFontSize = fontSize;
    _cachedTopBarTextWidth = textPainter.width;
  }

  // For nice time formatting (h:mm:ss or mm:ss)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showSpeedBottomSheet(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.gauge,
                  color: AppColors.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Playback Speed',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<double>(
              valueListenable: _playerService.playbackSpeedNotifier,
              builder: (context, currentSpeed, _) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: speeds.map((speed) {
                    final isSelected = speed == currentSpeed;
                    return GestureDetector(
                      onTap: () {
                        _playerService.setPlaybackSpeed(speed);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: AppConstants.animationFast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.glassBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.glassBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerBottomSheet(BuildContext context) {
    final timerOptions = [
      (const Duration(minutes: 15), '15 min'),
      (const Duration(minutes: 30), '30 min'),
      (const Duration(minutes: 45), '45 min'),
      (const Duration(hours: 1), '1 hour'),
      (const Duration(hours: 2), '2 hours'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.moonStar,
                      color: AppColors.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sleep Timer',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (_playerService.isSleepTimerActive)
                  TextButton(
                    onPressed: () {
                      _playerService.cancelSleepTimer();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel Timer',
                      style: TextStyle(
                        fontFamily: 'ProductSans',
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Duration?>(
              valueListenable: _playerService.sleepTimerRemainingNotifier,
              builder: (context, remaining, _) {
                if (remaining != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.timer,
                            color: AppColors.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stopping in ${_formatDuration(remaining)}',
                            style: const TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 14,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: timerOptions.map((option) {
                return GestureDetector(
                  onTap: () {
                    _playerService.setSleepTimer(option.$1);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      option.$2,
                      style: const TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPlayerLayoutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Consumer(
          builder: (context, ref, _) {
            final colorMode = ref.watch(albumColorModeProvider);
            final appPrefs = ref.watch(appPreferencesProvider);
            final prefsNotifier = ref.read(appPreferencesProvider.notifier);
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
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
                            color: sheetContext.adaptiveTextSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Player Layout',
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: sheetContext.adaptiveTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => _showFullScreenPreview(sheetContext),
                        child: Stack(
                          children: [
                            _PlayerLayoutPreview(
                              song: _playerService.currentSongNotifier.value,
                              mode: _playerScreenMode,
                              artworkCardArtworkScale:
                                  appPrefs.artworkCardArtworkScale,
                              artworkCardTextScale:
                                  appPrefs.artworkCardTextScale,
                              artworkCardVerticalOffset:
                                  appPrefs.artworkCardVerticalOffset,
                              artworkCardShowTitle:
                                  appPrefs.artworkCardShowTitle,
                              artworkCardShowArtist:
                                  appPrefs.artworkCardShowArtist,
                              artworkCardShowAlbum:
                                  appPrefs.artworkCardShowAlbum,
                              immersiveTextScale: appPrefs.immersiveTextScale,
                              immersiveVerticalOffset:
                                  appPrefs.immersiveVerticalOffset,
                              immersiveFullViewScale:
                                  appPrefs.immersiveFullViewScale,
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
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Fullscreen',
                                      style: TextStyle(
                                        fontFamily: 'ProductSans',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(
                                          alpha: 0.86,
                                        ),
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
                              isSelected:
                                  _playerScreenMode ==
                                  PlayerScreenMode.immersive,
                              onTap: () {
                                unawaited(
                                  _setPlayerScreenMode(
                                    PlayerScreenMode.immersive,
                                  ),
                                );
                                setSheetState(() {});
                              },
                            ),
                            const SizedBox(height: 12),
                            _PlayerLayoutOptionTile(
                              title: PlayerScreenMode.artworkCard.label,
                              subtitle:
                                  PlayerScreenMode.artworkCard.description,
                              icon: Icons.rounded_corner_rounded,
                              isSelected:
                                  _playerScreenMode ==
                                  PlayerScreenMode.artworkCard,
                              onTap: () {
                                unawaited(
                                  _setPlayerScreenMode(
                                    PlayerScreenMode.artworkCard,
                                  ),
                                );
                                setSheetState(() {});
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
                                  max: 1.18,
                                  divisions: 19,
                                  valueLabel:
                                      '${(appPrefs.artworkCardArtworkScale * 100).round()}%',
                                  onChanged:
                                      prefsNotifier
                                          .setArtworkCardArtworkScale,
                                ),
                                _PlayerCustomizationSlider(
                                  title: 'Text size',
                                  value: appPrefs.artworkCardTextScale,
                                  min: 0.82,
                                  max: 1.2,
                                  divisions: 19,
                                  valueLabel:
                                      '${(appPrefs.artworkCardTextScale * 100).round()}%',
                                  onChanged:
                                      prefsNotifier.setArtworkCardTextScale,
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
                                  onChanged:
                                      prefsNotifier
                                          .setArtworkCardVerticalOffset,
                                ),
                                const SizedBox(height: 6),
                                _PlayerCustomizationToggle(
                                  title: 'Show title',
                                  value: appPrefs.artworkCardShowTitle,
                                  onChanged:
                                      prefsNotifier.setArtworkCardShowTitle,
                                ),
                                _PlayerCustomizationToggle(
                                  title: 'Show artist',
                                  value: appPrefs.artworkCardShowArtist,
                                  onChanged:
                                      prefsNotifier.setArtworkCardShowArtist,
                                ),
                                _PlayerCustomizationToggle(
                                  title: 'Show album',
                                  value: appPrefs.artworkCardShowAlbum,
                                  onChanged:
                                      prefsNotifier.setArtworkCardShowAlbum,
                                ),
                                _PlayerCustomizationToggle(
                                  title: 'Show file info',
                                  value: appPrefs.artworkCardShowFileInfo,
                                  onChanged:
                                      prefsNotifier.setArtworkCardShowFileInfo,
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
                                  onChanged:
                                      prefsNotifier.setImmersiveTextScale,
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
                                  onChanged:
                                      prefsNotifier
                                          .setImmersiveVerticalOffset,
                                ),
                                _PlayerCustomizationSlider(
                                  title: 'Full-view card size',
                                  value: appPrefs.immersiveFullViewScale,
                                  min: 0.82,
                                  max: 1.18,
                                  divisions: 18,
                                  valueLabel:
                                      '${(appPrefs.immersiveFullViewScale * 100).round()}%',
                                  onChanged:
                                      prefsNotifier.setImmersiveFullViewScale,
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
                                  onChanged:
                                      prefsNotifier.setImmersiveShowArtist,
                                ),
                                _PlayerCustomizationToggle(
                                  title: 'Show file info',
                                  value: appPrefs.immersiveShowFileInfo,
                                  onChanged:
                                      prefsNotifier.setImmersiveShowFileInfo,
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
                                  currentValue:
                                      PlayerActionButtonX.fromStorageValue(
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
                                  currentValue:
                                      PlayerActionButtonX.fromStorageValue(
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
                                  color: sheetContext.adaptiveTextSecondary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Album Colors',
                                  style: TextStyle(
                                    fontFamily: 'ProductSans',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: sheetContext.adaptiveTextPrimary,
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
                                          ? AppColors.accent.withValues(
                                            alpha: 0.14,
                                          )
                                          : AppColors.glassBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.accent.withValues(
                                              alpha: 0.6,
                                            )
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
                                            : sheetContext
                                                .adaptiveTextSecondary,
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
          },
        ),
      ),
    );
  }

  void _showFullScreenPreview(BuildContext context) {
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
                          song: _playerService.currentSongNotifier.value,
                          mode: _playerScreenMode,
                          artworkCardArtworkScale:
                              appPrefs.artworkCardArtworkScale,
                          artworkCardTextScale:
                              appPrefs.artworkCardTextScale,
                          artworkCardVerticalOffset:
                              appPrefs.artworkCardVerticalOffset,
                          artworkCardShowTitle:
                              appPrefs.artworkCardShowTitle,
                          artworkCardShowArtist:
                              appPrefs.artworkCardShowArtist,
                          artworkCardShowAlbum:
                              appPrefs.artworkCardShowAlbum,
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
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _playerScreenMode ==
                                            PlayerScreenMode.immersive
                                        ? Icons.fit_screen_rounded
                                        : Icons.rounded_corner_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _playerScreenMode.label,
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
                                    color: Colors.white.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: Colors.white.withValues(
                                      alpha: 0.7,
                                    ),
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

  String _placementLabel(double value) {
    if (value == 0) return 'Center';
    return value < 0 ? '${value.abs().round()} up' : '${value.round()} down';
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.listPlus,
                  color: AppColors.accent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Add to Playlist',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) {
                final playlistsAsync = ref.watch(playlistsProvider);
                return playlistsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Error loading playlists',
                    style: TextStyle(color: context.adaptiveTextTertiary),
                  ),
                  data: (state) {
                    if (state.playlists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No playlists yet.\nCreate one in the Playlists tab.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.adaptiveTextTertiary,
                              fontFamily: 'ProductSans',
                            ),
                          ),
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = state.playlists[index];
                          final isAlreadyAdded = playlist.songIds.contains(
                            song.id,
                          );
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.music,
                                color: context.adaptiveTextSecondary,
                              ),
                            ),
                            title: Text(
                              playlist.name,
                              style: TextStyle(
                                color: context.adaptiveTextPrimary,
                                fontFamily: 'ProductSans',
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.songIds.length} songs',
                              style: TextStyle(
                                color: context.adaptiveTextTertiary,
                                fontFamily: 'ProductSans',
                              ),
                            ),
                            trailing: isAlreadyAdded
                                ? Icon(
                                    LucideIcons.check,
                                    color: AppColors.accent,
                                  )
                                : null,
                            onTap: isAlreadyAdded
                                ? null
                                : () async {
                                    await ref
                                        .read(playlistsProvider.notifier)
                                        .addSongToPlaylist(
                                          playlist.id,
                                          song.id,
                                          song: song,
                                        );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added to "${playlist.name}"',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _queueSong(BuildContext context, Song song) async {
    await _playerService.addToQueue(song);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Queued "${song.title}"'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View queue',
          onPressed: () {
            NavigationHelper.navigateToQueue(context);
          },
        ),
      ),
    );
  }

  Future<void> _openQueue(BuildContext context) async {
    await NavigationHelper.navigateToQueue(context);
  }

  void _showSongActionsBottomSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.glassBorder),
          ),
          padding: EdgeInsets.fromLTRB(
            context.responsive(16.0, 18.0, 20.0),
            context.responsive(10.0, 11.0, 12.0),
            context.responsive(16.0, 18.0, 20.0),
            context.responsive(20.0, 22.0, 24.0),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      context.responsive(10.0, 11.0, 12.0),
                    ),
                    child: SizedBox(
                      width: context.responsive(56.0, 62.0, 68.0),
                      height: context.responsive(56.0, 62.0, 68.0),
                      child: CachedImageWidget(
                        imagePath: song.albumArt,
                        audioSourcePath: song.filePath,
                        fit: BoxFit.cover,
                        useThumbnail: true,
                        thumbnailWidth: 136,
                        thumbnailHeight: 136,
                        placeholder: Container(
                          color: AppColors.surfaceLight,
                          child: const Icon(
                            LucideIcons.music,
                            color: AppColors.textTertiary,
                            size: 24,
                          ),
                        ),
                        errorWidget: Container(
                          color: AppColors.surfaceLight,
                          child: const Icon(
                            LucideIcons.music,
                            color: AppColors.textTertiary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsive(16.0, 17.0, 18.0),
                            fontWeight: FontWeight.w600,
                            color: sheetContext.adaptiveTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsive(12.0, 13.0, 14.0),
                            color: sheetContext.adaptiveTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSongInfoChip(
                              sheetContext,
                              song.formattedDuration,
                            ),
                            _buildSongInfoChip(
                              sheetContext,
                              song.fileType.toUpperCase(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!song.isFromLocker)
                _buildSongActionTile(
                  context: sheetContext,
                  icon: LucideIcons.listPlus,
                  label: 'Add to Queue',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _queueSong(context, song);
                  },
                ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.listMusic,
                label: 'Add to Playlist',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddToPlaylistDialog(context, song);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.image,
                label: 'Set Album Art',
                onTap: () {
                  Navigator.pop(sheetContext);
                  unawaited(
                    Future<void>.delayed(
                      Duration.zero,
                      () => AlbumArtPickerBottomSheet.show(context, song),
                    ),
                  );
                },
              ),
              if (song.filePath != null &&
                  song.startOffsetMs == null &&
                  !song.isExternal)
                _buildSongActionTile(
                  context: sheetContext,
                  icon: LucideIcons.pencil,
                  label: 'Edit Metadata',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => MetadataEditorScreen(song: song),
                      ),
                    ).then((saved) {
                      if (saved == true) {
                        ref.invalidate(songsProvider);
                      }
                    });
                  },
                ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.info,
                label: 'View Metadata',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSongMetadataBottomSheet(context, song);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.fileText,
                label: 'Lyrics',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setLyricsMode(true);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: Icons.graphic_eq_rounded,
                label: _isVisualizationMode ? 'Hide Visualizer' : 'Visualizer',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setVisualizationMode(!_isVisualizationMode);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.user,
                label: 'Go to Artist',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openArtistFromSong(context, song);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.disc,
                label: 'Go to Album',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAlbumFromSong(context, song);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: Icons.dashboard_customize_rounded,
                label: 'Player Layout',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showPlayerLayoutBottomSheet(context);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.gauge,
                label: 'Playback Speed',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSpeedBottomSheet(context);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.moonStar,
                label: 'Sleep Timer',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSleepTimerBottomSheet(context);
                },
              ),
              _buildSongActionTile(
                context: sheetContext,
                icon: LucideIcons.share2,
                label: 'Share',
                onTap: () {
                  Navigator.pop(sheetContext);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => ShareBottomSheet(song: song),
                  );
                },
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfoChip(BuildContext context, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(8.0, 9.0, 10.0),
        vertical: context.responsive(3.0, 3.5, 4.0),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(context.responsive(6.0, 7.0, 8.0)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: context.responsive(10.0, 11.0, 12.0),
          fontWeight: FontWeight.w600,
          color: context.adaptiveTextSecondary,
        ),
      ),
    );
  }

  Widget _buildSongActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final iconSize = context.responsive(16.0, 17.0, 18.0);
    final containerSize = context.responsive(30.0, 32.0, 34.0);
    final borderRadius = context.responsive(8.0, 9.0, 10.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          context.responsive(10.0, 11.0, 12.0),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.responsive(10.0, 11.0, 12.0),
          ),
          child: Row(
            children: [
              Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: context.adaptiveTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsive(13.0, 14.0, 15.0),
                    fontWeight: FontWeight.w500,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: context.responsive(14.0, 15.0, 16.0),
                color: context.adaptiveTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongMetadataBottomSheet(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 20,
                  color: sheetContext.adaptiveTextSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Song Metadata',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: sheetContext.adaptiveTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetadataRow(sheetContext, 'Title', song.title),
            _buildMetadataRow(sheetContext, 'Artist', song.artist),
            if (song.album != null)
              _buildMetadataRow(sheetContext, 'Album', song.album!),
            _buildMetadataRow(sheetContext, 'Duration', song.formattedDuration),
            _buildMetadataRow(
              sheetContext,
              'Format',
              song.isDsd ? '${song.fileType.toUpperCase()} (${song.dsdRateLabel})' : song.fileType.toUpperCase(),
            ),
            if (song.resolution != null && !song.isDsd)
              _buildMetadataRow(sheetContext, 'Resolution', song.resolution!),
            if (song.albumArtist != null)
              _buildMetadataRow(sheetContext, 'Album Artist', song.albumArtist!),
            if (song.genre != null)
              _buildMetadataRow(sheetContext, 'Genre', song.genre!),
            if (song.year != null)
              _buildMetadataRow(sheetContext, 'Year', song.year!.toString()),
            if (song.trackNumber != null)
              _buildMetadataRow(sheetContext, 'Track', song.trackNumber!.toString()),
            if (song.discNumber != null)
              _buildMetadataRow(sheetContext, 'Disc', song.discNumber!.toString()),
            if (song.filePath != null)
              _buildMetadataRow(sheetContext, 'File Path', song.filePath!),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 13,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openArtistFromSong(BuildContext context, Song song) async {
    final artistName = song.artist.trim();
    if (artistName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artist is not available for this song')),
      );
      return;
    }

    final artistMap = await _songRepository.getSongsByArtist();
    final artistSongs = artistMap[artistName];
    if (!mounted) return;

    if (artistSongs == null || artistSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load artist songs')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistDetailScreen(
          artistName: artistName,
          songs: artistSongs,
          artistArt: _firstArt(artistSongs),
          artistArtSourcePath: _firstSourcePath(artistSongs),
          playerService: _playerService,
        ),
      ),
    );
  }

  Future<void> _openAlbumFromSong(BuildContext context, Song song) async {
    final albumGroup = await _songRepository.getAlbumGroupForSong(song);
    if (!mounted) return;

    if (albumGroup == null || albumGroup.songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load album songs')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(
          albumName: albumGroup.albumName,
          albumArtist: albumGroup.albumArtist,
          songs: albumGroup.songs,
          albumArt: _firstArt(albumGroup.songs),
          albumArtSourcePath: _firstSourcePath(albumGroup.songs),
          playerService: _playerService,
        ),
      ),
    );
  }

  String? _firstArt(List<Song> songs) {
    for (final item in songs) {
      final art = item.albumArt;
      if (art != null && art.isNotEmpty) {
        return art;
      }
    }
    return null;
  }

  String? _firstSourcePath(List<Song> songs) {
    for (final item in songs) {
      final filePath = item.filePath;
      if (filePath != null && filePath.isNotEmpty) {
        return filePath;
      }
    }
    return null;
  }

  Widget _buildPlayerBadge(BuildContext context, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(4.0, 5.0, 6.0),
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: context.responsive(9.0, 10.0, 11.0),
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFileInfoRow(
    BuildContext context,
    Song song, {
    required bool lyricsMode,
    required PlayerScreenMode playerScreenMode,
    Color? albumColor,
    AlbumColorMode albumColorMode = AlbumColorMode.off,
    PlayerActionButton leftAction = PlayerActionButton.lyrics,
    PlayerActionButton rightAction = PlayerActionButton.favorites,
  }) {
    final immersiveActions = playerScreenMode == PlayerScreenMode.immersive;
    final actionPadding = immersiveActions
        ? EdgeInsets.all(context.responsive(8.0, 9.0, 10.0))
        : EdgeInsets.all(context.responsive(6.0, 7.0, 8.0));
    final actionRadius = immersiveActions ? 12.0 : 10.0;
    final actionIconSize = context.responsive(18.0, 20.0, 22.0);

    final accentBlend = albumColorMode.accentBlend;
    final surfaceBlend = albumColorMode.surfaceBlend;
    final hasAlbumTint = albumColor != null && accentBlend > 0;

    final inactiveBg = hasAlbumTint
        ? _AnimatedSongScene.albumSurface(
            albumColor,
            surfaceBlend,
          ).withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.15);
    final inactiveBorder = hasAlbumTint
        ? _AnimatedSongScene.albumSurface(
            albumColor,
            surfaceBlend,
          ).withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(
          context: context,
          song: song,
          action: leftAction,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
          immersiveActions: immersiveActions,
          lyricsMode: lyricsMode,
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerBadge(context, song.fileType.toUpperCase()),
              if (song.isDsd && song.dsdRateLabel.isNotEmpty) ...[
                SizedBox(width: context.responsive(5.0, 6.0, 7.0)),
                Flexible(
                  child: Text(
                    song.dsdRateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsive(9.0, 10.0, 11.0),
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ] else if (song.resolution != null) ...[
                SizedBox(width: context.responsive(5.0, 6.0, 7.0)),
                Flexible(
                  child: Text(
                    song.resolution!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsive(9.0, 10.0, 11.0),
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
              SizedBox(width: context.responsive(5.0, 6.0, 7.0)),
              BitPerfectIndicator(
                song: song,
                playerService: _playerService,
                onTap: () {
                  final diagnostics = ref.read(audioOutputDiagnosticsProvider);
                  final deviceStatus = ref.read(uac2DeviceStatusProvider);
                  BitPerfectIndicator.showInfoSheet(
                    context,
                    song: song,
                    diagnostics: diagnostics,
                    deviceStatus: deviceStatus,
                    playerService: _playerService,
                  );
                },
              ),
            ],
          ),
        ),
        _buildActionButton(
          context: context,
          song: song,
          action: rightAction,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
          immersiveActions: immersiveActions,
          lyricsMode: lyricsMode,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Song song,
    required PlayerActionButton action,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
    required bool immersiveActions,
    required bool lyricsMode,
  }) {
    switch (action) {
      case PlayerActionButton.lyrics:
        return _buildLyricsButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
          lyricsMode: lyricsMode,
        );
      case PlayerActionButton.favorites:
        if (song.isExternal) {
          return SizedBox(
            width: actionIconSize + actionPadding.horizontal,
            height: actionIconSize + actionPadding.vertical,
          );
        }
        return _buildFavoritesButton(
          song: song,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
        );
      case PlayerActionButton.visualizer:
        return _buildVisualizerButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
        );
      case PlayerActionButton.ratings:
        if (song.isExternal) {
          return SizedBox(
            width: actionIconSize + actionPadding.horizontal,
            height: actionIconSize + actionPadding.vertical,
          );
        }
        return _buildRatingsButton(
          song: song,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
        );
      case PlayerActionButton.queue:
        return _buildQueueButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
          albumColor: albumColor,
          accentBlend: accentBlend,
          hasAlbumTint: hasAlbumTint,
        );
      case PlayerActionButton.sleepTimer:
        return _buildSleepTimerButton(
          context: context,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
      case PlayerActionButton.share:
        return _buildShareButton(
          song: song,
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
      case PlayerActionButton.usbVolume:
        return _buildUsbVolumeButton(
          actionPadding: actionPadding,
          actionRadius: actionRadius,
          actionIconSize: actionIconSize,
          inactiveBg: inactiveBg,
          inactiveBorder: inactiveBorder,
        );
    }
  }

  Widget _buildLyricsButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
    required bool lyricsMode,
  }) {
    final lyricsActiveBg = hasAlbumTint
        ? _AnimatedSongScene.albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.28)
        : AppColors.accent.withValues(alpha: 0.28);
    final lyricsActiveBorder = hasAlbumTint
        ? _AnimatedSongScene.albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.45)
        : AppColors.accent.withValues(alpha: 0.45);

    return Tooltip(
      message: lyricsMode ? 'Hide lyrics' : 'Show lyrics',
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isLyricsMode = !lyricsMode;
          });
        },
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: lyricsMode ? lyricsActiveBg : inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(
              color: lyricsMode ? lyricsActiveBorder : inactiveBorder,
            ),
          ),
          child: Icon(
            lyricsMode
                ? Icons.keyboard_arrow_down_rounded
                : LucideIcons.fileText,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesButton({
    required Song song,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
  }) {
    return FutureBuilder<bool>(
      future: _favoritesService.isFavorite(song.id),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data ?? false;
        return GestureDetector(
          onTap: () async {
            final newState = await _favoritesService.toggleFavorite(
              song.id,
            );
            setState(() {});
            _playerService.refreshNotificationState();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newState
                        ? 'Added to favorites'
                        : 'Removed from favorites',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          child: Container(
            padding: actionPadding,
            decoration: BoxDecoration(
              color: isFavorite
                  ? (hasAlbumTint
                        ? _AnimatedSongScene.albumAccent(
                            albumColor!,
                            accentBlend,
                          ).withValues(alpha: 0.25)
                        : Colors.red.withValues(alpha: 0.25))
                  : inactiveBg,
              borderRadius: BorderRadius.circular(actionRadius),
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite
                  ? (hasAlbumTint
                        ? _AnimatedSongScene.albumAccent(
                            albumColor!,
                            accentBlend,
                          )
                        : Colors.red)
                  : Colors.white.withValues(alpha: 0.9),
              size: actionIconSize,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisualizerButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
  }) {
    final isVisMode = _isVisualizationMode;
    final visActiveBg = hasAlbumTint
        ? _AnimatedSongScene.albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.28)
        : AppColors.accent.withValues(alpha: 0.28);
    final visActiveBorder = hasAlbumTint
        ? _AnimatedSongScene.albumAccent(
            albumColor!,
            accentBlend,
          ).withValues(alpha: 0.45)
        : AppColors.accent.withValues(alpha: 0.45);

    return Tooltip(
      message: isVisMode ? 'Hide visualizer' : 'Show visualizer',
      child: GestureDetector(
        onTap: () => _setVisualizationMode(!isVisMode),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: isVisMode ? visActiveBg : inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(
              color: isVisMode ? visActiveBorder : inactiveBorder,
            ),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsButton({
    required Song song,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
  }) {
    final ratings = ref.watch(ratingProvider);
    final currentRating = ratings[song.id] ?? 0;

    return RatingButton(
      currentRating: currentRating,
      onRatingChanged: (rating) {
        if (rating == 0) {
          ref.read(ratingProvider.notifier).removeRating(song.id);
        } else {
          ref.read(ratingProvider.notifier).setRating(song.id, rating);
        }
        setState(() {});
      },
      iconSize: actionIconSize,
      padding: actionPadding,
      borderRadius: actionRadius,
      albumColor: albumColor,
      accentBlend: accentBlend,
      inactiveBg: inactiveBg,
      inactiveBorder: inactiveBorder,
    );
  }

  Widget _buildQueueButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
    required Color? albumColor,
    required double accentBlend,
    required bool hasAlbumTint,
  }) {
    return Tooltip(
      message: 'Queue',
      child: GestureDetector(
        onTap: () => _openQueue(context),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.listMusic,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimerButton({
    required BuildContext context,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    return Tooltip(
      message: 'Sleep timer',
      child: GestureDetector(
        onTap: () => _showSleepTimerBottomSheet(context),
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.moonStar,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required Song song,
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    return Tooltip(
      message: 'Share',
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => ShareBottomSheet(song: song),
          );
        },
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.share2,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildUsbVolumeButton({
    required EdgeInsets actionPadding,
    required double actionRadius,
    required double actionIconSize,
    required Color inactiveBg,
    required Color inactiveBorder,
  }) {
    final enginePref = ref.watch(audioEnginePreferenceProvider);
    final isIsochronous = enginePref.when(
      data: (e) => e == AudioEnginePreference.isochronousUsb,
      loading: () => false,
      error: (_, _) => false,
    );

    if (!isIsochronous) {
      return SizedBox(
        width: actionIconSize + actionPadding.horizontal,
        height: actionIconSize + actionPadding.vertical,
      );
    }

    return Tooltip(
      message: 'USB Volume',
      child: GestureDetector(
        key: _usbVolumeButtonKey,
        onTap: () {
          _dismissVolumePopup?.call();
          _dismissVolumePopup = showIsoVolumePopup(context, _usbVolumeButtonKey);
        },
        child: Container(
          padding: actionPadding,
          decoration: BoxDecoration(
            color: inactiveBg,
            borderRadius: BorderRadius.circular(actionRadius),
            border: Border.all(color: inactiveBorder),
          ),
          child: Icon(
            LucideIcons.volume2,
            color: Colors.white.withValues(alpha: 0.96),
            size: actionIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectoryInfo(
    BuildContext context,
    Song song, {
    required bool compact,
  }) {
    if (song.filePath == null) return const SizedBox.shrink();
    if (song.isFromLocker) {
      return Padding(
        padding: EdgeInsets.only(
          left: context.responsive(12.0, 16.0, 20.0),
          right: context.responsive(12.0, 16.0, 20.0),
          top: compact ? context.responsive(8.0, 10.0, 12.0) : 0,
          bottom: compact ? 0 : context.responsive(16.0, 20.0, 24.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.lock,
              size: context.responsive(11.0, 12.0, 13.0),
              color: Colors.white.withValues(alpha: 0.7),
            ),
            SizedBox(width: context.responsive(4.0, 5.0, 6.0)),
            Text(
              'Opened from Locker',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsive(10.0, 11.0, 12.0),
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
          ],
        ),
      );
    }
    if (song.isExternal) return const SizedBox.shrink();

    String dirText = '';
    final filePath = song.filePath!;
    final parts = filePath.split(RegExp(r'[/\\]'));
    if (parts.length > 1) {
      parts.removeLast();
      final startIndex = parts.length > 2 ? parts.length - 2 : 0;
      final folders = parts.sublist(startIndex);
      dirText = folders.join('/');
    }
    if (dirText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: context.responsive(12.0, 16.0, 20.0),
        right: context.responsive(12.0, 16.0, 20.0),
        top: compact ? context.responsive(8.0, 10.0, 12.0) : 0,
        bottom: compact ? 0 : context.responsive(16.0, 20.0, 24.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.folder,
            size: context.responsive(11.0, 12.0, 13.0),
            color: Colors.white.withValues(alpha: 0.7),
          ),
          SizedBox(width: context.responsive(4.0, 5.0, 6.0)),
          Flexible(
            child: Text(
              dirText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsive(10.0, 11.0, 12.0),
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appPreferencesProvider, (previous, next) {
      _setImmersiveAutoFullViewDelaySeconds(next.immersiveAutoFullViewSeconds);
    });

    final appPrefs = ref.watch(appPreferencesProvider);
    final visStyle = appPrefs.visualizerAnimationStyle;
    final visFreq = appPrefs.visualizerFrequencyMode;
    final visMove = appPrefs.visualizerMovementMode;

    final colorMode = ref.watch(albumColorModeProvider);
    final dominantColor = ref.watch(albumDominantColorSyncProvider);
    final Color? albumColor =
        (colorMode != AlbumColorMode.off && dominantColor != null)
        ? dominantColor
        : null;

    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ValueListenableBuilder<Song?>(
          valueListenable: _playerService.currentSongNotifier,
          builder: (context, song, _) {
            if (song == null) {
              // Should usually close the screen if song becomes null or error
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pop();
              });
              return const SizedBox.shrink();
            }

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleImmersiveSceneTap,
              onVerticalDragStart: (_) {
                _dragController.stop();
              },
              onVerticalDragUpdate: (details) {
                // Only track downward drag
                if (details.delta.dy > 0) {
                  // Throttle updates to every 16ms (~60fps) to avoid excessive updates
                  final now = DateTime.now();
                  if (now.difference(_lastDragUpdate).inMilliseconds < 16) {
                    return;
                  }
                  _lastDragUpdate = now;

                  // Update drag offset directly (no setState)
                  _dragOffset = (_dragOffset + details.delta.dy).clamp(
                    0.0,
                    1000.0,
                  );
                  // Update controller value for AnimatedBuilder
                  _dragController.value = _dragOffset;
                }
              },
              onVerticalDragEnd: (details) {
                // If dragged down enough or with enough velocity, dismiss
                if (_dragOffset > 100 || details.primaryVelocity! > 500) {
                  _dismissVolumePopup?.call();
                  _dismissVolumePopup = null;
                  Navigator.of(context).pop();
                  return;
                }

                // Animate back to 0
                _dragOffset = 0.0;
                _dragController.animateTo(0.0);
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -500) {
                  // Swipe Left -> Next
                  _animateToNextSong();
                } else if (details.primaryVelocity! > 500) {
                  // Swipe Right -> Previous
                  _animateToPreviousSong();
                }
              },
              child: AnimatedBuilder(
                animation: _dragController,
                builder: (context, child) {
                  // Use Transform.translate during drag (lightweight)
                  // Only use animation when releasing
                  final offset = _dragController.value * 0.5;
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child!,
                  );
                },
                child: _AnimatedSongScene(
                  song: song,
                  lyricsMode: _isLyricsMode,
                  visualizationMode: _isVisualizationMode,
                  immersiveFullView: _isImmersiveFullView,
                  playerScreenMode: _playerScreenMode,
                  albumColorMode: colorMode,
                  albumColor: albumColor,
                  transitionDirection: _songTransitionDirection,
                  topBarTextFontFamily: _topBarTextFontFamily,
                  topBarTextFontWeight: _topBarTextFontWeight,
                  cachedTopBarTextWidth: _cachedTopBarTextWidth,
                  playerService: _playerService,
                  lyricsService: _lyricsService,
                  throttledPositionNotifier: _throttledPositionNotifier,
                  formatDuration: _formatDuration,
                  onClose: () {
                    _dismissVolumePopup?.call();
                    _dismissVolumePopup = null;
                    Navigator.of(context).pop();
                  },
                  onOpenQueue: () => _openQueue(context),
                  onToggleLyrics: () => _setLyricsMode(!_isLyricsMode),
                  onQueueSwipe: () => _queueSong(context, song),
                  onReturnToLocker: () async {
                    final returned = await _externalPlaybackService
                        .returnToLocker();
                    if (!returned && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  onShowSongActions: () =>
                      _showSongActionsBottomSheet(context, song),
                  onPrevious: _animateToPreviousSong,
                  onNext: _animateToNextSong,
                  onNavigateToArtistDetail: (song) => _openArtistFromSong(context, song),
                  onNavigateToAlbumDetail: (song) => _openAlbumFromSong(context, song),
                  buildFileInfoRow: (song, lyricsMode, mode) =>
                      _buildFileInfoRow(
                        context,
                        song,
                        lyricsMode: lyricsMode,
                        playerScreenMode: mode,
                        albumColor: albumColor,
                        albumColorMode: colorMode,
                        leftAction: PlayerActionButtonX.fromStorageValue(appPrefs.leftActionButton),
                        rightAction: PlayerActionButtonX.fromStorageValue(appPrefs.rightActionButton),
                      ),
                  buildDirectoryInfo: (song) =>
                      _buildDirectoryInfo(context, song, compact: false),
                  visualizerAnimationStyle: visStyle,
                  visualizerFrequencyMode: visFreq,
                  visualizerMovementMode: visMove,
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
                  hideQueueBadge: PlayerActionButtonX.fromStorageValue(appPrefs.leftActionButton) == PlayerActionButton.queue ||
                      PlayerActionButtonX.fromStorageValue(appPrefs.rightActionButton) == PlayerActionButton.queue,
                 ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedSongScene extends StatelessWidget {
  final Song song;
  final bool lyricsMode;
  final bool visualizationMode;
  final bool immersiveFullView;
  final PlayerScreenMode playerScreenMode;
  final AlbumColorMode albumColorMode;
  final Color? albumColor;
  final int transitionDirection;

  static const Color _darkBase = Color(0xFF121212);

  /// Tinted surface for button/container backgrounds.
  static Color albumSurface(Color albumColor, double blend) =>
      Color.lerp(_darkBase, albumColor, blend)!;

  /// Tinted accent for active states — lighter, slightly desaturated.
  static Color albumAccent(Color albumColor, double blend) {
    final hsl = HSLColor.fromColor(albumColor);
    return hsl
        .withSaturation((hsl.saturation * 0.7).clamp(0.3, 0.8))
        .withLightness(0.65)
        .toColor()
        .withValues(alpha: (blend + 0.3).clamp(0.0, 1.0));
  }

  final String topBarTextFontFamily;
  final FontWeight topBarTextFontWeight;
  final double cachedTopBarTextWidth;
  final PlayerService playerService;
  final LyricsService lyricsService;
  final ValueNotifier<Duration> throttledPositionNotifier;
  final String Function(Duration) formatDuration;
  final VoidCallback onClose;
  final VoidCallback onOpenQueue;
  final VoidCallback onToggleLyrics;
  final Future<void> Function() onQueueSwipe;
  final Future<void> Function() onReturnToLocker;
  final VoidCallback onShowSongActions;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final void Function(Song song) onNavigateToArtistDetail;
  final void Function(Song song) onNavigateToAlbumDetail;
  final Widget Function(Song song, bool lyricsMode, PlayerScreenMode mode)
  buildFileInfoRow;
  final Widget Function(Song song) buildDirectoryInfo;
  final String visualizerAnimationStyle;
  final String visualizerFrequencyMode;
  final String visualizerMovementMode;
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
  final bool hideQueueBadge;

  const _AnimatedSongScene({
    required this.song,
    required this.lyricsMode,
    required this.visualizationMode,
    required this.immersiveFullView,
    required this.playerScreenMode,
    required this.albumColorMode,
    this.albumColor,
    required this.transitionDirection,
    required this.topBarTextFontFamily,
    required this.topBarTextFontWeight,
    required this.cachedTopBarTextWidth,
    required this.playerService,
    required this.lyricsService,
    required this.throttledPositionNotifier,
    required this.formatDuration,
    required this.onClose,
    required this.onOpenQueue,
    required this.onToggleLyrics,
    required this.onQueueSwipe,
    required this.onReturnToLocker,
    required this.onShowSongActions,
    required this.onPrevious,
    required this.onNext,
    required this.onNavigateToArtistDetail,
    required this.onNavigateToAlbumDetail,
    required this.buildFileInfoRow,
    required this.buildDirectoryInfo,
    this.visualizerAnimationStyle = 'bars',
    this.visualizerFrequencyMode = 'full',
    this.visualizerMovementMode = 'bouncy',
    this.artworkCardArtworkScale = 1.0,
    this.artworkCardTextScale = 1.0,
    this.artworkCardVerticalOffset = 0.0,
    this.artworkCardShowTitle = true,
    this.artworkCardShowArtist = true,
    this.artworkCardShowAlbum = true,
    this.artworkCardShowFileInfo = true,
    this.immersiveTextScale = 1.0,
    this.immersiveVerticalOffset = 0.0,
    this.immersiveFullViewScale = 1.0,
    this.immersiveShowTitle = true,
    this.immersiveShowArtist = true,
    this.immersiveShowFileInfo = true,
    this.hideQueueBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final direction = transitionDirection >= 0 ? 1.0 : -1.0;
    final sceneKey = ValueKey('${song.id}_${playerScreenMode.storageValue}');
    final showVisualizerOnly =
        visualizationMode &&
        immersiveFullView &&
        playerScreenMode == PlayerScreenMode.immersive;
    final showImmersiveFullView =
        immersiveFullView && playerScreenMode == PlayerScreenMode.immersive;

    final scene = RepaintBoundary(
      key: sceneKey,
      child: Stack(
        children: [
          Positioned.fill(child: _buildBackground(context)),
          AnimatedSwitcher(
            duration: AppConstants.animationNormal,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isFullView =
                  child.key == const ValueKey('immersive-full-view');
              final slideOffset = isFullView
                  ? const Offset(0, 0.12)
                  : const Offset(0, 0.03);
              return SlideTransition(
                position: Tween<Offset>(begin: slideOffset, end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: showVisualizerOnly
                ? const KeyedSubtree(
                    key: ValueKey('immersive-empty-overlay'),
                    child: SizedBox.shrink(),
                  )
                : showImmersiveFullView
                ? KeyedSubtree(
                    key: const ValueKey('immersive-full-view'),
                    child: SafeArea(
                      child: _buildImmersiveFullViewLayout(context),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('immersive-default-layout'),
                    child: SafeArea(
                      child: Column(
                        children: [
                          const Uac2ErrorNotification(),
                          _buildTopChrome(context),
                          SizedBox(height: context.responsive(8.0, 10.0, 12.0)),
                          Expanded(
                            child:
                                playerScreenMode == PlayerScreenMode.artworkCard
                                ? _buildArtworkCardLayout(context)
                                : _buildImmersiveLayout(context),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    if (AppConstants.animationNormal == Duration.zero) {
      return scene;
    }

    return AnimatedSwitcher(
      duration: AppConstants.animationNormal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ...?currentChild == null ? null : [currentChild],
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final offsetAnimation =
            Tween<Offset>(
              begin: Offset(direction * 0.4, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final outgoingOffsetAnimation =
            Tween<Offset>(
              begin: Offset(-direction * 0.4, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInCubic),
            );
        final isIncoming = child.key == sceneKey;

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: isIncoming ? offsetAnimation : outgoingOffsetAnimation,
            child: child,
          ),
        );
      },
      child: scene,
    );
  }

  Widget _buildBackground(BuildContext context) {
    final bgBlend = albumColorMode.backgroundBlend;
    final hasAlbumTint = albumColor != null && bgBlend > 0;

    if (visualizationMode && playerScreenMode != PlayerScreenMode.artworkCard) {
      final overlayColor = hasAlbumTint
          ? albumSurface(albumColor!, bgBlend * 0.5)
          : const Color(0xFF0A0A0A);
      return Stack(
        children: [
          Positioned.fill(
            child: AudioVisualizer(
              playerService: playerService,
              animationStyle: visualizerAnimationStyle,
              frequencyMode: visualizerFrequencyMode,
              movementMode: visualizerMovementMode,
              albumColor: albumColor,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    overlayColor.withValues(alpha: 0.7),
                    overlayColor.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.transparent,
                    overlayColor.withValues(alpha: 0.3),
                    overlayColor.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.12, 0.28, 0.62, 0.82, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (playerScreenMode == PlayerScreenMode.artworkCard) {
      return Stack(
        children: [
          Positioned.fill(
            child: (song.albumArt != null || song.filePath != null)
                ? AmbientBackground(song: song)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF181818), AppColors.background],
                      ),
                    ),
                    child: Icon(
                      LucideIcons.music,
                      size: 120,
                      color: AppColors.textTertiary.withValues(alpha: 0.2),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (hasAlbumTint
                            ? albumSurface(albumColor!, bgBlend)
                            : const Color(0xFF080808))
                        .withValues(alpha: 0.5),
                    (hasAlbumTint
                            ? albumSurface(albumColor!, bgBlend * 0.6)
                            : const Color(0xFF0E0E0E))
                        .withValues(alpha: 0.32),
                    (hasAlbumTint
                            ? albumSurface(albumColor!, bgBlend)
                            : const Color(0xFF0A0A0A))
                        .withValues(alpha: 0.94),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Immersive mode: full-bleed album art with dark gradient overlay
    final gradientBase = hasAlbumTint
        ? albumSurface(albumColor!, bgBlend)
        : const Color(0xFF121212);

    final gradientColors = immersiveFullView
        ? [
            gradientBase.withValues(alpha: 0.3),
            gradientBase.withValues(alpha: 0.25),
            gradientBase.withValues(alpha: 0.2),
            gradientBase.withValues(alpha: 0.15),
            gradientBase.withValues(alpha: 0.08),
            Colors.transparent,
          ]
        : [
            gradientBase,
            gradientBase.withValues(alpha: 0.95),
            gradientBase.withValues(alpha: 0.85),
            gradientBase.withValues(alpha: 0.6),
            gradientBase.withValues(alpha: 0.3),
            Colors.transparent,
          ];

    return Stack(
      children: [
        Positioned.fill(
          child: CachedImageWidget(
            imagePath: song.albumArt,
            audioSourcePath: song.filePath,
            fit: BoxFit.cover,
            placeholder: Container(
              color: AppColors.background,
              child: Icon(
                LucideIcons.music,
                size: 120,
                color: AppColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
            errorWidget: Container(
              color: AppColors.background,
              child: Icon(
                LucideIcons.music,
                size: 120,
                color: AppColors.textTertiary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedContainer(
            duration: AppConstants.animationNormal,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: gradientColors,
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopChrome(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(8.0, 12.0, 16.0),
        vertical: context.responsive(4.0, 6.0, 8.0),
      ),
      child: Row(
        children: [
          _buildChromeButton(
            context,
            icon: LucideIcons.chevronDown,
            onTap: onClose,
          ),
          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
          Expanded(
            child: GestureDetector(
              onTap: song.isFromLocker ? null : onOpenQueue,
              onHorizontalDragEnd: song.isFromLocker
                  ? null
                  : (details) async {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -400) {
                        await onQueueSwipe();
                      }
                    },
              child: ValueListenableBuilder<List<Song>>(
                valueListenable: playerService.upNextNotifier,
                builder: (context, upNext, _) {
                  final hasQueue = upNext.isNotEmpty;
                  final fromLocker = song.isFromLocker;
                  final nowPlayingContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: context.responsive(12.0, 13.0, 14.0),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (fromLocker) ...[
                        SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
                        Text(
                          'Opened from Locker',
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsive(10.0, 10.5, 11.0),
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  );

                  final chip = AnimatedContainer(
                    duration: AppConstants.animationFast,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsive(12.0, 14.0, 16.0),
                      vertical: context.responsive(6.0, 7.0, 8.0),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasQueue
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        nowPlayingContent,
                        if (!fromLocker && !hideQueueBadge) ...[
                          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
                          _buildQueueSummaryBadge(
                            context,
                            count: upNext.length,
                            highlighted: hasQueue,
                          ),
                        ],
                      ],
                    ),
                  );

                  return Align(
                    alignment: Alignment.center,
                    widthFactor: 1.0,
                    child: chip,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.isFromLocker) ...[
                _buildReturnToLockerButton(context),
                SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
              ],
              _buildChromeButton(
                context,
                icon: Icons.more_vert,
                onTap: onShowSongActions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnToLockerButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(onReturnToLocker());
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsive(12.0, 14.0, 16.0),
          vertical: context.responsive(10.0, 11.0, 12.0),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF121212).withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.undo2,
              size: context.responsive(14.0, 15.0, 16.0),
              color: Colors.white.withValues(alpha: 0.9),
            ),
            SizedBox(width: context.responsive(6.0, 7.0, 8.0)),
            Text(
              'Back to Locker',
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsive(11.0, 12.0, 13.0),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueSummaryBadge(
    BuildContext context, {
    required int count,
    required bool highlighted,
  }) {
    return AnimatedContainer(
      duration: AppConstants.animationFast,
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(8.0, 9.0, 10.0),
        vertical: context.responsive(3.0, 4.0, 5.0),
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.listMusic,
            size: context.responsive(12.0, 13.0, 14.0),
            color: Colors.white.withValues(alpha: highlighted ? 0.96 : 0.7),
          ),
          SizedBox(width: context.responsive(4.0, 5.0, 6.0)),
          Text(
            count > 0 ? 'Queue $count' : 'Queue',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: context.responsive(10.0, 11.0, 12.0),
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: highlighted ? 0.96 : 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChromeButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final surfaceColor = albumColor != null
        ? albumSurface(albumColor!, albumColorMode.surfaceBlend)
        : const Color(0xFF121212);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: AppHaptics.wrap(onTap),
        padding: EdgeInsets.all(context.responsive(8.0, 10.0, 12.0)),
        constraints: const BoxConstraints(),
        icon: Icon(
          icon,
          color: Colors.white,
          size: context.responsive(20.0, 22.0, 24.0),
        ),
      ),
    );
  }

  Widget _buildImmersiveLayout(BuildContext context) {
    final layout = lyricsMode
        ? KeyedSubtree(
            key: const ValueKey('immersive-lyrics-layout'),
            child: Column(
              children: [
                SizedBox(height: context.responsive(8.0, 10.0, 12.0)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsive(20.0, 28.0, 36.0),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _InlineLyricsPanel(
                            song: song,
                            playerService: playerService,
                            lyricsService: lyricsService,
                            albumColor: albumColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.responsive(10.0, 12.0, 14.0)),
                _LyricsModeWaveformStrip(
                  playerService: playerService,
                  positionNotifier: throttledPositionNotifier,
                  currentSong: song,
                  formatDuration: formatDuration,
                  horizontalPadding: context.responsive(18.0, 24.0, 30.0),
                  onSwipeUp: onToggleLyrics,
                ),
              ],
            ),
          )
        : KeyedSubtree(
            key: const ValueKey('immersive-default-layout'),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Transform.translate(
                  offset: Offset(0, immersiveVerticalOffset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.responsive(12.0, 16.0, 20.0),
                        ),
                        child: _buildImmersiveSongHeader(context),
                      ),
                      if (immersiveShowFileInfo) ...[
                        Builder(builder: (context) {
                          final diagnostics =
                              ProviderScope.containerOf(context)
                                  .read(audioOutputDiagnosticsProvider);
                          final appPrefs = ProviderScope.containerOf(context)
                              .read(appPreferencesProvider);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (diagnostics != null &&
                                  appPrefs.replaceAlbumWithBitPerfectCapsule) ...[
                                SizedBox(
                                    height: context.responsive(6.0, 8.0, 10.0)),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: context.responsive(
                                          12.0, 16.0, 20.0)),
                                  child: BitPerfectCapsule(
                                    diagnostics: diagnostics,
                                    horizontalPadding:
                                        context.responsive(12.0, 14.0, 16.0),
                                    verticalPadding:
                                        context.responsive(4.0, 5.0, 6.0),
                                    fontSize:
                                        context.responsive(11.0, 12.0, 13.0),
                                    onTap: () {
                                      final deviceStatus =
                                          ProviderScope.containerOf(context)
                                              .read(uac2DeviceStatusProvider);
                                      BitPerfectIndicator.showInfoSheet(
                                        context,
                                        song: song,
                                        diagnostics: diagnostics,
                                        deviceStatus: deviceStatus,
                                        playerService: playerService,
                                      );
                                    },
                                  ),
                                ),
                              ],
                              SizedBox(
                                  height: context.responsive(10.0, 12.0, 14.0)),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      context.responsive(12.0, 16.0, 20.0),
                                ),
                                child: buildFileInfoRow(
                                  song,
                                  lyricsMode,
                                  playerScreenMode,
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: context.responsive(12.0, 14.0, 16.0)),
                _buildPlaybackStack(context),
                SizedBox(height: context.responsive(24.0, 32.0, 40.0)),
              ],
            ),
          );

    if (AppConstants.animationNormal == Duration.zero) {
      return layout;
    }

    return AnimatedSwitcher(
      duration: AppConstants.animationNormal,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ...?currentChild == null ? null : [currentChild],
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isLyricsChild =
            child.key == const ValueKey('immersive-lyrics-layout');
        final offsetAnimation = Tween<Offset>(
          begin: isLyricsChild ? const Offset(0, -0.04) : const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: layout,
    );
  }

  Widget _buildImmersiveFullViewLayout(BuildContext context) {
    final artworkSize =
        context.responsive(56.0, 60.0, 64.0) * immersiveFullViewScale;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.responsive(16.0, 20.0, 24.0),
          0,
          context.responsive(16.0, 20.0, 24.0),
          context.responsive(20.0, 24.0, 28.0),
        ),
        child: Container(
          padding: EdgeInsets.all(
            context.responsive(10.0, 12.0, 14.0) * immersiveFullViewScale,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  18 * immersiveFullViewScale,
                ),
                child: SizedBox(
                  width: artworkSize,
                  height: artworkSize,
                  child: CachedImageWidget(
                    imagePath: song.albumArt,
                    audioSourcePath: song.filePath,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Icon(
                        LucideIcons.music,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: artworkSize * 0.44,
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Icon(
                        LucideIcons.music,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: artworkSize * 0.44,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.responsive(12.0, 14.0, 16.0)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (immersiveShowTitle)
                      Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: context.responsiveText(
                            context.responsive(18.0, 19.0, 21.0) *
                                immersiveTextScale,
                          ),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                    if (immersiveShowTitle && immersiveShowArtist)
                      SizedBox(height: context.responsive(6.0, 7.0, 8.0)),
                    if (immersiveShowArtist)
                      GestureDetector(
                        onTap: () => onNavigateToArtistDetail(song),
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsiveText(
                              context.responsive(13.0, 14.0, 15.0) *
                                  immersiveTextScale,
                            ),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
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
    );
  }

  Widget _buildImmersiveSongHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (immersiveShowTitle)
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsiveText(
                      context.responsive(22.0, 24.0, 28.0) * immersiveTextScale,
                    ),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.08,
                  ),
                ),
              if (immersiveShowTitle && immersiveShowArtist)
                SizedBox(height: context.responsive(10.0, 12.0, 14.0)),
              if (immersiveShowArtist)
                GestureDetector(
                  onTap: () => onNavigateToArtistDetail(song),
                  child: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: context.responsiveText(
                        context.responsive(13.0, 14.0, 16.0) *
                            immersiveTextScale,
                      ),
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              if (immersiveShowTitle || immersiveShowArtist)
                SizedBox(height: context.responsive(10.0, 12.0, 14.0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArtworkCardLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShortHeight = constraints.maxHeight < 620;
        final isVeryShortHeight = constraints.maxHeight < 540;
        final horizontalPadding = constraints.maxWidth < 360
            ? 16.0
            : context.responsive(20.0, 28.0, 36.0);
        final topPadding = isVeryShortHeight
            ? 6.0
            : context.responsive(10.0, 12.0, 16.0);
        final maxArtworkSize = context.responsive(320.0, 360.0, 400.0);
        final baseArtworkSize = math
            .min(
              constraints.maxWidth - (horizontalPadding * 2),
              isVeryShortHeight
                  ? constraints.maxHeight * 0.32
                  : isShortHeight
                  ? constraints.maxHeight * 0.36
                  : constraints.maxHeight * 0.42,
            )
            .clamp(isVeryShortHeight ? 160.0 : 180.0, maxArtworkSize)
            .toDouble();
        final artworkSize = (baseArtworkSize * artworkCardArtworkScale)
            .clamp(
              isVeryShortHeight ? 140.0 : 160.0,
              constraints.maxWidth - (horizontalPadding * 2),
            )
            .toDouble();
        final artworkSpacing = isVeryShortHeight
            ? 12.0
            : isShortHeight
            ? 16.0
            : context.responsive(22.0, 26.0, 30.0);
        final identitySpacing = isVeryShortHeight
            ? 8.0
            : isShortHeight
            ? 12.0
            : context.responsive(18.0, 20.0, 22.0);
        final lyricsSpacing = isVeryShortHeight
            ? 12.0
            : context.responsive(16.0, 18.0, 20.0);
        final playbackSpacing = isVeryShortHeight
            ? 10.0
            : context.responsive(14.0, 16.0, 18.0);
        final directorySpacing = isVeryShortHeight
            ? 12.0
            : isShortHeight
            ? 18.0
            : context.responsive(24.0, 32.0, 40.0);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            0,
          ),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppConstants.animationNormal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        ...?currentChild == null
                            ? null
                            : [currentChild],
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final isLyrics =
                        child.key == const ValueKey('artwork-lyrics');
                    final slide = Tween<Offset>(
                      begin: isLyrics
                          ? const Offset(0, -0.06)
                          : const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: lyricsMode
                      ? Padding(
                          key: const ValueKey('artwork-lyrics'),
                          padding: EdgeInsets.only(bottom: lyricsSpacing),
                          child: _InlineLyricsPanel(
                            song: song,
                            playerService: playerService,
                            lyricsService: lyricsService,
                            albumColor: albumColor,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('artwork-default'),
                          child: Transform.translate(
                            offset: Offset(0, artworkCardVerticalOffset),
                            child: Column(
                              mainAxisAlignment: isVeryShortHeight
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  flex: isVeryShortHeight ? 5 : 7,
                                  child: Center(
                                    child: visualizationMode
                                        ? _VisualizerArtBox(
                                            playerService: playerService,
                                            size: artworkSize,
                                            animationStyle:
                                                visualizerAnimationStyle,
                                            frequencyMode:
                                                visualizerFrequencyMode,
                                            movementMode:
                                                visualizerMovementMode,
                                            albumColor: albumColor,
                                          )
                                        : _AlbumArtBox(
                                            song: song,
                                            size: artworkSize,
                                            playerService: playerService),
                                  ),
                                ),
                                SizedBox(height: artworkSpacing),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        isVeryShortHeight ? 8.0 : 0.0,
                                  ),
                                  child: _buildSongIdentity(
                                    context,
                                    compact: isShortHeight,
                                    veryCompact: isVeryShortHeight,
                                  ),
                                ),
                                SizedBox(height: identitySpacing),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
              if (artworkCardShowFileInfo)
                buildFileInfoRow(song, lyricsMode, playerScreenMode),
              if (artworkCardShowFileInfo)
                SizedBox(height: playbackSpacing),
              _buildPlaybackStack(context),
              SizedBox(height: directorySpacing),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongIdentity(
    BuildContext context, {
    bool compact = false,
    bool veryCompact = false,
  }) {
    final titleSize =
        (veryCompact
            ? context.responsive(20.0, 22.0, 25.0)
            : compact
            ? context.responsive(22.0, 25.0, 28.0)
            : context.responsive(25.0, 27.0, 30.0)) *
        artworkCardTextScale;
    final artistSize =
        (veryCompact
            ? context.responsive(13.0, 14.0, 15.0)
            : compact
            ? context.responsive(14.0, 15.0, 16.0)
            : context.responsive(15.0, 16.0, 17.0)) *
        artworkCardTextScale;
    final titleToArtistSpacing = veryCompact
        ? 6.0
        : context.responsive(8.0, 10.0, 12.0);
    final artistToAlbumSpacing = veryCompact
        ? 8.0
        : compact
        ? 10.0
        : context.responsive(12.0, 14.0, 16.0);
    final albumHorizontalPadding = veryCompact
        ? 10.0
        : context.responsive(12.0, 14.0, 16.0);
    final albumVerticalPadding = veryCompact
        ? 5.0
        : context.responsive(6.0, 7.0, 8.0);
    final albumFontSize =
        (veryCompact
            ? context.responsive(10.0, 11.0, 12.0)
            : context.responsive(11.0, 12.0, 13.0)) *
        artworkCardTextScale;

    final diagnostics =
        ProviderScope.containerOf(context).read(audioOutputDiagnosticsProvider);
    final appPrefs =
        ProviderScope.containerOf(context).read(appPreferencesProvider);
    final isBitPerfectVerified =
        diagnostics?.capabilityFlags.supportsVerifiedBitPerfect == true;
    final showBitPerfectCapsule =
        appPrefs.replaceAlbumWithBitPerfectCapsule &&
            diagnostics != null &&
            isBitPerfectVerified;
    final hasAlbum =
        song.album != null && song.album!.trim().isNotEmpty;

    return Column(
      children: [
        if (artworkCardShowTitle)
          Text(
            song.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: context.responsiveText(titleSize),
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.08,
            ),
          ),
        if (artworkCardShowTitle && artworkCardShowArtist)
          SizedBox(height: titleToArtistSpacing),
        if (artworkCardShowArtist)
          GestureDetector(
            onTap: () => onNavigateToArtistDetail(song),
            child: Text(
              song.artist,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: context.responsiveText(artistSize),
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        if (artworkCardShowAlbum &&
            (artworkCardShowTitle || artworkCardShowArtist) &&
            (hasAlbum || showBitPerfectCapsule)) ...[
          SizedBox(height: artistToAlbumSpacing),
          if (diagnostics != null &&
              appPrefs.replaceAlbumWithBitPerfectCapsule)
            Stack(
              alignment: Alignment.center,
              children: [
                if (hasAlbum)
                  AnimatedOpacity(
                    opacity: isBitPerfectVerified ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: albumHorizontalPadding,
                        vertical: albumVerticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: GestureDetector(
                        onTap: () => onNavigateToAlbumDetail(song),
                        child: Text(
                          song.album!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ProductSans',
                            fontSize: context.responsiveText(albumFontSize),
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                        ),
                      ),
                    ),
                  ),
                BitPerfectCapsule(
                  diagnostics: diagnostics,
                  horizontalPadding: albumHorizontalPadding,
                  verticalPadding: albumVerticalPadding,
                  fontSize: albumFontSize,
                  onTap: () {
                    final deviceStatus =
                        ProviderScope.containerOf(context)
                            .read(uac2DeviceStatusProvider);
                    BitPerfectIndicator.showInfoSheet(
                      context,
                      song: song,
                      diagnostics: diagnostics,
                      deviceStatus: deviceStatus,
                      playerService: playerService,
                    );
                  },
                ),
              ],
            )
          else if (hasAlbum)
            GestureDetector(
              onTap: () => onNavigateToAlbumDetail(song),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: albumHorizontalPadding,
                  vertical: albumVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  song.album!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: context.responsiveText(albumFontSize),
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPlaybackStack(BuildContext context) {
    final immersivePlaybackPadding =
        playerScreenMode == PlayerScreenMode.immersive
        ? context.responsive(18.0, 24.0, 30.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: immersivePlaybackPadding),
          child: _WaveformLayer(
            playerService: playerService,
            positionNotifier: throttledPositionNotifier,
            currentSong: song,
          ),
        ),
        SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
        _PlayerControls(
          playerService: playerService,
          formatDuration: formatDuration,
          currentSong: song,
          isShuffleNotifier: playerService.isShuffleNotifier,
          onPrevious: onPrevious,
          onNext: onNext,
          timelineHorizontalPadding: immersivePlaybackPadding,
          albumColorMode: albumColorMode,
          albumColor: albumColor,
        ),
      ],
    );
  }
}

class _AlbumArtBox extends StatefulWidget {
  final Song song;
  final double? size;
  final PlayerService? playerService;

  const _AlbumArtBox({
    required this.song,
    this.size,
    this.playerService,
  });

  @override
  State<_AlbumArtBox> createState() => _AlbumArtBoxState();
}

class _AlbumArtBoxState extends State<_AlbumArtBox>
    with TickerProviderStateMixin {
  static const double _labelRatio = 0.44;
  static const Duration _spinDuration = Duration(seconds: 4);
  static const Duration _seekAnimationDuration =
      Duration(milliseconds: 450);
  static const int _msPerSeekRevolution = 1500;
  static const int _maxSeekRevolutions = 5;
  static const int _minSeekRevolutions = 1;
  static const int _forwardSeekThresholdMs = 1500;
  static const double _secondsPerVinylRotation = 30.0;

  late final AnimationController _morphController;
  late final AnimationController _spinController;
  late final AnimationController _seekAngleController;
  bool _isVinyl = false;
  Duration _lastObservedPosition = Duration.zero;
  double _userRotationOffset = 0.0;
  bool _isUserDragging = false;
  double _rotationHapticAccumulator = 0.0;
  static const double _hapticTickInterval = math.pi / 12;
  late final TapGestureRecognizer _tapRecognizer;
  late final _RotationSeekRecognizer _rotationRecognizer;

  bool get _isPlaying =>
      widget.playerService?.isPlayingNotifier.value ?? false;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _spinController = AnimationController(
      vsync: this,
      duration: _spinDuration,
    );
    _seekAngleController = AnimationController(
      vsync: this,
      duration: _seekAnimationDuration,
    );
    _morphController.addStatusListener(_handleMorphStatus);
    _tapRecognizer = TapGestureRecognizer()..onTap = _toggle;
    _rotationRecognizer = _RotationSeekRecognizer(
      onStart: _onRotationStart,
      onUpdate: _onRotationUpdate,
      onEnd: _onRotationEnd,
      discCenter: () => Offset.zero, // Will be set in build
    );
    final service = widget.playerService;
    if (service != null) {
      _lastObservedPosition = service.positionNotifier.value;
      service.positionNotifier.addListener(_onPositionChanged);
      service.isPlayingNotifier.addListener(_onPlayingChanged);
    }
  }

  @override
  void didUpdateWidget(covariant _AlbumArtBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _lastObservedPosition = Duration.zero;
      _seekAngleController.stop();
      _seekAngleController.value = 0;
      _userRotationOffset = 0.0;
      _isUserDragging = false;
      if (_isVinyl) {
        _isVinyl = false;
        _spinController.stop();
        _spinController.value = 0;
        _morphController.value = 0;
      }
    }
    if (oldWidget.playerService != widget.playerService) {
      oldWidget.playerService?.positionNotifier
          .removeListener(_onPositionChanged);
      oldWidget.playerService?.isPlayingNotifier
          .removeListener(_onPlayingChanged);
      final service = widget.playerService;
      if (service != null) {
        _lastObservedPosition = service.positionNotifier.value;
        service.positionNotifier.addListener(_onPositionChanged);
        service.isPlayingNotifier.addListener(_onPlayingChanged);
      } else {
        _lastObservedPosition = Duration.zero;
      }
    }
  }

  @override
  void dispose() {
    _morphController.removeStatusListener(_handleMorphStatus);
    widget.playerService?.positionNotifier.removeListener(_onPositionChanged);
    widget.playerService?.isPlayingNotifier.removeListener(_onPlayingChanged);
    _tapRecognizer.dispose();
    _rotationRecognizer.dispose();
    _seekAngleController.dispose();
    _spinController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  void _onPlayingChanged() {
    if (!mounted) return;
    if (!_isVinyl) return;
    if (_isUserDragging) return;
    if (_isPlaying) {
      _startSpinning();
    } else {
      _spinController.stop();
    }
  }

  void _startSpinning() {
    if (!_isVinyl) return;
    if (_morphController.isCompleted && !_spinController.isAnimating) {
      _spinController.repeat();
    }
  }

  void _handleMorphStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && _isVinyl) {
      if (_isPlaying) {
        _spinController.repeat();
      }
    } else if (status == AnimationStatus.dismissed) {
      _spinController.value = 0;
    }
  }

  void _onPositionChanged() {
    if (!_isVinyl) return;
    if (_isUserDragging) return;
    final service = widget.playerService;
    if (service == null) return;
    final newPosition = service.positionNotifier.value;
    final oldPosition = _lastObservedPosition;
    _lastObservedPosition = newPosition;

    final deltaMs = newPosition.inMilliseconds - oldPosition.inMilliseconds;
    if (deltaMs == 0) return;

    final isRewind = deltaMs < 0;
    final isForwardJump = deltaMs > _forwardSeekThresholdMs;
    if (isRewind || isForwardJump) {
      _animateSeek(deltaMs);
    }
  }

  void _onRotationStart() {
    if (!_isVinyl) return;
    final service = widget.playerService;
    if (service == null) return;
    _isUserDragging = true;
    _rotationHapticAccumulator = 0.0;
    _spinController.stop();
    _seekAngleController.stop();
    _seekAngleController.value = 0;
    _lastObservedPosition = service.positionNotifier.value;
    AppHaptics.selection();
  }

  void _onRotationUpdate(double delta) {
    if (!_isVinyl) return;
    final service = widget.playerService;
    if (service == null) return;
    _userRotationOffset += delta;

    _rotationHapticAccumulator += delta.abs();
    if (_rotationHapticAccumulator >= _hapticTickInterval) {
      _rotationHapticAccumulator -= _hapticTickInterval;
      AppHaptics.selection();
    }

    final msPerRadian =
        (_secondsPerVinylRotation * 1000) / (2 * math.pi);
    final seekMsDelta = (delta * msPerRadian).round();
    if (seekMsDelta != 0) {
      final current = service.positionNotifier.value;
      final duration = service.durationNotifier.value;
      var newPositionMs = current.inMilliseconds + seekMsDelta;
      if (duration.inMilliseconds > 0) {
        newPositionMs = newPositionMs.clamp(0, duration.inMilliseconds);
      } else {
        newPositionMs = newPositionMs.clamp(0, 0x7FFFFFFF);
      }
      final newPosition = Duration(milliseconds: newPositionMs);
      service.positionNotifier.value = newPosition;
      _lastObservedPosition = newPosition;
      unawaited(service.seek(newPosition));
    }

    setState(() {});
  }

  void _onRotationEnd() {
    _isUserDragging = false;
    _rotationHapticAccumulator = 0.0;
    if (_isVinyl && _isPlaying) {
      _spinController.repeat();
    }
    AppHaptics.confirm();
  }

  void _animateSeek(int deltaMs) {
    if (!_isVinyl) return;
    var revolutions = (deltaMs.abs() / _msPerSeekRevolution).round();
    revolutions = revolutions.clamp(_minSeekRevolutions, _maxSeekRevolutions);
    final signed = deltaMs >= 0 ? revolutions : -revolutions;

    final from = _seekAngleController.value;
    final to = from + signed * 2 * math.pi;

    _seekAngleController.stop();
    _seekAngleController.value = from;
    _seekAngleController.animateTo(
      to,
      duration: _seekAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle() {
    AppHaptics.confirm();
    setState(() {
      _isVinyl = !_isVinyl;
      if (_isVinyl) {
        _morphController.forward();
      } else {
        _spinController.stop();
        _seekAngleController.stop();
        _seekAngleController.value = 0;
        _userRotationOffset = 0.0;
        _morphController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double resolvedSize =
        widget.size ?? context.responsive(280.0, 320.0, 360.0);
    
    // Update the disc center for rotation detection
    _rotationRecognizer.discCenter = () => Offset(resolvedSize / 2, resolvedSize / 2);

    final framePadding = resolvedSize < 220 ? 5.0 : 7.0;
    final outerRadius = resolvedSize < 220 ? 28.0 : 34.0;
    final innerRadius = math.max(outerRadius - 7.0, 20.0);
    final iconSize = math.max(52.0, resolvedSize * 0.24);
    final shadowBlur = resolvedSize < 220 ? 28.0 : 36.0;
    final shadowOffsetY = resolvedSize < 220 ? 14.0 : 20.0;
    final labelSize = resolvedSize * _labelRatio;
    final labelRadius = labelSize / 2;

    return Center(
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => _tapRecognizer,
            (_) {},
          ),
          _RotationSeekRecognizer:
              GestureRecognizerFactoryWithHandlers<_RotationSeekRecognizer>(
            () => _rotationRecognizer,
            (_) {},
          ),
        },
        child: SizedBox(
          width: resolvedSize,
          height: resolvedSize,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _morphController,
              _spinController,
              _seekAngleController,
            ]),
            builder: (context, _) {
              final rawT = Curves.easeInOutCubic
                  .transform(_morphController.value);
              final t = rawT.isNaN ? 0.0 : rawT.clamp(0.0, 1.0);
              final glass = (1.0 - t).clamp(0.0, 1.0);
              final rawAngle = _spinController.value * 2 * math.pi * t +
                  _seekAngleController.value +
                  _userRotationOffset;
              final spinAngle = rawAngle.isNaN ? 0.0 : rawAngle;

              final artSize = resolvedSize - (resolvedSize - labelSize) * t;
              final artFramePadding = framePadding * glass;
              final artOuterRadius =
                  outerRadius + (labelRadius - outerRadius) * t;
              final artInnerRadius =
                  innerRadius + (labelRadius - innerRadius) * t;

              return Transform.rotate(
                angle: spinAngle,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (t > 0.001)
                      Opacity(
                        opacity: t,
                        child: SizedBox(
                          width: resolvedSize,
                          height: resolvedSize,
                          child: CustomPaint(
                            painter: _VinylDiscPainter(
                              labelRatio: _labelRatio,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: artSize,
                      height: artSize,
                      padding: EdgeInsets.all(artFramePadding),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(artOuterRadius),
                        gradient: glass > 0.01
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white
                                      .withValues(alpha: 0.16 * glass),
                                  Colors.white
                                      .withValues(alpha: 0.06 * glass),
                                  Colors.white
                                      .withValues(alpha: 0.02 * glass),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              )
                            : null,
                        border: Border.all(
                          color: glass > 0.5
                              ? Colors.white
                                  .withValues(alpha: 0.12 * glass)
                              : Colors.black
                                  .withValues(alpha: 0.28 * t),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.32 * (0.35 + 0.65 * glass),
                            ),
                            blurRadius:
                                shadowBlur * (0.45 + 0.55 * glass),
                            offset: Offset(
                              0,
                              shadowOffsetY * (0.25 + 0.75 * glass),
                            ),
                          ),
                          if (glass > 0.05)
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: 0.06 * glass,
                              ),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(artInnerRadius),
                        child: CachedImageWidget(
                          imagePath: widget.song.albumArt,
                          audioSourcePath: widget.song.filePath,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Icon(
                              LucideIcons.music,
                              size: iconSize * (1 - t * 0.5),
                              color:
                                  Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                          errorWidget: Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Icon(
                              LucideIcons.music,
                              size: iconSize * (1 - t * 0.5),
                              color:
                                  Colors.white.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (t > 0.35)
                      IgnorePointer(
                        child: Container(
                          width: resolvedSize * 0.045,
                          height: resolvedSize * 0.045,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF050505)
                                .withValues(alpha: t),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.55 * t),
                                blurRadius: 2,
                                offset: const Offset(0, 0.5),
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
        ),
      ),
    );
  }
}

class _RotationSeekRecognizer extends OneSequenceGestureRecognizer {
  _RotationSeekRecognizer({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.discCenter,
  });

  final VoidCallback onStart;
  final void Function(double delta) onUpdate;
  final VoidCallback onEnd;
  Offset Function() discCenter;

  Offset? _startPos;
  double? _lastAngle;
  bool _accepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _startPos = event.localPosition;
    _lastAngle = null;
    _accepted = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_accepted) {
      if (event is PointerMoveEvent) {
        _handleMove(event);
      } else if (event is PointerUpEvent || event is PointerCancelEvent) {
        onEnd();
        _accepted = false;
        stopTrackingPointer(event.pointer);
      }
      return;
    }

    if (event is PointerMoveEvent && _startPos != null) {
      final center = discCenter();
      if (center == Offset.zero) return;

      final totalDx = event.localPosition.dx - _startPos!.dx;
      final totalDy = event.localPosition.dy - _startPos!.dy;
      final totalDist = math.sqrt(totalDx * totalDx + totalDy * totalDy);

      if (totalDist < 12) return;

      // Check if motion is tangential (rotational) vs radial (linear swipe)
      final motionDx = event.localPosition.dx - _startPos!.dx;
      final motionDy = event.localPosition.dy - _startPos!.dy;
      final radiusDx = _startPos!.dx - center.dx;
      final radiusDy = _startPos!.dy - center.dy;
      final radiusLength = math.sqrt(radiusDx * radiusDx + radiusDy * radiusDy);
      
      if (radiusLength < 20) return; // Too close to center

      final dotProduct = motionDx * radiusDx + motionDy * radiusDy;
      final motionLength = math.sqrt(motionDx * motionDx + motionDy * motionDy);
      final cosAngle = (dotProduct / (motionLength * radiusLength)).clamp(-1.0, 1.0);
      
      // If motion is mostly radial (cosAngle close to ±1), it's a swipe
      // If motion is mostly tangential (cosAngle close to 0), it's rotation
      if (cosAngle.abs() > 0.5) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }

      resolve(GestureDisposition.accepted);
      _accepted = true;
      final initialDx = event.localPosition.dx - center.dx;
      final initialDy = event.localPosition.dy - center.dy;
      _lastAngle = math.atan2(initialDy, initialDx);
      onStart();
      _handleMove(event);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  void _handleMove(PointerMoveEvent event) {
    final center = discCenter();
    if (center == Offset.zero) return;
    final angle = math.atan2(
      event.localPosition.dy - center.dy,
      event.localPosition.dx - center.dx,
    );
    if (_lastAngle != null) {
      var delta = angle - _lastAngle!;
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;
      onUpdate(delta);
    }
    _lastAngle = angle;
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _startPos = null;
    _lastAngle = null;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'rotation seek';

  @override
  void dispose() {
    super.dispose();
    _startPos = null;
    _lastAngle = null;
    _accepted = false;
  }
}

class _VinylDiscPainter extends CustomPainter {
  _VinylDiscPainter({required this.labelRatio});

  final double labelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;

    final discPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.95,
        colors: const [Color(0xFF2A2A2A), Color(0xFF0A0A0A)],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, discPaint);

    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.06);
    final labelRadius = outerRadius * labelRatio;
    const grooves = 16;
    for (var i = 0; i < grooves; i++) {
      final t = (i + 1) / (grooves + 1);
      final r = labelRadius + (outerRadius - labelRadius) * t;
      canvas.drawCircle(center, r, groovePaint);
    }

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.45),
        radius: 0.55,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylDiscPainter oldDelegate) =>
      oldDelegate.labelRatio != labelRatio;
}

class _VisualizerArtBox extends StatelessWidget {
  final PlayerService playerService;
  final double? size;
  final String animationStyle;
  final String frequencyMode;
  final String movementMode;
  final Color? albumColor;

  const _VisualizerArtBox({
    required this.playerService,
    this.size,
    this.animationStyle = 'bars',
    this.frequencyMode = 'full',
    this.movementMode = 'bouncy',
    this.albumColor,
  });

  @override
  Widget build(BuildContext context) {
    final double resolvedSize = size ?? context.responsive(280.0, 320.0, 360.0);
    final framePadding = resolvedSize < 220 ? 5.0 : 7.0;
    final outerRadius = resolvedSize < 220 ? 28.0 : 34.0;
    final innerRadius = math.max(outerRadius - 7.0, 20.0);
    final shadowBlur = resolvedSize < 220 ? 28.0 : 36.0;
    final shadowOffsetY = resolvedSize < 220 ? 14.0 : 20.0;

    return Center(
      child: Container(
        width: resolvedSize,
        height: resolvedSize,
        padding: EdgeInsets.all(framePadding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: shadowBlur,
              offset: Offset(0, shadowOffsetY),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Container(
            color: const Color(0xFF0A0A0A),
            child: AudioVisualizer(
              playerService: playerService,
              animationStyle: animationStyle,
              frequencyMode: frequencyMode,
              movementMode: movementMode,
              albumColor: albumColor,
            ),
          ),
        ),
      ),
    );
  }
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
        final artSize = (maxWidth * 0.68).clamp(180.0, 380.0) *
            artworkCardArtworkScale;
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

class _InlineLyricsPanel extends StatefulWidget {
  final PlayerService playerService;
  final LyricsService lyricsService;
  final Song song;
  final Color? albumColor;

  const _InlineLyricsPanel({
    required this.playerService,
    required this.lyricsService,
    required this.song,
    this.albumColor,
  });

  @override
  State<_InlineLyricsPanel> createState() => _InlineLyricsPanelState();
}

class _InlineLyricsPanelState extends State<_InlineLyricsPanel> {
  static const double _lineHeight = 116;
  static const double _centerFactor = 0.35;

  final ScrollController _scrollController = ScrollController();
  LyricsData? _lyricsData;
  bool _isLoading = true;
  bool _hasManualLyricsSelection = false;
  int _activeLineIndex = -1;
  bool _isMetaCollapsed = false;
  bool _isScrollAnimating = false;
  double? _pendingScrollTarget;

  @override
  void initState() {
    super.initState();
    widget.playerService.positionNotifier.addListener(_onPositionChanged);
    _loadLyricsForSong(widget.song);
  }

  @override
  void didUpdateWidget(covariant _InlineLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadLyricsForSong(widget.song);
    }
  }

  @override
  void dispose() {
    widget.playerService.positionNotifier.removeListener(_onPositionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    final data = _lyricsData;
    if (data == null || !data.isSynchronized || data.lines.isEmpty) return;

    final position = widget.playerService.positionNotifier.value;
    final newIndex = widget.lyricsService.findCurrentLineIndex(data, position);
    if (newIndex == _activeLineIndex) return;

    _activeLineIndex = newIndex;
    _scrollToActiveLine(newIndex);
    setState(() {});
  }

  Future<void> _loadLyricsForSong(Song song) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lyricsData = null;
      _activeLineIndex = -1;
    });

    final loaded = await widget.lyricsService.loadLyricsForSong(
      song,
      forceRefresh: true,
    );
    final manualSource = await widget.lyricsService.getManualLyricsPathForSong(
      song,
    );
    if (!mounted) return;
    if (widget.song.id != song.id) return;

    setState(() {
      _lyricsData = loaded;
      _hasManualLyricsSelection =
          manualSource != null && manualSource.isNotEmpty;
      _isLoading = false;
    });

    _onPositionChanged();
  }

  void _scrollToActiveLine(int index) {
    if (!_scrollController.hasClients || index < 0) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (index * _lineHeight) + (_lineHeight / 2);
    final clampedTarget = target.clamp(0.0, maxScroll);

    _pendingScrollTarget = clampedTarget;

    if (!_isScrollAnimating) {
      _performScroll();
    }
  }

  void _performScroll() {
    if (!_scrollController.hasClients || _pendingScrollTarget == null) {
      _isScrollAnimating = false;
      return;
    }

    final target = _pendingScrollTarget!;
    _pendingScrollTarget = null;

    final delta = (_scrollController.offset - target).abs();
    if (delta < _lineHeight * 0.08) {
      _performScroll();
      return;
    }

    _isScrollAnimating = true;
    _scrollController
        .animateTo(
          target,
          duration: AppConstants.animationNormal,
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          _isScrollAnimating = false;
          _performScroll();
        });
  }

  Future<void> _seekToLyricLine(int index) async {
    final lyrics = _lyricsData;
    if (lyrics == null || !lyrics.isSynchronized || index < 0) return;

    final target = lyrics.lines[index].timestamp;
    widget.playerService.positionNotifier.value = target;

    if (mounted && _activeLineIndex != index) {
      setState(() {
        _activeLineIndex = index;
      });
    }

    _isScrollAnimating = false;
    _pendingScrollTarget = null;
    _scrollToActiveLine(index);
    await widget.playerService.seek(target);
  }

  String? _lyricsSourceLabel(String? source) {
    if (source == null || source.isEmpty) return null;
    final normalized = source.replaceAll('\\', '/');
    return normalized.split('/').last;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _openLyricsEditor() async {
    final result = await LyricsEditorBottomSheet.show(
      context: context,
      song: widget.song,
      playerService: widget.playerService,
      lyricsService: widget.lyricsService,
      initialLyrics: _lyricsData,
    );
    if (!mounted || result == null) return;
    _showMessage(result.message);
    await _loadLyricsForSong(widget.song);
  }

  Future<void> _importLyricsFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['lrc', 'txt', 'xml'],
        withData: true,
      );
      final pickedFile = result?.files.single;
      if (pickedFile == null) return;

      final content = await readTextFromPickedLyricsFile(pickedFile);
      if (content == null || content.trim().isEmpty) {
        _showMessage('Could not read the selected lyrics file.');
        return;
      }

      await widget.lyricsService.importLyricsForSong(
        song: widget.song,
        fileName: pickedFile.name,
        content: content,
      );
      if (!mounted) return;
      await _loadLyricsForSong(widget.song);
      _showMessage('Linked "${pickedFile.name}" to this song.');
    } catch (_) {
      _showMessage('Could not use the selected lyrics file.');
    }
  }

  Future<void> _resetManualLyricsSource() async {
    await widget.lyricsService.clearManualLyricsPathForSong(widget.song);
    if (!mounted) return;
    await _loadLyricsForSong(widget.song);
    if (!mounted) return;
    _showMessage('Switched back to the automatic lyrics source.');
  }

  Future<void> _searchOnlineLyrics() async {
    final result = await OnlineLyricsSearchSheet.show(
      context: context,
      song: widget.song,
      lyricsService: widget.lyricsService,
    );
    if (result == true && mounted) {
      await _loadLyricsForSong(widget.song);
      _showMessage('Lyrics saved from LRCLib.');
    }
  }

  Widget _buildActionButtons() {
    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool emphasized = false,
    }) {
      final fillColor = emphasized
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.08);
      return TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: fillColor,
          foregroundColor: Colors.white.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          action(
            icon: LucideIcons.pencilLine,
            label: _lyricsData == null ? 'Create Lyrics' : 'Edit & Sync',
            onPressed: () => unawaited(_openLyricsEditor()),
            emphasized: true,
          ),
          action(
            icon: LucideIcons.filePlus,
            label: 'Use Existing File',
            onPressed: () => unawaited(_importLyricsFile()),
          ),
          action(
            icon: LucideIcons.globe,
            label: 'Search Online',
            onPressed: () => unawaited(_searchOnlineLyrics()),
          ),
          if (_hasManualLyricsSelection)
            action(
              icon: LucideIcons.refreshCcw,
              label: 'Use Auto Source',
              onPressed: () => unawaited(_resetManualLyricsSource()),
            ),
        ],
      ),
    );
  }

  Widget _buildLyricsMeta(LyricsData lyrics) {
    final sourceLabel = _lyricsSourceLabel(lyrics.source);
    final textColor = Colors.white.withValues(alpha: 0.82);

    Widget chip(IconData icon, String label, {bool accent = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accent
                ? AppColors.accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: accent ? AppColors.accent : textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent ? AppColors.accent : textColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isMetaCollapsed = !_isMetaCollapsed),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chip(
                  lyrics.isSynchronized ? LucideIcons.clock3 : LucideIcons.fileText,
                  lyrics.isSynchronized ? 'Synced' : 'Plain',
                  accent: lyrics.isSynchronized,
                ),
                const SizedBox(width: 8),
                if (sourceLabel != null) ...[
                  chip(LucideIcons.badgeInfo, sourceLabel),
                  const SizedBox(width: 8),
                ],
                AnimatedRotation(
                  turns: _isMetaCollapsed ? 0.0 : 0.5,
                  duration: AppConstants.animationFast,
                  child: Icon(
                    LucideIcons.chevronDown,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: AppConstants.animationFast,
          crossFadeState: _isMetaCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip(
                      lyrics.isSynchronized
                          ? LucideIcons.touchpad
                          : Icons.notes_rounded,
                      lyrics.isSynchronized
                          ? 'Tap any line to seek'
                          : 'Static lyrics — no timestamps',
                    ),
                    chip(
                      LucideIcons.pencilLine,
                      'Edit & Sync Studio',
                    ),
                    if (lyrics.lines.isNotEmpty)
                      chip(
                        Icons.format_align_left,
                        '${lyrics.lines.length} lines',
                      ),
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlainLyricsView(LyricsData lyrics) {
    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Text(
          lyrics.lines.map((line) => line.text).join('\n'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'ProductSans',
            fontSize: 18,
            height: 1.9,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }

  double _lyricOpacityForIndex(int index) {
    if (_activeLineIndex < 0) return 0.72;

    final distance = (index - _activeLineIndex).abs();
    switch (distance) {
      case 0:
        return 1;
      case 1:
        return 0.56;
      case 2:
        return 0.36;
      case 3:
        return 0.24;
      default:
        return 0.18;
    }
  }

  TextStyle _lyricTextStyle(bool isActive, double opacity) {
    return TextStyle(
      fontFamily: 'ProductSans',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: Colors.white.withValues(alpha: opacity),
    );
  }

  StrutStyle _lyricStrutStyle(bool isActive) {
    return StrutStyle(
      fontFamily: 'ProductSans',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      forceStrutHeight: true,
    );
  }

  Widget _buildSynchronizedLyricsView(LyricsData lyrics) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerPadding = constraints.maxHeight * _centerFactor;
          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(10, centerPadding, 10, centerPadding),
            cacheExtent: _lineHeight * 8,
            itemCount: lyrics.lines.length,
            itemExtent: _lineHeight,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isActive = index == _activeLineIndex;
              final lineOpacity = _lyricOpacityForIndex(index);

              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => unawaited(_seekToLyricLine(index)),
                      child: Center(
                        child: isActive
                            ? AnimatedContainer(
                                duration: AppConstants.animationFast,
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  color: widget.albumColor != null
                                      ? _AnimatedSongScene.albumAccent(
                                          widget.albumColor!,
                                          0.3,
                                        ).withValues(alpha: 0.16)
                                      : Colors.white.withValues(alpha: 0.16),
                                  border: Border.all(
                                    color: widget.albumColor != null
                                        ? _AnimatedSongScene.albumAccent(
                                            widget.albumColor!,
                                            0.3,
                                          ).withValues(alpha: 0.22)
                                        : Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  line.text,
                                  maxLines: 3,
                                  overflow: TextOverflow.fade,
                                  textAlign: TextAlign.center,
                                  style: _lyricTextStyle(true, lineOpacity),
                                  strutStyle: _lyricStrutStyle(true),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Text(
                                  line.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.fade,
                                  textAlign: TextAlign.center,
                                  style: _lyricTextStyle(false, lineOpacity),
                                  strutStyle: _lyricStrutStyle(false),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final lyrics = _lyricsData;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  LucideIcons.fileText,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No lyrics yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
),
               const SizedBox(height: 8),
               Text(
                 'Search online, create your own synced lyrics, or import an existing file.',
                 textAlign: TextAlign.center,
                 style: TextStyle(
                   fontFamily: 'ProductSans',
                   fontSize: 13,
                   height: 1.5,
                   color: Colors.white.withValues(alpha: 0.56),
                 ),
               ),
               _buildActionButtons(),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildLyricsMeta(lyrics),
        if (lyrics.isSynchronized)
          _buildSynchronizedLyricsView(lyrics)
        else
          Expanded(child: _buildPlainLyricsView(lyrics)),
      ],
    );
  }
}

/// Extracted waveform layer widget.
/// Owns a ValueListenableBuilder on [positionNotifier] so that 50ms position
/// ticks **never** cause the parent [_FullPlayerScreenState] to rebuild.
class _WaveformLayer extends StatefulWidget {
  final PlayerService playerService;
  final ValueNotifier<Duration> positionNotifier;
  final Song? currentSong;

  const _WaveformLayer({
    required this.playerService,
    required this.positionNotifier,
    required this.currentSong,
  });

  @override
  State<_WaveformLayer> createState() => _WaveformLayerState();
}

class _WaveformLayerState extends State<_WaveformLayer> {
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final style = ref.watch(progressBarStyleProvider);
        return ValueListenableBuilder<Duration>(
          valueListenable: widget.playerService.durationNotifier,
          builder: (context, engineDuration, _) {
            final duration = engineDuration.inMilliseconds > 0
                ? engineDuration
                : (widget.currentSong?.duration ?? Duration.zero);

            if (duration.inMilliseconds == 0) {
              return const SizedBox();
            }

            return ValueListenableBuilder<Duration>(
              valueListenable: widget.positionNotifier,
              builder: (context, position, _) {
                final seekBar = switch (style) {
                  ProgressBarStyle.line => LineSeekBar(
                    position: position,
                    duration: duration,
                    onChanged: (newPos) {
                      widget.positionNotifier.value = newPos;
                      unawaited(widget.playerService.seek(newPos));
                    },
                  ),
                  ProgressBarStyle.waveform => WaveformSeekBar(
                    barCount: 60,
                    position: position,
                    duration: duration,
                    onChanged: (newPos) {
                      widget.positionNotifier.value = newPos;
                      unawaited(widget.playerService.seek(newPos));
                    },
                  ),
                };
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: RepaintBoundary(child: seekBar),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Extracted player controls widget to reduce nesting and improve performance
class _PlayerControls extends StatelessWidget {
  final PlayerService playerService;
  final String Function(Duration) formatDuration;
  final Song? currentSong;
  final ValueNotifier<bool> isShuffleNotifier;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final double timelineHorizontalPadding;
  final AlbumColorMode albumColorMode;
  final Color? albumColor;

  const _PlayerControls({
    required this.playerService,
    required this.formatDuration,
    required this.currentSong,
    required this.isShuffleNotifier,
    required this.onPrevious,
    required this.onNext,
    this.timelineHorizontalPadding = 0,
    this.albumColorMode = AlbumColorMode.off,
    this.albumColor,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceBlend = albumColorMode.surfaceBlend;
    final accentBlend = albumColorMode.accentBlend;
    final hasAlbumTint = albumColor != null && surfaceBlend > 0;

    final buttonSurface = hasAlbumTint
        ? _AnimatedSongScene.albumSurface(albumColor!, surfaceBlend)
        : const Color(0xFF121212);
    final activeAccent = hasAlbumTint
        ? _AnimatedSongScene.albumAccent(albumColor!, accentBlend)
        : AppColors.accent;

    return RepaintBoundary(
      child: ValueListenableBuilder<Duration>(
        valueListenable: playerService.positionNotifier,
        builder: (context, position, _) {
          return ValueListenableBuilder<Duration>(
            valueListenable: playerService.durationNotifier,
            builder: (context, engineDuration, _) {
              final duration = engineDuration.inMilliseconds > 0
                  ? engineDuration
                  : (currentSong?.duration ?? Duration.zero);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlaybackTimeLabels(
                    position: position,
                    duration: duration,
                    formatDuration: formatDuration,
                    horizontalPadding: timelineHorizontalPadding,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Shuffle
                      ValueListenableBuilder<bool>(
                        valueListenable: isShuffleNotifier,
                        builder: (context, isShuffle, _) {
                          return Container(
                            width: context.responsive(40.0, 44.0, 48.0),
                            height: context.responsive(40.0, 44.0, 48.0),
                            decoration: BoxDecoration(
                              color: isShuffle
                                  ? activeAccent.withValues(alpha: 0.25)
                                  : buttonSurface.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: isShuffle
                                  ? Border.all(
                                      color: activeAccent.withValues(
                                        alpha: 0.6,
                                      ),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: IconButton(
                              onPressed: () {
                                AppHaptics.tap();
                                playerService.toggleShuffle();
                              },
                              iconSize: context.responsive(18.0, 20.0, 22.0),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                LucideIcons.shuffle,
                                color: isShuffle
                                    ? activeAccent
                                    : Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: context.responsive(14.0, 18.0, 22.0)),
                      // Previous
                      Container(
                        width: context.responsive(40.0, 44.0, 48.0),
                        height: context.responsive(40.0, 44.0, 48.0),
                        decoration: BoxDecoration(
                          color: buttonSurface.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            AppHaptics.tap();
                            onPrevious();
                          },
                          iconSize: context.responsive(18.0, 20.0, 22.0),
                          padding: EdgeInsets.zero,
                          icon: Icon(LucideIcons.skipBack, color: Colors.white),
                        ),
                      ),
                      SizedBox(width: context.responsive(14.0, 18.0, 22.0)),
                      // Play/Pause
                      _PlayPauseButton(
                        playerService: playerService,
                        albumColorMode: albumColorMode,
                        albumColor: albumColor,
                      ),
                      SizedBox(width: context.responsive(14.0, 18.0, 22.0)),
                      // Next
                      Container(
                        width: context.responsive(40.0, 44.0, 48.0),
                        height: context.responsive(40.0, 44.0, 48.0),
                        decoration: BoxDecoration(
                          color: buttonSurface.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            AppHaptics.tap();
                            onNext();
                          },
                          iconSize: context.responsive(18.0, 20.0, 22.0),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            LucideIcons.skipForward,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: context.responsive(14.0, 18.0, 22.0)),
                      // Repeat/Loop
                      ValueListenableBuilder<LoopMode>(
                        valueListenable: playerService.loopModeNotifier,
                        builder: (context, loopMode, _) {
                          IconData icon = LucideIcons.repeat;
                          Color color = Colors.white.withValues(alpha: 0.7);
                          if (loopMode == LoopMode.all) {
                            color = activeAccent;
                          }
                          if (loopMode == LoopMode.one) {
                            icon = LucideIcons.repeat1;
                            color = activeAccent;
                          }
                          return Container(
                            width: context.responsive(40.0, 44.0, 48.0),
                            height: context.responsive(40.0, 44.0, 48.0),
                            decoration: BoxDecoration(
                              color: buttonSurface.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    AppHaptics.tap();
                                    playerService.toggleLoopMode();
                                  },
                                  iconSize: context.responsive(
                                    18.0,
                                    20.0,
                                    22.0,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(icon, color: color),
                                ),
                                if (loopMode == LoopMode.all)
                                  Positioned(
                                    bottom: 6,
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: activeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PlaybackTimeRow extends StatelessWidget {
  final PlayerService playerService;
  final String Function(Duration) formatDuration;
  final Song? currentSong;
  final double horizontalPadding;

  const _PlaybackTimeRow({
    required this.playerService,
    required this.formatDuration,
    required this.currentSong,
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: playerService.positionNotifier,
      builder: (context, position, _) {
        return ValueListenableBuilder<Duration>(
          valueListenable: playerService.durationNotifier,
          builder: (context, engineDuration, _) {
            final duration = engineDuration.inMilliseconds > 0
                ? engineDuration
                : (currentSong?.duration ?? Duration.zero);

            return _PlaybackTimeLabels(
              position: position,
              duration: duration,
              formatDuration: formatDuration,
              horizontalPadding: horizontalPadding,
            );
          },
        );
      },
    );
  }
}

class _LyricsModeWaveformStrip extends StatefulWidget {
  final PlayerService playerService;
  final ValueNotifier<Duration> positionNotifier;
  final Song? currentSong;
  final String Function(Duration) formatDuration;
  final double horizontalPadding;
  final VoidCallback onSwipeUp;

  const _LyricsModeWaveformStrip({
    required this.playerService,
    required this.positionNotifier,
    required this.currentSong,
    required this.formatDuration,
    required this.horizontalPadding,
    required this.onSwipeUp,
  });

  @override
  State<_LyricsModeWaveformStrip> createState() =>
      _LyricsModeWaveformStripState();
}

class _LyricsModeWaveformStripState extends State<_LyricsModeWaveformStrip>
    with SingleTickerProviderStateMixin {
  Offset? _pointerDownPosition;
  bool _didTriggerSwipe = false;

  late final AnimationController _arrowAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _arrowAnimController.dispose();
    super.dispose();
  }

  void _resetPointerTracking() {
    _pointerDownPosition = null;
    _didTriggerSwipe = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _pointerDownPosition;
    if (start == null || _didTriggerSwipe) {
      return;
    }

    final delta = event.position - start;
    final isSwipeUp = delta.dy <= -28;
    final isPrimarilyVertical = delta.dy.abs() > (delta.dx.abs() * 1.2);

    if (isSwipeUp && isPrimarilyVertical) {
      _didTriggerSwipe = true;
      widget.onSwipeUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerDownPosition = event.position;
        _didTriggerSwipe = false;
      },
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) => _resetPointerTracking(),
      onPointerCancel: (_) => _resetPointerTracking(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _arrowAnimController,
            builder: (context, child) {
              final t = _arrowAnimController.value;
              final bounce = -4.0 * math.sin(t * math.pi);
              final opacity = 0.72 + 0.28 * math.sin(t * math.pi);
              return Transform.translate(
                offset: Offset(0, bounce),
                child: Opacity(opacity: opacity, child: child!),
              );
            },
            child: Icon(
              Icons.keyboard_double_arrow_up_rounded,
              color: Colors.white,
              size: context.responsive(18.0, 20.0, 22.0),
            ),
          ),
          SizedBox(height: context.responsive(2.0, 4.0, 6.0)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
            child: _WaveformLayer(
              playerService: widget.playerService,
              positionNotifier: widget.positionNotifier,
              currentSong: widget.currentSong,
            ),
          ),
          SizedBox(height: context.responsive(4.0, 6.0, 8.0)),
          _PlaybackTimeRow(
            playerService: widget.playerService,
            formatDuration: widget.formatDuration,
            currentSong: widget.currentSong,
            horizontalPadding: widget.horizontalPadding,
          ),
          SizedBox(height: context.responsive(14.0, 18.0, 22.0)),
        ],
      ),
    );
  }
}

class _PlaybackTimeLabels extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final double horizontalPadding;

  const _PlaybackTimeLabels({
    required this.position,
    required this.duration,
    required this.formatDuration,
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDuration(position),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            formatDuration(duration),
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 12,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Extracted play/pause button to minimize rebuilds when only play state changes
class _PlayPauseButton extends StatelessWidget {
  final PlayerService playerService;
  final AlbumColorMode albumColorMode;
  final Color? albumColor;

  const _PlayPauseButton({
    required this.playerService,
    this.albumColorMode = AlbumColorMode.off,
    this.albumColor,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceBlend = albumColorMode.surfaceBlend;
    final accentBlend = albumColorMode.accentBlend;
    final hasAlbumTint = albumColor != null && surfaceBlend > 0;

    final buttonSurface = hasAlbumTint
        ? _AnimatedSongScene.albumSurface(albumColor!, surfaceBlend)
        : const Color(0xFF121212);
    final glowColor = hasAlbumTint
        ? _AnimatedSongScene.albumAccent(albumColor!, accentBlend)
        : AppColors.accent;

    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: playerService.isPlayingNotifier,
        builder: (context, isPlaying, _) {
          final buttonSize = context.responsive(58.0, 64.0, 68.0);
          final iconSize = context.responsive(26.0, 28.0, 30.0);

          return Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: buttonSurface.withValues(alpha: 0.6),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.4),
                  blurRadius: context.responsive(14.0, 18.0, 22.0),
                  offset: Offset(0, context.responsive(5.0, 6.0, 7.0)),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                AppHaptics.tap();
                playerService.togglePlayPause();
              },
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              icon: Icon(
                isPlaying ? LucideIcons.pause : LucideIcons.play,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
