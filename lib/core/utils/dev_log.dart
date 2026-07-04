import 'package:flutter/foundation.dart';
import 'package:flick/services/uac2_preferences_service.dart';
import 'package:flick/core/utils/app_log.dart';

void devLog(String message) {
  if (!Uac2PreferencesService.isDeveloperModeEnabledSync) return;
  AppLog.instance.add(message, source: LogSource.dart);
  debugPrint(message);
}
