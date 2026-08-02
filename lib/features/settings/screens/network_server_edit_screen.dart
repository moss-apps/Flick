import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../data/database.dart';
import '../../../services/sources/subsonic_service.dart';
import '../widgets/settings_widgets.dart';

/// Add or edit a network server. Subsonic is the only enabled protocol in
/// v1; the rest are greyed out with a "needs a new dependency" note.
class NetworkServerEditScreen extends StatefulWidget {
  const NetworkServerEditScreen({super.key, this.server});

  final NetworkServerEntity? server;

  @override
  State<NetworkServerEditScreen> createState() => _NetworkServerEditScreenState();
}

class _NetworkServerEditScreenState extends State<NetworkServerEditScreen> {
  static const _protocols = [
    ('subsonic', 'Subsonic', 'Navidrome, Airsonic, Gonic', true),
    ('webdav', 'WebDAV', 'Needs a new dependency', false),
    ('jellyfin', 'Jellyfin', 'Needs a new dependency', false),
    ('smb', 'SMB', 'Needs a new dependency', false),
    ('upnp', 'UPnP', 'Needs a new dependency', false),
  ];

  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late String _protocol;
  bool _testing = false;
  bool? _testPassed;
  bool _saving = false;

  bool get _isNew => widget.server == null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _labelController = TextEditingController(text: server?.label ?? '');
    _urlController = TextEditingController(text: server?.baseUrl ?? '');
    _usernameController = TextEditingController(text: server?.username ?? '');
    _passwordController = TextEditingController();
    _protocol = server?.protocol ?? 'subsonic';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _storedToken {
    final server = widget.server;
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      return SubsonicService.buildToken(password);
    }
    return server?.token;
  }

  NetworkServerEntity _draftEntity() {
    final server = widget.server ?? NetworkServerEntity();
    server
      ..label = _labelController.text.trim()
      ..protocol = _protocol
      ..baseUrl = _urlController.text.trim().replaceAll(RegExp(r'/+$'), '')
      ..username = _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim()
      ..token = _storedToken;
    return server;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testPassed = null;
    });
    AppHaptics.tap();
    final entity = _draftEntity();
    final ok = await SubsonicService.instance.ping(entity);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testPassed = ok;
    });
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    final url = _urlController.text.trim();
    if (label.isEmpty || url.isEmpty) return;

    setState(() => _saving = true);
    await Database.instance.writeTxn(() async {
      await Database.networkServers.put(_draftEntity());
    });
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

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
                  icon: _iconFor(_protocols[i].$1),
                  title: _protocols[i].$2,
                  subtitle: _protocols[i].$3,
                  selected: _protocol == _protocols[i].$1,
                  onTap: _protocols[i].$4
                      ? () => setState(() => _protocol = _protocols[i].$1)
                      : null,
                ),
              ],
            ],
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
                hint: 'https://music.example.com/subsonic',
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
                    ? 'Stored as a salted hash, never in plaintext'
                    : 'Leave empty to keep the current credentials',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _testing || _saving ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _testPassed == null
                              ? LucideIcons.wifi
                              : _testPassed!
                                  ? LucideIcons.checkCircle
                                  : LucideIcons.xCircle,
                          size: 18,
                        ),
                  label: Text(_testPassed == null
                      ? 'Test Connection'
                      : _testPassed!
                          ? 'Connection OK'
                          : 'Connection Failed'),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_isNew ? 'Add Server' : 'Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String protocol) {
    switch (protocol) {
      case 'subsonic':
        return LucideIcons.radio;
      case 'webdav':
        return LucideIcons.folderOpen;
      case 'jellyfin':
        return LucideIcons.film;
      case 'smb':
        return LucideIcons.network;
      default:
        return LucideIcons.zap;
    }
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
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          _SettingsTileIcon(icon: icon),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              autocorrect: false,
              enableSuggestions: !obscureText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.adaptiveTextPrimary,
              ),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                helperText: helperText,
                isDense: true,
                border: InputBorder.none,
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
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
      width: AppConstants.containerSizeMd,
      height: AppConstants.containerSizeMd,
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Icon(
        icon,
        color: context.adaptiveTextSecondary,
        size: AppConstants.iconSizeLg,
      ),
    );
  }
}
