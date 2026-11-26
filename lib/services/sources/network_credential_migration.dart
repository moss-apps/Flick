import 'package:isar_community/isar.dart';

import '../../core/utils/app_log.dart';
import '../../data/database.dart';
import 'jellyfin_password_store.dart';
import 'network_credential_store.dart';
import 'network_source_service.dart';

/// One-way migration from the legacy plaintext Isar `token` column into the
/// Android Keystore-backed [NetworkCredentialStore].
///
/// Each row is staged and verified before a transaction can set
/// [NetworkServerEntity.credentialRef] and clear `token`. A failed migration
/// leaves the row in place so the next startup can retry. Network requests do
/// not fall back to that token, and the DB is excluded from Android backups.
class NetworkCredentialMigration {
  const NetworkCredentialMigration._();

  static Future<void> run({
    Isar? isar,
    NetworkCredentialStore? store,
    JellyfinPasswordStore? legacyPasswords,
  }) async {
    isar ??= Database.instance;
    final credentials = store ?? NetworkCredentialStore.instance;
    final passwords = legacyPasswords ?? JellyfinPasswordStore();
    final collection = isar.networkServerEntitys;
    List<NetworkServerEntity> servers;
    try {
      servers = await collection.where().findAll();
    } catch (e) {
      AppLog.instance.add(
        'Network credential migration could not read servers (${e.runtimeType})',
      );
      return;
    }

    for (final server in servers) {
      final legacy = server.token;
      if (legacy == null) continue;
      String? stagedRef;
      var committed = false;
      try {
        // If a secure ref already exists, leave it alone and clear only the
        // obsolete column after confirming the bound credential is usable.
        final currentRef = server.credentialRef;
        if (currentRef != null) {
          await credentials.require(server);
        } else if (legacy.isNotEmpty &&
            server.protocol != NetworkProtocol.upnp) {
          stagedRef = await credentials.stage(
            NetworkCredential.forServer(server, legacy),
          );
        }
        committed = await isar.writeTxn(() async {
          final row = await collection.get(server.id);
          if (row == null ||
              row.token != legacy ||
              row.credentialRef != currentRef ||
              !NetworkCredentialStore.sameDestination(row, server)) {
            return false;
          }
          row
            ..credentialRef = currentRef ?? stagedRef
            ..token = null;
          await collection.put(row);
          return true;
        });
        // Legacy Jellyfin passwords were associated only with the row ID.
        // Older builds allowed endpoint edits without a new password, so
        // their origin cannot be verified. Migrate the token; require a fresh
        // password if the user later needs to sign in again.
        if (committed && server.protocol == NetworkProtocol.jellyfin) {
          await passwords.delete(server.id);
        }
      } catch (e) {
        AppLog.instance.add(
          'Network credential migration for server ${server.id} '
          '${committed ? 'could not remove old password' : 'failed'} '
          '(${e.runtimeType})',
        );
      } finally {
        if (!committed) await credentials.deleteRef(stagedRef);
      }
    }
  }
}
