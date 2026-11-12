import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/providers/album_color_provider.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/providers/visualizer_source_provider.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/services/visualizer_source.dart';

class AudioVisualizer extends ConsumerStatefulWidget {
  final PlayerService playerService;
  final String animationStyle;
  final String frequencyMode;
  final String movementMode;
  final String? colorMode;
  final Color? albumColor;
  final bool enabled;

  /// Enables the old generated animation when no live source is available.
  /// Production player surfaces leave this off so bars always represent audio.
  final bool simulationFallback;

  const AudioVisualizer({
    super.key,
    required this.playerService,
    this.animationStyle = 'bars',
    this.frequencyMode = 'full',
    this.movementMode = 'bouncy',
    this.colorMode,
    this.albumColor,
    this.enabled = true,
    this.simulationFallback = false,
  });

  @override
  ConsumerState<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends ConsumerState<AudioVisualizer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const int _barCount = 48;
  static const double _minHeight = 0.04;
  static const double _spring = 0.28;
  static const double _damping = 0.72;
  static const int _blockRows = 20;

  late final AnimationController _controller;
  late final ProviderSubscription<VisualizerSource> _sourceSubscription;
  late VisualizerSource _source;
  bool _sourceAcquired = false;
  bool _motionEnabled = false;
  bool _simulating = false;

  // These buffers belong to the paint layer, not to a rebuilt widget per frame.
  final List<double> _currentHeights = List.filled(_barCount, _minHeight);
  final List<double> _startHeights = List.filled(_barCount, _minHeight);
  final List<double> _targetHeights = List.filled(_barCount, _minHeight);
  final List<double> _displayHeights = List.filled(_barCount, _minHeight);
  final List<double> _velocities = List.filled(_barCount, 0.0);
  final List<double> _blockOpacities = List.filled(_barCount * _blockRows, 0.0);
  late List<double> _frequencyWeights;
  Animatable<double> _heightProgress = CurveTween(curve: Curves.linear);
  Duration _heightStartedAt = Duration.zero;
  Duration _heightDuration = const Duration(milliseconds: 100);
  Duration? _lastFrameElapsed;

  bool _isPlaying = false;
  bool _appActive = true;
  int _frameCount = 0;
  int _songSeed = 0;
  double _songDurationSec = 180.0;
  String? _lastMotionState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _source = ref.read(visualizerSourceProvider);

    _isPlaying = widget.playerService.isPlayingNotifier.value;
    _updateSongSeed();
    _frequencyWeights = _frequencyMask(widget.frequencyMode);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addListener(_onFrame);
    if (_isPlaying && _hasLiveData) {
      _currentHeights.setAll(0, _source.bars!);
      _targetHeights.setAll(0, _currentHeights);
      _updateDisplayHeights();
      _updateBlockTrails(0.0);
    }
    _sourceSubscription = ref.listenManual(visualizerSourceProvider, (_, next) {
      if (!identical(_source, next)) {
        final previous = _source;
        final acquired = _sourceAcquired;
        _sourceAcquired = false;
        _source = next;
        if (acquired) previous.release();
        _setSourceAcquired(_motionEnabled);
      }
      _onSourceChanged();
    });

    widget.playerService.isPlayingNotifier.addListener(_onPlayingChanged);
    widget.playerService.positionNotifier.addListener(_onPositionChanged);
    widget.playerService.currentSongNotifier.addListener(_onSongChanged);

