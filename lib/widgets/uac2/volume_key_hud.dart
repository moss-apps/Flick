import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/services/player_service.dart' show VolumeKeyFeedback;

/// Briefly shows the DAC level on top of the app after a phone volume key.
///
/// While the DAC owns the keys the activity consumes them, so Android shows no
/// volume panel of its own; this stands in for it.
class VolumeKeyHudHost extends StatefulWidget {
  const VolumeKeyHudHost({
    super.key,
    required this.feedback,
    required this.child,
  });

  final ValueListenable<VolumeKeyFeedback?> feedback;
  final Widget child;

  @override
  State<VolumeKeyHudHost> createState() => _VolumeKeyHudHostState();
}

class _VolumeKeyHudHostState extends State<VolumeKeyHudHost> {
  static const Duration _visibleFor = Duration(milliseconds: 1500);

  Timer? _hideTimer;
  VolumeKeyFeedback? _shown;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.feedback.addListener(_onFeedback);
  }

  @override
  void didUpdateWidget(VolumeKeyHudHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feedback != widget.feedback) {
      oldWidget.feedback.removeListener(_onFeedback);
      widget.feedback.addListener(_onFeedback);
      _onFeedback();
    }
  }

  @override
  void dispose() {
    widget.feedback.removeListener(_onFeedback);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onFeedback() {
    final feedback = widget.feedback.value;
    _hideTimer?.cancel();
    if (feedback == null) {
      if (_shown != null) {
        setState(() {
          _shown = null;
          _visible = false;
        });
      }
      return;
    }
    _hideTimer = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
    setState(() {
      _shown = feedback;
      _visible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (shown != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppConstants.spacingMd,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                excluding: !_visible,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: _VolumeKeyHud(feedback: shown),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VolumeKeyHud extends StatelessWidget {
  const _VolumeKeyHud({required this.feedback});

  final VolumeKeyFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final level = feedback.level.clamp(0.0, 1.0);
    final percent = (level * 100).round();
    return Semantics(
      liveRegion: true,
      label: '${l10n.volume} $percent%',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(
                feedback.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                size: 18,
                color: feedback.muted
                    ? Colors.red.shade400
                    : AppColors.textPrimary,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: level,
                    minHeight: 4,
                    color: AppColors.accent,
                    backgroundColor: AppColors.textTertiary.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              SizedBox(
                width: 40,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
