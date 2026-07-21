import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';

class WaveformSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration>? onChangeEnd;
  final double appearProgress;
  final List<double>? cachedPeaks;

  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    this.onChangeEnd,
    this.barCount = 60,
    this.appearProgress = 1.0,
    this.cachedPeaks,
  });

  final int barCount;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  static const double _baseHeight = 60;
  static const double _expandedHeight = 96;
  static const double _fineScrubZoom = 2.6;
  static const int _cachedSampleCount = 180;

  // Cache the waveform data so it doesn't jitter on rebuilds
  late List<double> _waveformData;
  bool _isFineScrubbing = false;
  Duration? _interactivePosition;
  double _fineScrubAnchorDx = 0;
  Duration _fineScrubAnchorPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _generateWaveform();
  }

  @override
  void didUpdateWidget(WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final peaksChanged = widget.cachedPeaks != oldWidget.cachedPeaks;
    final durationChanged = widget.duration != oldWidget.duration ||
        widget.barCount != oldWidget.barCount;
    if ((durationChanged || peaksChanged) &&
        widget.duration.inMilliseconds > 0) {
      _generateWaveform();
    }
  }

  void _generateWaveform() {
    final peaks = widget.cachedPeaks;
    if (peaks != null && peaks.isNotEmpty) {
      // Resample cached peaks to barCount-sized array
      final target = max(widget.barCount, _cachedSampleCount);
      _waveformData = List.generate(target, (i) {
        final t = i / (target - 1);
        final idx = (t * (peaks.length - 1)).round();
        return peaks[idx].clamp(0.0, 1.0) * 0.9 + 0.1;
      });
      return;
    }
    // Fallback: deterministic pseudo-random bar heights
    final random = Random(widget.duration.inMilliseconds);
    _waveformData = List.generate(
      max(widget.barCount, _cachedSampleCount),
      (index) => 0.3 + random.nextDouble() * 0.7,
    );
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
    // Optional: add visual feedback when dragging starts
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
    final finalPosition = _displayPosition;
    if (_interactivePosition != null) {
      setState(() {
        _interactivePosition = null;
      });
    }
    widget.onChanged(finalPosition);
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(finalPosition);
    }
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
    final finalPosition = _displayPosition;
    if (!_isFineScrubbing && _interactivePosition == null) {
      return;
    }

    setState(() {
      _isFineScrubbing = false;
      _interactivePosition = null;
    });
    widget.onChanged(finalPosition);
    widget.onChangeEnd?.call(finalPosition);
  }

  double _timeIndicatorLeft(double maxWidth, double progress) {
    final effectiveWidth = maxWidth - 4;
    final rawLeft = 2 + effectiveWidth * progress;
    return (rawLeft - 25).clamp(0.0, maxWidth - 50);
  }

  Widget _buildTimeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.88),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isScrubbing = _isFineScrubbing || _interactivePosition != null;
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
                  horizontal: 2,
                  vertical: _isFineScrubbing ? 6 : 0,
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      waveformData: _waveformData,
                      position: _displayPosition,
                      duration: widget.duration,
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      activeColor: AppColors.accent,
                      barCount: widget.barCount,
                      zoomFactor: _isFineScrubbing ? _fineScrubZoom : 1.0,
                      appearProgress: widget.appearProgress,
                    ),
                  ),
                ),
              ),
            ),
            if (isScrubbing)
              Positioned(
                top: -22,
                left: _timeIndicatorLeft(constraints.maxWidth, progress),
                child: _buildTimeIndicator(),
              ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Duration position;
  final Duration duration;
  final Color color;
  final Color activeColor;
  final int barCount;
  final double zoomFactor;
  final double appearProgress;

  _WaveformPainter({
    required this.waveformData,
    required this.position,
    required this.duration,
    required this.color,
    required this.activeColor,
    required this.barCount,
    required this.zoomFactor,
    required this.appearProgress,
  });

  double _sampleHeight(double progress) {
    final sampleProgress = progress.clamp(0.0, 1.0) * (waveformData.length - 1);
    final lowerIndex = sampleProgress.floor();
    final upperIndex = sampleProgress.ceil();

    if (lowerIndex == upperIndex) {
      return waveformData[lowerIndex];
    }

    final t = sampleProgress - lowerIndex;
    return waveformData[lowerIndex] * (1 - t) + waveformData[upperIndex] * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Spacing between bars
    final spacing = 2.0;
    // Calculate total available width for bars (width - total spacing)
    final totalSpacing = (barCount - 1) * spacing;
    final barWidth = (size.width - totalSpacing) / barCount;

    final currentProgress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;
    final visibleProgressWindow = 1 / zoomFactor;
    final startProgress = zoomFactor <= 1
        ? 0.0
        : (currentProgress - visibleProgressWindow / 2).clamp(
            0.0,
            max(0.0, 1.0 - visibleProgressWindow),
          );

    final paint = Paint()..strokeCap = StrokeCap.round;

    // Number of bars for the smooth transition zone
    const transitionBars = 3.0;
    final transitionWidth = transitionBars / barCount;

    for (int i = 0; i < barCount; i++) {
      final barProgress = zoomFactor <= 1
          ? i / barCount
          : startProgress + (i / max(1, barCount - 1)) * visibleProgressWindow;
      final barHeight = _sampleHeight(barProgress) * size.height * appearProgress;
      final x = i * (barWidth + spacing) + barWidth / 2;
      final yCenter = size.height / 2;

      // Smooth color interpolation around the current progress
      // Calculate how far this bar is from the current progress
      final distanceFromProgress = currentProgress - barProgress;

      Color barColor;
      if (distanceFromProgress >= transitionWidth) {
        // Fully played
        barColor = activeColor;
      } else if (distanceFromProgress <= 0) {
        // Not yet played
        barColor = color;
      } else {
        // In the transition zone - smoothly interpolate
        final t = distanceFromProgress / transitionWidth;
        barColor = Color.lerp(color, activeColor, t)!;
      }

      paint.color = barColor;
      paint.strokeWidth = barWidth;

      // Draw line from center up and down
      canvas.drawLine(
        Offset(x, yCenter - barHeight / 2),
        Offset(x, yCenter + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    // Only repaint if duration changed
    if (oldDelegate.duration != duration) {
      return true;
    }

    if (oldDelegate.zoomFactor != zoomFactor ||
        oldDelegate.waveformData != waveformData ||
        oldDelegate.appearProgress != appearProgress) {
      return true;
    }

    // For position changes, only repaint if the visual progress (which bar is highlighted) changed
    // Calculate which bar index corresponds to the current progress
    if (duration.inMilliseconds == 0) {
      return false;
    }

    final oldProgress =
        oldDelegate.position.inMilliseconds /
        oldDelegate.duration.inMilliseconds;
    final newProgress = position.inMilliseconds / duration.inMilliseconds;

    // Calculate bar indices (0 to barCount-1)
    final oldBarIndex = (oldProgress * barCount).floor();
    final newBarIndex = (newProgress * barCount).floor();

    // Only repaint if we've crossed a bar boundary or if the difference is significant
    // This reduces repaints from ~60fps to ~10fps for a typical song
    return oldBarIndex != newBarIndex ||
        (oldProgress - newProgress).abs() > (1.0 / barCount);
  }
}
