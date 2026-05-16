import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/nav_bar_config.dart';
import '../providers/player_provider.dart';
import '../providers/navigation_provider.dart';

class WidgetIntentHandler {
  WidgetIntentHandler(this._ref);

  final WidgetRef _ref;
  MethodChannel? _channel;

  Future<void> attach() async {
    await detach();

    _channel = const MethodChannel('com.mossapps.flick/widget');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'dispatch') {
        final uriStr = call.arguments as String?;
        if (uriStr != null) {
          final uri = Uri.tryParse(uriStr);
          if (uri != null) _dispatch(uri);
        }
      }
    });

    final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (launchUri != null) {
      _dispatch(launchUri);
    }
  }

  Future<void> detach() async {
    _channel?.setMethodCallHandler(null);
    _channel = null;
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
    final navNotifier = _ref.read(navigationIndexProvider.notifier);
    final targetIndex = switch (section) {
      'songs' => NavBarButton.songs.pageIndex,
      'albums' => NavBarButton.albums.pageIndex,
      'artists' => NavBarButton.artists.pageIndex,
      'playlists' => NavBarButton.playlists.pageIndex,
      'favorites' => NavBarButton.favorites.pageIndex,
      'folders' => NavBarButton.folders.pageIndex,
      'settings' => NavBarButton.settings.pageIndex,
      'menu' => NavBarButton.menu.pageIndex,
      _ => NavBarButton.songs.pageIndex,
    };
    navNotifier.setIndex(targetIndex);
  }
}
