import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';

class QueueSettingsScreen extends ConsumerWidget {
  const QueueSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);

    return SettingsScaffold(
      title: 'Queue',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Queue'),
          SettingsCard(
            children: [
              _WrapAroundQueueTile(playerService: playerService),
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
          title: 'Wrap-around Queue',
          subtitle: enabled
              ? 'Songs before the tapped track queue at the end'
              : 'Stop at the end of the current list',
          value: enabled,
          onChanged: (value) => playerService.setWrapAroundQueue(value),
        );
      },
    );
  }
}
