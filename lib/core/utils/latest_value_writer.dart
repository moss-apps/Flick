/// Runs [write] for a value that changes faster than the write completes (a
/// dragged slider driving a USB control transfer): at most one write is in
/// flight, and while it runs a newer value replaces any queued one, so a burst
/// costs one write plus the newest value. The last value submitted is always
/// written.
class LatestValueWriter<T> {
  LatestValueWriter(this._write);

  final Future<void> Function(T value) _write;
  T? _pending;
  bool _hasPending = false;
  T? _inFlight;
  bool _writing = false;
  Future<void>? _drain;

  /// Completes once [value], or a newer value that replaced it, has been
  /// written. If the final write throws, so does this future; an earlier
  /// write's failure is superseded by the write that followed it.
  Future<void> submit(T value) {
    final drain = _drain;
    // Already being written and nothing newer is waiting.
    if (drain != null && _writing && !_hasPending && value == _inFlight) {
      return drain;
    }
    _pending = value;
    _hasPending = true;
    return _drain ??= _run();
  }

  Future<void> _run() async {
    Object? error;
    StackTrace? stack;
    try {
      while (_hasPending) {
        final value = _pending as T;
        _pending = null;
        _hasPending = false;
        _inFlight = value;
        _writing = true;
        try {
          await _write(value);
          error = null;
          stack = null;
        } catch (e, s) {
          error = e;
          stack = s;
        }
      }
    } finally {
      _inFlight = null;
      _writing = false;
      _drain = null;
    }
    if (error != null) Error.throwWithStackTrace(error, stack!);
  }
}
