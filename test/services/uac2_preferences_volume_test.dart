import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/services/uac2_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const deviceA = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  serial: 'SERIAL-A',
  deviceName: '/dev/bus/usb/001/002',
);

const deviceB = Uac2DeviceInfo(
  vendorId: 0x1234,
  productId: 0x5678,
  productName: 'Test DAC',
  manufacturer: 'Test Audio',
  serial: 'SERIAL-B',
  deviceName: '/dev/bus/usb/001/003',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to 40 percent for a DAC with no saved level', () async {
    final prefs = Uac2PreferencesService();

    expect(
      await prefs.getUsbVolumeForDevice(deviceA),
      Uac2PreferencesService.defaultUsbDacVolume,
    );
  });

  test('round-trips per-device levels including zero and one', () async {
    final prefs = Uac2PreferencesService();

    await prefs.setUsbVolumeForDevice(deviceA, 0.0);
    await prefs.setUsbVolumeForDevice(deviceB, 1.0);

    expect(await prefs.getUsbVolumeForDevice(deviceA), 0.0);
    expect(await prefs.getUsbVolumeForDevice(deviceB), 1.0);

    await prefs.setUsbVolumeForDevice(deviceA, 0.27);
    expect(await prefs.getUsbVolumeForDevice(deviceA), closeTo(0.27, 1e-9));
    expect(await prefs.getUsbVolumeForDevice(deviceB), 1.0);
  });

  test('path-like serials fall back to the device model', () {
    const androidRouteDevice = Uac2DeviceInfo(
      vendorId: 0x1234,
      productId: 0x5678,
      productName: 'Test DAC',
      manufacturer: 'Test Audio',
      serial: '/dev/bus/usb/001/002',
      deviceName: '/dev/bus/usb/001/002',
    );
    const sameModelWithoutSerial = Uac2DeviceInfo(
      vendorId: 0x1234,
      productId: 0x5678,
      productName: 'Test DAC',
      manufacturer: 'Test Audio',
    );

    expect(
      Uac2PreferencesService.usbDeviceVolumeKey(androidRouteDevice),
      Uac2PreferencesService.usbDeviceVolumeKey(sameModelWithoutSerial),
    );
  });

  test(
    'migrates the legacy global level to only the first DAC',
    () async {
      SharedPreferences.setMockInitialValues({
        'uac2_usb_software_volume': 0.33,
      });
      final prefs = Uac2PreferencesService();

      expect(await prefs.getUsbVolumeForDevice(deviceA), closeTo(0.33, 1e-9));
      expect(
        await prefs.getUsbVolumeForDevice(deviceB),
        Uac2PreferencesService.defaultUsbDacVolume,
      );

      await prefs.setUsbVolumeForDevice(deviceA, 0.55);
      expect(await prefs.getUsbVolumeForDevice(deviceA), closeTo(0.55, 1e-9));
      // The legacy value belonged to the old single global slot, not to some
      // other DAC the user has never connected.
      expect(
        await prefs.getUsbVolumeForDevice(deviceB),
        Uac2PreferencesService.defaultUsbDacVolume,
      );
    },
  );

  test('remembered levels survive a new preferences service', () async {
    await Uac2PreferencesService().setUsbVolumeForDevice(deviceA, 0.27);

    expect(
      await Uac2PreferencesService().getUsbVolumeForDevice(deviceA),
      closeTo(0.27, 1e-9),
    );
  });

  test('ignores non-finite levels instead of saving full volume', () async {
    final prefs = Uac2PreferencesService();
    await prefs.setUsbVolumeForDevice(deviceA, 0.27);

    await prefs.setUsbVolumeForDevice(deviceA, double.nan);
    await prefs.setUsbVolumeForDevice(deviceA, double.infinity);

    expect(await prefs.getUsbVolumeForDevice(deviceA), closeTo(0.27, 1e-9));
  });

  test('invalid persisted levels use the first-use default', () async {
    final key = Uac2PreferencesService.usbDeviceVolumeKey(deviceA);
    SharedPreferences.setMockInitialValues({
      'uac2_usb_device_volumes': '{"$key":1e999}',
    });

    expect(
      await Uac2PreferencesService().getUsbVolumeForDevice(deviceA),
      Uac2PreferencesService.defaultUsbDacVolume,
    );
  });

  test('clearing preferences removes remembered per-device levels', () async {
    final prefs = Uac2PreferencesService();
    await prefs.setUsbVolumeForDevice(deviceA, 0.22);

    await prefs.clearAllPreferences();

    expect(
      await prefs.getUsbVolumeForDevice(deviceA),
      Uac2PreferencesService.defaultUsbDacVolume,
    );
  });

  test('new DAC keeps the first-use hardware and software default', () async {
    final settings = await Uac2PreferencesService().getUsbVolumeSettingsForDevice(deviceA);
    expect(settings.hardware, 0.4);
    expect(settings.software, 0.4);
  });

  test('legacy device percentage never establishes hardware authority', () async {
    final prefs = Uac2PreferencesService();
    await prefs.setUsbVolumeForDevice(deviceA, 0.5);
    final settings = await prefs.getUsbVolumeSettingsForDevice(deviceA);
    expect(settings.hardware, isNull);
    expect(settings.software, 0.5);
    expect((await prefs.getUsbVolumeSettingsForDevice(deviceB)).hardware, 0.4);
  });

  test('global software migration uses the default rather than a hardware percentage', () async {
    SharedPreferences.setMockInitialValues({'uac2_usb_software_volume': 0.33});
    final prefs = Uac2PreferencesService();
    final settings = await prefs.getUsbVolumeSettingsForDevice(deviceA);
    expect(settings.hardware, isNull);
    expect(settings.software, 0.33);
    expect((await prefs.getUsbVolumeSettingsForDevice(deviceB)).hardware, 0.4);
  });

  test('hardware and software levels round-trip independently', () async {
    final prefs = Uac2PreferencesService();
    await prefs.setUsbVolumeForDevice(deviceA, 0.5);
    await prefs.setUsbVolumeForDevice(deviceA, 0.2, authority: UsbVolumeAuthority.hardware);
    await prefs.setUsbVolumeForDevice(deviceA, 0.6, authority: UsbVolumeAuthority.software);
    final settings = await Uac2PreferencesService().getUsbVolumeSettingsForDevice(deviceA);
    expect(settings.hardware, 0.2);
    expect(settings.software, 0.6);
    expect(await prefs.getUsbVolumeForDevice(deviceA), 0.5); // Legacy untouched.
    await prefs.setUsbVolumeForDevice(deviceA, 0.0, authority: UsbVolumeAuthority.hardware);
    await prefs.setUsbVolumeForDevice(deviceB, 1.0, authority: UsbVolumeAuthority.hardware);
    expect((await prefs.getUsbVolumeSettingsForDevice(deviceA)).hardware, 0.0);
    expect((await prefs.getUsbVolumeSettingsForDevice(deviceB)).hardware, 1.0);
  });

  test('software-only records cannot become DAC percentages on reconnect', () async {
    final prefs = Uac2PreferencesService();
    await prefs.setUsbVolumeForDevice(deviceA, 0.3, authority: UsbVolumeAuthority.software);
    final settings = await prefs.getUsbVolumeSettingsForDevice(deviceA);
    expect(settings.hardware, isNull);
    expect(settings.software, 0.3);
  });

  test('corrupt or invalid hardware records fail closed', () async {
    final key = Uac2PreferencesService.usbDeviceVolumeKey(deviceA);
    for (final raw in ['not-json', '{"$key":{"hardware":2.0}}', '{"$key":null}']) {
      SharedPreferences.setMockInitialValues({'uac2_usb_device_volume_authorities': raw});
      expect((await Uac2PreferencesService().getUsbVolumeSettingsForDevice(deviceA)).hardware, isNull);
    }
    SharedPreferences.setMockInitialValues({'uac2_usb_device_volumes': '{"$key":1e999}'});
    expect((await Uac2PreferencesService().getUsbVolumeSettingsForDevice(deviceA)).hardware, isNull);
  });

  test('clearing preferences also removes authority-specific levels', () async {
    final prefs = Uac2PreferencesService();
    await prefs.setUsbVolumeForDevice(deviceA, 0.2, authority: UsbVolumeAuthority.hardware);
    await prefs.clearAllPreferences();
    expect((await prefs.getUsbVolumeSettingsForDevice(deviceA)).hardware, 0.4);
  });
}
