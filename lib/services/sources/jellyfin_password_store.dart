import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Removes ID-only Jellyfin passwords saved by older builds. New passwords
/// are part of the endpoint-bound network credential bundle.
class JellyfinPasswordStore {
  JellyfinPasswordStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(int serverId) => 'jellyfin_password_$serverId';

  Future<void> delete(int serverId) => _storage.delete(key: _key(serverId));
}
