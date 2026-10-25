// Real bundled fonts and layout assertions, not platform-dependent pixel goldens.
// Enable BAYBAYIN_SCREENSHOTS for images a human can review for mark placement.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/interface_settings_screen.dart';
import 'package:flick/features/settings/screens/support_flick_screen.dart';
import 'package:flick/features/settings/widgets/language_settings_card.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/l10n/home_greeting.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/models/mini_player_config.dart';
import 'package:flick/models/nav_bar_config.dart';
import 'package:flick/providers/player_provider.dart';
import 'package:flick/widgets/common/mini_player_bar.dart';
import 'package:flick/widgets/common/library_heading.dart';
import 'package:flick/widgets/common/baybayin_text.dart';
import 'package:flick/widgets/navigation/flick_nav_bar.dart';

const _shotKey = ValueKey('baybayin_layout_shot');
const _screenshots = bool.fromEnvironment('BAYBAYIN_SCREENSHOTS');

Future<void> _shoot(WidgetTester tester, String name) async {
  if (!_screenshots) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/baybayin_shots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Widget _app(Widget child, {double scale = 1}) => ProviderScope(
  overrides: [currentSongProvider.overrideWith((ref) => null)],
  child: RepaintBoundary(
    key: _shotKey,
    child: ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController.instance,
      builder: (context, selectedLocale, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: selectedLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kAppLocalizationsDelegates,
        localeResolutionCallback: resolveAppLocale,
        builder: (context, child) {
          LocaleController.instance.bind(AppLocalizations.of(context));
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          );
        },
        home: Scaffold(body: child),
      ),
    ),
  ),
);

Widget _languagePage() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Builder(
        builder: (context) =>
            SettingsSectionHeader(context.l10n.englishForFilipino.language),
      ),
      const LanguageSettingsCard(),
    ],
  ),
);

Finder _option(String autonym) => find.byWidgetPredicate(
  (widget) => widget is SelectionSetting && widget.title == autonym,
);

const _latinHeadings = [
  'Mga kanta',
  'Mga kumanta',
  'Mga album',
  'Mga talaan ng kanta',
];
const _baybayinHeadings = [
  'ᜋᜅ ᜃᜈ᜔ᜆ',
  'ᜋᜅ ᜃᜓᜋᜈ᜔ᜆ',
  'ᜋᜅ ᜀᜎ᜔ᜊᜓᜋ᜔',
  'ᜋᜅ ᜆᜎᜀᜈ᜔ ᜈᜅ᜔ ᜃᜈ᜔ᜆ',
];

// Exercise the real heading widget within constrained header rows, including
// the Songs screen's three trailing actions. The page can grow vertically.
Widget _headingPage() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Builder(
    builder: (context) => Column(
      children: [
        for (final section in LibrarySection.values) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LibraryHeading(
                      section: section,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(context.l10n.songsCount(101)),
                  ],
                ),
              ),
              for (
                var action = 0;
                action < (section == LibrarySection.songs ? 3 : 2);
                action++
              )
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ],
    ),
  ),
);

// Match the home greeting's available width, typography and summary row rather
// than testing the string in an unconstrained Text widget.
Widget _greetingPage(String hook) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Builder(
    builder: (context) => Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hook,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 0.94,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.tracksLikedSongsPlaylists(101, 20, 4),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
      ],
    ),
  ),
);

