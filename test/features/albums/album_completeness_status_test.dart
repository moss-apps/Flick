import 'dart:io';
import 'dart:ui' as ui;

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/albums/widgets/album_completeness_status.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/album_completeness.dart';
import 'package:flick/models/song.dart';
import 'package:flick/widgets/common/detail_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

AlbumCompleteness _result({required int trackTotal, int? discTotal}) {
  return AlbumCompleteness.resolve([
    Song(
      id: '1',
      title: 'Track',
      artist: 'Artist',
      duration: const Duration(minutes: 3),
      fileType: 'FLAC',
      trackNumber: 1,
      trackTotal: trackTotal,
      discNumber: 1,
      discTotal: discTotal,
    ),
  ]);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in ['GoogleSansFlex', 'NotoSansSC']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  for (final locale in kSupportedLocales) {
    test('missing counts retain the actual number in $locale', () {
      final copy = lookupFlickLocalizations(locale).englishForFilipino;
      for (final count in [0, 1, 2, 3, 10, 21]) {
        expect(copy.albumMissingTracks(count), contains('$count'));
        expect(copy.albumMissingDiscs(count), contains('$count'));
      }
    });

    testWidgets('status and badge fit 320dp at 200% text in $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      try {
        final complete = _result(trackTotal: 1);
        final incomplete = _result(trackTotal: 3, discTotal: 2);
        const screenshotKey = ValueKey('completeness-gallery');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            locale: locale,
            supportedLocales: kSupportedLocales,
            localizationsDelegates: kAppLocalizationsDelegates,
            localeResolutionCallback: resolveAppLocale,
            builder: (context, child) => RepaintBoundary(
              key: screenshotKey,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: ColoredBox(
                color: AppTheme.darkTheme.scaffoldBackgroundColor,
                child: CustomScrollView(
                  slivers: [
                    DetailHeader(
                      expanded: false,
                      centeredTitle: false,
                      artBuilder: (_) => const SizedBox.shrink(),
                      title: 'Album',
                      subtitle: 'Artist',
                      meta: '2026 · FLAC',
                      lossless: true,
                      metadataBadge: AlbumVerifiedBadge(completeness: complete),
                      fadeTo: AppTheme.darkTheme.scaffoldBackgroundColor,
                      onBack: () {},
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AlbumCompletenessStatusWidget(completeness: complete),
                          const SizedBox(height: 24),
                          AlbumCompletenessStatusWidget(
                            completeness: incomplete,
                          ),
                          const SizedBox(height: 24),
                          const AlbumCompletenessStatusWidget(
                            completeness: AlbumCompleteness.unknown,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AlbumCompletenessBadge(completeness: complete),
                              const SizedBox(width: 24),
                              AlbumCompletenessBadge(completeness: incomplete),
                              const AlbumCompletenessBadge(
                                completeness: AlbumCompleteness.unknown,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final localized = lookupFlickLocalizations(locale);
        final copy = localized.englishForFilipino;
        expect(tester.takeException(), isNull);
        expect(find.text(copy.albumComplete), findsNothing);
        expect(find.text(localized.lossless), findsOneWidget);
        expect(find.byTooltip(copy.albumComplete), findsOneWidget);
        final headerBadge = find.descendant(
          of: find.byType(DetailHeader),
          matching: find.byType(AlbumVerifiedBadge),
        );
        expect(headerBadge, findsOneWidget);
        expect(
          Localizations.localeOf(tester.element(headerBadge)).languageCode,
          locale.languageCode,
        );
        final badgeRect = tester.getRect(headerBadge);
        final losslessRect = tester.getRect(find.text(localized.lossless));
        expect(badgeRect.left, greaterThanOrEqualTo(losslessRect.right));
        expect(badgeRect.center.dy, closeTo(losslessRect.center.dy, 1));
        expect(badgeRect.width, greaterThanOrEqualTo(48));
        // The inline action must not inflate the metadata line to a 48dp
        // button height the way a standalone button would.
        expect(badgeRect.height, lessThanOrEqualTo(losslessRect.height + 4));
        final completeLabel = find.text(copy.albumCompleteShort);
        expect(completeLabel, findsOneWidget);
        expect(
          tester.getCenter(completeLabel).dy,
          closeTo(losslessRect.center.dy, 1),
        );
        final completeIcon = find.descendant(
          of: headerBadge,
          matching: find.byIcon(LucideIcons.badgeCheck),
        );
        expect(
          tester.getSize(completeIcon),
          tester.getSize(find.byIcon(LucideIcons.audioWaveform)),
        );
        expect(
          DefaultTextStyle.of(tester.element(completeLabel)).style.fontSize,
          tester.widget<Text>(find.text(localized.lossless)).style!.fontSize,
        );
        expect(find.text(copy.albumMissingTracks(2)), findsOneWidget);
        expect(find.text(copy.albumMissingDiscs(1)), findsOneWidget);
        expect(find.text(copy.albumCompletenessUnknown), findsOneWidget);
        expect(
          find.textContaining(copy.albumMissingDiscNumbers('2')),
          findsOneWidget,
        );
        expect(
          find.textContaining(copy.albumMissingPositions('1:2, 1:3')),
          findsOneWidget,
        );
        expect(find.byTooltip(copy.albumCompleteShort), findsOneWidget);
        expect(find.byTooltip(copy.albumIncompleteShort), findsOneWidget);
        expect(find.byType(Tooltip), findsNWidgets(3));
        expect(find.bySemanticsLabel(copy.albumCompleteShort), findsOneWidget);
        expect(find.bySemanticsLabel(copy.albumComplete), findsOneWidget);
        for (final text in find.byType(Text).evaluate()) {
          final rect = tester.getRect(find.byWidget(text.widget));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }

        await _capture(tester, screenshotKey, locale.languageCode);
        await tester.tap(headerBadge);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(copy.albumCompleteTitle), findsOneWidget);
        expect(find.text(copy.albumCompleteExplanation), findsOneWidget);
        expect(find.text(copy.albumCompleteVerificationNote), findsOneWidget);
        _expectSheetHeaderAligned(tester, copy.albumCompleteTitle, copy.close);
        final surface = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Material),
        );
        expect(tester.getTopLeft(surface.first).dy, lessThan(64));
        await _capture(
          tester,
          screenshotKey,
          'verification_${locale.languageCode}',
        );
        await tester.tap(find.byTooltip(copy.close));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(headerBadge);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(8, 990));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('verified badge works without lossless in $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: locale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kAppLocalizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DetailHeader(
                  expanded: false,
                  centeredTitle: true,
                  artBuilder: (_) => const SizedBox.shrink(),
                  title: 'Album',
                  subtitle: 'Artist',
                  meta: '2026 · MP3',
                  metadataBadge: AlbumVerifiedBadge(
                    completeness: _result(trackTotal: 1),
                  ),
                  fadeTo: AppTheme.darkTheme.scaffoldBackgroundColor,
                  onBack: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AlbumVerifiedBadge));
      await tester.pumpAndSettle();
      expect(
        find.text(
          lookupFlickLocalizations(
            locale,
          ).englishForFilipino.albumCompleteExplanation,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    for (final layout in [
      (name: 'phone', size: const Size(360, 800), textScale: 1.0),
      (name: 'tablet', size: const Size(800, 1000), textScale: 1.0),
      (name: 'landscape', size: const Size(640, 360), textScale: 2.0),
    ]) {
      testWidgets('aligned verification on ${layout.name} in $locale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = layout.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final screenshotKey = ValueKey('verification-${layout.name}');
        final localized = lookupFlickLocalizations(locale);
        final copy = localized.englishForFilipino;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            locale: locale,
            supportedLocales: kSupportedLocales,
            localizationsDelegates: kAppLocalizationsDelegates,
            builder: (context, child) => RepaintBoundary(
              key: screenshotKey,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(layout.textScale)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  DetailHeader(
                    expanded: false,
                    centeredTitle: true,
                    artBuilder: (_) =>
                        const ColoredBox(color: Color(0xFF2C1011)),
                    title: 'CLAPCLAPCLAP!',
                    subtitle: 'IV Of Spades',
                    meta: '2019 · 16 tracks · 59m',
                    lossless: true,
                    metadataBadge: AlbumVerifiedBadge(
                      completeness: _result(trackTotal: 1),
                    ),
                    fadeTo: AppTheme.darkTheme.scaffoldBackgroundColor,
                    onBack: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final label = find.text(copy.albumCompleteShort);
        expect(label, findsOneWidget);
        expect(
          tester.getCenter(label).dy,
          closeTo(tester.getCenter(find.text(localized.lossless)).dy, 1),
        );
        await _capture(
          tester,
          screenshotKey,
          '${layout.name}_${locale.languageCode}',
        );

        await tester.tap(find.byType(AlbumVerifiedBadge));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(copy.albumCompleteTitle), findsOneWidget);
        _expectSheetHeaderAligned(tester, copy.albumCompleteTitle, copy.close);
        final panel = tester.getRect(find.byType(Dialog));
        expect(panel.left, greaterThanOrEqualTo(0));
        expect(panel.right, lessThanOrEqualTo(layout.size.width));
        final closeRect = tester.getRect(find.byTooltip(copy.close));
        expect(closeRect.bottom, lessThan(layout.size.height));
        expect(closeRect.size.width, greaterThanOrEqualTo(48));
        expect(closeRect.size.height, greaterThanOrEqualTo(48));
        await _capture(
          tester,
          screenshotKey,
          '${layout.name}_verification_${locale.languageCode}',
        );
        await tester.tap(find.byTooltip(copy.close));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      });
    }
  }

  test('verification heading uses the requested sentence', () {
    expect(
      lookupFlickLocalizations(const Locale('en')).albumCompleteTitle,
      'Album is complete',
    );
  });

  testWidgets('only complete albums have the inline verification action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            AlbumVerifiedBadge(completeness: _result(trackTotal: 3)),
            const AlbumVerifiedBadge(completeness: AlbumCompleteness.unknown),
          ],
        ),
      ),
    );
    expect(find.byType(TextButton), findsNothing);
  });
}

void _expectSheetHeaderAligned(
  WidgetTester tester,
  String title,
  String closeLabel,
) {
  final check = find.descendant(
    of: find.byType(Dialog),
    matching: find.byIcon(LucideIcons.badgeCheck),
  );
  final titleRect = tester.getRect(find.text(title));
  expect(tester.getCenter(check).dy, closeTo(titleRect.center.dy, 1));
  expect(
    tester.getCenter(find.byTooltip(closeLabel)).dy,
    closeTo(titleRect.center.dy, 1),
  );
  expect(tester.getRect(check).right, lessThan(titleRect.left));
  expect(
    titleRect.right,
    lessThanOrEqualTo(tester.getRect(find.byTooltip(closeLabel)).left),
  );
}

Future<void> _capture(WidgetTester tester, Key key, String name) async {
  if (!const bool.fromEnvironment('ALBUM_COMPLETENESS_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/album_completeness_shots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
