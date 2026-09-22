import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogSource { dart, rust, crash, zone, platform }

class LogEntry {
  const LogEntry(this.timestamp, this.message, this.source);

  final DateTime timestamp;
  final String message;
  final LogSource source;
}

class AppLog extends ChangeNotifier {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const int maxEntries = 2000;
  static const int _maxFileBytes = 512 * 1024;
  static const Duration _flushInterval = Duration(seconds: 5);

  final List<LogEntry> _entries = [];
  final List<String> _pendingLines = [];
  File? _logFile;
  bool _persistenceInitialized = false;

  List<LogEntry> get entries => _entries;

  void add(String message, {LogSource source = LogSource.dart}) {
    final entry = LogEntry(DateTime.now(), message, source);
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    if (_persistenceInitialized) {
      _pendingLines.add(jsonEncode({
        't': entry.timestamp.millisecondsSinceEpoch,
        's': source.name,
        'm': message,
      }));
    }
    notifyListeners();
  }

  Future<void> initializePersistence() async {
    if (_persistenceInitialized) return;
    _persistenceInitialized = true;
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(p.join(support.path, 'logs'));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _logFile = File(p.join(directory.path, 'flick_log.jsonl'));
      await _replayPersisted();
      Timer.periodic(
        _flushInterval,
        (_) => unawaited(flushToDisk()),
      );
    } catch (error) {
      debugPrint('AppLog persistence unavailable: $error');
    }
  }

  Future<void> _replayPersisted() async {
    final file = _logFile;
    if (file == null || !await file.exists()) return;
    try {
      final lines = await file.readAsLines();
      final start = math.max(0, lines.length - maxEntries);
      for (final line in lines.sublist(start)) {
        final entry = _decodeEntry(line);
        if (entry != null) {
          _entries.add(entry);
        }
      }
      if (_entries.length > maxEntries) {
        _entries.removeRange(0, _entries.length - maxEntries);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('AppLog replay failed: $error');
    }
  }

  Future<void> flushToDisk() async {
    final file = _logFile;
    if (file == null || _pendingLines.isEmpty) return;
    final lines = List<String>.of(_pendingLines);
    _pendingLines.clear();
    try {
      await file.writeAsString(
        '${lines.join('\n')}\n',
        mode: FileMode.append,
        flush: true,
      );
      if (await file.length() > _maxFileBytes) {
        await _trimFile(file);
      }
    } catch (error) {
      _pendingLines.insertAll(0, lines);
      debugPrint('AppLog flush failed: $error');
    }
  }

  Future<void> _trimFile(File file) async {
    final lines = await file.readAsLines();
    final keep = lines.length > maxEntries
        ? lines.sublist(lines.length - maxEntries)
        : lines;
    await file.writeAsString('${keep.join('\n')}\n', flush: true);
  }

  LogEntry? _decodeEntry(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) return null;
      final timestamp = decoded['t'];
      final message = decoded['m'];
      final sourceName = decoded['s'];
      if (timestamp is! int || message is! String) return null;
      return LogEntry(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
        message,
        LogSource.values.firstWhere(
          (value) => value.name == sourceName,
          orElse: () => LogSource.dart,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void clear() {
    _entries.clear();
    _pendingLines.clear();
    final file = _logFile;
    if (file != null) {
      unawaited(_deleteFile(file));
    }
    notifyListeners();
  }

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('AppLog delete failed: $error');
    }
  }
}
