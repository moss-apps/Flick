import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flick/core/utils/dev_log.dart';
import 'package:flick/services/listenbrainz/listenbrainz_credentials.dart';

/// ListenBrainz API configuration.
class ListenBrainzConfig {
  static const String baseUrl = 'https://api.listenbrainz.org';
}

/// Thrown when ListenBrainz returns an error response.
class ListenBrainzApiException implements Exception {
  const ListenBrainzApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ListenBrainzApiException($statusCode): $message';
}

/// Thrown when the caller is rate limited (HTTP 429).
class ListenBrainzRateLimitException implements Exception {
  const ListenBrainzRateLimitException(this.retryAfterSeconds);

  final int retryAfterSeconds;

  @override
  String toString() =>
      'ListenBrainzRateLimitException: retry after $retryAfterSeconds seconds';
}

/// Thrown when a ListenBrainz operation requires a token but none is available.
class ListenBrainzNoTokenException implements Exception {
  @override
  String toString() => 'ListenBrainzNoTokenException: no user token configured';
}

/// Tracks ListenBrainz rate limit headers across requests.
class _RateLimitTracker {
  int? _remaining;
  DateTime? _resetAt;

  /// Updates state from response headers.
  void update(Map<String, String> headers) {
    final remainingRaw = headers['x-ratelimit-remaining'];
    final resetInRaw = headers['x-ratelimit-reset-in'];

    if (remainingRaw != null) {
      _remaining = int.tryParse(remainingRaw);
    }

    if (resetInRaw != null) {
      final resetInSeconds = int.tryParse(resetInRaw);
      if (resetInSeconds != null) {
        _resetAt = DateTime.now().add(Duration(seconds: resetInSeconds));
      }
    }
  }

  /// Waits until the current rate limit window resets if we are out of calls.
  Future<void> maybeWait() async {
    if (_remaining == null || _remaining! > 0) return;

    final resetAt = _resetAt;
    if (resetAt == null) return;

    final wait = resetAt.difference(DateTime.now());
    if (wait.inMilliseconds > 0) {
      devLog(
        '[ListenBrainz] rate limit hit, waiting ${wait.inSeconds}s until reset',
      );
      await Future<void>.delayed(wait + const Duration(milliseconds: 100));
    }
  }
}

/// Low-level HTTP client for ListenBrainz API.
/// Handles `Authorization: Token <token>` headers and rate limit tracking.
class ListenBrainzApiClient {
  ListenBrainzApiClient({ListenBrainzCredentials? credentials})
    : _credentials = credentials ?? ListenBrainzCredentials();

  final ListenBrainzCredentials _credentials;
  final _rateLimit = _RateLimitTracker();

  Future<String> _getToken() async {
    final token = await _credentials.getUserToken();
    if (token == null || token.isEmpty) {
      throw ListenBrainzNoTokenException();
    }
    return token;
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Token $token',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(String path) async {
    await _rateLimit.maybeWait();
    final token = await _getToken();

    final response = await http.get(
      Uri.parse('${ListenBrainzConfig.baseUrl}$path'),
      headers: {'Authorization': 'Token $token'},
    );

    _rateLimit.update(response.headers);
    return _parse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _rateLimit.maybeWait();
    final token = await _getToken();

    final response = await http.post(
      Uri.parse('${ListenBrainzConfig.baseUrl}$path'),
      headers: _headers(token),
      body: body == null ? null : jsonEncode(body),
    );

    _rateLimit.update(response.headers);
    return _parse(response);
  }

  Map<String, dynamic> _parse(http.Response response) {
    if (response.statusCode == 429) {
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '') ??
          int.tryParse(response.headers['x-ratelimit-reset-in'] ?? '') ??
          60;
      throw ListenBrainzRateLimitException(retryAfter);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ListenBrainzApiException(
        response.statusCode,
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      );
    }

    if (response.body.isEmpty) {
      return {};
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Some LB error responses still come back with HTTP 200 and a message/code.
    if (data['valid'] == false) {
      throw ListenBrainzApiException(
        401,
        data['message'] as String? ?? 'Invalid token',
      );
    }

    return data;
  }
}