    devLog('[Visualizer] live source ${_source.mode.name}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateControllerState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    _updateControllerState();
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationStyle != widget.animationStyle ||
        oldWidget.frequencyMode != widget.frequencyMode ||
        oldWidget.simulationFallback != widget.simulationFallback) {
      _blockOpacities.fillRange(0, _blockOpacities.length, 0.0);
    }
    if (oldWidget.frequencyMode != widget.frequencyMode) {
      _frequencyWeights = _frequencyMask(widget.frequencyMode);
      _updateDisplayHeights();
    }
    if (oldWidget.playerService != widget.playerService) {
      oldWidget.playerService.isPlayingNotifier.removeListener(
        _onPlayingChanged,
      );
      oldWidget.playerService.positionNotifier.removeListener(
        _onPositionChanged,
      );
      oldWidget.playerService.currentSongNotifier.removeListener(
        _onSongChanged,
      );
      widget.playerService.isPlayingNotifier.addListener(_onPlayingChanged);
      widget.playerService.positionNotifier.addListener(_onPositionChanged);
      widget.playerService.currentSongNotifier.addListener(_onSongChanged);
      _isPlaying = widget.playerService.isPlayingNotifier.value;
      _resetAnimation();
      _updateSongSeed();
    }
    _updateControllerState();
  }

  bool get _hasLiveData {
    final bars = _source.bars;
    return bars != null && bars.length == _barCount;
  }

  void _onSongChanged() {
    _resetAnimation();
    _updateSongSeed();
    if (_motionEnabled && _isPlaying && widget.simulationFallback) {
      _onSourceChanged();
    }
  }

  void _resetAnimation() {
    _controller.stop();
    _simulating = false;
    _currentHeights.fillRange(0, _barCount, _minHeight);
    _startHeights.fillRange(0, _barCount, _minHeight);
    _targetHeights.fillRange(0, _barCount, _minHeight);
    _displayHeights.fillRange(0, _barCount, _minHeight);
    _velocities.fillRange(0, _barCount, 0.0);
    _blockOpacities.fillRange(0, _blockOpacities.length, 0.0);
    _lastFrameElapsed = null;
    _frameCount = 0;
    _controller.value = 0.0;
  }

  void _updateSongSeed() {
    final song = widget.playerService.currentSongNotifier.value;
    if (song == null) return;
    final path = song.filePath ?? song.id;
    var hash = 0x811c9dc5;
    for (var i = 0; i < path.length; i++) {
      hash ^= path.codeUnitAt(i);
      hash = _imul(hash, 0x01000193);
    }
    hash ^= song.duration.inMilliseconds;
    hash = _imul(hash, 0x01000193);
    _songSeed = hash;
    _songDurationSec = math.max(10.0, song.duration.inMilliseconds / 1000.0);
  }

  static int _imul(int a, int b) {
    final ah = (a >> 16) & 0xffff;
    final al = a & 0xffff;
    final bh = (b >> 16) & 0xffff;
    final bl = b & 0xffff;
    return ((al * bl) + (((ah * bl + al * bh) << 16) >> 0)) | 0;
  }

  double _frand(int n) {
    var x = _songSeed ^ n;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = (x >> 16) ^ x;
    return (x & 0x7fffffff) / 0x7fffffff;
  }

  double _noise2D(double x, double y) {
    final ix = x.floor();
    final iy = y.floor();
    final fx = x - ix;
    final fy = y - iy;

    final n00 = _frand(ix * 73856093 ^ iy * 19349663);
    final n10 = _frand((ix + 1) * 73856093 ^ iy * 19349663);
    final n01 = _frand(ix * 73856093 ^ (iy + 1) * 19349663);
    final n11 = _frand((ix + 1) * 73856093 ^ (iy + 1) * 19349663);

    final u = fx * fx * (3.0 - 2.0 * fx);
    final v = fy * fy * (3.0 - 2.0 * fy);

    return n00 * (1 - u) * (1 - v) +
        n10 * u * (1 - v) +
        n01 * (1 - u) * v +
        n11 * u * v;
  }

  double _fbm(double x, double y, int octaves) {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    for (var i = 0; i < octaves; i++) {
      value += amplitude * _noise2D(x * frequency, y * frequency);
      amplitude *= 0.5;
      frequency *= 2.0;
    }
    return value;
  }

  double _songEnergy(double t) {
    final progress = t / _songDurationSec;
    final sectionNoise = _fbm(progress * 8.0, _songSeed * 0.1, 3);

    double energy;
    if (progress < 0.08) {
      energy = 0.2 + progress * 3.75;
    } else if (progress < 0.35) {
      energy = 0.5 + sectionNoise * 0.2;
    } else if (progress < 0.55) {
      energy = 0.75 + sectionNoise * 0.2;
    } else if (progress < 0.72) {
      energy = 0.55 + sectionNoise * 0.15;
    } else if (progress < 0.88) {
      energy = 0.85 + sectionNoise * 0.15;
    } else {
      energy = 0.6 * (1.0 - (progress - 0.88) / 0.12);
    }

    final swell =
        math.sin(progress * math.pi * 6.0 + _songSeed) * 0.08 +
        math.sin(progress * math.pi * 14.0 + _songSeed * 2.0) * 0.04;

    return (energy + swell).clamp(0.1, 1.0);
  }

  void _computeSimulatedTargets(int positionMs) {
    final t = positionMs / 1000.0;
    final energy = _songEnergy(t);

    final beatPhase = (t * (_frand(1) * 2.0 + 1.8)) % 1.0;
    final isBeat = beatPhase < 0.12;
    final beatStrength = isBeat ? (1.0 - beatPhase / 0.12) : 0.0;

    final fastBeatPhase = (t * (_frand(2) * 4.0 + 4.0)) % 1.0;
    final isFastBeat = fastBeatPhase < 0.08;
    final fastBeatStrength = isFastBeat
        ? (1.0 - fastBeatPhase / 0.08) * 0.4
        : 0.0;

    for (int i = 0; i < _barCount; i++) {
      final x = i / (_barCount - 1);

      final freqFactor = x < 0.25
          ? 0.4
          : x < 0.5
          ? 0.8
          : x < 0.75
          ? 1.3
          : 1.8;

      final barSeed = i * 7919 + _songSeed;
      final charOffset = _frand(barSeed) * 2.0 - 1.0;

      final noiseTime = t * freqFactor * (0.8 + _frand(barSeed + 1) * 0.6);
      final noiseFreq = x * 12.0 + charOffset * 3.0;
      final organic = _fbm(noiseTime, noiseFreq, 4);

      final bassEnv = math.exp(-x * 5.0);
      final midEnv = math.exp(-((x - 0.35) * 6.0).abs());
      final trebleEnv = math.exp(-((x - 0.75) * 8.0).abs());

      final bassMovement = organic * bassEnv * 0.9;
      final midMovement = organic * midEnv * 0.7;
      final trebleMovement = organic * trebleEnv * 0.5;

      final bassBeat = beatStrength * bassEnv * 0.5;
      final midBeat = beatStrength * midEnv * 0.3;
      final trebleFastBeat = fastBeatStrength * trebleEnv * 0.4;

      var height =
          (bassMovement +
              midMovement +
              trebleMovement +
              bassBeat +
              midBeat +
              trebleFastBeat) *
          energy;

      final transientChance = _frand((t * 30.0).floor() * 97 + barSeed);
      if (transientChance > 0.985) {
        height += _frand((t * 30.0).floor() * 53 + barSeed) * 0.35 * energy;
      }

      height = (height * 1.1 + 0.05).clamp(_minHeight, 1.0);
      _targetHeights[i] = height;
    }
  }

  void _onPositionChanged() {
    if (!_isPlaying || _hasLiveData || !widget.simulationFallback) return;
    final ms = widget.playerService.positionNotifier.value.inMilliseconds;
    _computeSimulatedTargets(ms);
  }

  void _onPlayingChanged() {
    final playing = widget.playerService.isPlayingNotifier.value;
    if (playing == _isPlaying) return;
    _isPlaying = playing;
    _updateControllerState();
  }

  void _updateControllerState() {
    if (!mounted) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!widget.enabled) {
      _logMotionState('still: visualizer disabled in settings');
      _motionEnabled = false;
      _setSourceAcquired(false);
      _resetAnimation();
      return;
    }
    if (!_appActive) {
      _logMotionState('paused: app is in the background');
      _motionEnabled = false;
      _setSourceAcquired(false);
      _resetAnimation();
      return;
    }
    if (reducedMotion) {
      _logMotionState(
        'still: animations are off (Android accessibility or Flick interface)',
      );
      _motionEnabled = false;
      _setSourceAcquired(false);
      _resetAnimation();
      return;
    }
    if (!TickerMode.valuesOf(context).enabled) {
      _logMotionState('paused: visualizer is not visible');
      _motionEnabled = false;
      _setSourceAcquired(false);
      _resetAnimation();
      return;
    }
    _motionEnabled = true;
    _setSourceAcquired(true);
    _logMotionState(_isPlaying ? 'running' : 'idle: playback is paused');
    _onSourceChanged();
  }

  void _setSourceAcquired(bool value) {
    if (_sourceAcquired == value) return;
    _sourceAcquired = value;
    if (value) {
      _source.acquire();
    } else {
      _source.release();
    }
  }

  void _logMotionState(String state) {
    if (_lastMotionState == state) return;
    _lastMotionState = state;
    devLog('[Visualizer] $state');
  }

  void _onSourceChanged() {
    if (!mounted || !_motionEnabled) return;
    if (!widget.simulationFallback && !_source.isAvailable) {
      _resetAnimation();
      return;
    }
    // Read playback here as well: capture may publish its pause notification
    // before this widget's playback listener runs.
    if (!widget.playerService.isPlayingNotifier.value) {
      _retarget(null);
    } else if (_hasLiveData) {
      _retarget(_source.bars);
    } else if (widget.simulationFallback) {
      if (_simulating) return;
      _simulating = true;
      _lastFrameElapsed = null;
      _onPositionChanged();
      _controller.duration = const Duration(seconds: 1);
      _controller.repeat();
    } else {
      _retarget(null);
    }
  }

  void _retarget(List<double>? bars) {
    var changed = _simulating;
    for (var i = 0; i < _barCount; i++) {
      final value = bars == null ? _minHeight : bars[i];
      final target = value.isFinite ? value.clamp(_minHeight, 1.0) : _minHeight;
      changed |= target != _targetHeights[i];
      _targetHeights[i] = target;
    }
    if (!changed) return;
    _startHeights.setAll(0, _currentHeights);
    _simulating = false;

    // Capture still stops on pause. Only the last real spectrum eases to rest.
    final settling = bars == null;
    _heightDuration = settling
        ? const Duration(milliseconds: 360)
        : switch (widget.movementMode) {
            'snappy' => const Duration(milliseconds: 70),
            'smooth' => const Duration(milliseconds: 100),
            _ => const Duration(milliseconds: 130),
          };
    final curve = settling
        ? Curves.easeOutCubic
        : switch (widget.movementMode) {
            'snappy' => Curves.easeOutQuad,
            'smooth' => Curves.easeOutCubic,
            _ => Curves.easeOutBack,
          };
    _heightProgress = CurveTween(curve: curve);
    // Keep one vsync clock while captures arrive. Restarting forward(from: 0)
    // for each capture makes every display frame a zero-time first tick when
    // capture is faster than rendering, freezing every visualizer on screen.
    _heightStartedAt = _controller.isAnimating
        ? _controller.lastElapsedDuration ?? Duration.zero
        : Duration.zero;
    if (!_controller.isAnimating) {
      _lastFrameElapsed = null;
      _controller.repeat(period: const Duration(seconds: 1));
    }
  }

  void _onFrame() {
    if (!mounted || !_motionEnabled) return;
    var deltaSeconds = 0.0;
    final scheduler = SchedulerBinding.instance;
    // Controller value changes can also notify synchronously between frames.
    // Only advance the trail clock during a frame, never during a reset.
    if (scheduler.schedulerPhase != SchedulerPhase.idle) {
      final elapsed = scheduler.currentFrameTimeStamp;
      if (_lastFrameElapsed != null) {
        deltaSeconds = math.max(
          0.0,
          (elapsed - _lastFrameElapsed!).inMicroseconds / 1e6,
        );
      }
      _lastFrameElapsed = elapsed;
    }

    var heightsSettled = false;
    if (_simulating) {
      _advancePreview();
    } else {
      final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
      final fraction =
          ((elapsed - _heightStartedAt).inMicroseconds /
                  _heightDuration.inMicroseconds)
              .clamp(0.0, 1.0);
      final progress = _heightProgress.transform(fraction);
      heightsSettled = fraction >= 1.0;
      for (var i = 0; i < _barCount; i++) {
        _currentHeights[i] =
            (_startHeights[i] +
                    (_targetHeights[i] - _startHeights[i]) * progress)
                .clamp(_minHeight, 1.0);
      }
    }
    _updateDisplayHeights();
    final trailsSettled = _updateBlockTrails(deltaSeconds);
    if (heightsSettled && trailsSettled) {
      _controller.stop();
    }
  }

  void _advancePreview() {
    // Generated movement remains opt-in and is never used by the live player.
    for (var i = 0; i < _barCount; i++) {
      switch (widget.movementMode) {
        case 'smooth':
          final blend = _targetHeights[i] >= _currentHeights[i] ? 0.55 : 0.35;
          _currentHeights[i] +=
              (_targetHeights[i] - _currentHeights[i]) * blend;
        case 'snappy':
          _currentHeights[i] += (_targetHeights[i] - _currentHeights[i]) * 0.75;
        default:
          final diff = _targetHeights[i] - _currentHeights[i];
          _velocities[i] = _velocities[i] * _damping + diff * _spring;
          _currentHeights[i] += _velocities[i];
      }
      _currentHeights[i] = _currentHeights[i].clamp(_minHeight, 1.0);
    }
    if (++_frameCount % 2 == 0) _onPositionChanged();
  }

  bool _updateBlockTrails(double deltaSeconds) {
    if (widget.animationStyle != 'blocks') return true;
    final decay = math.exp(-deltaSeconds * 6.0);
    var settled = true;
    for (var i = 0; i < _barCount; i++) {
      final litRows = (_displayHeights[i] * _blockRows).ceil();
      for (var row = 0; row < _blockRows; row++) {
        final index = i * _blockRows + row;
        final opacity = row < litRows ? 1.0 : _blockOpacities[index] * decay;
        _blockOpacities[index] = opacity < 0.01 ? 0.0 : opacity;
        if (row >= litRows && opacity >= 0.01) settled = false;
      }
    }
    return settled;
  }

  void _updateDisplayHeights() {
    for (int i = 0; i < _barCount; i++) {
      final masked = (_currentHeights[i] * _frequencyWeights[i]).clamp(
        _minHeight,
        1.0,
      );
      _displayHeights[i] = masked < 0.06 ? _minHeight : masked;
    }
  }

  static List<double> _frequencyMask(String mode) {
    final w = List<double>.filled(_barCount, 1.0);
    final n = _barCount;

    void rampDown(int start, int end) {
      for (int i = start; i <= end && i < n; i++) {
        final t = end > start ? (i - start) / (end - start) : 1.0;
        w[i] = 1.0 - t * 0.95;
      }
    }

    void rampUp(int start, int end) {
      for (int i = start; i <= end && i < n; i++) {
        final t = end > start ? (i - start) / (end - start) : 1.0;
        w[i] = 0.05 + t * 0.95;
      }
    }

    switch (mode) {
      case 'bass':
        rampDown(12, 17);
        for (int i = 18; i < n; i++) {
          w[i] = 0.05;
        }
      case 'mid':
        rampUp(0, 11);
        rampDown(36, 41);
        for (int i = 42; i < n; i++) {
          w[i] = 0.05;
        }
      case 'treble':
        for (int i = 0; i < 36; i++) {
          w[i] = 0.05;
        }
        rampUp(36, 41);
      case 'bass_treble':
        rampDown(12, 23);
        for (int i = 24; i < 36; i++) {
          w[i] = 0.05;
        }
        rampUp(36, 41);
    }
    return w;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.playerService.isPlayingNotifier.removeListener(_onPlayingChanged);
    widget.playerService.positionNotifier.removeListener(_onPositionChanged);
    widget.playerService.currentSongNotifier.removeListener(_onSongChanged);
    _sourceSubscription.close();
    if (_sourceAcquired) {
      _sourceAcquired = false;
      _source.release();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Spectrum frames go straight to the painter. Only availability can change
    // this widget's structure, so capture must not rebuild the player at 30 Hz.
    final source = ref.watch(
      visualizerSourceProvider.select(
        (value) => (mode: value.mode, available: value.isAvailable),
      ),
    );
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }
    if (!widget.simulationFallback &&
        (!source.available ||
            source.mode == VisualizerSourceMode.unavailable ||
            source.mode == VisualizerSourceMode.dsdUnavailable)) {
      return const SizedBox.shrink();
    }
    final String colorMode =
        widget.colorMode ??
        ref.watch<String>(
          appPreferencesProvider.select((prefs) => prefs.visualizerColorMode),
        );
    final albumColor = colorMode == 'album_art'
        ? widget.albumColor ?? ref.watch(albumDominantColorSyncProvider)
        : null;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _VisualizerBarPainter(
          barHeights: _displayHeights,
          animationStyle: widget.animationStyle,
          frequencyMode: widget.frequencyMode,
          colorMode: colorMode,
          albumColor: albumColor,
          blockOpacities: _blockOpacities,
          repaint: _controller,
        ),
      ),
    );
  }
}

