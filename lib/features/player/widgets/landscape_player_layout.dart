import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A bounded listening composition, not two columns stretched to the window.
/// The identity and playback stay together; only the identity/actions scroll
/// when enlarged text or a short window leaves too little vertical space.
class LandscapePlayerLayout extends StatelessWidget {
  final Widget stage;
  final Widget identity;
  final Widget? actions;
  final Widget playback;
  final bool artworkCard;
  final bool lyricsMode;

  const LandscapePlayerLayout({
    super.key,
    required this.stage,
    required this.identity,
    required this.playback,
    this.actions,
    this.artworkCard = false,
    this.lyricsMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(1080.0, constraints.maxWidth);
        final gap = width >= 800 ? 40.0 : 20.0;
        final controlsWidth = math.min(
          500.0,
          math.max(248.0, width * (lyricsMode ? 0.48 : 0.52)),
        );
        final stageWidth = math.max(0.0, width - controlsWidth - gap);
        final artExtent = math.min(400.0, stageWidth);
        // The artwork card's file row sits directly below the identity block;
        // give that pairing more air than the immersive header needs.
        final identityToActionsGap = artworkCard ? 24.0 : 12.0;

        return Center(
          child: SizedBox(
            width: width,
            child: Row(
              children: [
                SizedBox(
                  width: stageWidth,
                  child: Center(
                    child: artworkCard && !lyricsMode
                        ? SizedBox(
                            width: artExtent,
                            height: math.min(artExtent, constraints.maxHeight),
                            child: stage,
                          )
                        : stage,
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: controlsWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          key: const ValueKey('landscape-player-details'),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              identity,
                              if (actions != null) ...[
                                SizedBox(height: identityToActionsGap),
                                actions!,
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      playback,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
