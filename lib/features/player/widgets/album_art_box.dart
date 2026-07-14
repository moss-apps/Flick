import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/models/song.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';

class AlbumArtBox extends StatefulWidget {
  final Song song;
  final double? size;
  final PlayerService? playerService;
  final void Function(bool enabled)? onRotationEnabledChanged;
  final bool initialVinyl;
  final ValueChanged<bool>? onVinylChanged;
  final bool showFrame;

  const AlbumArtBox({super.key,
    required this.song,
    this.size,
    this.playerService,
    this.onRotationEnabledChanged,
    this.initialVinyl = false,
    this.onVinylChanged,
    this.showFrame = true,
  });

  @override
  State<AlbumArtBox> createState() => _AlbumArtBoxState();
}

class _AlbumArtBoxState extends State<AlbumArtBox>
    with TickerProviderStateMixin {
  static const double _labelRatio = 0.44;
  static const Duration _spinDuration = Duration(seconds: 4);
  static const Duration _seekAnimationDuration = Duration(milliseconds: 450);
  static const int _msPerSeekRevolution = 1500;
  static const int _maxSeekRevolutions = 5;
  static const int _minSeekRevolutions = 1;
  static const int _forwardSeekThresholdMs = 1500;
  static const double _secondsPerVinylRotation = 30.0;

  late final AnimationController _morphController;
  late final AnimationController _spinController;
  late final AnimationController _seekAngleController;
  late final AnimationController _outlineController;
  bool _isVinyl = false;
  bool _isRotationEnabled = false;
  Duration _lastObservedPosition = Duration.zero;
  final ValueNotifier<double> _userRotationOffset = ValueNotifier(0.0);
  bool _isUserDragging = false;
  double _rotationHapticAccumulator = 0.0;
  static const double _hapticTickInterval = math.pi / 16;
  late final DoubleTapGestureRecognizer _doubleTapRecognizer;
  late final TapGestureRecognizer _singleTapRecognizer;
  late final _RotationSeekRecognizer _rotationRecognizer;

  bool get _isPlaying => widget.playerService?.isPlayingNotifier.value ?? false;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _spinController = AnimationController(vsync: this, duration: _spinDuration);
    _seekAngleController = AnimationController(
      vsync: this,
      duration: _seekAnimationDuration,
    );
    _outlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _outlineController.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        setState(() => _isRotationEnabled = true);
        widget.onRotationEnabledChanged?.call(true);
      } else if (status == AnimationStatus.dismissed) {
        setState(() => _isRotationEnabled = false);
        widget.onRotationEnabledChanged?.call(false);
      }
    });
    _morphController.addStatusListener(_handleMorphStatus);
    _doubleTapRecognizer = DoubleTapGestureRecognizer()..onDoubleTap = _toggle;
    _singleTapRecognizer = TapGestureRecognizer()
      ..onTap = _handleVinylSingleTap;
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
    if (widget.initialVinyl) {
      _isVinyl = true;
      _morphController.value = 1.0;
      if (_isPlaying) {
        _spinController.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AlbumArtBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _lastObservedPosition = Duration.zero;
      _seekAngleController.stop();
      _seekAngleController.value = 0;
      _userRotationOffset.value = 0.0;
      _isUserDragging = false;
      _isRotationEnabled = false;
      _outlineController.value = 0;
      if (_isVinyl) {
        _spinController.stop();
        _spinController.value = 0;
        if (_isPlaying) {
          _spinController.repeat();
        }
      }
    }
    if (oldWidget.playerService != widget.playerService) {
      oldWidget.playerService?.positionNotifier.removeListener(
        _onPositionChanged,
      );
      oldWidget.playerService?.isPlayingNotifier.removeListener(
        _onPlayingChanged,
      );
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
    if (_isUserDragging) {
      widget.playerService?.endInteractiveSeek();
    }
    _morphController.removeStatusListener(_handleMorphStatus);
    widget.playerService?.positionNotifier.removeListener(_onPositionChanged);
    widget.playerService?.isPlayingNotifier.removeListener(_onPlayingChanged);
    _doubleTapRecognizer.dispose();
    _singleTapRecognizer.dispose();
    _rotationRecognizer.dispose();
    _outlineController.dispose();
    _seekAngleController.dispose();
    _spinController.dispose();
    _morphController.dispose();
    _userRotationOffset.dispose();
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
    if (!_isVinyl || !_isRotationEnabled) return;
    final service = widget.playerService;
    if (service == null) return;
    _isUserDragging = true;
    _rotationHapticAccumulator = 0.0;
    service.beginInteractiveSeek();
    _spinController.stop();
    _seekAngleController.stop();
    _seekAngleController.value = 0;
    _lastObservedPosition = service.positionNotifier.value;
    AppHaptics.confirm();
  }

  void _onRotationUpdate(double delta) {
    if (!_isVinyl || !_isRotationEnabled) return;
    final service = widget.playerService;
    if (service == null) return;
    _userRotationOffset.value += delta;

    _rotationHapticAccumulator += delta.abs();
    if (_rotationHapticAccumulator >= _hapticTickInterval) {
      _rotationHapticAccumulator -= _hapticTickInterval;
      AppHaptics.tap();
    }

    final msPerRadian = (_secondsPerVinylRotation * 1000) / (2 * math.pi);
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
  }

  void _onRotationEnd() {
    _isUserDragging = false;
    widget.playerService?.endInteractiveSeek();
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
        _userRotationOffset.value = 0.0;
        _isRotationEnabled = false;
        _outlineController.value = 0;
        _morphController.reverse();
      }
    });
    widget.onVinylChanged?.call(_isVinyl);
  }

  void _handleVinylSingleTap() {
    if (!_isVinyl) return;
    if (_outlineController.isAnimating) return;
    AppHaptics.confirm();
    if (_isRotationEnabled) {
      _outlineController.reverse();
    } else {
      _outlineController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double resolvedSize =
        widget.size ?? context.responsive(280.0, 320.0, 360.0);

    // Update the disc center for rotation detection
    _rotationRecognizer.discCenter = () =>
        Offset(resolvedSize / 2, resolvedSize / 2);

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
          DoubleTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
                () => _doubleTapRecognizer,
                (_) {},
              ),
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => _singleTapRecognizer,
                (_) {},
              ),
          if (_isRotationEnabled)
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
              _outlineController,
              _userRotationOffset,
            ]),
            builder: (context, _) {
              final rawT = Curves.easeInOutCubic.transform(
                _morphController.value,
              );
              final t = rawT.isFinite ? rawT.clamp(0.0, 1.0) : 0.0;
              final glass = (1.0 - t).clamp(0.0, 1.0);
              final rawAngle =
                  _spinController.value * 2 * math.pi * t +
                  _seekAngleController.value +
                  _userRotationOffset.value;
              final spinAngle = rawAngle.isFinite ? rawAngle : 0.0;

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
                            painter: _VinylDiscPainter(labelRatio: _labelRatio),
                          ),
                        ),
                      ),
                    widget.showFrame
                        ? Container(
                            width: artSize,
                            height: artSize,
                            padding: EdgeInsets.all(artFramePadding),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                artOuterRadius,
                              ),
                              gradient: glass > 0.01
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(
                                          alpha: 0.16 * glass,
                                        ),
                                        Colors.white.withValues(
                                          alpha: 0.06 * glass,
                                        ),
                                        Colors.white.withValues(
                                          alpha: 0.02 * glass,
                                        ),
                                      ],
                                      stops: const [0.0, 0.4, 1.0],
                                    )
                                  : null,
                              border: Border.all(
                                color: glass > 0.5
                                    ? Colors.white.withValues(
                                        alpha: 0.12 * glass,
                                      )
                                    : Colors.black.withValues(alpha: 0.28 * t),
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
                              borderRadius: BorderRadius.circular(
                                artInnerRadius,
                              ),
                              child: CachedImageWidget(
                                imagePath: widget.song.albumArt,
                                audioSourcePath: widget.song.filePath,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: Icon(
                                    LucideIcons.music,
                                    size: iconSize * (1 - t * 0.5),
                                    color: Colors.white.withValues(alpha: 0.48),
                                  ),
                                ),
                                errorWidget: Container(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: Icon(
                                    LucideIcons.music,
                                    size: iconSize * (1 - t * 0.5),
                                    color: Colors.white.withValues(alpha: 0.48),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(artOuterRadius),
                            child: SizedBox(
                              width: artSize,
                              height: artSize,
                              child: CachedImageWidget(
                                imagePath: widget.song.albumArt,
                                audioSourcePath: widget.song.filePath,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: Icon(
                                    LucideIcons.music,
                                    size: iconSize * (1 - t * 0.5),
                                    color: Colors.white.withValues(alpha: 0.48),
                                  ),
                                ),
                                errorWidget: Container(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: Icon(
                                    LucideIcons.music,
                                    size: iconSize * (1 - t * 0.5),
                                    color: Colors.white.withValues(alpha: 0.48),
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
                            color: const Color(0xFF050505).withValues(alpha: t),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.55 * t),
                                blurRadius: 2,
                                offset: const Offset(0, 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_isVinyl && _outlineController.value > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _VinylOutlinePainter(
                            progress: _outlineController.value,
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

      if (totalDist < 8) return;

      // Check if motion is tangential (rotational) vs radial (linear swipe)
      final motionDx = event.localPosition.dx - _startPos!.dx;
      final motionDy = event.localPosition.dy - _startPos!.dy;
      final radiusDx = _startPos!.dx - center.dx;
      final radiusDy = _startPos!.dy - center.dy;
      final radiusLength = math.sqrt(radiusDx * radiusDx + radiusDy * radiusDy);

      if (radiusLength < 10) return; // Too close to center

      final dotProduct = motionDx * radiusDx + motionDy * radiusDy;
      final motionLength = math.sqrt(motionDx * motionDx + motionDy * motionDy);
      final cosAngle = (dotProduct / (motionLength * radiusLength)).clamp(
        -1.0,
        1.0,
      );

      // If motion is mostly radial (cosAngle close to ±1), it's a swipe
      // If motion is mostly tangential (cosAngle close to 0), it's rotation
      if (cosAngle.abs() > 0.8) {
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

class _VinylOutlinePainter extends CustomPainter {
  _VinylOutlinePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VinylOutlinePainter old) =>
      old.progress != progress;
}

