import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';

/// One-shot, route-local section navigation. IDs are stable, never translated.
/// Missing/conditional sections leave the page at its normal starting position.
class SettingsScrollTarget extends StatefulWidget {
  const SettingsScrollTarget({
    super.key,
    required this.child,
    this.initialSection,
  });

  final Widget child;
  final String? initialSection;

  @override
  State<SettingsScrollTarget> createState() => _SettingsScrollTargetState();
}

class _SettingsScrollTargetState extends State<SettingsScrollTarget> {
  bool _handled = false;
  BuildContext? _target;
  Animation<double>? _routeAnimation;

  void _register(String id, BuildContext target) {
    if (_handled || id != widget.initialSection) return;
    _target = target;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (!mounted || _handled || _target?.mounted != true) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && animation.status == AnimationStatus.forward) {
      if (_routeAnimation == null) {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteStatus);
      }
      return;
    }
    _handled = true;
    Scrollable.ensureVisible(
      _target!,
      alignment: 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppConstants.animationNormal,
      curve: Curves.easeOutCubic,
    );
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TargetScope(
      state: this,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (notification) {
          // Never fight a user who starts scrolling before layout completes.
          if (notification.dragDetails != null) _handled = true;
          return false;
        },
        child: widget.child,
      ),
    );
  }
}

class _TargetScope extends InheritedWidget {
  const _TargetScope({required this.state, required super.child});

  final _SettingsScrollTargetState state;

  @override
  bool updateShouldNotify(_TargetScope oldWidget) => state != oldWidget.state;
}

class SettingsSectionAnchor extends StatefulWidget {
  const SettingsSectionAnchor({
    super.key,
    required this.id,
    required this.child,
  });

  final String id;
  final Widget child;

  @override
  State<SettingsSectionAnchor> createState() => _SettingsSectionAnchorState();
}

class _SettingsSectionAnchorState extends State<SettingsSectionAnchor> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.dependOnInheritedWidgetOfExactType<_TargetScope>()?.state._register(
      widget.id,
      context,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
