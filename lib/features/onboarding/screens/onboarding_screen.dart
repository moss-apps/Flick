import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_system_ui.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/onboarding/widgets/onboarding_poster.dart';
import 'package:flick/features/recap/widgets/replay_style.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/onboarding_provider.dart';
import 'package:flick/providers/tutorial_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNext() {
    if (_currentPage == _totalPages - 1) {
      _complete();
      return;
    }
    final duration = ReplayStyle.duration(context);
    if (duration == Duration.zero) {
      _pageController.jumpToPage(_currentPage + 1);
    } else {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _complete() {
    ref.read(tutorialProvider.notifier).flagAutoStart();
    ref.read(onboardingCompletedProvider.notifier).complete();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.englishForFilipino;
    // Taglish deliberately keeps its supplied welcome and English guidance.
    final titles = [
      context.l10n.onboardingWelcomeTitle,
      l10n.onboardingLibraryTitle,
      l10n.onboardingBrowseTitle,
      l10n.onboardingPlaybackTitle,
      l10n.onboardingReadyTitle,
    ];
    final descriptions = [
      l10n.onboardingWelcomeBody,
      l10n.onboardingLibraryBody,
      l10n.onboardingBrowseBody,
      l10n.onboardingPlaybackBody,
      l10n.onboardingReadyBody,
    ];
    final colors = OnboardingPosterColors.forPage(_currentPage);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.forBackground(colors.background),
      child: Scaffold(
        backgroundColor: colors.background,
        body: AnimatedContainer(
          duration: ReplayStyle.duration(context),
          curve: Curves.easeOutCubic,
          color: colors.background,
          child: SafeArea(
            child: Column(
              children: [
                _frame(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'Flick',
                              // Fixed-size logotype, not guidance copy.
                              textScaler: TextScaler.noScaling,
                              style: _type(24, colors.foreground).copyWith(
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.7,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Divider(
                            color: colors.foreground.withValues(alpha: 0.3),
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_currentPage < _totalPages - 1)
                          TextButton(
                            onPressed: _complete,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.foreground,
                              minimumSize: const Size(48, 48),
                              textStyle: _type(15, colors.foreground),
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(l10n.skip),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _totalPages,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) => OnboardingPoster(
                      index: index,
                      title: titles[index],
                      description: descriptions[index],
                      active: index == _currentPage,
                    ),
                  ),
                ),
                _frame(child: _buildFooter(colors, l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _frame({required Widget child}) => Align(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      ),
    ),
  );

  Widget _buildFooter(OnboardingPosterColors colors, AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.foreground.withValues(alpha: 0.3)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final progress = _buildProgress(colors);
            final action = FilledButton(
              onPressed: _goToNext,
              style: FilledButton.styleFrom(
                backgroundColor: colors.button,
                foregroundColor: colors.onButton,
                minimumSize: const Size(144, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                textStyle: _type(
                  16,
                  colors.onButton,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _currentPage == _totalPages - 1
                          ? l10n.getStarted
                          : l10n.next,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(LucideIcons.arrowRight, size: 20),
                ],
              ),
            );
            // Give translated/scaled labels the whole row before shrinking art.
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(16) > 21) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [progress, const SizedBox(height: 12), action],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [progress, const SizedBox(width: 16), action],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgress(OnboardingPosterColors colors) => Semantics(
    value: '${_currentPage + 1} / $_totalPages',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(_currentPage + 1).toString().padLeft(2, '0')} / 05',
            style: _type(
              13,
              colors.foreground,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_totalPages, (index) {
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.foreground.withValues(
                    alpha: index == _currentPage ? 1 : 0.25,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );

  TextStyle _type(double size, Color color) => TextStyle(
    fontFamily: 'GoogleSansFlex',
    fontFamilyFallback: AppTheme.fontFamilyFallback,
    fontSize: size,
    color: color,
  );
}
