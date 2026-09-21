import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/floating_scan_indicator_side.dart';
import 'package:flick/services/audio_preload_service.dart';
import 'package:flick/services/floating_scan_indicator_preference_service.dart';
import 'package:flick/services/scan_session_controller.dart';

/// Pinned bubble (plus anchored details card) that keeps scan/preload progress
/// visible after the full-screen overlay is minimized.
///
/// Two sources, in priority order:
/// 1. An active [ScanSessionController] session whose overlay was minimized
///    (scan all folders, single folder, manual preload, ReplayGain scan).
/// 2. A running post-scan auto preload pass (no active session).
///
/// The bubble can be dragged anywhere and snaps to the nearest screen edge;
/// its side and vertical position persist across launches.
class FloatingScanProgress extends StatefulWidget {
  const FloatingScanProgress({
    super.key,
    this.autoPreloadProgress,
    this.onCancelAutoPreload,
  });

  /// Progress notifier for the silent post-scan auto preload pass. Defaults to
  /// the app-wide [AudioPreloadService] notifier; tests inject a local one to
  /// avoid spinning up the service.
  final ValueNotifier<PreloadProgress?>? autoPreloadProgress;

  /// Stops the silent post-scan auto preload pass. Defaults to
  /// [AudioPreloadService.cancel]; tests inject a stub so the database-backed
  /// singleton is never constructed.
  final VoidCallback? onCancelAutoPreload;

  @override
  State<FloatingScanProgress> createState() => _FloatingScanProgressState();
}

