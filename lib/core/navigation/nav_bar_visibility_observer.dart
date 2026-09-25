import 'package:flutter/material.dart';

/// Notifies when the top route of a navigator changes (push, pop, replace).
/// Used by [MainShell] to re-show the bottom bar whenever a screen is entered
/// or the user returns to a tab.
class NavBarVisibilityObserver extends NavigatorObserver {
  NavBarVisibilityObserver(this.onScreenChanged);

  final VoidCallback onScreenChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onScreenChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onScreenChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onScreenChanged();
  }
}
