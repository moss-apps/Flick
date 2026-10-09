import 'package:flutter/material.dart';

import 'replay_style.dart';

/// A single, viewport-triggered entrance, retained through history refreshes.
class ReplayReveal extends StatefulWidget {
  final ScrollController scrollController;
  final Widget child;
  final int order;

  const ReplayReveal({
    super.key,
    required this.scrollController,
    required this.child,
    this.order = 0,
  });

  @override
  State<ReplayReveal> createState() => _ReplayRevealState();
}

class _ReplayRevealState extends State<ReplayReveal>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _revealed = false;
  bool _checkScheduled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scheduleCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = ReplayStyle.duration(context, slow: true);
    if (_controller.duration == Duration.zero) {
      _revealed = true;
      _controller.value = 1;
    } else {
      _scheduleCheck();
    }
  }

  @override
  void didUpdateWidget(ReplayReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_scheduleCheck);
      widget.scrollController.addListener(_scheduleCheck);
      _scheduleCheck();
    }
  }

  void _scheduleCheck() {
    if (_revealed || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted || _revealed || !TickerMode.valuesOf(context).enabled) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final height = MediaQuery.sizeOf(context).height;
    if (top < height - 24 && top + box.size.height > 0) {
      _revealed = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scheduleCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final start = (widget.order * 0.06).clamp(0.0, 0.24);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Interval(
          start,
          1,
          curve: Curves.easeOutQuart,
        ).transform(_controller.value);
        // Full-contrast content even before its entrance or when a ticker is
        // paused. A reveal must not wash out a colored panel or its text.
        return Transform.translate(
          offset: Offset(0, 32 * (1 - progress)),
          child: child,
        );
      },
    );
  }
}
