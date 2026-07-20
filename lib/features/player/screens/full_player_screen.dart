import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/duration_format.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/player/widgets/animated_song_scene.dart';

import 'package:flick/features/player/widgets/player_layout_sheet.dart';
import 'package:flick/features/player/widgets/player_action_button_row.dart';
import 'package:flick/features/player/widgets/player_navigation.dart';
import 'package:flick/features/player/widgets/song_actions_sheet.dart';

import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/external_playback_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_screen_mode_preference_service.dart';


import 'package:flick/widgets/common/display_mode_wrapper.dart';
import 'package:flick/widgets/uac2/iso_volume_popup.dart';
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
  late final PlayerNavigation _navigation = PlayerNavigation(
    playerService: _playerService,
    songRepository: _songRepository,
  );

  void _close(BuildContext context) {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    Navigator.of(context).pop();
  }
  static const String _topBarTextFontFamily = 'ProductSans';
  static const FontWeight _topBarTextFontWeight = FontWeight.w500;

  // Animation controller for drag offset (replaces setState)
  late AnimationController _dragController;

  // Track current drag offset (updated directly, no setState)
  double _dragOffset = 0.0;

  // Last drag update time for throttling
  DateTime _lastDragUpdate = DateTime.now();

  // ponytail: 24dp edge zone matches Android's predictive back gesture origin
  static const double _backGestureEdgeWidth = 24.0;
  double _horizontalDragStartX = double.infinity;

  // Notifier for throttled position – only _WaveformLayer listens, so no setState needed.
  late final ValueNotifier<Duration> _throttledPositionNotifier;
  Timer? _positionThrottleTimer;
  String? _cachedTopBarText;
  double? _cachedTopBarFontSize;
  double _cachedTopBarTextWidth = 0;
  bool _isLyricsMode = false;
  bool _isVinylRotationActive = false;
  bool _isVinylMode = false;
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

  void _showUsbVolumePopup(BuildContext context) {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = showIsoVolumePopup(context, _usbVolumeButtonKey);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close(context);
      },
      child: DisplayModeWrapper(
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
                  if (_isVinylRotationActive) return;
                  _dragController.stop();
                },
                onVerticalDragUpdate: (details) {
                  if (_isVinylRotationActive) return;
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
                  if (_isVinylRotationActive) return;
                  // If dragged down enough or with enough velocity, dismiss
                  if (_dragOffset > 100 || details.primaryVelocity! > 500) {
                    _close(context);
                    return;
                  }

                  // Animate back to 0
                  _dragOffset = 0.0;
                  _dragController.animateTo(0.0);
                },
                onHorizontalDragStart: (details) {
                  _horizontalDragStartX = details.globalPosition.dx;
                },
                onHorizontalDragEnd: (details) {
                  if (_isVinylRotationActive) return;
                  // Skip song navigation if drag started at screen edge so the
                  // native Android back gesture takes priority.
                  final screenWidth = MediaQuery.sizeOf(context).width;
                  final nearLeftEdge = _horizontalDragStartX <= _backGestureEdgeWidth;
                  final nearRightEdge =
                      _horizontalDragStartX >= screenWidth - _backGestureEdgeWidth;
                  if (nearLeftEdge || nearRightEdge) return;

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
                  child: AnimatedSongScene(
                    song: song,
                    lyricsMode: _isLyricsMode,
                    visualizationMode:
                        _isVisualizationMode && appPrefs.visualizerEnabled,
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
                    formatDuration: formatDuration,
                    onClose: () => _close(context),
                    onOpenQueue: () => _navigation.openQueue(context),
                    onToggleLyrics: () => _setLyricsMode(!_isLyricsMode),
                    onQueueSwipe: () => _navigation.queueSong(context, song),
                    onReturnToLocker: () async {
                      final returned = await _externalPlaybackService
                          .returnToLocker();
                      if (!returned && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    onShowSongActions: () => SongActionsSheet.show(
                      context,
                      playerService: _playerService,
                      song: song,
                      isVisualizationMode: _isVisualizationMode,
                      onShowLyrics: () => _setLyricsMode(true),
                      onToggleVisualization: (v) => _setVisualizationMode(v),
                      onShowPlayerLayout: (ctx) => PlayerLayoutSheet.show(
                        ctx,
                        playerService: _playerService,
                        currentMode: _playerScreenMode,
                        onModeChanged: _setPlayerScreenMode,
                        song: _playerService.currentSongNotifier.value,
                      ),
                      navigation: _navigation,
                    ),
                    onPrevious: _animateToPreviousSong,
                    onNext: _animateToNextSong,
                    onNavigateToArtistDetail: (song) =>
                        _navigation.openArtistFromSong(context, song),
                    onNavigateToAlbumDetail: (song) =>
                        _navigation.openAlbumFromSong(context, song),
                    buildFileInfoRow: (song, lyricsMode, mode) =>
                        PlayerActionButtonRow(
                      song: song,
                      lyricsMode: lyricsMode,
                      isVisualizationMode: _isVisualizationMode,
                      playerScreenMode: mode,
                      albumColor: albumColor,
                      albumColorMode: colorMode,
                      leftAction: PlayerActionButtonX.fromStorageValue(
                        appPrefs.leftActionButton,
                      ),
                      rightAction: PlayerActionButtonX.fromStorageValue(
                        appPrefs.rightActionButton,
                      ),
                      playerService: _playerService,
                      favoritesService: _favoritesService,
                      onToggleLyrics: () =>
                          setState(() => _isLyricsMode = !lyricsMode),
                      onToggleVisualization: (v) => _setVisualizationMode(v),
                      onOpenQueue: (ctx) => _navigation.openQueue(ctx),
                      usbVolumeButtonKey: _usbVolumeButtonKey,
                      onShowUsbVolumePopup: (ctx) => _showUsbVolumePopup(ctx),
                    ),
                    visualizerAnimationStyle: visStyle,
                    visualizerFrequencyMode: visFreq,
                    visualizerMovementMode: visMove,
                    artworkCardArtworkScale: appPrefs.artworkCardArtworkScale,
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
                    hideQueueBadge:
                        PlayerActionButtonX.fromStorageValue(
                              appPrefs.leftActionButton,
                            ) ==
                            PlayerActionButton.queue ||
                        PlayerActionButtonX.fromStorageValue(
                              appPrefs.rightActionButton,
                            ) ==
                            PlayerActionButton.queue,
                    onRotationEnabledChanged: (enabled) {
                      _isVinylRotationActive = enabled;
                    },
                    vinylMode: _isVinylMode,
                    onVinylChanged: (vinyl) {
                      _isVinylMode = vinyl;
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

