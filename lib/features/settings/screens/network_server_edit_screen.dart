// Main sources
import 'package:flick/widgets/common/flick_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../services/playlist_service.dart';
import '../../../services/sources/jellyfin_service.dart';
import '../../../services/sources/network_source_service.dart';
import '../../../services/sources/tidal_service.dart';
import '../widgets/settings_widgets.dart';
import 'package:flick/l10n/l10n.dart';

/// Add or edit a network server. All registered protocols are selectable;
/// each dispatches test/sync/stream through [networkSourceServiceFor].
class NetworkServerEditScreen extends StatefulWidget {
  const NetworkServerEditScreen({super.key, this.server});

  final NetworkServerEntity? server;

  @override
  State<NetworkServerEditScreen> createState() =>
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
  });
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final String urlHint;
  final String passwordHelper;
}

List<_ProtocolMeta> _protocolsFor(AppLocalizations l10n) => [
  _ProtocolMeta(
    id: NetworkProtocol.subsonic,
    label: l10n.subsonic,
    subtitle: l10n.navidromeAirsonicGonic,
    icon: LucideIcons.radio,
    urlHint: 'https://music.example.com/subsonic',
    passwordHelper: l10n.storedAsASaltedHashNever,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.jellyfin,
    label: l10n.jellyfin,
    subtitle: l10n.jellyfinEmby,
    icon: LucideIcons.clapperboard,
    urlHint: 'https://jf.example.com',
    passwordHelper: l10n.keptInSecureStorageToRe,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.webdav,
    label: l10n.webdav,
    subtitle: l10n.nextcloudOwncloudSabredav,
    icon: LucideIcons.cloud,
    urlHint: 'https://cloud.example.com/remote.php/dav/files/user',
    passwordHelper: l10n.httpBasicNeedsItRecoverableStored,
  ),
  _ProtocolMeta(
    id: NetworkProtocol.upnp,
    label: l10n.upnpDlna,
    subtitle: l10n.minimserverServiioKodi,
    icon: LucideIcons.cast,
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
    label: l10n.tidal,
    subtitle: l10n.signInWithYourAccountHifi,
    icon: LucideIcons.waves,
    urlHint: TidalService.tidalBaseUrl,
    passwordHelper: l10n.oauthSignInNoPasswordStored,
  ),
];

class _NetworkServerEditScreenState extends State<NetworkServerEditScreen> {
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

  bool get _isNew => widget.server == null;

  bool get _isTidal => _selectedProtocol == NetworkProtocol.tidal;

  /// Tidal OAuth token resolved during this session (device-code login).
  String? _resolvedToken;

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
    _labelController.addListener(_updateValidity);
    _urlController.addListener(_updateValidity);
    _isValid =
        _labelController.text.trim().isNotEmpty &&
        _urlController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateValidity() {
    final valid = _labelController.text.trim().isNotEmpty &&
        (_isTidal || _urlController.text.trim().isNotEmpty);
    if (_isValid != valid) setState(() => _isValid = valid);
  }

