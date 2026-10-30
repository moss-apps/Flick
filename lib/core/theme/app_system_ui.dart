import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flick/core/theme/app_colors.dart';

/// System-bar chrome shared by the app shell and full-screen routes.
///
/// These are applied through [AnnotatedRegion] instead of a one-off
/// [SystemChrome] call: the imperative style survives route changes, so a
/// route that requested dark icons over a light surface would leave them dark
/// after it is popped. Annotated regions are resolved from the painted tree
/// every frame, and the app-wide region in [MaterialApp.builder] is the
/// fallback whenever the current route does not declare its own style.
abstract final class AppSystemUi {
  /// Luminance where black icons start having more contrast than white.
  static const double _darkIconLuminanceThreshold = 0.179;

  /// Chrome for Flick's standard dark surfaces.
  static const SystemUiOverlayStyle standard = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Chrome whose icon brightness follows [background].
  static SystemUiOverlayStyle forBackground(Color background) {
    // Pick whichever icon color has more contrast, not simply whether the
    // background is "dark" at luminance 0.5. Mid-tone surfaces such as the
    // signal-orange onboarding poster read better with dark icons.
    final useDarkIcons =
        background.computeLuminance() > _darkIconLuminanceThreshold;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: useDarkIcons
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness: useDarkIcons
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}
