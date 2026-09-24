import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/providers/connectivity_provider.dart';

/// Full-width notice bar that sits below the app content while the device is
/// offline and briefly confirms when the connection comes back.
///
/// Because it takes its own layout space instead of floating over the UI, it
/// never covers or blocks any interface.
class OfflineNotice extends ConsumerStatefulWidget {
  const OfflineNotice({super.key});

  @override
  ConsumerState<OfflineNotice> createState() => _OfflineNoticeState();
}

class _OfflineNoticeState extends ConsumerState<OfflineNotice>
    with SingleTickerProviderStateMixin {
  static const Duration _backOnlineDuration = Duration(seconds: 2);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppConstants.animationNormal,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();
    if (ref.read(connectivityProvider) == ConnectivityStatus.offline) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(ConnectivityStatus? previous, ConnectivityStatus next) {
    if (next == ConnectivityStatus.offline) {
      _backOnlineTimer?.cancel();
      _backOnlineTimer = null;
      if (_showBackOnline) {
        setState(() => _showBackOnline = false);
      }
      _show();
      return;
    }

    if (next == ConnectivityStatus.online &&
        previous == ConnectivityStatus.offline) {
      _show();
      _backOnlineTimer?.cancel();
      setState(() => _showBackOnline = true);
      _backOnlineTimer = Timer(_backOnlineDuration, () {
        if (!mounted) return;
        setState(() => _showBackOnline = false);
        _controller.reverse();
      });
    }
  }

  void _show() {
    _controller.duration = AppConstants.animationNormal;
    if (!_controller.isCompleted) {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityStatus>(connectivityProvider, _onStatusChanged);
    final status = ref.watch(connectivityProvider);

    final isOffline = status == ConnectivityStatus.offline;
    final visible = isOffline || _showBackOnline;

    return ExcludeSemantics(
      excluding: !visible,
      child: SizeTransition(
        key: const ValueKey('offline_notice_size'),
        sizeFactor: _curve,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: _curve,
          child: _NoticeBar(isOffline: isOffline),
        ),
      ),
    );
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final duration = AppConstants.animationNormal;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isOffline ? context.adaptiveTextPrimary : AppColors.onSuccess,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isOffline
          ? context.adaptiveTextSecondary
          : AppColors.onSuccess.withValues(alpha: 0.72),
      fontSize: 12,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: isOffline
          ? "You're offline. Some online features may not work."
          : 'Back online',
      child: AnimatedContainer(
        key: const ValueKey('offline_notice_bar'),
        duration: duration,
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppConstants.spacingMd,
          AppConstants.spacingSm,
          AppConstants.spacingMd,
          AppConstants.spacingSm + bottomInset,
        ),
        decoration: BoxDecoration(
          color: isOffline ? AppColors.surfaceLight : AppColors.success,
          border: Border(
            top: BorderSide(
              color: isOffline
                  ? AppColors.glassBorder
                  : AppColors.success.withValues(alpha: 0),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                isOffline ? LucideIcons.wifiOff : LucideIcons.check,
                key: ValueKey<bool>(isOffline),
                size: 18,
                color: isOffline ? AppColors.error : AppColors.onSuccess,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: isOffline ? "You're offline" : 'Back online',
                  style: titleStyle,
                  children: isOffline
                      ? [
                          TextSpan(
                            text: '  ·  Some online features may not work',
                            style: detailStyle,
                          ),
                        ]
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
