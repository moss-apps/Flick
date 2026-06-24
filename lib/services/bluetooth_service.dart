import 'dart:async';

import 'package:flutter/services.dart';

/// Connected Bluetooth device (from BluetoothA2dp/HEADSET proxies).
class BluetoothDeviceDto {
  const BluetoothDeviceDto({
    required this.address,
    required this.name,
    required this.isA2dp,
  });

  final String address;
  final String name;
  final bool isA2dp;

  factory BluetoothDeviceDto.fromMap(Map<Object?, Object?> m) =>
      BluetoothDeviceDto(
        address: m['address'] as String? ?? '',
        name: m['name'] as String? ?? 'Unknown',
        isA2dp: m['isA2dp'] as bool? ?? false,
      );
}

/// Negotiated codec for a connected A2DP device (API 33+; null below).
class BluetoothCodecStatusDto {
  const BluetoothCodecStatusDto({
    required this.codecName,
    this.sampleRate,
    this.bitsPerSample,
    this.channelMode,
  });

  final String codecName;
  final int? sampleRate;
  final int? bitsPerSample;
  final String? channelMode;

  factory BluetoothCodecStatusDto.fromMap(Map<Object?, Object?> m) =>
      BluetoothCodecStatusDto(
        codecName: m['codecName'] as String? ?? 'Unknown',
        sampleRate: m['sampleRate'] as int?,
        bitsPerSample: m['bitsPerSample'] as int?,
        channelMode: m['channelMode'] as String?,
      );
}

/// A2DP codec source type ids (BluetoothCodecConfig.CODEC_SOURCE_*).
abstract final class BluetoothCodecType {
  static const sbc = 0;
  static const aac = 1;
  static const aptx = 2;
  static const aptxHd = 3;
  static const ldac = 4;
  static const aptxAdaptive = 5;

  static String label(int type) => switch (type) {
        sbc => 'SBC',
        aac => 'AAC',
        aptx => 'aptX',
        aptxHd => 'aptX HD',
        ldac => 'LDAC',
        aptxAdaptive => 'aptX Adaptive',
        _ => 'Codec $type',
      };
}

/// LDAC bitrate preference.
enum BtLdacBitrate { adaptive, kbps330, kbps660, kbps990 }

/// Wraps the native Bluetooth MethodChannel/EventChannel.
///
/// Methods are best-effort: several depend on hidden/system APIs that vary by
/// OEM and Android version. Native side degrades gracefully (returns null /
/// false / empty) on any failure rather than crashing.
class BluetoothService {
  BluetoothService._();
  static final BluetoothService instance = BluetoothService._();

  static const _channel = MethodChannel('com.mossapps.flick/bluetooth');
  static const _events = EventChannel('com.mossapps.flick/bluetooth_events');

  /// Connect/disconnect events: maps with {event, address, name}.
  Stream<Map<Object?, Object?>> get deviceEvents =>
      _events.receiveBroadcastStream().map((e) => Map<Object?, Object?>.from(e as Map));

  Future<List<BluetoothDeviceDto>> getConnectedDevices() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getConnectedDevices');
      if (raw == null) return const [];
      return raw
          .map((e) => BluetoothDeviceDto.fromMap(Map<Object?, Object?>.from(e as Map)))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  Future<BluetoothCodecStatusDto?> getCodecStatus(String address) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCodecStatus',
        {'address': address},
      );
      if (raw == null) return null;
      return BluetoothCodecStatusDto.fromMap(Map<Object?, Object?>.from(raw));
    } on PlatformException {
      return null;
    }
  }

  /// Force a codec for a device. Returns true only if the system call
  /// succeeded; false when the hidden API is unavailable or blocked.
  Future<bool> setCodecConfig({
    required String address,
    required int codecType,
    int sampleRate = 0,
    int bitsPerSample = 0,
    int channelMode = 0,
    int ldacBitrate = 0,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setCodecConfig', {
        'address': address,
        'codecType': codecType,
        'sampleRate': sampleRate,
        'bitsPerSample': bitsPerSample,
        'channelMode': channelMode,
        'ldacBitrate': ldacBitrate,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Battery level 0..100 or null when unreadable.
  Future<int?> getBatteryLevel(String address) async {
    try {
      return await _channel.invokeMethod<int>('getBatteryLevel', {'address': address});
    } on PlatformException {
      return null;
    }
  }

  /// Enable/disable AVRCP absolute volume. Returns false if unsupported.
  Future<bool> setAbsoluteVolumeEnabled(String address, bool enabled) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setAbsoluteVolumeEnabled', {
        'address': address,
        'enabled': enabled,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }
}
