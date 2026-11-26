// Main sources
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// App constants and other app UI libraries
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/responsive.dart';

// Database, widgets, and service configurations
import '../../../data/database.dart';
import '../../../data/repositories/song_repository.dart';
import '../../../providers/providers.dart';
import '../../../services/playlist_service.dart';
import '../../../services/sources/jellyfin_password_store.dart';
import '../../../services/sources/jellyfin_service.dart';
import '../../../services/sources/network_credential_store.dart';
import '../../../services/sources/network_endpoint_policy.dart';
import '../../../services/sources/network_source_service.dart';
import '../../../services/sources/smb_failure.dart';
import '../../../services/sources/smb_service.dart';
import '../../../services/sources/tidal_service.dart';
import '../../../widgets/common/brand_icon.dart';
import '../widgets/settings_widgets.dart';
import 'package:flick/l10n/settings_l10n.dart';

/// Add or edit a network server. All registered protocols are selectable;
/// each dispatches test/sync/stream through [networkSourceServiceFor].
class NetworkServerEditScreen extends ConsumerStatefulWidget {
  const NetworkServerEditScreen({super.key, this.server});

  final NetworkServerEntity? server;

  @override
  ConsumerState<NetworkServerEditScreen> createState() =>
      _NetworkServerEditScreenState();
}

class _ProtocolMeta {
  const _ProtocolMeta({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.urlHint,
    required this.passwordHelper,
    this.logoAsset,
    this.logoTinted = false,
  });
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final String urlHint;
  final String passwordHelper;

  /// Official service mark, when the protocol has one. Protocols without a
  /// brand (WebDAV, SMB) fall back to [icon].
  final String? logoAsset;

  /// Tint [logoAsset] with the current foreground color (used for marks whose
  /// official form is black/white on transparent).
  final bool logoTinted;
}

List<_ProtocolMeta> _protocolsFor(AppLocalizations l10n) => [
  _ProtocolMeta(
    id: NetworkProtocol.subsonic,
    label: l10n.englishForFilipino.subsonic,
    subtitle: l10n.navidromeAirsonicGonic,
    icon: LucideIcons.radio,
    logoAsset: BrandAssets.subsonic,
    urlHint: 'https://music.example.com/subsonic',
    passwordHelper: l10n.storedAsASaltedHashNever,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.jellyfin,
    label: l10n.englishForFilipino.jellyfin,
    subtitle: l10n.jellyfinEmby,
    icon: LucideIcons.clapperboard,
    logoAsset: BrandAssets.jellyfin,
    urlHint: 'https://jf.example.com',
    passwordHelper: l10n.keptInSecureStorageToRe,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.webdav,
    label: l10n.englishForFilipino.webdav,
    subtitle: l10n.nextcloudOwncloudSabredav,
    icon: LucideIcons.cloud,
    urlHint: 'https://cloud.example.com/remote.php/dav/files/user',
    passwordHelper: l10n.httpBasicNeedsItRecoverableStored,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.upnp,
    label: l10n.englishForFilipino.upnpDlna,
    subtitle: l10n.minimserverServiioKodi,
    icon: LucideIcons.cast,
    logoAsset: BrandAssets.dlna,
    urlHint: 'http://192.168.1.10:8200/rootDesc.xml',
    passwordHelper: l10n.mostDlnaServersNeedNoPassword,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.smb,
    label: 'SMB',
    subtitle: l10n.sambaWindowsShareTransportPending,
    icon: LucideIcons.hardDrive,
    urlHint: 'smb://nas/music',
    passwordHelper: l10n.storedEncodedPlaybackUnavailableInThis,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.tidal,
    label: l10n.englishForFilipino.tidal,
    subtitle: l10n.signInWithYourAccountHifi,
    icon: LucideIcons.waves,
    logoAsset: BrandAssets.tidal,
    logoTinted: true,
    urlHint: TidalService.tidalBaseUrl,
    passwordHelper: l10n.oauthSignInNoPasswordStored,
  ),
];

