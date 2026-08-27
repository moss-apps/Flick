import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-keystore copy of a Jellyfin password, keyed by server id.
///
/// Jellyfin access tokens can die server-side (restart with a fresh
/// encryption key, password change, revoked session). The password lives
/// here — never in the Isar row — so a 401 during sync/stream silently
/// re-authenticates instead of forcing a manual re-entry.
class JellyfinPasswordStore {
  JellyfinPasswordStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(int serverId) => 'jellyfin_password_$serverId';

  Future<String?> read(int serverId) => _storage.read(key: _key(serverId));

  Future<void> write(int serverId, String password) =>
      _storage.write(key: _key(serverId), value: password);

  Future<void> delete(int serverId) => _storage.delete(key: _key(serverId));
}
