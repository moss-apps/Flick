// Main sources
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// App constants and other app UI libraries
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/responsive.dart';

// Database, widgets, and service configurations
import '../../../data/database.dart';
import '../../../data/repositories/song_repository.dart';
import '../../../services/sources/network_source_service.dart';
import '../widgets/settings_widgets.dart';

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

const List<_ProtocolMeta> _protocols = [
  _ProtocolMeta(
    id: NetworkProtocol.subsonic,
    label: 'Subsonic',
    subtitle: 'Navidrome · Airsonic · Gonic',
    icon: LucideIcons.radio,
    urlHint: 'https://music.example.com/subsonic',
    passwordHelper: 'Stored as a salted hash, never in plaintext',
  ),
  _ProtocolMeta(
    id: NetworkProtocol.jellyfin,
    label: 'Jellyfin',
    subtitle: 'Jellyfin · Emby',
    icon: LucideIcons.clapperboard,
    urlHint: 'https://jf.example.com',
    passwordHelper: 'Sent once to sign in; an access token is stored',
  ),
  _ProtocolMeta(
    id: NetworkProtocol.webdav,
    label: 'WebDAV',
    subtitle: 'Nextcloud · ownCloud · SabreDAV',
    icon: LucideIcons.cloud,
    urlHint: 'https://cloud.example.com/remote.php/dav/files/user',
    passwordHelper: 'HTTP Basic needs it recoverable; stored encoded',
  ),
  _ProtocolMeta(
    id: NetworkProtocol.upnp,
    label: 'UPnP / DLNA',
    subtitle: 'MinimServer · Serviio · Kodi',
    icon: LucideIcons.cast,
    urlHint: 'http://192.168.1.10:8200/rootDesc.xml',
    passwordHelper: 'Most DLNA servers need no password',
  ),
  _ProtocolMeta(
    id: NetworkProtocol.smb,
    label: 'SMB',
    subtitle: 'Samba · Windows share (transport pending)',
    icon: LucideIcons.hardDrive,
    urlHint: 'smb://nas/music',
    passwordHelper: 'Stored encoded; playback unavailable in this build',
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
  bool _saving = false;
  bool _isValid = false;

  bool get _isNew => widget.server == null;

  _ProtocolMeta get _meta =>
      _protocols.firstWhere((p) => p.id == _selectedProtocol);

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
    final valid =
        _labelController.text.trim().isNotEmpty &&
        _urlController.text.trim().isNotEmpty;
    if (_isValid != valid) setState(() => _isValid = valid);
  }

  /// Resolve the token to persist. When a password is typed it's resolved
  /// through the protocol service (local transform for Subsonic/WebDAV, a
  /// sign-in round-trip for Jellyfin). Otherwise the existing token is kept.
  Future<String?> _resolvePersistedToken() async {
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      final draft = _draftEntity(token: null);
      try {
        return await networkSourceServiceFor(_selectedProtocol)
            .resolveToken(draft, password);
      } catch (_) {
        return null;
      }
    }
    return widget.server?.token;
  }

  NetworkServerEntity _draftEntity({String? token}) {
    final server = widget.server ?? NetworkServerEntity();
    server
      ..label = _labelController.text.trim()
      ..protocol = _selectedProtocol
      ..baseUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '')
      ..username = _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim()
      ..token = token ?? server.token;
    return server;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testPassed = null;
      _testError = null;
    });
    AppHaptics.tap();
    final token = await _resolvePersistedToken();
    final entity = _draftEntity(token: token);
    try {
      final ok = await networkSourceServiceFor(_selectedProtocol).ping(entity);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testPassed = ok;
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

  Future<void> _save() async {  
    if (!_isValid) return;
    setState(() => _saving = true);
    final token = await _resolvePersistedToken();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove server?'),
      content: Text(
          'Delete "${server.label}" and all songs synced from it? '
          'Cached downloads are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Database.instance.writeTxn(() async {
      await Database.networkServers.delete(server.id);
    });
    await SongRepository().deleteSongsForRemoteServer(server.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  IconData get _testIcon => _testPassed == null
      ? LucideIcons.wifi
      : _testPassed!
      ? LucideIcons.checkCircle
      : LucideIcons.xCircle;

  String get _testLabel => _testPassed == null
      ? 'Test Connection'
      : _testPassed!
      ? 'Connection OK'
      : 'Connection Failed — Retry';

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: _isNew ? 'Add Server' : 'Edit Server',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader('Protocol'),
          SettingsCard(
            children: [
              for (var i = 0; i < _protocols.length; i++) ...[
                if (i > 0) const SettingsDivider(),
                SelectionSetting(
                  icon: _protocols[i].icon,
                  title: _protocols[i].label,
                  subtitle: _protocols[i].subtitle,
                  selected: _selectedProtocol == _protocols[i].id,
                  onTap: _isNew
                      ? () {
                          AppHaptics.tap();
                          setState(() {
                            _selectedProtocol = _protocols[i].id;
                            _testPassed = null;
                            _testError = null;
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
                'SMB shares can be added now, but streaming needs a native '
                'transport that is not yet wired into this build.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
              ),
            ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader('Connection'),
          SettingsCard(
            children: [
              _TextFieldSetting(
                controller: _labelController,
                icon: LucideIcons.tag,
                label: 'Label',
                hint: 'My Navidrome',
              ),
              const SettingsDivider(),
              _TextFieldSetting(
                controller: _urlController,
                icon: LucideIcons.link,
                label: 'Server URL',
                hint: _meta.urlHint,
                keyboardType: TextInputType.url,
              ),
              const SettingsDivider(),
              _TextFieldSetting(
                controller: _usernameController,
                icon: LucideIcons.user,
                label: 'Username',
              ),
              const SettingsDivider(),
              _TextFieldSetting(
                controller: _passwordController,
                icon: LucideIcons.lock,
                label: 'Password',
                obscureText: true,
                helperText: _isNew
                    ? _meta.passwordHelper
                    : 'Leave empty to keep the current credentials',
              ),
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
                  : Text(_isNew ? 'Add Server' : 'Save'),
            ),
          ),
          if (!_isNew) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('Remove server'),
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
}

class _TextFieldSetting extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SettingsTileIcon(icon: icon),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.adaptiveTextTertiary,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  enableSuggestions: !obscureText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    helperText: helperText,
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.glassBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
