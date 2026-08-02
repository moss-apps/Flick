import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../data/database.dart';
import '../../../data/repositories/song_repository.dart';
import '../../../services/sources/subsonic_service.dart';
import '../widgets/settings_widgets.dart';

/// Add or edit a network server. Subsonic is the only enabled protocol in
/// v1; the rest are deferred and surfaced as a single "coming soon" note.
class NetworkServerEditScreen extends StatefulWidget {
  const NetworkServerEditScreen({super.key, this.server});

  final NetworkServerEntity? server;

  @override
  State<NetworkServerEditScreen> createState() => _NetworkServerEditScreenState();
}

class _NetworkServerEditScreenState extends State<NetworkServerEditScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _testing = false;
  bool? _testPassed;
  bool _saving = false;
  bool _isValid = false;

  bool get _isNew => widget.server == null;

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _labelController = TextEditingController(text: server?.label ?? '');
    _urlController = TextEditingController(text: server?.baseUrl ?? '');
    _usernameController = TextEditingController(text: server?.username ?? '');
    _passwordController = TextEditingController();
    _labelController.addListener(_updateValidity);
    _urlController.addListener(_updateValidity);
    _isValid = _labelController.text.trim().isNotEmpty &&
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
        _urlController.text.trim().isNotEmpty;
    if (_isValid != valid) setState(() => _isValid = valid);
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
      ..protocol = server.protocol.isNotEmpty ? server.protocol : 'subsonic'
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
    if (!_isValid) return;
    setState(() => _saving = true);
    await Database.instance.writeTxn(() async {
      await Database.networkServers.put(_draftEntity());
    });
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Row(
                  children: [
                    const _SettingsTileIcon(icon: LucideIcons.radio),
                    const SizedBox(width: AppConstants.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subsonic',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: context.adaptiveTextPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Navidrome · Airsonic · Gonic',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: context.adaptiveTextTertiary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: context.adaptiveTextPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingXs,
              top: AppConstants.spacingSm,
              bottom: AppConstants.spacingSm,
            ),
            child: Text(
              'More protocols (WebDAV, Jellyfin) coming soon.',
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
      padding: const EdgeInsets.all(AppConstants.spacingMd),
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
                    helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.adaptiveTextTertiary,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSm),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSm),
                      borderSide:
                          const BorderSide(color: AppColors.glassBorderStrong),
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
