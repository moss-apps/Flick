import 'package:http/http.dart' as http;

import '../../data/entities/network_server_entity.dart';
import '../../l10n/l10n.dart';
import 'network_credential_store.dart';

/// Endpoint rules for protocols that send reusable credentials.
///
/// HTTPS is required unless the user explicitly opts that server into plain
/// HTTP. The policy is enforced where credentials are read/sent, not only in
/// the settings form, so an old HTTP row fails closed after an upgrade.
class NetworkEndpointPolicy {
  const NetworkEndpointPolicy._();

  /// Validate [server] before any credentialed request. Throws a safe
  /// [NetworkCredentialException] when the endpoint is unusable.
  static Uri requireAllowed(NetworkServerEntity server) {
    final raw = server.baseUrl.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw NetworkCredentialException(l10n.serverUrlInvalid(server.label));
    }
    if (uri.userInfo.isNotEmpty) {
      throw NetworkCredentialException(l10n.serverUrlContainsCredentials);
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw NetworkCredentialException(l10n.serverUrlInvalid(server.label));
    }
    switch (uri.scheme.toLowerCase()) {
      case 'https':
        return uri;
      case 'http':
        if (server.allowInsecureHttp) return uri;
        throw NetworkCredentialException(l10n.serverRequiresHttps);
      default:
        throw NetworkCredentialException(
          l10n.serverUrlUnsupportedScheme(server.label),
        );
    }
  }

  /// True when [raw] is plain HTTP and would need an explicit opt-in.
  static bool isInsecureHttp(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null && uri.scheme.toLowerCase() == 'http';
  }

  /// HTTP client that never follows redirects automatically. A server could
  /// otherwise redirect a credentialed request from HTTPS to plain HTTP or to
  /// another origin. Services treat the resulting 3xx as a failed request and
  /// ask the user to correct the URL.
  static http.Client secureClient([http.Client? inner]) =>
      _NoRedirectClient(inner ?? http.Client());
}

class _NoRedirectClient extends http.BaseClient {
  _NoRedirectClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request
      ..followRedirects = false
      ..maxRedirects = 0;
    try {
      final response = await _inner.send(request);
      return http.StreamedResponse(
        response.stream.handleError((Object _) {
          throw http.ClientException('Network response failed');
        }),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on http.ClientException {
      // ClientException includes the request URI, which can contain Subsonic
      // query credentials. None of the error's remote text is safe to forward.
      throw http.ClientException('Network request failed');
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
