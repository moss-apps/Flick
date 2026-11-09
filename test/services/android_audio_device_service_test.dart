import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/android_audio_device_service.dart';

void main() {
  test('parses wired physical output fields', () {
    final info = AndroidPlaybackDeviceInfo.fromMap({
      'hasUsbDac': false,
      'hasAttachedUac2Device': false,
      'hasWiredAudioRoute': true,
      'hasPhysicalOutput': true,
      'physicalOutputType': 'wired',
      'physicalOutputId': 42,
      'physicalOutputLabel': 'USB-C Earphones',
      'manufacturer': 'Test',
      'model': 'Phone',
      'routeType': 'wired',
      'routeLabel': 'USB-C Earphones',
    });

    expect(info.hasPhysicalOutput, isTrue);
    expect(info.hasWiredAudioRoute, isTrue);
    expect(info.physicalOutputId, '42');
    expect(info.physicalOutputKey, 'wired:42');
  });

  test('USB identity wins over a wired route label', () {
    final info = AndroidPlaybackDeviceInfo.fromMap({
      'hasUsbDac': true,
      'hasAttachedUac2Device': true,
      'hasWiredAudioRoute': true,
      'physicalOutputType': 'usb',
      'physicalOutputId': 'usb-1',
      'manufacturer': 'Test',
      'model': 'Phone',
      'routeType': 'internal',
      'routeLabel': 'Built-in output',
    });

    expect(info.physicalOutputKey, 'usb:usb-1');
  });

  test('no physical output has no guard key', () {
    const info = AndroidPlaybackDeviceInfo(
      hasUsbDac: false,
      hasAttachedUac2Device: false,
      manufacturer: 'Test',
      model: 'Phone',
      routeType: 'internal',
      routeLabel: 'Built-in output',
    );

    expect(info.hasPhysicalOutput, isFalse);
    expect(info.physicalOutputKey, isNull);
  });

  test('USB connection identity does not depend on the managed route id', () {
    const connectionId = '/dev/bus/usb/001/002';
    AndroidPlaybackDeviceInfo info(Object id, String routeType) =>
        AndroidPlaybackDeviceInfo.fromMap({
          'hasUsbDac': true,
          'hasAttachedUac2Device': true,
          'physicalOutputId': id,
          'physicalOutputConnectionId': connectionId,
          'routeType': routeType,
        });

    expect(
      info(connectionId, 'internal').physicalOutputKey,
      'usb:$connectionId',
    );
    expect(info(42, 'usb').physicalOutputKey, 'usb:$connectionId');
  });

  test('attached UAC2 device is a physical output without a route', () {
    final info = AndroidPlaybackDeviceInfo.fromMap({
      'hasUsbDac': true,
      'hasAttachedUac2Device': true,
      'manufacturer': 'Test',
      'model': 'Phone',
      'routeType': 'internal',
      'routeLabel': 'Built-in output',
      'physicalOutputLabel': 'Test DAC',
    });

    expect(info.hasPhysicalOutput, isTrue);
    expect(info.physicalOutputKey, 'usb:Test DAC');
  });
}
