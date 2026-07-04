import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/utils/app_haptics.dart';
import 'package:flick/core/utils/app_log.dart';
import 'package:flick/widgets/common/display_mode_wrapper.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _ctrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final Set<LogSource> _sources = {};
  bool _stickToBottom = true;

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LogEntry> _filtered(List<LogEntry> all) {
    var result = all;
    if (_sources.isNotEmpty) {
      result = result.where((e) => _sources.contains(e.source)).toList(growable: false);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result.where((e) => e.message.toLowerCase().contains(q)).toList(growable: false);
    }
    return result;
  }

  void _stickIfWanted() {
    if (!_stickToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ctrl.hasClients) return;
      _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
    });
  }

  String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  String _format(LogEntry e) => '${_ts(e.timestamp)} [${e.source.name}] ${e.message}';

  Color _sourceColor(LogSource s) {
    switch (s) {
      case LogSource.dart:
        return const Color(0xFFB0B0B0);
      case LogSource.rust:
        return const Color(0xFF8BB8FF);
      case LogSource.crash:
        return const Color(0xFFFF6B6B);
      case LogSource.zone:
        return const Color(0xFFFFB454);
      case LogSource.platform:
        return const Color(0xFFC4A3FF);
    }
  }

  Future<void> _copyAll(List<LogEntry> entries) async {
    if (entries.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: entries.map(_format).join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied')),
    );
  }

  Future<void> _shareAll(List<LogEntry> entries) async {
    if (entries.isEmpty) return;
    await Share.share(entries.map(_format).join('\n'), subject: 'Flick logs');
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear logs?', style: TextStyle(color: context.adaptiveTextPrimary)),
        content: Text(
          'This removes all ${AppLog.instance.entries.length} entries from memory.',
          style: TextStyle(color: context.adaptiveTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (ok == true) {
      AppLog.instance.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DisplayModeWrapper(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildControls(context),
              Expanded(child: _buildList(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop();
            },
            icon: Icon(LucideIcons.chevronLeft, color: context.adaptiveTextPrimary),
          ),
          Text(
            'Logs',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.adaptiveTextPrimary,
                ),
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: AppLog.instance,
            builder: (context, _) {
              final count = AppLog.instance.entries.length;
              return IconButton(
                tooltip: 'Copy',
                onPressed: count == 0 ? null : () => _copyAll(_filtered(AppLog.instance.entries)),
                icon: Icon(LucideIcons.copy, color: context.adaptiveTextSecondary),
              );
            },
          ),
          ListenableBuilder(
            listenable: AppLog.instance,
            builder: (context, _) {
              final count = AppLog.instance.entries.length;
              return IconButton(
                tooltip: 'Share',
                onPressed: count == 0 ? null : () => _shareAll(_filtered(AppLog.instance.entries)),
                icon: Icon(LucideIcons.share2, color: context.adaptiveTextSecondary),
              );
            },
          ),
          ListenableBuilder(
            listenable: AppLog.instance,
            builder: (context, _) {
              final count = AppLog.instance.entries.length;
              return IconButton(
                tooltip: 'Clear',
                onPressed: count == 0 ? null : _confirmClear,
                icon: Icon(LucideIcons.trash2, color: context.adaptiveTextSecondary),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: TextStyle(color: context.adaptiveTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter logs…',
              hintStyle: TextStyle(color: context.adaptiveTextTertiary, fontSize: 13),
              prefixIcon: Icon(LucideIcons.search, size: 16, color: context.adaptiveTextTertiary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: context.adaptiveAccent),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(context, null, 'All'),
                for (final s in LogSource.values) _chip(context, s, s.name),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, LogSource? source, String label) {
    final selected = source == null ? _sources.isEmpty : _sources.contains(source);
    final color = source == null ? context.adaptiveAccent : _sourceColor(source);
    return Padding(
      padding: const EdgeInsets.only(right: AppConstants.spacingXs),
      child: GestureDetector(
        onTap: () {
          AppHaptics.tap();
          setState(() {
            if (source == null) {
              _sources.clear();
            } else if (_sources.contains(source)) {
              _sources.remove(source);
            } else {
              _sources.add(source);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
            border: Border.all(color: selected ? color : AppColors.glassBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : context.adaptiveTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLog.instance,
      builder: (context, _) {
        final entries = _filtered(AppLog.instance.entries);
        _stickIfWanted();
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingXl),
              child: Text(
                AppLog.instance.entries.isEmpty ? 'No logs yet.' : 'No matches.',
                style: TextStyle(color: context.adaptiveTextTertiary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (!_ctrl.hasClients) return false;
            final max = _ctrl.position.maxScrollExtent;
            final cur = _ctrl.position.pixels;
            final atBottom = (max - cur).abs() < 64;
            if (atBottom != _stickToBottom) {
              setState(() => _stickToBottom = atBottom);
            }
            return false;
          },
          child: ListView.builder(
            controller: _ctrl,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              AppConstants.spacingMd,
              AppConstants.spacingXl,
            ),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final c = _sourceColor(e.source);
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.3,
                      color: context.adaptiveTextSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: '${_ts(e.timestamp)} ',
                        style: TextStyle(color: context.adaptiveTextTertiary),
                      ),
                      TextSpan(
                        text: '[${e.source.name}] ',
                        style: TextStyle(color: c, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: e.message, style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
