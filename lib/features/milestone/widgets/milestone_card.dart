import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/milestone_service.dart';

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
    this.nextLabel,
    this.nextRemaining,
    this.supportLabel = 'Support Flick',
    this.dismissLabel = 'Dismiss',
    this.onSupportTap,
  });

  final MilestoneType milestone;
  final DateTime? achievedAt;
  final String? nextLabel;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppConstants.glassBlurSigma,
            sigmaY: AppConstants.glassBlurSigma,
          ),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingXl,
              AppConstants.spacingLg,
              AppConstants.spacingLg,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
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
        ),
      ),
    );
  }

  Widget _buildDisc(Color tierColor) {
    return AnimatedBuilder(
      animation: _discController,
      builder: (context, _) {
        final scale = _discScale.value;
        final rotation = (_discRotation.value - 1.0) * (math.pi / 6);
        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 104,
              height: 104,
              child: _VinylRecord(labelColor: tierColor),
            ),
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
            (widget.nextLabel != null && widget.nextRemaining != null)) ...[
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
    if (widget.nextLabel != null && widget.nextRemaining != null) {
      final unit = _unitFor(widget.nextLabel!, widget.nextRemaining!);
      parts.add(
        'Next: ${widget.nextLabel} — ${widget.nextRemaining} $unit to go',
      );
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

  static String _unitFor(String label, int remaining) {
    if (remaining == 1) {
      return label.contains('song') ? 'song' : 'hour';
    }
    return label.contains('song') ? 'songs' : 'hours';
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

/// A hand-painted vinyl record — concentric grooves, a tinted center label
/// with the Flick logo, and a center hole. Sized at 104×104 by the parent.
class _VinylRecord extends StatelessWidget {
  const _VinylRecord({required this.labelColor});

  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VinylPainter(
        labelColor: labelColor,
        grooveColor: labelColor.withValues(alpha: 0.18),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/flicklogo_svg.svg',
          width: 20,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  _VinylPainter({required this.labelColor, required this.grooveColor});

  final Color labelColor;
  final Color grooveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;

    // Outer disc body — use a dark gradient to suggest a glossy record.
    final discPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.95,
        colors: [const Color(0xFF2A2A2A), const Color(0xFF0A0A0A)],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));
    canvas.drawCircle(center, outerRadius, discPaint);

    // Concentric grooves — drawn as thin tinted rings, skipping the label area.
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = grooveColor;
    const labelRatio = 0.44;
    final labelRadius = outerRadius * labelRatio;
    final grooves = 9;
    for (var i = 0; i < grooves; i++) {
      final t = (i + 1) / (grooves + 1);
      final r = labelRadius + (outerRadius - labelRadius) * t;
      canvas.drawCircle(center, r, groovePaint);
    }

    // Subtle highlight on top-left to suggest light catching the disc.
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

    // Center label — the tier color.
    final labelPaint = Paint()..color = labelColor;
    canvas.drawCircle(center, labelRadius, labelPaint);

    // Subtle inner shadow on the label edge so the disc has depth.
    final labelEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawCircle(center, labelRadius, labelEdgePaint);

    // Center spindle hole — the Flick logo (rendered as a child widget) sits
    // on top of the label, and the hole gives the disc a real record feel.
    final holePaint = Paint()..color = const Color(0xFF0A0A0A);
    canvas.drawCircle(center, outerRadius * 0.05, holePaint);
  }

  @override
  bool shouldRepaint(covariant _VinylPainter oldDelegate) {
    return oldDelegate.labelColor != labelColor ||
        oldDelegate.grooveColor != grooveColor;
  }
}
