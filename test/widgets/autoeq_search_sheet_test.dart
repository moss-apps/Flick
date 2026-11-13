import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/features/settings/screens/widgets/autoeq_search_sheet.dart';
import 'package:flick/l10n/l10n.dart';
import 'package:flick/services/autoeq_catalog_service.dart';

final _entry = AutoEqEntry.fromJson({
  'id': 'online-hd650',
  'b': 'Sennheiser',
  'm': 'HD 650',
  't': 'over-ear',
  's': 'oratory1990',
  'pa': -6.1,
  'g': [
    [205, -12.2, 0.18, 'PK'],
  ],
});

class _Catalog extends Fake implements AutoEqCatalogService {
  final requests = <(String, String)>[];
  Future<AutoEqEntry?> Function(String, String) lookup = (_, _) async => null;
  List<AutoEqSearchResult> searchResults = const [];

  @override
  Future<List<AutoEqEntry>> loadBundled() async => [];

  @override
  Future<List<String>> loadBrands() async => ['Sennheiser'];

  @override
  List<AutoEqSearchResult> search(
    String query, {
    String? brand,
    int limit = 60,
  }) => searchResults;

  @override
  Future<AutoEqEntry?> fetchOnline(String brand, String model) {
    requests.add((brand, model));
    return lookup(brand, model);
  }
}

