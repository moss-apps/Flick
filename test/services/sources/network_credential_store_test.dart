import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/network_credential_migration.dart';
import 'package:flick/services/sources/network_credential_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../isar_core_test_helper.dart';

NetworkServerEntity _server(int id) => NetworkServerEntity()
  ..id = id
  ..label = 'Server $id'
  ..protocol = 'subsonic'
  ..baseUrl = 'https://server-$id.example.com'
  ..username = 'demo';

void main() {
  const storage = FlutterSecureStorage();
  final repairError = throwsA(isA<NetworkCredentialException>());
  late NetworkCredentialStore store;
  late bool flushSucceeds;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    flushSucceeds = true;
    store = NetworkCredentialStore(
      storage: storage,
      flush: () async => flushSucceeds,
    );
  });

  test('a staged replacement leaves the saved credential untouched', () async {
    final server = _server(7);
    final original = NetworkCredential.forServer(server, 'salt:original');
    final firstRef = await store.stage(original);
    server.credentialRef = firstRef;

    final secondRef = await store.stage(
      original.withSecret('salt:replacement'),
    );

    expect(secondRef, isNot(firstRef));
    expect(secondRef, isNot(contains('replacement')));
    expect((await store.require(server)).secret, 'salt:original');

    server.credentialRef = secondRef;
    await store.deleteRef(firstRef);
    final loaded = await store.require(server);
    expect(loaded.secret, 'salt:replacement');
    expect(loaded.matches(server), isTrue);
    expect(await storage.readAll(), hasLength(1));
    expect(server.token, isNull);
  });

  test('a plaintext legacy value is unusable before migration', () async {
    final server = _server(7)..token = 'salt:legacy';
    await expectLater(store.read(server), repairError);
    expect(await storage.readAll(), isEmpty);
  });

  test(
    'a missing bundle and a changed account or endpoint are rejected',
    () async {
      final server = _server(7)..credentialRef = 'nc_missing';
      await expectLater(store.read(server), repairError);

      server.credentialRef = await store.stage(
        NetworkCredential.forServer(server, 'salt:original'),
      );
      server.username = 'other-account';
      await expectLater(store.read(server), repairError);

      server
        ..username = 'demo'
        ..baseUrl = 'https://other.example.com';
      await expectLater(store.read(server), repairError);
    },
  );

  test('a failed storage flush discards the unverified slot', () async {
    final server = _server(7);
    flushSucceeds = false;

    await expectLater(
      store.stage(NetworkCredential.forServer(server, 'salt:original')),
      repairError,
    );
    expect(await storage.readAll(), isEmpty);
  });

  test('a refresh started before deletion cannot recreate the slot', () async {
    final server = _server(7);
    server.credentialRef = await store.stage(
      NetworkCredential.forServer(server, 'salt:original'),
    );
    final started = Completer<void>();
    final response = Completer<String>();
    final pending = store.refresh(server, (current) {
      expect(current.secret, 'salt:original');
      started.complete();
      return response.future;
    });
    final checked = expectLater(pending, repairError);

    await started.future;
    await store.deleteRef(server.credentialRef);
    response.complete('salt:too-late');
    await checked;

    expect(await storage.readAll(), isEmpty);
  });

  final library = findIsarCoreLibrary();
  test(
    'migration retries failed writes and keeps each server ID and binding',
    () async {
      Isar.initializeIsarCore(libraries: {Abi.current(): library!});
      final directory = await Directory.systemTemp.createTemp(
        'flick_credentials',
      );
      addTearDown(() => directory.delete(recursive: true));
      final isar = await Isar.open([
        NetworkServerEntitySchema,
      ], directory: directory.path);
      addTearDown(() => isar.close());
      final first = _server(7)
        ..token = 'salt:legacy-first'
        ..lastSyncedAt = DateTime.utc(2025, 10, 3, 12);
      final second = _server(8)..token = 'salt:legacy-second';
      final rows = isar.networkServerEntitys;
      await isar.writeTxn(() => rows.putAll([first, second]));

      flushSucceeds = false;
      await NetworkCredentialMigration.run(isar: isar, store: store);
      final failed = (await rows.get(7))!;
      expect(failed.credentialRef, isNull);
      expect(failed.token, first.token);
      await expectLater(store.read(failed), repairError);

      flushSucceeds = true;
      await NetworkCredentialMigration.run(isar: isar, store: store);
      final migrated = (await rows.get(7))!;
      final other = (await rows.get(8))!;
      expect(migrated.label, first.label);
      expect(
        migrated.lastSyncedAt!.isAtSameMomentAs(first.lastSyncedAt!),
        isTrue,
      );
      expect(migrated.token, isNull);
      expect(other.token, isNull);
      expect(migrated.credentialRef, isNot(other.credentialRef));
      expect((await store.require(migrated)).secret, first.token);
      expect((await store.require(other)).secret, second.token);

      await NetworkCredentialMigration.run(isar: isar, store: store);
      expect((await rows.get(7))!.credentialRef, migrated.credentialRef);
      expect(await storage.readAll(), hasLength(2));
    },
    skip: library == null
        ? 'Set ISAR_CORE_LIB to run the migration test'
        : false,
  );
}
