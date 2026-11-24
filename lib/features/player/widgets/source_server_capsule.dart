import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/utils/network_source_display.dart';
import 'package:flick/l10n/english_l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/providers.dart';

/// Quiet, display-only capsule naming the server a song was imported from.
///
/// Renders nothing for local songs (including no spacing), so adding it to a
/// layout does not change local playback layouts.
class SourceServerCapsule extends ConsumerWidget {
  final Song song;
  final double topSpacing;
  final double maxWidth;

  const SourceServerCapsule({
    super.key,
    required this.song,
    this.topSpacing = 0,
    this.maxWidth = 240,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(networkServersProvider).value;
    final name = networkServerDisplayName(song, servers);
    if (name == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: topSpacing),
      child: Semantics(
        container: true,
        label: '${l10n.source}: $name',
        child: ExcludeSemantics(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.server,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'GoogleSansFlex',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.64),
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
