import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/player/widgets/audio_visualizer.dart';
import 'package:flick/core/utils/responsive.dart';

class VisualizerArtBox extends StatelessWidget {
  final PlayerService playerService;
  final double? size;
  final String animationStyle;
  final String frequencyMode;
  final String movementMode;
  final Color? albumColor;
  final bool showFrame;

  const VisualizerArtBox({super.key,
    required this.playerService,
    this.size,
    this.animationStyle = 'bars',
    this.frequencyMode = 'full',
    this.movementMode = 'bouncy',
    this.albumColor,
    this.showFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    final double resolvedSize = size ?? context.responsive(280.0, 320.0, 360.0);
    final framePadding = resolvedSize < 220 ? 5.0 : 7.0;
    final outerRadius = resolvedSize < 220 ? 28.0 : 34.0;
    final innerRadius = math.max(outerRadius - 7.0, 20.0);
    final shadowBlur = resolvedSize < 220 ? 28.0 : 36.0;
    final shadowOffsetY = resolvedSize < 220 ? 14.0 : 20.0;

    final visualizer = Container(
      color: const Color(0xFF0A0A0A),
      child: AudioVisualizer(
        playerService: playerService,
        animationStyle: animationStyle,
        frequencyMode: frequencyMode,
        movementMode: movementMode,
        albumColor: albumColor,
      ),
    );

    return Center(
      child: showFrame
          ? Container(
              width: resolvedSize,
              height: resolvedSize,
              padding: EdgeInsets.all(framePadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(outerRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: shadowBlur,
                    offset: Offset(0, shadowOffsetY),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.06),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(innerRadius),
                child: visualizer,
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(outerRadius),
              child: SizedBox(
                width: resolvedSize,
                height: resolvedSize,
                child: visualizer,
              ),
            ),
    );
  }
}

