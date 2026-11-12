import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/adaptive_layout.dart';
import 'package:flick/core/utils/duration_format.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/data/repositories/song_repository.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/features/player/widgets/player_action_button_row.dart';
import 'package:flick/features/player/widgets/player_controls.dart';
import 'package:flick/features/player/widgets/player_layout_sheet.dart';
import 'package:flick/features/player/widgets/player_navigation.dart';
import 'package:flick/features/player/widgets/song_actions_sheet.dart';
import 'package:flick/features/player/widgets/song_stage.dart';
import 'package:flick/features/player/widgets/song_stage_carousel.dart';
import 'package:flick/features/player/widgets/landscape_player_layout.dart';
import 'package:flick/features/player/widgets/lyrics_mode_waveform_strip.dart';
import 'package:flick/features/player/widgets/inline_lyrics_panel.dart';
import 'package:flick/features/player/widgets/album_color_helpers.dart';
import 'package:flick/models/album_color_mode.dart';
import 'package:flick/models/audio_engine_type.dart';
import 'package:flick/models/immersive_background_style.dart';
import 'package:flick/models/player_screen_mode.dart';
import 'package:flick/models/player_action_button.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/external_playback_service.dart';
import 'package:flick/services/favorites_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_screen_mode_preference_service.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/visualizer_source.dart';
import 'package:flick/widgets/common/animated_album_art.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'package:flick/widgets/common/flick_artwork_placeholder.dart';
import 'package:flick/widgets/uac2/iso_volume_popup.dart';
import 'package:flick/widgets/uac2/uac2_error_notification.dart';
import 'package:flick/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/widgets/common/baybayin_text.dart';

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

  static const String _topBarTextFontFamily = 'GoogleSansFlex';
  static const FontWeight _topBarTextFontWeight = FontWeight.w500;

  late AnimationController _dragController;
  double _dragOffset = 0.0;
  DateTime _lastDragUpdate = DateTime.now();
  static const double _backGestureEdgeWidth = 32.0;

  late final ValueNotifier<Duration> _throttledPositionNotifier;
  final ValueNotifier<Duration> _zeroPosition = ValueNotifier(Duration.zero);
  Timer? _positionThrottleTimer;
  String? _cachedTopBarText;
  double? _cachedTopBarFontSize;
  bool _isLyricsMode = false;
  bool _isVinylRotationActive = false;
  bool _isVinylMode = false;
  bool _isVisualizationMode = false;
  bool _isImmersiveFullView = false;
  bool _isCarouselDragging = false;
  PlayerScreenMode _playerScreenMode = PlayerScreenMode.immersive;
  int _immersiveAutoFullViewDelaySeconds = 0;
  Timer? _immersiveFullViewTimer;
  final GlobalKey _usbVolumeButtonKey = GlobalKey();
  final GlobalKey<SongStageCarouselState> _carouselKey = GlobalKey();
  VoidCallback? _dismissVolumePopup;

  @override
  void initState() {
    super.initState();
    _immersiveAutoFullViewDelaySeconds = ref
        .read(appPreferencesProvider)
        .immersiveAutoFullViewSeconds;
    _dragController = AnimationController(
      vsync: this,
      duration: AppConstants.animationFast,
      lowerBound: 0.0,
      upperBound: 1000.0,
    );
    _dragController.value = 0.0;
    _throttledPositionNotifier = ValueNotifier(
      _playerService.positionNotifier.value,
    );
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
    _playerService.initializedPlaybackModeNotifier.addListener(
      _handleVisualizerAvailabilityChanged,
    );
    _playerService.selectedPlaybackModeNotifier.addListener(
      _handleVisualizerAvailabilityChanged,
    );
    _playerService.bitPerfectProcessingLockedNotifier.addListener(
      _handleVisualizerAvailabilityChanged,
    );
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
    _playerService.initializedPlaybackModeNotifier.removeListener(
      _handleVisualizerAvailabilityChanged,
    );
    _playerService.selectedPlaybackModeNotifier.removeListener(
      _handleVisualizerAvailabilityChanged,
    );
    _playerService.bitPerfectProcessingLockedNotifier.removeListener(
      _handleVisualizerAvailabilityChanged,
    );
    _playerService.favoriteNotificationToggleNotifier.removeListener(
      _handleFavoriteToggledFromNotification,
    );
    _positionThrottleTimer?.cancel();
    _immersiveFullViewTimer?.cancel();
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    _throttledPositionNotifier.dispose();
    _zeroPosition.dispose();
    _dragController.dispose();
    super.dispose();
  }

  void _handleCurrentSongChanged() {
    if (_playerService.currentSongNotifier.value == null) return;
    if (_isImmersiveFullView) {
      setState(() => _isImmersiveFullView = false);
    }
    _updateTopBarTextMeasurement(_playerService.currentSongNotifier.value);
    _refreshImmersiveFullViewTimer();
    _handleVisualizerAvailabilityChanged();
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
        if (mode != PlayerScreenMode.immersive) _isImmersiveFullView = false;
      });
    }
    _refreshImmersiveFullViewTimer();
  }

  Future<void> _setPlayerScreenMode(PlayerScreenMode mode) async {
    if (_playerScreenMode == mode) return;
    setState(() {
      _playerScreenMode = mode;
      if (mode != PlayerScreenMode.immersive) _isImmersiveFullView = false;
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
        setState(() => _isImmersiveFullView = true);
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

  Future<void> _handleToggleVisualization(bool value) async {
    if (!value) {
      _setVisualizationMode(false);
      return;
    }
    final source = ref.read(visualizerSourceProvider);
    if (source.mode == VisualizerSourceMode.unavailable ||
        source.mode == VisualizerSourceMode.dsdUnavailable) {
      await _showVisualizerUnavailableSheet(source.mode);
      return;
    }
    if (source.needsPermission) {
      final l10n = context.l10n.englishForFilipino;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.visualizerStandardMicTitle),
          content: Text(l10n.visualizerStandardMicBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.continueLabel),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final ready = await source.prepare();
    if (!ready) {
      if (mounted) {
        _showVisualizerSnack(
          context.l10n.englishForFilipino.visualizerPermissionDenied,
        );
      }
      return;
    }
    if (mounted) _setVisualizationMode(true);
  }

  Future<void> _showVisualizerUnavailableSheet(
    VisualizerSourceMode mode,
  ) async {
    final l10n = context.l10n.englishForFilipino;
    final isDsd = mode == VisualizerSourceMode.dsdUnavailable;
    final title = isDsd
        ? l10n.visualizerUnavailableDsdTitle
        : l10n.visualizerUnavailableBitPerfectTitle;
    final body = isDsd
        ? l10n.visualizerUnavailableDsdBody
        : l10n.visualizerUnavailableBitPerfectBody;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(LucideIcons.lock, size: 30, color: AppColors.accent),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                if (!isDsd) ...[
                  FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_switchToHighQualityForVisualizer());
                    },
                    child: Text(l10n.visualizerSwitchToHighQuality),
                  ),
                  const SizedBox(height: 6),
                ],
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(
                    isDsd ? l10n.close : l10n.visualizerKeepBitPerfect,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchToHighQualityForVisualizer() async {
    final l10n = context.l10n.englishForFilipino;
    final engine = _playerService.currentEngineType;
    final wasUsbBitPerfect =
        engine == AudioEngineType.usbDacExperimental &&
        _playerService.isBitPerfectModeEnabled;
    final wasDapBitPerfect =
        engine == AudioEngineType.dapInternalHighRes &&
        _playerService.isBitPerfectModeEnabled;
    try {
      await _playerService.setAudioEnginePreference(
        AudioEnginePreference.rustOboe,
      );
      if (wasUsbBitPerfect) {
        await ref.read(uac2ServiceProvider).setBitPerfectEnabled(false);
        ref.invalidate(uac2BitPerfectEnabledProvider);
        ref.invalidate(uac2ExclusiveDacModeProvider);
      }
      if (wasDapBitPerfect) {
        await _playerService.setDapBitPerfectEnabled(false);
      }
      ref.invalidate(audioEnginePreferenceProvider);
      if (!mounted) return;
      _showVisualizerSnack(
        '${l10n.restartRequired} ${l10n.yourNewAudioEngineIsReady}',
      );
    } catch (e) {
      devLog('[Visualizer] failed to switch engine: $e');
      if (mounted) {
        _showVisualizerSnack(l10n.visualizerPermissionDenied);
      }
    }
  }

  void _showVisualizerSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleVisualizerAvailabilityChanged() {
    if (!mounted || !_isVisualizationMode) return;
    final engine = _playerService.currentEngineType;
    final dsd = _playerService.isCurrentTrackDoP;
    final blocked =
        engine == AudioEngineType.usbDacExperimental ||
        engine == AudioEngineType.dapInternalHighRes ||
        dsd;
    if (!blocked) return;
    setState(() => _isVisualizationMode = false);
    final l10n = context.l10n.englishForFilipino;
    _showVisualizerSnack(
      dsd ? l10n.visualizerPausedDsd : l10n.visualizerPausedBitPerfect,
    );
  }

  void _handleImmersiveSceneTap() {
    if (_playerScreenMode != PlayerScreenMode.immersive) return;
    if (_isLyricsMode) return;
    setState(() => _isImmersiveFullView = !_isImmersiveFullView);
    _refreshImmersiveFullViewTimer();
  }

  Future<void> _animateToNextSong() async {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    final carousel = _carouselKey.currentState;
    if (carousel != null && !_isVinylRotationActive) {
      await carousel.animateToNext();
    } else {
      await _playerService.next();
    }
  }

  Future<void> _animateToPreviousSong() async {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    // Button: restart if >3s, else slide to previous track
    if (_playerService.positionNotifier.value.inSeconds > 3) {
      await _playerService.previous(allowRestart: true);
      return;
    }
    final carousel = _carouselKey.currentState;
    if (carousel != null && !_isVinylRotationActive) {
      await carousel.animateToPrevious();
    } else {
      await _playerService.previous(allowRestart: false);
    }
  }

  Future<void> _handleCarouselNext() async {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    await _playerService.next();
  }

  Future<void> _handleCarouselPrevious() async {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = null;
    // Swipe/slide: always go to previous track, ignoring >3s restart rule
    await _playerService.previous(allowRestart: false);
  }

  void _updateTopBarTextMeasurement(Song? song) {
    if (!mounted || song == null) return;
    final text = '${song.title} - ${song.artist}';
    final fontSize = context.responsiveText(
      context.responsive(13.0, 14.0, 15.0),
    );
    if (_cachedTopBarText == text && _cachedTopBarFontSize == fontSize) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _topBarTextFontFamily,
          fontFamilyFallback: AppTheme.fontFamilyFallback,
          fontSize: fontSize,
          fontWeight: _topBarTextFontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _cachedTopBarText = text;
    _cachedTopBarFontSize = fontSize;
    textPainter.width; // measure kept for future use
  }

  void _showUsbVolumePopup(BuildContext context) {
    _dismissVolumePopup?.call();
    _dismissVolumePopup = showIsoVolumePopup(context, _usbVolumeButtonKey);
  }

  // ---------------------------------------------------------------------------
  // Background (static, not sliding)
  // ---------------------------------------------------------------------------

  Widget _buildBackground(
    BuildContext context,
    Song song,
    AlbumColorMode albumColorMode,
    Color? albumColor,
    bool visualizationMode,
    String visStyle,
    String visFreq,
    String visMove,
    bool animatedArtwork,
    ImmersiveBackgroundStyle backgroundStyle,
  ) {
    final bgBlend = albumColorMode.backgroundBlend;
    final hasAlbumTint = albumColor != null && bgBlend > 0;
    final scrimColor = hasAlbumTint
        ? Color.lerp(
            Colors.black,
            albumColor,
            (bgBlend * 1.2).clamp(0.0, 0.35),
          )!
        : Colors.black;
    return Stack(
      children: [
        Positioned.fill(
          child: _buildBaseBackground(
            context,
            song,
            albumColorMode,
            albumColor,
            visualizationMode,
            visStyle,
            visFreq,
            visMove,
            animatedArtwork,
            backgroundStyle,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: AppConstants.animationNormal,
              opacity: _isLyricsMode ? 1.0 : 0.0,
              child: AnimatedContainer(
                duration: AppConstants.animationNormal,
                color: scrimColor.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaseBackground(
    BuildContext context,
    Song song,
    AlbumColorMode albumColorMode,
    Color? albumColor,
    bool visualizationMode,
    String visStyle,
    String visFreq,
    String visMove,
    bool animatedArtwork,
    ImmersiveBackgroundStyle backgroundStyle,
  ) {
    final bgBlend = albumColorMode.backgroundBlend;
    final hasAlbumTint = albumColor != null && bgBlend > 0;
    final useBlurGradient =
        backgroundStyle == ImmersiveBackgroundStyle.blurGradient;
    // In the side-by-side immersive layout the controls own the right pane, so
    // the scrim/blur needs to deepen toward that edge instead of the bottom.
    final sideImmersiveLayout =
        _playerScreenMode == PlayerScreenMode.immersive &&
        !_isImmersiveFullView &&
        AdaptiveLayout.usePlayerSideLayout(MediaQuery.sizeOf(context));

    if (visualizationMode &&
        _playerScreenMode != PlayerScreenMode.artworkCard) {
      final overlayColor = hasAlbumTint
          ? albumSurface(albumColor, bgBlend * 0.5)
          : const Color(0xFF0A0A0A);
      return Stack(
        children: [
          Positioned.fill(
            child: AudioVisualizer(
              playerService: _playerService,
              animationStyle: visStyle,
              frequencyMode: visFreq,
              movementMode: visMove,
              albumColor: albumColor,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: sideImmersiveLayout
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          overlayColor.withValues(alpha: 0.35),
                          overlayColor.withValues(alpha: 0.75),
                        ],
                        stops: const [0.0, 0.42, 0.68, 1.0],
                      )
                    : LinearGradient(
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

    if (_playerScreenMode == PlayerScreenMode.artworkCard) {
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
                    child: const Center(
                      child: FlickArtworkPlaceholder(size: 96, opacity: 0.22),
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
                            ? albumSurface(albumColor, bgBlend)
                            : const Color(0xFF080808))
                        .withValues(alpha: 0.5),
                    (hasAlbumTint
                            ? albumSurface(albumColor, bgBlend * 0.6)
                            : const Color(0xFF0E0E0E))
                        .withValues(alpha: 0.32),
                    (hasAlbumTint
                            ? albumSurface(albumColor, bgBlend)
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

    final gradientBase = hasAlbumTint
        ? albumSurface(albumColor, bgBlend)
        : const Color(0xFF121212);
    final gradientColors = _isImmersiveFullView
        ? [
            gradientBase.withValues(alpha: 0.3),
            gradientBase.withValues(alpha: 0.25),
            gradientBase.withValues(alpha: 0.2),
            gradientBase.withValues(alpha: 0.15),
            gradientBase.withValues(alpha: 0.08),
            Colors.transparent,
          ]
        : useBlurGradient
        ? [
            gradientBase.withValues(alpha: 0.72),
            gradientBase.withValues(alpha: 0.58),
            gradientBase.withValues(alpha: 0.42),
            gradientBase.withValues(alpha: 0.24),
            gradientBase.withValues(alpha: 0.1),
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
    final placeholder = Container(
      color: AppColors.background,
      child: const Center(
        child: FlickArtworkPlaceholder(size: 96, opacity: 0.35),
      ),
    );
    final hasArtwork = song.albumArt != null || song.filePath != null;
    final artLayer = animatedArtwork && hasArtwork
        ? AnimatedAlbumArt(
            imagePath: song.albumArt,
            audioSourcePath: song.filePath,
            dominantColor: albumColor,
            placeholder: placeholder,
            errorWidget: placeholder,
            albumName: song.album,
            artistName:
                (song.albumArtist != null &&
                    song.albumArtist!.trim().isNotEmpty)
                ? song.albumArtist
                : song.artist,
            representativeSongTitle: song.title,
            preferVertical: true,
            // In the standard layout the art card carries Motion Art; only the
            // immersive full-bleed view needs a second video layer.
            motionEnabled: _isImmersiveFullView,
          )
        : CachedImageWidget(
            imagePath: song.albumArt,
            audioSourcePath: song.filePath,
            fit: BoxFit.cover,
            placeholder: placeholder,
            errorWidget: placeholder,
          );
    return Stack(
      children: [
        Positioned.fill(child: artLayer),
        if (useBlurGradient)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: AppConstants.animationNormal,
                opacity: _isImmersiveFullView ? 0.0 : 1.0,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: sideImmersiveLayout
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    end: sideImmersiveLayout
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white,
                    ],
                    stops: const [0.0, 0.42, 0.82],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: AmbientBackground(
                    song: song,
                    imageOpacity: 1.0,
                    scrimOpacity: 0.0,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: AnimatedContainer(
            duration: AppConstants.animationNormal,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: sideImmersiveLayout
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                end: sideImmersiveLayout
                    ? Alignment.centerLeft
                    : Alignment.topCenter,
                colors: gradientColors,
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top chrome (pinned)
  // ---------------------------------------------------------------------------

  Widget _buildTopChrome(
    BuildContext context,
    Song song,
    Color? albumColor,
    AlbumColorMode albumColorMode,
    dynamic appPrefs,
  ) {
    final hideQueueBadge =
        PlayerActionButtonX.fromStorageValue(appPrefs.leftActionButton) ==
            PlayerActionButton.queue ||
        PlayerActionButtonX.fromStorageValue(appPrefs.rightActionButton) ==
            PlayerActionButton.queue ||
        PlayerActionButtonX.fromStorageValue(appPrefs.leftTopActionButton) ==
            PlayerActionButton.queue ||
        PlayerActionButtonX.fromStorageValue(appPrefs.rightTopActionButton) ==
            PlayerActionButton.queue;
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
            albumColor: albumColor,
            albumColorMode: albumColorMode,
            onTap: () => _close(context),
          ),
          SizedBox(width: context.responsive(8.0, 10.0, 12.0)),
          Expanded(
            child: GestureDetector(
              onTap: song.isFromLocker
                  ? null
                  : () => _navigation.openQueue(context),
              onHorizontalDragEnd: song.isFromLocker
                  ? null
                  : (details) async {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! < -400) {
                        await _navigation.queueSong(context, song);
                      }
                    },
              child: ValueListenableBuilder<List<Song>>(
                valueListenable: _playerService.upNextNotifier,
                builder: (context, upNext, _) {
                  final hasQueue = upNext.isNotEmpty;
                  final fromLocker = song.isFromLocker;
                  final nowPlayingContent = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BaybayinText(
                        label: BaybayinLabel.playing,
                        fallback: context.l10n.isFilipino
                            ? context.l10n.playingLabel
                            : l10n.nowPlaying,
                        style: TextStyle(
                          fontFamily: 'GoogleSansFlex',
                          fontSize: context.responsive(12.0, 13.0, 14.0),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (fromLocker) ...[
                        SizedBox(height: context.responsive(2.0, 3.0, 4.0)),
                        Text(
                          l10n.openedFromLocker,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: context.responsive(10.0, 10.5, 11.0),
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  );
                  final chip = AnimatedContainer(
                    duration: AppConstants.animationFast,
                    padding: EdgeInsets.fromLTRB(
                      context.responsive(12.0, 14.0, 16.0),
                      context.responsive(6.0, 7.0, 8.0),
                      (!fromLocker && !hideQueueBadge)
                          ? context.responsive(10.0, 11.0, 12.0)
                          : context.responsive(12.0, 14.0, 16.0),
                      context.responsive(6.0, 7.0, 8.0),
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
                  return Align(alignment: Alignment.center, child: chip);
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
                albumColor: albumColor,
                albumColorMode: albumColorMode,
                onTap: () => SongActionsSheet.show(
                  context,
                  playerService: _playerService,
                  song: song,
                  isVisualizationMode: _isVisualizationMode,
                  onShowLyrics: () => _setLyricsMode(true),
                  onToggleVisualization: _handleToggleVisualization,
                  onShowPlayerLayout: (ctx) => PlayerLayoutSheet.show(
                    ctx,
                    playerService: _playerService,
                    currentMode: _playerScreenMode,
                    onModeChanged: _setPlayerScreenMode,
                    song: _playerService.currentSongNotifier.value,
                  ),
                  navigation: _navigation,
                ),
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
        unawaited(
          _externalPlaybackService.returnToLocker().then((returned) {
            if (!returned && context.mounted) Navigator.of(context).pop();
          }),
        );
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
              l10n.backToLocker,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
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
            count > 0
                ? l10n.englishForFilipino.queue2(count)
                : l10n.englishForFilipino.queue,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
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
    Color? albumColor,
    AlbumColorMode? albumColorMode,
  }) {
    final surfaceColor = (albumColor != null && albumColorMode != null)
        ? albumSurface(albumColor, albumColorMode.surfaceBlend)
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

  /// Pinned waveform — stays fixed while carousel slides art+identity.
  /// Lazy-loads for current song only; peek stages no longer build waveforms.
  /// Always builds LyricsModeWaveformStrip so the WaveformLayer inside keeps
  /// its state (no re-appear animation / peaks reload) when lyrics toggle.
  Widget _buildPinnedWaveform(
    BuildContext context,
    Song song,
    PlayerScreenMode mode, {
    double? horizontalPadding,
  }) {
    final isImmersive = mode == PlayerScreenMode.immersive;
    // Lyrics uses the strip for immersive (waveform + dismiss arrow) but the
    // time labels are now unified as a single pinned default for BOTH
    // immersive and artworkCard when lyrics are on. Hide strip's internal
    // labels and PlayerControls's labels; keep one under waveform.
    return LyricsModeWaveformStrip(
      playerService: _playerService,
      positionNotifier: _throttledPositionNotifier,
      currentSong: song,
      formatDuration: formatDuration,
      horizontalPadding:
          horizontalPadding ??
          (isImmersive
              ? context.responsive(18.0, 24.0, 30.0)
              : context.responsive(16.0, 20.0, 24.0)),
      onSwipeUp: () => _setLyricsMode(false),
      showTimeLabels: false,
      showArrow: _isLyricsMode && isImmersive,
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
    final immersiveBackgroundStyle = ImmersiveBackgroundStyleX.fromStorageValue(
      appPrefs.immersiveBackgroundStyle,
    );

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
        if (ref.read(tutorialProvider).active) {
          ref.read(tutorialProvider.notifier).skip();
          return;
        }
        _close(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ValueListenableBuilder<Song?>(
          valueListenable: _playerService.currentSongNotifier,
          builder: (context, song, _) {
            if (song == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).pop();
              });
              return const SizedBox.shrink();
            }

            final showImmersiveFullView =
                _isImmersiveFullView &&
                _playerScreenMode == PlayerScreenMode.immersive;
            final showVisualizerOnly =
                _isVisualizationMode &&
                appPrefs.visualizerEnabled &&
                showImmersiveFullView;

            // Outer vertical-dismiss gesture (kept). Horizontal is now inside carousel.
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _handleImmersiveSceneTap,
              onVerticalDragStart: (details) {
                if (_isVinylRotationActive || _isCarouselDragging) return;
                final screenHeight = MediaQuery.sizeOf(context).height;
                if (details.globalPosition.dy >=
                    screenHeight - _backGestureEdgeWidth) {
                  _dragOffset = 0.0;
                  return;
                }
                _dragController.stop();
              },
              onVerticalDragUpdate: (details) {
                if (_isVinylRotationActive || _isCarouselDragging) return;
                if (details.delta.dy > 0) {
                  final now = DateTime.now();
                  if (now.difference(_lastDragUpdate).inMilliseconds < 16) {
                    return;
                  }
                  _lastDragUpdate = now;
                  _dragOffset = (_dragOffset + details.delta.dy).clamp(
                    0.0,
                    1000.0,
                  );
                  _dragController.value = _dragOffset;
                }
              },
              onVerticalDragEnd: (details) {
                if (_isVinylRotationActive || _isCarouselDragging) return;
                if (_dragOffset > 100 || details.primaryVelocity! > 500) {
                  _close(context);
                  return;
                }
                _dragOffset = 0.0;
                _dragController.animateTo(0.0);
              },
              child: AnimatedBuilder(
                animation: _dragController,
                builder: (context, child) {
                  final offset = _dragController.value * 0.5;
                  return Transform.translate(
                    offset: Offset(0, offset),
                    child: child!,
                  );
                },
                child: _buildPlayerBody(
                  context,
                  song,
                  appPrefs,
                  colorMode,
                  albumColor,
                  visStyle,
                  visFreq,
                  visMove,
                  showImmersiveFullView,
                  showVisualizerOnly,
                  immersiveBackgroundStyle,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerBody(
    BuildContext context,
    Song song,
    dynamic appPrefs,
    AlbumColorMode colorMode,
    Color? albumColor,
    String visStyle,
    String visFreq,
    String visMove,
    bool showImmersiveFullView,
    bool showVisualizerOnly,
    ImmersiveBackgroundStyle backgroundStyle,
  ) {
    final visualizationMode =
        _isVisualizationMode && appPrefs.visualizerEnabled;
    final visualizerMode = ref.watch(
      visualizerSourceProvider.select((source) => source.mode),
    );

    // Shared action-row builder for stages and the pinned overlay. The
    // landscape pane passes `compact: true` for a single short row.
    Widget buildActionRow(
      Song s,
      bool lm,
      PlayerScreenMode mode, {
      bool compact = false,
    }) {
      return PlayerActionButtonRow(
        compact: compact,
        song: s,
        lyricsMode: lm,
        isVisualizationMode: _isVisualizationMode,
        playerScreenMode: mode,
        albumColor: albumColor,
        albumColorMode: colorMode,
        leftTopAction: PlayerActionButtonX.fromStorageValue(
          appPrefs.leftTopActionButton,
        ),
        leftAction: PlayerActionButtonX.fromStorageValue(
          appPrefs.leftActionButton,
        ),
        rightTopAction: PlayerActionButtonX.fromStorageValue(
          appPrefs.rightTopActionButton,
        ),
        rightAction: PlayerActionButtonX.fromStorageValue(
          appPrefs.rightActionButton,
        ),
        playerService: _playerService,
        favoritesService: _favoritesService,
        onToggleLyrics: () => setState(() => _isLyricsMode = !lm),
        onToggleVisualization: _handleToggleVisualization,
        visualizerUnavailable:
            visualizerMode == VisualizerSourceMode.unavailable ||
            visualizerMode == VisualizerSourceMode.dsdUnavailable,
        onOpenQueue: (ctx) => _navigation.openQueue(ctx),
        usbVolumeButtonKey: _usbVolumeButtonKey,
        onShowUsbVolumePopup: (ctx) => _showUsbVolumePopup(ctx),
      );
    }

    Widget fileInfoBuilder(Song s, bool lm, PlayerScreenMode mode) =>
        buildActionRow(s, lm, mode);

    // Overlay shows over the stage's reserved invisible row slot.
    final showPinnedActionRow = _playerScreenMode == PlayerScreenMode.immersive
        ? (appPrefs.immersiveShowFileInfo && !_isLyricsMode)
        : appPrefs.artworkCardShowFileInfo;
    // Match the stage's own row padding so the overlay lines up exactly.
    final pinnedActionRowPadding =
        _playerScreenMode == PlayerScreenMode.immersive
        ? context.responsive(12.0, 16.0, 20.0)
        : (MediaQuery.sizeOf(context).width < 360
              ? 16.0
              : context.responsive(20.0, 28.0, 36.0));

    // Background is always behind
    final background = _buildBackground(
      context,
      song,
      colorMode,
      albumColor,
      visualizationMode,
      visStyle,
      visFreq,
      visMove,
      appPrefs.animatedAlbumArt && appPrefs.animationsEnabled,
      backgroundStyle,
    );

    if (showVisualizerOnly) {
      // Full-bleed visualizer, tap to exit full-view
      return Stack(
        children: [
          Positioned.fill(child: background),
          // keep top chrome hidden in full-view; still allow tap to exit
        ],
      );
    }

    if (showImmersiveFullView) {
      // Minimal bottom card — no top chrome, no pinned controls
      return Stack(
        children: [
          Positioned.fill(child: background),
          SafeArea(
            child: ValueListenableBuilder<List<Song>>(
              valueListenable: _playerService.upNextNotifier,
              builder: (context, upNext, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _playerService.currentIndexNotifier,
                  builder: (context, idx, _) {
                    final prev = _playerService.peekPrevious;
                    final next = _playerService.peekNext;
                    return SongStageCarousel(
                      key: _carouselKey,
                      currentSong: song,
                      prevSong: prev,
                      nextSong: next,
                      enabled: !_isVinylRotationActive,
                      onDragStateChanged: (v) => _isCarouselDragging = v,
                      onNext: _handleCarouselNext,
                      onPrevious: _handleCarouselPrevious,
                      stageBuilder: (s) {
                        final isCurrent = s.id == song.id;
                        return SongStage(
                          song: s,
                          lyricsMode: _isLyricsMode,
                          visualizationMode: visualizationMode,
                          immersiveFullView: true,
                          playerScreenMode: _playerScreenMode,
                          albumColorMode: colorMode,
                          albumColor: albumColor,
                          playerService: _playerService,
                          lyricsService: _lyricsService,
                          positionNotifier: isCurrent
                              ? _throttledPositionNotifier
                              : _zeroPosition,
                          formatDuration: formatDuration,
                          onNavigateToArtistDetail: (s) =>
                              _navigation.openArtistFromSong(context, s),
                          onNavigateToAlbumDetail: (s) =>
                              _navigation.openAlbumFromSong(context, s),
                          buildFileInfoRow: fileInfoBuilder,
                          visualizerAnimationStyle: visStyle,
                          visualizerFrequencyMode: visFreq,
                          visualizerMovementMode: visMove,
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
                          immersiveShowFileInfo: appPrefs.immersiveShowFileInfo,
                          onRotationEnabledChanged: (enabled) {
                            _isVinylRotationActive = enabled;
                          },
                          vinylMode: _isVinylMode,
                          onVinylChanged: (v) => _isVinylMode = v,
                          onToggleLyrics: () => _setLyricsMode(!_isLyricsMode),
                          showWaveform: false,
                          motionArtEnabled: isCurrent,
                          active: isCurrent,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    if (AdaptiveLayout.usePlayerSideLayout(MediaQuery.sizeOf(context))) {
      return Stack(
        children: [
          Positioned.fill(child: background),
          SafeArea(
            child: _buildLandscapeLayout(
              context,
              song,
              appPrefs,
              colorMode,
              albumColor,
              visStyle,
              visFreq,
              visMove,
              visualizationMode,
              (s) => buildActionRow(
                s,
                _isLyricsMode,
                _playerScreenMode,
                compact: true,
              ),
            ),
          ),
        ],
      );
    }

    // Default: pinned top chrome + sliding stage + pinned controls
    return Stack(
      children: [
        Positioned.fill(child: background),
        SafeArea(
          child: Column(
            children: [
              const Uac2ErrorNotification(),
              _buildTopChrome(context, song, albumColor, colorMode, appPrefs),
              SizedBox(height: context.responsive(8.0, 10.0, 12.0)),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ValueListenableBuilder<List<Song>>(
                        valueListenable: _playerService.upNextNotifier,
                        builder: (context, upNext, _) {
                          return ValueListenableBuilder<int>(
                            valueListenable:
                                _playerService.currentIndexNotifier,
                            builder: (context, idx, _) {
                              final prev = _playerService.peekPrevious;
                              final next = _playerService.peekNext;
                              // Precache adjacent artwork for buttery peek
                              final nextArt = next?.albumArt;
                              if (nextArt != null) {
                                precacheImage(
                                  FileImage(File(nextArt)),
                                  context,
                                  onError: (_, __) {},
                                );
                              }
                              return SongStageCarousel(
                                key: _carouselKey,
                                currentSong: song,
                                prevSong: prev,
                                nextSong: next,
                                enabled: !_isVinylRotationActive,
                                onDragStateChanged: (v) =>
                                    _isCarouselDragging = v,
                                onNext: _handleCarouselNext,
                                onPrevious: _handleCarouselPrevious,
                                stageBuilder: (s) {
                                  final isCurrent = s.id == song.id;
                                  return SongStage(
                                    song: s,
                                    lyricsMode: _isLyricsMode,
                                    visualizationMode: visualizationMode,
                                    immersiveFullView: false,
                                    playerScreenMode: _playerScreenMode,
                                    albumColorMode: colorMode,
                                    albumColor: albumColor,
                                    playerService: _playerService,
                                    lyricsService: _lyricsService,
                                    positionNotifier: isCurrent
                                        ? _throttledPositionNotifier
                                        : _zeroPosition,
                                    formatDuration: formatDuration,
                                    onNavigateToArtistDetail: (s) => _navigation
                                        .openArtistFromSong(context, s),
                                    onNavigateToAlbumDetail: (s) => _navigation
                                        .openAlbumFromSong(context, s),
                                    buildFileInfoRow: fileInfoBuilder,
                                    fileInfoRowVisible: false,
                                    visualizerAnimationStyle: visStyle,
                                    visualizerFrequencyMode: visFreq,
                                    visualizerMovementMode: visMove,
                                    motionArtEnabled: isCurrent,
                                    artworkCardArtworkScale:
                                        appPrefs.artworkCardArtworkScale,
                                    artworkCardTextScale:
                                        appPrefs.artworkCardTextScale,
                                    artworkCardVerticalOffset:
                                        appPrefs.artworkCardVerticalOffset,
                                    artworkCardArtworkOffset:
                                        appPrefs.artworkCardArtworkOffset,
                                    artworkCardShowTitle:
                                        appPrefs.artworkCardShowTitle,
                                    artworkCardShowArtist:
                                        appPrefs.artworkCardShowArtist,
                                    artworkCardShowAlbum:
                                        appPrefs.artworkCardShowAlbum,
                                    artworkCardShowFileInfo:
                                        appPrefs.artworkCardShowFileInfo,
                                    artworkCardShowFrame:
                                        appPrefs.artworkCardShowFrame,
                                    immersiveTextScale:
                                        appPrefs.immersiveTextScale,
                                    immersiveVerticalOffset:
                                        appPrefs.immersiveVerticalOffset,
                                    immersiveFullViewScale:
                                        appPrefs.immersiveFullViewScale,
                                    immersiveShowTitle:
                                        appPrefs.immersiveShowTitle,
                                    immersiveShowArtist:
                                        appPrefs.immersiveShowArtist,
                                    immersiveShowFileInfo:
                                        appPrefs.immersiveShowFileInfo,
                                    onRotationEnabledChanged: (enabled) {
                                      _isVinylRotationActive = enabled;
                                    },
                                    vinylMode: _isVinylMode,
                                    onVinylChanged: (v) => _isVinylMode = v,
                                    onToggleLyrics: () =>
                                        _setLyricsMode(!_isLyricsMode),
                                    showWaveform: false,
                                    active: isCurrent,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (showPinnedActionRow)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: pinnedActionRowPadding,
                          ),
                          child: fileInfoBuilder(
                            song,
                            _isLyricsMode,
                            _playerScreenMode,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Pinned waveform — not sliding, lazy-loads current song only.
              // Mirrors the gap SongStage previously had before its waveform.
              Builder(
                builder: (context) {
                  final isImmersive =
                      _playerScreenMode == PlayerScreenMode.immersive;
                  double topGap;
                  if (_isLyricsMode && isImmersive) {
                    topGap = context.responsive(10.0, 12.0, 14.0);
                  } else if (isImmersive) {
                    topGap = context.responsive(12.0, 14.0, 16.0);
                  } else {
                    // artworkCard gap before waveform (playbackSpacing)
                    final isVeryShort = MediaQuery.sizeOf(context).height < 540;
                    topGap = appPrefs.artworkCardShowFileInfo
                        ? (isVeryShort
                              ? 10.0
                              : context.responsive(14.0, 16.0, 18.0))
                        : context.responsive(8.0, 10.0, 12.0);
                  }
                  final timeLabelsPadding = isImmersive
                      ? context.responsive(18.0, 24.0, 30.0)
                      : context.responsive(16.0, 20.0, 24.0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        height: topGap,
                      ),
                      _buildPinnedWaveform(context, song, _playerScreenMode),
                      // Unified default: when lyrics are on, keep single time
                      // labels under waveform for BOTH immersive and artworkCard.
                      // This replaces the duplicated labels previously inside
                      // PlayerControls and (for immersive) inside the strip.
                      // AnimatedSize so the waveform lowers/raises smoothly.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _isLyricsMode
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: context.responsive(8.0, 10.0, 12.0),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: timeLabelsPadding,
                                    ),
                                    child: ValueListenableBuilder<Duration>(
                                      valueListenable:
                                          _playerService.positionNotifier,
                                      builder: (context, position, _) {
                                        return ValueListenableBuilder<Duration>(
                                          valueListenable:
                                              _playerService.durationNotifier,
                                          builder:
                                              (context, engineDuration, _) {
                                                final duration =
                                                    engineDuration
                                                            .inMilliseconds >
                                                        0
                                                    ? engineDuration
                                                    : (song.duration);
                                                return PlaybackTimeLabels(
                                                  position: position,
                                                  duration: duration,
                                                  formatDuration:
                                                      formatDuration,
                                                  horizontalPadding:
                                                      timeLabelsPadding,
                                                );
                                              },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
              // Gap between pinned waveform/time-labels and controls.
              // When lyrics are open we keep only the one under the waveform,
              // so tighten the gap and hide the duplicate inside PlayerControls.
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                height: _isLyricsMode
                    ? context.responsive(10.0, 12.0, 14.0)
                    : context.responsive(14.0, 16.0, 18.0),
              ),
              // Pinned controls — do not slide. Deduplicate time labels:
              // immersive lyrics keeps strip's labels, artworkCard lyrics keeps
              // the pinned labels just above (under waveform). Hide duplicate
              // inside PlayerControls when lyrics are open.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _playerScreenMode == PlayerScreenMode.immersive
                      ? context.responsive(18.0, 24.0, 30.0)
                      : context.responsive(16.0, 20.0, 24.0),
                ),
                child: PlayerControls(
                  playerService: _playerService,
                  formatDuration: formatDuration,
                  currentSong: song,
                  onPrevious: _animateToPreviousSong,
                  onNext: _animateToNextSong,
                  timelineHorizontalPadding:
                      _playerScreenMode == PlayerScreenMode.immersive
                      ? context.responsive(18.0, 24.0, 30.0)
                      : context.responsive(16.0, 20.0, 24.0),
                  albumColorMode: colorMode,
                  albumColor: albumColor,
                  showTimeLabels: !_isLyricsMode,
                ),
              ),
              // Original bottom spacing: immersive 24-40, artworkCard directorySpacing 24-40
              SizedBox(height: context.responsive(24.0, 32.0, 40.0)),
            ],
          ),
        ),
      ],
    );
  }

  /// Wide, short window: square stage on the left, pinned playback on the
  /// right. Both player styles keep their own identity instead of being
  /// squeezed into the portrait column.
  Widget _buildLandscapeLayout(
    BuildContext context,
    Song song,
    dynamic appPrefs,
    AlbumColorMode colorMode,
    Color? albumColor,
    String visStyle,
    String visFreq,
    String visMove,
    bool visualizationMode,
    Widget Function(Song song) actionRowBuilder,
  ) {
    final isArtwork = _playerScreenMode == PlayerScreenMode.artworkCard;
    final showActions = isArtwork
        ? appPrefs.artworkCardShowFileInfo
        : appPrefs.immersiveShowFileInfo;

    final leftPane = _isLyricsMode
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
            child: InlineLyricsPanel(
              song: song,
              playerService: _playerService,
              lyricsService: _lyricsService,
              albumColor: albumColor,
              positionNotifier: _throttledPositionNotifier,
              active: true,
            ),
          )
        : ValueListenableBuilder<List<Song>>(
            valueListenable: _playerService.upNextNotifier,
            builder: (context, upNext, _) {
              return ValueListenableBuilder<int>(
                valueListenable: _playerService.currentIndexNotifier,
                builder: (context, idx, _) {
                  final prev = _playerService.peekPrevious;
                  final next = _playerService.peekNext;
                  return SongStageCarousel(
                    key: _carouselKey,
                    currentSong: song,
                    prevSong: prev,
                    nextSong: next,
                    enabled: !_isVinylRotationActive,
                    onDragStateChanged: (v) => _isCarouselDragging = v,
                    onNext: _handleCarouselNext,
                    onPrevious: _handleCarouselPrevious,
                    stageBuilder: (s) {
                      final isCurrent = s.id == song.id;
                      return SongStage(
                        song: s,
                        pane: isArtwork
                            ? SongStagePane.artworkOnly
                            : SongStagePane.backdropOnly,
                        lyricsMode: _isLyricsMode,
                        visualizationMode: visualizationMode,
                        immersiveFullView: false,
                        playerScreenMode: _playerScreenMode,
                        albumColorMode: colorMode,
                        albumColor: albumColor,
                        playerService: _playerService,
                        lyricsService: _lyricsService,
                        positionNotifier: isCurrent
                            ? _throttledPositionNotifier
                            : _zeroPosition,
                        formatDuration: formatDuration,
                        onNavigateToArtistDetail: (s) =>
                            _navigation.openArtistFromSong(context, s),
                        onNavigateToAlbumDetail: (s) =>
                            _navigation.openAlbumFromSong(context, s),
                        buildFileInfoRow: (s, _, _) => actionRowBuilder(s),
                        fileInfoRowVisible: false,
                        visualizerAnimationStyle: visStyle,
                        visualizerFrequencyMode: visFreq,
                        visualizerMovementMode: visMove,
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
                        immersiveFullViewScale: appPrefs.immersiveFullViewScale,
                        immersiveShowTitle: appPrefs.immersiveShowTitle,
                        immersiveShowArtist: appPrefs.immersiveShowArtist,
                        immersiveShowFileInfo: appPrefs.immersiveShowFileInfo,
                        onRotationEnabledChanged: (enabled) {
                          _isVinylRotationActive = enabled;
                        },
                        vinylMode: _isVinylMode,
                        onVinylChanged: (v) => _isVinylMode = v,
                        onToggleLyrics: () => _setLyricsMode(!_isLyricsMode),
                        showWaveform: false,
                        motionArtEnabled: isCurrent,
                        active: isCurrent,
                      );
                    },
                  );
                },
              );
            },
          );

    final detailsPane = isArtwork
        ? SongStagePane.artworkCardDetails
        : SongStagePane.immersiveIdentity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          const Uac2ErrorNotification(),
          _buildTopChrome(context, song, albumColor, colorMode, appPrefs),
          const SizedBox(height: 4),
          Expanded(
            child: LandscapePlayerLayout(
              stage: leftPane,
              artworkCard: isArtwork,
              lyricsMode: _isLyricsMode,
              identity: SongStage(
                song: song,
                pane: detailsPane,
                lyricsMode: _isLyricsMode,
                visualizationMode: visualizationMode,
                immersiveFullView: false,
                playerScreenMode: _playerScreenMode,
                albumColorMode: colorMode,
                albumColor: albumColor,
                playerService: _playerService,
                lyricsService: _lyricsService,
                positionNotifier: _throttledPositionNotifier,
                formatDuration: formatDuration,
                onNavigateToArtistDetail: (s) =>
                    _navigation.openArtistFromSong(context, s),
                onNavigateToAlbumDetail: (s) =>
                    _navigation.openAlbumFromSong(context, s),
                buildFileInfoRow: (s, _, _) => actionRowBuilder(s),
                fileInfoRowVisible: false,
                visualizerAnimationStyle: visStyle,
                visualizerFrequencyMode: visFreq,
                visualizerMovementMode: visMove,
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
                onRotationEnabledChanged: (enabled) {
                  _isVinylRotationActive = enabled;
                },
                vinylMode: _isVinylMode,
                onVinylChanged: (v) => _isVinylMode = v,
                onToggleLyrics: () => _setLyricsMode(!_isLyricsMode),
                showWaveform: false,
                motionArtEnabled: true,
                active: true,
              ),
              actions: showActions ? actionRowBuilder(song) : null,
              playback: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPinnedWaveform(
                    context,
                    song,
                    _playerScreenMode,
                    horizontalPadding: 4,
                  ),
                  if (_isLyricsMode) ...[
                    const SizedBox(height: 6),
                    ValueListenableBuilder<Duration>(
                      valueListenable: _playerService.positionNotifier,
                      builder: (context, position, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: _playerService.durationNotifier,
                          builder: (context, engineDuration, _) {
                            final duration = engineDuration.inMilliseconds > 0
                                ? engineDuration
                                : song.duration;
                            return PlaybackTimeLabels(
                              position: position,
                              duration: duration,
                              formatDuration: formatDuration,
                              horizontalPadding: 4,
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  PlayerControls(
                    playerService: _playerService,
                    formatDuration: formatDuration,
                    currentSong: song,
                    onPrevious: _animateToPreviousSong,
                    onNext: _animateToNextSong,
                    timelineHorizontalPadding: 4,
                    albumColorMode: colorMode,
                    albumColor: albumColor,
                    showTimeLabels: !_isLyricsMode,
                    compact: MediaQuery.sizeOf(context).height < 500,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
