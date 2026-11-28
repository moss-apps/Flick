import 'dart:async';

import 'package:flick/services/widget_intent_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.mossapps.flick/widget');
  const homeChannel = MethodChannel('home_widget');
  late WidgetIntentHandler handler;
  late int recapOpens;
  late int queueOpens;
  late int fullPlayerOpens;
  late int pluginLaunchReads;
  String? pendingUri;
  Completer<String?>? handshake;

  Future<void> mount(WidgetTester tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (_, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    handler = WidgetIntentHandler(
      widgetRef,
      onOpenRecap: () => recapOpens++,
      onOpenQueue: () => queueOpens++,
      onOpenFullPlayer: () => fullPlayerOpens++,
    );
    addTearDown(handler.detach);
  }

  Future<void> dispatch(
    WidgetTester tester,
    String method, [
    String? uri,
  ]) async {
    final reply = Completer<void>();
    tester.binding.channelBuffers.push(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, uri)),
      (_) => reply.complete(),
    );
    await reply.future;
  }

  setUp(() {
    recapOpens = queueOpens = fullPlayerOpens = pluginLaunchReads = 0;
    pendingUri = null;
    handshake = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'widgetHandlerDetached') return null;
      if (call.method == 'widgetHandlerReady') {
        if (handshake != null) return handshake!.future;
        final uri = pendingUri;
        pendingUri = null;
        return uri;
      }
      fail('Unexpected native widget call ${call.method}');
    });
    messenger.setMockMethodCallHandler(homeChannel, (call) async {
      expect(call.method, 'initiallyLaunchedFromHomeWidget');
      pluginLaunchReads++;
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(homeChannel, null);
  });

  testWidgets(
    'cold-start Replay taps drain once without relying on the plugin action',
    (tester) async {
      await mount(tester);
      pendingUri = 'flickwidget://recap/open';
      await handler.attach();
      expect(recapOpens, 1);
      expect(pluginLaunchReads, 0);
      await dispatch(tester, 'channelReady');
      expect(recapOpens, 1);
    },
  );

  testWidgets(
    'warm clicks preserve Queue and Replay routing and reject unrelated URIs',
    (tester) async {
      await mount(tester);
      await handler.attach();
      await dispatch(tester, 'dispatch', 'flickwidget://recap/open');
      await dispatch(tester, 'dispatch', 'flickwidget://queue/open');
      await dispatch(tester, 'dispatch', 'flickwidget://player/open');
      await dispatch(tester, 'dispatch', 'https://recap/open');
      await dispatch(tester, 'dispatch', 'flickwidget://recap/not-open');
      expect(recapOpens, 1);
      expect(queueOpens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Now Playing opens the full player on cold and warm taps', (
    tester,
  ) async {
    await mount(tester);
    pendingUri = 'flickwidget://player/full';
    await handler.attach();
    expect(fullPlayerOpens, 1);
    await dispatch(tester, 'channelReady');
    await dispatch(tester, 'dispatch', 'flickwidget://player/open');
    expect(fullPlayerOpens, 1);
    await dispatch(tester, 'dispatch', 'flickwidget://player/full');
    expect(fullPlayerOpens, 2);
  });

  testWidgets('cached engine reattachment drains the next tap only once', (
    tester,
  ) async {
    await mount(tester);
    await handler.attach();
    pendingUri = 'flickwidget://recap/open';
    await dispatch(tester, 'channelReady');
    await dispatch(tester, 'channelReady');
    expect(recapOpens, 1);
  });

  testWidgets('detaching during a pending handshake prevents late navigation', (
    tester,
  ) async {
    await mount(tester);
    handshake = Completer<String?>();
    final attaching = handler.attach();
    await tester.pump();
    await handler.detach();
    handshake!.complete('flickwidget://recap/open');
    await attaching;
    expect(recapOpens, 0);
    expect(pluginLaunchReads, 0);
  });
}
