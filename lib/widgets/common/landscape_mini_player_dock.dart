import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/adaptive_layout.dart';
import 'package:flick/features/onboarding/tutorial_targets.dart';

/// Moves between the bottom bar and compact orbit strip without laying out
/// either player on every animation frame.
class LandscapeMiniPlayerDock extends StatefulWidget {
  const LandscapeMiniPlayerDock({
    super.key,
    required this.sideDocked,
    required this.bottomPlayerHeight,
    required this.bottomPlayer,
    required this.sidePlayer,
  });

  final bool sideDocked;
  final double bottomPlayerHeight;
  final Widget bottomPlayer;
  final Widget sidePlayer;

  @override
  State<LandscapeMiniPlayerDock> createState() =>
      _LandscapeMiniPlayerDockState();
}

class _LandscapeMiniPlayerDockState extends State<LandscapeMiniPlayerDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.sideDocked ? 1 : 0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(LandscapeMiniPlayerDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion(move: oldWidget.sideDocked != widget.sideDocked);
  }

  void _syncMotion({bool move = false}) {
    final disabled =
        MediaQuery.disableAnimationsOf(context) ||
        AppConstants.animationNormal == Duration.zero;
    _controller.duration = disabled
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final target = widget.sideDocked ? 1.0 : 0.0;
    if (disabled) {
      _controller.value = target;
    } else if (move) {
      // animateTo starts at the current position, including on rapid reversals.
      _controller.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _player(Widget child, {required bool active}) => HeroMode(
    enabled: active,
    child: TickerMode(
      enabled: active,
      child: ExcludeSemantics(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: RepaintBoundary(child: child),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Match the original bottom player's safe area; the side strip additionally
    // leaves room for the top system inset.
    final topInset = MediaQuery.paddingOf(context).top;
    return SafeArea(
      top: false,
      left: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomRect = Rect.fromLTWH(
            0,
            constraints.maxHeight - widget.bottomPlayerHeight,
            constraints.maxWidth,
            widget.bottomPlayerHeight,
          );
          final sideRect = Rect.fromLTWH(
            constraints.maxWidth - AdaptiveLayout.sideMiniPlayerWidth - 6,
            topInset,
            AdaptiveLayout.sideMiniPlayerWidth,
            (constraints.maxHeight - topInset).clamp(0.0, double.infinity),
          );
          final travel = sideRect.center - bottomRect.center;
          // These subtrees stay fixed during ticks. Only translation and opacity
          // change; the outgoing visualizer is muted and removed on completion.
          final bottomPlayer = _player(
            widget.bottomPlayer,
            active: !widget.sideDocked,
          );
          final sidePlayer = _player(
            widget.sidePlayer,
            active: widget.sideDocked,
          );
          final anchor = IgnorePointer(
            child: TutorialTargetAnchor(
              target: TutorialTarget.miniPlayer,
              child: const SizedBox.expand(),
            ),
          );

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final bottomOffset = travel * t;
              final sideOffset = travel * (t - 1);
              return ClipRect(
                child: Stack(
                  children: [
                    if (t < 1)
                      Positioned.fromRect(
                        key: const ValueKey('bottom_mini_player_dock'),
                        rect: bottomRect,
                        child: Transform.translate(
                          offset: bottomOffset,
                          child: Opacity(opacity: 1 - t, child: bottomPlayer),
                        ),
                      ),
                    if (t > 0)
                      Positioned.fromRect(
                        key: const ValueKey('side_mini_player_dock'),
                        rect: sideRect,
                        child: Transform.translate(
                          offset: sideOffset,
                          child: Opacity(opacity: t, child: sidePlayer),
                        ),
                      ),
                    // One persistent anchor avoids duplicate registrations while
                    // both player layouts briefly share the dock.
                    Positioned.fromRect(
                      key: const ValueKey('mini_player_dock_anchor'),
                      rect: widget.sideDocked ? sideRect : bottomRect,
                      child: Transform.translate(
                        offset: widget.sideDocked ? sideOffset : bottomOffset,
                        child: anchor,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
