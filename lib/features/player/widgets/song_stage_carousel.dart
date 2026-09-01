import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/models/song.dart';

/// Horizontal carousel that *only* slides the middle stage (art + identity +
/// waveform). Background, top chrome and [PlayerControls] stay pinned outside.
///
/// Physics:
/// - Drag attaches directly to finger (no setState per frame would drop, but
///   we use a [ValueNotifier] + [AnimatedBuilder] to avoid rebuilding chrome).
/// - Threshold: 28% of width or velocity ±700.
/// - Rubber-band 0.32 when no neighbour.
/// - Commit 320ms easeOutCubic, cancel 260ms.
/// - Peek is natural: adjacent stage at ±width + dragOffset, so ~15% peek
///   appears at ~15% drag.
class SongStageCarousel extends StatefulWidget {
  final Song currentSong;
  final Song? nextSong;
  final Song? prevSong;
  final Widget Function(Song song) stageBuilder;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final bool enabled;

  /// Called when drag starts/ends to let outer screen know swipe is active
  /// (e.g. to suppress vertical dismiss).
  final ValueChanged<bool>? onDragStateChanged;

  const SongStageCarousel({
    super.key,
    required this.currentSong,
    required this.nextSong,
    required this.prevSong,
    required this.stageBuilder,
    required this.onNext,
    required this.onPrevious,
    this.enabled = true,
    this.onDragStateChanged,
  });

  @override
  State<SongStageCarousel> createState() => SongStageCarouselState();
}