class _FloatingScanProgressState extends State<FloatingScanProgress>
    with WidgetsBindingObserver {
  static const double _bubbleSize = 52;
  static const double _edgeMargin = 8;
  static const double _cardGap = 8;
  static const double _cardMaxWidth = 300;
  static const double _estimatedCardHeight = 220;

  final _prefs = FloatingScanIndicatorPreferenceService();

  bool _expanded = false;
  bool _pressed = false;
  bool _autoStopped = false;
  DateTime? _autoPreloadSince;
  Timer? _elapsedTimer;

  FloatingScanIndicatorSide _side = FloatingScanIndicatorSide.right;
  double? _yFraction;

  Offset? _dragPosition;
  Offset _dragStartPointer = Offset.zero;
  Offset _dragStartPosition = Offset.zero;
  bool _isDragging = false;
  Offset _resolvedPosition = Offset.zero;

  ValueNotifier<PreloadProgress?> get _autoPreloadProgress =>
      widget.autoPreloadProgress ?? AudioPreloadService.instance.progress;

  bool get _sessionVisible => ScanSessionController.instance.isVisible;

  bool get _autoVisible =>
      !ScanSessionController.instance.isActive &&
      _autoPreloadProgress.value != null &&
      !_autoStopped;

  bool get _visible => _sessionVisible || _autoVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final controller = ScanSessionController.instance;
    controller.session.addListener(_onChanged);
    controller.progress.addListener(_onChanged);
    controller.minimized.addListener(_onChanged);
    _autoPreloadProgress.addListener(_onChanged);
    if (_autoVisible) _autoPreloadSince = DateTime.now();
    _syncTimer();
    unawaited(_loadPosition());
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final controller = ScanSessionController.instance;
    controller.session.removeListener(_onChanged);
    controller.progress.removeListener(_onChanged);
    controller.minimized.removeListener(_onChanged);
    _autoPreloadProgress.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPosition() async {
    final side = await _prefs.getSide();
    final yFraction = await _prefs.getYFraction();
    if (!mounted) return;
    setState(() {
      _side = side;
      _yFraction = yFraction;
    });
  }

  void _onChanged() {
    if (_autoPreloadProgress.value == null) _autoStopped = false;
    if (_autoVisible) {
      _autoPreloadSince ??= DateTime.now();
    } else {
      _autoPreloadSince = null;
    }
    if (!_visible) _expanded = false;
    _syncTimer();
    if (mounted) setState(() {});
  }

  void _syncTimer() {
    final needsTicker = _visible && _expanded;
    if (needsTicker && _elapsedTimer == null) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _elapsedTimer != null) {
      _elapsedTimer!.cancel();
      _elapsedTimer = null;
    }
  }

  void _stop() {
    final controller = ScanSessionController.instance;
    final session = controller.session.value;
    if (session != null) {
      // The owning flow only reaches its end() once the scan stream drains,
      // which lags the cancel hook; clear the session now so the bubble
      // leaves the screen the moment Stop is pressed.
      controller.stop();
      // Scan and preload cancels share the auto preload pass. Suppress it up
      // front: a post-scan auto pass can still be enqueued after this cancel,
      // and letting it resurface would defeat the Stop action.
      setState(() {
        _autoStopped = true;
        _expanded = false;
      });
      return;
    }
    (widget.onCancelAutoPreload ?? AudioPreloadService.instance.cancel)();
    setState(() {
      _autoStopped = true;
      _expanded = false;
    });
  }

  void _toggleExpanded() {
    if (!_visible) return;
    setState(() => _expanded = !_expanded);
  }

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

  ({double top, double bottom, double width}) _layoutFor(
    Size size,
    EdgeInsets padding,
  ) {
    final minTop = padding.top + _edgeMargin;
    final maxTop = math.max(
      minTop,
      size.height -
          padding.bottom -
          AppConstants.navBarHeight -
          _edgeMargin -
          _bubbleSize,
    );
    return (top: minTop, bottom: maxTop, width: size.width);
  }

  double _resolveTop(Size size, EdgeInsets padding) {
    final layout = _layoutFor(size, padding);
    final fraction = _yFraction;
    if (fraction != null) {
      return layout.top + fraction * (layout.bottom - layout.top);
    }
    final restTop =
        size.height -
        padding.bottom -
        AppConstants.navBarHeight -
        AppConstants.spacingLg -
        _bubbleSize;
    return restTop.clamp(layout.top, layout.bottom).toDouble();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = false;
    _dragStartPointer = details.globalPosition;
    _dragStartPosition = _resolvedPosition;
    if (_expanded) setState(() => _expanded = false);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final delta = details.globalPosition - _dragStartPointer;
    if (!_isDragging && delta.distance > 4) _isDragging = true;
    if (!_isDragging) return;

    final layout = _layoutFor(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
    );
    setState(() {
      _dragPosition = Offset(
        (_dragStartPosition.dx + delta.dx)
            .clamp(_edgeMargin, layout.width - _bubbleSize - _edgeMargin)
            .toDouble(),
        (_dragStartPosition.dy + delta.dy)
            .clamp(layout.top, layout.bottom)
            .toDouble(),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final position = _dragPosition;
    if (!_isDragging || position == null) {
      setState(() => _isDragging = false);
      return;
    }

    final layout = _layoutFor(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
    );
    final centerX = position.dx + _bubbleSize / 2;
    final side = centerX < layout.width / 2
        ? FloatingScanIndicatorSide.left
        : FloatingScanIndicatorSide.right;
    final span = layout.bottom - layout.top;
    final yFraction = span <= 0 ? 0.0 : (position.dy - layout.top) / span;

    setState(() {
      _isDragging = false;
      _dragPosition = null;
      _side = side;
      _yFraction = yFraction.clamp(0.0, 1.0).toDouble();
    });

    unawaited(_prefs.setSide(side));
    unawaited(_prefs.setYFraction(_yFraction!));
  }

  String _formatElapsed(DateTime since) {
    final elapsed = DateTime.now().difference(since);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }

  String? _basename(String? path) {
    if (path == null || path.isEmpty) return null;
    final slashed = path.split('/').last;
    return slashed.isEmpty ? path : slashed;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.isEmpty) return const SizedBox.shrink();

        final padding = MediaQuery.paddingOf(context);
        final position =
            _dragPosition ??
            Offset(
              _side == FloatingScanIndicatorSide.right
                  ? size.width - _bubbleSize - _edgeMargin
                  : _edgeMargin,
              _resolveTop(size, padding),
            );
        _resolvedPosition = position;

        final controller = ScanSessionController.instance;
        final session = controller.session.value;
        final scanProgress = session == null ? null : controller.progress.value;
        final preloadProgress = session == null
            ? _autoPreloadProgress.value
            : null;

        final title = session?.title ?? 'Preloading audio';
        final fraction = session != null
            ? (scanProgress?.progressFraction ?? 0.0)
            : (preloadProgress?.fraction ?? 0.0);
        final processed = session != null
            ? (scanProgress?.filesProcessed ?? 0)
            : (preloadProgress?.completed ?? 0);
        final total = session != null
            ? (scanProgress?.totalFiles ?? 0)
            : (preloadProgress?.total ?? 0);
        final currentFile = _basename(
          session != null
              ? scanProgress?.currentFile
              : preloadProgress?.currentFile,
        );
        final startedAt =
            session?.startedAt ?? _autoPreloadSince ?? DateTime.now();
        final icon = switch (session?.kind) {
          ScanSessionKind.scan => LucideIcons.scanSearch,
          ScanSessionKind.replayGain => LucideIcons.audioWaveform,
          ScanSessionKind.preload || null => LucideIcons.activity,
        };
        final foldersTotal = scanProgress?.foldersTotal ?? 0;
        final folderStatus = foldersTotal > 1
            ? 'Folder ${scanProgress?.foldersCompleted ?? 0} of $foldersTotal'
            : null;
        // All files counted but the stream has not finished yet: say so instead
        // of letting the card look done.
        final finishingUp =
            session != null &&
            total > 0 &&
            processed >= total &&
            scanProgress?.isComplete != true;

        return IgnorePointer(
          ignoring: !_visible,
          child: TickerMode(
            enabled: _visible,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_expanded && _visible)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _collapse,
                    ),
                  ),
                AnimatedPositioned(
                  duration: _isDragging
                      ? Duration.zero
                      : AppConstants.animationNormal,
                  curve: Curves.easeOutCubic,
                  left: position.dx,
                  top: position.dy,
                  child: _buildBubble(
                    icon: icon,
                    fraction: fraction.clamp(0.0, 1.0).toDouble(),
                    total: total,
                  ),
                ),
                _buildCard(
                  size: size,
                  padding: padding,
                  icon: icon,
                  title: title,
                  fraction: fraction.clamp(0.0, 1.0).toDouble(),
                  processed: processed,
                  total: total,
                  currentFile: currentFile,
                  startedAt: startedAt,
                  failed: preloadProgress?.failed ?? 0,
                  folderStatus: folderStatus,
                  finishingUp: finishingUp,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubble({
    required IconData icon,
    required double fraction,
    required int total,
  }) {
    return GestureDetector(
      onTap: _toggleExpanded,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedOpacity(
        key: const ValueKey('floating_scan_bubble'),
        opacity: _visible ? 1 : 0,
        duration: AppConstants.animationFast,
        child: AnimatedScale(
          scale: _visible ? (_pressed ? 0.92 : 1) : 0.6,
          duration: AppConstants.animationNormal,
          curve: Curves.easeOutCubic,
          child: Semantics(
            button: true,
            label: 'Scan progress',
            child: Container(
              width: _bubbleSize,
              height: _bubbleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surfaceLight.withValues(alpha: 0.92),
                    AppColors.surface.withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(color: AppColors.glassBorderStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: CircularProgressIndicator(
                        value: total > 0 ? fraction : null,
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppColors.glassBackground,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  Icon(icon, size: 20, color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Size size,
    required EdgeInsets padding,
    required IconData icon,
    required String title,
    required double fraction,
    required int processed,
    required int total,
    required String? currentFile,
    required DateTime startedAt,
    required int failed,
    String? folderStatus,
    bool finishingUp = false,
  }) {
    final cardWidth = math.min(_cardMaxWidth, size.width - _edgeMargin * 2);
    final bubbleTop = _resolvedPosition.dy;
    final bubbleBottom = bubbleTop + _bubbleSize;
    final roomAbove =
        bubbleTop - _cardGap - _estimatedCardHeight >=
        padding.top + _edgeMargin;
    final below = !roomAbove;
    final rightAligned = _side == FloatingScanIndicatorSide.right;

    return AnimatedPositioned(
      duration: AppConstants.animationNormal,
      curve: Curves.easeOutCubic,
      left: rightAligned ? null : _edgeMargin,
      right: rightAligned ? _edgeMargin : null,
      top: below ? bubbleBottom + _cardGap : null,
      bottom: below ? null : size.height - bubbleTop + _cardGap,
      child: IgnorePointer(
        ignoring: !_expanded,
        child: ExcludeSemantics(
          excluding: !_expanded,
          child: AnimatedOpacity(
            key: const ValueKey('floating_scan_card'),
            opacity: _expanded ? 1 : 0,
            duration: AppConstants.animationFast,
            child: AnimatedScale(
              scale: _expanded ? 1 : 0.94,
              alignment: below
                  ? (rightAligned ? Alignment.topRight : Alignment.topLeft)
                  : (rightAligned
                        ? Alignment.bottomRight
                        : Alignment.bottomLeft),
              duration: AppConstants.animationNormal,
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: cardWidth,
                child: _buildCardContent(
                  icon: icon,
                  title: title,
                  fraction: fraction,
                  processed: processed,
                  total: total,
                  currentFile: currentFile,
                  startedAt: startedAt,
                  failed: failed,
                  folderStatus: folderStatus,
                  finishingUp: finishingUp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent({
    required IconData icon,
    required String title,
    required double fraction,
    required int processed,
    required int total,
    required String? currentFile,
    required DateTime startedAt,
    required int failed,
    String? folderStatus,
    bool finishingUp = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.96),
            AppColors.surface.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'ProductSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatElapsed(startedAt),
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusRound),
              child: LinearProgressIndicator(
                value: total > 0 ? fraction : null,
                minHeight: 5,
                backgroundColor: AppColors.glassBackground,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              total > 0
                  ? '$processed / $total files${finishingUp ? ' · Finishing up…' : ''}${folderStatus != null ? ' · $folderStatus' : ''}${failed > 0 ? ' · $failed failed' : ''}'
                  : 'Counting files…',
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (currentFile != null && currentFile.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                currentFile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _stop,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Stop',
                    style: TextStyle(
                      fontFamily: 'ProductSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _collapse,
                  icon: Icon(
                    LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