Future<void> _open(
  WidgetTester tester,
  _Catalog service, {
  Locale locale = kFallbackLocale,
  Size size = const Size(390, 844),
  double keyboardHeight = 0,
  double textScale = 1,
  void Function(AutoEqEntry?)? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kAppLocalizationsDelegates,
      builder: (context, child) {
        LocaleController.instance.bind(AppLocalizations.of(context));
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showAutoEqSearchSheet(
                context,
                service: service,
              );
              onResult?.call(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder get _onlineButton => find.byKey(const Key('autoeq-online-search'));
Finder get _status => find.byKey(const Key('autoeq-online-status'));
Finder get _applyButton => find.byType(FilledButton);
Finder get _result => find.widgetWithText(ListTile, _entry.displayName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('GoogleSansFlex')
          ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex-Bold.ttf')))
        .load();
    await (FontLoader(
      'NotoSansSC',
    )..addFont(rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'))).load();
  });
  tearDown(() => LocaleController.instance.bindLocale(kFallbackLocale));

  testWidgets('online lookup is disabled until a query is entered', (
    tester,
  ) async {
    final service = _Catalog();
    await _open(tester, service);

    expect(tester.widget<IconButton>(_onlineButton).onPressed, isNull);
    expect(service.requests, isEmpty);
    expect(_status, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty results offer a labeled online-search action', (
    tester,
  ) async {
    final service = _Catalog();
    await _open(tester, service);
    await tester.enterText(find.byType(TextField), 'Unknown Model');
    await tester.pumpAndSettle();

    final cta = find.widgetWithText(TextButton, l10n.searchOnline2);
    expect(cta, findsOneWidget);
    expect(tester.widget<TextButton>(cta).onPressed, isNotNull);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(service.requests, [('', 'Unknown Model')]);
    expect(
      find.text(l10n.autoeqOnlineSearchFailed).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'tap displays loading, loads one preset and returns it on Apply',
    (tester) async {
      final pending = Completer<AutoEqEntry?>();
      final service = _Catalog()..lookup = (_, _) => pending.future;
      AutoEqEntry? applied;
      await _open(tester, service, onResult: (value) => applied = value);
      await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
      await tester.pump();
      await tester.tap(_onlineButton);
      await tester.pump();

      expect(service.requests, [('Sennheiser', 'HD 650')]);
      expect(find.text(l10n.searchingOnline).hitTestable(), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.widget<IconButton>(_onlineButton).onPressed, isNull);
      expect(tester.widget<FilledButton>(_applyButton).onPressed, isNull);
      expect(tester.testTextInput.isVisible, isFalse);

      pending.complete(_entry);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.foundOnline(_entry.displayName)).hitTestable(),
        findsOneWidget,
      );
      expect(_result.hitTestable(), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.widget<IconButton>(_onlineButton).onPressed, isNotNull);
      await tester.tap(_applyButton);
      await tester.pumpAndSettle();
      expect(applied, same(_entry));
      expect(tester.takeException(), isNull);
    },
  );

  for (final throws in [false, true]) {
    testWidgets('failed lookup ($throws) is visible and can be retried', (
      tester,
    ) async {
      final service = _Catalog()
        ..lookup = (_, _) async {
          if (throws) throw StateError('Offline');
          return null;
        };
      await _open(tester, service);
      await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
      await tester.pump();
      await tester.tap(_onlineButton);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.autoeqOnlineSearchFailed).hitTestable(),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(_onlineButton).onPressed, isNotNull);
      expect(tester.widget<FilledButton>(_applyButton).onPressed, isNull);
      service.lookup = (_, _) async => _entry;
      await tester.tap(_onlineButton);
      await tester.pumpAndSettle();
      expect(_result, findsOneWidget);
      expect(find.text(l10n.autoeqOnlineSearchFailed), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a failed lookup keeps the bundled preset appliable', (
    tester,
  ) async {
    final service = _Catalog()
      ..searchResults = [AutoEqSearchResult(_entry, 1000)]
      ..lookup = (_, _) async => null;
    AutoEqEntry? applied;
    await _open(tester, service, onResult: (value) => applied = value);
    await tester.enterText(find.byType(TextField), 'Sennheiser');
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(_applyButton).onPressed, isNotNull);
    await tester.tap(_onlineButton);
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.autoeqOnlineSearchFailed).hitTestable(),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_applyButton).onPressed, isNotNull);
    await tester.tap(_applyButton);
    await tester.pumpAndSettle();
    expect(applied, same(_entry));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a query ignores an old request without stopping the new one',
    (tester) async {
      final old = Completer<AutoEqEntry?>();
      final current = Completer<AutoEqEntry?>();
      final service = _Catalog()
        ..lookup = (_, model) =>
            model == 'HD 650' ? old.future : current.future;
      await _open(tester, service);
      await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
      await tester.pump();
      await tester.tap(_onlineButton);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Sennheiser HD 600');
      await tester.pump();
      await tester.tap(_onlineButton);
      await tester.pump();

      old.complete(_entry);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(_result, findsNothing);
      current.complete(null);
      await tester.pumpAndSettle();
      expect(find.text(l10n.autoeqOnlineSearchFailed), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'IME search submits and repeated lookup does not duplicate results',
    (tester) async {
      final service = _Catalog()..lookup = (_, _) async => _entry;
      await _open(tester, service);
      await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(_onlineButton);
      await tester.pumpAndSettle();

      expect(service.requests, hasLength(2));
      expect(_result, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('caret changes do not cancel a running lookup', (tester) async {
    final pending = Completer<AutoEqEntry?>();
    final service = _Catalog()..lookup = (_, _) => pending.future;
    await _open(tester, service);
    await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
    await tester.pump();
    await tester.tap(_onlineButton);
    await tester.pump();
    tester.widget<TextField>(find.byType(TextField)).controller!.selection =
        const TextSelection.collapsed(offset: 0);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(service.requests, hasLength(1));
    pending.complete(_entry);
    await tester.pumpAndSettle();
    expect(_result, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing during lookup ignores the eventual response', (
    tester,
  ) async {
    final pending = Completer<AutoEqEntry?>();
    final service = _Catalog()..lookup = (_, _) => pending.future;
    await _open(tester, service);
    await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
    await tester.pump();
    await tester.tap(_onlineButton);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    pending.complete(_entry);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('online status can be dismissed', (tester) async {
    final service = _Catalog()..lookup = (_, _) async => null;
    await _open(tester, service);
    await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
    await tester.pump();
    await tester.tap(_onlineButton);
    await tester.pumpAndSettle();
    expect(_status, findsOneWidget);

    await tester.tap(
      find.descendant(of: _status, matching: find.byIcon(Icons.close_rounded)),
    );
    await tester.pumpAndSettle();
    expect(_status, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [kFallbackLocale, const Locale('zh', 'CN')]) {
    testWidgets(
      'search, feedback and Apply stay above the keyboard ($locale)',
      (tester) async {
        final service = _Catalog();
        await _open(tester, service, locale: locale, keyboardHeight: 300);
        expect(tester.getRect(_onlineButton).bottom, lessThanOrEqualTo(544));
        await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
        await tester.pump();
        await tester.tap(_onlineButton);
        await tester.pumpAndSettle();
        expect(_status.hitTestable(), findsOneWidget);
        expect(tester.getRect(_status).bottom, lessThanOrEqualTo(544));
        expect(tester.getRect(_applyButton).bottom, lessThanOrEqualTo(544));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in const [Size(891, 411), Size(1024, 800), Size(320, 800)]) {
    testWidgets('picker actions and feedback fit at $size', (tester) async {
      final service = _Catalog();
      await _open(
        tester,
        service,
        size: size,
        textScale: size.width == 320 ? 2 : 1,
      );
      await tester.enterText(find.byType(TextField), 'Sennheiser HD 650');
      await tester.pump();
      await tester.tap(_onlineButton);
      await tester.pumpAndSettle();

      expect(_onlineButton.hitTestable(), findsOneWidget);
      expect(_applyButton, findsOneWidget);
      expect(_status.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
