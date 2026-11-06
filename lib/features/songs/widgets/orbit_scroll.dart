import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/models/song.dart';
import 'package:flick/features/songs/widgets/song_card.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class OrbitScrollController {
  void Function(int index, bool animate)? _jumpToIndex;

  void _attach(void Function(int index, bool animate) jumpToIndex) {
    _jumpToIndex = jumpToIndex;
  }

  void _detach() {
    _jumpToIndex = null;
  }

  void jumpToIndex(int index, {bool animate = true}) {
    _jumpToIndex?.call(index, animate);
  }
}

/// Orbital scrolling widget that displays songs in a curved arc.
class OrbitScroll extends StatefulWidget {
  /// List of songs to display
  final List<Song> songs;

  /// Index of the currently selected song
  final int selectedIndex;

  /// Callback when a song is selected
  final ValueChanged<int>? onSongSelected;

  /// Callback when the selected song changes via scrolling
  final ValueChanged<int>? onSelectedIndexChanged;

  /// Callback when a song card is swiped left.
  final ValueChanged<int>? onSongSwipedLeft;

  /// Callback when a song card is swiped right.
  final ValueChanged<int>? onSongSwipedRight;

  /// Whether swipe-to-queue and swipe-to-favorite gestures are enabled.
  final bool swipeActionsEnabled;

  /// Whether multiselect mode is active.
  final bool isSelectionMode;

  /// Set of selected song IDs in multiselect mode.
  final Set<String> selectedIds;

  /// Controller for external jump-to-index actions.
  final OrbitScrollController? controller;

  /// Landscape owns horizontal drags only within its music viewport. The
  /// surrounding header and side gutters remain available to tab navigation.
  final Axis scrollDirection;

  final double radiusRatio;
  final double centerOffsetRatio;
  final double centerYRatio;
  final double itemSpacing;
  final double selectedScale;
  final double depth;
  final int visibleItems;
  final double cardArtSize;
  final double cardWidthRatio;
  final double artResolutionMultiplier;
  final bool showPath;
  final bool showGlow;

  const OrbitScroll({
    super.key,
    required this.songs,
    this.selectedIndex = 0,
    this.onSongSelected,
    this.onSelectedIndexChanged,
    this.onSongSwipedLeft,
    this.onSongSwipedRight,
    this.swipeActionsEnabled = false,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.radiusRatio = 1.0,
    this.centerOffsetRatio = -0.5,
    this.centerYRatio = 0.42,
    this.itemSpacing = 0.28,
    this.selectedScale = 1.25,
    this.depth = 0.75,
    this.visibleItems = 5,
    this.cardArtSize = 64.0,
    this.cardWidthRatio = 0.68,
    this.artResolutionMultiplier = 2.0,
    this.showPath = true,
    this.showGlow = true,
  });

  @override
  State<OrbitScroll> createState() => _OrbitScrollState();
}

