import 'dart:async';
import 'package:flutter/services.dart';
import 'cast_device.dart';

// ponytail: wraps native Cast SDK via platform channels (bluetooth_service.dart pattern).
// Returns graceful empty/no-op when native side isn't available (e.g. non-Android).
// ignore_for_file: empty_catches
class ChromecastBackend {
  static const _channel = MethodChannel('com.mossapps.flick/cast');
  static const _eventChannel = EventChannel('com.mossapps.flick/cast_events');

  Stream<Map<String, dynamic>>? _events;

  Future<List<CastDevice>> discover() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('discover');
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((m) => CastDevice(
                id: m['id'] as String? ?? '',
                name: m['name'] as String? ?? 'Chromecast',
                backend: CastBackend.chromecast,
              ))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<void> connect(CastDevice device) async {
    try {
      await _channel.invokeMethod<void>('connect', {'id': device.id});
    } on PlatformException {
    } on MissingPluginException {
    }
  }

  Future<void> load(String url, {String? title, String? artist}) async {
    try {
      await _channel.invokeMethod<void>('load', {'url': url, 'title': title, 'artist': artist});
    } on PlatformException {
    } on MissingPluginException {
    }
  }

  Future<void> play() => _invoke('play');
  Future<void> pause() => _invoke('pause');
  Future<void> resume() => _invoke('play');
  Future<void> stop() => _invoke('stop');
  Future<void> seek(Duration position) => _invoke('seek', {'position': position.inMilliseconds});
  Future<void> setVolume(double volume) => _invoke('setVolume', {'volume': volume});

  Future<void> disconnect() => _invoke('disconnect');

  Future<List<Map<String, dynamic>>> getOutputRoutes() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getOutputRoutes');
      if (raw == null) return const [];
      return raw.whereType<Map>().map((m) => (m).cast<String, dynamic>()).toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<bool> selectOutputRoute(String id) async {
    try {
      return await _channel.invokeMethod<bool>('selectOutputRoute', {'id': id}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
    } on MissingPluginException {
    }
  }

  // Native-pushed state updates (position/playing). Optional — CastingService polls DLNA;
  // for Chromecast we rely on this stream when available.
  Stream<Map<String, dynamic>> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((e) => (e as Map).cast<String, dynamic>());
    return _events!;
  }
}
