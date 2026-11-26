import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/entities/network_server_entity.dart';
import '../../l10n/l10n.dart';

/// A protocol credential bundle stored in the Android Keystore-backed secure
/// storage. [secret] keeps the protocol-specific representation already used by
/// each client (JSON OAuth/token blob, `salt:md5hex`, or `base64(password)`).
///
/// The protocol/endpoint/account fields bind the secret to the server row it
/// was created for. If the row's destination changes without a fresh
/// credential, the bundle no longer matches and is never sent to the new host.
@immutable
class NetworkCredential {
  const NetworkCredential({
    required this.protocol,
    required this.baseUrl,
    required this.username,
    required this.secret,
    this.password,
  });

  NetworkCredential.forServer(
    NetworkServerEntity server,
    String secret, {
    String? password,
  }) : this(
         protocol: server.protocol,
         baseUrl: server.baseUrl,
         username: server.username,
         secret: secret,
         password: password,
       );

  final String protocol;
  final String baseUrl;
  final String? username;
  final String secret;
  final String? password;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'protocol': protocol,
    'baseUrl': NetworkCredentialStore.normalizeEndpoint(baseUrl),
    'username': NetworkCredentialStore._normalizeUsername(username),
    'secret': secret,
    if (password != null) 'password': password,
  };

  static NetworkCredential? tryParse(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      if (map['v'] != 1) return null;
      final protocol = map['protocol'];
      final baseUrl = map['baseUrl'];
      final secret = map['secret'];
      if (protocol is! String || baseUrl is! String || secret is! String) {
        return null;
      }
      final username = map['username'];
      final password = map['password'];
      return NetworkCredential(
        protocol: protocol,
        baseUrl: baseUrl,
        username: username is String ? username : null,
        secret: secret,
        password: password is String ? password : null,
      );
    } catch (_) {
      return null;
    }
  }

  bool matches(NetworkServerEntity server) => _matchesDestination(
    server,
    protocol: protocol,
    baseUrl: baseUrl,
    username: username,
  );

  NetworkCredential withSecret(String secret) => NetworkCredential(
    protocol: protocol,
    baseUrl: baseUrl,
    username: username,
    secret: secret,
    password: password,
  );
}

