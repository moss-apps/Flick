import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/song_repository.dart';
import '../../../services/library_scanner_service.dart' show ScanProgress;
import '../../../services/sources/subsonic_service.dart';
import '../widgets/settings_widgets.dart';
import 'network_server_edit_screen.dart';

/// Manage configured network music servers (Subsonic in v1).
class NetworkSourcesScreen extends StatefulWidget {
  const NetworkSourcesScreen({super.key});

  @override
  State<NetworkSourcesScreen> createState() => _NetworkSourcesScreenState();
}

class _NetworkSourcesScreenState extends State<NetworkSourcesScreen> {
  List<NetworkServerEntity> _servers = [];
  int? _syncingId;
  ScanProgress? _syncProgress;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final servers = await Database.networkServers.where().findAll();
    servers.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    if (!mounted) return;
    setState(() => _servers = servers);
  }

  Future<void> _openEditor({NetworkServerEntity? server}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NetworkServerEditScreen(server: server),
      ),
    );
    if (changed == true) {
      await _loadServers();
    }
  }

  Future<void> _deleteServer(NetworkServerEntity server) async {
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
    await _loadServers();
  }

  Future<void> _syncServer(NetworkServerEntity server) async {
    if (_syncingId != null) return;
    setState(() {
      _syncingId = server.id;
      _syncProgress = null;
    });
    try {
      await for (final progress
          in SubsonicService.instance.syncLibrary(server)) {
        if (mounted && _syncingId == server.id) {
          setState(() => _syncProgress = progress);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
    if (mounted) {
      setState(() {
        _syncingId = null;
        _syncProgress = null;
      });
      await _loadServers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Network Sources',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_servers.isEmpty) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Center(
              child: Text(
                'No network sources yet.\nAdd a Subsonic server to browse and '
                'stream your remote library.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
            ),
          ] else
            SettingsCard(
              children: [
                for (var i = 0; i < _servers.length; i++) ...[
                  if (i > 0) const SettingsDivider(),
                  _buildServerRow(context, _servers[i]),
                ],
              ],
            ),
          const SizedBox(height: AppConstants.spacingMd),
          ActionButton(
            icon: LucideIcons.plus,
            title: 'Add Server',
            subtitle: 'Connect a Subsonic server',
            onTap: () => _openEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildServerRow(BuildContext context, NetworkServerEntity server) {
    final isSyncing = _syncingId == server.id;
    final lastSynced = server.lastSyncedAt;
    final syncedLabel = lastSynced == null
        ? 'Never synced'
        : 'Synced ${_formatDate(lastSynced)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEditor(server: server),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ColoredSettingsIcon(
                    icon: LucideIcons.server,
                    backgroundColor: const Color(0xFF2D4A6F),
                    iconColor: const Color(0xFF8BB8FF),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                server.label,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: context.adaptiveTextPrimary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ProtocolChip(server.protocol),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.baseUrl,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSyncing
                              ? _syncProgress?.phase ?? 'Syncing…'
                              : syncedLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSyncing
                                ? context.adaptiveTextSecondary
                                : context.adaptiveTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isSyncing ? null : () => _syncServer(server),
                    icon: Icon(
                      isSyncing
                          ? LucideIcons.loaderCircle
                          : LucideIcons.refreshCw,
                      size: 18,
                      color: context.adaptiveTextSecondary,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openEditor(server: server);
                        case 'delete':
                          _deleteServer(server);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              if (isSyncing) ...[
                const SizedBox(height: AppConstants.spacingSm),
                LinearProgressIndicator(
                  value: _syncProgress?.progressFraction ?? 0,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ProtocolChip extends StatelessWidget {
  const _ProtocolChip(this.protocol);

  final String protocol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A6F).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        protocol.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF8BB8FF),
        ),
      ),
    );
  }
}
