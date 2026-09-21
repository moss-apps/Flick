import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/providers/songs_provider.dart';

void main() {
  late StreamController<void> changes;
  late ProviderContainer container;
  late List<int> revisions;

  setUp(() {
    changes = StreamController<void>.broadcast();
    container = ProviderContainer(
      overrides: [songLibraryWatchProvider.overrideWithValue(changes.stream)],
    );
  });

  tearDown(() {
    container.dispose();
    changes.close();
  });

  void listen() {
    revisions = <int>[];
    container.listen(libraryChangeRevisionProvider, (previous, next) {
      final revision = next.value;
      if (revision != null) revisions.add(revision);
    });
  }

  testWidgets('emits only after the throttle window', (tester) async {
    listen();

    changes.add(null);
    await tester.pump(const Duration(milliseconds: 200));
    expect(revisions, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    expect(revisions, [1]);
  });

  testWidgets('coalesces bursts and emits a trailing revision', (
    tester,
  ) async {
    listen();

    changes.add(null);
    await tester.pump(const Duration(milliseconds: 100));
    changes.add(null);
    await tester.pump(const Duration(milliseconds: 100));
    changes.add(null);
    await tester.pump(const Duration(milliseconds: 400));

    // Three writes, one revision so far.
    expect(revisions, [1]);

    // The write that landed mid-window produces the trailing revision.
    await tester.pump(const Duration(milliseconds: 500));
    expect(revisions, [1, 2]);
  });

  testWidgets('stays silent when the library never changes', (tester) async {
    listen();

    await tester.pump(const Duration(seconds: 2));
    expect(revisions, isEmpty);
  });
}
