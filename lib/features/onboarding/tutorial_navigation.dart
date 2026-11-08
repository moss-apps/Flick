import 'package:flutter/material.dart';

/// Both stacks report here, so a nested sheet also suspends guidance.
class TutorialNavigation extends ChangeNotifier {
  final root = TutorialRouteObserver();
  final nested = TutorialRouteObserver();
  TutorialNavigation() {
    root.onChanged = notifyListeners;
    nested.onChanged = notifyListeners;
  }
  String? get currentName => root.top?.isFirst == true
      ? nested.top?.settings.name ?? root.top?.settings.name
      : root.top?.settings.name;
  bool get visible {
    final route = root.top;
    if (route == null || route is PopupRoute || nested.top is PopupRoute) {
      return false;
    }
    final name = currentName;
    return (route.isFirst && (nested.top?.isFirst ?? true)) ||
        name == '/full_player' ||
        name == '/queue' ||
        (name?.startsWith('/tutorial/') ?? false);
  }

  @override
  void dispose() {
    root.onChanged = null;
    nested.onChanged = null;
    super.dispose();
  }
}

class TutorialRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  VoidCallback? onChanged;
  Route<dynamic>? get top => _routes.lastOrNull;
  bool _scheduled = false;
  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      onChanged?.call();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) _routes.clear();
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _changed();
  }
}

final tutorialNavigation = TutorialNavigation();
