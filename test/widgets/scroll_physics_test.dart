import 'dart:io';

import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  test('production scrollables use Android platform physics', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('BouncingScrollPhysics')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Flick is Android-only and must use the platform scroll physics. '
          'Remove BouncingScrollPhysics from:\n${offenders.join('\n')}',
    );
  });

  test('the Menu keeps its pull-to-refresh physics on Android', () {
    final source = File(
      'lib/features/menu/screens/menu_screen.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'AlwaysScrollableScrollPhysics\(\s*'
        r'parent:\s*ClampingScrollPhysics\(\),?\s*\)',
      ).hasMatch(source),
      isTrue,
      reason:
          'The Menu RefreshIndicator needs AlwaysScrollableScrollPhysics so it '
          'can start even when the content is short.',
    );
  });

  testWidgets('the shared bottom sheet inherits Android clamping physics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const GlassBottomSheet(content: SizedBox(height: 2000))),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.physics, isA<ClampingScrollPhysics>());
    expect(scrollable.position.physics, isNot(isA<BouncingScrollPhysics>()));
  });
}
