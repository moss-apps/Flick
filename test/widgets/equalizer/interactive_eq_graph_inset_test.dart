import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/widgets/equalizer/interactive_eq_graph.dart';

class _FakeEqNotifier extends EqualizerNotifier {
  @override
  EqualizerState build() => EqualizerState.initial();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('interactive EQ clears the bottom bar and mini-player inset', (
    tester,
  ) async {
    const bottomInset = 180.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [equalizerProvider.overrideWith(_FakeEqNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          locale: kFallbackLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kAppLocalizationsDelegates,
          home: Builder(
            builder: (context) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(bottom: bottomInset),
                  viewPadding: mq.viewPadding.copyWith(bottom: bottomInset),
                ),
                child: const InteractiveEqGraphScreen(mode: EqMode.parametric),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final parametric = lookupFlickLocalizations(kFallbackLocale).parametric;
    final statusBottom = tester.getBottomLeft(find.text(parametric)).dy;
    expect(statusBottom, lessThan(1600 - bottomInset));
  });
}
