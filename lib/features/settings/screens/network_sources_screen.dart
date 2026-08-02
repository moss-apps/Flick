import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/adaptive_color_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../data/database.dart';
import '../../../data/repositories/song_repository.dart';
import '../../../services/library_scanner_service.dart' show ScanProgress;
import '../../../services/sources/network_source_service.dart';
import '../widgets/settings_widgets.dart';
import 'network_server_edit_screen.dart';

/// Manage configured network music servers (Subsonic, Jellyfin, WebDAV,
/// UPnP/DLNA, SMB).
class NetworkSourcesScreen extends StatefulWidget {
  const NetworkSourcesScreen({super.key});

  @override
  State<NetworkSourcesScreen> createState() => _NetworkSourcesScreenState();
}

class _NetworkSourcesScreenState extends State<NetworkSourcesScreen> {
  List<NetworkServerEntity> _servers = [];
  final _songCounts = <int, int>{};
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
    final repo = SongRepository();
    final counts = <int, int>{};
    for (final s in servers) {
      counts[s.id] = await repo.countSongsByRemoteServer(s.id);
    }
    if (!mounted) return;
    setState(() {
      _servers = servers;
      _songCounts
        ..clear()
        ..addAll(counts);
    });
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

  Future<void> _syncServer(NetworkServerEntity server) async {
    if (_syncingId != null) return;
    setState(() {
      _syncingId = server.id;
      _syncProgress = null;
    });
    try {
      await for (final progress
          in networkSourceServiceFor(server.protocol).syncLibrary(server)) {
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
          if (_servers.isEmpty)
            _buildEmptyState(context)
          else ...[
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
              subtitle: 'Connect a music server',
              onTap: () => _openEditor(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(
                LucideIcons.server,
                size: 32,
                color: context.adaptiveTextTertiary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'No servers connected',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.adaptiveTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              'Connect a Subsonic, Jellyfin, WebDAV, or UPnP server to stream '
              'your remote library.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.adaptiveTextTertiary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add Server'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerRow(BuildContext context, NetworkServerEntity server) {
    final isSyncing = _syncingId == server.id;
    final songCount = _songCounts[server.id] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSyncing ? null : () => _openEditor(server: server),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ColoredSettingsIcon(
                    icon: LucideIcons.server,
                    backgroundColor: AppColors.glassBackgroundStrong,
                    iconColor: context.adaptiveTextSecondary,
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
                                    .titleMedium
                                    ?.copyWith(
                                      color: context.adaptiveTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _ProtocolChip(server.protocol),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          server.baseUrl,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.adaptiveTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSyncing)
                    IconButton(
                      tooltip: 'Sync now',
                      onPressed: () {
                        AppHaptics.tap();
                        _syncServer(server);
                      },
                      icon: Icon(
                        LucideIcons.refreshCw,
                        size: 18,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              if (isSyncing)
                _buildSyncPanel(context)
              else
                _buildMetaRow(context, server, songCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    BuildContext context,
    NetworkServerEntity server,
    int songCount,
  ) {
    final synced = server.lastSyncedAt;
    final parts = <String>[
      if (songCount > 0) '$songCount ${songCount == 1 ? 'song' : 'songs'}',
      synced == null ? 'Never synced' : 'Synced ${_formatDate(synced)}',
    ];
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: synced == null ? AppColors.textTertiary : AppColors.accent,
          ),
        ),
        Flexible(
          child: Text(
            parts.join('  ·  '),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncPanel(BuildContext context) {
    final p = _syncProgress;
    final fraction = p?.progressFraction ?? 0.0;
    final total = p?.totalFiles ?? 0;
    final done = p?.filesProcessed ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(context.adaptiveAccent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p?.phase ?? 'Syncing…',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (total > 0)
              Text(
                '$done / $total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.adaptiveTextTertiary,
                ),
              ),
          ],
        ),
        if (p?.currentFile != null && p!.currentFile!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            p.currentFile!,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
        const SizedBox(height: AppConstants.spacingXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: AppColors.glassBackground,
            valueColor: AlwaysStoppedAnimation(context.adaptiveAccent),
          ),
        ),
        if ((p?.songsFound ?? 0) > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${p!.songsFound} songs found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.adaptiveTextTertiary,
            ),
          ),
        ],
      ],
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
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusXs),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        protocol.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.adaptiveTextTertiary,
        ),
      ),
    );
  }
}
