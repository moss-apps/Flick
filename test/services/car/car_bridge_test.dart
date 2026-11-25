import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/car/car_bridge.dart';

void main() {
  group('CarChangeCoalescer', () {
    const window = Duration(milliseconds: 40);
    const settle = Duration(milliseconds: 120);

    test('a burst of one kind becomes one call', () async {
      final sent = <String>[];
      final coalescer = CarChangeCoalescer(send: sent.add, window: window);

      for (var i = 0; i < 20; i++) {
        coalescer.notify('queue');
      }
      expect(sent, isEmpty);

      await Future<void>.delayed(settle);
      expect(sent, ['queue']);
      coalescer.dispose();
    });

    test('kinds are coalesced independently', () async {
      final sent = <String>[];
      final coalescer = CarChangeCoalescer(send: sent.add, window: window);

      coalescer.notify('queue');
      coalescer.notify('modes');
      coalescer.notify('queue');
      coalescer.notify('track');
      coalescer.notify('modes');

      await Future<void>.delayed(settle);
      expect(sent.toSet(), {'queue', 'modes', 'track'});
      expect(sent, hasLength(3));
      coalescer.dispose();
    });

    test('a notification after the window sends again', () async {
      final sent = <String>[];
      final coalescer = CarChangeCoalescer(send: sent.add, window: window);

      coalescer.notify('library');
      await Future<void>.delayed(settle);
      coalescer.notify('library');
      await Future<void>.delayed(settle);

      expect(sent, ['library', 'library']);
      coalescer.dispose();
    });

    test('dispose drops what is pending', () async {
      final sent = <String>[];
      final coalescer = CarChangeCoalescer(send: sent.add, window: window);

      coalescer.notify('queue');
      coalescer.dispose();

      await Future<void>.delayed(settle);
      expect(sent, isEmpty);
    });

    test('the default window is 150 ms', () {
      final coalescer = CarChangeCoalescer(send: (_) {});
      expect(coalescer.window, const Duration(milliseconds: 150));
    });
  });
}