class _VisualizerBarPainter extends CustomPainter {
  final List<double> barHeights;
  final String animationStyle;
  final String frequencyMode;
  final String colorMode;
  final Color? albumColor;
  final List<double> blockOpacities;
  late final _barPaints = _paints(barHeights.length, 0.82);
  late final _barHalos = _paints(barHeights.length, 0.10, strokeWidth: 3.0);
  late final _mirroredPaints = _paints(barHeights.length ~/ 2, 0.78);
  late final _mirroredHalos = _paints(
    barHeights.length ~/ 2,
    0.08,
    strokeWidth: 2.0,
  );
  late final _dotPaints = _paints(barHeights.length, 0.85);
  late final _dotHalos = _paints(barHeights.length, 0.12);
  late final _waveDots = _paints(barHeights.length, 0.70);
  final _fillPath = Path();
  final _linePath = Path();
  final _fillPaint = Paint();
  final _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _glowStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.0;
  Size? _shaderSize;
  _BlockGrid? _blockGrid;

  _VisualizerBarPainter({
    required this.barHeights,
    required this.animationStyle,
    required this.frequencyMode,
    required this.colorMode,
    required this.blockOpacities,
    this.albumColor,
    required Listenable repaint,
  }) : super(repaint: repaint);

  List<Paint> _paints(int count, double alpha, {double? strokeWidth}) =>
      List.generate(count, (i) {
        final paint = Paint()
          ..color = _barColor(
            count > 1 ? i / (count - 1) : 0.0,
          ).withValues(alpha: alpha);
        if (strokeWidth != null) {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth;
        }
        return paint;
      });

