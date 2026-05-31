String decodeUriDisplayComponent(String value) {
  var decoded = value;

  for (var i = 0; i < 3; i++) {
    try {
      final next = Uri.decodeComponent(decoded);
      if (next == decoded) break;
      decoded = next;
    } on ArgumentError {
      break;
    }
  }

  return decoded;
}

List<String> decodedUriPathSegments(Uri uri) {
  return uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .map(decodeUriDisplayComponent)
      .toList();
}
