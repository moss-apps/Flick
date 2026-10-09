import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/recently_played_repository.dart';

/// Two print-like color fields, grounded by Flick's ink surfaces.
abstract final class ReplayStyle {
  static const ink = Color(0xFF0A0A0A);
  static const paper = Color(0xFFF1F0EB);
  static const silver = Color(0xFFCBCBC6);
  static const muted = Color(0xFFA4A49F);
  static const surface = Color(0xFF191919);
  static const rule = Color(0xFF333332);
  static const signal = Color(0xFFFF5636);
  static const acid = Color(0xFFE3F369);
  static const onSignal = Color(0xFF351009);
  static const onAcid = Color(0xFF343C0E);

  static Duration duration(BuildContext context, {bool slow = false}) {
    if (MediaQuery.disableAnimationsOf(context) ||
        AppConstants.animationNormal == Duration.zero) {
      return Duration.zero;
    }
    return Duration(milliseconds: slow ? 650 : 300);
  }

  static String range(ListeningRecap recap) {
    final locale = Intl.getCurrentLocale();
    final end = recap.endExclusive.subtract(const Duration(days: 1));
    return switch (recap.period) {
      ListeningRecapPeriod.daily => DateFormat.yMMMd(
        locale,
      ).format(recap.start),
      ListeningRecapPeriod.weekly =>
        '${DateFormat.MMMd(locale).format(recap.start)} – ${DateFormat.yMMMd(locale).format(end)}',
      ListeningRecapPeriod.monthly => DateFormat.yMMMM(
        locale,
      ).format(recap.start),
      ListeningRecapPeriod.yearly => DateFormat.y(locale).format(recap.start),
    };
  }

  static String plays(int count) => count == 1 ? '1 play' : '$count plays';

  static String durationLabel(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${duration.inMinutes}m';
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  static String peakHour(int? hour) {
    if (hour == null) return '—';
    return '${hour % 12 == 0 ? 12 : hour % 12} ${hour >= 12 ? 'PM' : 'AM'}';
  }
}
