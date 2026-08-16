import 'dart:async';
import 'dart:io';
import 'dart:math';

// ponytail: one-file embedded HTTP server so the renderer can pull bytes from
// the phone. Covers local files and SMB/cached sources that have no LAN URL.
// Token paths on a home LAN are enough auth; add TLS/pins if this ever leaves
// the house.
class CastContentServer {
  CastContentServer._();
  static final instance = CastContentServer._();

  HttpServer? _server;
  final Map<String, String> _paths = {};
  final _rand = Random.secure();

  /// Serve [filePath] and return a LAN-reachable URL for it.
  Future<String> serve(String filePath, {required String filename}) async {
    final server = _server ??= await _bind();
    final token = _token();
    _paths[token] = filePath;
    final ip = await _lanIp();
    final safe = Uri.encodeComponent(
      filename.replaceAll(RegExp(r'[^A-Za-z0-9._\- ]'), ''),
    );
    return 'http://$ip:${server.port}/$token/$safe';
  }

  Future<void> stop() async {
    _paths.clear();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  String _token() {
    final bytes = List<int>.generate(16, (_) => _rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<HttpServer> _bind() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    server.listen((req) {
      _handle(req).catchError((_) {
        try {
          req.response.close();
        } catch (_) {}
      });
    }, onError: (_) {});
    return server;
  }

  Future<String> _lanIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final it in interfaces) {
      for (final addr in it.addresses) {
        final s = addr.address;
        if (s.startsWith('192.168.') ||
            s.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(s)) {
          return s;
        }
      }
    }
    // Virtual/odd adapters only: fall back to the first IPv4 that isn't loopback.
    return interfaces.first.addresses.first.address;
  }

  Future<void> _handle(HttpRequest req) async {
    final token = req.uri.pathSegments.isNotEmpty
        ? req.uri.pathSegments.first
        : '';
    final path = _paths[token];
    if (path == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final total = await file.length();
    final range = req.headers.value(HttpHeaders.rangeHeader);

    var start = 0;
    var end = total - 1;
    var status = HttpStatus.ok;
    if (range != null) {
      final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
      if (m != null) {
        if (m.group(1)!.isNotEmpty) start = int.parse(m.group(1)!);
        if (m.group(2)!.isNotEmpty) end = int.parse(m.group(2)!);
        if (start >= total) {
          req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          req.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$total',
          );
          await req.response.close();
          return;
        }
        if (m.group(2)!.isEmpty) end = total - 1;
        status = HttpStatus.partialContent;
      }
    }

    final length = end - start + 1;
    req.response.statusCode = status;
    req.response.headers.contentType = _contentTypeFor(path);
    req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    req.response.headers.set(HttpHeaders.contentLengthHeader, '$length');
    if (status == HttpStatus.partialContent) {
      req.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$total',
      );
    }

    // ponytail: chunked manual copy; StreamedResponse plumbing adds nothing
    // for a LAN-local single consumer.
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      var remaining = length;
      const chunk = 64 * 1024;
      while (remaining > 0) {
        final read = await raf.read(min(chunk, remaining));
        if (read.isEmpty) break;
        req.response.add(read);
        remaining -= read.length;
        await req.response.flush();
      }
    } finally {
      await raf.close();
      await req.response.close();
    }
  }
}

ContentType _contentTypeFor(String path) {
  final ext = path.lastIndexOf('.') == -1
      ? ''
      : path.substring(path.lastIndexOf('.') + 1).toLowerCase();
  return switch (ext) {
    'mp3' => ContentType.parse('audio/mpeg'),
    'flac' => ContentType.parse('audio/flac'),
    'wav' => ContentType.parse('audio/wav'),
    'ogg' || 'oga' || 'opus' => ContentType.parse('audio/ogg'),
    'm4a' || 'mp4' || 'aac' => ContentType.parse('audio/mp4'),
    'aiff' || 'aif' => ContentType.parse('audio/aiff'),
    'wv' => ContentType.parse('audio/x-wavpack'),
    'dsf' || 'dff' => ContentType.parse('audio/dsd'),
    _ => ContentType.binary,
  };
}
