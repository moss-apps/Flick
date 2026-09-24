import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flick/providers/connectivity_provider.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeConnectivity connectivity;
  late ProviderContainer container;

  setUp(() {
    connectivity = _FakeConnectivity([ConnectivityResult.wifi]);
    container = ProviderContainer(
      overrides: [connectivityClientProvider.overrideWithValue(connectivity)],
    );
  });

  tearDown(() async {
    container.dispose();
    await connectivity.close();
  });

  Future<void> settleBootstrap() => Future<void>.delayed(Duration.zero);

  test('starts unknown and resolves online from the initial check', () async {
    expect(container.read(connectivityProvider), ConnectivityStatus.unknown);

    await settleBootstrap();

    expect(container.read(connectivityProvider), ConnectivityStatus.online);
  });

  test('resolves offline when the initial check has no interface', () async {
    connectivity.results = [ConnectivityResult.none];

    container.read(connectivityProvider);
    await settleBootstrap();

    expect(container.read(connectivityProvider), ConnectivityStatus.offline);
  });

  test('offline transition is debounced, recovery is immediate', () async {
    container.read(connectivityProvider);
    await settleBootstrap();
    expect(container.read(connectivityProvider), ConnectivityStatus.online);

    connectivity.emit([ConnectivityResult.none]);
    expect(container.read(connectivityProvider), ConnectivityStatus.online);

    await Future<void>.delayed(
      ConnectivityNotifier.offlineDebounce + const Duration(milliseconds: 100),
    );
    expect(container.read(connectivityProvider), ConnectivityStatus.offline);

    connectivity.emit([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(connectivityProvider), ConnectivityStatus.online);
  });

  test('brief drop within the debounce window stays online', () async {
    container.read(connectivityProvider);
    await settleBootstrap();

    connectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(
      ConnectivityNotifier.offlineDebounce ~/ 2,
    );
    connectivity.emit([ConnectivityResult.mobile]);
    await Future<void>.delayed(
      ConnectivityNotifier.offlineDebounce + const Duration(milliseconds: 100),
    );

    expect(container.read(connectivityProvider), ConnectivityStatus.online);
  });

  test('refresh performs a check and applies the result immediately', () async {
    connectivity.results = [ConnectivityResult.none];

    final isOnline = await container
        .read(connectivityProvider.notifier)
        .refresh();

    expect(isOnline, isFalse);
    expect(container.read(connectivityProvider), ConnectivityStatus.offline);
  });

  test('dispose cancels the connectivity subscription', () async {
    container.read(connectivityProvider);
    await settleBootstrap();

    container.dispose();

    connectivity.emit([ConnectivityResult.none]);
    await Future<void>.delayed(
      ConnectivityNotifier.offlineDebounce + const Duration(milliseconds: 100),
    );
  });
}
