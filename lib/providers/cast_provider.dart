import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/casting/cast_device.dart';
import '../services/casting/casting_service.dart';

class CastState {
  final List<CastDevice> devices;
  final CastDevice? activeDevice;
  final bool isActive;
  final bool isDiscovering;

  const CastState({
    this.devices = const [],
    this.activeDevice,
    this.isActive = false,
    this.isDiscovering = false,
  });

  // ponytail: no copyWith — its `activeDevice ?? old` kept a stale device after
  // disconnect. Always build from service notifiers instead.
}

final castServiceProvider = Provider<CastingService>((ref) {
  return CastingService.instance;
});

class CastNotifier extends Notifier<CastState> {
  late final CastingService _service;

  @override
  CastState build() {
    _service = ref.read(castServiceProvider);
    final initial = CastState(
      devices: _service.devicesNotifier.value,
      activeDevice: _service.activeDeviceNotifier.value,
      isActive: _service.isActiveNotifier.value,
      isDiscovering: _service.isDiscoveringNotifier.value,
    );

    void sync() {
      state = CastState(
        devices: _service.devicesNotifier.value,
        activeDevice: _service.activeDeviceNotifier.value,
        isActive: _service.isActiveNotifier.value,
        isDiscovering: _service.isDiscoveringNotifier.value,
      );
    }

    _service.devicesNotifier.addListener(sync);
    _service.activeDeviceNotifier.addListener(sync);
    _service.isActiveNotifier.addListener(sync);
    _service.isDiscoveringNotifier.addListener(sync);

    ref.onDispose(() {
      _service.devicesNotifier.removeListener(sync);
      _service.activeDeviceNotifier.removeListener(sync);
      _service.isActiveNotifier.removeListener(sync);
      _service.isDiscoveringNotifier.removeListener(sync);
    });

    return initial;
  }

  Future<void> discover() => _service.discover();
  Future<void> connect(CastDevice device) => _service.connect(device);
  Future<void> disconnect() => _service.disconnect();
}

final castProvider = NotifierProvider<CastNotifier, CastState>(CastNotifier.new);

final castDevicesProvider = Provider<List<CastDevice>>((ref) {
  return ref.watch(castProvider.select((s) => s.devices));
});

final activeCastDeviceProvider = Provider<CastDevice?>((ref) {
  return ref.watch(castProvider.select((s) => s.activeDevice));
});

final isCastingProvider = Provider<bool>((ref) {
  return ref.watch(castProvider.select((s) => s.isActive));
});

final isCastDiscoveringProvider = Provider<bool>((ref) {
  return ref.watch(castProvider.select((s) => s.isDiscovering));
});
