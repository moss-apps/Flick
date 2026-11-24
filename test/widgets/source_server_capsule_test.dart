import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/features/player/widgets/source_server_capsule.dart';
import 'package:flick/models/song.dart';
import 'package:flick/providers/playlist_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song({String? sourceType, int? remoteServerId}) {
  return Song(
    id: 'song-1',
    title: 'Track',
    artist: 'Artist',
    duration: const Duration(minutes: 3),
    fileType: 'FLAC',
    sourceType: sourceType,
    remoteServerId: remoteServerId,
  );
}

NetworkServerEntity _server() {
  return NetworkServerEntity()
    ..id = 7
    ..label = 'Home NAS'
    ..protocol = 'jellyfin'
    ..baseUrl = 'https://example.test';
}

Widget _host(
  Song song,
  List<NetworkServerEntity> servers, {
  double width = 320,
}) {
  return ProviderScope(
    overrides: [networkServersProvider.overrideWith((ref) async => servers)],
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SourceServerCapsule(song: song),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing for local songs', (tester) async {
    await tester.pumpWidget(_host(_song(), const []));
    await tester.pumpAndSettle();

    expect(find.text('Home NAS'), findsNothing);
    expect(tester.getSize(find.byType(SourceServerCapsule)).height, 0);
  });

  testWidgets('shows the configured server name with accessible semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(_song(sourceType: 'jellyfin', remoteServerId: 7), [_server()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home NAS'), findsOneWidget);
    expect(find.bySemanticsLabel('Source: Home NAS'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('truncates long server names without overflowing', (
    tester,
  ) async {
    final server = _server()..label = 'A very long living room music server';
    await tester.pumpWidget(
      _host(_song(sourceType: 'jellyfin', remoteServerId: 7), [
        server,
      ], width: 120),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('A very long living room music server'), findsOneWidget);
  });
}
