import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flick/core/utils/latest_value_writer.dart';

class _Gated {
  final started = <int>[];
  final gates = <Completer<void>>[];

  Future<void> write(int value) {
    started.add(value);
    final gate = Completer<void>();
    gates.add(gate);
    return gate.future;
  }
}

void main() {
  test('writes the first value straight away', () async {
    final gated = _Gated();
    final writer = LatestValueWriter<int>(gated.write);

    final done = writer.submit(1);
    expect(gated.started, [1]);
    gated.gates.single.complete();
    await done;
  });

  test('keeps one write in flight and applies only the newest queued value', () async {
    final gated = _Gated();
    final writer = LatestValueWriter<int>(gated.write);

    final done = [for (final value in [1, 2, 3, 4, 5]) writer.submit(value)];
    await pumpEventQueue();
    expect(gated.started, [1]); // 2, 3 and 4 never reach the DAC.

    gated.gates[0].complete();
    await pumpEventQueue();
    expect(gated.started, [1, 5]); // Still one at a time.

    gated.gates[1].complete();
    await Future.wait(done);
    expect(gated.started, [1, 5]);
  });

  test('every waiting caller completes only after the final value is written', () async {
    final gated = _Gated();
    final writer = LatestValueWriter<int>(gated.write);
    var firstDone = false;
    var lastDone = false;

    unawaited(writer.submit(1).then((_) => firstDone = true));
    unawaited(writer.submit(2).then((_) => lastDone = true));
    gated.gates[0].complete();
    await pumpEventQueue();
    expect(gated.started, [1, 2]);
    expect(firstDone, isFalse);
    expect(lastDone, isFalse);

    gated.gates[1].complete();
    await pumpEventQueue();
    expect(firstDone, isTrue);
    expect(lastDone, isTrue);
  });

  test('does not repeat a value that is already being written', () async {
    final gated = _Gated();
    final writer = LatestValueWriter<int>(gated.write);

    final done = [writer.submit(7), writer.submit(7), writer.submit(7)];
    gated.gates[0].complete();
    await Future.wait(done);
    expect(gated.started, [7]);
  });

  test('a value that differs from the one in flight is still written last', () async {
    final gated = _Gated();
    final writer = LatestValueWriter<int>(gated.write);

    final done = [writer.submit(1), writer.submit(2), writer.submit(1)];
    gated.gates[0].complete();
    await pumpEventQueue();
    gated.gates[1].complete();
    await Future.wait(done);
    expect(gated.started.last, 1);
  });

  test('a failed write is superseded by the write that follows it', () async {
    final started = <int>[];
    final writer = LatestValueWriter<int>((value) async {
      started.add(value);
      await Future<void>.delayed(Duration.zero);
      if (value == 1) throw StateError('stalled');
    });

    await writer.submit(1).then((_) {}, onError: (_) {}); // Alone, it fails.
    expect(started, [1]);

    final done = [writer.submit(1), writer.submit(2)];
    await Future.wait(done); // 2 succeeded after 1 failed: no error.
    expect(started, [1, 1, 2]);
  });

  test('the final write failing reaches every waiting caller', () async {
    final writer = LatestValueWriter<int>((value) async {
      await Future<void>.delayed(Duration.zero);
      if (value == 2) throw StateError('rejected');
    });

    final first = writer.submit(1);
    final last = writer.submit(2);
    await expectLater(first, throwsStateError);
    await expectLater(last, throwsStateError);
  });

  test('starts a new burst after the previous one drained', () async {
    final gated = _Gated();
    final writer = LatestValueWriter<int>(gated.write);

    final first = writer.submit(1);
    gated.gates[0].complete();
    await first;
    final second = writer.submit(1); // Not in flight any more: written again.
    expect(gated.started, [1, 1]);
    gated.gates[1].complete();
    await second;
  });
}
