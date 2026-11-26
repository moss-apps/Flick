import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/services/casting/cast_content_server.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('serves full, partial, and rejected ranges', () async {
    await binding.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('cast_server');
      final file = File('${dir.path}/track.m4a');
      final bytes = List<int>.generate(100, (i) => i);
      await file.writeAsBytes(bytes);

      final server = CastContentServer.instance;
      addTearDown(() async {
        await server.stop();
        await dir.delete(recursive: true);
      });
      final url = await server.serve(file.path, filename: 'track.m4a');
      final uri = Uri.parse(url!).replace(host: '127.0.0.1');
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      Future<HttpClientResponse> get(Map<String, String> headers) async {
        final req = await client.getUrl(uri);
        headers.forEach(req.headers.set);
        return await req.close();
      }

      Future<List<int>> body(HttpClientResponse r) =>
          r.fold<List<int>>([], (p, c) => p..addAll(c));

      final full = await get({});
      expect(full.statusCode, 200);
      expect(full.headers.value(HttpHeaders.contentLengthHeader), '100');
      expect(await body(full), bytes);

      final part = await get({HttpHeaders.rangeHeader: 'bytes=10-19'});
      expect(part.statusCode, 206);
      expect(await body(part), bytes.sublist(10, 20));
      expect(
        part.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 10-19/100',
      );

      final openEnded = await get({HttpHeaders.rangeHeader: 'bytes=90-'});
      expect(openEnded.statusCode, 206);
      expect(await body(openEnded), bytes.sublist(90));

      final suffix = await get({HttpHeaders.rangeHeader: 'bytes=-5'});
      expect(suffix.statusCode, 206);
      expect(await body(suffix), bytes.sublist(95));

      final head = await (await client.headUrl(uri)).close();
      expect(head.contentLength, 100);
      expect(await body(head), isEmpty);

      final invalid = await get({HttpHeaders.rangeHeader: 'bytes=500-'});
      expect(invalid.statusCode, 416);
      await invalid.drain<void>();

      final req = await client.getUrl(uri.replace(path: '/deadbeef/x.m4a'));
      final notFound = await req.close();
      expect(notFound.statusCode, 404);
      await notFound.drain<void>();

      final replacement = await server.serve(file.path, filename: 'next.m4a');
      expect(
        Uri.parse(replacement!).pathSegments.first,
        isNot(uri.pathSegments.first),
      );
      final retired = await get({});
      expect(retired.statusCode, 404);
      await retired.drain<void>();
    });
  });

  test('stopping while a grant is being published cancels it', () async {
    final server = CastContentServer.instance;
    final pending = server.serve('/unused.flac', filename: 'unused.flac');
    await server.stop();
    expect(await pending, isNull);
  });
}
