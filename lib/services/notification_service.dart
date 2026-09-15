import 'package:flutter/services.dart';
import 'package:flick/models/song.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Flutter service to communicate with native Android notification service.
/// Handles media playback notifications with controls.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _channel = MethodChannel('com.mossapps.flick/player');

  bool _isNotificationVisible = false;
  bool get isNotificationVisible => _isNotificationVisible;

  /// Initialize the notification service and set up method call handler
  /// for receiving commands from the notification buttons.
  void init({
    required VoidCallback onTogglePlayPause,
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required VoidCallback onStop,
    required Function(Duration) onSeek,
    required VoidCallback onToggleShuffle,
    required VoidCallback onToggleFavorite,
    VoidCallback? onDisconnectCast,
    Function(double)? onSetCastVolume,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'togglePlayPause':
          onTogglePlayPause();
          break;
        case 'play':
          onPlay();
          break;
        case 'pause':
          onPause();
          break;
        case 'next':
          onNext();
          break;
        case 'previous':
          onPrevious();
          break;
        case 'stop':
          onStop();
          break;
        case 'seek':
          final position = call.arguments['position'] as int?;
          if (position != null) {
            onSeek(Duration(milliseconds: position));
          }
          break;
        case 'toggleShuffle':
          onToggleShuffle();
          break;
        case 'toggleFavorite':
          onToggleFavorite();
          break;
        case 'disconnectCast':
          onDisconnectCast?.call();
          break;
        case 'setCastVolume':
          final volume = (call.arguments['volume'] as num?)?.toDouble();
          if (volume != null) onSetCastVolume?.call(volume);
          break;
      }
    });
  }

  /// Show or update the notification with song information.
  Future<void> showNotification({
    required Song song,
    required bool isPlaying,
    Duration? duration,
    Duration? position,
    bool isShuffle = false,
    bool isFavorite = false,
    int? color,
    bool isCasting = false,
    String? castDeviceName,
    int? castVolumePercent,
  }) async {
    try {
      final args = <String, dynamic>{
        'title': song.title,
        'artist': song.artist,
        'albumArtPath': song.albumArt,
        'isPlaying': isPlaying,
        'duration': duration?.inMilliseconds ?? 0,
        'position': position?.inMilliseconds ?? 0,
        'isShuffle': isShuffle,
        'isFavorite': isFavorite,
        'isCasting': isCasting,
      };
      if (castDeviceName != null) args['castDeviceName'] = castDeviceName;
      if (castVolumePercent != null) {
        args['castVolume'] = castVolumePercent;
      }
      if (color != null) args['color'] = color;
      await _channel.invokeMethod('showNotification', args);
      _isNotificationVisible = true;
    } catch (e) {
      devLog('Failed to show notification: $e');
    }
  }

  /// Update only the playback state (play/pause button) in the notification.
  Future<void> updatePlaybackState({
    required bool isPlaying,
    Duration? position,
  }) async {
    if (!_isNotificationVisible) return;

    try {
      final args = <String, dynamic>{'isPlaying': isPlaying};
      if (position != null) {
        args['position'] = position.inMilliseconds;
      }
      await _channel.invokeMethod('updateNotification', args);
    } catch (e) {
      devLog('Failed to update notification state: $e');
    }
  }

  /// Update the notification with new song metadata or state.
  Future<void> updateNotification({
    required Song song,
    required bool isPlaying,
    Duration? duration,
    Duration? position,
    bool? isShuffle,
    bool? isFavorite,
    int? color,
    bool? isCasting,
    String? castDeviceName,
    int? castVolumePercent,
  }) async {
    try {
      final args = <String, dynamic>{
        'title': song.title,
        'artist': song.artist,
        'albumArtPath': song.albumArt,
        'isPlaying': isPlaying,
        'duration': duration?.inMilliseconds ?? 0,
        'position': position?.inMilliseconds ?? 0,
      };

      if (isShuffle != null) args['isShuffle'] = isShuffle;
      if (isFavorite != null) args['isFavorite'] = isFavorite;
      if (color != null) args['color'] = color;
      if (isCasting != null) {
        args['isCasting'] = isCasting;
        args['castDeviceName'] = castDeviceName;
        if (castVolumePercent != null) args['castVolume'] = castVolumePercent;
      }

      await _channel.invokeMethod('updateNotification', args);
      _isNotificationVisible = true;
    } catch (e) {
      devLog('Failed to update notification: $e');
    }
  }

  /// Lightweight cast-only update: swaps the MediaSession between local and
  /// remote volume without touching metadata (no favorite/color churn while
  /// the volume slider is dragged).
  Future<void> updateCastState({
    required bool isCasting,
    String? castDeviceName,
    int? castVolumePercent,
  }) async {
    if (!_isNotificationVisible) return;
    try {
      final args = <String, dynamic>{
        'isCasting': isCasting,
        'castDeviceName': castDeviceName,
      };
      if (castVolumePercent != null) args['castVolume'] = castVolumePercent;
      await _channel.invokeMethod('updateNotification', args);
    } catch (e) {
      devLog('Failed to update cast state: $e');
    }
  }

  /// Hide the notification and stop the foreground service.
  Future<void> hideNotification() async {
    try {
      await _channel.invokeMethod('hideNotification');
      _isNotificationVisible = false;
    } catch (e) {
      devLog('Failed to hide notification: $e');
    }
  }
}
