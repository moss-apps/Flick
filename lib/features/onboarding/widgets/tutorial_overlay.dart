import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/tutorial_provider.dart';
import 'package:flick/providers/navigation_provider.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';
import 'package:flick/features/manual/screens/manual_screen.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Rect? _currentSpotlight;
  bool _measureAttempted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.animationNormal,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    ref.listenManual(
      tutorialProvider.select((s) => s.currentStep),
      (prev, next) => _onStepChanged(next),
    );
  }

  void _onStepChanged(int stepIndex) {
    final step = TutorialStep.values[
        stepIndex.clamp(0, TutorialStep.values.length - 1)];

    if (step.requiredTabIndex != null) {
      ref
          .read(navigationIndexProvider.notifier)
          .setIndex(step.requiredTabIndex!);
    }

    setState(() {
      _currentSpotlight = null;
      _measureAttempted = step.spotlightTarget == null;
    });

    if (step.spotlightTarget == null) return;

    final target = step.spotlightTarget!;
    final delay = step.requiredTabIndex != null
        ? AppConstants.animationNormal + const Duration(milliseconds: 50)
        : const Duration(milliseconds: 50);

    Future.delayed(delay, () {
      if (!mounted) return;
      if (ref.read(tutorialProvider).currentStep != stepIndex) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(tutorialProvider).currentStep != stepIndex) return;
        final rect = ref.read(tutorialTargetRegistryProvider).rectFor(target);
        setState(() {
          _currentSpotlight = rect;
          _measureAttempted = true;
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorialProvider);

    if (state.active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    return FadeTransition(
      opacity: _opacity,
      child:
          state.active ? _buildOverlay(context, state) : const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(BuildContext context, TutorialState state) {
    final screenSize = MediaQuery.of(context).size;
    final step = state.step;

    final hasSpotlight = step.spotlightTarget != null &&
        _currentSpotlight != null &&
        _measureAttempted;
    final centered = step.spotlightTarget == null || !hasSpotlight;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: RepaintBoundary(
            child: CustomPaint(
              size: screenSize,
              painter: _SpotlightPainter(
                spotlight: hasSpotlight ? _currentSpotlight : null,
                borderRadius: 16,
              ),
            ),
          ),
        ),
        if (centered)
          _buildCenterTooltip(context, state, step)
        else
          _buildAnchoredTooltip(context, state, step, _currentSpotlight!),
      ],
    );
  }

  Widget _buildCenterTooltip(
    BuildContext context,
    TutorialState state,
    TutorialStep step,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: _TooltipCard(
          step: step,
          currentStep: state.currentStep,
          totalSteps: state.totalSteps,
          isLastStep: state.isLastStep,
          onNext: () => ref.read(tutorialProvider.notifier).nextStep(),
          onBack: state.currentStep > 0
              ? () => ref.read(tutorialProvider.notifier).previousStep()
              : null,
          onSkip: () => ref.read(tutorialProvider.notifier).skip(),
          onOpenManual: () => _openManualAndComplete(context),
        ),
      ),
    );
  }

  Widget _buildAnchoredTooltip(
    BuildContext context,
    TutorialState state,
    TutorialStep step,
    Rect spotlight,
  ) {
    final screenH = MediaQuery.of(context).size.height;
    final above = spotlight.center.dy > screenH / 2;
    return Positioned(
      left: AppConstants.spacingMd,
      right: AppConstants.spacingMd,
      top: above ? null : spotlight.bottom + AppConstants.spacingMd,
      bottom: above
          ? screenH - spotlight.top + AppConstants.spacingMd
          : null,
      child: _TooltipCard(
        step: step,
        currentStep: state.currentStep,
        totalSteps: state.totalSteps,
        isLastStep: state.isLastStep,
        onNext: () => ref.read(tutorialProvider.notifier).nextStep(),
        onBack: state.currentStep > 0
            ? () => ref.read(tutorialProvider.notifier).previousStep()
            : null,
        onSkip: () => ref.read(tutorialProvider.notifier).skip(),
        onOpenManual: () => _openManualAndComplete(context),
      ),
    );
  }

  void _openManualAndComplete(BuildContext context) {
    ref.read(tutorialProvider.notifier).complete();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ManualScreen()),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? spotlight;
  final double borderRadius;

  const _SpotlightPainter({this.spotlight, this.borderRadius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.78);

    if (spotlight == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(spotlight!, Radius.circular(borderRadius)));

    final result = Path.combine(PathOperation.difference, fullPath, cutout);
    canvas.drawPath(result, paint);

    final borderPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight!, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      spotlight != old.spotlight || borderRadius != old.borderRadius;
}

class _TooltipCard extends StatelessWidget {
  final TutorialStep step;
  final int currentStep;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final VoidCallback onOpenManual;

  const _TooltipCard({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.isLastStep,
    required this.onNext,
    this.onBack,
    required this.onSkip,
    required this.onOpenManual,
  });

  @override
  Widget build(BuildContext context) {
    final showManualButton = step.isManualPointer && isLastStep;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.glassBorderStrong),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.glassBackgroundStrong,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${currentStep + 1}/$totalSteps',
                  style: const TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontFamily: 'ProductSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            step.title,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.description,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onBack != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppConstants.spacingSm),
                  child: _SecondaryButton(
                    label: 'Back',
                    icon: LucideIcons.chevronLeft,
                    onTap: onBack!,
                  ),
                ),
              if (showManualButton)
                _PrimaryButton(
                  label: 'Open Manual',
                  icon: LucideIcons.bookOpen,
                  onTap: onOpenManual,
                )
              else
                _PrimaryButton(
                  label: isLastStep ? 'Get Started' : 'Next',
                  icon: isLastStep ? null : LucideIcons.chevronRight,
                  onTap: onNext,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd + 4,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF5F7FF), Color(0xFF9CC4FF)],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF0A111A)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A111A),
              ),
            ),
            if (icon == LucideIcons.chevronRight) ...[
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Color(0xFF0A111A),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.glassBackgroundStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
