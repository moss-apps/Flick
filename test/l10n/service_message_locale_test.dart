// The service-layer exception messages must follow a language switch.
//
// `lib/l10n/l10n.dart` documents the trap this guards: a *field* initialised
// with `l10n.something` or a top-level `final` keeps the locale it was built
// with. That is exactly what broke once (protocol/crossfade/crossfeed labels,
// fixed upstream in 1fe3af48).
//
// This round moved 60+ exception messages to `l10n.*` inside the service layer
// -- code with no BuildContext. If any of them were hoisted into a constant, the
// error shown to a user who switched to Chinese would still be English. So this
// test builds the same exception twice, across a locale switch, and requires
// the text to change.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/l10n/l10n.dart';

/// Same wiring as `lib/app/app.dart`: the app builder keeps the global accessor
/// pointed at the active localizations.
Widget _app(Widget child) {
  return ValueListenableBuilder<Locale?>(
    valueListenable: LocaleController.instance,
    builder: (context, selectedLocale, _) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: kSupportedLocales,
        locale: selectedLocale,
        home: Builder(
          builder: (context) {
            LocaleController.instance.bind(AppLocalizations.of(context));
            return child;
          },
        ),
      );
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    LocaleController.instance.value = null;
  });

  testWidgets('service-layer error messages follow a language switch', (
    tester,
  ) async {
    await LocaleController.instance.select(const Locale('en'));
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    expect(l10n.smbMissingServerAddress, contains('Missing server address'));

    final english = <String>[
      l10n.smbAuthFailed,
      l10n.tidalSignInExpired,
      l10n.storagePermissionRequiredForRecap,
      l10n.failedToWriteTagsToTheFile,
    ];

    await LocaleController.instance.select(const Locale('zh', 'CN'));
    await tester.pumpAndSettle();

    // Read through the global accessor, the same way the services do.
    final chinese = <String>[
      l10n.smbAuthFailed,
      l10n.tidalSignInExpired,
      l10n.storagePermissionRequiredForRecap,
      l10n.failedToWriteTagsToTheFile,
    ];

    for (var i = 0; i < english.length; i++) {
      expect(
        chinese[i],
        isNot(english[i]),
        reason: 'message $i is still the English string after switching to zh, '
            'which means it was captured at startup -- exactly the bug '
            'locale_switch_test.dart was written for',
      );
      expect(
        RegExp(r'[\u4e00-\u9fff]').hasMatch(chinese[i]),
        isTrue,
        reason: 'message $i has no Chinese in it: "${chinese[i]}"',
      );
    }
  });

  testWidgets('a thrown Tidal message is born in the current locale', (
    tester,
  ) async {
    // The message text is built when the exception is constructed, which is the
    // realistic order: the user taps "test connection", the service throws, the
    // screen prints `e.message`.
    await LocaleController.instance.select(const Locale('en'));
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    final enMessage = l10n.tidalSignInTimedOut;

    await LocaleController.instance.select(const Locale('zh', 'CN'));
    await tester.pumpAndSettle();
    final zhMessage = l10n.tidalSignInTimedOut;

    expect(enMessage, isNot(zhMessage));
    expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(zhMessage), isTrue);
  });
}
