import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/onboarding/screens/onboarding_screen.dart';

Future<void> _pumpOnboarding(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: OnboardingScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  testWidgets('Next advances to the following page', (tester) async {
    AppConstants.setAnimationsEnabled(true);
    await _pumpOnboarding(tester);

    expect(find.text('Welcome to\nFlick Player'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Build Your\nLibrary'), findsOneWidget);
  });

  testWidgets('Next advances when animations are disabled', (tester) async {
    AppConstants.setAnimationsEnabled(false);
    await _pumpOnboarding(tester);

    expect(find.text('Welcome to\nFlick Player'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Build Your\nLibrary'), findsOneWidget);
  });
}
