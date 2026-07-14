import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/models/song.dart';
import 'package:flick/models/progress_bar_style.dart';
import 'package:flick/features/player/widgets/line_seek_bar.dart';
import 'package:flick/features/player/widgets/waveform_seek_bar.dart';
import 'package:flick/providers/providers.dart';

class WaveformLayer extends StatefulWidget {
  final PlayerService playerService;
  final ValueNotifier<Duration> positionNotifier;
  final Song? currentSong;

  const WaveformLayer({super.key,
    required this.playerService,
    required this.positionNotifier,
    required this.currentSong,
  });

  @override
  State<WaveformLayer> createState() => _WaveformLayerState();
}

class _WaveformLayerState extends State<WaveformLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appearController;
  late final Animation<double> _appearAnimation;
  String? _lastSongId;

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.currentSong?.id;
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _appearAnimation = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    );
    _appearController.forward();
  }

  @override
  void didUpdateWidget(covariant WaveformLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSong?.id != _lastSongId) {
      _lastSongId = widget.currentSong?.id;
      _appearController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final style = ref.watch(progressBarStyleProvider);
        return AnimatedBuilder(
          animation: _appearAnimation,
          builder: (context, _) {
            final t = _appearAnimation.value;
            return ValueListenableBuilder<Duration>(
              valueListenable: widget.playerService.durationNotifier,
              builder: (context, engineDuration, _) {
                final duration = engineDuration.inMilliseconds > 0
                    ? engineDuration
                    : (widget.currentSong?.duration ?? Duration.zero);

                if (duration.inMilliseconds == 0) {
                  return const SizedBox();
                }

                return ValueListenableBuilder<Duration>(
                  valueListenable: widget.positionNotifier,
                  builder: (context, position, _) {
                    final seekBar = switch (style) {
                      ProgressBarStyle.line => LineSeekBar(
                        position: position,
                        duration: duration,
                        appearProgress: t,
                        onChanged: (newPos) {
                          widget.positionNotifier.value = newPos;
                          unawaited(widget.playerService.seek(newPos));
                        },
                      ),
                      ProgressBarStyle.waveform => WaveformSeekBar(
                        barCount: 60,
                        position: position,
                        duration: duration,
                        appearProgress: t,
                        onChanged: (newPos) {
                          widget.positionNotifier.value = newPos;
                          unawaited(widget.playerService.seek(newPos));
                        },
                      ),
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RepaintBoundary(child: seekBar),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Extracted player controls widget to reduce nesting and improve performance
