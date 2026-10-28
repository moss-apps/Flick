/// Version of the metadata extraction pass used by the library scanner.
///
/// Bump this when the scanner starts reading a new embedded field so rows
/// written by an older pass are re-read on the next library scan.
const int kCurrentTrackMetadataVersion = 1;
