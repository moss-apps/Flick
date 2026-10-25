// Switching the language at runtime has to reach the strings.
//
// `l10n` is a global accessor (see lib/l10n/l10n.dart) because a large share of
// this app's user-visible text lives in services with no BuildContext.
// `LocaleController.bind` re-points it from `MaterialApp.builder` on every
// build. Anything that reads `l10n` while building therefore follows a language
// switch -- but anything that *captures* it (a field initialised with
// `l10n.something`, a top-level `final`) keeps the first locale forever. That is
// exactly what shipped once: protocol, crossfade and crossfeed labels were built
// at startup, so changing the language left them in the old one
// (fixed upstream in 1fe3af48).
//
// This test pins the contract: flip the controller, and both the global accessor
// and the rendered text must change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/l10n/l10n.dart';
import 'package:flick/services/app_preferences_service.dart';

/// The same wiring `lib/app/app.dart` uses: the controller drives `locale`, and
/// the builder keeps the global accessor pointed at the active localizations.
Widget _app() {
  return ValueListenableBuilder<Locale?>(
    valueListenable: LocaleController.instance,
    builder: (context, selectedLocale, _) {
      return MaterialApp(
        localizationsDelegates: kAppLocalizationsDelegates,
        supportedLocales: kSupportedLocales,
        localeResolutionCallback: resolveAppLocale,
        locale: selectedLocale,
        home: Builder(
          builder: (context) {
            LocaleController.instance.bind(AppLocalizations.of(context));
            // Read through the global accessor on purpose: this is what the
            // service layer and the enumerated labels do.
            return Column(
              children: [Text(l10n.flickReplay), Text(l10n.language)],
            );
          },
        ),
      );
    },
  );
}

