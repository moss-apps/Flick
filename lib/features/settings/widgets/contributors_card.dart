import 'package:flutter/material.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/services/github_contributors_service.dart';
import 'package:flick/widgets/common/cached_image_widget.dart';
import 'settings_widgets.dart';

/// A contributor credited in Settings → App Info.
@immutable
class FlickContributor {
  const FlickContributor(this.username);

  final String username;

  String get profileUrl => 'https://github.com/$username';

  /// GitHub serves the profile image from this stable path and follows the
  /// redirect to its avatar CDN, so no API token or rate-limited endpoint is
  /// involved.
  String get avatarUrl => '$profileUrl.png?size=160';
}

/// Snapshot of everyone credited for contributing to the repository.
///
/// The live list is loaded from GitHub when the card mounts. This snapshot
/// keeps the card complete offline and retains credits that are not part of
/// the GitHub commit list.
const List<FlickContributor> flickContributors = <FlickContributor>[
  FlickContributor('ultraelectronica'),
  FlickContributor('jneerdael-netskope'),
  FlickContributor('gc233402-blip'),
  FlickContributor('Harleythetech'),
  FlickContributor('adithya-s-119'),
  FlickContributor('SenpaiAdri'),
  FlickContributor('fukiame'),
  FlickContributor('SamarpitSantoki'),
  FlickContributor('MagosVox'),
];

/// Card of round GitHub profile pictures for Flick's contributors.
///
/// The contributor list and images are fetched when App Info opens. A bundled
/// snapshot and monogram fallbacks keep the card intact offline or when GitHub
/// is unreachable. Tapping a portrait reveals the username in a tooltip.
class ContributorsCard extends StatefulWidget {
  const ContributorsCard({super.key, this.contributors});

  /// Explicit list for tests and previews. When null the card loads the
  /// repository's contributors from GitHub.
  final List<FlickContributor>? contributors;

  @override
  State<ContributorsCard> createState() => _ContributorsCardState();
}

class _ContributorsCardState extends State<ContributorsCard> {
  late List<FlickContributor> _contributors =
      widget.contributors ?? flickContributors;

  @override
  void initState() {
    super.initState();
    if (widget.contributors == null) {
      _loadContributors();
    }
  }

  Future<void> _loadContributors() async {
    try {
      final usernames = await GitHubContributorsService.fetch();
      if (!mounted || usernames.isEmpty) return;

      final seen = {for (final username in usernames) username.toLowerCase()};
      final merged = <FlickContributor>[
        for (final username in usernames) FlickContributor(username),
        for (final contributor in flickContributors)
          if (!seen.contains(contributor.username.toLowerCase())) contributor,
      ];

      setState(() => _contributors = merged);
    } catch (_) {
      // Keep the bundled snapshot when GitHub is unreachable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Wrap(
            spacing: AppConstants.spacingMd,
            runSpacing: AppConstants.spacingMd,
            children: [
              for (final contributor in _contributors)
                ContributorAvatar(contributor: contributor),
            ],
          ),
        ),
      ],
    );
  }
}

class ContributorAvatar extends StatelessWidget {
  const ContributorAvatar({super.key, required this.contributor});

  static const double _size = 48;

  final FlickContributor contributor;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      color: AppColors.glassBackgroundStrong,
      child: Text(
        contributor.username.isEmpty
            ? '?'
            : contributor.username.substring(0, 1).toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: context.adaptiveTextSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Tooltip(
      message: '@${contributor.username}',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      child: Container(
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.glassBackground,
          border: Border.all(color: AppColors.glassBorderStrong),
        ),
        child: ClipOval(
          child: CachedImageWidget(
            imagePath: contributor.avatarUrl,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            placeholder: fallback,
            errorWidget: fallback,
            useThumbnail: true,
            thumbnailWidth: _size.round() * 2,
            thumbnailHeight: _size.round() * 2,
          ),
        ),
      ),
    );
  }
}
