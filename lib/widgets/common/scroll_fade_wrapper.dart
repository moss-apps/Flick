import 'package:flutter/material.dart';

/// Fades [child] out as the scroll offset grows, so heroes dissolve
/// instead of being clipped by the pinned app bar.
class ScrollFadeWrapper extends StatefulWidget {
  final ScrollController scrollController;
  final double fadeDistance;
  final Widget child;

  const ScrollFadeWrapper({
    super.key,
    required this.scrollController,
    this.fadeDistance = 196,
    required this.child,
  });

  @override
  State<ScrollFadeWrapper> createState() => _ScrollFadeWrapperState();
}

class _ScrollFadeWrapperState extends State<ScrollFadeWrapper> {
  // ponytail: ValueNotifier so only the Opacity node rebuilds per scroll
  // frame; switch to RenderProxyBox if this ever shows up in profiles.
  final ValueNotifier<double> _opacity = ValueNotifier(1.0);

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    _opacity.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final t = (widget.scrollController.offset / widget.fadeDistance).clamp(
      0.0,
      1.0,
    );
    final v = 1.0 - t;
    if ((v - _opacity.value).abs() > 0.01) _opacity.value = v;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _opacity,
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: widget.child,
    );
  }
}
