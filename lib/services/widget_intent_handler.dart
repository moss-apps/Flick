import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../providers/player_provider.dart';

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
      if (uri.host == 'player') {
        _handlePlayer(segments.isEmpty ? '' : segments.first);
      } else {
        debugPrint('WidgetIntentHandler: unknown host ${uri.host}');
      }
    } catch (e, st) {
      debugPrint('WidgetIntentHandler dispatch error: $e\n$st');
    }
  }

  void _handlePlayer(String action) {
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
      default:
        debugPrint('WidgetIntentHandler: unknown player action $action');
    }
  }
}
