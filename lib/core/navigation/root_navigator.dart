import 'package:flutter/material.dart';

/// Global key for the root navigator. Pushing via this key places routes
/// above the persistent bottom bar (i.e. the bar is hidden). The nested
/// navigator inside [MainShell] keeps routes below the bar.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global key for the nested navigator inside [MainShell]. Pushing via this
/// key keeps the persistent bottom bar visible.
final GlobalKey<NavigatorState> nestedNavigatorKey =
    GlobalKey<NavigatorState>();
