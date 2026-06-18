import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TutorialTarget { navBar, miniPlayer, songsSearchBar, songsSortButton }

class TutorialTargetRegistry {
  final Map<TutorialTarget, GlobalKey> _keys = {};

  void register(TutorialTarget target, GlobalKey key) => _keys[target] = key;
  void unregister(TutorialTarget target) => _keys.remove(target);

  Rect? rectFor(TutorialTarget target) {
    final key = _keys[target];
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }
}

final tutorialTargetRegistryProvider =
    Provider<TutorialTargetRegistry>((ref) => TutorialTargetRegistry());

class TutorialTargetAnchor extends ConsumerStatefulWidget {
  const TutorialTargetAnchor({
    super.key,
    required this.target,
    required this.child,
  });

  final TutorialTarget target;
  final Widget child;

  @override
  ConsumerState<TutorialTargetAnchor> createState() =>
      _TutorialTargetAnchorState();
}

class _TutorialTargetAnchorState extends ConsumerState<TutorialTargetAnchor> {
  late final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(tutorialTargetRegistryProvider)
          .register(widget.target, _key);
    });
  }

  @override
  void dispose() {
    ref.read(tutorialTargetRegistryProvider).unregister(widget.target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
