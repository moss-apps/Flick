// just_audio's streaming API keeps upstream credentials out of player URLs.
// ignore_for_file: experimental_member_use

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../l10n/l10n.dart';
import 'sources/network_endpoint_policy.dart';

/// Streams the original file through just_audio's existing loopback server.
/// ExoPlayer receives only the loopback URL; Dart owns the upstream credentials
/// and makes each request without following redirects.
class AuthenticatedHttpAudioSource extends StreamAudioSource {
  AuthenticatedHttpAudioSource({required this.resolve, http.Client? client})
    : _client = client == null
          ? _sharedClient
          : NetworkEndpointPolicy.secureClient(client);

  final Future<({String url, Map<String, String> headers})?> Function() resolve;
  final http.Client _client;

  static final _sharedClient = NetworkEndpointPolicy.secureClient();
  static final _contentRange = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // Re-read the current server settings and credentials instead of keeping
    // a token in a queued AudioSource after an edit or a session renewal.
    final source = await resolve();
    final uri = source == null ? null : Uri.tryParse(source.url);
    if (source == null || uri == null) {
      throw StateError(l10n.couldNotReachTheServer);
    }
    final ranged = start != null || end != null;
    final request = http.Request('GET', uri)
      ..headers.addAll(source.headers)
      ..headers['Accept-Encoding'] = 'identity';
    if (ranged) {
      request.headers['Range'] =
          'bytes=${start ?? 0}-${end == null ? '' : end - 1}';
    }
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final contentType =
        response.headers['content-type'] ?? 'application/octet-stream';
    if (response.statusCode == 200) {
      return StreamAudioResponse(
        rangeRequestsSupported: response.headers['accept-ranges'] == 'bytes',
        sourceLength: null,
        contentLength: response.contentLength,
        offset: null,
        stream: response.stream,
        contentType: contentType,
      );
    }
    if (response.statusCode == 206 && ranged) {
      final match = _contentRange.firstMatch(
        response.headers['content-range'] ?? '',
      );
      final offset = int.tryParse(match?.group(1) ?? '');
      final last = int.tryParse(match?.group(2) ?? '');
      final total = int.tryParse(match?.group(3) ?? '');
      if (offset == (start ?? 0) &&
          offset != null &&
          last != null &&
          last >= offset &&
          (end == null || last < end) &&
          (total == null || total > last)) {
        return StreamAudioResponse(
          sourceLength: total,
          contentLength: last - offset + 1,
          offset: offset,
          stream: response.stream,
          contentType: contentType,
        );
      }
    }
    await response.stream.listen(null).cancel();
    // just_audio logs request failures. Never attach the upstream URL or body.
    throw StateError(
      'Network audio request failed (HTTP ${response.statusCode})',
    );
  }
}
