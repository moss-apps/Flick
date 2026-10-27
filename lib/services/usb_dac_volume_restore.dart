import 'dart:async';

/// A safety refusal, not a reason to auto-start on a different audio output.
class UsbDacVolumeRestoreError extends StateError {
  UsbDacVolumeRestoreError([String reason = ''])
    : super(
        'Failed to restore USB DAC hardware volume before playback'
        '${reason.isEmpty ? '' : ': $reason'}',
      );
}

/// Restores once per DAC/volume authority, coalescing concurrent handoffs.
/// A detach or authority change invalidates work waiting on permission or prefs.
class UsbDacVolumeRestore {
  int _generation = 0;
  int _connectionGeneration = 0;
  String? _key;
  bool _restored = false;
  Future<void>? _inFlight;

  int get connectionGeneration => _connectionGeneration;

  /// Shared by device activation and enabling bit-perfect on an active DAC.
  /// Completion is the barrier before software gain may be released.
  Future<void> restoreHardwareVolume(
    String key, {
    required Future<double> Function() loadVolume,
    required Future<bool> Function(double volume) writeVolume,
  }) => runOnce(key, (ensureCurrent) async {
    try {
      final volume = await loadVolume();
      ensureCurrent();
      if (!volume.isFinite ||
          volume < 0.0 ||
          volume > 1.0 ||
          !await writeVolume(volume)) {
        throw UsbDacVolumeRestoreError();
      }
      ensureCurrent();
    } on UsbDacVolumeRestoreError {
      rethrow;
    } catch (error) {
      throw UsbDacVolumeRestoreError(error.toString());
    }
  });

  void reset() {
    _connectionGeneration++;
    _clear();
  }

  void _clear() {
    _generation++;
    _key = null;
    _restored = false;
    _inFlight = null;
  }

  Future<void> runOnce(
    String key,
    Future<void> Function(void Function() ensureCurrent) restore,
  ) {
    if (_key != key) {
      _clear();
      _key = key;
    }
    if (_restored) return Future<void>.value();
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final generation = _generation;
    void ensureCurrent() {
      if (generation != _generation) {
        throw UsbDacVolumeRestoreError('route changed');
      }
    }

    final completer = Completer<void>();
    _inFlight = completer.future;
    () async {
      try {
        await restore(ensureCurrent);
        ensureCurrent();
        _restored = true;
        completer.complete();
      } catch (error, stack) {
        // A failed write is never cached: the next playback attempt retries it.
        completer.completeError(error, stack);
      } finally {
        if (generation == _generation) _inFlight = null;
      }
    }();
    return completer.future;
  }
}
