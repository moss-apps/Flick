import 'package:flutter/material.dart';
import 'package:flick/widgets/common/flick_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/features/settings/widgets/settings_widgets.dart';
import 'package:flick/providers/providers.dart';
import 'package:flick/services/casting/cast_device.dart';
import 'package:flick/services/casting/chromecast_backend.dart';
import 'package:flick/l10n/settings_l10n.dart';

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
      if (!mounted) return;
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
        CastBackend.dlna => l10n.dlnaUpnp,
        CastBackend.chromecast => l10n.chromecast,
      };

  Future<void> _onSelect(CastDevice device) async {
    await ref.read(castProvider.notifier).connect(device);
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showFlickSnackBar(
        SnackBar(
          content: Text(l10n.castingTo2(device.name)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final castState = ref.watch(castProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.casting,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.availableDevices),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.refreshCw,
                title: castState.isDiscovering ? l10n.englishForFilipino.searching : l10n.englishForFilipino.scanForDevices,
                subtitle: l10n.discoversDlnaUpnpAndChromecastReceivers,
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
            SettingsSectionHeader(l10n.englishForFilipino.session),
            SettingsCard(
              children: [
                ActionButton(
                  icon: LucideIcons.powerOff,
                  title: l10n.englishForFilipino.stopCasting,
                  subtitle: l10n.disconnectFrom(castState.activeDevice!.name),
                  onTap: () => ref.read(castProvider.notifier).disconnect(),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.outputDevice, tag: l10n.englishForFilipino.android),
          SettingsCard(
            children: [_OutputSection()],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.about, tag: l10n.englishForFilipino.info2),
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
                  ? l10n.noCastingDevicesFoundMakeSure
                  : l10n.searchingTheLocalNetwork,
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
              title: l10n.englishForFilipino.refreshOutputs,
              subtitle: l10n.listAvailableLocalAudioOutputDevices,
              onTap: _refresh,
            ),
            if (routes.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppConstants.spacingLg),
                child: Text(l10n.noOutputDevicesAvailable),
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
      title: r['name'] as String? ?? l10n.englishForFilipino.output,
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
        l10n.dlnaAndUpnpReceiversAreControlled,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.adaptiveTextSecondary,
              height: 1.4,
            ),
      ),
    );
  }
}
