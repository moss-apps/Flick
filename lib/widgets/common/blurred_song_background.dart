import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/features/player/widgets/ambient_background.dart';
import 'package:flick/providers/player_provider.dart';

/// Gradient base + blurred current-song album art behind pushed routes.
/// Matches the MainShell / SettingsScaffold background so screens pushed
/// onto the navigator don't fall through to black.
class BlurredSongBackground extends ConsumerWidget {
  final Widget child;

  const BlurredSongBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
        ),
        Positioned.fill(child: AmbientBackground(song: currentSong)),
        Positioned.fill(child: child),
      ],
    );
  }
}
