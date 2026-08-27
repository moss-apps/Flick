import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show ScrollCacheExtent, ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/features/player/widgets/album_color_helpers.dart';
import 'package:flick/features/player/widgets/karaoke_lyric_line.dart';
import 'package:flick/features/player/widgets/lyrics_alignment.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';

/// Synced lyrics list with a fixed focus anchor: the active line pins at
/// [_anchorFraction] of the viewport height, per-line geometry comes from a
/// measured-height registry (TextPainter estimates until real sizes arrive),
/// and animations are single-flight — a new target simply interrupts the
/// previous animateTo.
///
/// User drags suspend auto-following; it resumes after [_followResumeMs] of
/// idle, or immediately on a tap-to-seek or external seek.
class SyncedLyricsView extends ConsumerStatefulWidget {
  final PlayerService playerService;
  final LyricsService lyricsService;
  final LyricsData lyrics;
  final Color? albumColor;

  const SyncedLyricsView({
    super.key,
    required this.playerService,
    required this.lyricsService,
    required this.lyrics,
    this.albumColor,
  });

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView> {
  static const double _anchorFraction = 0.32;
  static const int _followResumeMs = 4000;
  static const int _seekBackThresholdMs = 1200;
  static const int _seekForwardThresholdMs = 3000;
  static const double _measureEpsilonPx = 0.5;
  static const double _correctionMinDeltaPx = 6;

  final ScrollController _scrollController = ScrollController();

  List<double> _inactiveEstimates = const [];
  List<double> _activeEstimates = const [];
  List<double?> _measuredHeights = const [];
  List<double> _lineTops = const [];
  double? _estimatesForWidth;
  LyricsData? _estimatesForLyrics;

  int _activeLineIndex = -1;
  Duration _lastTickPosition = Duration.zero;
  bool _following = true;
  Timer? _followResumeTimer;
  bool _needsInitialJump = true;

  @override
  void initState() {
    super.initState();
    widget.playerService.positionNotifier.addListener(_onPositionChanged);
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerService != widget.playerService) {
      oldWidget.playerService.positionNotifier.removeListener(_onPositionChanged);
      widget.playerService.positionNotifier.addListener(_onPositionChanged);
    }
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _estimatesForWidth = null;
      _needsInitialJump = true;
    }
  }

  @override
  void dispose() {
    _followResumeTimer?.cancel();
    widget.playerService.positionNotifier.removeListener(_onPositionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    final position = widget.playerService.positionNotifier.value;
    final deltaMs = position.inMilliseconds - _lastTickPosition.inMilliseconds;
    _lastTickPosition = position;
    final isSeekBack = deltaMs <= -_seekBackThresholdMs;
    final isSeek = isSeekBack || deltaMs >= _seekForwardThresholdMs;

    final newIndex = widget.lyricsService.findCurrentLineIndex(
      widget.lyrics,
      position,
    );
    if (newIndex == _activeLineIndex) {
      if (isSeek) _resumeFollow();
      return;
    }

    // Transient position dips from the audio engine must not scroll back.
    if (newIndex < _activeLineIndex && !isSeekBack) return;

    _setActiveIndex(newIndex);
    if (isSeek) _resumeFollow(animateNow: false);
    if (_following) {
      _animateToActiveLine(immediate: isSeek);
    }
  }

  void _syncToPosition() {
    final position = widget.playerService.positionNotifier.value;
    _lastTickPosition = position;
    final newIndex = widget.lyricsService.findCurrentLineIndex(
      widget.lyrics,
      position,
    );
    if (newIndex != _activeLineIndex) {
      _setActiveIndex(newIndex);
    }
    _jumpToActiveLine();
  }

  Future<void> _seekToLine(int index) async {
    if (index < 0 || index >= widget.lyrics.lines.length) return;
    final target = widget.lyrics.lines[index].timestamp;
    widget.playerService.positionNotifier.value = target;
    _lastTickPosition = target;
    _resumeFollow(animateNow: false);
    _setActiveIndex(index);
    _animateToActiveLine();
    await widget.playerService.seek(target);
  }

  // --- geometry ---------------------------------------------------------

  void _ensureEstimates(double listWidth) {
    if (_estimatesForWidth == listWidth &&
        identical(_estimatesForLyrics, widget.lyrics)) {
      return;
    }
    final lines = widget.lyrics.lines;
    final textWidth = listWidth - 44 > 24 ? listWidth - 44 : 24.0;
    final inactive = <double>[];
    final active = <double>[];
    for (final line in lines) {
      inactive.add(
        32 + _estimateTextHeight(line.text, 17, 1.24, 2, textWidth),
      );
      active.add(28 + _estimateTextHeight(line.text, 22, 1.18, 3, textWidth));
    }
    _inactiveEstimates = inactive;
    _activeEstimates = active;
    _measuredHeights = List<double?>.filled(lines.length, null);
    _lineTops = List<double>.filled(lines.length, 0);
    _estimatesForWidth = listWidth;
    _estimatesForLyrics = widget.lyrics;
    _recomputeTops();
  }

  double _estimateTextHeight(
    String text,
    double fontSize,
    double heightFactor,
    int maxLines,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'ProductSans',
          fontSize: fontSize,
          height: heightFactor,
          fontWeight: maxLines == 3 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );
    painter.layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _heightOf(int index) {
    final measured = index < _measuredHeights.length
        ? _measuredHeights[index]
        : null;
    if (measured != null) return measured;
    return index == _activeLineIndex
        ? _activeEstimates[index]
        : _inactiveEstimates[index];
  }

  void _recomputeTops() {
    final count = widget.lyrics.lines.length;
    if (_lineTops.length != count) {
      _lineTops = List<double>.filled(count, 0);
    }
    var top = 0.0;
    for (var i = 0; i < count; i++) {
      _lineTops[i] = top;
      top += _heightOf(i);
    }
  }

  void _onLineMeasured(int index, double height) {
    if (index >= _measuredHeights.length) return;
    final current = _heightOf(index);
    if ((current - height).abs() <= _measureEpsilonPx) {
      _measuredHeights[index] = height;
      return;
    }
    _measuredHeights[index] = height;
    _recomputeTops();
    if (_following && _scrollController.hasClients) {
      final target = _targetFor(_activeLineIndex);
      if (target != null &&
          (target - _scrollController.offset).abs() >
              _correctionMinDeltaPx) {
        _animateToActiveLine();
      }
    }
  }

  void _setActiveIndex(int index) {
    if (index == _activeLineIndex) return;
    if (_activeLineIndex >= 0 && _activeLineIndex < _measuredHeights.length) {
      _measuredHeights[_activeLineIndex] = null;
    }
    _activeLineIndex = index;
    if (index >= 0 && index < _measuredHeights.length) {
      _measuredHeights[index] = null;
    }
    _recomputeTops();
    setState(() {});
  }

  // --- scrolling --------------------------------------------------------

  double? _targetFor(int index) {
    if (!_scrollController.hasClients) return null;
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final anchorPx = viewport * _anchorFraction;
    if (index < 0) return 0.0;
    if (index >= _lineTops.length) return null;
    final center =
        viewport * _anchorFraction + _lineTops[index] + _heightOf(index) / 2;
    return (center - anchorPx).clamp(0.0, position.maxScrollExtent);
  }

  void _animateToActiveLine({bool immediate = false}) {
    if (!_scrollController.hasClients) return;
    final target = _targetFor(_activeLineIndex);
    if (target == null) return;
    final distance = (target - _scrollController.offset).abs();
    final durationMs = immediate
        ? 350
        : (250 + distance * 0.6).clamp(250, 600).round();
    _scrollController
        .animateTo(
          target,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        )
        .catchError((_) {});
  }

  void _jumpToActiveLine() {
    if (!_scrollController.hasClients) return;
    final target = _targetFor(_activeLineIndex);
    if (target == null) return;
    _scrollController.jumpTo(target);
  }

  void _suspendFollow() {
    _followResumeTimer?.cancel();
    _followResumeTimer = Timer(const Duration(milliseconds: _followResumeMs), () {
      if (!mounted) return;
      _following = true;
      _animateToActiveLine();
    });
    _following = false;
  }

  void _resumeFollow({bool animateNow = true}) {
    _followResumeTimer?.cancel();
    _following = true;
    if (animateNow) _animateToActiveLine();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final userDragging =
        (notification is ScrollStartNotification &&
            notification.dragDetails != null) ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle);
    if (userDragging) _suspendFollow();
    return false;
  }

  // --- rendering --------------------------------------------------------

  double _opacityForIndex(int index) {
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

  TextStyle _textStyle(bool isActive, double opacity) {
    return TextStyle(
      fontFamily: 'ProductSans',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: Colors.white.withValues(alpha: opacity),
    );
  }

  StrutStyle _strutStyle(bool isActive) {
    return StrutStyle(
      fontFamily: 'ProductSans',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      forceStrutHeight: true,
    );
  }

  Color get _sungColor {
    final albumColor = widget.albumColor;
    if (albumColor != null) {
      return albumAccent(albumColor, 0.7, lightness: 0.88);
    }
    return Colors.white;
  }

  Widget _buildLine(BuildContext context, int index, LyricsAlignment alignment) {
    final line = widget.lyrics.lines[index];
    final isActive = index == _activeLineIndex;

    final content = isActive
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: KaraokeLyricLine(
              playerService: widget.playerService,
              lyricsService: widget.lyricsService,
              lyrics: widget.lyrics,
              lineIndex: index,
              textAlign: alignment.textAlign,
              style: _textStyle(true, 1),
              sungColor: _sungColor,
              unsungColor: Colors.white.withValues(alpha: 0.30),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              line.text,
              maxLines: 2,
              overflow: TextOverflow.fade,
              textAlign: alignment.textAlign,
              style: _textStyle(false, _opacityForIndex(index)),
              strutStyle: _strutStyle(false),
            ),
          );

    return _MeasuredLine(
      index: index,
      onMeasured: _onLineMeasured,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => unawaited(_seekToLine(index)),
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alignment = resolveLyricsAlignment(
      ref.watch(appPreferencesProvider).lyricsTextAlign,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureEstimates(constraints.maxWidth);
        if (_needsInitialJump) {
          _needsInitialJump = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncToPosition();
          });
        }

        final anchorPx = constraints.maxHeight * _anchorFraction;
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ListView.builder(
            controller: _scrollController,
            scrollCacheExtent: ScrollCacheExtent.pixels(900),
            padding: EdgeInsets.only(
              top: anchorPx,
              bottom: constraints.maxHeight - anchorPx,
              left: 10,
              right: 10,
            ),
            itemCount: widget.lyrics.lines.length,
            itemBuilder: (context, index) =>
                _buildLine(context, index, alignment),
          ),
        );
      },
    );
  }
}

/// Reports its rendered height after each frame so the parent can keep its
/// line geometry registry in sync with reality.
class _MeasuredLine extends StatefulWidget {
  final int index;
  final void Function(int index, double height) onMeasured;
  final Widget child;

  const _MeasuredLine({
    required this.index,
    required this.onMeasured,
    required this.child,
  });

  @override
  State<_MeasuredLine> createState() => _MeasuredLineState();
}

class _MeasuredLineState extends State<_MeasuredLine> {
  double? _reported;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }

  void _report() {
    if (!mounted) return;
    final size = context.size;
    if (size == null) return;
    if (_reported != null &&
        (_reported! - size.height).abs() <= 0.5) {
      return;
    }
    _reported = size.height;
    widget.onMeasured(widget.index, size.height);
  }
}
