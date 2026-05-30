import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/tutorial_provider.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
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
      child: state.active ? _buildOverlay(context, state) : const SizedBox.shrink(),
    );
  }

  Widget _buildOverlay(BuildContext context, TutorialState state) {
    final screenSize = MediaQuery.of(context).size;
    final config = _stepConfig(state.step, screenSize);

    return Stack(
      key: ValueKey(state.currentStep),
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: CustomPaint(
            size: screenSize,
            painter: _SpotlightPainter(
              spotlight: config.spotlight,
              borderRadius: config.borderRadius,
            ),
          ),
        ),
        if (config.spotlight != null)
          _buildAboveTooltip(context, state, config)
        else
          _buildCenterTooltip(context, state, config),
      ],
    );
  }

  Widget _buildCenterTooltip(
    BuildContext context,
    TutorialState state,
    _StepConfig config,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: _TooltipCard(
          title: config.title,
          description: config.description,
          currentStep: state.currentStep,
          totalSteps: state.totalSteps,
          isLastStep: state.isLastStep,
          onNext: () => ref.read(tutorialProvider.notifier).nextStep(),
          onBack: state.currentStep > 0
              ? () => ref.read(tutorialProvider.notifier).previousStep()
              : null,
          onSkip: () => ref.read(tutorialProvider.notifier).skip(),
        ),
      ),
    );
  }

  Widget _buildAboveTooltip(
    BuildContext context,
    TutorialState state,
    _StepConfig config,
  ) {
    final spotlight = config.spotlight!;
    return Positioned(
      left: AppConstants.spacingMd,
      right: AppConstants.spacingMd,
      bottom: screenSize(context).height - spotlight.top + AppConstants.spacingMd,
      child: _TooltipCard(
        title: config.title,
        description: config.description,
        currentStep: state.currentStep,
        totalSteps: state.totalSteps,
        isLastStep: state.isLastStep,
        onNext: () => ref.read(tutorialProvider.notifier).nextStep(),
        onBack: state.currentStep > 0
            ? () => ref.read(tutorialProvider.notifier).previousStep()
            : null,
        onSkip: () => ref.read(tutorialProvider.notifier).skip(),
      ),
    );
  }

  Size screenSize(BuildContext context) => MediaQuery.of(context).size;

  _StepConfig _stepConfig(TutorialStep step, Size size) {
    const bottomBarHeight = 170.0;
    const miniPlayerHeight = 68.0;

    switch (step) {
      case TutorialStep.welcome:
        return _StepConfig(
          title: 'Welcome to Flick!',
          description: "Let's take a quick tour of your new music player.",
        );
      case TutorialStep.navBar:
        return _StepConfig(
          title: 'Navigation Bar',
          description:
              'Tap icons to switch between tabs. Swipe between pages to browse.',
          spotlight: Rect.fromLTWH(
            0,
            size.height - bottomBarHeight,
            size.width,
            bottomBarHeight,
          ),
          borderRadius: 20,
        );
      case TutorialStep.miniPlayer:
        return _StepConfig(
          title: 'Mini Player',
          description: "Shows what's playing. Tap it to open the full player.",
          spotlight: Rect.fromLTWH(
            28,
            size.height - bottomBarHeight + 4,
            size.width - 56,
            miniPlayerHeight,
          ),
          borderRadius: 16,
        );
      case TutorialStep.browseMusic:
        return _StepConfig(
          title: 'Browse Your Music',
          description:
              'Songs, Albums, Artists, Playlists, Folders, and more — all accessible from the navigation bar.',
        );
      case TutorialStep.settingsTab:
        return _StepConfig(
          title: 'Settings',
          description:
              'Customize audio, display, navigation, integrations, and more from the Settings tab.',
          spotlight: Rect.fromLTWH(
            0,
            size.height - bottomBarHeight,
            size.width,
            bottomBarHeight,
          ),
          borderRadius: 20,
        );
      case TutorialStep.fullPlayer:
        return _StepConfig(
          title: 'Full Player',
          description:
              'Tap the mini player to access the full player with waveform seekbar, equalizer, lyrics, and visualizer.',
          spotlight: Rect.fromLTWH(
            28,
            size.height - bottomBarHeight + 4,
            size.width - 56,
            miniPlayerHeight,
          ),
          borderRadius: 16,
        );
    }
  }
}

class _StepConfig {
  final String title;
  final String description;
  final Rect? spotlight;
  final double borderRadius;

  const _StepConfig({
    required this.title,
    required this.description,
    this.spotlight,
    this.borderRadius = 16,
  });
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

    final fullPath =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(
        spotlight!,
        Radius.circular(borderRadius),
      ));

    final result =
        Path.combine(PathOperation.difference, fullPath, cutout);
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
  final String title;
  final String description;
  final int currentStep;
  final int totalSteps;
  final bool isLastStep;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.title,
    required this.description,
    required this.currentStep,
    required this.totalSteps,
    required this.isLastStep,
    required this.onNext,
    this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
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
            title,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
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
                  child: GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingMd,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackgroundStrong,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.chevronLeft,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: 'ProductSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onNext,
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
                      Text(
                        isLastStep ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontFamily: 'ProductSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A111A),
                        ),
                      ),
                      if (!isLastStep) ...[
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
