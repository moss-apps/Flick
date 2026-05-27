import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class SupportFlickScreen extends ConsumerStatefulWidget {
  const SupportFlickScreen({super.key});

  @override
  ConsumerState<SupportFlickScreen> createState() =>
      _SupportFlickScreenState();
}

class _SupportFlickScreenState extends ConsumerState<SupportFlickScreen>
    with SingleTickerProviderStateMixin {
  static const _kofiUrl = 'https://ko-fi.com/ultraelectronica';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _revealController;
  late final Animation<double> _fade1;
  late final Animation<double> _fade2;
  late final Animation<double> _fade3;
  late final Animation<Offset> _slide1;
  late final Animation<Offset> _slide2;
  late final Animation<Offset> _slide3;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    final Curve easeOut = Curves.easeOutCubic;
    _fade1 = CurvedAnimation(
      parent: _revealController,
      curve: Interval(0.0, 0.5, curve: easeOut),
    );
    _fade2 = CurvedAnimation(
      parent: _revealController,
      curve: Interval(0.2, 0.7, curve: easeOut),
    );
    _fade3 = CurvedAnimation(
      parent: _revealController,
      curve: Interval(0.4, 0.9, curve: easeOut),
    );
    _slide1 = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: Interval(0.0, 0.5, curve: easeOut),
      ),
    );
    _slide2 = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: Interval(0.2, 0.7, curve: easeOut),
      ),
    );
    _slide3 = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: Interval(0.4, 0.9, curve: easeOut),
      ),
    );
    _revealController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _launchKoFi() async {
    final uri = Uri.parse(_kofiUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Support Flick',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: _fade1,
            child: SlideTransition(
              position: _slide1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionHeader('Why Donate'),
                  SettingsCard(
                    children: [
                      _InfoTile(
                        icon: LucideIcons.user,
                        title: 'Solo Developer',
                        subtitle:
                            'Flick is built and maintained by one person with zero budget. No team, no funding, no ads.',
                      ),
                      const SettingsDivider(),
                      _InfoTile(
                        icon: LucideIcons.code,
                        title: 'Free & Open Source',
                        subtitle:
                            'Flick will always be free. Donations keep the project alive without paywalls or subscriptions.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          FadeTransition(
            opacity: _fade2,
            child: SlideTransition(
              position: _slide2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionHeader('Where Your Money Goes'),
                  SettingsCard(
                    children: [
                      _InfoTile(
                        icon: LucideIcons.smartphone,
                        title: 'Google Play Developer Fees',
                        subtitle:
                            'Keeping Flick on the Play Store costs \$25/year in developer registration fees.',
                      ),
                      const SettingsDivider(),
                      _InfoTile(
                        icon: LucideIcons.headphones,
                        title: 'Audio Testing Equipment',
                        subtitle:
                            'USB DACs, headphones, and reference gear to test and improve playback quality.',
                      ),
                      const SettingsDivider(),
                      _InfoTile(
                        icon: LucideIcons.music,
                        title: 'DSD / DSF Playback',
                        subtitle:
                            'Funding native DSD/DSF playback development — a highly requested feature for audiophiles.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          FadeTransition(
            opacity: _fade3,
            child: SlideTransition(
              position: _slide3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionHeader('Donate'),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return SettingsCard(
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(
                            alpha: 0.25 + _pulseAnimation.value * 0.55,
                          ),
                          width: 1.0 + _pulseAnimation.value * 1.2,
                        ),
                        children: [
                          NavigationSetting(
                            icon: LucideIcons.heart,
                            title: 'Buy me a coffee',
                            subtitle: 'Support development on Ko-fi',
                            onTap: _launchKoFi,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.scaleSize(AppConstants.containerSizeMd),
            height: context.scaleSize(AppConstants.containerSizeMd),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              icon,
              color: context.adaptiveTextSecondary,
              size: context.responsiveIcon(AppConstants.iconSizeLg),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
