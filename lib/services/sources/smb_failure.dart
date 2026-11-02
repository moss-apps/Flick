import '../../l10n/l10n.dart';

/// A privacy-safe error. Never retain native exceptions or server input here.
class SmbFailure implements Exception {
  const SmbFailure(this.stage, this.code);

  final String stage;
  final String code;

  static const _stages = {
    'connect',
    'share',
    'root',
    'read',
    'download',
    'cache',
    'decode',
    'url',
  };
  static const _codes = {
    'auth',
    'signing',
    'denied',
    'not_found',
    'timeout',
    'connection',
    'protocol',
    'incomplete',
    'storage',
    'cancelled',
  };

  factory SmbFailure.from(Object error, {String stage = 'download'}) {
    if (error is SmbFailure) return error;
    final raw = error.toString();
    final match = RegExp(r'SMB stage=(\w+) code=(\w+)').firstMatch(raw);
    if (match != null &&
        _stages.contains(match[1]) &&
        _codes.contains(match[2])) {
      return SmbFailure(match[1]!, match[2]!);
    }
    // Compatibility with older bridge errors. Match only known categories;
    // unknown messages must not be returned verbatim to logs or banners.
    final lower = raw.toLowerCase();
    final code =
        lower.contains('authentication failed') ||
            lower.contains('logon_failure')
        ? 'auth'
        : lower.contains('access_denied') || lower.contains('access denied')
        ? 'denied'
        : lower.contains('bad_network_name') || lower.contains('name_not_found')
        ? 'not_found'
        : lower.contains('timed out')
        ? 'timeout'
        : 'protocol';
    return SmbFailure(_stages.contains(stage) ? stage : 'download', code);
  }

  String get message => switch ((stage, code)) {
    (_, 'auth') => l10n.smbAuthFailed,
    (_, 'denied') => l10n.smbAccessDenied,
    (_, 'timeout') => l10n.smbTimedOut,
    (_, 'connection') => l10n.smbCouldNotReach,
    (_, 'signing') => l10n.smbSigningRequired,
    (_, 'storage') => l10n.smbCacheWriteFailed,
    (_, 'incomplete') => l10n.smbDownloadIncomplete,
    ('share', 'not_found') => l10n.smbShareNotFound,
    (_, 'not_found') => l10n.smbPathNotFound,
    ('decode', _) => l10n.smbDecodeFailed,
    _ => l10n.smbOperationFailed,
  };

  @override
  String toString() {
    final safeStage = _stages.contains(stage) ? stage : 'download';
    final safeCode = _codes.contains(code) ? code : 'protocol';
    return 'SMB stage=$safeStage code=$safeCode';
  }
}
