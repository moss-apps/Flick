import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Serves only the current cast track on the LAN, under a random URL. The
/// renderer never receives the credentials used to download a network file.
class CastContentServer {
  CastContentServer._();
  static final instance = CastContentServer._();

  static const _grantIdleTimeout = Duration(minutes: 30);
  static final _rangePattern = RegExp(r'^bytes=(\d*)-(\d*)$');

  Future<HttpServer>? _server;
  _ServedFile? _grant;
  int _generation = 0;
  final _rand = Random.secure();

  /// Serve [filePath] and return a LAN-reachable URL for it.
  ///
  /// Replaces the previous grant. Returns null if superseded or stopped.
  Future<String?> serve(String filePath, {required String filename}) async {
    final generation = ++_generation;
    _grant = null;
    final pending = _server ??= _bind();
    final HttpServer server;
    try {
      server = await pending;
    } catch (_) {
      if (identical(_server, pending)) _server = null;
      rethrow;
    }
    if (_generation != generation) return null;
    final ip = await _lanIp();
    if (_generation != generation) return null;
    final token = _token();
    _grant = _ServedFile(
      token,
      filePath,
      DateTime.now().add(_grantIdleTimeout),
    );
    return Uri(
      scheme: 'http',
      host: ip,
      port: server.port,
      pathSegments: [token, filename.replaceAll(RegExp(r'[^A-Za-z0-9._\- ]'), '')],
    ).toString();
  }

  Future<void> stop() async {
    _generation++;
    _grant = null;
    final pending = _server;
    _server = null;
    if (pending == null) return;
    try {
      await (await pending).close(force: true);
    } catch (_) {
      // A pending bind may have failed before there was a listener to close.
    }
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
    final grant = _grant;
    final now = DateTime.now();
    if (grant == null ||
        token != grant.token ||
        !grant.expiresAt.isAfter(now)) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    if (req.method != 'GET' && req.method != 'HEAD') {
      req.response.statusCode = HttpStatus.methodNotAllowed;
      req.response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      await req.response.close();
      return;
    }
    grant.expiresAt = now.add(_grantIdleTimeout);

    final path = grant.path;
    final file = File(path);
    if (!await file.exists()) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }
    final total = await file.length();
    final range = req.method == 'GET'
        ? req.headers.value(HttpHeaders.rangeHeader)
        : null;

    var start = 0;
    var end = total - 1;
    var status = HttpStatus.ok;
    final bounds = range == null ? null : _rangePattern.firstMatch(range);
    if (bounds != null) {
      final first = bounds.group(1)!;
      final last = bounds.group(2)!;
      if (first.isEmpty) {
        final suffix = int.tryParse(last) ?? 0;
        start = max(0, total - suffix);
      } else {
        start = int.tryParse(first) ?? total;
        if (last.isNotEmpty) end = min(end, int.tryParse(last) ?? end);
      }
      if (start > end) {
        req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        await req.response.close();
        return;
      }
      status = HttpStatus.partialContent;
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
    if (req.method == 'HEAD') {
      await req.response.close();
      return;
    }

    // ponytail: chunked manual copy; StreamedResponse plumbing adds nothing
    // for a LAN-local single consumer.
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      var remaining = length;
      const chunk = 64 * 1024;
      while (remaining > 0 && identical(_grant, grant)) {
        final read = await raf.read(min(chunk, remaining));
        if (read.isEmpty) break;
        if (!identical(_grant, grant)) break;
        req.response.add(read);
        remaining -= read.length;
        await req.response.flush();
        grant.expiresAt = DateTime.now().add(_grantIdleTimeout);
      }
    } finally {
      await raf.close();
      await req.response.close();
    }
  }
}

class _ServedFile {
  _ServedFile(this.token, this.path, this.expiresAt);

  final String token;
  final String path;
  DateTime expiresAt;
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
