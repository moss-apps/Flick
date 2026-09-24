import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/providers/connectivity_provider.dart';
import 'package:flick/widgets/common/offline_notice.dart';

class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.results);

  List<ConnectivityResult> results;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void emit(List<ConnectivityResult> value) {
    results = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

const _sizeKey = ValueKey('offline_notice_size');
const _barKey = ValueKey('offline_notice_bar');

Widget _host(_FakeConnectivity connectivity, {Widget? home}) => ProviderScope(
  overrides: [connectivityClientProvider.overrideWithValue(connectivity)],
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, navigator) => Column(
      children: [
        Expanded(child: navigator ?? const SizedBox.shrink()),
        const OfflineNotice(),
      ],
    ),
    home: home ?? const Scaffold(body: SizedBox.expand()),
  ),
);

double _barHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(_sizeKey)).height;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _goOffline(
  WidgetTester tester,
  _FakeConnectivity connectivity,
) async {
  connectivity.emit([ConnectivityResult.none]);
  await tester.pump(
    ConnectivityNotifier.offlineDebounce + const Duration(milliseconds: 100),
  );
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppConstants.setAnimationsEnabled(true));

  late _FakeConnectivity connectivity;

  setUp(() {
    connectivity = _FakeConnectivity([ConnectivityResult.wifi]);
  });

  tearDown(() => connectivity.close());

  testWidgets('stays collapsed while online', (tester) async {
    await tester.pumpWidget(_host(connectivity));
    await _settle(tester);

    expect(_barHeight(tester), 0);
    expect(find.textContaining("You're offline"), findsNothing);
  });

  testWidgets('shows a full-width bar at the bottom while offline', (
    tester,
  ) async {
    await tester.pumpWidget(_host(connectivity));
    await _settle(tester);

    connectivity.emit([ConnectivityResult.none]);
    await tester.pump();
    expect(_barHeight(tester), 0);

    await tester.pump(
      ConnectivityNotifier.offlineDebounce + const Duration(milliseconds: 100),
    );
    await _settle(tester);

    final barSize = tester.getSize(find.byKey(_barKey));
    final barBottom = tester.getBottomLeft(find.byKey(_barKey)).dy;

    expect(barSize.height, greaterThan(0));
    expect(barSize.width, 800);
    expect(barBottom, 600);
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(
      find.textContaining('Some online features may not work'),
      findsOneWidget,
    );
  });

  testWidgets('pushes app content up instead of covering it', (tester) async {
    await tester.pumpWidget(_host(connectivity));
    await _settle(tester);

    final scaffoldHeightOnline = tester.getSize(find.byType(Scaffold)).height;

    await _goOffline(tester, connectivity);

    final scaffoldHeightOffline = tester.getSize(find.byType(Scaffold)).height;
    final barTop = tester.getTopLeft(find.byKey(_barKey)).dy;
    final scaffoldBottom = tester.getBottomLeft(find.byType(Scaffold)).dy;

    expect(scaffoldHeightOffline, lessThan(scaffoldHeightOnline));
    expect(scaffoldBottom, lessThanOrEqualTo(barTop));
  });

  testWidgets('shows an animated check and green background when back online', (
    tester,
  ) async {
    await tester.pumpWidget(_host(connectivity));
    await _settle(tester);
    await _goOffline(tester, connectivity);
    expect(find.byIcon(LucideIcons.wifiOff), findsOneWidget);

    connectivity.emit([ConnectivityResult.wifi]);
    await _settle(tester);

    expect(_barHeight(tester), greaterThan(0));
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.byIcon(LucideIcons.wifiOff), findsNothing);
    expect(find.textContaining('Back online'), findsOneWidget);

    final decoration =
        tester.widget<AnimatedContainer>(find.byKey(_barKey)).decoration
            as BoxDecoration;
    expect(decoration.color, AppColors.success);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(_barHeight(tester), 0);
  });

  testWidgets('does not block taps on the interface above it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        connectivity,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('tap me'),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await _goOffline(tester, connectivity);
    expect(find.textContaining("You're offline"), findsOneWidget);

    await tester.tap(find.text('tap me'));
    await tester.pump();

    expect(taps, 1);
  });
}
