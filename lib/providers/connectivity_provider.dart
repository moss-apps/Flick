import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network interface available.
///
/// [unknown] only exists before the first check completes, so widgets can
/// avoid flashing an "offline" notice during cold start.
enum ConnectivityStatus { unknown, online, offline }

/// The [Connectivity] client used by [ConnectivityNotifier].
///
/// Overridable in tests with a fake implementation.
final connectivityClientProvider = Provider<Connectivity>(
  (ref) => Connectivity(),
);

/// Shared connectivity state for the whole app.
///
/// Tracks interface availability reported by the platform, not real internet
/// reachability, so wording in the UI should stay conservative.
final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
      ConnectivityNotifier.new,
    );

class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  static const Duration offlineDebounce = Duration(milliseconds: 600);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineTimer;
  bool _initialized = false;

  @override
  ConnectivityStatus build() {
    if (!_initialized) {
      _initialized = true;
      final connectivity = ref.read(connectivityClientProvider);
      ref.onDispose(() {
        _offlineTimer?.cancel();
        _subscription?.cancel();
      });
      _subscription = connectivity.onConnectivityChanged.listen(
        _onResults,
        onError: (_) {},
      );
      Future<void>.microtask(() => unawaited(refresh()));
    }
    return ConnectivityStatus.unknown;
  }

  /// Runs an explicit platform check and applies the result immediately.
  ///
  /// Returns the resolved online state. Falls back to the last known state
  /// when the platform call fails.
  Future<bool> refresh() async {
    try {
      final results = await ref
          .read(connectivityClientProvider)
          .checkConnectivity();
      final isOnline = _isOnline(results);
      _apply(isOnline, immediate: true);
      return isOnline;
    } catch (_) {
      return state == ConnectivityStatus.online;
    }
  }

  void _onResults(List<ConnectivityResult> results) {
    _apply(_isOnline(results));
  }

  void _apply(bool isOnline, {bool immediate = false}) {
    if (isOnline) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (state != ConnectivityStatus.online) {
        state = ConnectivityStatus.online;
      }
      return;
    }

    if (immediate) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (state != ConnectivityStatus.offline) {
        state = ConnectivityStatus.offline;
      }
      return;
    }

    // Debounce offline transitions so brief drops while switching networks
    // don't flash the notice.
    if (state == ConnectivityStatus.offline) {
      return;
    }
    _offlineTimer?.cancel();
    _offlineTimer = Timer(offlineDebounce, () {
      _offlineTimer = null;
      if (state != ConnectivityStatus.offline) {
        state = ConnectivityStatus.offline;
      }
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