void _setSize(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
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
    await (FontLoader(
          'NotoSansTagalog',
        )..addFont(rootBundle.load('assets/fonts/NotoSansTagalog-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocaleController.instance.load();
  });

  tearDown(() {
    LocaleController.instance.value = null;
    LocaleController.instance.bindLocale(kFallbackLocale);
  });

  testWidgets('language choices survive narrow screens and enlarged text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in kSupportedLocales) {
      for (final width in [320.0, 375.0, 600.0]) {
        for (final scale in [1.0, 2.0, 3.0]) {
          _setSize(tester, width);
          LocaleController.instance.value = locale;
          // Reset the page/scroll position between sweep cases.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(_app(_languagePage(), scale: scale));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale width=$width scale=$scale',
          );
          expect(_option('Taglish'), findsOneWidget);
          expect(_option('English'), findsOneWidget);
          expect(
            find.byType(ToggleSetting),
            locale == kFilipinoLocale ? findsOneWidget : findsNothing,
          );
          if (width == 320 && scale == 1 && locale.languageCode != 'zh') {
            await _shoot(tester, 'language-${locale.toString()}-320');
          }
          await tester.ensureVisible(_option('English'));
          await tester.pumpAndSettle();
          expect(
            _option('English').hitTestable(),
            findsOneWidget,
            reason: 'The escape option must remain reachable.',
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets(
    'Taglish selector and independent script switch retain the English escape',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      _setSize(tester, 320);
      LocaleController.instance.value = const Locale('en');
      await tester.pumpWidget(_app(_languagePage(), scale: 2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_option('Taglish'));
      await tester.tap(_option('Taglish'));
      await tester.pumpAndSettle();
      expect(LocaleController.instance.value, kFilipinoLocale);
      expect(
        tester.widget<SelectionSetting>(_option('Taglish')).selected,
        isTrue,
      );
      expect(l10n.language, 'Wika');
      expect(
        tester.widget<ToggleSetting>(find.byType(ToggleSetting)).value,
        isFalse,
      );
      await tester.ensureVisible(find.byType(ToggleSetting));
      await tester.tap(find.byType(ToggleSetting));
      await tester.pumpAndSettle();
      expect(LocaleController.instance.baybayinHeadings, isTrue);
      expect(
        tester.widget<ToggleSetting>(find.byType(ToggleSetting)).value,
        isTrue,
      );
      expect(l10n.nextSong, 'Susunod na kanta');
      await tester.ensureVisible(_option('English'));
      await tester.pumpAndSettle();
      await _shoot(tester, 'language-tl-320-large-escape');
      await tester.tap(_option('English'));
      await tester.pumpAndSettle();
      expect(LocaleController.instance.value, const Locale('en'));
      expect(l10n.language, 'Language');
      expect(find.byType(ToggleSetting), findsNothing);
      expect(LocaleController.instance.baybayinHeadings, isTrue);
      await tester.ensureVisible(_option('Taglish'));
      await tester.tap(_option('Taglish'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ToggleSetting));
      await tester.tap(find.byType(ToggleSetting));
      await tester.pumpAndSettle();
      expect(LocaleController.instance.baybayinHeadings, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the four library headings change live, with one Latin accessibility label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        _setSize(tester, 375);
        LocaleController.instance.value = kFilipinoLocale;
        await tester.pumpWidget(_app(_headingPage()));
        await tester.pumpAndSettle();
        for (final text in _baybayinHeadings) {
          expect(find.text(text), findsNothing);
        }
        await LocaleController.instance.setBaybayinHeadings(true);
        await tester.pumpAndSettle();
        for (var i = 0; i < LibrarySection.values.length; i++) {
          expect(find.text(_baybayinHeadings[i]), findsOneWidget);
          expect(find.text(_latinHeadings[i]), findsOneWidget);
          final node = tester.getSemantics(find.byType(LibraryHeading).at(i));
          expect(node.label, _latinHeadings[i]);
          expect(
            node,
            matchesSemantics(label: _latinHeadings[i], isHeader: true),
          );
        }
        await _shoot(tester, 'headings-tl-baybayin-375');
        await LocaleController.instance.select(const Locale('en'));
        await tester.pumpAndSettle();
        for (final text in _baybayinHeadings) {
          expect(find.text(text), findsNothing);
        }
        await LocaleController.instance.select(kFilipinoLocale);
        await LocaleController.instance.setBaybayinHeadings(false);
        await tester.pumpAndSettle();
        for (final text in _baybayinHeadings) {
          expect(find.text(text), findsNothing);
        }
        for (final text in _latinHeadings) {
          expect(find.text(text), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'all four constrained headings wrap at narrow widths and enlarged text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await LocaleController.instance.setBaybayinHeadings(true);
      for (final locale in kSupportedLocales) {
        LocaleController.instance.value = locale;
        for (final width in [320.0, 375.0, 600.0]) {
          for (final scale in [1.0, 2.0, 3.0]) {
            _setSize(tester, width);
            await tester.pumpWidget(_app(_headingPage(), scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$locale width=$width scale=$scale',
            );
            for (final text in _baybayinHeadings) {
              expect(
                find.text(text),
                locale == kFilipinoLocale ? findsOneWidget : findsNothing,
              );
            }
            if (locale == kFilipinoLocale && width == 320 && scale == 2) {
              await _shoot(tester, 'headings-tl-baybayin-320-large');
            }
          }
        }
      }
    },
  );

  testWidgets(
    'curated compact labels have no caption and one Latin announcement',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        LocaleController.instance.value = kFilipinoLocale;
        final strings = lookupFlickLocalizations(kFilipinoLocale);
        final script = lookupAppLocalizations(kBaybayinLocale);
        await LocaleController.instance.setBaybayinHeadings(true);
        for (final width in [320.0, 375.0, 600.0]) {
          for (final scale in [1.0, 2.0, 3.0]) {
            _setSize(tester, width);
            await tester.pumpWidget(
              _app(
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final label in BaybayinLabel.values) ...[
                        BaybayinText(
                          label: label,
                          fallback: label.text(strings.englishForFilipino),
                          style: AppTheme.darkTheme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'labels width=$width scale=$scale',
            );
            for (var i = 0; i < BaybayinLabel.values.length; i++) {
              final label = BaybayinLabel.values[i];
              expect(find.text(label.text(script)), findsOneWidget);
              expect(find.text(label.text(strings)), findsNothing);
              // The semantics of visible nodes are checked below at normal size.
              if (width == 375 && scale == 1 && i < 4) {
                expect(
                  tester.getSemantics(find.byType(BaybayinText).at(i)).label,
                  label.text(strings),
                );
              }
            }
            if (width == 375 && scale == 1) {
              await _shoot(tester, 'curated-baybayin-labels-375');
            }
          }
        }
        await LocaleController.instance.setBaybayinHeadings(false);
        await tester.pumpAndSettle();
        expect(find.text(script.playingLabel), findsNothing);
        expect(find.text('Playing'), findsOneWidget);
        await LocaleController.instance.setBaybayinHeadings(true);
        for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
          await LocaleController.instance.select(locale);
          await tester.pumpAndSettle();
          expect(find.text(script.playingLabel), findsNothing);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('real interface settings use English titles and descriptions', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _setSize(tester, 375);
    LocaleController.instance.value = kFilipinoLocale;
    await tester.pumpWidget(_app(const InterfaceSettingsScreen()));
    await tester.pumpAndSettle();
    final strings = lookupFlickLocalizations(kFilipinoLocale);
    final english = strings.englishForFilipino;
    for (final (title, description) in [
      (english.animations, english.enableAnimatedTransitionsAndEffects),
      (english.hapticFeedback, english.enableVibrationOnInteractions),
      (
        english.autoFocusSearch,
        english.automaticallyOpenKeyboardWhenSwitchingTo,
      ),
    ]) {
      final tile = find.byWidgetPredicate(
        (widget) =>
            widget is ToggleSetting &&
            widget.title == title &&
            widget.subtitle == description,
      );
      expect(tile, findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('support is English with the exact Taglish-only donation card', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final strings = lookupFlickLocalizations(kFilipinoLocale);
    final english = strings.englishForFilipino;
    for (final locale in kSupportedLocales) {
      for (final width in [320.0, 375.0, 600.0]) {
        for (final scale in [1.0, 2.0, 3.0]) {
          _setSize(tester, width);
          LocaleController.instance.value = locale;
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            _app(const SupportFlickScreen(), scale: scale),
          );
          // Support's decorative pulse is continuous; do not pumpAndSettle.
          await tester.pump(const Duration(seconds: 1));
          expect(
            tester.takeException(),
            isNull,
            reason: 'support $locale width=$width scale=$scale',
          );
          expect(
            find.text(strings.filipinoDonationNote),
            locale == kFilipinoLocale ? findsOneWidget : findsNothing,
          );
          if (locale == kFilipinoLocale) {
            expect(find.text(english.supportFlick), findsOneWidget);
            expect(find.text(english.soloDeveloper), findsOneWidget);
            expect(
              find.text(english.flickIsBuiltAndMaintainedBy),
              findsOneWidget,
            );
            expect(find.text(english.whyDonate.toUpperCase()), findsOneWidget);
            final note = find.text(strings.filipinoDonationNote);
            final kofi = find.byWidgetPredicate(
              (widget) =>
                  widget is NavigationSetting &&
                  widget.title == english.koFi &&
                  widget.subtitle == english.supportDevelopmentOnKoFi,
            );
            final coffee = find.byWidgetPredicate(
              (widget) =>
                  widget is NavigationSetting &&
                  widget.title == english.buyMeACoffee &&
                  widget.subtitle == english.supportDevelopmentOnBuyMeACoffee,
            );
            expect(kofi, findsOneWidget);
            expect(coffee, findsOneWidget);
            expect(
              tester.getTopLeft(note).dy,
              lessThan(tester.getTopLeft(kofi).dy),
            );
            expect(
              tester.getTopLeft(note).dy,
              lessThan(tester.getTopLeft(coffee).dy),
            );
            if (width == 375 && scale == 1) {
              await tester.ensureVisible(note);
              await tester.pump(const Duration(milliseconds: 300));
              await _shoot(tester, 'support-tl-donation-375');
            }
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('all fifteen Filipino hooks fit the constrained home heading', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LocaleController.instance.value = kFilipinoLocale;
    for (final group in filipinoHomeGreetingHooks.entries) {
      for (final hook in group.value) {
        for (final width in [320.0, 375.0, 600.0]) {
          for (final scale in [1.0, 2.0, 3.0]) {
            _setSize(tester, width);
            await tester.pumpWidget(_app(_greetingPage(hook), scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$hook width=$width scale=$scale',
            );
            expect(find.text(hook), findsOneWidget);
            if (width == 375 && scale == 1 && hook == group.value.first) {
              await _shoot(tester, 'greeting-tl-${group.key.name}-375');
            }
          }
        }
      }
    }
  });

  testWidgets(
    'only the requested navigation labels change and metadata stays untouched',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      LocaleController.instance.value = kFilipinoLocale;
      await LocaleController.instance.setBaybayinHeadings(true);
      for (final width in [320.0, 375.0, 600.0]) {
        for (final scale in [1.0, 2.0, 3.0]) {
          for (final allButtons in [false, true]) {
            _setSize(tester, width);
            await tester.pumpWidget(
              _app(
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FlickNavBar(
                    config: allButtons
                        ? NavBarConfig(
                            enabledButtons: NavBarButton.values,
                            showLabels: true,
                          )
                        : NavBarConfig.defaultConfig,
                    currentIndex: 1,
                    onTap: (_) {},
                    showMiniPlayer: true,
                    miniPlayerWidget: MiniPlayerBar(
                      config: MiniPlayerConfig.defaultConfig,
                      songId: 'test-song',
                      title: 'Jóga',
                      artist: 'Björk',
                      progress: 0.42,
                      enableHero: false,
                      onPlayPause: () {},
                      onPrevious: () {},
                      onNext: () {},
                    ),
                  ),
                ),
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'width=$width scale=$scale allButtons=$allButtons',
            );
            expect(find.text('Jóga'), findsOneWidget);
            expect(find.text('Björk'), findsOneWidget);
            final buttons = allButtons
                ? NavBarButton.values
                : NavBarConfig.defaultConfig.enabledButtons;
            final script = lookupAppLocalizations(kBaybayinLocale);
            final strings = lookupFlickLocalizations(kFilipinoLocale);
            for (final button in buttons) {
              final label = baybayinNavigationLabel(button);
              final expected = label?.text(script) ?? button.labelFor(strings);
              expect(find.text(expected), findsOneWidget);
            }
            if (width == 375 && scale == 1 && !allButtons) {
              await _shoot(tester, 'navigation-tl-375');
            }
          }
        }
      }
    },
  );
}
