import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'replay_artwork.dart';
import 'replay_style.dart';

/// Three authored SVG layers. Bounds reserve the entire ±2° / 3dp movement,
/// including strokes. The SVG viewBoxes never rely on a cropped oversized arc.
class ReplayOrnament extends StatefulWidget {
  final Color color;
  final bool animated;
  final ScrollController? scrollController;

  const ReplayOrnament({
    super.key,
    required this.color,
    this.animated = false,
    this.scrollController,
  });

  @override
  State<ReplayOrnament> createState() => _ReplayOrnamentState();
}

class _ReplayOrnamentState extends State<ReplayOrnament>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
    value: 0.5,
  );
  bool _scheduled = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController?.addListener(_scheduleVisibility);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleVisibility();
  }

  @override
  void didUpdateWidget(ReplayOrnament oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_scheduleVisibility);
      widget.scrollController?.addListener(_scheduleVisibility);
    }
    _scheduleVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!_resumed) _controller.stop();
    _scheduleVisibility();
  }

  void _scheduleVisibility() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final render = context.findRenderObject();
      final viewport = MediaQuery.of(context);
      final enabled =
          widget.animated &&
          _resumed &&
          TickerMode.valuesOf(context).enabled &&
          ReplayStyle.duration(context) != Duration.zero;
      var visible = false;
      if (render is RenderBox && render.hasSize && render.attached) {
        final top = render.localToGlobal(Offset.zero).dy;
        visible =
            top < viewport.size.height - viewport.padding.bottom &&
            top + render.size.height > viewport.padding.top;
      }
      if (enabled && visible) {
        if (!_controller.isAnimating) _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        if (!enabled) _controller.value = 0.5;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.scrollController?.removeListener(_scheduleVisibility);
    _controller.dispose();
    super.dispose();
  }

  Widget _layer(String name, double strength) => RepaintBoundary(
    child: SvgPicture.asset(
      'assets/recap/replay_$name.svg',
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        widget.color.withValues(alpha: strength),
        BlendMode.srcIn,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dots = _layer('dots', 0.9);
    final motion =
        widget.animated && ReplayStyle.duration(context) != Duration.zero;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AnimatedBuilder(
          animation: _controller,
          child: Stack(
            fit: StackFit.expand,
            children: [_layer('loop', 0.82), _layer('contours', 0.72)],
          ),
          builder: (context, child) {
            // Capture must settle in this paint, not in the visibility check's
            // following frame. Otherwise a fast save can keep the idle pose.
            final sway = motion
                ? math.sin((_controller.value - 0.5) * math.pi)
                : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(sway * 3, -sway * 2),
                  child: Transform.rotate(angle: sway * 0.035, child: child),
                ),
                Transform.translate(
                  offset: Offset(-sway * 2, sway * 2),
                  child: dots,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Stable covers above a living vector ornament. Entrance and scroll settle
/// the sleeves; only the ornament moves while idle. The front cover is intact.
class ReplayArtworkStage extends StatelessWidget {
  final List<String?> paths;
  final ScrollController? scrollController;
  final Color color;
  final String? badge;
  final bool animated;
  final bool ornaments;
  final bool layered;
  final bool framed;
  final bool highResolution;

  const ReplayArtworkStage({
    super.key,
    required this.paths,
    this.scrollController,
    this.color = ReplayStyle.acid,
    this.badge,
    this.animated = true,
    this.ornaments = true,
    this.layered = true,
    this.framed = false,
    this.highResolution = false,
  });

  @override
  Widget build(BuildContext context) {
    final motion = animated && ReplayStyle.duration(context) != Duration.zero;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final coverSize = math.min(228.0, width * 0.62);
        final count = layered
            ? math.min(paths.length, 3)
            : math.min(paths.length, 1);
        Widget compose(double entrance, double scroll) {
          final release = Curves.easeOutCubic.transform(scroll);
          final fan = entrance * (1 - release * 0.35);
          return SizedBox(
            height: coverSize + 64,
            width: width,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (ornaments)
                  Positioned.fill(
                    child: ReplayOrnament(
                      color: color,
                      animated: motion,
                      scrollController: scrollController,
                    ),
                  ),
                if (framed)
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: coverSize + 28,
                      child: CustomPaint(
                        painter: ReplaySleeveFramePainter(color: color),
                      ),
                    ),
                  ),
                for (var i = count - 1; i >= 0; i--)
                  ExcludeSemantics(
                    child: Transform.translate(
                      offset: Offset(
                        i == 0 ? (framed ? 0 : 6 * fan) : -14 * i * fan,
                        i * 3.0,
                      ),
                      child: Transform.rotate(
                        angle: i == 0
                            ? (framed || !layered ? 0 : 0.025 * fan)
                            : -0.09 * i * fan,
                        child: Transform.scale(
                          scale: (0.95 + 0.05 * entrance) * (1 - i * 0.045),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x45000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ReplayArtwork(
                              path: paths[i],
                              size: coverSize,
                              useThumbnail: !highResolution,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (badge != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ReplayStyle.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width - 40),
                          child: Text(
                            badge!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ReplayStyle.acid,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        Widget withScroll(double entrance) {
          if (!motion || scrollController == null) return compose(entrance, 0);
          return AnimatedBuilder(
            animation: scrollController!,
            builder: (context, child) => compose(
              entrance,
              (scrollController!.hasClients
                      ? scrollController!.offset / 280
                      : 0.0)
                  .clamp(0.0, 1.0),
            ),
          );
        }

        if (!motion) return withScroll(1);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: ReplayStyle.duration(context, slow: true),
          curve: Curves.easeOutQuart,
          builder: (context, entrance, child) => withScroll(entrance),
        );
      },
    );
  }
}

/// Quiet registration corners outside the complete cover, never over it.
class ReplaySleeveFramePainter extends CustomPainter {
  final Color color;
  const ReplaySleeveFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;
    const inset = 2.0;
    const length = 14.0;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final corners = Path()
      ..moveTo(inset, inset + length)
      ..lineTo(inset, inset)
      ..lineTo(inset + length, inset)
      ..moveTo(right - length, inset)
      ..lineTo(right, inset)
      ..lineTo(right, inset + length)
      ..moveTo(right, bottom - length)
      ..lineTo(right, bottom)
      ..lineTo(right - length, bottom)
      ..moveTo(inset + length, bottom)
      ..lineTo(inset, bottom)
      ..lineTo(inset, bottom - length);
    canvas.drawPath(corners, paint);
  }

  @override
  bool shouldRepaint(ReplaySleeveFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
