class Playlist {
  /// URI scheme used in [sourcePath] for playlists mirrored from a Subsonic
  /// server: `subsonic://<serverId>/<remotePlaylistId>`.
  static const String networkSourceScheme = 'subsonic';

  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? sourcePath;

  /// Timestamp of when each song was added to this playlist, keyed by song id.
  /// Songs without an entry (legacy playlists, imported lists) fall back to
  /// their position in [songIds] when sorting by "Date Added".
  final Map<String, DateTime> songAddedAt;

  /// True when this playlist is a mirror of a server-side (Subsonic) playlist.
  bool get isNetworkSource {
    final path = sourcePath;
    return path != null && path.startsWith('$networkSourceScheme://');
  }

  /// [NetworkServerEntity.id] of the owning server, null for local playlists.
  int? get networkServerId {
    final path = sourcePath;
    if (path == null) return null;
    final rest = path.startsWith('$networkSourceScheme://')
        ? path.substring('$networkSourceScheme://'.length)
        : '';
    final slash = rest.indexOf('/');
    return int.tryParse(slash == -1 ? rest : rest.substring(0, slash));
  }

  /// The server-assigned playlist id, null for local playlists.
  String? get networkRemoteId {
    final path = sourcePath;
    if (path == null) return null;
    final rest = path.startsWith('$networkSourceScheme://')
        ? path.substring('$networkSourceScheme://'.length)
        : '';
    final slash = rest.indexOf('/');
    if (slash == -1 || slash == rest.length - 1) return null;
    return rest.substring(slash + 1);
  }

  const Playlist({
    required this.id,
    required this.name,
    this.songIds = const [],
    required this.createdAt,
    this.updatedAt,
    this.sourcePath,
    this.songAddedAt = const {},
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sourcePath,
    Map<String, DateTime>? songAddedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourcePath: sourcePath ?? this.sourcePath,
      songAddedAt: songAddedAt ?? this.songAddedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songIds': songIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'sourcePath': sourcePath,
      'songAddedAt': {
        for (final entry in songAddedAt.entries)
          entry.key: entry.value.toIso8601String(),
      },
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawAddedAt = json['songAddedAt'] as Map<String, dynamic>? ?? {};
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: (json['songIds'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      sourcePath: json['sourcePath'] as String?,
      songAddedAt: {
        for (final entry in rawAddedAt.entries)
          entry.key: DateTime.parse(entry.value as String),
      },
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Playlist(id: $id, name: $name, songCount: ${songIds.length})';
  }
}
