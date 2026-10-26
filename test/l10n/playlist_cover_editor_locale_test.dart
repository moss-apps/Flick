import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/playlists/screens/playlist_cover_editor_screen.dart';
import 'package:flick/l10n/l10n.dart';

Widget _host(String sourcePath, Locale locale) => MaterialApp(
  theme: AppTheme.darkTheme,
  locale: locale,
  supportedLocales: kSupportedLocales,
  localizationsDelegates: kAppLocalizationsDelegates,
  localeResolutionCallback: resolveAppLocale,
  builder: (context, child) {
    LocaleController.instance.bind(AppLocalizations.of(context));
    return child!;
  },
  home: PlaylistCoverEditorScreen(sourcePath: sourcePath),
);

Future<void> _waitForText(WidgetTester tester, String text) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('the cover editor did not finish preparing: $text');
}

void _setPhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  late Directory temporaryDirectory;
  late String sourcePath;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'flick_cover_editor_locale_',
    );
    final image = img.Image(width: 16, height: 16);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        image.setPixelRgb(x, y, x * 10, y * 10, 80);
      }
    }
    sourcePath = '${temporaryDirectory.path}/cover.png';
    File(sourcePath).writeAsBytesSync(img.encodePng(image));
  });

  tearDown(() {
    LocaleController.instance.bindLocale(kFallbackLocale);
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('Taglish cover editor is fully English', (tester) async {
    _setPhoneSize(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(_host(sourcePath, kFilipinoLocale));
    expect(find.text(tl.editCover), findsNothing);
    expect(find.text(en.editCover), findsOneWidget);
    await _waitForText(tester, en.crop);

    for (final copy in [en.crop, en.adjust, en.filters, en.reset, en.save]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text(tl.crop), findsNothing);
    expect(find.text(tl.adjust), findsNothing);
    expect(find.text(tl.filters), findsNothing);

    for (final copy in [
      en.rotateLeft,
      en.rotateRight,
      en.flipHorizontal,
      en.flipVertical,
      en.cropCoverHint,
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text(tl.rotateLeft), findsNothing);
    expect(find.text(tl.cropCoverHint), findsNothing);

    await tester.tap(find.text(en.adjust));
    await tester.pump();
    for (final copy in [
      en.brightness,
      en.contrast,
      en.saturation,
      en.warmth,
      en.vignette,
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text(tl.brightness), findsNothing);
    expect(find.text(tl.warmth), findsNothing);

    await tester.tap(find.text(en.filters));
    await tester.pump();
    await _waitForText(tester, en.filterOriginal);
    for (final copy in [en.filterOriginal, en.filterMono, en.filterWarm]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text(tl.filterOriginal), findsNothing);
    expect(find.text(tl.filterWarm), findsNothing);

    await tester.tap(find.text(en.crop));
    await tester.pump();
    await tester.tap(find.text(en.rotateLeft));
    await tester.pump();
    await tester.tap(find.byTooltip(en.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.discardChanges2), findsOneWidget);
    expect(find.text(en.youHaveUnsavedChangesAreYou), findsOneWidget);
    expect(find.text(en.discard), findsOneWidget);
    expect(find.text(en.cancel), findsOneWidget);
    expect(find.text(tl.discardChanges2), findsNothing);
    expect(find.text(tl.discard), findsNothing);
    expect(find.text(tl.cancel), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chinese cover editor keeps its Chinese copy', (tester) async {
    _setPhoneSize(tester);
    const zhLocale = Locale('zh', 'CN');
    final zh = lookupFlickLocalizations(zhLocale);
    await tester.pumpWidget(_host(sourcePath, zhLocale));
    await _waitForText(tester, zh.crop);

    expect(find.text(zh.editCover), findsWidgets);
    expect(find.text('Edit cover'), findsNothing);
    expect(find.text(zh.crop), findsOneWidget);
    expect(find.text(zh.adjust), findsOneWidget);
    expect(find.text(zh.filters), findsOneWidget);
    expect(find.text(zh.reset), findsOneWidget);
    expect(find.text(zh.save), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
