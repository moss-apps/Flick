/// Best-effort redaction for text written to device logs or exported by Flick.
///
/// This is defense in depth, not a substitute for not logging secrets in the
/// first place. It catches the common URL query, Authorization header, and JSON
/// shapes used by Last.fm, Jellyfin, Subsonic, WebDAV, and OAuth clients.
final _urlCredentials = RegExp(
  r'([?&](?:api_key|api_sig|token|session_key|password|pass|pw|access_token|refresh_token|client_secret|device_code|t|s)=)[^&\s#"<>]+',
  caseSensitive: false,
);
final _authHeader = RegExp(
  r'\b(Bearer|Basic|Authorization"?\s*:\s*"?Token)\s+[A-Za-z0-9._~+/=-]+',
  caseSensitive: false,
);
final _quotedCredential = RegExp(
  r'("(?:access_token|refresh_token|token|api_key|session_key|password|secret|client_secret|device_code|pw)"\s*:\s*"|\btoken\s*=\s*")(?:[^"\\]|\\.)*(")',
  caseSensitive: false,
);
final _bareCredential = RegExp(
  r'\b(api_key|api_sig|token|session_key|password|access_token|refresh_token|secret|client_secret|device_code)=(?!["<])[^\s&,;"<>]+',
  caseSensitive: false,
);
final _lastFmToken = RegExp(
  r'(\[LastFm\] getTokenAndLaunchAuth: Token received: ).+',
);
final _legacyLastFmAuthError = RegExp(
  r'(\[LastFm\] (?:(?:_startAuth|_completeAuth|exchangeTokenForSession): ERROR - |'
  r'getTokenAndLaunchAuth: ERROR during (?:launch|token request) - ))[\s\S]+',
);
final _tidalLink = RegExp(
  r'\b(https?://)?link\.tidal\.com/[^\s"<>]+',
  caseSensitive: false,
);
final _legacyTidalResponse = RegExp(
  r'(\[Tidal\] POST [^\s]+ -> HTTP \d{3}):[\s\S]*',
);

String redactSensitiveLogText(String input) {
  if (input.isEmpty) return input;
  return input
      .replaceAllMapped(_legacyTidalResponse, (m) => '${m[1]}: <redacted>')
      .replaceAllMapped(_legacyLastFmAuthError, (m) => '${m[1]}<redacted>')
      .replaceAllMapped(_lastFmToken, (m) => '${m[1]}<redacted>')
      .replaceAll(_tidalLink, 'link.tidal.com/<redacted>')
      .replaceAllMapped(_urlCredentials, (m) => '${m[1]}<redacted>')
      .replaceAllMapped(_authHeader, (m) => '${m[1]} <redacted>')
      .replaceAllMapped(_quotedCredential, (m) => '${m[1]}<redacted>${m[2]}')
      .replaceAllMapped(_bareCredential, (m) => '${m[1]}=<redacted>');
}
