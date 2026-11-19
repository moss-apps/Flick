// The interactive EQ is an English surface in Taglish. The curve itself is
// numeric, but every label around it has to come from the English copy role.
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

Widget _host(Widget child, {Locale locale = kFilipinoLocale}) => ProviderScope(
  overrides: [equalizerProvider.overrideWith(_FakeEqNotifier.new)],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: locale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    localeResolutionCallback: resolveAppLocale,
    builder: (context, child) {
      LocaleController.instance.bind(AppLocalizations.of(context));
      return child!;
    },
    home: child,
  ),
);

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  EqMode mode, {
  Locale locale = kFilipinoLocale,
}) async {
  _setTallView(tester);
  await tester.pumpWidget(
    _host(InteractiveEqGraphScreen(mode: mode), locale: locale),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('Taglish graphic EQ shows English headings and status', (
    tester,
  ) async {
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await _pumpScreen(tester, EqMode.graphic);

    expect(find.text(en.interactiveEq), findsOneWidget);
    expect(find.text(en.dragBandsUpOrDown), findsOneWidget);
    expect(find.text(en.graphic), findsOneWidget);
    expect(find.text(en.flat), findsOneWidget);

    expect(find.text(tl.interactiveEq), findsNothing);
    expect(find.text(tl.dragBandsUpOrDown), findsNothing);
    expect(find.text(tl.flat), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Taglish parametric EQ shows English headings and status', (
    tester,
  ) async {
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await _pumpScreen(tester, EqMode.parametric);

    expect(find.text(en.interactiveEq), findsOneWidget);
    expect(find.text(en.dragToMovePinchToWiden), findsOneWidget);
    expect(find.text(en.parametric), findsOneWidget);
    expect(find.text(en.bandsActive(10, 10)), findsOneWidget);

    expect(find.text(tl.interactiveEq), findsNothing);
    expect(find.text(tl.dragToMovePinchToWiden), findsNothing);
    expect(find.text(tl.bandsActive(10, 10)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese graphic EQ keeps its localized headings and status', (
    tester,
  ) async {
    final en = lookupFlickLocalizations(kFallbackLocale);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    await _pumpScreen(tester, EqMode.graphic, locale: const Locale('zh', 'CN'));

    expect(find.text(zh.interactiveEq), findsOneWidget);
    expect(find.text(zh.dragBandsUpOrDown), findsOneWidget);
    expect(find.text(zh.graphic), findsOneWidget);
    expect(find.text(zh.flat), findsOneWidget);

    expect(find.text(en.interactiveEq), findsNothing);
    expect(find.text(en.dragBandsUpOrDown), findsNothing);
    expect(find.text(en.flat), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese parametric EQ keeps its localized headings and status', (
    tester,
  ) async {
    final en = lookupFlickLocalizations(kFallbackLocale);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    await _pumpScreen(
      tester,
      EqMode.parametric,
      locale: const Locale('zh', 'CN'),
    );

    expect(find.text(zh.interactiveEq), findsOneWidget);
    expect(find.text(zh.dragToMovePinchToWiden), findsOneWidget);
    expect(find.text(zh.parametric), findsOneWidget);
    expect(find.text(zh.bandsActive(10, 10)), findsOneWidget);

    expect(find.text(en.interactiveEq), findsNothing);
    expect(find.text(en.dragToMovePinchToWiden), findsNothing);
    expect(find.text(en.bandsActive(10, 10)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('parametric Q labels resolve from the caller catalog', () {
    final en = lookupFlickLocalizations(kFallbackLocale);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));

    for (final copy in [en, zh]) {
      expect(ParametricBandType.lowShelf.qLabelFor(copy), copy.slope);
      expect(ParametricBandType.highShelf.qLabelFor(copy), copy.slope);
      for (final type in [
        ParametricBandType.lowPass,
        ParametricBandType.highPass,
        ParametricBandType.bandPass,
        ParametricBandType.notch,
        ParametricBandType.allPass,
      ]) {
        expect(type.qLabelFor(copy), copy.resonance);
      }
      expect(ParametricBandType.peaking.qLabelFor(copy), 'Q');
    }
  });
}