class _OrbitScrollState extends State<OrbitScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // The physics state — notifier drives only the song items rebuild
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  // Track if we're actively scrolling to reduce visible range when idle
  bool _isScrolling = false;

  // Debounce timer that flushes deferred artwork extraction after a fling settles.
  Timer? _artworkGateTimer;
  // ponytail: hold at most ONE pause; per-tick pauses with canceled release
  // timers leaked the refcount and froze artwork extraction forever.
  bool _artworkGateHeld = false;
  DateTime _lastScrollTime = DateTime.now();
  int _lastReportedIndex = 0;
  Size? _layoutSize;
  double _dragExtent = 90.0;
  int _animationGeneration = 0;

  // Cache for transform calculations (bounded)
  final Map<int, _Position> _positionCache = {};
  final Map<int, _ItemTransform> _transformCache = {};
  static const int _maxCacheSize = 120;

  // ponytail: recompute each build (~9 ints). Was a static final keyed on
  // AppConstants.orbitVisibleItems; now derives from widget.visibleItems so the
  // user-tunable count takes effect. Upgrade to a memo if this ever shows in a profile.
  List<int> get _orderedIndices {
    final visibleRange = widget.visibleItems ~/ 2;
    return List.generate(visibleRange * 2 + 1, (i) => i - visibleRange)
      ..sort((a, b) => b.abs().compareTo(a.abs()));
  }

  @override
  void initState() {
    super.initState();
    _scrollOffset.value = widget.selectedIndex.toDouble();
    _lastReportedIndex = widget.selectedIndex;
    _controller = AnimationController.unbounded(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _controller.addListener(_onPhysicsTick);
    widget.controller?._attach(_jumpToIndex);
  }

  @override
  void didUpdateWidget(OrbitScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_jumpToIndex);
    }
    // ponytail: invalidate transform/position caches when geometry changes.
    // Caches are keyed by relative index only, so any layout-affecting pref
    // (spacing, scales, depth, sizes) must flush them or stale transforms render.
    if (oldWidget.itemSpacing != widget.itemSpacing ||
        oldWidget.selectedScale != widget.selectedScale ||
        oldWidget.depth != widget.depth ||
        oldWidget.visibleItems != widget.visibleItems ||
        oldWidget.radiusRatio != widget.radiusRatio ||
        oldWidget.centerOffsetRatio != widget.centerOffsetRatio ||
        oldWidget.centerYRatio != widget.centerYRatio ||
        oldWidget.cardArtSize != widget.cardArtSize ||
        oldWidget.cardWidthRatio != widget.cardWidthRatio ||
        oldWidget.scrollDirection != widget.scrollDirection) {
      _transformCache.clear();
      _positionCache.clear();
    }
    if (oldWidget.scrollDirection != widget.scrollDirection ||
        oldWidget.songs.length != widget.songs.length) {
      _animationGeneration++;
      _controller.stop();
      _isScrolling = false;
      _scrollOffset.value = _scrollOffset.value
          .round()
          .clamp(0, math.max(0, widget.songs.length - 1))
          .toDouble();
    }
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _lastReportedIndex = widget.selectedIndex;
      // If the index changed externally, snap/spring to it
      if ((widget.selectedIndex.toDouble() - _scrollOffset.value).abs() >
          0.05) {
        _animateTo(widget.selectedIndex.toDouble());
      }
    }
  }

  @override
  void dispose() {
    _animationGeneration++;
    widget.controller?._detach();
    _controller.dispose();
    _scrollOffset.dispose();
    _artworkGateTimer?.cancel();
    if (_artworkGateHeld) {
      _artworkGateHeld = false;
      pauseArtworkExtraction(false);
    }
    super.dispose();
  }

  void _jumpToIndex(int index, bool animate) {
    if (widget.songs.isEmpty) return;

    final clampedIndex = index.clamp(0, widget.songs.length - 1);
    if (animate) {
      _animateTo(clampedIndex.toDouble());
      return;
    }

    _controller.stop();
    _scrollOffset.value = clampedIndex.toDouble();
    setState(() {
      _isScrolling = false;
      _lastScrollTime = DateTime.now();
    });
    if (_lastReportedIndex != clampedIndex) {
      _lastReportedIndex = clampedIndex;
      widget.onSelectedIndexChanged?.call(clampedIndex);
    }
  }

  void _onPhysicsTick() {
    if (_controller.isAnimating) {
      final newOffset = _controller.value;
      if ((newOffset - _scrollOffset.value).abs() > 0.001) {
        _scrollOffset.value = newOffset;
        _markScrollActive();
        if (!_isScrolling) {
          setState(() {
            _isScrolling = true;
            _lastScrollTime = DateTime.now();
          });
        } else {
          _lastScrollTime = DateTime.now();
        }
      }
    } else if (_isScrolling) {
      final now = DateTime.now();
      if (now.difference(_lastScrollTime).inMilliseconds > 100) {
        setState(() {
          _isScrolling = false;
        });
      }
    }
  }

  // --- Gesture Handling ---

  void _markScrollActive() {
    if (!_artworkGateHeld) {
      _artworkGateHeld = true;
      pauseArtworkExtraction(true);
    }
    _artworkGateTimer?.cancel();
    _artworkGateTimer = Timer(const Duration(milliseconds: 150), () {
      _artworkGateTimer = null;
      if (_artworkGateHeld) {
        _artworkGateHeld = false;
        pauseArtworkExtraction(false);
      }
    });
  }

  void _onDragStart(DragStartDetails details) {
    _animationGeneration++;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.songs.isEmpty) return;
    final delta = details.primaryDelta ?? 0.0;
    if (delta == 0) return;

    final direction = delta > 0
        ? ScrollDirection.forward
        : ScrollDirection.reverse;

    UserScrollNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: widget.songs.length.toDouble(),
        pixels: _scrollOffset.value,
        viewportDimension: 100,
        axisDirection: widget.scrollDirection == Axis.horizontal
            ? AxisDirection.right
            : AxisDirection.down,
        devicePixelRatio: 1.0,
      ),
      context: context,
      direction: direction,
    ).dispatch(context);

    var itemDelta = -(delta / _dragExtent);
    _markScrollActive();

    double newOffset = _scrollOffset.value + itemDelta;
    if (newOffset < -0.5 || newOffset > widget.songs.length - 0.5) {
      itemDelta = itemDelta * 0.4;
      newOffset = _scrollOffset.value + itemDelta;
    }

    if ((newOffset - _scrollOffset.value).abs() > 0.001) {
      _scrollOffset.value = newOffset;
      if (!_isScrolling) {
        setState(() {
          _isScrolling = true;
          _lastScrollTime = DateTime.now();
        });
      } else {
        _lastScrollTime = DateTime.now();
      }
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.songs.isEmpty) return;
    final velocity = details.primaryVelocity ?? 0.0;

    // Dispatch end notification (idle)
    UserScrollNotification(
      metrics: FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: widget.songs.length.toDouble(),
        pixels: _scrollOffset.value,
        viewportDimension: 100,
        axisDirection: widget.scrollDirection == Axis.horizontal
            ? AxisDirection.right
            : AxisDirection.down,
        devicePixelRatio: 1.0,
      ),
      context: context,
      direction: ScrollDirection.idle,
    ).dispatch(context);

    // Pixels per second
    // Convert to items per second
    final velocityItemsPerSec = -velocity / _dragExtent;

    // 1. Predict landing point
    // We use a FrictionSimulation to see where it WOULD land.
    final simulation = FrictionSimulation(
      0.15, // Drag coefficient (higher = stops faster)
      _scrollOffset.value,
      velocityItemsPerSec,
    );

    final finalTime = 2.0; // Simulate far enough ahead
    final projectedOffset = simulation.x(finalTime);

    // 2. Snap to nearest valid item
    final targetIndex = projectedOffset.round().clamp(
      0,
      widget.songs.length - 1,
    );

    // 3. Spring to that target
    _animateTo(targetIndex.toDouble(), velocity: velocityItemsPerSec);
  }

  void _animateTo(double target, {double velocity = 0.0}) {
    final generation = ++_animationGeneration;
    if (MediaQuery.disableAnimationsOf(context)) {
      _jumpToIndex(target.round(), false);
      return;
    }
    // Create a spring simulation from current => target
    final description = SpringDescription.withDampingRatio(
      mass: 1.0,
      stiffness: 100.0, // Reasonable stiffness for UI
      ratio: 1.0, // Critically damped (no bounce unless overshooting)
    );

    final simulation = SpringSimulation(
      description,
      _scrollOffset.value,
      target,
      velocity,
    );

    _controller.animateWith(simulation).whenComplete(() {
      if (!mounted || generation != _animationGeneration) return;
      // Ensure we explicitly set the final state to avoid micro-drifts
      _scrollOffset.value = target;
      setState(() {
        _isScrolling = false;
        _lastScrollTime = DateTime.now();
      });
      // Clear caches after animation completes to prevent unbounded growth
      if (_transformCache.length > _maxCacheSize) {
        _transformCache.clear();
      }
      if (_positionCache.length > _maxCacheSize) {
        _positionCache.clear();
      }
      final finalIndex = target.round();
      if (finalIndex >= 0 && finalIndex < widget.songs.length) {
        if (_lastReportedIndex != finalIndex) {
          _lastReportedIndex = finalIndex;
          AppHaptics.selection();
        }
        widget.onSelectedIndexChanged?.call(finalIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.scrollDirection == Axis.horizontal;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal ? 28 : 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_layoutSize != size) {
            _layoutSize = size;
            _positionCache.clear();
            _transformCache.clear();
          }
          // Phone landscape leaves a much shorter stage than a tablet. Keep
          // the same orbit metaphor, but lift and shrink it so the flanking
          // cards are not pushed off the bottom of the window. The lift is a
          // runtime fit only; the saved landscape preference is never rewritten.
          final compactHorizontal = horizontal && size.height < 420;
          final orbitRadius = horizontal
              ? size.width * widget.radiusRatio.clamp(0.5, 2.0)
              : size.width * widget.radiusRatio;
          final orbitCenterX = horizontal
              ? size.width / 2
              : size.width * widget.centerOffsetRatio;
          final landscapeCardHeight = horizontal
              ? _landscapeCardHeight(size, compactHorizontal)
              : 0.0;
          final landscapeCardWidth = horizontal
              ? _landscapeCardWidth(
                  size,
                  landscapeCardHeight,
                  compactHorizontal,
                )
              : 0.0;
          final orbitCenterY = horizontal
              ? _landscapeFocalCenterY(
                  size,
                  orbitRadius,
                  landscapeCardHeight,
                  compactHorizontal,
                )
              : size.height * widget.centerYRatio;
          _dragExtent = horizontal
              ? (size.width * 0.28).clamp(140.0, 280.0)
              : 90;

          final viewport = GestureDetector(
            onVerticalDragStart: horizontal ? null : _onDragStart,
            onVerticalDragUpdate: horizontal ? null : _onDragUpdate,
            onVerticalDragEnd: horizontal ? null : _onDragEnd,
            onVerticalDragCancel: horizontal ? null : _onDragCancel,
            onHorizontalDragStart: horizontal ? _onDragStart : null,
            onHorizontalDragUpdate: horizontal ? _onDragUpdate : null,
            onHorizontalDragEnd: horizontal ? _onDragEnd : null,
            onHorizontalDragCancel: horizontal ? _onDragCancel : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Background glow
                  if (widget.showGlow)
                    _buildSelectionGlow(
                      orbitCenterX,
                      orbitCenterY,
                      orbitRadius,
                    ),

                  // Path
                  if (widget.showPath)
                    _buildOrbitPath(orbitCenterX, orbitCenterY, orbitRadius),

                  // Songs — only rebuilds when scroll offset changes
                  ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    builder: (context, _, __) {
                      return SizedBox.expand(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: _buildSongItems(
                            orbitCenterX,
                            orbitCenterY,
                            orbitRadius,
                            cardWidth: horizontal ? landscapeCardWidth : null,
                            cardHeight: horizontal ? landscapeCardHeight : null,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
          // Inner recognizers win Flutter's gesture arena before the ancestor
          // PageView. No global physics toggle is needed (or left stuck on cancel).
          return viewport;
        },
      ),
    );
  }

  void _onDragCancel() {
    if (widget.songs.isEmpty) return;
    _animateTo(
      _scrollOffset.value.round().clamp(0, widget.songs.length - 1).toDouble(),
    );
  }

  Widget _buildSelectionGlow(double centerX, double centerY, double radius) {
    final horizontal = widget.scrollDirection == Axis.horizontal;
    final x = horizontal ? centerX : centerX + radius;
    final y = horizontal ? centerY - radius : centerY;
    return Positioned(
      left: x - 120, // Slightly larger glow
      top: y - 120,
      child: RepaintBoundary(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrbitPath(double centerX, double centerY, double radius) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _OrbitPathPainter(
          centerX: centerX,
          centerY: centerY,
          radius: radius,
          horizontal: widget.scrollDirection == Axis.horizontal,
        ),
      ),
    );
  }

  /// Unscaled card height for a horizontal (landscape) orbit. The selected
  /// card is multiplied by [OrbitScroll.selectedScale] at paint time, so this
  /// value is divided by that scale to keep the focused card fitting the stage.
  double _landscapeCardHeight(Size size, bool compact) {
    final cardScale = math.max(1.0, widget.selectedScale);
    return compact
        ? size.height * 0.72 / cardScale
        : math.min(380.0, size.height * 0.85) / cardScale;
  }

  double _landscapeCardWidth(Size size, double cardHeight, bool compact) {
    final cardScale = math.max(1.0, widget.selectedScale);
    final viewportCardWidth =
        size.width * widget.cardWidthRatio * 0.5 / cardScale;
    return compact
        ? math.min(viewportCardWidth, cardHeight * 1.05).clamp(88.0, 280.0)
        : viewportCardWidth.clamp(160.0, 280.0);
  }

  /// The horizontal orbit circle sits below the visible arc. `centerYRatio`
  /// names the focal song's vertical position, then the runtime clamp keeps
  /// that song's full scaled height inside the stage.
  double _landscapeFocalCenterY(
    Size size,
    double radius,
    double cardHeight,
    bool compact,
  ) {
    final cardScale = math.max(1.0, widget.selectedScale);
    final selectedCardHeight = cardHeight * cardScale;
    final focalRatio = widget.centerYRatio - (compact ? 0.04 : 0.0);
    final desiredFocalY = size.height * focalRatio;
    final minFocalY = selectedCardHeight / 2 + 8;
    final maxFocalY = size.height - selectedCardHeight / 2 - 8;
    final focalY = maxFocalY < minFocalY
        ? size.height / 2
        : desiredFocalY.clamp(minFocalY, maxFocalY);
    return focalY + radius;
  }

  List<Widget> _buildSongItems(
    double centerX,
    double centerY,
    double radius, {
    double? cardWidth,
    double? cardHeight,
  }) {
    final List<Widget> items = [];

    final horizontal = widget.scrollDirection == Axis.horizontal;

    final centerIndex = _scrollOffset.value.round();

    // ponytail: adjacent/distant shrink derived from one Depth slider.
    // adjacent = 1 - 0.6*depth, distant = 1 - 0.8*depth. At default depth 0.75
    // this reproduces the old 0.55/0.35. Split into two sliders if finer control is needed.
    final adjacentScale = 1.0 - 0.6 * widget.depth;
    final distantScale = 1.0 - 0.8 * widget.depth;

    for (final relativeIndex in _orderedIndices) {
      final actualIndex = centerIndex + relativeIndex;

      if (actualIndex < 0 || actualIndex >= widget.songs.length) continue;

      final diff = actualIndex.toDouble() - _scrollOffset.value;

      final cacheKey = (diff * 100).toInt();
      _ItemTransform? transform = _transformCache[cacheKey];

      if (transform == null) {
        final position = _calculateItemPosition(diff, centerX, centerY, radius);
        final distanceFromCenter = diff.abs();

        double scale;
        if (distanceFromCenter < 1.0) {
          scale =
              widget.selectedScale -
              (widget.selectedScale - adjacentScale) * distanceFromCenter;
        } else if (distanceFromCenter < 2.0) {
          scale =
              adjacentScale -
              (adjacentScale - distantScale) * (distanceFromCenter - 1.0);
        } else {
          scale = distantScale - (distanceFromCenter - 2.0) * 0.12;
        }
        scale = scale.clamp(0.0, math.max(1.25, widget.selectedScale));

        if (scale < 0.1) continue;

        final opacity = (1.0 - (distanceFromCenter * 0.25)).clamp(0.0, 1.0);
        final isSelected = distanceFromCenter < 0.4;

        transform = _ItemTransform(
          position: position,
          scale: scale,
          opacity: opacity,
          isSelected: isSelected,
        );

        _transformCache[cacheKey] = transform;
      }

      items.add(
        Positioned(
          // Key the direct Stack child, not SongCard: as the visible window
          // and back-to-front order advance, keeping the key here lets a
          // surviving song's card State (and retained artwork) move between
          // position slots instead of being disposed and rebuilt.
          key: ValueKey(widget.songs[actualIndex].id),
          left: transform.position.x,
          top: transform.position.y,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: SongCard(
              song: widget.songs[actualIndex],
              scale: transform.scale,
              opacity: transform.opacity,
              isSelected: transform.isSelected,
              // Horizontal drags browse songs here, never queue/favorite.
              // Those actions remain in the existing long-press song menu.
              swipeActionsEnabled:
                  widget.swipeActionsEnabled &&
                  widget.scrollDirection == Axis.vertical,
              isSelectionMode: widget.isSelectionMode,
              isMultiSelected: widget.selectedIds.contains(
                widget.songs[actualIndex].id,
              ),
              artSizeBase: widget.cardArtSize,
              artSizeLarge: widget.cardArtSize * 1.5625,
              cardWidthRatio: widget.cardWidthRatio,
              artworkAbove: horizontal,
              width: cardWidth,
              height: cardHeight,
              artResolutionMultiplier: widget.artResolutionMultiplier,
              onTap: () {
                AppHaptics.tap();
                _animateTo(actualIndex.toDouble());
                widget.onSongSelected?.call(actualIndex);
              },
              onSwipeLeft: () => widget.onSongSwipedLeft?.call(actualIndex),
              onSwipeRight: () => widget.onSongSwipedRight?.call(actualIndex),
            ),
          ),
        ),
      );
    }

    return items;
  }

  _Position _calculateItemPosition(
    double relativeIndex,
    double centerX,
    double centerY,
    double radius,
  ) {
    final cacheKey = (relativeIndex * 100).toInt();

    final existing = _positionCache[cacheKey];
    if (existing != null) {
      return existing;
    }

    // Split effect: push adjacent items away from the center highlighted item
    double adjustedIndex = relativeIndex;
    final double splitAmount =
        0.55; // Determines how much the items split apart
    adjustedIndex +=
        relativeIndex.sign * splitAmount * math.min(relativeIndex.abs(), 1.0);

    final angle = adjustedIndex * widget.itemSpacing;
    final horizontal = widget.scrollDirection == Axis.horizontal;
    final x = horizontal
        ? centerX + radius * math.sin(angle)
        : centerX + radius * math.cos(angle);
    final y = horizontal
        ? centerY - radius * math.cos(angle)
        : centerY + radius * math.sin(angle);

    final position = _Position(x, y);

    _positionCache[cacheKey] = position;
    return position;
  }
}

class _Position {
  final double x;
  final double y;
  const _Position(this.x, this.y);
}

/// Cached transform data for orbit items
class _ItemTransform {
  final _Position position;
  final double scale;
  final double opacity;
  final bool isSelected;

  const _ItemTransform({
    required this.position,
    required this.scale,
    required this.opacity,
    required this.isSelected,
  });
}

class _OrbitPathPainter extends CustomPainter {
  final double centerX;
  final double centerY;
  final double radius;
  final bool horizontal;

  _OrbitPathPainter({
    required this.centerX,
    required this.centerY,
    required this.radius,
    this.horizontal = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.glassBorder.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: radius,
    );

    canvas.drawArc(
      rect,
      horizontal ? -math.pi / 2 - math.pi / 2.5 : -math.pi / 2.5,
      2 * math.pi / 2.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPathPainter oldDelegate) {
    return centerX != oldDelegate.centerX ||
        centerY != oldDelegate.centerY ||
        radius != oldDelegate.radius ||
        horizontal != oldDelegate.horizontal;
  }
}
