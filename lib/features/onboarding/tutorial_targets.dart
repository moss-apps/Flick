import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TutorialTarget {
  navBar,
  miniPlayer,
  songsSearchBar,
  songsSortButton,
  songLibrary,
  addMusicFolder,
  playerQueue,
  playerLyrics,
}

/// Layout handoffs may overlap: unregister only the owner and prefer the
/// most recently mounted, visible target on the current route.
class TutorialTargetRegistry extends ChangeNotifier {
  final Map<TutorialTarget, List<GlobalKey>> _keys = {};
  bool _scheduled = false;
  bool _disposed = false;
  void register(TutorialTarget target, GlobalKey key) {
    (_keys[target] ??= []).add(key);
    changed();
  }

  void unregister(TutorialTarget target, [GlobalKey? key]) {
    if (key == null) {
      _keys.remove(target);
    } else {
      _keys[target]?.remove(key);
    }
    changed();
  }

  void changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  Rect? rectFor(TutorialTarget target, {RenderBox? relativeTo}) {
    for (final key in (_keys[target] ?? <GlobalKey>[]).reversed) {
      final ctx = key.currentContext;
      if (ctx == null || ModalRoute.of(ctx)?.isCurrent == false) continue;
      final object = ctx.findRenderObject();
      if (object is! RenderBox ||
          !object.attached ||
          !object.hasSize ||
          object.size.isEmpty) {
        continue;
      }
      final rect = MatrixUtils.transformRect(
        object.getTransformTo(relativeTo),
        Offset.zero & object.size,
      );
      if (rect.isFinite && !rect.isEmpty) return rect;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final tutorialTargetRegistryProvider = Provider<TutorialTargetRegistry>((ref) {
  final registry = TutorialTargetRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});

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
  final _key = GlobalKey();
  late final TutorialTargetRegistry _registry;
  @override
  void initState() {
    super.initState();
    _registry = ref.read(tutorialTargetRegistryProvider)
      ..register(widget.target, _key);
  }

  @override
  void didUpdateWidget(TutorialTargetAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _registry.unregister(oldWidget.target, _key);
      _registry.register(widget.target, _key);
    }
  }

  @override
  void dispose() {
    _registry.unregister(widget.target, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LayoutSignal(key: _key, onPaint: _registry.changed, child: widget.child);
}

class _LayoutSignal extends SingleChildRenderObjectWidget {
  const _LayoutSignal({super.key, required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) => _SignalBox(onPaint);
  @override
  void updateRenderObject(BuildContext context, _SignalBox renderObject) =>
      renderObject.onPaint = onPaint;
}

class _SignalBox extends RenderProxyBox {
  _SignalBox(this.onPaint);
  VoidCallback onPaint;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    onPaint();
  }
}
