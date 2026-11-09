import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/core/utils/dev_log.dart';

class AndroidPlaybackDeviceInfo {
  const AndroidPlaybackDeviceInfo({
    required this.hasUsbDac,
    required this.hasAttachedUac2Device,
    required this.manufacturer,
    required this.model,
    this.routeType,
    this.routeLabel,
    this.hasWiredAudioRoute = false,
    this.physicalOutputType,
    this.physicalOutputId,
    this.physicalOutputConnectionId,
    this.physicalOutputLabel,
  });

  final bool hasUsbDac;
  final bool hasAttachedUac2Device;
  final String manufacturer;
  final String model;
  final String? routeType;
  final String? routeLabel;
  final bool hasWiredAudioRoute;
  final String? physicalOutputType;
  final String? physicalOutputId;
  final String? physicalOutputConnectionId;
  final String? physicalOutputLabel;

  bool get isUsbRoute => routeType == 'usb';
  bool get isInternalRoute => routeType == 'internal';
  bool get isWiredRoute => routeType == 'wired';
  bool get isBluetoothRoute => routeType == 'bluetooth';
  bool get isDockRoute => routeType == 'dock';

  /// True whenever an external output exists, even if Android has not routed
  /// audio to it yet or the app has no USB permission.
  bool get hasPhysicalOutput =>
      hasUsbDac ||
      hasAttachedUac2Device ||
      hasWiredAudioRoute ||
      isUsbRoute ||
      isWiredRoute ||
      isDockRoute;

  /// Stable identity for one physical connection. Repeated AudioDeviceCallback
  /// events for the same output must not re-apply the safety ceiling.
  String? get physicalOutputKey {
    if (!hasPhysicalOutput) return null;
    final kind =
        hasUsbDac ||
            hasAttachedUac2Device ||
            physicalOutputType == 'usb' ||
            isUsbRoute
        ? 'usb'
        : physicalOutputType ?? routeType ?? 'physical';
    final id =
        physicalOutputConnectionId ??
        physicalOutputId ??
        physicalOutputLabel ??
        routeLabel;
    return id == null || id.isEmpty ? kind : '$kind:$id';
  }

  bool get looksLikeUsbAudioRoute {
    final summary = routeSummary.toLowerCase();
    return summary.contains('usb') || summary.contains('dac');
  }

  bool get isLikelyDap {
    final haystack = '${manufacturer.toLowerCase()} ${model.toLowerCase()}';
    const dapKeywords = <String>[
      'fiio',
      'ibasso',
      'hiby',
      'shanling',
      'astell',
      'iriver',
      'cayin',
      'sony',
      'tempotec',
      'luxury',
      'luxuryprecision',
    ];
    return dapKeywords.any(haystack.contains);
  }

  bool get isXiaomiDevice {
    final haystack = '${manufacturer.toLowerCase()} ${model.toLowerCase()}';
    return haystack.contains('xiaomi') ||
        haystack.contains('redmi') ||
        haystack.contains('poco') ||
        haystack.contains('miui');
  }

  String get routeSummary => routeLabel ?? routeType ?? 'unknown';

  factory AndroidPlaybackDeviceInfo.fromMap(Map<Object?, Object?> raw) {
    return AndroidPlaybackDeviceInfo(
      hasUsbDac: raw['hasUsbDac'] == true,
      hasAttachedUac2Device:
          raw['hasAttachedUac2Device'] == true || raw['hasUsbDac'] == true,
      manufacturer: raw['manufacturer'] as String? ?? '',
      model: raw['model'] as String? ?? '',
      routeType: raw['routeType'] as String?,
      routeLabel: raw['routeLabel'] as String?,
      hasWiredAudioRoute: raw['hasWiredAudioRoute'] == true,
      physicalOutputType: raw['physicalOutputType']?.toString(),
      physicalOutputId: raw['physicalOutputId']?.toString(),
      physicalOutputConnectionId: raw['physicalOutputConnectionId']?.toString(),
      physicalOutputLabel: raw['physicalOutputLabel']?.toString(),
    );
  }

  static const unknown = AndroidPlaybackDeviceInfo(
    hasUsbDac: false,
    hasAttachedUac2Device: false,
    manufacturer: '',
    model: '',
  );
}

class AndroidAudioDeviceService {
  AndroidAudioDeviceService._();

  static final AndroidAudioDeviceService instance =
      AndroidAudioDeviceService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mossapps.flick/audio_device',
  );

  final ValueNotifier<AndroidPlaybackDeviceInfo> deviceInfoNotifier =
      ValueNotifier(AndroidPlaybackDeviceInfo.unknown);

  bool _channelConfigured = false;
  Future<void>? _initializeInFlight;
  Future<AndroidPlaybackDeviceInfo>? _refreshInFlight;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    final inFlight = _initializeInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initializeInternal();
    _initializeInFlight = future;
    try {
      await future;
    } finally {
      _initializeInFlight = null;
    }
  }

  Future<AndroidPlaybackDeviceInfo> refresh() async {
    if (!Platform.isAndroid) {
      return AndroidPlaybackDeviceInfo.unknown;
    }

    if (Uac2Service.instance.shouldFreezeAndroidDirectUsbSessionQueries) {
      return deviceInfoNotifier.value;
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshInternal();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (!_channelConfigured) {
      _channelConfigured = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onPlaybackDevicesChanged') {
          devLog('[Engine] Audio device change detected');
          if (Uac2Service.instance.shouldFreezeAndroidDirectUsbSessionQueries) {
            return;
          }
          await refresh();
        }
      });
    }

    await refresh();
  }

  Future<AndroidPlaybackDeviceInfo> _refreshInternal() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'getPlaybackDeviceInfo',
      );
      final info = raw == null
          ? AndroidPlaybackDeviceInfo.unknown
          : AndroidPlaybackDeviceInfo.fromMap(raw);
      deviceInfoNotifier.value = info;
      return info;
    } catch (e) {
      devLog('AndroidAudioDeviceService.refresh failed: $e');
      deviceInfoNotifier.value = AndroidPlaybackDeviceInfo.unknown;
      return AndroidPlaybackDeviceInfo.unknown;
    }
  }
}