/// Thrown when a server row has no usable secure credential, or the stored
/// bundle belongs to a different protocol/endpoint/account.
///
/// The message is safe to show or log: it never contains credential material.
class NetworkCredentialException implements Exception {
  const NetworkCredentialException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Keystore-backed storage for network-source secrets.
///
/// Isar stores only [NetworkServerEntity.credentialRef], an opaque random id.
/// Only migration reads the legacy `token` value. Connection tests get their
/// own in-memory credentials, which are never serialized with a server row.
class NetworkCredentialStore {
  NetworkCredentialStore({
    FlutterSecureStorage? storage,
    Random? random,
    Future<bool> Function()? flush,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(
               storageNamespace: 'network_credentials',
               resetOnError: false,
             ),
           ),
       _random = random ?? Random.secure(),
       _flush = flush ?? (storage == null ? _flushAndroid : _noFlush);

  static final NetworkCredentialStore instance = NetworkCredentialStore();

  static const String _keyPrefix = 'network_credential_v1_';
  static const String _refPrefix = 'nc_';
  static const _channel = MethodChannel(
    'com.mossapps.flick/network_credentials',
  );

  final FlutterSecureStorage _storage;
  final Random _random;
  final Future<bool> Function() _flush;
  final _drafts = Expando<NetworkCredential>();
  final _refreshes = <Object, Future<NetworkCredential?>>{};
  final _mutations = <String, Future<void>>{};
  final _retired = <String>{};

  static Future<bool> _flushAndroid() async =>
      await _channel.invokeMethod<bool>('flush') ?? false;

  static Future<bool> _noFlush() async => true;

  /// Create a new opaque reference. This is safe to persist in Isar.
  String createRef() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return '$_refPrefix${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  /// Attach an unsaved credential to this particular form/test object.
  void setDraft(NetworkServerEntity server, NetworkCredential credential) {
    _checkBinding(server, credential);
    _drafts[server] = credential;
  }

  Future<NetworkCredential?> read(NetworkServerEntity server) async {
    final ref = server.credentialRef;
    if (ref != null) return _readRef(ref, server);
    final draft = _drafts[server];
    if (draft != null) {
      _checkBinding(server, draft);
      return draft;
    }
    if (server.token?.isNotEmpty ?? false) {
      throw NetworkCredentialException(l10n.credentialMissing(server.label));
    }
    return null;
  }

  /// Like [read], but throws a user-safe repair message when absent.
  Future<NetworkCredential> require(NetworkServerEntity server) async {
    final credential = await read(server);
    if (credential == null) {
      throw NetworkCredentialException(l10n.credentialMissing(server.label));
    }
    return credential;
  }

  /// Stage a fresh slot so a failed database write cannot replace the existing
  /// server's credential. The caller owns the new ref once this succeeds.
  ///
  /// Flush the encrypted preferences and verify the decrypted value before
  /// Isar is allowed to point at it or discard the legacy value.
  Future<String> stage(NetworkCredential credential) async {
    final ref = createRef();
    try {
      await _write(ref, credential);
      return ref;
    } catch (_) {
      await deleteRef(ref);
      rethrow;
    }
  }

  Future<void> _write(String ref, NetworkCredential credential) async {
    final encoded = jsonEncode(credential.toJson());
    final key = _keyFor(ref);
    try {
      await _storage.write(key: key, value: encoded);
      if (!await _flush() || await _storage.read(key: key) != encoded) {
        throw NetworkCredentialException(l10n.credentialStorageVerifyFailed);
      }
    } on NetworkCredentialException {
      rethrow;
    } catch (_) {
      throw NetworkCredentialException(l10n.credentialStorageSaveFailed);
    }
  }

  /// Coalesce concurrent renewals for one credential. [exchange] receives the
  /// latest bundle and can return its current secret if another request has
  /// already renewed it. Returning null indicates the session couldn't renew.
  Future<NetworkCredential?> refresh(
    NetworkServerEntity server,
    Future<String?> Function(NetworkCredential current) exchange,
  ) async {
    final ref = server.credentialRef;
    final slot = ref ?? server;
    final updated = await _refreshes.putIfAbsent(
      slot,
      () => _refresh(server, ref, exchange).whenComplete(() {
        _refreshes.remove(slot);
      }),
    );
    if (updated != null) {
      _checkBinding(server, updated);
      if (_retired.contains(ref)) {
        throw NetworkCredentialException(l10n.credentialMissing(server.label));
      }
    }
    return updated;
  }

  Future<NetworkCredential?> _refresh(
    NetworkServerEntity server,
    String? ref,
    Future<String?> Function(NetworkCredential current) exchange,
  ) async {
    final current = await require(server);
    final secret = await exchange(current);
    if (secret == null || secret == current.secret) {
      return secret == null ? null : current;
    }
    final updated = current.withSecret(secret);
    _checkBinding(server, updated);
    if (ref == null) {
      setDraft(server, updated);
    } else {
      await _mutate(ref, () async {
        // A server edited or removed during the exchange cannot be revived by
        // a late refresh. The network exchange itself doesn't hold this lock.
        await _readRef(ref, server);
        await _write(ref, updated);
      });
    }
    return updated;
  }

  Future<void> deleteRef(String? ref) async {
    if (ref == null) return;
    _retired.add(ref);
    await _mutate(ref, () async {
      try {
        await _storage.delete(key: _keyFor(ref));
      } catch (_) {
        // The slot is retired even if the plugin can't remove its ciphertext.
      }
    });
  }

  Future<void> _mutate(String ref, Future<void> Function() action) async {
    final previous = _mutations[ref];
    final done = Completer<void>();
    _mutations[ref] = done.future;
    try {
      await previous;
      await action();
    } finally {
      if (identical(_mutations[ref], done.future)) _mutations.remove(ref);
      done.complete();
    }
  }

  Future<NetworkCredential> _readRef(
    String ref,
    NetworkServerEntity server,
  ) async {
    String? raw;
    try {
      if (!_retired.contains(ref)) raw = await _storage.read(key: _keyFor(ref));
    } catch (_) {
      throw NetworkCredentialException(l10n.credentialStorageDecryptFailed);
    }
    if (raw == null || raw.isEmpty || _retired.contains(ref)) {
      throw NetworkCredentialException(l10n.credentialMissing(server.label));
    }
    final parsed = NetworkCredential.tryParse(raw);
    if (parsed == null) {
      throw NetworkCredentialException(l10n.credentialStorageUnreadable);
    }
    _checkBinding(server, parsed);
    return parsed;
  }

  void _checkBinding(NetworkServerEntity server, NetworkCredential credential) {
    if (!credential.matches(server)) {
      throw NetworkCredentialException(
        l10n.credentialServerMismatch(server.label),
      );
    }
  }

  String _keyFor(String ref) => '$_keyPrefix$ref';

  static String normalizeEndpoint(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');

  static String? _normalizeUsername(String? value) =>
      value == '' ? null : value;

  static bool sameDestination(
    NetworkServerEntity first,
    NetworkServerEntity second,
  ) => _matchesDestination(
    first,
    protocol: second.protocol,
    baseUrl: second.baseUrl,
    username: second.username,
  );
}

bool _matchesDestination(
  NetworkServerEntity server, {
  required String protocol,
  required String baseUrl,
  required String? username,
}) =>
    protocol == server.protocol &&
    NetworkCredentialStore.normalizeEndpoint(baseUrl) ==
        NetworkCredentialStore.normalizeEndpoint(server.baseUrl) &&
    NetworkCredentialStore._normalizeUsername(username) ==
        NetworkCredentialStore._normalizeUsername(server.username);
