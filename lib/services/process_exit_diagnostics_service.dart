import 'dart:io';

import 'package:flick/core/utils/app_log.dart';
import 'package:flick/core/utils/dev_log.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProcessExitDiagnosticsService {
  static const _channel = MethodChannel('com.mossapps.flick/diagnostics');
  static const _lastSeenKey = 'diagnostics.last_process_exit_timestamp';

  Future<void> reportPreviousExits() async {
    if (!Platform.isAndroid) return;
    try {
      final exits =
          await _channel.invokeListMethod<Object?>('getProcessExitInfo');
      if (exits == null || exits.isEmpty) return;

      final preferences = await SharedPreferences.getInstance();
      final lastSeen = preferences.getInt(_lastSeenKey) ?? 0;
      var newest = lastSeen;

      for (final raw in exits) {
        if (raw is! Map) continue;
        final info = raw.cast<String, Object?>();
        final timestamp = (info['timestamp'] as num?)?.toInt() ?? 0;
        if (timestamp <= lastSeen) continue;
        AppLog.instance.add(_describe(info), source: LogSource.crash);
        final trace = info['trace'];
        if (trace is String && trace.isNotEmpty) {
          AppLog.instance.add(
            '[native-exit-trace] $trace',
            source: LogSource.crash,
          );
        }
        if (timestamp > newest) newest = timestamp;
      }

      if (newest > lastSeen) {
        await preferences.setInt(_lastSeenKey, newest);
      }
    } catch (error) {
      devLog('Process exit diagnostics failed: $error');
    }
  }

  String _describe(Map<String, Object?> info) {
    final timestamp = (info['timestamp'] as num?)?.toInt() ?? 0;
    final reason = (info['reason'] as num?)?.toInt() ?? 0;
    final parts = <String>[
      'previous run ended: ${_reasonLabel(reason)} (reason $reason)',
      if (timestamp > 0)
        'at ${DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()}',
      'importance ${info['importance'] ?? '?'}',
      'pid ${info['pid'] ?? '?'}',
      'pss ${info['pss'] ?? '?'}kB',
      'rss ${info['rss'] ?? '?'}kB',
      'status ${info['status'] ?? '?'}',
    ];
    final description = info['description'];
    if (description is String && description.isNotEmpty) {
      parts.add(description);
    }
    return '[native-exit] ${parts.join(' ')}';
  }

  String _reasonLabel(int reason) => switch (reason) {
        1 => 'exit self',
        2 => 'signal',
        3 => 'low memory',
        4 => 'crash',
        5 => 'native crash',
        6 => 'anr',
        7 => 'initialization failure',
        8 => 'permission change',
        9 => 'excessive resource usage',
        10 => 'user requested',
        11 => 'user stopped',
        12 => 'dependency died',
        13 => 'other',
        _ => 'unknown',
      };
}
