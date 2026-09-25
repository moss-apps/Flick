import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:flick/widgets/uac2/usb_bit_perfect_prompt.dart';

Uac2DeviceStatus status({
  Uac2State state = Uac2State.connected,
  Uac2RouteType routeType = Uac2RouteType.externalUsb,
  bool isExternalRoute = false,
}) {
  return Uac2DeviceStatus(
    device: Uac2DeviceInfo(
      vendorId: 1,
      productId: 2,
      productName: 'Test DAC',
      manufacturer: 'Test',
    ),
    state: state,
    routeType: routeType,
    isExternalRoute: isExternalRoute,
  );
}

bool autoEngage(
  Uac2DeviceStatus s, {
  bool bitPerfectEnabled = false,
  bool isochronousEngineSelected = false,
  bool autoEngageEnabled = true,
  bool deviceDeclined = false,
}) {
  return shouldAutoEngageDirectUsb(
    s,
    bitPerfectEnabled: bitPerfectEnabled,
    isochronousEngineSelected: isochronousEngineSelected,
    autoEngageEnabled: autoEngageEnabled,
    deviceDeclined: deviceDeclined,
  );
}

void main() {
  test('auto-engages for external USB route in live states', () {
    expect(autoEngage(status()), isTrue);
    expect(autoEngage(status(state: Uac2State.streaming)), isTrue);
    expect(autoEngage(status(state: Uac2State.prewarming)), isTrue);
  });

  test('no auto-engage when the direct path is already active', () {
    expect(
      autoEngage(
        status(),
        bitPerfectEnabled: true,
        isochronousEngineSelected: true,
      ),
      isFalse,
    );
  });

  test('selects the engine when bit-perfect is on but engine is not', () {
    expect(
      autoEngage(
        status(),
        bitPerfectEnabled: true,
        isochronousEngineSelected: false,
      ),
      isTrue,
    );
  });

  test('honors the master toggle and per-device declines', () {
    expect(autoEngage(status(), autoEngageEnabled: false), isFalse);
    expect(autoEngage(status(), deviceDeclined: true), isFalse);
  });

  test('no auto-engage for internal route or non-live states', () {
    expect(autoEngage(status(routeType: Uac2RouteType.internalDac)), isFalse);
    expect(autoEngage(status(state: Uac2State.idle)), isFalse);
    expect(autoEngage(status(state: Uac2State.error)), isFalse);
    expect(autoEngage(status(state: Uac2State.connecting)), isFalse);
  });

  test('isExternalRoute flag alone qualifies as USB route', () {
    expect(
      autoEngage(
        status(routeType: Uac2RouteType.unknown, isExternalRoute: true),
      ),
      isTrue,
    );
  });

  test('prompt key is stable per device and dedupable', () {
    final a = usbDevicePromptKey(
      Uac2DeviceInfo(
        vendorId: 1,
        productId: 2,
        productName: 'DAC',
        manufacturer: 'M',
        serial: 'S1',
      ),
    );
    final b = usbDevicePromptKey(
      Uac2DeviceInfo(
        vendorId: 1,
        productId: 2,
        productName: 'DAC',
        manufacturer: 'M',
        serial: 'S1',
      ),
    );
    final noSerial = usbDevicePromptKey(
      Uac2DeviceInfo(
        vendorId: 1,
        productId: 2,
        productName: 'DAC',
        manufacturer: 'M',
        deviceName: '/dev/bus/usb/001/002',
      ),
    );
    expect(a, b);
    expect(
      <String>{}
        ..add(a)
        ..add(b),
      {a},
    );
    expect(noSerial, '1:2:/dev/bus/usb/001/002');
  });

  test('auto-engage defaults to enabled and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final service = Uac2PreferencesService();

    expect(await service.getAutoEngageUsbDacEnabled(), isTrue);

    await service.setAutoEngageUsbDacEnabled(false);
    expect(await service.getAutoEngageUsbDacEnabled(), isFalse);
    expect(Uac2PreferencesService.isAutoEngageUsbDacEnabledSync, isFalse);

    await service.clearAllPreferences();
    expect(await service.getAutoEngageUsbDacEnabled(), isTrue);
  });

  test('declined devices persist and can be cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final service = Uac2PreferencesService();

    expect(await service.getDeclinedUsbDevices(), isEmpty);

    await service.addDeclinedUsbDevice('1:2:S1');
    await service.addDeclinedUsbDevice('1:2:S1');
    await service.addDeclinedUsbDevice('3:4:S2');
    expect(await service.getDeclinedUsbDevices(), {'1:2:S1', '3:4:S2'});

    await service.removeDeclinedUsbDevice('1:2:S1');
    expect(await service.getDeclinedUsbDevices(), {'3:4:S2'});

    await service.clearDeclinedUsbDevices();
    expect(await service.getDeclinedUsbDevices(), isEmpty);
  });

  test('legacy prompted devices migrate to declined', () async {
    SharedPreferences.setMockInitialValues({});
    final service = Uac2PreferencesService();

    await service.addPromptedUsbDevice('1:2:S1');
    await service.addPromptedUsbDevice('3:4:S2');
    expect(await service.getDeclinedUsbDevices(), {'1:2:S1', '3:4:S2'});

    // Resetting declines must not let the legacy list re-seed them.
    await service.clearDeclinedUsbDevices();
    expect(await service.getDeclinedUsbDevices(), isEmpty);
  });
}