  Color _barColor(double t) {
    if (colorMode == 'rainbow') {
      return HSLColor.fromAHSL(1.0, t * 300.0, 0.80, 0.65).toColor();
    }
    if (colorMode == 'monochrome' || albumColor == null) {
      final b = 1.0 - t * 0.40;
      return Color.fromRGBO(
        (255 * b).round(),
        (255 * b).round(),
        (255 * b).round(),
        1.0,
      );
    }
    final hsl = HSLColor.fromColor(albumColor!);
    final l = 0.56 + t * 0.10;
    final s = hsl.saturation < 0.05
        ? 0.0
        : (hsl.saturation * 1.35 + 0.20).clamp(0.72, 1.0);
    return hsl.withLightness(l).withSaturation(s).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    switch (animationStyle) {
      case 'wave':
        _paintWave(canvas, size);
      case 'curved_wave':
        _paintCurvedWave(canvas, size);
      case 'mirrored':
        _paintMirrored(canvas, size);
      case 'dots':
        _paintDots(canvas, size);
      case 'blocks':
        _paintBlocks(canvas, size);
      default:
        _paintBars(canvas, size);
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final barCount = barHeights.length;
    final spacing = math.min(2.5, size.width / (barCount * 2));
    final totalSpacing = (barCount - 1) * spacing;
    final barWidth = (size.width - totalSpacing) / barCount;
    final maxBarHeight = size.height * 0.88;

    for (int i = 0; i < barCount; i++) {
      final height = barHeights[i] * maxBarHeight;
      final x = i * (barWidth + spacing);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - height, barWidth, height),
        const Radius.circular(2.0),
      );

      // A bounded outline keeps the highlight without 48 Gaussian blur passes.
      canvas.drawRRect(rect, _barHalos[i]);
      canvas.drawRRect(rect, _barPaints[i]);
    }
  }

  void _paintBlocks(Canvas canvas, Size size) {
    if (_blockGrid?.size != size) {
      _blockGrid = _BlockGrid(size, barHeights.length, _barColor);
    }
    _blockGrid!.paint(canvas, barHeights, blockOpacities);
  }

  Shader _rainbowShader(Size size, double alpha) => LinearGradient(
    colors: List.generate(7, (i) => _barColor(i / 6).withValues(alpha: alpha)),
  ).createShader(Offset.zero & size);

  void _ensureWaveShaders(Size size) {
    if (_shaderSize == size) return;
    _shaderSize = size;
    final curved = animationStyle == 'curved_wave';
    final maxHeight = size.height * (curved ? 0.50 : 0.44);
    _fillPaint.shader = colorMode == 'rainbow'
        ? _rainbowShader(size, curved ? 0.35 : 0.40)
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _barColor(
                curved ? 0.3 : 0.0,
              ).withValues(alpha: curved ? 0.70 : 0.85),
              _barColor(
                curved ? 0.7 : 1.0,
              ).withValues(alpha: curved ? 0.08 : 0.15),
            ],
          ).createShader(
            Rect.fromLTWH(0, size.height - maxHeight, size.width, maxHeight),
          );
    _linePaint
      ..color = _barColor(0.5).withValues(alpha: 0.95)
      ..strokeWidth = curved ? 2.2 : 1.8;
    _glowStrokePaint.color = _barColor(0.5).withValues(alpha: 0.12);
    if (colorMode == 'rainbow') {
      _linePaint.shader = _rainbowShader(size, 0.95);
      _glowStrokePaint.shader = _rainbowShader(size, 0.12);
      _linePaint.color = Colors.white;
      _glowStrokePaint.color = Colors.white;
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    _ensureWaveShaders(size);
    final barCount = barHeights.length;
    final maxHeight = size.height * 0.44;
    final baseline = size.height;
    final spacing = size.width / barCount;

    _fillPath
      ..reset()
      ..moveTo(0, baseline);
    _linePath.reset();
    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + spacing / 2;
      final y = baseline - barHeights[i] * maxHeight;
      _fillPath.lineTo(x, y);
      if (i == 0) {
        _linePath.moveTo(x, y);
      } else {
        _linePath.lineTo(x, y);
      }
    }
    _fillPath
      ..lineTo(size.width, baseline)
      ..close();
    canvas.drawPath(_fillPath, _fillPaint);
    canvas.drawPath(_linePath, _linePaint);

    for (int i = 0; i < barCount; i += 2) {
      final x = i * spacing + spacing / 2;
      final y = baseline - barHeights[i] * maxHeight;
      canvas.drawCircle(Offset(x, y), 1.5, _waveDots[i]);
    }
  }

  void _paintCurvedWave(Canvas canvas, Size size) {
    _ensureWaveShaders(size);
    final barCount = barHeights.length;
    final maxHeight = size.height * 0.50;
    final baseline = size.height;
    final spacing = size.width / (barCount - 1);

    // Convert Catmull-Rom control points to smooth cubic Bézier path.
    double y(int index) => baseline - barHeights[index] * maxHeight;
    _linePath
      ..reset()
      ..moveTo(0, y(0));
    for (var i = 0; i < barCount - 1; i++) {
      final before = i > 0 ? i - 1 : i;
      final after = i + 2 < barCount ? i + 2 : i + 1;
      _linePath.cubicTo(
        i * spacing + ((i + 1 - before) * spacing) / 6.0,
        y(i) + (y(i + 1) - y(before)) / 6.0,
        (i + 1) * spacing - ((after - i) * spacing) / 6.0,
        y(i + 1) - (y(after) - y(i)) / 6.0,
        (i + 1) * spacing,
        y(i + 1),
      );
    }

    _fillPath
      ..reset()
      ..addPath(_linePath, Offset.zero)
      ..lineTo(size.width, baseline)
      ..lineTo(0, baseline)
      ..close();
    canvas.drawPath(_fillPath, _fillPaint);
    canvas.drawPath(_linePath, _glowStrokePaint);
    canvas.drawPath(_linePath, _linePaint);
  }

  void _paintMirrored(Canvas canvas, Size size) {
    final barCount = barHeights.length;
    final half = barCount ~/ 2;
    final spacing = math.min(2.0, size.width * 0.48 / (half * 2));
    final totalSpacing = (half - 1) * spacing;
    final barWidth = (size.width * 0.48 - totalSpacing) / half;
    final maxHeight = size.height * 0.42;

    for (int i = 0; i < half; i++) {
      final leftIdx = half - 1 - i;
      final rightIdx = half + i;
      final height =
          ((barHeights[leftIdx] + barHeights[rightIdx]) / 2) * maxHeight;
      final xFromCenter = i * (barWidth + spacing) + barWidth / 2;
      final centerX = size.width / 2;
      final leftX = centerX - xFromCenter - barWidth / 2;
      final rightX = centerX + xFromCenter - barWidth / 2;

      void drawBar(double x, double y) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, height),
          const Radius.circular(1.5),
        );

        canvas.drawRRect(rect, _mirroredHalos[i]);
        canvas.drawRRect(rect, _mirroredPaints[i]);
      }

      drawBar(leftX, size.height / 2 - height);
      drawBar(rightX, size.height / 2 - height);
      drawBar(leftX, size.height / 2);
      drawBar(rightX, size.height / 2);
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    final barCount = barHeights.length;
    final maxRadius = size.height * 0.38;
    final minRadius = maxRadius * 0.04;
    final baseline = size.height / 2;
    final spacing = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + spacing / 2;
      final radius = (barHeights[i] * (maxRadius - minRadius) + minRadius)
          .clamp(minRadius, maxRadius);
      canvas.drawCircle(Offset(x, baseline), radius + 1.5, _dotHalos[i]);
      canvas.drawCircle(Offset(x, baseline), radius, _dotPaints[i]);
    }
  }

  @override
  bool shouldRepaint(_VisualizerBarPainter oldDelegate) =>
      oldDelegate.barHeights != barHeights ||
      oldDelegate.blockOpacities != blockOpacities ||
      oldDelegate.animationStyle != animationStyle ||
      oldDelegate.frequencyMode != frequencyMode ||
      oldDelegate.colorMode != colorMode ||
      oldDelegate.albumColor != albumColor;
}

