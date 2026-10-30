import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_system_ui.dart';

void main() {
  test('forBackground picks the higher-contrast icon color', () {
    final onDark = AppSystemUi.forBackground(AppColors.background);
    expect(onDark.statusBarIconBrightness, Brightness.light);
    expect(onDark.systemNavigationBarIconBrightness, Brightness.light);
    expect(onDark.systemNavigationBarColor, AppColors.background);

    final onLight = AppSystemUi.forBackground(Colors.white);
    expect(onLight.statusBarIconBrightness, Brightness.dark);
    expect(onLight.systemNavigationBarIconBrightness, Brightness.dark);
    expect(onLight.systemNavigationBarColor, Colors.white);

    // Signal orange is mid-tone: dark icons have the better contrast even
    // though a plain luminance < 0.5 check would call it a dark surface.
    final onSignal = AppSystemUi.forBackground(const Color(0xFFFF5636));
    expect(onSignal.statusBarIconBrightness, Brightness.dark);
    expect(onSignal.systemNavigationBarIconBrightness, Brightness.dark);
  });

  testWidgets('popping a light route restores the shell status bar style', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppSystemUi.standard,
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);

    // A light full-screen route (like an onboarding poster) asks for dark
    // icons while it is on top.
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppSystemUi.forBackground(Colors.white),
          child: const Scaffold(backgroundColor: Colors.white),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);

    // Once it is gone the app-wide fallback must take over again instead of
    // leaving dark icons on Flick's dark shell.
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
  });
}
