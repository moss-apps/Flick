import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/onboarding_provider.dart';
import 'package:flick/providers/tutorial_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 5;
  static const List<_StepData> _steps = [
    _StepData(
      icon: LucideIcons.zap,
      title: 'Welcome to\nFlick Player',
      description:
          'A beautiful, fast music player\nbuilt for your local library.\nNo ads. No tracking. Just music.',
    ),
    _StepData(
      icon: LucideIcons.folderOpen,
      title: 'Build Your\nLibrary',
      description:
          'Head to Settings and tap\nMusic Folders to scan your\ndevice. Supports MP3, FLAC,\nAAC, WAV, and more.',
    ),
    _StepData(
      icon: LucideIcons.layoutGrid,
      title: 'Browse\nYour Music',
      description:
          'Swipe between tabs to explore\nSongs, Artists, Albums, and\nPlaylists. Sort and search\nyour entire collection.',
    ),
    _StepData(
      icon: LucideIcons.music,
      title: 'Rich\nPlayback',
      description:
          'Tap any song for the full player\nwith waveform seek bar,\nequalizer, lyrics, and ambient\nalbum art visuals.',
    ),
    _StepData(
      icon: LucideIcons.headphones,
      title: "You're\nAll Set",
      description:
          'Start exploring your music.\nSit back, relax, and enjoy\nthe sound of Flick Player.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: AppConstants.animationNormal,
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _skip() {
    _complete();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: _OnboardingBackdrop(pageController: _pageController),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: _steps.map((step) {
                      return AnimatedSwitcher(
                        duration: AppConstants.animationNormal,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _StepContent(
                          key: ValueKey(step.title),
                          data: step,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_currentPage < _totalPages - 1)
            TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingXs,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: AppConstants.fontSizeMd,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isLastPage = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingXl,
        AppConstants.spacingMd,
        AppConstants.spacingXl,
        AppConstants.spacingXl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDots(),
          _buildActionButton(isLastPage: isLastPage),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: AppConstants.animationFast,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFFEDF6FF), Color(0xFF8AB7FF)],
                  )
                : null,
            color: isActive ? null : AppColors.inactiveState,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF8AB7FF).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildActionButton({required bool isLastPage}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F7FF), Color(0xFF9CC4FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8AB7FF).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _goToNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF0A111A),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg + 4,
            vertical: AppConstants.spacingSm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLastPage ? 'Get Started' : 'Next',
              style: const TextStyle(
                fontFamily: 'ProductSans',
                fontSize: AppConstants.fontSizeMd,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            if (!isLastPage) ...[
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronRight, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Animated Onboarding Backdrop ─────────────────────────────────────────────
// Each page has a unique arrangement of glowing orbs. As the user swipes,
// the orbs interpolate smoothly between configurations. A subtle breathing
// animation keeps the backdrop feeling alive even when idle.

class _OrbState {
  final double x; // fraction of screen width  (0 = left edge)
  final double y; // fraction of screen height (0 = top edge)
  final double size;
  final Color color;

  const _OrbState(this.x, this.y, this.size, this.color);

  _OrbState lerp(_OrbState other, double t) {
    return _OrbState(
      _lerpDouble(x, other.x, t),
      _lerpDouble(y, other.y, t),
      _lerpDouble(size, other.size, t),
      Color.lerp(color, other.color, t) ?? color,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Per-page configurations for 3 orbs.
const _orbConfigs = <List<_OrbState>>[
  // Page 0 – Welcome: cool blues, centered
  [
    _OrbState(-0.15, -0.10, 340, Color(0xFF1B3258)),
    _OrbState(0.70, 0.35, 300, Color(0xFF1A2D44)),
    _OrbState(0.05, 0.82, 240, Color(0xFF1A2D44)),
  ],
  // Page 1 – Library: warmer tones appear
  [
    _OrbState(0.55, -0.08, 320, Color(0xFF2A1D45)),
    _OrbState(-0.20, 0.45, 360, Color(0xFF4A2A1F)),
    _OrbState(0.40, 0.78, 260, Color(0xFF1B3258)),
  ],
  // Page 2 – Browse: spread out, purple accent
  [
    _OrbState(0.10, 0.05, 280, Color(0xFF3B1D5E)),
    _OrbState(0.75, 0.50, 320, Color(0xFF1B3258)),
    _OrbState(-0.10, 0.70, 300, Color(0xFF2A1D45)),
  ],
  // Page 3 – Playback: vibrant, tighter
  [
    _OrbState(0.60, -0.05, 360, Color(0xFF4A2A1F)),
    _OrbState(-0.15, 0.40, 280, Color(0xFF3B1D5E)),
    _OrbState(0.35, 0.85, 320, Color(0xFF1B3258)),
  ],
  // Page 4 – All Set: calm, centred glow
  [
    _OrbState(0.25, 0.05, 380, Color(0xFF1A2D44)),
    _OrbState(0.60, 0.45, 340, Color(0xFF1B3258)),
    _OrbState(0.10, 0.75, 280, Color(0xFF2A1D45)),
  ],
];

class _OnboardingBackdrop extends StatefulWidget {
  final PageController pageController;

  const _OnboardingBackdrop({required this.pageController});

  @override
  State<_OnboardingBackdrop> createState() => _OnboardingBackdropState();
}

class _OnboardingBackdropState extends State<_OnboardingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    widget.pageController.addListener(_onScroll);
  }

  void _onScroll() {
    final p = widget.pageController.page;
    if (p != null && mounted) setState(() => _page = p);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onScroll);
    _breathe.dispose();
    super.dispose();
  }

  List<_OrbState> _interpolatedOrbs() {
    final base = _page.floor().clamp(0, _orbConfigs.length - 1);
    final next = (base + 1).clamp(0, _orbConfigs.length - 1);
    final t = _page - _page.floor();
    return [
      for (int i = 0; i < 3; i++) _orbConfigs[base][i].lerp(_orbConfigs[next][i], t),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, _) {
          final orbs = _interpolatedOrbs();
          final breath = _breathe.value; // 0 → 1 → 0
          final w = MediaQuery.sizeOf(context).width;
          final h = MediaQuery.sizeOf(context).height;

          return Stack(
            children: [
              // Base gradient
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF040608), Color(0xFF0A0A0A)],
                    ),
                  ),
                ),
              ),
              // Animated orbs
              for (int i = 0; i < orbs.length; i++)
                _buildOrb(orbs[i], i, breath, w, h),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrb(_OrbState orb, int index, double breath, double w, double h) {
    // Each orb breathes with a slightly different phase offset
    final phase = math.sin((breath + index * 0.33) * math.pi);
    final sizeScale = 1.0 + phase * 0.08; // ±8% size pulse
    final offsetX = phase * 12.0 * (index.isEven ? 1 : -1); // subtle drift
    final offsetY = phase * 8.0 * (index.isOdd ? 1 : -1);
    final s = orb.size * sizeScale;

    return Positioned(
      left: orb.x * w + offsetX - s / 2,
      top: orb.y * h + offsetY - s / 2,
      child: _GlowOrb(
        size: s,
        color: orb.color,
        opacity: 0.85 + phase * 0.15,
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  final _StepData data;

  const _StepContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x26FFFFFF), Color(0x08FFFFFF)],
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              border: Border.all(
                color: const Color(0x33FFFFFF),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8AB7FF).withValues(alpha: 0.08),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(data.icon, size: 48, color: AppColors.accent),
          ),
          const Spacer(flex: 1),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 0.92,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ProductSans',
              fontSize: AppConstants.fontSizeMd,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _StepData {
  final IconData icon;
  final String title;
  final String description;

  const _StepData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