class _NetworkServerEditScreenState extends ConsumerState<NetworkServerEditScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late String _selectedProtocol;
  bool _testing = false;
  bool? _testPassed;
  String? _testError;
  /// Set when Tidal sign-in can't auto-open the browser; the live banner shows
  /// it for manual copy/open while polling continues.
  String? _testVerificationUri;
  bool _saving = false;
  bool _isValid = false;
  String? _insecureHttpEndpoint;

  bool get _isNew => widget.server == null;
  bool get _busy => _testing || _saving;

  bool get _isTidal => _selectedProtocol == NetworkProtocol.tidal;

  bool get _showInsecureHttpOption =>
      NetworkProtocol.usesAuthenticatedHttp(_selectedProtocol) &&
      NetworkEndpointPolicy.isInsecureHttp(_urlController.text);

  String get _enteredEndpoint =>
      NetworkCredentialStore.normalizeEndpoint(_urlController.text);

  /// Kept in memory if Tidal sign-in succeeds but saving it needs a retry.
  NetworkCredential? _tidalSignIn;

  _ProtocolMeta get _meta =>
      _protocolsFor(l10n).firstWhere((p) => p.id == _selectedProtocol);

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _selectedProtocol = (server?.protocol.isNotEmpty ?? false)
        ? server!.protocol
        : NetworkProtocol.subsonic;
    _labelController = TextEditingController(text: server?.label ?? '');
    _urlController = TextEditingController(text: server?.baseUrl ?? '');
    _usernameController = TextEditingController(text: server?.username ?? '');
    _passwordController = TextEditingController();
    if (server?.allowInsecureHttp ?? false) {
      _insecureHttpEndpoint = _enteredEndpoint;
    }
    _labelController.addListener(_updateValidity);
    _urlController.addListener(_endpointChanged);
    _isValid = _hasRequiredFields;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _hasRequiredFields =>
      _labelController.text.trim().isNotEmpty &&
      (_isTidal || _urlController.text.trim().isNotEmpty);

  void _updateValidity() {
    final valid = _hasRequiredFields;
    if (_isValid != valid) setState(() => _isValid = valid);
  }

  void _endpointChanged() {
    setState(() {
      _isValid = _hasRequiredFields;
      if (_enteredEndpoint != _insecureHttpEndpoint) {
        _insecureHttpEndpoint = null;
      }
      _testPassed = null;
      _testError = null;
    });
  }

  NetworkCredentialStore get _credentials => NetworkCredentialStore.instance;

  // Snapshot the endpoint, account and HTTP consent together, before awaiting
  // any login or storage operation.
  NetworkServerEntity _draftEntity() {
    final old = widget.server;
    return NetworkServerEntity()
      ..id = old?.id ?? Isar.autoIncrement
      ..lastSyncedAt = old?.lastSyncedAt
      ..label = _labelController.text.trim().isEmpty
          ? (_isTidal ? l10n.tidal : '')
          : _labelController.text.trim()
      ..protocol = _selectedProtocol
      ..baseUrl = _isTidal
          ? TidalService.tidalBaseUrl
          : _enteredEndpoint
      ..username = _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim()
      ..allowInsecureHttp =
          _showInsecureHttpOption && _insecureHttpEndpoint == _enteredEndpoint;
  }

  void _validateEndpoint(NetworkServerEntity draft) {
    if (NetworkProtocol.usesAuthenticatedHttp(draft.protocol)) {
      NetworkEndpointPolicy.requireAllowed(draft);
    } else if (draft.protocol == NetworkProtocol.smb) {
      try {
        SmbService.parseServerUrl(draft.baseUrl);
      } on FormatException catch (e) {
        throw NetworkCredentialException(e.message);
      }
    }
  }

  Future<NetworkCredential?> _prepareCredential(
    NetworkServerEntity draft,
    String password,
  ) async {
    _validateEndpoint(draft);
    if (draft.protocol == NetworkProtocol.tidal && _tidalSignIn != null) {
      return _tidalSignIn;
    }
    if (password.isNotEmpty && draft.protocol != NetworkProtocol.upnp) {
      final secret = await networkSourceServiceFor(draft.protocol)
          .resolveToken(draft, password);
      if (secret == null || secret.isEmpty) {
        throw NetworkCredentialException(l10n.credentialMissing(draft.label));
      }
      return NetworkCredential.forServer(
        draft,
        secret,
        password: draft.protocol == NetworkProtocol.jellyfin ? password : null,
      );
    }
    final old = widget.server;
    if (old != null && NetworkCredentialStore.sameDestination(old, draft)) {
      // Validate the current slot, but don't rewrite it on a label or consent
      // edit. An in-flight renewal may have just rotated its secret.
      await _credentials.read(old);
      draft.credentialRef = old.credentialRef;
    } else if (old != null &&
        (old.credentialRef != null ||
            (old.token?.isNotEmpty ?? false)) &&
        draft.protocol != NetworkProtocol.tidal) {
      throw NetworkCredentialException(l10n.serverPasswordReentryRequired);
    }
    if (draft.credentialRef == null &&
        (draft.protocol == NetworkProtocol.jellyfin ||
            draft.protocol == NetworkProtocol.subsonic ||
            draft.protocol == NetworkProtocol.tidal)) {
      throw NetworkCredentialException(l10n.credentialMissing(draft.label));
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (_busy) return;
    final draft = _draftEntity();
    final password = _passwordController.text;
    setState(() {
      _testing = true;
      _testPassed = null;
      _testError = null;
      _testVerificationUri = null;
    });
    AppHaptics.tap();
    try {
      if (draft.protocol == NetworkProtocol.tidal) {
        await _testTidal(draft);
        return;
      }
      final credential = await _prepareCredential(draft, password);
      if (credential != null) _credentials.setDraft(draft, credential);
      final service = networkSourceServiceFor(draft.protocol);
      final ok = await service.ping(draft);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = ok;
        if (!ok) _testError = service.lastPingError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = false;
        _testError = _humanError(e);
      });
    }
  }

  /// Tidal's test button means "sign in and connect": ping any stored session,
  /// and when it's missing OR dead (expired/revoked refresh token — the old
  /// flow could never recover from that), run the device-code login. Ping a
  /// saved session through its real ref so a refresh updates the saved token.
  Future<void> _testTidal(NetworkServerEntity draft) async {
    final tidal = TidalService.instance;
    final old = widget.server;
    final pending = _tidalSignIn;
    if (pending != null) {
      _credentials.setDraft(draft, pending);
    } else if (old != null &&
        NetworkCredentialStore.sameDestination(old, draft)) {
      draft.credentialRef = old.credentialRef;
    }
    var ok = await tidal.ping(draft);
    if (!mounted) return;
    if (!ok) {
      final token = await tidal.signIn(
        onVerificationLink: (uri) {
          if (mounted) setState(() => _testVerificationUri = uri);
        },
      );
      if (!mounted) return;
      draft.credentialRef = null;
      _credentials.setDraft(draft, NetworkCredential.forServer(draft, token));
      setState(() => _testVerificationUri = null);
      ok = await tidal.ping(draft);
    }
    if (!mounted) return;
    if (ok && draft.credentialRef == null) {
      _tidalSignIn = await _credentials.read(draft);
      if (!mounted) return;
    }
    setState(() {
      _testing = false;
      _testPassed = ok;
    });
    if (ok && _tidalSignIn != null) {
      await _saveDraft(draft, '');
    }
  }

  Future<void> _save() async {
    if (_busy || !_isValid) return;
    await _saveDraft(_draftEntity(), _passwordController.text);
  }

  Future<void> _saveDraft(NetworkServerEntity draft, String password) async {
    setState(() => _saving = true);
    final old = widget.server;
    final providers = ProviderScope.containerOf(context, listen: false);
    String? stagedRef;
    try {
      final credential = await _prepareCredential(draft, password);
      if (credential != null) {
        stagedRef = await _credentials.stage(credential);
        draft.credentialRef = stagedRef;
      }
      await Database.instance.writeTxn(() async {
        if (old != null) {
          final current = await Database.networkServers.get(old.id);
          if (current == null ||
              current.credentialRef != old.credentialRef ||
              current.allowInsecureHttp != old.allowInsecureHttp ||
              !NetworkCredentialStore.sameDestination(current, old)) {
            throw NetworkCredentialException(l10n.credentialSaveConflict);
          }
          draft.lastSyncedAt = current.lastSyncedAt;
        }
        await Database.networkServers.put(draft);
      });
    } catch (e) {
      await _credentials.deleteRef(stagedRef);
      if (mounted) {
        setState(() {
          _saving = false;
          _testPassed = false;
          _testError = _humanError(e);
        });
      }
      return;
    }
    if (old?.credentialRef != draft.credentialRef) {
      await _credentials.deleteRef(old?.credentialRef);
    }
    providers.invalidate(networkServersProvider);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _humanError(Object e) {
    return switch (e) {
      NetworkCredentialException() => e.message,
      JellyfinNetworkException() => e.message,
      TidalException() => e.message,
      SmbFailure() => e.message,
      _ => l10n.couldNotReachTheServer,
    };
  }

  Future<void> _delete() async {
    final server = widget.server;
    if (server == null || _busy) return;
    AppHaptics.tap();
    final confirmed = await FlickDialogs.confirm(
      context,
      title: l10n.englishForFilipino.removeServer,
      message:
          l10n.deleteAndAllSongsAndPlaylists(server.label),
      confirmLabel: l10n.englishForFilipino.delete,
      destructive: true,
    );
    if (!confirmed || !mounted || _busy) return;
    setState(() => _saving = true);
    final providers = ProviderScope.containerOf(context, listen: false);
    try {
      final removed = await Database.instance.writeTxn(() async {
        final current = await Database.networkServers.get(server.id);
        await Database.networkServers.delete(server.id);
        return current;
      });
      await _credentials.deleteRef(removed?.credentialRef);
      await SongRepository().deleteSongsForRemoteServer(server.id);
      await PlaylistService.instance.removeNetworkPlaylistsForServer('${server.id}');
      if (removed?.protocol == NetworkProtocol.jellyfin) {
        await JellyfinPasswordStore().delete(server.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _testPassed = false;
          _testError = _humanError(e);
        });
      }
      return;
    } finally {
      providers.invalidate(networkServersProvider);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  IconData get _testIcon => _testPassed == null
      ? LucideIcons.wifi
      : _testPassed!
      ? LucideIcons.checkCircle
      : LucideIcons.xCircle;

  String get _testLabel {
    if (_testPassed == true) return _isTidal ? l10n.signedIn : l10n.connectionOk;
    if (_testPassed == false) {
      return _isTidal ? l10n.signInFailedRetry : l10n.connectionFailedRetry;
    }
    if (_isTidal) {
      final hasToken = _tidalSignIn != null || widget.server?.credentialRef != null;
      return hasToken ? l10n.testConnection : l10n.signInWithTidal;
    }
    return l10n.testConnection;
  }

  @override
  Widget build(BuildContext context) {
    final protocols = _protocolsFor(l10n);
    return SettingsScaffold(
      title: _isNew ? l10n.englishForFilipino.addServer : l10n.englishForFilipino.editServer,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.protocol),
          SettingsCard(
            children: [
              for (var i = 0; i < protocols.length; i++) ...[
                if (i > 0) const SettingsDivider(),
                SelectionSetting(
                  icon: protocols[i].icon,
                  iconAsset: protocols[i].logoAsset,
                  iconAssetColor: protocols[i].logoTinted
                      ? context.adaptiveTextPrimary
                      : null,
                  title: protocols[i].label,
                  subtitle: protocols[i].subtitle,
                  selected: _selectedProtocol == protocols[i].id,
                   onTap: _isNew && !_busy
                      ? () {
                          AppHaptics.tap();
                          setState(() {
                            _selectedProtocol = protocols[i].id;
                            _testPassed = null;
                            _testError = null;
                            _testVerificationUri = null;
                             _tidalSignIn = null;
                             _insecureHttpEndpoint = null;
                              _isValid = _hasRequiredFields;
                          });
                        }
                      : null,
                ),
              ],
            ],
          ),
          if (_selectedProtocol == NetworkProtocol.smb)
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spacingXs,
                top: AppConstants.spacingSm,
              ),
              child: Text(
                l10n.smbSharesCanBeAddedNow,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
              ),
            ),
          if (_isTidal)
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.spacingXs,
                top: AppConstants.spacingSm,
              ),
              child: Text(
                l10n.signInWithYourOwnTidal,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
              ),
            ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.connection),
          SettingsCard(
            children: [
              _TextFieldSetting(
                enabled: !_busy,
                controller: _labelController,
                icon: LucideIcons.tag,
                label: l10n.englishForFilipino.label,
                hint: l10n.my(_meta.label),
              ),
              if (!_isTidal) ...[
                const SettingsDivider(),
                _TextFieldSetting(
                  enabled: !_busy,
                  controller: _urlController,
                  icon: LucideIcons.link,
                  label: l10n.englishForFilipino.serverUrl,
                  hint: _meta.urlHint,
                  keyboardType: TextInputType.url,
                ),
                if (_showInsecureHttpOption) ...[
                  const SettingsDivider(),
                  ToggleSetting(
                    icon: LucideIcons.triangleAlert,
                    title: l10n.allowInsecureHttp,
                    subtitle: l10n.allowInsecureHttpDescription,
                     value: _insecureHttpEndpoint == _enteredEndpoint,
                     onChanged: (value) {
                       if (_busy) return;
                       setState(() {
                         _insecureHttpEndpoint = value ? _enteredEndpoint : null;
                        _testPassed = null;
                        _testError = null;
                      });
                    },
                  ),
                ],
                const SettingsDivider(),
                _TextFieldSetting(
                  enabled: !_busy,
                  controller: _usernameController,
                  icon: LucideIcons.user,
                  label: l10n.englishForFilipino.username,
                ),
                const SettingsDivider(),
                _TextFieldSetting(
                  enabled: !_busy,
                  controller: _passwordController,
                  icon: LucideIcons.lock,
                  label: l10n.englishForFilipino.password,
                  obscureText: true,
                  helperText: _isNew
                      ? _meta.passwordHelper
                      : l10n.leaveEmptyToKeepTheCurrent,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _busy ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_testIcon, size: 18),
              label: Text(_testLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
            ),
          ),
          if (_testing && _testVerificationUri != null) ...[
            const SizedBox(height: AppConstants.spacingSm),
            _buildSignInLinkBanner(context),
          ],
          if (_testPassed == false) ...[
            const SizedBox(height: AppConstants.spacingSm),
            _buildFailureBanner(context),
          ],
          const SizedBox(height: AppConstants.spacingSm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_busy || !_isValid) ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isNew ? l10n.englishForFilipino.addServer : l10n.englishForFilipino.save),
            ),
          ),
          if (!_isNew) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: Text(l10n.removeServer2),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFailureBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 16,
            color: context.adaptiveTextSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _testError ?? l10n.couldNotReachTheServer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown live while Tidal device-code polling runs after the browser failed
  /// to auto-open. Offers manual copy/open of the verification link.
  Widget _buildSignInLinkBanner(BuildContext context) {
    final uri = _testVerificationUri!;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.glassBackground,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.link,
                size: 16,
                color: context.adaptiveTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.couldnTOpenTheBrowserAutomatically,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.adaptiveTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: SelectableText(
              uri,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextSecondary,
                fontFamily: 'monospace',
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _linkAction(
                icon: LucideIcons.externalLink,
                label: l10n.englishForFilipino.openInBrowser,
                onTap: () => _openLink(uri),
              ),
              _linkAction(
                icon: LucideIcons.copy,
                label: l10n.englishForFilipino.copyLink,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: uri));
                  AppHaptics.tap();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Glass-styled action button matching the app design language (used for the
  /// Tidal sign-in link actions).
  Widget _linkAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glassBackgroundStrong,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.glassBorderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: context.adaptiveTextSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.adaptiveTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open [uri] for the Tidal device flow in the default browser. If no
  /// default browser is set, the system shows its own chooser.
  Future<void> _openLink(String uri) async {
    AppHaptics.tap();
    try {
      await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    } catch (_) {/* nothing to do — the banner still shows the link */}
  }
}

class _TextFieldSetting extends StatefulWidget {
  const _TextFieldSetting({
    required this.controller,
    required this.icon,
    required this.label,
    this.hint,
    this.helperText,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String? hint;
  final String? helperText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  State<_TextFieldSetting> createState() => _TextFieldSettingState();
}

class _TextFieldSettingState extends State<_TextFieldSetting> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SettingsTileIcon(icon: widget.icon),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  obscureText: _obscured,
                  keyboardType: widget.keyboardType,
                  autocorrect: false,
                  enableSuggestions: !widget.obscureText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    helperText: widget.helperText,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.glassBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: widget.obscureText
                        ? IconButton(
                            icon: Icon(
                              _obscured
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 18,
                            ),
                            color: context.adaptiveTextSecondary,
                            tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
                            onPressed: () {
                              AppHaptics.tap();
                              setState(() => _obscured = !_obscured);
                            },
                          )
                        : null,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
                    helperStyle: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: context.adaptiveTextTertiary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                      borderSide: const BorderSide(
                        color: AppColors.glassBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                      borderSide: const BorderSide(
                        color: AppColors.glassBorderStrong,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTileIcon extends StatelessWidget {
  const _SettingsTileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.scaleSize(AppConstants.containerSizeMd),
      height: context.scaleSize(AppConstants.containerSizeMd),
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Icon(
        icon,
        color: context.adaptiveTextSecondary,
        size: context.responsiveIcon(AppConstants.iconSizeLg),
      ),
    );
  }
}
