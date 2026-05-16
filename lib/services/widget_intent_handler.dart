import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../providers/player_provider.dart';
import '../providers/navigation_provider.dart';

/// Handles deep-link intents coming from the home-screen widgets.
///
/// Widgets fire `home_widget://<action>?...` URIs through the `home_widget`
/// plugin. This class translates those URIs into Riverpod actions.
///
/// Recognised actions:
///   * `home_widget://player/play_pause`
///   * `home_widget://player/next`
///   * `home_widget://player/previous`
///   * `home_widget://player/jump?index=<int>`
///   * `home_widget://library/open?section=<songs|albums|artists|playlists|favorites|menu|settings>`
class WidgetIntentHandler {
  WidgetIntentHandler(this._ref);

  final WidgetRef _ref;
  StreamSubscription<Uri?>? _sub;

  /// Wires up listeners. Safe to call multiple times.
  Future<void> attach() async {
    await detach();
    // Handle the URI used to launch the app (cold start).
    final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (launchUri != null) {
      _dispatch(launchUri);
    }
    // Handle URIs while the app is already running.
    _sub = HomeWidget.widgetClicked.listen(_dispatch);
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _dispatch(Uri? uri) {
    if (uri == null) return;
    try {
      final segments = uri.pathSegments;
      switch (uri.host) {
        case 'player':
          _handlePlayer(segments.isEmpty ? '' : segments.first, uri);
          break;
        case 'library':
          _handleLibrary(segments.isEmpty ? '' : segments.first, uri);
          break;
        default:
          debugPrint('WidgetIntentHandler: unknown host ${uri.host}');
      }
    } catch (e, st) {
      debugPrint('WidgetIntentHandler dispatch error: $e\n$st');
    }
  }

  void _handlePlayer(String action, Uri uri) {
    final notifier = _ref.read(playerProvider.notifier);
    switch (action) {
      case 'play_pause':
        unawaited(notifier.togglePlayPause());
        break;
      case 'next':
        unawaited(notifier.next());
        break;
      case 'previous':
        unawaited(notifier.previous());
        break;
      case 'jump':
        final idx = int.tryParse(uri.queryParameters['index'] ?? '');
        if (idx != null && idx >= 0) {
          unawaited(notifier.playFromQueueIndex(idx));
        }
        break;
      default:
        debugPrint('WidgetIntentHandler: unknown player action $action');
    }
  }

  void _handleLibrary(String action, Uri uri) {
    if (action != 'open') return;
    final section = uri.queryParameters['section'] ?? 'songs';
    // The navigation index map mirrors `_MainShell`'s PageView pages:
    //   0 = menu, 1 = songs, 2 = settings.
    // Library sections beyond those three are exposed through the menu.
    final navNotifier = _ref.read(navigationIndexProvider.notifier);
    switch (section) {
      case 'menu':
      case 'albums':
      case 'artists':
      case 'playlists':
      case 'favorites':
      case 'folders':
        navNotifier.setIndex(0);
        break;
      case 'settings':
        navNotifier.setIndex(2);
        break;
      case 'songs':
      default:
        navNotifier.setIndex(1);
    }
  }
}