void main() {
  setUp(() async {
    // `LocaleController.select` persists the choice, so the platform channel has
    // to answer; without this the first await never completes.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocaleController.instance.load();
  });

  tearDown(() {
    // Singleton: leave it following the device locale for the next test.
    LocaleController.instance.value = null;
    LocaleController.instance.bindLocale(kFallbackLocale);
  });

  testWidgets('a language switch reaches the global l10n accessor', (
    tester,
  ) async {
    await LocaleController.instance.select(const Locale('en'));
    await tester.pumpWidget(_app());
    expect(l10n.flickReplay, 'Flick Replay');
    expect(find.text('Flick Replay'), findsOneWidget);

    await LocaleController.instance.select(const Locale('zh', 'CN'));
    await tester.pumpAndSettle();

    expect(
      l10n.flickReplay,
      'Flick 回顾',
      reason:
          'The global accessor still points at the previous locale, so every '
          'string the service layer produces is stale.',
    );
    expect(find.text('Flick 回顾'), findsOneWidget);
    expect(find.text('Flick Replay'), findsNothing);
  });

  testWidgets('a widget reading l10n during build follows the switch', (
    tester,
  ) async {
    // Two switches in a row: a cached value would freeze at the first one.
    await LocaleController.instance.select(const Locale('zh', 'CN'));
    await tester.pumpWidget(_app());
    expect(l10n.flickReplay, 'Flick 回顾');

    await LocaleController.instance.select(const Locale('en'));
    await tester.pumpAndSettle();
    expect(l10n.flickReplay, 'Flick Replay');
    expect(find.text('Flick Replay'), findsOneWidget);
  });

  test(
    'Filipino aliases resolve to the Latin UI, never the script resource',
    () {
      const cases = <(Locale, Locale)>[
        (Locale('en', 'GB'), Locale('en')),
        (Locale('zh', 'TW'), Locale('zh', 'CN')),
        (Locale('tl'), kFilipinoLocale),
        (Locale('tl', 'PH'), kFilipinoLocale),
        (Locale('fil', 'PH'), kFilipinoLocale),
        (
          Locale.fromSubtags(languageCode: 'tl', scriptCode: 'Latn'),
          kFilipinoLocale,
        ),
        (
          Locale.fromSubtags(
            languageCode: 'tl',
            scriptCode: 'Tglg',
            countryCode: 'PH',
          ),
          kFilipinoLocale,
        ),
        (Locale('es'), kFallbackLocale),
      ];
      for (final (requested, expected) in cases) {
        expect(resolveSupportedLocale(requested), expected);
        expect(resolveAppLocale(requested, kSupportedLocales), expected);
      }
      expect(kSupportedLocales, contains(kFilipinoLocale));
      expect(kSupportedLocales, isNot(contains(kBaybayinLocale)));
      expect(LocaleController.instance.baybayinHeadings, isFalse);
    },
  );

  test('language and heading preferences persist independently', () async {
    final controller = LocaleController.instance;
    final preferences = AppPreferencesService();
    expect(controller.baybayinHeadings, isFalse);
    await controller.select(kFilipinoLocale);
    await controller.setBaybayinHeadings(true);
    expect(await preferences.getAppLocale(), 'tl');
    expect(await preferences.getBaybayinHeadings(), isTrue);

    // Simulate startup: forget the in-memory selection, then load preferences.
    controller.value = null;
    await controller.load();
    expect(controller.value, kFilipinoLocale);
    expect(controller.baybayinHeadings, isTrue);
    controller.bindLocale(controller.effectiveLocale);
    expect(l10n.language, 'Wika');

    await controller.select(const Locale('en'));
    await controller.load();
    expect(controller.value, const Locale('en'));
    expect(controller.baybayinHeadings, isTrue);
    await controller.setBaybayinHeadings(false);
    await controller.load();
    expect(controller.baybayinHeadings, isFalse);

    await controller.select(null);
    expect(await preferences.getAppLocale(), 'system');
    controller.value = kFilipinoLocale;
    await controller.load();
    expect(controller.followsSystem, isTrue);
  });

  test(
    'the earlier opt-in Baybayin choice migrates once without re-enabling',
    () async {
      final preferences = AppPreferencesService();
      final controller = LocaleController.instance;
      for (final tag in ['tl_Tglg', 'tl-Tglg-PH', 'TL_tglg_ph']) {
        await preferences.setAppLocale(tag);
        await preferences.setBaybayinHeadings(false);
        await controller.load();
        expect(controller.value, kFilipinoLocale);
        expect(controller.baybayinHeadings, isTrue);
        expect(await preferences.getAppLocale(), 'tl');
        expect(await preferences.getBaybayinHeadings(), isTrue);
        await controller.setBaybayinHeadings(false);
        await controller.load();
        expect(controller.value, kFilipinoLocale);
        expect(controller.baybayinHeadings, isFalse);
      }
    },
  );

  test(
    'stored legacy, script/region and malformed tags resolve safely',
    () async {
      const cases = <String, Locale?>{
        'en': Locale('en'),
        'en_US': Locale('en'),
        'zh_CN': Locale('zh', 'CN'),
        'zh_TW': Locale('zh', 'CN'),
        'tl_Tglg': kFilipinoLocale,
        'tl-Tglg-PH': kFilipinoLocale,
        'TL_tglg_ph': kFilipinoLocale,
        'tl_PH': kFilipinoLocale,
        'tl_Latn_PH': kFilipinoLocale,
        'fil': kFilipinoLocale,
        'tl_Tglg_broken': kFallbackLocale,
        '_Tglg': kFallbackLocale,
        'system': null,
        '': null,
      };
      for (final entry in cases.entries) {
        await AppPreferencesService().setAppLocale(entry.key);
        await AppPreferencesService().setBaybayinHeadings(false);
        await LocaleController.instance.load();
        expect(LocaleController.instance.value, entry.value, reason: entry.key);
      }
    },
  );

  testWidgets('Filipino device locales select Latin Filipino, not Baybayin', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearLocalesTestValue);
    for (final deviceLocale in [
      const Locale('tl'),
      const Locale('tl', 'PH'),
      const Locale('fil', 'PH'),
      const Locale.fromSubtags(languageCode: 'tl', scriptCode: 'Latn'),
      kBaybayinLocale,
    ]) {
      dispatcher.localesTestValue = [deviceLocale];
      LocaleController.instance.value = null;
      LocaleController.instance.bindLocale(
        LocaleController.instance.effectiveLocale,
      );
      expect(l10n.language, 'Wika');
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(l10n.localeName, 'tl');
      expect(find.text('Wika'), findsOneWidget);
      expect(LocaleController.instance.baybayinHeadings, isFalse);
      expect(
        Localizations.localeOf(tester.element(find.text('Wika'))),
        kFilipinoLocale,
      );
    }
  });

  testWidgets(
    'Filipino and its visual switch reach widgets without changing services',
    (tester) async {
      await LocaleController.instance.select(const Locale('en'));
      await tester.pumpWidget(_app());
      await LocaleController.instance.select(kFilipinoLocale);
      await tester.pumpAndSettle();
      expect(l10n.language, 'Wika');
      expect(find.text('Wika'), findsOneWidget);
      await LocaleController.instance.setBaybayinHeadings(true);
      await tester.pumpAndSettle();
      expect(l10n.language, 'Wika');
      expect(l10n.songs14, 'Mga kanta');
      final context = tester.element(find.text('Wika'));
      expect(AppLocalizations.of(context).language, l10n.language);
      expect(
        l10n.songUnit(0),
        'kanta',
        reason: 'The full Filipino baseline uses its own ICU rules.',
      );
      expect(Localizations.localeOf(context), kFilipinoLocale);
      expect(MaterialLocalizations.of(context).cancelButtonLabel, isNotEmpty);
      expect(Directionality.of(context), TextDirection.ltr);

      await LocaleController.instance.select(const Locale('zh', 'CN'));
      await tester.pumpAndSettle();
      expect(l10n.language, '语言');
      expect(find.text('语言'), findsOneWidget);

      await LocaleController.instance.select(const Locale('en'));
      await tester.pumpAndSettle();
      expect(l10n.language, 'Language');
      expect(find.text('Language'), findsOneWidget);
    },
  );
}
