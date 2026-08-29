import 'package:flutter/foundation.dart';

import 'library_scanner_service.dart' show ScanProgress;

/// What kind of work a live session represents.
enum ScanSessionKind { scan, preload, replayGain }

/// Immutable snapshot of a user-visible scan/preload/ReplayGain session.
class ScanSession {
  final String title;
  final ScanSessionKind kind;
  final DateTime startedAt;
  final void Function() onCancel;

  const ScanSession({
    required this.title,
    this.kind = ScanSessionKind.scan,
    required this.startedAt,
    required this.onCancel,
  });
}

/// App-level state for the single user-visible scan session, shared between
/// the full-screen scanning overlay (library settings screen) and the
/// floating progress pill (main shell). Exactly one session exists at a
/// time; the overlay shows it full-screen until minimized, after which the
/// pill keeps reporting progress until the owning flow calls [end].
///
/// Silent background work (auto library sync, post-scan auto preload) never
/// touches this controller — the pill listens to
/// [AudioPreloadService.instance.progress] directly for that.
class ScanSessionController {
  static final ScanSessionController instance = ScanSessionController._();

  ScanSessionController._();

  final ValueNotifier<ScanSession?> session = ValueNotifier(null);
  final ValueNotifier<ScanProgress?> progress = ValueNotifier(null);
  final ValueNotifier<bool> minimized = ValueNotifier(false);

  bool get isActive => session.value != null;

  /// True when the floating pill should render: a session exists but its
  /// overlay has been dismissed.
  bool get isVisible => session.value != null && minimized.value;

  /// Starts a new session, replacing any stale one.
  void begin({
    required String title,
    required ScanSessionKind kind,
    required void Function() onCancel,
  }) {
    session.value = ScanSession(
      title: title,
      kind: kind,
      startedAt: DateTime.now(),
      onCancel: onCancel,
    );
    progress.value = null;
    minimized.value = false;
  }

  /// Stores the latest progress. Ignored when no session is active so a
  /// straggler update from a finished flow can't resurrect the pill.
  void update(ScanProgress value) {
    if (session.value == null) return;
    progress.value = value;
  }

  /// The overlay was dismissed without the work finishing — keep reporting
  /// via the floating pill.
  void overlayDismissed() {
    if (session.value != null) minimized.value = true;
  }

  /// Invokes the session's cancel hook. Does not end the session; the owning
  /// flow's completion path calls [end].
  void cancel() => session.value?.onCancel();

  /// Clears all session state. Called by the owning flow when the work
  /// finishes, is cancelled, or fails.
  void end() {
    session.value = null;
    progress.value = null;
    minimized.value = false;
  }
}
