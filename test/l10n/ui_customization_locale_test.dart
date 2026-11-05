// UI Customization is an English surface in Taglish. The option labels already
// used the English copy role, but the model descriptions resolved the active
// catalog directly, so these sections fell back to Tagalog.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/ui_customization_settings_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/player_provider.dart';

Widget _host(Widget child, {Locale locale = kFilipinoLocale}) => ProviderScope(
  overrides: [currentSongProvider.overrideWithValue(null)],
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
    home: Scaffold(body: child),
  ),
);

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 3000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('Taglish UI customization options are English', (tester) async {
    _setTallView(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final tl = lookupFlickLocalizations(kFilipinoLocale);
    await tester.pumpWidget(_host(const UiCustomizationSettingsScreen()));
    await tester.pumpAndSettle();

    for (final copy in [
      en.uiCustomization,
      en.trackThumbnails.toUpperCase(),
      en.progressBar.toUpperCase(),
      en.albumColors.toUpperCase(),
    ]) {
      expect(find.text(copy), findsOneWidget);
    }

    for (final copy in [
      en.albumArt,
      en.trackNumber,
      en.numberOnArt,
      en.waveform,
      en.line,
      en.off,
      en.subtle,
      en.moderate,
      en.vibrant,
    ]) {
      expect(find.text(copy), findsWidgets);
    }

    for (final copy in [
      en.showAlbumArtwork,
      en.showTheTrackNumber,
      en.showTheNumberOverBlurredArt,
      en.verticalBarsThatAnimateAcrossThe,
      en.cleanStraightLineWithPrecisionScrubbing,
      en.useTheDefaultMonochromeTheme,
      en.faintHueShiftFromAlbumArt,
      en.noticeableTintingFromAlbumArt,
      en.boldSaturatedColorsFromAlbumArt,
    ]) {
      expect(find.text(copy), findsOneWidget);
    }

    for (final copy in [
      tl.albumArt,
      tl.trackNumber,
      tl.numberOnArt,
      tl.line,
      tl.off,
      tl.subtle,
      tl.moderate,
      tl.vibrant,
      tl.showAlbumArtwork,
      tl.showTheTrackNumber,
      tl.showTheNumberOverBlurredArt,
      tl.verticalBarsThatAnimateAcrossThe,
      tl.cleanStraightLineWithPrecisionScrubbing,
      tl.useTheDefaultMonochromeTheme,
      tl.faintHueShiftFromAlbumArt,
      tl.noticeableTintingFromAlbumArt,
      tl.boldSaturatedColorsFromAlbumArt,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Chinese UI customization options stay Chinese', (tester) async {
    _setTallView(tester);
    final en = lookupFlickLocalizations(kFallbackLocale);
    final zh = lookupFlickLocalizations(const Locale('zh', 'CN'));
    await tester.pumpWidget(
      _host(
        const UiCustomizationSettingsScreen(),
        locale: const Locale('zh', 'CN'),
      ),
    );
    await tester.pumpAndSettle();

    for (final copy in [
      zh.uiCustomization,
      zh.trackThumbnails.toUpperCase(),
      zh.progressBar.toUpperCase(),
      zh.albumColors.toUpperCase(),
      zh.albumArt,
      zh.trackNumber,
      zh.numberOnArt,
      zh.waveform,
      zh.line,
      zh.off,
      zh.subtle,
      zh.moderate,
      zh.vibrant,
      zh.showAlbumArtwork,
      zh.showTheTrackNumber,
      zh.showTheNumberOverBlurredArt,
      zh.verticalBarsThatAnimateAcrossThe,
      zh.cleanStraightLineWithPrecisionScrubbing,
      zh.useTheDefaultMonochromeTheme,
      zh.faintHueShiftFromAlbumArt,
      zh.noticeableTintingFromAlbumArt,
      zh.boldSaturatedColorsFromAlbumArt,
    ]) {
      expect(find.text(copy), findsWidgets);
    }

    for (final copy in [
      en.showAlbumArtwork,
      en.showTheTrackNumber,
      en.showTheNumberOverBlurredArt,
      en.verticalBarsThatAnimateAcrossThe,
      en.cleanStraightLineWithPrecisionScrubbing,
      en.useTheDefaultMonochromeTheme,
      en.faintHueShiftFromAlbumArt,
      en.noticeableTintingFromAlbumArt,
      en.boldSaturatedColorsFromAlbumArt,
    ]) {
      expect(find.text(copy), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
