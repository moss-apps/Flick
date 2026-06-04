import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/features/onboarding/screens/onboarding_screen.dart';
import 'package:flick/features/settings/screens/privacy_policy_screen.dart';
import 'package:flick/features/settings/screens/support_flick_screen.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

class AppInfoSettingsScreen extends ConsumerStatefulWidget {
  const AppInfoSettingsScreen({super.key});

  @override
  ConsumerState<AppInfoSettingsScreen> createState() =>
      _AppInfoSettingsScreenState();
}

class _AppInfoSettingsScreenState extends ConsumerState<AppInfoSettingsScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _releaseNotesApiUri = Uri.parse(
    'https://api.github.com/repos/ultraelectronica/flick_player/releases/latest',
  );
  static const String _releaseNotesUrl =
      'https://github.com/ultraelectronica/flick_player/releases/latest';

  late final AnimationController _donationPulseController;
  late final Animation<double> _donationPulseAnimation;

  @override
  void initState() {
    super.initState();
    _donationPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _donationPulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _donationPulseController,
        curve: Curves.easeInOut,
      ),
    );
    _donationPulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _donationPulseController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _checkForUpdatesManually() async {
    await ref.read(updateCheckProvider.notifier).refreshIfOnline(force: true);

    if (!mounted) {
      return;
    }

    final updateState = ref.read(updateCheckProvider);
    if (!updateState.isOnline) {
      _showToast('Connect to the internet to check for updates.');
      return;
    }
    if (updateState.updateAvailable) {
      if (updateState.isPlayStoreBuild) {
        _showToast('Update available on the Play Store.');
      } else {
        _showToast('Update available — download from flick-player.site');
      }
      return;
    }
    if (updateState.errorMessage != null) {
      _showToast(updateState.errorMessage!);
      return;
    }
    _showToast('No new update found.');
  }

  Future<void> _openPlayStoreListing() async {
    final marketUri = Uri.parse(UpdateCheckNotifier.flickPlayStoreMarketUrl);
    final webUri = Uri.parse(UpdateCheckNotifier.flickPlayStoreUrl);

    try {
      var launched = await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      }
      if (!launched) {
        launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        _showToast('Could not open the Play Store');
      }
    } catch (error) {
      if (mounted) {
        _showToast('Could not open the Play Store: $error');
      }
    }
  }

  ({IconData icon, String title, String subtitle}) _getUpdateStatusDetails(
    UpdateCheckState updateState,
  ) {
    final isPlay = updateState.isPlayStoreBuild;
    if (updateState.isChecking) {
      return (
        icon: LucideIcons.refreshCw,
        title: 'Checking for Updates',
        subtitle: isPlay
            ? 'Looking for the latest Play Store update right now'
            : 'Looking for the latest Flick release right now',
      );
    }
    if (updateState.updateAvailable) {
      return (
        icon: LucideIcons.badgeAlert,
        title: 'Update Available',
        subtitle: isPlay
            ? 'Open the Play Store to install the latest Flick build'
            : 'Download the latest APK from flick-player.site',
      );
    }
    if (updateState.errorMessage != null) {
      return (
        icon: LucideIcons.info,
        title: 'Could Not Check for Updates',
        subtitle: updateState.errorMessage!,
      );
    }
    if (!updateState.isOnline) {
      return (
        icon: LucideIcons.wifiOff,
        title: 'Offline',
        subtitle: 'Reconnect to Wi-Fi or mobile data so Flick can scan again',
      );
    }
    if (updateState.hasChecked) {
      return (
        icon: LucideIcons.badgeCheck,
        title: 'No Update Available',
        subtitle: isPlay
            ? 'You already have the latest Play Store release'
            : 'You already have the latest Flick release',
      );
    }
    return (
      icon: LucideIcons.info,
      title: 'Automatic Update Checks',
      subtitle: isPlay
          ? 'Flick scans for Play Store updates whenever you are online'
          : 'Flick checks flick-player.site for updates whenever you are online',
    );
  }

  Widget _buildUpdateStatusTile(UpdateCheckState updateState) {
    final details = _getUpdateStatusDetails(updateState);
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            width: context.scaleSize(AppConstants.containerSizeSm),
            height: context.scaleSize(AppConstants.containerSizeSm),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              details.icon,
              color: context.adaptiveTextSecondary,
              size: context.responsiveIcon(AppConstants.iconSizeMd),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details.subtitle,
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

  Future<_PatchNotes> _fetchPatchNotes() async {
    final response = await http.get(
      _releaseNotesApiUri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'FlickPlayer',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final title = (data['name'] as String?)?.trim();
    final tag = (data['tag_name'] as String?)?.trim();
    final body = (data['body'] as String?)?.trim();
    final htmlUrl = (data['html_url'] as String?)?.trim();

    return _PatchNotes(
      title: title?.isNotEmpty == true
          ? title!
          : tag?.isNotEmpty == true
          ? tag!
          : 'Latest Update',
      body: body?.isNotEmpty == true ? body! : 'No patch notes available yet.',
      url: htmlUrl?.isNotEmpty == true ? htmlUrl! : _releaseNotesUrl,
    );
  }

  void _showPatchNotesBottomSheet() {
    GlassBottomSheet.show(
      context: context,
      title: 'Patch Notes',
      maxHeightRatio: 0.7,
      content: FutureBuilder<_PatchNotes>(
        future: _fetchPatchNotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppConstants.spacingMd),
                  const CircularProgressIndicator(color: AppColors.textPrimary),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'Loading patch notes...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppConstants.spacingMd),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    'Unable to load patch notes right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _launchUrl(_releaseNotesUrl),
                    icon: const Icon(LucideIcons.externalLink),
                    label: const Text('Open Release Notes'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
              ],
            );
          }

          final notes = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppConstants.spacingMd),
                Text(
                  notes.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: SelectableText(
                    notes.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _launchUrl(notes.url),
                    icon: const Icon(LucideIcons.externalLink),
                    label: const Text('Open Full Notes'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAboutBottomSheet() {
    GlassBottomSheet.show(
      context: context,
      title: 'About Flick Player',
      maxHeightRatio: 0.5,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppConstants.spacingMd),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: SvgPicture.asset(
              'assets/icons/flicklogo_svg.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const Text(
            'Flick Player',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Version 0.18.0-beta.1',
            style: TextStyle(
              fontFamily: 'ProductSans',
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Text(
              'A premium music player with custom UAC 2.0 powered by Rust for the best audio experience.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ProductSans',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _launchUrl(
                  'https://github.com/ultraelectronica/flick_player',
                ),
                icon: const Icon(LucideIcons.squareCode, size: 18),
                label: const Text(
                  'GitHub',
                  style: TextStyle(fontFamily: 'ProductSans'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
        ],
      ),
    );
  }

  void _showLicensesBottomSheet() {
    const licenseContent = '''
MIT License

Copyright (c) 2026 Flick Player Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

    GlassBottomSheet.show(
      context: context,
      title: 'Licenses',
      maxHeightRatio: 0.7,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppConstants.spacingMd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Text(
                licenseContent,
                style: TextStyle(
                  fontFamily: 'ProductSans',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        _showToast('Could not open the link');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Could not open the link: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateCheckProvider);

    return SettingsScaffold(
      title: 'App Info',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Updates'),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.refreshCw,
                title: updateState.isChecking
                    ? 'Checking for Updates...'
                    : 'Check Again',
                subtitle: updateState.isOnline
                    ? updateState.isPlayStoreBuild
                          ? 'Run another Play Store update scan right now'
                          : 'Run another update scan right now'
                    : 'Reconnect to the internet to scan for updates',
                onTap: updateState.isChecking ? null : _checkForUpdatesManually,
              ),
              const SettingsDivider(),
              _buildUpdateStatusTile(updateState),
              if (updateState.updateAvailable) ...[
                const SettingsDivider(),
                NavigationSetting(
                  icon: LucideIcons.fileText,
                  title: 'Patch Notes',
                  subtitle: 'See what is new in this update',
                  onTap: _showPatchNotesBottomSheet,
                ),
                const SettingsDivider(),
                if (updateState.isPlayStoreBuild)
                  ActionButton(
                    icon: LucideIcons.externalLink,
                    title: 'Open in Play Store',
                    subtitle: 'Jump to the Flick listing and update from there',
                    onTap: _openPlayStoreListing,
                  )
                else
                  ActionButton(
                    icon: LucideIcons.download,
                    title: 'Download Update',
                    subtitle: 'Get the latest APK from flick-player.site',
                    onTap: () =>
                        _launchUrl(UpdateCheckNotifier.flickWebsiteDownloadUrl),
                  ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('About'),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.info,
                title: 'About Flick Player',
                subtitle: 'Version 0.18.0-beta.1',
                onTap: _showAboutBottomSheet,
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.fileText,
                title: 'Licenses',
                subtitle: 'Open source licenses',
                onTap: _showLicensesBottomSheet,
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.shieldCheck,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.sparkles,
                title: 'View Onboarding',
                subtitle: 'Replay the tutorial and feature guide',
                onTap: () {
                  ref.read(onboardingCompletedProvider.notifier).reset();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.graduationCap,
                title: 'Interactive Tutorial',
                subtitle: 'Step-by-step walkthrough of the app',
                onTap: () {
                  ref.read(tutorialProvider.notifier).start();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Support'),
          AnimatedBuilder(
            animation: _donationPulseAnimation,
            builder: (context, child) {
              return SettingsCard(
                border: Border.all(
                  color: AppColors.textPrimary.withValues(
                    alpha: 0.25 + _donationPulseAnimation.value * 0.55,
                  ),
                  width: 1.0 + _donationPulseAnimation.value * 1.2,
                ),
                children: [
                  NavigationSetting(
                    icon: LucideIcons.heart,
                    title: 'Support Flick',
                    subtitle: 'Donate, fund features, and keep the app alive',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SupportFlickScreen(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _PatchNotes {
  const _PatchNotes({
    required this.title,
    required this.body,
    required this.url,
  });

  final String title;
  final String body;
  final String url;
}
