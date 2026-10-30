import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/features/onboarding/widgets/onboarding_graphics.dart';
import 'package:flick/features/recap/widgets/replay_style.dart';

Iterable<Rect> _circleBounds(CustomPainter painter, Size size) sync* {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  var offset = Offset.zero;
  var scale = const Offset(1, 1);
  final stack = <(Offset, Offset)>[];
  for (final recorded in canvas.invocations) {
    final call = recorded.invocation;
    final args = call.positionalArguments;
    switch (call.memberName) {
      case #save:
        stack.add((offset, scale));
      case #restore:
        (offset, scale) = stack.removeLast();
      case #translate:
        offset += Offset(
          (args[0] as num).toDouble() * scale.dx,
          (args[1] as num).toDouble() * scale.dy,
        );
      case #scale:
        final x = (args[0] as num).toDouble();
        final y = args.length > 1 ? (args[1] as num?)?.toDouble() ?? x : x;
        scale = Offset(scale.dx * x, scale.dy * y);
      case #drawCircle:
        final center = args[0] as Offset;
        final radius = (args[1] as num).toDouble();
        final paint = args[2] as Paint;
        final extent =
            radius +
            (paint.style == PaintingStyle.stroke ? paint.strokeWidth / 2 : 0);
        yield Rect.fromCenter(
          center: offset + Offset(center.dx * scale.dx, center.dy * scale.dy),
          width: extent * 2 * scale.dx,
          height: extent * 2 * scale.dy,
        );
    }
  }
}

void main() {
  tearDown(() => AppConstants.setAnimationsEnabled(true));

  for (final reducedMotion in [false, true]) {
    testWidgets('playback vinyl stays whole throughout its reveal '
        '(reduced motion: $reducedMotion)', (tester) async {
      AppConstants.setAnimationsEnabled(true);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: const Center(
            child: SizedBox(
              width: 360,
              height: 244,
              child: OnboardingGraphic(
                index: 3,
                active: true,
                foreground: ReplayStyle.ink,
                accent: ReplayStyle.acid,
                background: ReplayStyle.signal,
              ),
            ),
          ),
        ),
      );
      final graphic = find.descendant(
        of: find.byType(OnboardingGraphic),
        matching: find.byType(CustomPaint),
      );
      for (final elapsed in [0, 16, 100, 200, 400]) {
        await tester.pump(Duration(milliseconds: elapsed));
        final painter = tester.widget<CustomPaint>(graphic).painter!;
        for (final size in const [
          Size(360, 244),
          Size(272, 176),
          Size(342, 300),
          Size(448, 400),
        ]) {
          final fitted = applyBoxFit(
            BoxFit.contain,
            const Size(360, 244),
            size,
          );
          final artboard = Alignment.center.inscribe(
            fitted.destination,
            Offset.zero & size,
          );
          final circles = _circleBounds(painter, size).toList();
          expect(circles, isNotEmpty);
          for (final bounds in circles) {
            expect(bounds.left, greaterThan(artboard.left));
            expect(bounds.top, greaterThan(artboard.top));
            expect(bounds.right, lessThan(artboard.right));
            expect(bounds.bottom, lessThan(artboard.bottom));
          }
        }
      }
    });
  }
}
