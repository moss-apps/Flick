import 'package:flutter/foundation.dart';

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
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => _entries;

  void add(String message, {LogSource source = LogSource.dart}) {
    _entries.add(LogEntry(DateTime.now(), message, source));
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
