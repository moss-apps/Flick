import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/l10n/settings_l10n.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(
                          title: l10n.englishForFilipino.dataCollection,
                          content:
                              l10n.flickPlayerDoesNotCollectStore,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.localData,
                          content:
                              l10n.allDataIsStoredLocallyOn,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.cameraAndPhotos,
                          content:
                              l10n.cameraAndPhotoLibraryAccessIs,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.storagePermissions,
                          content:
                              l10n.storageAccessIsRequiredToScan,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.usbDeviceAccess,
                          content:
                              l10n.usbAudioClass20Devices,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.lastFmScrobbling,
                          content:
                              l10n.ifYouConnectYourLastFm,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.albumArtImport,
                          content:
                              l10n.theAppQueriesPublicApisMusicbrainz,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.mossEcosystem,
                          content:
                              l10n.flickCanReceivePlaybackHandoffsFrom,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.inAppUpdates,
                          content:
                              l10n.playStoreUpdatesUseGooglePlay,
                        ),
                        _Section(
                          title: l10n.englishForFilipino.childrenSPrivacy,
                          content:
                              l10n.theAppDoesNotKnowinglyCollect,
                        ),
                        const SizedBox(height: AppConstants.spacingLg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppConstants.spacingMd),
                          decoration: BoxDecoration(
                            color: AppColors.glassBackground,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMd,
                            ),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.lastUpdated,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(
                                  color: context.adaptiveTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.may42026,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: context.adaptiveTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingLg),
                        const SizedBox(
                          height: AppConstants.navBarHeight + 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              LucideIcons.chevronLeft,
              color: context.adaptiveTextPrimary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            l10n.englishForFilipino.privacyPolicy,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.adaptiveTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
