import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/audio_preload_service.dart';
import 'package:flick/services/scan_session_controller.dart';

/// Floating pill (plus expandable card) that keeps scan/preload progress
/// visible after the full-screen overlay is minimized.
///
/// Two sources, in priority order:
/// 1. An active [ScanSessionController] session whose overlay was minimized
///    (scan all folders, single folder, manual preload, ReplayGain scan).
/// 2. A running post-scan auto preload pass (no active session).
class FloatingScanProgress extends StatefulWidget {
  const FloatingScanProgress({super.key});

  @override
  State<FloatingScanProgress> createState() => _FloatingScanProgressState();
}

class _FloatingScanProgressState extends State<FloatingScanProgress> {
  bool _expanded = false;
  DateTime? _autoPreloadSince;
  Timer? _elapsedTimer;

  bool get _sessionVisible =>
      ScanSessionController.instance.isVisible;

  bool get _autoVisible =>
      !ScanSessionController.instance.isActive &&
      AudioPreloadService.instance.progress.value != null;

  bool get _visible => _sessionVisible || _autoVisible;

  @override
  void initState() {
    super.initState();
    final controller = ScanSessionController.instance;
    controller.session.addListener(_onChanged);
    controller.progress.addListener(_onChanged);
    controller.minimized.addListener(_onChanged);
    AudioPreloadService.instance.progress.addListener(_onChanged);
    if (_autoVisible) _autoPreloadSince = DateTime.now();
    _syncTimer();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    final controller = ScanSessionController.instance;
    controller.session.removeListener(_onChanged);
    controller.progress.removeListener(_onChanged);
    controller.minimized.removeListener(_onChanged);
    AudioPreloadService.instance.progress.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
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
    if (_sessionVisible) {
      ScanSessionController.instance.cancel();
    } else {
      AudioPreloadService.instance.cancel();
    }
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final entering = child.key == const ValueKey('floating_scan_card');
        return SlideTransition(
          position: Tween<Offset>(
            begin: entering ? const Offset(0, 0.35) : Offset.zero,
            end: entering ? Offset.zero : const Offset(0, 0.35),
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _visible
          ? _buildCard()
          : const SizedBox.shrink(key: ValueKey('floating_scan_hidden')),
    );
  }

  Widget _buildCard() {
    final controller = ScanSessionController.instance;
    final session = controller.session.value;
    final scanProgress = session == null
        ? null
        : controller.progress.value;
    final preloadProgress = session == null
        ? AudioPreloadService.instance.progress.value
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
      session != null ? scanProgress?.currentFile : preloadProgress?.currentFile,
    );
    final startedAt = session?.startedAt ?? _autoPreloadSince ?? DateTime.now();
    final icon = switch (session?.kind) {
          ScanSessionKind.scan => LucideIcons.scanSearch,
          ScanSessionKind.replayGain => LucideIcons.audioWaveform,
          ScanSessionKind.preload || null => LucideIcons.activity,
        };

    return Container(
      key: const ValueKey('floating_scan_card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.92),
            AppColors.surface.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: AppConstants.animationFast,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _buildExpandedBody(
                  icon: icon,
                  title: title,
                  fraction: fraction,
                  processed: processed,
                  total: total,
                  currentFile: currentFile,
                  startedAt: startedAt,
                  failed: preloadProgress?.failed ?? 0,
                )
              : _buildCollapsedPill(
                  icon: icon,
                  title: title,
                  fraction: fraction,
                  processed: processed,
                  total: total,
                ),
        ),
      ),
    );
  }

  Widget _buildCollapsedPill({
    required IconData icon,
    required String title,
    required double fraction,
    required int processed,
    required int total,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = true),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total > 0 ? '$title · $processed/$total' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ProductSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusRound,
                      ),
                      child: LinearProgressIndicator(
                        value: total > 0 ? fraction : null,
                        minHeight: 3,
                        backgroundColor: AppColors.glassBackground,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronUp,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBody({
    required IconData icon,
    required String title,
    required double fraction,
    required int processed,
    required int total,
    required String? currentFile,
    required DateTime startedAt,
    required int failed,
  }) {
    return Padding(
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
                ? '$processed / $total files${failed > 0 ? ' · $failed failed' : ''}'
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
                onPressed: () => setState(() => _expanded = false),
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
    );
  }
}
