import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/equalizer_screen.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/providers/equalizer_provider.dart';
import 'package:flick/providers/player_provider.dart';

class _FakeEqualizer extends EqualizerNotifier {
  @override
  EqualizerState build() => EqualizerState.initial();
}

Widget _app(Widget home) => ProviderScope(
  overrides: [
    equalizerProvider.overrideWith(_FakeEqualizer.new),
    currentSongProvider.overrideWithValue(null),
  ],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    locale: kFallbackLocale,
    supportedLocales: kSupportedLocales,
    localizationsDelegates: kAppLocalizationsDelegates,
    home: home,
  ),
);

Widget _host({required bool embedded}) => _app(
  Scaffold(body: EqualizerScreen(embedded: embedded, showBackButton: false)),
);

Widget _pagerHost(PageController controller) => _app(
  Scaffold(
    body: PageView(
      controller: controller,
      children: [
        const EqualizerScreen(embedded: true, showBackButton: false),
        const SizedBox.expand(),
      ],
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('GoogleSansFlex')
          ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Bold.ttf')))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester, {required bool embedded}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_host(embedded: embedded));
    await tester.pumpAndSettle();
  }

  testWidgets('embedded content swipes leave section paging to the tab bar', (
    tester,
  ) async {
    await pumpScreen(tester, embedded: true);
    expect(find.text('Compressor'), findsNothing);

    await tester.fling(find.text('Preamp'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Compressor'), findsNothing);

    await tester.fling(find.text('EQ'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Compressor'), findsOneWidget);

    await tester.fling(find.text('EQ'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('CREATIVE FX'), findsOneWidget);

    await tester.fling(find.text('FX'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('CREATIVE FX'), findsOneWidget);
  });

  testWidgets('embedded EQ lets the parent pager receive content swipes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_pagerHost(controller));
    await tester.pumpAndSettle();
    expect(controller.page, 0.0);

    await tester.fling(find.text('EQ'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Compressor'), findsOneWidget);
    expect(controller.page, 0.0);

    await tester.fling(find.text('Threshold'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 1.0);
  });

  testWidgets('standalone content swipes still page through EQ sections', (
    tester,
  ) async {
    await pumpScreen(tester, embedded: false);
    expect(find.text('Compressor'), findsNothing);

    await tester.fling(find.text('Preamp'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Compressor'), findsOneWidget);
  });
}
