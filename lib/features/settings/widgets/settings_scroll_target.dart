import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';

/// The localized title of the search result that pushed the current route.
/// [SettingsScrollTarget] uses it to reveal the exact row, not just the
/// section. Title matching is intentional: the catalog and the destination
/// rows both use the same localized strings, so no IDs have to be threaded
/// through every settings screen constructor.
class SettingsSearchArrival extends InheritedWidget {
  const SettingsSearchArrival({
    super.key,
    this.itemTitle,
    required super.child,
  });

  final String? itemTitle;

  static SettingsSearchArrival? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsSearchArrival>();

  @override
  bool updateShouldNotify(SettingsSearchArrival oldWidget) =>
      itemTitle != oldWidget.itemTitle;
}

/// One-shot, route-local section/item navigation. IDs are stable, never
/// translated. Missing/conditional sections leave the page at its normal
/// starting position.
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
  static const _highlightHold = Duration(milliseconds: 1800);

  bool _handled = false;
  bool _revealScheduled = false;
  String? _itemTitle;
  Animation<double>? _routeAnimation;
  Timer? _highlightTimer;
  final _highlighted = ValueNotifier<Object?>(null);
  final _sections = <String, _SettingsSectionAnchorState>{};
  final _rows = <String, Set<_SettingsSearchAnchorState>>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _itemTitle = SettingsSearchArrival.maybeOf(context)?.itemTitle;
  }

  void _registerSection(String id, _SettingsSectionAnchorState anchor) {
    _sections[id] = anchor;
    if (!_handled && id == widget.initialSection) _scheduleReveal();
  }

  void _unregisterSection(String id, _SettingsSectionAnchorState anchor) {
    if (identical(_sections[id], anchor)) _sections.remove(id);
  }

  void _registerRow(Set<String> titles, _SettingsSearchAnchorState anchor) {
    for (final title in titles) {
      (_rows[title] ??= <_SettingsSearchAnchorState>{}).add(anchor);
    }
    final itemTitle = _itemTitle;
    if (!_handled && itemTitle != null && titles.contains(itemTitle)) {
      _scheduleReveal();
    }
  }

  void _unregisterRow(Set<String> titles, _SettingsSearchAnchorState anchor) {
    for (final title in titles) {
      final anchors = _rows[title];
      anchors?.remove(anchor);
      if (anchors != null && anchors.isEmpty) _rows.remove(title);
    }
  }

  void _scheduleReveal() {
    if (_handled || _revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (mounted) unawaited(_reveal());
    });
  }

  Future<void> _reveal() async {
    if (!mounted || _handled) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation != null && animation.status == AnimationStatus.forward) {
      if (_routeAnimation == null) {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteStatus);
      }
      return;
    }
    final section = widget.initialSection == null
        ? null
        : _sections[widget.initialSection];
    final row = _itemTitle == null ? null : _findRow(_itemTitle!, section);
    final target = row?.context ?? section?.context;
    if (target == null) return;

    _handled = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    await Scrollable.ensureVisible(
      target,
      alignment: row == null ? 0 : 0.18,
      duration: reduceMotion ? Duration.zero : AppConstants.animationNormal,
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _highlight(row ?? section);
  }

  /// Picks the first matching row at or below the target section. This keeps
  /// repeated labels such as "Text Size" attached to the right section.
  _SettingsSearchAnchorState? _findRow(
    String title,
    _SettingsSectionAnchorState? section,
  ) {
    final candidates = _rows[title];
    if (candidates == null || candidates.isEmpty) return null;
    final mounted = candidates.where((anchor) => anchor.mounted).toList();
    if (mounted.isEmpty) return null;
    if (section == null || !section.mounted) return mounted.first;

    final sectionBox = section.context.findRenderObject();
    if (sectionBox is! RenderBox || !sectionBox.attached) return mounted.first;
    final sectionTop = sectionBox.localToGlobal(Offset.zero).dy;
    _SettingsSearchAnchorState? best;
    var bestDelta = double.infinity;
    for (final anchor in mounted) {
      final box = anchor.context.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final delta = box.localToGlobal(Offset.zero).dy - sectionTop;
      if (delta < -1) continue;
      if (delta < bestDelta) {
        bestDelta = delta;
        best = anchor;
      }
    }
    return best;
  }

  void _highlight(Object? anchor) {
    _highlighted.value = anchor;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_highlightHold, () {
      if (mounted) _highlighted.value = null;
    });
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    _scheduleReveal();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _highlighted.dispose();
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialSection == null && _itemTitle == null) {
      return widget.child;
    }
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
  _SettingsScrollTargetState? _scope;
  bool _registered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TargetScope>()
        ?.state;
    if (!identical(scope, _scope)) {
      if (_registered) _scope?._unregisterSection(widget.id, this);
      _scope = scope;
      _registered = false;
    }
    if (!_registered && scope != null) {
      scope._registerSection(widget.id, this);
      _registered = true;
    }
  }

  @override
  void dispose() {
    if (_registered) _scope?._unregisterSection(widget.id, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    if (scope == null) return widget.child;
    return ValueListenableBuilder<Object?>(
      valueListenable: scope._highlighted,
      builder: (context, highlighted, child) => _HighlightFrame(
        highlighted: identical(highlighted, this),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

/// Registers a regular settings row by its localized title so search can
/// scroll to and highlight it. Wrapping the existing row widgets keeps every
/// settings screen automatically searchable without per-screen plumbing.
class SettingsSearchAnchor extends StatefulWidget {
  const SettingsSearchAnchor({
    super.key,
    required this.titles,
    required this.child,
  });

  final List<String> titles;
  final Widget child;

  @override
  State<SettingsSearchAnchor> createState() => _SettingsSearchAnchorState();
}

class _SettingsSearchAnchorState extends State<SettingsSearchAnchor> {
  _SettingsScrollTargetState? _scope;
  Set<String> _registeredTitles = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TargetScope>()
        ?.state;
    if (!identical(scope, _scope)) {
      if (_scope != null) {
        _scope!._unregisterRow(_registeredTitles, this);
      }
      _scope = scope;
      _registeredTitles = const {};
    }
    _syncRegistration();
  }

  @override
  void didUpdateWidget(SettingsSearchAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRegistration();
  }

  void _syncRegistration() {
    final scope = _scope;
    if (scope == null) return;
    final titles = widget.titles.toSet();
    if (titles.length == _registeredTitles.length &&
        titles.every(_registeredTitles.contains)) {
      return;
    }
    if (_registeredTitles.isNotEmpty) {
      scope._unregisterRow(_registeredTitles, this);
    }
    _registeredTitles = titles;
    if (titles.isNotEmpty) scope._registerRow(titles, this);
  }

  @override
  void dispose() {
    _scope?._unregisterRow(_registeredTitles, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    if (scope == null) return widget.child;
    return ValueListenableBuilder<Object?>(
      valueListenable: scope._highlighted,
      builder: (context, highlighted, child) => _HighlightFrame(
        highlighted: identical(highlighted, this),
        child: child!,
      ),
      child: widget.child,
    );
  }
}

class _HighlightFrame extends StatelessWidget {
  const _HighlightFrame({
    required this.highlighted,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final bool highlighted;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : AppConstants.animationFast,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: highlighted
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
