import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/player_service.dart';

/// Keeps the thumb on the user's value until the final write is read back.
class VolumeSliderInteraction {
  VolumeSliderInteraction(this._notify);

  final void Function() _notify;
  VolumeSliderAdjustment? _adjustment;
  double? _startValue;
  double? _value;
  ({double value, Future<void> done})? _preview;

  bool get isCurrent => _adjustment?.isCurrent() ?? false;
  double? get value => isCurrent ? _value : null;

  void start(PlayerService player, double value) {
    _adjustment = player.beginVolumeSliderAdjustment();
    _startValue = value;
    _value = null;
    _preview = null;
  }

  void change(double value) {
    final adjustment = _adjustment;
    if (adjustment == null || !adjustment.isCurrent()) return;
    if (_value == null && value == _startValue) return;
    _value = value;
    if (adjustment.live && _preview?.value != value) {
      _preview = (value: value, done: _apply(adjustment, value));
    }
    _notify();
  }

  Future<void> finish(double value) async {
    final adjustment = _adjustment;
    if (adjustment == null) return;
    final preview = _preview;
    if (adjustment.isCurrent() && (_value != null || value != _startValue)) {
      _value = value;
      _notify();
      await (preview?.value == value
          ? preview!.done
          : _apply(adjustment, value));
    }
    if (identical(_adjustment, adjustment)) {
      _adjustment = null;
      _startValue = null;
      _value = null;
      _preview = null;
      _notify();
    }
  }

  Future<void> _apply(VolumeSliderAdjustment adjustment, double value) async {
    try {
      await adjustment.apply(value);
    } catch (error) {
      devLog('Volume slider adjustment failed: $error');
    }
  }
}