  /// Resolve the token to persist. When a password is typed it's resolved
  /// through the protocol service (local transform for Subsonic/WebDAV, a
  /// sign-in round-trip for Jellyfin). Otherwise the existing token is kept.
  /// Tidal has no password field — its device-code token is captured in
  /// [_resolvedToken] during [_testConnection], or the previously-stored
  /// sign-in is reused.
  Future<String?> _resolvePersistedToken() async {
    if (_isTidal) {
      if (_resolvedToken != null) return _resolvedToken;
      return widget.server?.token;
    }
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      final draft = _draftEntity(token: null);
      return await networkSourceServiceFor(_selectedProtocol)
          .resolveToken(draft, password);
    }
    return widget.server?.token;
  }

  // Fresh entity, never the caller's in-memory row. Test Connection resolves
  // tokens from whatever is typed; mutating the shared entity here leaked
  // untested credentials into the list screen even when the edit was abandoned.
  NetworkServerEntity _draftEntity({String? token}) {
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
          : _urlController.text.trim().replaceAll(RegExp(r'/+$'), '')
      ..username = _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim()
      ..token = token ?? old?.token;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testPassed = null;
      _testError = null;
      _testVerificationUri = null;
    });
    AppHaptics.tap();
    String? token;
    try {
      token = await _resolvePersistedToken();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = false;
        _testError = _humanError(e);
      });
      return;
    }
    if (_isTidal) {
      await _testTidal(token);
      return;
    }
    final entity = _draftEntity(token: token);
    try {
      final service = networkSourceServiceFor(_selectedProtocol);
      final ok = await service.ping(entity);
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
  /// flow could never recover from that), run the device-code login. A fresh
  /// sign-in is persisted immediately; previously the token only lived in
  /// [_resolvedToken] and was silently dropped unless the user also tapped
  /// Add Server, so the account never stayed signed in.
  Future<void> _testTidal(String? storedToken) async {
    try {
      var ok = storedToken != null &&
          storedToken.isNotEmpty &&
          await TidalService.instance.ping(_draftEntity(token: storedToken));
      if (!ok) {
        final token = await TidalService.instance.signIn(
          onVerificationLink: (uri) {
            if (!mounted) return;
            setState(() => _testVerificationUri = uri);
          },
        );
        _resolvedToken = token;
        if (!mounted) return;
        setState(() => _testVerificationUri = null);
        ok = await TidalService.instance.ping(_draftEntity(token: token));
      }
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = ok;
      });
      if (ok && _resolvedToken != null) await _save(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = false;
        _testError = _humanError(e);
      });
    }
  }

  Future<void> _save({bool force = false}) async {
    if (!_isValid && !force) return;
    setState(() => _saving = true);
    String? token;
    try {
      token = await _resolvePersistedToken();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _testPassed = false;
        _testError = _humanError(e);
      });
      return;
    }
    final password = _passwordController.text;
    if (_selectedProtocol == NetworkProtocol.jellyfin &&
        token != null &&
        password.isNotEmpty) {
      await JellyfinService.instance
          .persistPassword(_draftEntity(token: token), password);
    }
    await Database.instance.writeTxn(() async {
      await Database.networkServers.put(_draftEntity(token: token));
    });
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _humanError(Object e) {
    final raw = e.toString();
    // Trim the "UnsupportedError: " / "Exception: " boilerplate.
    final colon = raw.indexOf(': ');
    return colon > 0 && colon < 24 ? raw.substring(colon + 2) : raw;
  }

  Future<void> _delete() async {
    final server = widget.server;
    if (server == null) return;
    AppHaptics.tap();
    final confirmed = await FlickDialogs.confirm(
      context,
      title: l10n.removeServer,
      message:
          l10n.deleteAndAllSongsAndPlaylists(server.label),
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed) return;
    if (server.protocol == NetworkProtocol.jellyfin) {
      await JellyfinService.instance.forgetPassword(server.id);
    }
    await Database.instance.writeTxn(() async {
      await Database.networkServers.delete(server.id);
    });
    await SongRepository().deleteSongsForRemoteServer(server.id);
    await PlaylistService.instance.removeNetworkPlaylistsForServer('${server.id}');
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
      final hasToken = _resolvedToken != null ||
          (widget.server?.token?.isNotEmpty ?? false);
      return hasToken ? l10n.testConnection : l10n.signInWithTidal;
    }
    return l10n.testConnection;
  }

  @override
  Widget build(BuildContext context) {
    final protocols = _protocolsFor(l10n);
    return SettingsScaffold(
      title: _isNew ? l10n.addServer : l10n.editServer,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.protocol),
          SettingsCard(
            children: [
              for (var i = 0; i < protocols.length; i++) ...[
                if (i > 0) const SettingsDivider(),
                SelectionSetting(
                  icon: protocols[i].icon,
                  title: protocols[i].label,
                  subtitle: protocols[i].subtitle,
                  selected: _selectedProtocol == protocols[i].id,
                  onTap: _isNew
                      ? () {
                          AppHaptics.tap();
                          setState(() {
                            _selectedProtocol = protocols[i].id;
                            _testPassed = null;
                            _testError = null;
                            _testVerificationUri = null;
                            _resolvedToken = null;
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
          SettingsSectionHeader(l10n.connection),
          SettingsCard(
            children: [
              _TextFieldSetting(
                controller: _labelController,
                icon: LucideIcons.tag,
                label: l10n.label,
                hint: l10n.my(_meta.label),
              ),
              if (!_isTidal) ...[
                const SettingsDivider(),
                _TextFieldSetting(
                  controller: _urlController,
                  icon: LucideIcons.link,
                  label: l10n.serverUrl,
                  hint: _meta.urlHint,
                  keyboardType: TextInputType.url,
                ),
                const SettingsDivider(),
                _TextFieldSetting(
                  controller: _usernameController,
                  icon: LucideIcons.user,
                  label: l10n.username,
                ),
                const SettingsDivider(),
                _TextFieldSetting(
                  controller: _passwordController,
                  icon: LucideIcons.lock,
                  label: l10n.password,
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
              onPressed: _testing || _saving ? null : _testConnection,
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
              onPressed: (_saving || !_isValid) ? null : _save,
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
                  : Text(_isNew ? l10n.addServer : l10n.save),
            ),
          ),
          if (!_isNew) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _delete,
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
              _testError ??
                  'Could not reach the server. Check the URL and credentials, '
                  'then try again.',
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
                label: l10n.openInBrowser,
                onTap: () => _openLink(uri),
              ),
              _linkAction(
                icon: LucideIcons.copy,
                label: l10n.copyLink,
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
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String? hint;
  final String? helperText;
  final bool obscureText;
  final TextInputType? keyboardType;

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
                  obscureText: _obscured,
                  keyboardType: widget.keyboardType,
                  autocorrect: false,
                  enableSuggestions: !_obscured,
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
