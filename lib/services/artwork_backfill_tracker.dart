import 'dart:async';

import 'package:flutter/foundation.dart';

/// Aggregate progress of the post-scan artwork backfill.
class ArtworkBackfillProgress {
  const ArtworkBackfillProgress({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  double get fraction =>
      total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
}

class _ArtworkBackfillEntry {
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Tracks post-scan artwork backfill per folder so the scan session can wait
/// for covers (and show progress) instead of declaring the scan done while
/// tiles are still resolving.
///
/// A folder is scanned by one task at a time, but the same folder can be
/// rescanned while a previous backfill still runs. The opaque [begin] token
/// keeps the stale task's [finish]/[setProgress] calls from disturbing the
/// newer entry — the stale entry is still completed so earlier awaiters are
/// never left hanging.
class ArtworkBackfillTracker {
  final Map<String, _ArtworkBackfillEntry> _entries = {};
  final Map<String, ArtworkBackfillProgress> _perFolder = {};

  /// Aggregated progress across folders; null when no backfill is running.
  final ValueNotifier<ArtworkBackfillProgress?> progress = ValueNotifier(null);

  bool get hasPending => _entries.values.any((entry) => !entry.isCompleted);

  /// Registers a backfill for [folderKey] and returns a token that must be
  /// passed to [finish] and [setProgress].
  Object begin(String folderKey) {
    final entry = _ArtworkBackfillEntry();
    _entries[folderKey] = entry;
    return entry;
  }

  Future<void> awaitFolder(String folderKey) =>
      _entries[folderKey]?.future ?? Future<void>.value();

  Future<void> awaitAll() {
    final pending = _entries.values
        .where((entry) => !entry.isCompleted)
        .map((entry) => entry.future)
        .toList(growable: false);
    if (pending.isEmpty) return Future<void>.value();
    return Future.wait(pending);
  }

  void setProgress(String folderKey, Object token, int completed, int total) {
    if (!identical(_entries[folderKey], token)) return;
    _perFolder[folderKey] = ArtworkBackfillProgress(
      completed: completed,
      total: total,
    );
    _recompute();
  }

  void finish(String folderKey, Object token) {
    if (token is! _ArtworkBackfillEntry) return;
    token.complete();
    if (!identical(_entries[folderKey], token)) return;
    _entries.remove(folderKey);
    _perFolder.remove(folderKey);
    _recompute();
  }

  void _recompute() {
    if (_perFolder.isEmpty) {
      progress.value = null;
      return;
    }
    var completed = 0;
    var total = 0;
    for (final folder in _perFolder.values) {
      completed += folder.completed;
      total += folder.total;
    }
    progress.value = ArtworkBackfillProgress(
      completed: completed,
      total: total,
    );
  }
}
