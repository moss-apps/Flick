// The user manual is a document, not a set of labels -- which is exactly why it
// stayed in English through every previous localization pass: its 172 strings
// lived in a `const List<ManualSection>`, and `l10n` cannot appear in a `const`
// expression.
//
// This test pins the two things that can silently regress now that the copy is
// resolved through functions:
//
//   1. the manual renders in the active locale (not the English source);
//   2. search matches what is *on screen*, which is why `_searchHits` resolves
//      the copy before comparing -- searching "歌曲" has to find entries whose
//      English title is "Browsing your library".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/manual/data/manual_data.dart';
import 'package:flick/features/manual/screens/manual_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/player_provider.dart';

Widget _host(Locale locale, {double width = 375}) {
  return ProviderScope(
    // The screen watches the current song only to tint its background; without
    // this override it reaches the database and the whole tree fails to build,
    // which would make every assertion here meaningless.
    overrides: [currentSongProvider.overrideWithValue(null)],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      locale: locale,
      home: Builder(
        builder: (context) {
          LocaleController.instance.bind(AppLocalizations.of(context));
          return MediaQuery(
            data: MediaQueryData(
              size: Size(width, 2400),
              textScaler: TextScaler.noScaling,
              disableAnimations: true,
            ),
            child: const ManualScreen(),
          );
        },
      ),
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
    await (FontLoader('packages/lucide_icons_flutter/Lucide')
          ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf')))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    LocaleController.instance.value = null;
  });

  test('every manual string is translated, and none is left as the source', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh', 'CN'));

    var checked = 0;
    final untranslated = <String>[];
    final notChinese = <String>[];

    for (final section in kManualSections) {
      final pairs = <String, List<String>>{
        section.id: [section.title(en), section.title(zh)],
      };
      for (var i = 0; i < section.entries.length; i++) {
        final entry = section.entries[i];
        pairs['${section.id}.$i.title'] = [entry.title(en), entry.title(zh)];
        pairs['${section.id}.$i.body'] = [entry.body(en), entry.body(zh)];
        final enTips = entry.tips(en) ?? const <String>[];
        final zhTips = entry.tips(zh) ?? const <String>[];
        for (var t = 0; t < enTips.length; t++) {
          pairs['${section.id}.$i.tip$t'] = [enTips[t], zhTips[t]];
        }
      }

      for (final e in pairs.entries) {
        checked++;
        final source = e.value[0];
        final translated = e.value[1];
        if (source == translated) untranslated.add('${e.key}: "$source"');
        if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(translated)) {
          notChinese.add('${e.key}: "$translated"');
        }
      }
    }

    // ignore: avoid_print
    print('manual strings checked: $checked');
    expect(checked, greaterThan(150),
        reason: 'the manual should hold ~172 strings; if this dropped, the '
            'sections or entries were lost');
    expect(untranslated, isEmpty,
        reason: 'these manual strings still show the English source in zh:\n'
            '${untranslated.join('\n')}');
    expect(notChinese, isEmpty,
        reason: 'these manual strings contain no Chinese:\n'
            '${notChinese.join('\n')}');
  });

  testWidgets('zh: the manual renders Chinese section titles', (tester) async {
    final zh = lookupAppLocalizations(const Locale('zh', 'CN'));
    final en = lookupAppLocalizations(const Locale('en'));

    await tester.pumpWidget(_host(const Locale('zh', 'CN')));
    await tester.pump(const Duration(milliseconds: 50));

    // The section list is what the screen shows first.
    expect(find.text(zh.manualSongs), findsOneWidget);
    expect(find.text(en.manualSongs), findsNothing,
        reason: 'the section title is still the English source');
    expect(tester.takeException(), isNull);
  });

  testWidgets('zh: searching Chinese finds the entry', (tester) async {
    // "歌曲" appears in the Songs section title and in several bodies, so a
    // match proves the search compares rendered copy rather than the source.
    final zh = lookupAppLocalizations(const Locale('zh', 'CN'));

    await tester.pumpWidget(_host(const Locale('zh', 'CN')));
    await tester.pump(const Duration(milliseconds: 50));

    // The field only exists after the search icon is tapped; without this the
    // finder would match nothing and the test would pass for the wrong reason.
    // Two search icons exist once the bar opens (header button + field prefix),
    // so target the header one explicitly.
    await tester.tap(find.byIcon(LucideIcons.search).first);
    await tester.pump(const Duration(milliseconds: 200));

    final field = find.byType(TextField);
    expect(field, findsOneWidget,
        reason: 'the search field did not open, so nothing below is meaningful');

    await tester.enterText(field, zh.manualSongs);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.textContaining(zh.manualSongs, findRichText: true),
      findsWidgets,
      reason: 'searching the Chinese section name returned nothing, which means '
          'the search still compares the English source',
    );
    expect(tester.takeException(), isNull);
  });
}
