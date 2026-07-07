import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flick/core/utils/dev_log.dart';

/// Connected Bluetooth device (from BluetoothA2dp/HEADSET proxies).
class BluetoothDeviceDto {
  const BluetoothDeviceDto({
    required this.address,
    required this.name,
    required this.isA2dp,
    this.isConnected = false,
  });

  final String address;
  final String name;
  final bool isA2dp;
  final bool isConnected;

  factory BluetoothDeviceDto.fromMap(Map<Object?, Object?> m) =>
      BluetoothDeviceDto(
        address: m['address'] as String? ?? '',
        name: m['name'] as String? ?? 'Unknown',
        isA2dp: m['isA2dp'] as bool? ?? false,
        isConnected: m['isConnected'] as bool? ?? false,
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
enum BtLdacBitrate {
  adaptive,
  kbps330,
  kbps660,
  kbps990;

  static BtLdacBitrate fromName(String? name) {
    if (name == null) return adaptive;
    return BtLdacBitrate.values.firstWhere(
      (b) => b.name == name,
      orElse: () => BtLdacBitrate.adaptive,
    );
  }

  int get kbps => switch (this) {
        adaptive => 0,
        kbps330 => 330,
        kbps660 => 660,
        kbps990 => 990,
      };
}

/// A2DP sample-rate bitmask values (BluetoothCodecConfig.SAMPLE_RATE_*).
///
/// Stored as a single int preference; callers OR-combine their selection and
/// the native side decodes. 0 = automatic.
abstract final class BtSampleRate {
  static const automatic = 0;
  static const hz44100 = 0x1;
  static const hz88200 = 0x2;
  static const hz48000 = 0x4;
  static const hz96000 = 0x8;
  static const hz176400 = 0x10;
  static const hz192000 = 0x20;

  static const entries = <(int, String)>[
    (automatic, 'Automatic'),
    (hz44100, '44.1 kHz'),
    (hz48000, '48 kHz'),
    (hz88200, '88.2 kHz'),
    (hz96000, '96 kHz'),
    (hz176400, '176.4 kHz'),
    (hz192000, '192 kHz'),
  ];
}

/// A2DP bits-per-sample bitmask values (BluetoothCodecConfig.BITS_PER_SAMPLE_*).
///
/// 0 = automatic.
abstract final class BtBitsPerSample {
  static const automatic = 0;
  static const bit16 = 0x1;
  static const bit24 = 0x2;
  static const bit32 = 0x4;

  static const entries = <(int, String)>[
    (automatic, 'Automatic'),
    (bit16, '16-bit'),
    (bit24, '24-bit'),
    (bit32, '32-bit'),
  ];
}

/// Outcome of a [BluetoothService.setCodecConfig] attempt.
class BtCodecResult {
  const BtCodecResult({
    required this.invokeOk,
    required this.negotiated,
    this.reason,
  });

  /// The hidden system call returned without throwing.
  final bool invokeOk;

  /// After polling, the active codec matches the request.
  final bool negotiated;

  /// Native failure detail when [invokeOk] is false.
  final String? reason;

  /// The request fully succeeded.
  bool get ok => invokeOk && negotiated;
}

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

  /// Paired/bonded devices (BluetoothAdapter.bondedDevices), each flagged
  /// isConnected. Includes currently-connected A2DP devices first.
  Future<List<BluetoothDeviceDto>> getBondedDevices() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getBondedDevices');
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

  /// Outcome of a [setCodecConfig] attempt.
  ///
  /// - [invokeOk]: the hidden system call returned without throwing.
  /// - [negotiated]: after polling, the active codec matches the request.
  ///   When [invokeOk] is true but [negotiated] is false, the hidden API
  ///   silently no-op'd (typical for apps not signed with the platform key).
  /// - [reason]: native failure detail when [invokeOk] is false.
  Future<BtCodecResult> setCodecConfig({
    required String address,
    required int codecType,
    int sampleRate = 0,
    int bitsPerSample = 0,
    int channelMode = 0,
    int ldacBitrate = 0,
  }) async {
    final requestedLabel = BluetoothCodecType.label(codecType);
    devLog('[BT] setCodecConfig: requesting $requestedLabel for $address');
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'setCodecConfig',
        {
          'address': address,
          'codecType': codecType,
          'sampleRate': sampleRate,
          'bitsPerSample': bitsPerSample,
          'channelMode': channelMode,
          'ldacBitrate': ldacBitrate,
        },
      );
      final map =
          raw != null ? Map<Object?, Object?>.from(raw) : <Object?, Object?>{};
      final ok = (map['ok'] as bool?) ?? false;
      final reason = (map['reason'] as String?) ?? 'no reason returned';
      if (!ok) {
        devLog('[BT] setCodecConfig: FAILED — $reason');
        return BtCodecResult(invokeOk: false, negotiated: false, reason: reason);
      }
      // Verify: the hidden @SystemApi often returns true but silently
      // no-ops on apps not signed with the platform key. A2DP codec
      // renegotiation also takes ~1-2s, so poll before declaring a mismatch.
      String? actualName;
      for (var attempt = 0; attempt < 4; attempt++) {
        await Future.delayed(const Duration(milliseconds: 500));
        final actual = await getCodecStatus(address);
        actualName = actual?.codecName ?? 'unknown';
        if (actualName == requestedLabel) break;
      }
      final negotiated = actualName == requestedLabel;
      if (negotiated) {
        devLog('[BT] setCodecConfig: confirmed $requestedLabel active');
      } else {
        devLog(
          '[BT] setCodecConfig: MISMATCH — requested $requestedLabel but '
          'negotiated codec is $actualName after retries (hidden API '
          'likely no-op on this device; use Android Developer Options → '
          'Bluetooth Audio Codec)',
        );
      }
      return BtCodecResult(invokeOk: true, negotiated: negotiated);
    } on PlatformException catch (e) {
      devLog('[BT] setCodecConfig: PlatformException ${e.code}: ${e.message}');
      return BtCodecResult(
        invokeOk: false,
        negotiated: false,
        reason: '${e.code}: ${e.message}',
      );
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

  /// Opens Android Developer Options, where "Bluetooth Audio Codec" lives.
  /// Returns false if Developer Options is disabled/unavailable.
  Future<bool> openBluetoothCodecSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openBluetoothCodecSettings') ??
          false;
    } on PlatformException {
      return false;
    }
  }
}
