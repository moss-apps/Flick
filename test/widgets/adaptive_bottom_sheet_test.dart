import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/widgets/common/glass_bottom_sheet.dart';

void main() {
  for (final size in const [Size(891, 411), Size(1280, 800), Size(375, 800)]) {
    testWidgets('modal uses usable width and height at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => GlassBottomSheet.show<void>(
                  context: context,
                  title: 'Options',
                  content: Column(
                    children: List.generate(
                      80,
                      (i) => ListTile(title: Text('Option $i')),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final surface = find.byWidgetPredicate(
        (w) =>
            w is Container && w.decoration == AppBottomSheetSurface.decoration,
      );
      final rect = tester.getRect(surface);
      expect(rect.width, greaterThan(size.width * 0.85));
      expect(rect.height, greaterThan(size.height * 0.85));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard reduces and lifts the sheet without hiding actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(891, 411);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 180)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => GlassBottomSheet.show<void>(
                context: context,
                title: 'Options',
                content: const SizedBox(height: 500, child: Text('Content')),
                actions: [
                  TextButton(onPressed: () {}, child: const Text('Save')),
                ],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(231));
    expect(tester.takeException(), isNull);
  });
}