class SongStageCarouselState extends State<SongStageCarousel>
    with SingleTickerProviderStateMixin {
  static const double _edgeExclusion = 32.0;
  static const double _commitThresholdFraction = 0.28;
  static const double _velocityThreshold = 700.0;
  static const double _rubberBandFactor = 0.32;

  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  double _animStartOffset = 0.0;
  double _animTargetOffset = 0.0;
  bool _isDragging = false;
  bool _isAnimating = false;
  double _dragStartX = double.infinity;
  double _dragStartY = double.infinity;

  // Frozen stages — prevents the glimpse bug where upNext updates to C
  // (via _setCurrentIndex) before currentSongNotifier flips from A->B,
  // which would otherwise swap nextStage B->C while offset==-width and flash C.
  late Song _stableCurrent;
  Song? _stableNext;
  Song? _stablePrev;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _controller.addListener(() {
      if (_isAnimating) {
        setState(() {
          _dragOffset = _animation.value;
        });
      }
    });
    _stableCurrent = widget.currentSong;
    _stableNext = widget.nextSong;
    _stablePrev = widget.prevSong;
  }

  @override
  void didUpdateWidget(covariant SongStageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSong.id != widget.currentSong.id) {
      // Song changed (our commit or external). Snap offset and sync frozen.
      _controller.stop();
      _isAnimating = false;
      _dragOffset = 0.0;
      _isDragging = false;
      _stableCurrent = widget.currentSong;
      _stableNext = widget.nextSong;
      _stablePrev = widget.prevSong;
      return;
    }
    // No song change: only sync peek neighbours when idle at offset 0.
    // While dragging/animating or mid-commit (offset!=0) we keep frozen
    // to avoid flashing C when upNext flips before currentSong does.
    if (!_isDragging && !_isAnimating && _dragOffset == 0.0) {
      _stableNext = widget.nextSong;
      _stablePrev = widget.prevSong;
      // current unchanged, but keep in sync if parent rebuilt it identically
      _stableCurrent = widget.currentSong;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Programmatic next (control button). Slides out to left, then fires service.
  Future<void> animateToNext() async {
    if (!widget.enabled || _stableNext == null || _isAnimating) {
      await widget.onNext();
      return;
    }
    await _animateToTargetAndCommit(isNext: true);
  }

  Future<void> animateToPrevious() async {
    if (!widget.enabled || _stablePrev == null || _isAnimating) {
      await widget.onPrevious();
      return;
    }
    await _animateToTargetAndCommit(isNext: false);
  }

  Future<void> _animateToTargetAndCommit({required bool isNext}) async {
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final target = isNext ? -width : width;
    await _animateOffsetTo(target, commitDuration: const Duration(milliseconds: 320));
    // Service changes song; our didUpdateWidget will snap offset.
    HapticFeedback.lightImpact();
    if (isNext) {
      await widget.onNext();
    } else {
      await widget.onPrevious();
    }
    if (mounted) {
      setState(() => _dragOffset = 0.0);
    }
  }

  Future<void> _animateOffsetTo(double target,
      {required Duration commitDuration}) async {
    if (_dragOffset == target) return;
    _isAnimating = true;
    _animStartOffset = _dragOffset;
    _animTargetOffset = target;
    _animation = Tween<double>(begin: _animStartOffset, end: _animTargetOffset)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        );
    _controller.duration = commitDuration;
    _controller.value = 0;
    await _controller.forward();
    _isAnimating = false;
  }

  void _handleDragStart(DragStartDetails details) {
    if (!widget.enabled || _isAnimating) return;
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _controller.stop();
    _isAnimating = false;
    _isDragging = true;
    _animStartOffset = _dragOffset;
    widget.onDragStateChanged?.call(true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || !_isDragging) return;
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    double delta = details.delta.dx;

    // Rubber-band when no neighbour in that direction (use frozen).
    if (delta < 0 && _stableNext == null) {
      delta *= _rubberBandFactor;
      // Also damp overall offset exponentially when beyond edge.
      if (_dragOffset < 0) {
        final overshoot = _dragOffset.abs();
        final damp = math.exp(-overshoot / (width * 0.6));
        delta *= damp;
      }
    } else if (delta > 0 && _stablePrev == null) {
      delta *= _rubberBandFactor;
      if (_dragOffset > 0) {
        final overshoot = _dragOffset.abs();
        final damp = math.exp(-overshoot / (width * 0.6));
        delta *= damp;
      }
    }

    setState(() {
      _dragOffset += delta;
      // Clamp to not fly infinitely.
      final maxOffset = width * 1.1;
      _dragOffset = _dragOffset.clamp(-maxOffset, maxOffset);
    });
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    if (!_isDragging) return;
    _isDragging = false;
    widget.onDragStateChanged?.call(false);

    // Edge exclusion: if drag started near screen edge, don't navigate.
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final nearEdge =
        _dragStartX <= _edgeExclusion ||
        _dragStartX >= width - _edgeExclusion ||
        _dragStartY >= height - _edgeExclusion;
    if (nearEdge) {
      await _animateOffsetTo(0, commitDuration: const Duration(milliseconds: 220));
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final threshold = width * _commitThresholdFraction;

    final shouldNext =
        (_dragOffset < -threshold || velocity < -_velocityThreshold) &&
        _stableNext != null;
    final shouldPrev =
        (_dragOffset > threshold || velocity > _velocityThreshold) &&
        _stablePrev != null;

    if (shouldNext) {
      HapticFeedback.mediumImpact();
      await _animateOffsetTo(-width,
          commitDuration: const Duration(milliseconds: 320));
      await widget.onNext();
      if (mounted) setState(() => _dragOffset = 0.0);
    } else if (shouldPrev) {
      HapticFeedback.mediumImpact();
      await _animateOffsetTo(width,
          commitDuration: const Duration(milliseconds: 320));
      await widget.onPrevious();
      if (mounted) setState(() => _dragOffset = 0.0);
    } else {
      if (_dragOffset.abs() > 8) AppHaptics.tap();
      await _animateOffsetTo(0,
          commitDuration: const Duration(milliseconds: 260));
    }
  }

  void _handleDragCancel() {
    if (_isDragging) {
      _isDragging = false;
      widget.onDragStateChanged?.call(false);
      _animateOffsetTo(0, commitDuration: const Duration(milliseconds: 260));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        // Precached stages — RepaintBoundary to keep 60fps
        // Use frozen stages to avoid flashing C when upNext flips early.
        final currentStage = RepaintBoundary(
          child: widget.stageBuilder(_stableCurrent),
        );
        final nextStage = _stableNext != null
            ? RepaintBoundary(child: widget.stageBuilder(_stableNext!))
            : null;
        final prevStage = _stablePrev != null
            ? RepaintBoundary(child: widget.stageBuilder(_stablePrev!))
            : null;

        // Simple opacity peek fade: current fades slightly as it slides out
        // (kept minimal per user request: just slide, pinned controls).
        // We keep opacity 1 for now to stay blunt.
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            onHorizontalDragCancel: _handleDragCancel,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (prevStage != null)
                  Transform.translate(
                    offset: Offset(-width + _dragOffset, 0),
                    child: SizedBox(width: width, child: prevStage),
                  ),
                if (nextStage != null)
                  Transform.translate(
                    offset: Offset(width + _dragOffset, 0),
                    child: SizedBox(width: width, child: nextStage),
                  ),
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: SizedBox(width: width, child: currentStage),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
