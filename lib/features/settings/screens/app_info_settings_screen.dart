import 'dart:convert';
import 'package:flick/widgets/common/flick_snackbar.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
import 'package:flick/services/build_info_service.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flick/l10n/settings_l10n.dart';

class AppInfoSettingsScreen extends ConsumerStatefulWidget {
  const AppInfoSettingsScreen({super.key});

  @override
  ConsumerState<AppInfoSettingsScreen> createState() =>
      _AppInfoSettingsScreenState();
}

class _AppInfoSettingsScreenState extends ConsumerState<AppInfoSettingsScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _releaseNotesApiUri = Uri.parse(
    'https://api.github.com/repos/moss-apps/Flick/releases/tags/0.18.0-beta.1',
  );
  static const String _releaseNotesUrl =
      'https://github.com/moss-apps/Flick/releases/tag/0.18.0-beta.1';

  late final AnimationController _donationPulseController;
  late final Animation<double> _donationPulseAnimation;

  String? _buildFlavor;

  @override
  void initState() {
    super.initState();
    _loadBuildFlavor();
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
    messenger.showFlickSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadBuildFlavor() async {
    final flavor = await BuildInfoService().getBuildFlavor();
    if (!mounted || flavor == null) return;
    setState(() => _buildFlavor = flavor);
  }

  String _buildFlavorSubtitle(String flavor) => switch (flavor) {
        'full' => l10n.buildFlavorFull,
        'play' => l10n.buildFlavorPlay,
        _ => flavor,
      };

  Future<void> _checkForUpdatesManually() async {
    await ref.read(updateCheckProvider.notifier).refreshIfOnline(force: true);

    if (!mounted) {
      return;
    }

    final updateState = ref.read(updateCheckProvider);
    if (!updateState.isOnline) {
      _showToast(l10n.connectToTheInternetToCheck);
      return;
    }
    if (updateState.updateAvailable) {
      if (updateState.isPlayStoreBuild) {
        _showToast(l10n.updateAvailableOnThePlayStore);
      } else {
        _showToast(l10n.updateAvailableDownloadFromFlickPlayer);
      }
      return;
    }
    if (updateState.errorMessage != null) {
      _showToast(updateState.errorMessage!);
      return;
    }
    _showToast(l10n.noNewUpdateFound);
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
        _showToast(l10n.couldNotOpenThePlayStore3);
      }
    } catch (error) {
      if (mounted) {
        _showToast(l10n.couldNotOpenThePlayStore2(error));
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
        title: l10n.englishForFilipino.checkingForUpdates,
        subtitle: isPlay
            ? l10n.lookingForTheLatestPlayStore
            : l10n.lookingForTheLatestFlickRelease,
      );
    }
    if (updateState.updateAvailable) {
      return (
        icon: LucideIcons.badgeAlert,
        title: l10n.englishForFilipino.updateAvailable,
        subtitle: isPlay
            ? l10n.openThePlayStoreToInstall
            : l10n.downloadTheLatestApkFromFlick,
      );
    }
    if (updateState.errorMessage != null) {
      return (
        icon: LucideIcons.info,
        title: l10n.englishForFilipino.couldNotCheckForUpdates,
        subtitle: updateState.errorMessage!,
      );
    }
    if (!updateState.isOnline) {
      return (
        icon: LucideIcons.wifiOff,
        title: l10n.englishForFilipino.offline,
        subtitle: l10n.reconnectToWiFiOrMobile,
      );
    }
    if (updateState.hasChecked) {
      return (
        icon: LucideIcons.badgeCheck,
        title: l10n.englishForFilipino.noUpdateAvailable,
        subtitle: isPlay
            ? l10n.youAlreadyHaveTheLatestPlay
            : l10n.youAlreadyHaveTheLatestFlick,
      );
    }
    return (
      icon: LucideIcons.info,
      title: l10n.englishForFilipino.automaticUpdateChecks,
      subtitle: isPlay
          ? l10n.flickScansForPlayStoreUpdates
          : l10n.flickChecksFlickPlayerSiteFor,
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
          : l10n.latestUpdate,
      body: body?.isNotEmpty == true ? body! : l10n.noPatchNotesAvailableYet,
      url: htmlUrl?.isNotEmpty == true ? htmlUrl! : _releaseNotesUrl,
    );
  }

  void _showPatchNotesBottomSheet() {
    GlassBottomSheet.show(
      context: context,
      title: l10n.englishForFilipino.patchNotes,
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
                    l10n.loadingPatchNotes,
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
                    l10n.unableToLoadPatchNotesRight,
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
                    label: Text(l10n.openReleaseNotes),
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
                  child: MarkdownBody(
                    data: notes.body,
                    styleSheet: MarkdownStyleSheet(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.adaptiveTextSecondary,
                        height: 1.5,
                      ),
                      h1: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      h3: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.adaptiveTextPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w700),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: context.adaptiveTextSecondary,
                        backgroundColor: AppColors.glassBackgroundStrong,
                      ),
                      listBullet: TextStyle(
                        color: context.adaptiveTextSecondary,
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.glassBorder),
                        ),
                      ),
                      blockquote: TextStyle(
                        color: context.adaptiveTextTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                      tableBorder: TableBorder.all(
                        color: AppColors.glassBorder,
                      ),
                      tableHead: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    selectable: true,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _launchUrl(notes.url),
                    icon: const Icon(LucideIcons.externalLink),
                    label: Text(l10n.openFullNotes),
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
      title: l10n.englishForFilipino.aboutFlickPlayer,
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
            child: Center(
              child: SvgPicture.asset(
                'assets/icons/flicklogo_svg.svg',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            l10n.flickPlayer,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.version(kAppVersion),
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
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
            child: Text(
              l10n.aPremiumMusicPlayerWithCustom,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
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
                onPressed: () =>
                    _launchUrl('https://github.com/moss-apps/Flick'),
                icon: const Icon(LucideIcons.squareCode, size: 18),
                label: Text(
                  l10n.github,
                  style: TextStyle(fontFamily: 'GoogleSansFlex'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              TextButton.icon(
                onPressed: () => _launchUrl('https://discord.gg/5hgcrdnKY6'),
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: Text(
                  l10n.discord,
                  style: TextStyle(fontFamily: 'GoogleSansFlex'),
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

  static String get _flickLicenseText => l10n.mitLicenseCopyrightC2026Flick;

  static bool _flickLicenseRegistered = false;

  // ponytail: LicensePage covers the list + detail UI; only Flick's own entry is added manually
  void _openLicensesScreen() {
    if (!_flickLicenseRegistered) {
      _flickLicenseRegistered = true;
      LicenseRegistry.addLicense(() async* {
        yield LicenseEntryWithLineBreaks(['Flick'], _flickLicenseText);
        // The Simplified Chinese fallback font ships with the app, so its
        // license has to be surfaced here as well.
        yield LicenseEntryWithLineBreaks(
          ['Noto Sans SC'],
          await rootBundle.loadString('assets/fonts/NotoSansSC-OFL.txt'),
        );
        yield LicenseEntryWithLineBreaks(
          ['Noto Sans Tagalog'],
          await rootBundle.loadString('assets/fonts/NotoSansTagalog-OFL.txt'),
        );
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // ponytail: iOS platform override swaps the app bar back arrow for a chevron-left
        builder: (_) => Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: LicensePage(
            applicationName: l10n.flick,
            applicationVersion: kAppVersion,
            applicationIcon: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              child: SvgPicture.asset(
                'assets/icons/flicklogo_svg.svg',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
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
        _showToast(l10n.couldNotOpenTheLink);
      }
    } catch (e) {
      if (mounted) {
        _showToast(l10n.couldNotOpenTheLink2(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateCheckProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.appInfo,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.updates),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.refreshCw,
                title: updateState.isChecking
                    ? l10n.englishForFilipino.checkingForUpdates2
                    : l10n.englishForFilipino.checkAgain,
                subtitle: updateState.isOnline
                    ? updateState.isPlayStoreBuild
                          ? l10n.runAnotherPlayStoreUpdateScan
                          : l10n.runAnotherUpdateScanRightNow
                    : l10n.reconnectToTheInternetToScan,
                onTap: updateState.isChecking ? null : _checkForUpdatesManually,
              ),
              const SettingsDivider(),
              _buildUpdateStatusTile(updateState),
              if (updateState.updateAvailable) ...[
                const SettingsDivider(),
                NavigationSetting(
                  icon: LucideIcons.fileText,
                  title: l10n.englishForFilipino.patchNotes,
                  subtitle: l10n.seeWhatIsNewInThis,
                  onTap: _showPatchNotesBottomSheet,
                ),
                const SettingsDivider(),
                if (updateState.isPlayStoreBuild)
                  ActionButton(
                    icon: LucideIcons.externalLink,
                    title: l10n.englishForFilipino.openInPlayStore,
                    subtitle: l10n.jumpToTheFlickListingAnd,
                    onTap: _openPlayStoreListing,
                  )
                else
                  ActionButton(
                    icon: LucideIcons.download,
                    title: l10n.englishForFilipino.downloadUpdate,
                    subtitle: l10n.getTheLatestApkFromFlick,
                    onTap: () =>
                        _launchUrl(UpdateCheckNotifier.flickWebsiteDownloadUrl),
                  ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.about),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.info,
                title: l10n.englishForFilipino.aboutFlickPlayer,
                subtitle: l10n.version(kAppVersion),
                onTap: _showAboutBottomSheet,
              ),
              if (_buildFlavor != null) ...[
                const SettingsDivider(),
                InfoSetting(
                  icon: LucideIcons.package,
                  title: l10n.englishForFilipino.buildFlavor,
                  subtitle: _buildFlavorSubtitle(_buildFlavor!),
                ),
              ],
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.fileText,
                title: l10n.englishForFilipino.licenses,
                subtitle: l10n.openSourceLicenses,
                onTap: _openLicensesScreen,
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.shieldCheck,
                title: l10n.englishForFilipino.privacyPolicy,
                subtitle: l10n.howWeHandleYourData,
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
                title: l10n.englishForFilipino.viewOnboarding,
                subtitle: l10n.replayTheTutorialAndFeatureGuide,
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
                title: l10n.englishForFilipino.interactiveTutorial,
                subtitle: l10n.stepByStepWalkthroughOfThe,
                onTap: () {
                  ref.read(tutorialProvider.notifier).start();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.support),
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
                    title: l10n.englishForFilipino.supportFlick,
                    subtitle: l10n.donateFundFeaturesAndKeepThe,
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
