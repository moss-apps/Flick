// The SMB failure banner is the longest string this round introduced, and it is
// rendered inside an `Expanded` next to an icon in a settings card. Chinese is
// shorter than English for this key, so overflow is unlikely -- but "unlikely"
// is not "checked", and this is the one place a long exception message lands in
// a constrained Row.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/l10n/l10n.dart';

const List<double> _widths = <double>[320, 360, 375, 600];
const List<double> _scales = <double>[1.0, 1.5, 2.0, 3.0];

/// Mirrors the failure banner in `network_server_edit_screen.dart`: an icon, a
/// gap, and an `Expanded` Text with bodySmall styling.
Widget _banner(String message) {
  return Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _host(Widget child, Locale locale, double width, double scale) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: kSupportedLocales,
    locale: locale,
    home: Builder(
      builder: (context) {
        LocaleController.instance.bind(AppLocalizations.of(context));
        return MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: child),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('GoogleSansFlex')
          ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Bold.ttf')))
        .load();
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Bold.ttf')))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    LocaleController.instance.value = null;
  });

  testWidgets('zh: the longest error message fits every width and scale', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('zh', 'CN')]) {
      // Every message this round added to a user-facing banner.
      await tester.pumpWidget(_host(
        _banner(lookupAppLocalizations(locale).smbMissingServerAddress),
        locale,
        375,
        1,
      ));
      await tester.pumpAndSettle();

      final all = <String>[
        lookupAppLocalizations(locale).smbMissingServerAddress,
        lookupAppLocalizations(locale).smbMissingShareName,
        lookupAppLocalizations(locale).smbAuthFailed,
        lookupAppLocalizations(locale).smbHostNotResolved,
        lookupAppLocalizations(locale).smbTimedOut,
        lookupAppLocalizations(locale).smbConnectionRefused,
        lookupAppLocalizations(locale).smbCouldNotReach,
        lookupAppLocalizations(locale).smbServerUnresponsive,
        lookupAppLocalizations(locale).smbAccessDenied,
        lookupAppLocalizations(locale).smbShareNotFound,
        lookupAppLocalizations(locale).couldNotReachTheServer,
        lookupAppLocalizations(locale).tidalAppKeyRejected,
      ];

      for (final width in _widths) {
        for (final scale in _scales) {
          for (final message in all) {
            await tester.pumpWidget(_host(
              _banner(message),
              locale,
              width,
              scale,
            ));
            await tester.pump();

            // The message must actually be on screen: an empty tree would pass
            // the overflow check for the wrong reason.
            expect(find.text(message), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'overflowed at locale=$locale width=$width scale=$scale '
                  'message="$message"',
            );
          }
        }
      }
    }
  });
}
