/// Case-insensitive compare for user-facing alphabetical sorts.
/// Falls back to a case-sensitive compare so equal-ignoring-case strings
/// (e.g. 'Alpha' vs 'alpha') still order deterministically.
int compareCaseInsensitive(String a, String b) {
  final c = a.toLowerCase().compareTo(b.toLowerCase());
  if (c != 0) return c;
  return a.compareTo(b);
}
