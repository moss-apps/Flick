import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/player/widgets/line_seek_bar.dart';
import 'package:flick/features/player/widgets/waveform_seek_bar.dart';
import 'package:flick/models/progress_bar_size.dart';

void main() {
  const position = Duration(minutes: 1);
  const duration = Duration(minutes: 3);

  Future<void> pumpBar(WidgetTester tester, Widget bar) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: bar)),
        ),
      ),
    );
  }

  for (final thickness in [
    ProgressBarSizes.minLineThickness,
    ProgressBarSizes.maxLineThickness,
  ]) {
    testWidgets('line style keeps a 48dp touch target at ${thickness}dp', (
      tester,
    ) async {
      await pumpBar(
        tester,
        LineSeekBar(
          position: position,
          duration: duration,
          onChanged: (_) {},
          thickness: thickness,
        ),
      );

      expect(tester.getSize(find.byType(LineSeekBar)).height, 48);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('waveform height below the touch target stays tappable', (
    tester,
  ) async {
    await pumpBar(
      tester,
      WaveformSeekBar(
        position: position,
        duration: duration,
        onChanged: (_) {},
        height: ProgressBarSizes.minWaveformHeight,
      ),
    );

    expect(tester.getSize(find.byType(WaveformSeekBar)).height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waveform uses the selected height above the touch target', (
    tester,
  ) async {
    await pumpBar(
      tester,
      WaveformSeekBar(
        position: position,
        duration: duration,
        onChanged: (_) {},
        height: ProgressBarSizes.maxWaveformHeight,
      ),
    );

    expect(
      tester.getSize(find.byType(WaveformSeekBar)).height,
      ProgressBarSizes.maxWaveformHeight,
    );
    expect(tester.takeException(), isNull);
  });
}