/// One cached square grid, drawn as a single sprite atlas.
///
/// Drawing thousands of individual points every frame is expensive on mobile
/// GPUs. Each cell is instead a compact atlas sprite whose colour carries the
/// column gradient and row/trail alpha, so the whole grid is one draw call.
class _BlockGrid {
  static const _sourceRows = _AudioVisualizerState._blockRows;
  static const _maxColorStops = 7;

  static ui.Image? _whiteSprite;

  final Size size;
  late final int _columns;
  late final int _rows;
  late final Float32List _transforms;
  late final Float32List _rects;
  late final Int32List _colors;
  late final Uint8List _sources;
  late final Uint8List _sourceRow;
  late final Float32List _rowAlpha;
  late final Int32List _columnRgb;
  final _paint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  _BlockGrid(this.size, int barCount, Color Function(double) barColor) {
    final availableHeight = size.height * 0.88;
    final pitch = math.min(6.0, math.min(size.width, availableHeight));
    _columns = math.max(1, (size.width / pitch).floor());
    _rows = math.max(1, (availableHeight / pitch).floor());
    final left = (size.width - _columns * pitch) / 2;

    final blockSize = pitch - math.min(2.0, pitch * 0.25);
    final half = blockSize / 2;
    final cellCount = _columns * _rows;
    _transforms = Float32List(cellCount * 4);
    _rects = Float32List(cellCount * 4);
    _colors = Int32List(cellCount);
    _sources = Uint8List(_columns);
    _sourceRow = Uint8List(_rows);
    _rowAlpha = Float32List(_rows);
    _columnRgb = Int32List(_columns);

    for (var row = 0; row < _rows; row++) {
      _sourceRow[row] = row * _sourceRows ~/ _rows;
      _rowAlpha[row] = 0.88 - row / _rows * 0.30;
    }
    for (var column = 0; column < _columns; column++) {
      _sources[column] = column * barCount ~/ _columns;
      final centerX = left + (column + 0.5) * pitch;
      for (var row = 0; row < _rows; row++) {
        final cell = column * _rows + row;
        final centerY = size.height - (row + 0.5) * pitch;
        final index = cell * 4;
        // RSTransform: [scale, rotation, translateX, translateY].
        _transforms[index] = blockSize;
        _transforms[index + 1] = 0;
        _transforms[index + 2] = centerX - half;
        _transforms[index + 3] = centerY - half;
        _rects[index] = 0;
        _rects[index + 1] = 0;
        _rects[index + 2] = 1;
        _rects[index + 3] = 1;
      }
    }

    // Sample the same bounded horizontal palette once per column. Blocks are
    // only a few pixels wide, so a solid per-column colour is visually
    // identical to the old per-point shader while letting the atlas carry all
    // of the colour work in a single textured draw.
    final colorCount = math.min(_maxColorStops, math.max(2, _columns));
    final stops = List.generate(
      colorCount,
      (i) => barColor(_columns > 1 ? i / (colorCount - 1) : 0.5),
    );
    final startX = left + pitch / 2;
    final endX = left + (_columns > 1 ? _columns - 0.5 : 1.5) * pitch;
    final span = endX - startX;
    for (var column = 0; column < _columns; column++) {
      final t = span == 0
          ? 0.0
          : ((left + (column + 0.5) * pitch) - startX) / span;
      _columnRgb[column] = _sampleStops(stops, t.clamp(0.0, 1.0));
    }
  }

