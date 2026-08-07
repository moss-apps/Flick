enum CastBackend { dlna, chromecast }

class CastDevice {
  final String id;
  final String name;
  final CastBackend backend;
  final String? locationUrl;
  final String? iconUrl;
  final bool supportsVolume;

  const CastDevice({
    required this.id,
    required this.name,
    required this.backend,
    this.locationUrl,
    this.iconUrl,
    this.supportsVolume = true,
  });

  @override
  bool operator ==(Object other) => other is CastDevice && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
