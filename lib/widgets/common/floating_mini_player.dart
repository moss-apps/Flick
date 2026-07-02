import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/features/player/screens/full_player_screen.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class FloatingMiniPlayer extends ConsumerStatefulWidget {
  const FloatingMiniPlayer({super.key});

  @override
  ConsumerState<FloatingMiniPlayer> createState() => _FloatingMiniPlayerState();
}

class _FloatingMiniPlayerState extends ConsumerState<FloatingMiniPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _expanded = false;

  static const _heroTag = 'floating_mini_player';

  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  Offset _offset = Offset.zero;
  Offset _startDragOffset = Offset.zero;
  Offset _dragStartPosition = Offset.zero;
  Offset _pointerDownPosition = Offset.zero;
  bool _isDragging = false;
  bool _isLongPress = false;
  Timer? _longPressTimer;
  static const _longPressDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _offset = Offset.zero;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _expandController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(() => _offset = Offset.zero);
  }

  void _onTap() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _isLongPress = false;
    _pointerDownPosition = event.position;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(_longPressDelay, () {
      if (!mounted) return;
      _isLongPress = true;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const FullPlayerScreen(heroTag: _heroTag),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          opaque: false,
          barrierColor: Colors.black,
        ),
      );
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDragging) {
      final delta = event.position - _pointerDownPosition;
      if (delta.distance > 8) {
        _longPressTimer?.cancel();
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    if (_isLongPress || _isDragging) return;
    _onTap();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = false;
    _startDragOffset = _offset;
    _dragStartPosition = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final delta = details.globalPosition - _dragStartPosition;
    if (!_isDragging && delta.distance > 4) {
      _isDragging = true;
    }
    if (_isDragging) {
      final screenSize = MediaQuery.of(context).size;
      final safeArea = MediaQuery.of(context).padding;
      final bottomLimit =
          screenSize.height - 36.0 - safeArea.bottom - safeArea.top - 16;
      setState(() {
        _offset = Offset(
          _startDragOffset.dx + delta.dx,
          (_startDragOffset.dy + delta.dy).clamp(0.0, bottomLimit),
        );
      });
    }
  }

  double _clampHorizontalOffset(Size screenSize) {
    final t = _expandAnimation.value;
    final width = 96.0 + t * 184.0;
    final halfScreen = screenSize.width / 2;
    final halfWidget = width / 2;
    final maxDx = halfScreen - halfWidget - 8;
    return (_offset.dx).clamp(-maxDx, maxDx) / maxDx;
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final velocity = details.velocity.pixelsPerSecond;

    final t = _expandAnimation.value;
    final width = 96.0 + t * 184.0;
    final height = 36.0;

    final double absCenterX =
        (screenSize.width - width) / 2 + _offset.dx + width / 2;
    final bool nearCenterX =
        (absCenterX - screenSize.width / 2).abs() < screenSize.width * 0.25;
    final bool flingCenterX = velocity.dx.abs() < 200 && nearCenterX;

    double snapDx;
    if (flingCenterX) {
      snapDx = 0.0;
    } else if (absCenterX < screenSize.width / 2) {
      snapDx = 8.0 - (screenSize.width - width) / 2;
    } else {
      snapDx = (screenSize.width - width) / 2 - 8.0;
    }

    final bottomLimit =
        screenSize.height - height - safeArea.bottom - safeArea.top - 16;
    final double absTop = safeArea.top + 8 + _offset.dy;
    final bool nearTop = absTop < screenSize.height * 0.25;
    final bool nearBottom =
        absTop > screenSize.height * 0.75 - safeArea.bottom;
    final bool flingVertical = velocity.dy.abs() > 400;

    double snapDy;
    if (flingVertical) {
      if (velocity.dy < 0) {
        snapDy = 0.0;
      } else {
        snapDy = bottomLimit;
      }
    } else if (nearTop) {
      snapDy = 0.0;
    } else if (nearBottom) {
      snapDy = bottomLimit;
    } else {
      snapDy = _offset.dy.clamp(0.0, bottomLimit);
    }

    _isDragging = false;
    setState(() {
      _offset = Offset(snapDx, snapDy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = ref.watch(currentSongProvider);
    if (currentSong == null) return const SizedBox.shrink();

    final appPrefs = ref.watch(appPreferencesProvider);
    if (!appPrefs.floatingIslandEnabled) return const SizedBox.shrink();

    final topPadding = MediaQuery.of(context).padding.top;
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      top: topPadding + 8 + _offset.dy,
      left: 0,
      right: 0,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Align(
            alignment: Alignment(_clampHorizontalOffset(screenSize), 0),
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment(_clampHorizontalOffset(screenSize), 0),
              child: Hero(
                tag: _heroTag,
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, _) {
                    final t = _expandAnimation.value;
                    final width = 96.0 + t * 184.0;

                    return Container(
                      height: 36,
                      width: width,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.glassBorderStrong,
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                ),
                                child: currentSong.albumArt != null
                                    ? CachedImageWidget(
                                        imagePath: currentSong.albumArt!,
                                        fit: BoxFit.cover,
                                        useThumbnail: true,
                                        thumbnailWidth: 96,
                                        thumbnailHeight: 96,
                                      )
                                    : const Icon(
                                        LucideIcons.music,
                                        size: 16,
                                        color: AppColors.textTertiary,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _FloatingMiniVisualizer(),
                            SizedBox(width: t * 10),
                            Expanded(
                              child: Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(8 * (1 - t), 0),
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 14 * t),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currentSong.title,
                                            style: TextStyle(
                                              fontFamily: 'ProductSans',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  context.adaptiveTextPrimary,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            currentSong.artist,
                                            style: TextStyle(
                                              fontFamily: 'ProductSans',
                                              fontSize: 9,
                                              color:
                                                  context.adaptiveTextSecondary,
                                              fontWeight: FontWeight.w500,
                                              height: 1.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingMiniVisualizer extends ConsumerWidget {
  const _FloatingMiniVisualizer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);
    final appPrefs = ref.watch(appPreferencesProvider);

    return SizedBox(
      height: 18,
      width: 40,
      child: AudioVisualizer(
        playerService: playerService,
        animationStyle: appPrefs.visualizerAnimationStyle,
        frequencyMode: appPrefs.visualizerFrequencyMode,
        movementMode: appPrefs.visualizerMovementMode,
        enabled: appPrefs.visualizerEnabled,
      ),
    );
  }
}
