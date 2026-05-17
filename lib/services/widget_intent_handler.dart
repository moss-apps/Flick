import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';

class WidgetIntentHandler {
  WidgetIntentHandler(this._ref, {VoidCallback? onOpenQueue})
      : _onOpenQueue = onOpenQueue;

  final WidgetRef _ref;
  final VoidCallback? _onOpenQueue;
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
      } else if (uri.host == 'queue') {
        _onOpenQueue?.call();
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
        unawaited(notifier.togglePlayPause().then((_) => _pushWidgetState()));
        break;
      case 'next':
        unawaited(notifier.next().then((_) => _pushWidgetState()));
        break;
      case 'previous':
        unawaited(notifier.previous().then((_) => _pushWidgetState()));
        break;
      case 'shuffle':
        unawaited(notifier.toggleShuffle().then((_) => _pushWidgetState()));
        break;
      case 'repeat':
        notifier.toggleLoopMode();
        unawaited(_pushWidgetState());
        break;
      default:
        debugPrint('WidgetIntentHandler: unknown player action $action');
    }
  }

  static const _provider = 'com.mossapps.flick.widgets.MiniPlayerWidgetProvider';

  Future<void> _pushWidgetState() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final state = _ref.read(playerProvider);
      final Song? song = state.currentSong;
      await HomeWidget.saveWidgetData('flick_widget_is_playing', state.isPlaying);
      await HomeWidget.saveWidgetData('flick_widget_has_song', song != null);
      if (song != null) {
        await HomeWidget.saveWidgetData('flick_widget_title', song.title);
        await HomeWidget.saveWidgetData('flick_widget_artist', song.artist);
        await HomeWidget.saveWidgetData('flick_widget_album_art', song.albumArt ?? '');
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (e) {
      debugPrint('WidgetIntentHandler: failed to push widget state: $e');
    }
  }
}
