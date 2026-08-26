import 'dart:math' as math;

import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/milestone_service.dart';
import '../../../widgets/common/vinyl_record.dart';

/// Signature celebration card shown when a milestone is unlocked. The visual
/// anchor is a hand-painted vinyl record — a deliberate reference to Flick's
/// music-player identity — with a tier-tinted center label. The card chrome
/// stays in the app's monochrome glass vocabulary; the tier color is reserved
/// for the disc label and a thin accent dot next to the title.
class MilestoneCard extends StatefulWidget {
  const MilestoneCard({
    super.key,
    required this.milestone,
    this.achievedAt,
    this.nextMilestone,
    this.nextRemaining,
    this.supportLabel = 'Support Flick',
    this.dismissLabel = 'Dismiss',
    this.onSupportTap,
  });

  final MilestoneType milestone;
  final DateTime? achievedAt;
  final MilestoneType? nextMilestone;
  final int? nextRemaining;
  final String supportLabel;
  final String dismissLabel;

  /// Called when the user taps the support action. If null, the host screen
  /// is responsible for navigating to its own support page.
  final VoidCallback? onSupportTap;

  @override
  State<MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<MilestoneCard>
    with TickerProviderStateMixin {
  late final AnimationController _discController;
  late final Animation<double> _discScale;
  late final Animation<double> _discRotation;

  late final AnimationController _contentController;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  late final AnimationController _actionsController;
  late final Animation<double> _actionsFade;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _discScale = CurvedAnimation(
      parent: _discController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );
    _discRotation = CurvedAnimation(
      parent: _discController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    _actionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _actionsFade = CurvedAnimation(
      parent: _actionsController,
      curve: Curves.easeOutCubic,
    );

    _discController.forward();
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _contentController.forward();
    });
    Future<void>.delayed(const Duration(milliseconds: 560), () {
      if (mounted) _actionsController.forward();
    });
  }

  @override
  void dispose() {
    _discController.dispose();
    _contentController.dispose();
    _actionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = widget.milestone.tierColor;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FlickDialogSurface(
        width: 320,
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingXl,
          AppConstants.spacingLg,
          AppConstants.spacingLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildDisc(tierColor)),
            const SizedBox(height: AppConstants.spacingLg),
            FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: _buildContent(context, tierColor),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            FadeTransition(
              opacity: _actionsFade,
              child: _buildActions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisc(Color tierColor) {
    return AnimatedBuilder(
      animation: _discController,
      builder: (context, _) {
        final scale = _discScale.value.clamp(0.001, double.infinity);
        final rotation = (_discRotation.value - 1.0) * (math.pi / 6);
        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: VinylRecord(size: 104, labelColor: tierColor),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, Color tierColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACHIEVEMENT UNLOCKED',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          widget.milestone.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          widget.milestone.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        if (widget.achievedAt != null ||
            (widget.nextMilestone != null && widget.nextRemaining != null)) ...[
          const SizedBox(height: AppConstants.spacingMd),
          Container(height: 1, color: AppColors.glassBorder),
          const SizedBox(height: AppConstants.spacingSm),
          _buildMetaLine(context, tierColor),
        ],
      ],
    );
  }

  Widget _buildMetaLine(BuildContext context, Color tierColor) {
    final parts = <String>[];
    if (widget.achievedAt != null) {
      parts.add('Achieved ${_formatDate(widget.achievedAt!)}');
    }
    final next = widget.nextMilestone;
    if (next != null && widget.nextRemaining != null) {
      final remaining = widget.nextRemaining!;
      final unit = remaining == 1 ? next.category.unitSingular : next.unit;
      parts.add('Next: ${next.shortLabel} — $remaining $unit to go');
    }
    return Text(
      parts.join(' · '),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.dismissLabel),
        ),
        const SizedBox(width: AppConstants.spacingXs),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSupportTap?.call();
          },
          child: Text(
            widget.supportLabel,
            style: TextStyle(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}


