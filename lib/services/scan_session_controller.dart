import 'package:flutter/foundation.dart';

import 'audio_preload_service.dart';
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

  int _generation = 0;

  bool get isActive => session.value != null;

  /// True when the floating pill should render: a session exists but its
  /// overlay has been dismissed.
  bool get isVisible => session.value != null && minimized.value;

  /// True when [generation] still owns the active session. Stale flows (a
  /// scan that was stopped or replaced) use this to stop touching state.
  bool isCurrent(int generation) =>
      _generation == generation && session.value != null;

  /// Starts a new session, replacing any stale one. Returns a generation id;
  /// pass it to [update]/[end]/[overlayDismissed] so a superseded flow can't
  /// pollute a newer session.
  int begin({
    required String title,
    required ScanSessionKind kind,
    required void Function() onCancel,
  }) {
    final generation = ++_generation;
    session.value = ScanSession(
      title: title,
      kind: kind,
      startedAt: DateTime.now(),
      onCancel: onCancel,
    );
    progress.value = null;
    minimized.value = false;
    // A visible session means the user started work again; lift the sticky
    // auto-preload suppression a previous Stop installed.
    AudioPreloadService.instance.clearAutoSuppression();
    return generation;
  }

  /// Stores the latest progress for [generation]. Ignored when the session is
  /// gone or was replaced, so stragglers can't resurrect the pill.
  void update(int generation, ScanProgress value) {
    if (!isCurrent(generation)) return;
    progress.value = value;
  }

  /// The [generation] overlay was dismissed without the work finishing — keep
  /// reporting via the floating pill.
  void overlayDismissed(int generation) {
    if (!isCurrent(generation)) return;
    minimized.value = true;
  }

  /// Invokes the session's cancel hook. Does not end the session; the owning
  /// flow's completion path calls [end].
  void cancel() => session.value?.onCancel();

  /// Cancels the active work and clears all state immediately. Stop actions
  /// use this so the UI disappears without waiting for the owning flow to
  /// observe the cancel; the flow's later [end] is a no-op.
  void stop() {
    cancel();
    end();
  }

  /// Clears session state. When [generation] is given, a stale flow's end is
  /// ignored and cannot clear a newer session.
  void end([int? generation]) {
    if (generation != null && generation != _generation) return;
    session.value = null;
    progress.value = null;
    minimized.value = false;
  }
}
