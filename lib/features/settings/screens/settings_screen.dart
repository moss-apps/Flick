import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/settings/screens/app_info_settings_screen.dart';
import 'package:flick/features/settings/screens/audio_settings_screen.dart';
import 'package:flick/features/settings/screens/interface_settings_screen.dart';
import 'package:flick/features/settings/screens/library_settings_screen.dart';
import 'package:flick/features/settings/screens/playback_display_settings_screen.dart';
import 'package:flick/features/settings/screens/ui_customization_settings_screen.dart';
import 'package:flick/features/settings/screens/integrations_settings_screen.dart';
import 'package:flick/features/settings/screens/lyrics_settings_screen.dart';
import 'package:flick/features/settings/screens/player_layout_settings_screen.dart';
import 'package:flick/features/settings/screens/widget_settings_screen.dart';
import 'package:flick/features/settings/screens/support_flick_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/features/milestone/screens/milestones_screen.dart';
import 'package:flick/services/milestone_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _milestonesUnlocked = 0;

  @override
  void initState() {
    super.initState();
    _refreshMilestoneCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshMilestoneCount();
  }

  Future<void> _refreshMilestoneCount() async {
    final shown = await MilestoneService().getShownMilestones();
    if (!mounted) return;
    if (shown.length != _milestonesUnlocked) {
      setState(() => _milestonesUnlocked = shown.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background is handled by _PersistentBackground in MaterialApp.builder.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: AppConstants.spacingMd),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context, 'Media'),
                    SettingsCard(
                      children: [
                        _CategoryTile(
                          icon: LucideIcons.library,
                          iconBg: const Color(0xFF2D4A6F),
                          iconFg: const Color(0xFF8BB8FF),
                          title: 'Library',
                          subtitle: 'Folders, scanning, and duplicates',
                          onTap: () =>
                              _navigate(context, const LibrarySettingsScreen()),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.play,
                          iconBg: const Color(0xFF4A2D6F),
                          iconFg: const Color(0xFFD19FFF),
                          title: 'Playback & Display',
                          subtitle: 'Gapless, view mode, and appearance',
                          onTap: () => _navigate(
                            context,
                            const PlaybackDisplaySettingsScreen(),
                          ),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.layoutPanelTop,
                          iconBg: const Color(0xFF4A2D6F),
                          iconFg: const Color(0xFFC4A3FF),
                          title: 'Player Layout',
                          subtitle: 'Layout mode, sizing, and quick actions',
                          onTap: () => _navigate(
                            context,
                            const PlayerLayoutSettingsScreen(),
                          ),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.headphones,
                          iconBg: const Color(0xFF6F4A2D),
                          iconFg: const Color(0xFFFFC48B),
                          title: 'Audio',
                          subtitle: 'UAC2 and equalizer',
                          onTap: () =>
                              _navigate(context, const AudioSettingsScreen()),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.fileText,
                          iconBg: const Color(0xFF4A6F2D),
                          iconFg: const Color(0xFFC4FF8B),
                          title: 'Lyrics',
                          subtitle: 'Lyrics saving behavior',
                          onTap: () =>
                              _navigate(context, const LyricsSettingsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                    _buildSectionHeader(context, 'System'),
                    SettingsCard(
                      children: [
                        _CategoryTile(
                          icon: LucideIcons.layoutDashboard,
                          iconBg: const Color(0xFF2D6F4A),
                          iconFg: const Color(0xFF8BFFC4),
                          title: 'Interface',
                          subtitle: 'Animations and haptic feedback',
                          onTap: () => _navigate(
                            context,
                            const InterfaceSettingsScreen(),
                          ),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.palette,
                          iconBg: const Color(0xFF2D4A6F),
                          iconFg: const Color(0xFF8BB8FF),
                          title: 'UI Customization',
                          subtitle: 'Show or hide home screen sections',
                          onTap: () => _navigate(
                            context,
                            const UiCustomizationSettingsScreen(),
                          ),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.plug,
                          iconBg: const Color(0xFF6F2D4A),
                          iconFg: const Color(0xFFFF8BB8),
                          title: 'Integrations',
                          subtitle: 'Last.fm scrobbling',
                          onTap: () => _navigate(
                            context,
                            const IntegrationsSettingsScreen(),
                          ),
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.layoutGrid,
                          iconBg: const Color(0xFF2D4A6F),
                          iconFg: const Color(0xFF8BB8FF),
                          title: 'Widgets',
                          subtitle: 'Customize home screen widgets',
                          onTap: () =>
                              _navigate(context, const WidgetSettingsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                    _buildSectionHeader(context, 'About'),
                    SettingsCard(
                      children: [
                        _CategoryTile(
                          icon: LucideIcons.trophy,
                          iconBg: const Color(0xFF3A3320),
                          iconFg: const Color(0xFFD4B265),
                          title: 'Milestones',
                          subtitle: _milestonesUnlocked == 0
                              ? 'No achievements yet — keep listening'
                              : '$_milestonesUnlocked / ${MilestoneType.values.length} unlocked',
                          onTap: () async {
                            _navigate(context, const MilestonesScreen());
                            await _refreshMilestoneCount();
                          },
                        ),
                        const SettingsDivider(),
                        _CategoryTile(
                          icon: LucideIcons.info,
                          iconBg: const Color(0xFF3A3A3A),
                          iconFg: const Color(0xFFB0B0B0),
                          title: 'App Info',
                          subtitle: 'Updates, about, and support',
                          onTap: () =>
                              _navigate(context, const AppInfoSettingsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                    SizedBox(
                      height:
                          AppConstants.navBarHeight +
                          MediaQuery.of(context).padding.bottom +
                          AppConstants.spacingLg * 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your music experience',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SupportFlickScreen(),
                ),
              );
            },
            icon: _PulsingHeartIcon(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.spacingXs,
        bottom: AppConstants.spacingSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

/// A single category row in the main settings menu with a colored icon.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            children: [
              ColoredSettingsIcon(
                icon: icon,
                backgroundColor: iconBg,
                iconColor: iconFg,
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
              Icon(
                LucideIcons.chevronRight,
                color: context.adaptiveTextTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingHeartIcon extends StatefulWidget {
  const _PulsingHeartIcon();

  @override
  State<_PulsingHeartIcon> createState() => _PulsingHeartIconState();
}

class _PulsingHeartIconState extends State<_PulsingHeartIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        LucideIcons.heart,
        color: context.adaptiveTextTertiary,
        size: 22,
      ),
    );
  }
}
