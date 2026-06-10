import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';

class LineSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration>? onChangeEnd;
  final double appearProgress;

  const LineSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    this.onChangeEnd,
    this.appearProgress = 1.0,
  });

  @override
  State<LineSeekBar> createState() => _LineSeekBarState();
}

class _LineSeekBarState extends State<LineSeekBar>
    with SingleTickerProviderStateMixin {
  static const double _baseHeight = 40;
  static const double _expandedHeight = 72;
  static const double _fineScrubZoom = 2.6;

  bool _isDragging = false;
  bool _isFineScrubbing = false;
  Duration? _interactivePosition;
  double _fineScrubAnchorDx = 0;
  Duration _fineScrubAnchorPosition = Duration.zero;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Duration get _displayPosition => _interactivePosition ?? widget.position;

  Duration _positionFromDx(double dx, double width) {
    final progress = (dx / width).clamp(0.0, 1.0);
    final ms = (progress * widget.duration.inMilliseconds).round();
    return Duration(milliseconds: ms);
  }

  void _updateInteractivePosition(Duration position) {
    _interactivePosition = position;
  }

  void _onDragStart(DragStartDetails details) {
    if (!mounted) return;
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isFineScrubbing) return;
    final width = constraints.maxWidth;
    final position = _positionFromDx(details.localPosition.dx, width);
    setState(() {
      _updateInteractivePosition(position);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final finalPosition = _displayPosition;
    _interactivePosition = null;
    widget.onChanged(finalPosition);
    widget.onChangeEnd?.call(finalPosition);
    if (mounted) setState(() {});
  }

  void _onTapUp(TapUpDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final newPos = _positionFromDx(details.localPosition.dx, width);
    widget.onChanged(newPos);
    widget.onChangeEnd?.call(newPos);
  }

  void _onLongPressStart(
    LongPressStartDetails details,
    BoxConstraints constraints,
  ) {
    _pulseController.repeat(reverse: true);
    final anchorPosition = _positionFromDx(
      details.localPosition.dx,
      constraints.maxWidth,
    );
    setState(() {
      _isFineScrubbing = true;
      _fineScrubAnchorDx = details.localPosition.dx;
      _fineScrubAnchorPosition = anchorPosition;
      _updateInteractivePosition(anchorPosition);
    });
  }

  void _onLongPressMoveUpdate(
    LongPressMoveUpdateDetails details,
    BoxConstraints constraints,
  ) {
    final width = constraints.maxWidth;
    final anchorProgress = widget.duration.inMilliseconds == 0
        ? 0.0
        : _fineScrubAnchorPosition.inMilliseconds /
            widget.duration.inMilliseconds;
    final deltaProgress =
        (details.localPosition.dx - _fineScrubAnchorDx) /
            width /
            _fineScrubZoom;
    final progress = (anchorProgress + deltaProgress).clamp(0.0, 1.0);
    final nextPosition = Duration(
      milliseconds: (progress * widget.duration.inMilliseconds).round(),
    );

    setState(() {
      _updateInteractivePosition(nextPosition);
    });
  }

  void _endFineScrub() {
    _pulseController.stop();
    _pulseController.reset();
    final finalPosition = _displayPosition;
    _isFineScrubbing = false;
    _interactivePosition = null;
    widget.onChanged(finalPosition);
    widget.onChangeEnd?.call(finalPosition);
    if (mounted) setState(() {});
  }

  double _timeIndicatorLeft(double maxWidth, double progress) {
    final effectiveWidth = maxWidth - 4;
    final rawLeft = 2 + effectiveWidth * progress;
    return (rawLeft - 25).clamp(0.0, maxWidth - 50);
  }

  Widget _buildTimeIndicator(bool isFine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: isFine ? 1.0 : 0.88),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatDuration(_displayPosition),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'ProductSans',
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _effectiveLineHeight {
    if (_isFineScrubbing) return 10;
    if (_isDragging) return 5;
    return 3;
  }

  double get _effectiveDotRadius {
    if (_isFineScrubbing) return 7;
    if (_isDragging) return 5;
    return 3.5;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isScrubbing = _isFineScrubbing || _isDragging;
        final progress = widget.duration.inMilliseconds == 0
            ? 0.0
            : _displayPosition.inMilliseconds / widget.duration.inMilliseconds;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: (details) =>
                  _onDragUpdate(details, constraints),
              onHorizontalDragEnd: _onDragEnd,
              onLongPressStart: (details) =>
                  _onLongPressStart(details, constraints),
              onLongPressMoveUpdate: (details) =>
                  _onLongPressMoveUpdate(details, constraints),
              onLongPressEnd: (_) => _endFineScrub(),
              onTapUp: (details) => _onTapUp(details, constraints),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: AppConstants.animationFast,
                curve: Curves.easeOutCubic,
                height: _isFineScrubbing ? _expandedHeight : _baseHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: _isFineScrubbing
                      ? AppColors.glassBackgroundStrong
                      : Colors.transparent,
                ),
                padding: EdgeInsets.symmetric(
                  vertical: _isFineScrubbing ? (_expandedHeight - 10) / 2 : 18,
                ),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _LineSeekBarPainter(
                          progress: progress,
                          lineHeight: _effectiveLineHeight,
                          dotRadius: _effectiveDotRadius,
                          glowIntensity:
                              _isFineScrubbing ? _pulseAnimation.value : 0.0,
                          trackColor:
                              AppColors.textTertiary.withValues(alpha: 0.2),
                          activeColor: AppColors.accent,
                          appearProgress: widget.appearProgress,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (isScrubbing)
              Positioned(
                top: -2,
                left: _timeIndicatorLeft(constraints.maxWidth, progress),
                child: _buildTimeIndicator(_isFineScrubbing),
              ),
          ],
        );
      },
    );
  }
}

