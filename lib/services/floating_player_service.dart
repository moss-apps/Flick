import 'package:flutter/services.dart';
import 'package:flick/models/song.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Flutter service to communicate with the native Android floating
/// mini-player overlay (WindowManager TYPE_APPLICATION_OVERLAY).
class FloatingPlayerService {
  static final FloatingPlayerService _instance =
      FloatingPlayerService._internal();
  factory FloatingPlayerService() => _instance;
  FloatingPlayerService._internal();

  static const _channel = MethodChannel('com.mossapps.flick/overlay');

  /// Whether the app is allowed to draw over other apps.
  Future<bool> canDrawOverlays() async {
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } catch (e) {
      devLog('canDrawOverlays failed: $e');
      return false;
    }
  }

  /// Launch the system overlay-permission settings screen and resolve with
  /// `true` once permission has been granted.
  Future<bool> requestPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } catch (e) {
      devLog('requestOverlayPermission failed: $e');
      return false;
    }
  }

  /// Show (or update) the floating overlay with the current song metadata.
  Future<void> show({
    required Song song,
    required bool isPlaying,
    Duration? duration,
    Duration? position,
  }) async {
    try {
      final args = <String, dynamic>{
        'title': song.title,
        'artist': song.artist,
        'albumArtPath': song.albumArt,
        'isPlaying': isPlaying,
      };
      if (duration != null) args['duration'] = duration.inMilliseconds;
      if (position != null) args['position'] = position.inMilliseconds;
      await _channel.invokeMethod('showFloatingPlayer', args);
    } catch (e) {
      devLog('Failed to show floating player: $e');
    }
  }

  /// Remove the floating overlay.
  Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideFloatingPlayer');
    } catch (e) {
      devLog('Failed to hide floating player: $e');
    }
  }
}
