import 'dart:async';
import 'dart:convert';

import '../../core/utils/app_log.dart';
import '../../data/entities/network_server_entity.dart';
import '../library_scanner_service.dart' show ScanProgress;
import 'network_source_service.dart';

/// SMB placeholder.
///
/// SMB2/3 has no mature pure-Dart client, and the candidate Rust crates either
/// link the system `libsmbclient` (unavailable on Android NDK) or are
/// experimental and don't build cleanly on mobile. Rather than ship a fake
/// transport, this service is wired through the registry so every flow fails
/// loudly with a clear, honest message. Landing a real transport is then a
/// localized change: implement [ping]/[stream]/[syncLibrary] and the UI works.
///
/// Recommended workaround for SMB shares: expose them over WebDAV (many NAS
/// firmwares do this out of the box) and add a WebDAV server instead.
class SmbService implements NetworkSourceService {
  SmbService._();
  static SmbService instance = SmbService._();

  static const String _unavailableMessage =
      'SMB playback is not available in this build. Use a Subsonic, Jellyfin, '
      'WebDAV, or UPnP/DLNA server, or expose the SMB share over WebDAV.';

  @override
  String get protocol => NetworkProtocol.smb;

  @override
  String get coverScheme => 'smb-cover://';

  @override
  Future<String?> resolveToken(
    NetworkServerEntity server,
    String password,
  ) async {
    // Store base64(password) so a future transport has the credential ready.
    return password.isEmpty ? null : base64Encode(utf8.encode(password));
  }

  @override
  Future<bool> ping(NetworkServerEntity server) async {
    AppLog.instance.add('SMB ping rejected: transport unavailable');
    throw UnsupportedError(_unavailableMessage);
  }

  @override
  Future<List<int>> getCoverArt(
    NetworkServerEntity server,
    String marker,
  ) async {
    throw UnsupportedError(_unavailableMessage);
  }

  @override
  Future<String> stream(
    NetworkServerEntity server,
    String remoteId, {
    String? extension,
    void Function(double progress)? onProgress,
  }) async {
    throw UnsupportedError(_unavailableMessage);
  }

  @override
  Stream<ScanProgress> syncLibrary(NetworkServerEntity server) async* {
    throw UnsupportedError(_unavailableMessage);
  }
}
