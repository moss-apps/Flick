import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

class QueueSettingsScreen extends ConsumerWidget {
  const QueueSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.queue,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.queue, sectionId: 'queue'),
          SettingsCard(
            children: [
              _WrapAroundQueueTile(playerService: playerService),
              _AutoplayOnQueueEndTile(playerService: playerService),
            ],
          ),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _WrapAroundQueueTile extends StatelessWidget {
  const _WrapAroundQueueTile({required this.playerService});

  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerService.wrapAroundQueueNotifier,
      builder: (context, _) {
        final enabled = playerService.wrapAroundQueueNotifier.value;
        return ToggleSetting(
          icon: LucideIcons.refreshCw,
          title: l10n.englishForFilipino.wrapAroundQueue,
          subtitle: enabled
              ? l10n.songsBeforeTheTappedTrackQueue
              : l10n.stopAtTheEndOfThe,
          value: enabled,
          onChanged: (value) => playerService.setWrapAroundQueue(value),
        );
      },
    );
  }
}

class _AutoplayOnQueueEndTile extends StatelessWidget {
  const _AutoplayOnQueueEndTile({required this.playerService});

  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerService.autoplayOnQueueEndNotifier,
      builder: (context, _) {
        final enabled = playerService.autoplayOnQueueEndNotifier.value;
        return ToggleSetting(
          icon: LucideIcons.shuffle,
          title: l10n.englishForFilipino.autoplayOnQueueEnd,
          subtitle: enabled
              ? l10n.playARandomLibrarySongWhen
              : l10n.stopWhenTheQueueEnds,
          value: enabled,
          onChanged: (value) => playerService.setAutoplayOnQueueEnd(value),
        );
      },
    );
  }
}
