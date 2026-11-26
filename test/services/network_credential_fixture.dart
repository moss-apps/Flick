import 'package:flick/data/entities/network_server_entity.dart';
import 'package:flick/services/sources/network_credential_store.dart';

NetworkServerEntity withCredential(
  NetworkServerEntity server,
  String? secret, {
  String? password,
}) {
  if (secret != null) {
    NetworkCredentialStore.instance.setDraft(
      server,
      NetworkCredential.forServer(server, secret, password: password),
    );
  }
  return server;
}