class _LineSeekBarPainter extends CustomPainter {
  final double progress;
  final double lineHeight;
  final double dotRadius;
  final double glowIntensity;
  final Color trackColor;
  final Color activeColor;
  final double appearProgress;

  _LineSeekBarPainter({
    required this.progress,
    required this.lineHeight,
    required this.dotRadius,
    required this.glowIntensity,
    required this.trackColor,
    required this.activeColor,
    required this.appearProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final lineTop = centerY - lineHeight / 2;
    final trackWidth = size.width * appearProgress;
    final playedWidth = (trackWidth * progress).clamp(0.0, trackWidth);

    if (trackWidth <= 0) return;

    final trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, lineTop, trackWidth, lineHeight),
      Radius.circular(lineHeight / 2),
    );

    final paint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, paint);

    if (playedWidth > 0) {
      final playedRadius = math.min(playedWidth, lineHeight) / 2;
      final playedRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, lineTop, playedWidth, lineHeight),
        Radius.circular(playedRadius),
      );
      paint.color = activeColor;
      canvas.drawRRect(playedRRect, paint);
    }

    final dotX = playedWidth.clamp(0.0, trackWidth);

    if (glowIntensity > 0) {
      final glowPaint = Paint()..style = PaintingStyle.fill;
      for (int i = 3; i >= 0; i--) {
        final radius = dotRadius + (i + 1) * 8.0;
        final alpha = (glowIntensity * 0.06 / (i + 1)).clamp(0.0, 1.0);
        glowPaint.color = activeColor.withValues(alpha: alpha);
        canvas.drawCircle(Offset(dotX, centerY), radius, glowPaint);
      }
    }

    final dotPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, centerY), dotRadius, dotPaint);

    if (dotRadius > 3) {
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(dotX - dotRadius * 0.2, centerY - dotRadius * 0.2),
        dotRadius * 0.35,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_LineSeekBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.appearProgress != appearProgress;
  }
}
