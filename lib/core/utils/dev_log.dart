import 'package:flutter/foundation.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/core/utils/app_log.dart';

void devLog(String message) {
  // Terminal output is a developer surface (visible via `flutter run`,
  // `flutter run --release`, or logcat) — always print so logs can be
  // copy-pasted without first enabling developer mode.
  debugPrint(message);
  // The in-app log viewer is a user-facing surface: keep it gated.
  if (!Uac2PreferencesService.isDeveloperModeEnabledSync) return;
  AppLog.instance.add(message, source: LogSource.dart);
}
