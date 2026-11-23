import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/network_source_display.dart';
import 'package:flick/l10n/english_l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';

/// "Source" metadata row for network songs. Renders nothing for local songs.
///
/// Kept as a [ConsumerWidget] so both metadata sheets resolve the current
/// server label without each sheet needing its own data plumbing.
class SongNetworkSourceRow extends ConsumerWidget {
  final Song song;

  const SongNetworkSourceRow({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(networkServersProvider).value;
    final name = networkServerDisplayName(song, servers);
    if (name == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              l10n.source,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 13,
                color: context.adaptiveTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
