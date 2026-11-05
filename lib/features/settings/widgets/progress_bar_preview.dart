import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flick/features/player/widgets/line_seek_bar.dart';
import 'package:flick/features/player/widgets/waveform_seek_bar.dart';
import 'package:flick/models/progress_bar_style.dart';
import 'package:flick/providers/providers.dart';

/// Non-interactive preview of the player progress bar at its current size.
class ProgressBarPreview extends ConsumerWidget {
  const ProgressBarPreview({super.key});

  static const _position = Duration(minutes: 1, seconds: 23);
  static const _duration = Duration(minutes: 3, seconds: 20);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(progressBarStyleProvider);
    final sizes = ref.watch(progressBarSizeProvider);

    return ExcludeSemantics(
      child: IgnorePointer(
        child: switch (style) {
          ProgressBarStyle.line => LineSeekBar(
            position: _position,
            duration: _duration,
            onChanged: (_) {},
            thickness: sizes.lineThickness,
          ),
          ProgressBarStyle.waveform => WaveformSeekBar(
            barCount: 60,
            position: _position,
            duration: _duration,
            onChanged: (_) {},
            height: sizes.waveformHeight,
          ),
        },
      ),
    );
  }
}
