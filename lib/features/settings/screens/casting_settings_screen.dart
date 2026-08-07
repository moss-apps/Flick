import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/casting/cast_device.dart';
import 'package:flick/services/casting/chromecast_backend.dart';

class CastingSettingsScreen extends ConsumerStatefulWidget {
  const CastingSettingsScreen({super.key});

  @override
  ConsumerState<CastingSettingsScreen> createState() =>
      _CastingSettingsScreenState();
}

class _CastingSettingsScreenState extends ConsumerState<CastingSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(castProvider.notifier).discover();
    });
  }

  List<Widget> _withDividers(List<Widget> rows) {
    if (rows.length <= 1) return rows;
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SettingsDivider(),
        rows[i],
      ],
    ];
  }

  IconData _iconFor(CastDevice d) => switch (d.backend) {
        CastBackend.dlna => LucideIcons.radio,
        CastBackend.chromecast => LucideIcons.cast,
      };

  String _subtitleFor(CastDevice d) => switch (d.backend) {
        CastBackend.dlna => 'DLNA / UPnP',
        CastBackend.chromecast => 'Chromecast',
      };

  Future<void> _onSelect(CastDevice device) async {
    await ref.read(castProvider.notifier).connect(device);
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Casting to ${device.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final castState = ref.watch(castProvider);

    return SettingsScaffold(
      title: 'Casting',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsSectionHeader('Available Devices'),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.refreshCw,
                title: castState.isDiscovering ? 'Searching…' : 'Scan for devices',
                subtitle: 'Discovers DLNA, UPnP and Chromecast receivers on your network',
                onTap: castState.isDiscovering
                    ? null
                    : () => ref.read(castProvider.notifier).discover(),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          if (castState.devices.isEmpty)
            SettingsCard(
              children: [
                _EmptyState(visible: !castState.isDiscovering),
              ],
            )
          else ...[
            SettingsCard(
              children: _withDividers(
                castState.devices
                    .map((d) => SelectionSetting(
                          icon: _iconFor(d),
                          title: d.name,
                          subtitle: _subtitleFor(d),
                          selected: castState.activeDevice?.id == d.id,
                          onTap: () => _onSelect(d),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (castState.activeDevice != null) ...[
            const SizedBox(height: AppConstants.spacingLg),
            const SettingsSectionHeader('Session'),
            SettingsCard(
              children: [
                ActionButton(
                  icon: LucideIcons.powerOff,
                  title: 'Stop Casting',
                  subtitle: 'Disconnect from ${castState.activeDevice!.name}',
                  onTap: () => ref.read(castProvider.notifier).disconnect(),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('Output Device', tag: 'Android'),
          SettingsCard(
            children: [_OutputSection()],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SettingsSectionHeader('About', tag: 'Info'),
          SettingsCard(
            children: [
              _AboutBody(),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.visible});
  final bool visible;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinner;

  @override
  void initState() {
    super.initState();
    _spinner = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (!widget.visible) _spinner.repeat();
  }

  @override
  void didUpdateWidget(covariant _EmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _spinner.stop();
    } else {
      _spinner.repeat();
    }
  }

  @override
  void dispose() {
    _spinner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = !widget.visible;
    final icon = searching
        ? RotationTransition(
            turns: _spinner,
            child: Icon(
              LucideIcons.loaderCircle,
              color: context.adaptiveTextTertiary,
              size: 28,
            ),
          )
        : Icon(
            LucideIcons.wifiOff,
            color: context.adaptiveTextTertiary,
            size: 28,
          );
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Center(
        child: Column(
          children: [
            icon,
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              widget.visible
                  ? 'No casting devices found. Make sure your phone and the receiver are on the same network.'
                  : 'Searching the local network…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.adaptiveTextTertiary,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputSection extends StatefulWidget {
  @override
  State<_OutputSection> createState() => _OutputSectionState();
}

class _OutputSectionState extends State<_OutputSection> {
  Future<List<Map<String, dynamic>>>? _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = ChromecastBackend().getOutputRoutes();
  }

  void _refresh() {
    setState(() {
      _routesFuture = ChromecastBackend().getOutputRoutes();
    });
  }

  IconData _iconFor(String? type) => switch (type) {
        'Speaker' => LucideIcons.speaker,
        'Wired Headset / AUX' => LucideIcons.headphones,
        'Bluetooth' => LucideIcons.bluetooth,
        'System' => LucideIcons.smartphone,
        _ => LucideIcons.usb,
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _routesFuture,
      builder: (context, snapshot) {
        final routes = snapshot.data ?? const [];
        return Column(
          children: [
            ActionButton(
              icon: LucideIcons.refreshCw,
              title: 'Refresh outputs',
              subtitle: 'List available local audio output devices',
              onTap: _refresh,
            ),
            if (routes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppConstants.spacingLg),
                child: Text('No output devices available.'),
              )
            else
              for (var i = 0; i < routes.length; i++) ...[
                const SettingsDivider(),
                _outputTile(routes[i]),
              ],
          ],
        );
      },
    );
  }

  Widget _outputTile(Map<String, dynamic> r) {
    final selected = r['selected'] == true;
    return SelectionSetting(
      icon: _iconFor(r['type'] as String?),
      title: r['name'] as String? ?? 'Output',
      subtitle: r['type'] as String? ?? '',
      selected: selected,
      onTap: selected
          ? null
          : () async {
              await ChromecastBackend().selectOutputRoute(r['id'] as String);
              _refresh();
            },
    );
  }
}

class _AboutBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      child: Text(
        'DLNA and UPnP receivers are controlled directly in pure Dart — no extra '
        'dependencies. Chromecast support uses the native Cast SDK. Only network '
        'sources (Subsonic, WebDAV, Jellyfin, UPnP) can be cast; local files are '
        'not yet supported for casting.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              height: 1.4,
            ),
      ),
    );
  }
}
