import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/utils/frame_timings_monitor.dart';
import 'package:flick/services/uac2_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FrameTimingsMonitor.instance.stop();
    Uac2PreferencesService.developerModeNotifier.value = false;
  });

  tearDown(() {
    FrameTimingsMonitor.instance.stop();
    Uac2PreferencesService.developerModeNotifier.value = false;
  });

  test('does not collect frame timings while developer mode is off', () {
    FrameTimingsMonitor.instance.start();

    expect(FrameTimingsMonitor.instance.isCollecting, isFalse);
  });

  test('starts and stops collection as developer mode changes', () {
    FrameTimingsMonitor.instance.start();
    Uac2PreferencesService.developerModeNotifier.value = true;

    expect(FrameTimingsMonitor.instance.isCollecting, isTrue);

    Uac2PreferencesService.developerModeNotifier.value = false;

    expect(FrameTimingsMonitor.instance.isCollecting, isFalse);
  });

  test('clears pending timings when developer mode is disabled', () {
    Uac2PreferencesService.developerModeNotifier.value = true;
    FrameTimingsMonitor.instance.start();
    FrameTimingsMonitor.instance.recordTimingsForTesting([_frameTiming()]);

    expect(FrameTimingsMonitor.instance.pendingTimingsCount, 1);

    Uac2PreferencesService.developerModeNotifier.value = false;

    expect(FrameTimingsMonitor.instance.pendingTimingsCount, 0);
  });

  test('resumes collection when developer mode is re-enabled', () {
    FrameTimingsMonitor.instance.start();
    Uac2PreferencesService.developerModeNotifier.value = true;
    Uac2PreferencesService.developerModeNotifier.value = false;
    Uac2PreferencesService.developerModeNotifier.value = true;

    expect(FrameTimingsMonitor.instance.isCollecting, isTrue);
  });

  test('stop stops following developer mode', () {
    FrameTimingsMonitor.instance.start();
    FrameTimingsMonitor.instance.stop();

    Uac2PreferencesService.developerModeNotifier.value = true;

    expect(FrameTimingsMonitor.instance.isCollecting, isFalse);
  });
}

FrameTiming _frameTiming() => FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: 1000,
  rasterStart: 1000,
  rasterFinish: 2000,
  rasterFinishWallTime: 2000,
);
