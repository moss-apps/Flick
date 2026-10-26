// Copy-role widgets read the global localization getter, so these tests bind
// Taglish exactly as MaterialApp.builder does in production.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/player/widgets/audio_signal_report.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/detail_header.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = kFilipinoLocale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
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
}

void main() {
  testWidgets('detail More sheet is English under Taglish', (tester) async {
    addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
    await _pump(
      tester,
      DetailMoreSheet(
        items: [
          DetailMoreSheetItem(
            icon: LucideIcons.imagePlus,
            label: 'Change cover',
            onTap: () {},
          ),
        ],
      ),
    );

    expect(find.text('MORE'), findsOneWidget);
    expect(find.text('HIGIT PA'), findsNothing);
    expect(find.text('Change cover'), findsOneWidget);
  });

  testWidgets('audio signal report is English under Taglish', (tester) async {
    addTearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));
    final taglish = lookupFlickLocalizations(kFilipinoLocale);
    final english = lookupFlickLocalizations(kFallbackLocale);
    final song = Song(
      id: 'signal',
      title: 'Signal',
      artist: 'Flick',
      duration: const Duration(minutes: 3),
      fileType: 'FLAC',
      resolution: '24-bit / 96 kHz',
      sampleRate: 96000,
      bitDepth: 24,
    );

    await _pump(
      tester,
      AudioSignalReport(
        song: song,
        diagnostics: null,
        page: AudioSignalReportPage.source,
        expanded: true,
      ),
    );

    expect(find.text(english.signalSourceDescription), findsOneWidget);
    expect(find.text(english.signalFileFormat), findsOneWidget);
    expect(find.text(taglish.signalSourceDescription), findsNothing);
    expect(find.text(taglish.signalFileFormat), findsNothing);
  });
}
