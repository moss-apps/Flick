import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/theme/adaptive_colors.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/app_theme.dart';
import 'package:flick/widgets/common/detail_header.dart';

Widget _host({
  Color? artColor,
  String? meta,
  bool lossless = false,
  String? losslessLabel,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          DetailHeader(
            expanded: true,
            centeredTitle: false,
            artBuilder: (_) => const ColoredBox(color: Colors.black),
            title: 'Test Album',
            subtitle: 'Test Artist',
            meta: meta,
            lossless: lossless,
            losslessLabel: losslessLabel,
            fadeTo: AppColors.background,
            artColor: artColor,
            onBack: () {},
          ),
        ],
      ),
    ),
  );
}

BoxDecoration _backButtonDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  return container.decoration! as BoxDecoration;
}

Icon _backButtonIcon(WidgetTester tester) {
  return tester.widget<Icon>(find.byIcon(LucideIcons.chevronLeft));
}

void main() {
  testWidgets('back button keeps the light glass when no art color is known', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    final decoration = _backButtonDecoration(tester);
    expect(decoration.color, AppColors.glassBackgroundStrong);
    expect(
      (decoration.border! as Border).top.color,
      AppColors.glassBorder,
    );
    expect(
      _backButtonIcon(tester).color,
      AdaptiveColors.textPrimaryOn(AppColors.background),
    );
  });

  testWidgets('back button keeps white frost and light icon on dark art', (
    tester,
  ) async {
    await tester.pumpWidget(_host(artColor: const Color(0xFF101010)));

    final decoration = _backButtonDecoration(tester);
    expect(decoration.color, AppColors.glassBackgroundStrong);
    expect(
      (decoration.border! as Border).top.color,
      AppColors.glassBorder,
    );
    expect(
      _backButtonIcon(tester).color,
      AdaptiveColors.textPrimaryOn(const Color(0xFF101010)),
    );
  });

  testWidgets('back button switches to smoked glass on bright art', (
    tester,
  ) async {
    await tester.pumpWidget(_host(artColor: const Color(0xFFFFEB3B)));

    final decoration = _backButtonDecoration(tester);
    expect(decoration.color, const Color(0x61000000));
    expect(
      (decoration.border! as Border).top.color,
      Colors.white.withValues(alpha: 0.24),
    );
    // The smoked surface is still mid-tone over a bright cover, so the
    // near-black glyph has the stronger contrast.
    expect(_backButtonIcon(tester).color, const Color(0xFF1A1A1A));
  });

  testWidgets('mid-tone art gets smoked glass with a white icon', (
    tester,
  ) async {
    await tester.pumpWidget(_host(artColor: const Color(0xFF9E9E9E)));

    final decoration = _backButtonDecoration(tester);
    expect(decoration.color, const Color(0x61000000));
    expect(
      _backButtonIcon(tester).color,
      AdaptiveColors.textPrimaryOn(AppColors.background),
    );
  });

  testWidgets('callers can supply an English lossless label', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _host(meta: '3 songs', lossless: true, losslessLabel: ' Custom Lossless'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Custom Lossless', findRichText: true),
      findsOneWidget,
    );
  });
}