  static int _sampleStops(List<Color> stops, double t) {
    final scaled = t * (stops.length - 1);
    final index = math.min(scaled.floor(), stops.length - 2);
    final local = scaled - index;
    final a = stops[index].toARGB32();
    final b = stops[index + 1].toARGB32();
    int channel(int shift) {
      final from = (a >> shift) & 0xFF;
      final to = (b >> shift) & 0xFF;
      return (from + (to - from) * local).round();
    }

    return 0xFF000000 | (channel(16) << 16) | (channel(8) << 8) | channel(0);
  }

  static ui.Image _getWhiteSprite() {
    final cached = _whiteSprite;
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(1, 1);
    picture.dispose();
    return _whiteSprite = image;
  }

  void paint(Canvas canvas, List<double> heights, List<double> trails) {
    for (var column = 0; column < _columns; column++) {
      final source = _sources[column];
      final litRows = (heights[source] * _rows).ceil().clamp(0, _rows);
      final rgb = _columnRgb[column] & 0x00FFFFFF;
      final trailBase = source * _sourceRows;
      final cellBase = column * _rows;
      for (var row = 0; row < _rows; row++) {
        final intensity = row < litRows
            ? 1.0
            : trails[trailBase + _sourceRow[row]];
        final alpha = (intensity * _rowAlpha[row] * 255).round().clamp(0, 255);
        _colors[cellBase + row] = alpha == 0 ? 0 : (alpha << 24) | rgb;
      }
    }
    canvas.drawRawAtlas(
      _getWhiteSprite(),
      _transforms,
      _rects,
      _colors,
      ui.BlendMode.modulate,
      null,
      _paint,
    );
  }
}
