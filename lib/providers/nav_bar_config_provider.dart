import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flick/models/nav_bar_config.dart';

class NavBarConfigNotifier extends Notifier<NavBarConfig> {
  static const _buttonsKey = 'nav_bar_buttons';
  static const _hiddenKey = 'nav_bar_hidden';
  static const _sizeKey = 'nav_bar_size';
  static const _spacingKey = 'nav_bar_spacing';
  static const _iconSizeKey = 'nav_bar_icon_size';
  static const _showLabelsKey = 'nav_bar_show_labels';

  bool _initialized = false;

  @override
  NavBarConfig build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_load);
    }
    return NavBarConfig.defaultConfig;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;

    final buttonsStr = prefs.getString(_buttonsKey);
    final buttons = buttonsStr != null
        ? _parseButtons(buttonsStr)
        : NavBarConfig.allButtons;

    final hiddenStr = prefs.getString(_hiddenKey);
    final hidden = hiddenStr != null
        ? _parseButtonSet(hiddenStr)
        : <NavBarButton>{};

    state = NavBarConfig(
      enabledButtons: buttons.isEmpty ? NavBarConfig.allButtons : buttons,
      hidden: hidden,
      barSizeFactor: prefs.getDouble(_sizeKey) ?? 1.0,
      buttonSpacingFactor: prefs.getDouble(_spacingKey) ?? 1.0,
      iconSizeFactor: prefs.getDouble(_iconSizeKey) ?? 1.0,
      showLabels: prefs.getBool(_showLabelsKey) ?? true,
    );
  }

  List<NavBarButton> _parseButtons(String raw) {
    final result = <NavBarButton>[];
    for (final name in raw.split(',')) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      try {
        result.add(NavBarButton.values.byName(trimmed));
      } catch (_) {}
    }
    return result;
  }

  Set<NavBarButton> _parseButtonSet(String raw) {
    final result = <NavBarButton>{};
    for (final name in raw.split(',')) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      try {
        result.add(NavBarButton.values.byName(trimmed));
      } catch (_) {}
    }
    return result;
  }

  String _serializeButtons(List<NavBarButton> buttons) {
    return buttons.map((b) => b.name).join(',');
  }

  String _serializeButtonSet(Set<NavBarButton> buttons) {
    return buttons.map((b) => b.name).join(',');
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_buttonsKey, _serializeButtons(state.enabledButtons));
    await prefs.setString(_hiddenKey, _serializeButtonSet(state.hidden));
    await prefs.setDouble(_sizeKey, state.barSizeFactor);
    await prefs.setDouble(_spacingKey, state.buttonSpacingFactor);
    await prefs.setDouble(_iconSizeKey, state.iconSizeFactor);
    await prefs.setBool(_showLabelsKey, state.showLabels);
  }

  Future<void> setEnabledButtons(List<NavBarButton> buttons) async {
    if (buttons.isEmpty) return;
    if (_buttonsEqual(state.enabledButtons, buttons)) return;
    state = state.copyWith(enabledButtons: buttons);
    await _persist();
  }

  Future<void> toggleButton(NavBarButton button) async {
    final updated = List<NavBarButton>.from(state.enabledButtons);
    if (updated.contains(button)) {
      if (updated.length == 1) return;
      updated.remove(button);
    } else {
      updated.add(button);
    }
    state = state.copyWith(enabledButtons: updated);
    await _persist();
  }

  Future<void> toggleHidden(NavBarButton button) async {
    final updated = Set<NavBarButton>.from(state.hidden);
    if (updated.contains(button)) {
      updated.remove(button);
    } else {
      updated.add(button);
    }
    state = state.copyWith(hidden: updated);
    await _persist();
  }

  Future<void> reorderButtons(int oldIndex, int newIndex) async {
    state = state.reorder(oldIndex, newIndex);
    await _persist();
  }

  Future<void> setBarSizeFactor(double value) async {
    if (state.barSizeFactor == value) return;
    state = state.copyWith(barSizeFactor: value);
    await _persist();
  }

  Future<void> setButtonSpacingFactor(double value) async {
    if (state.buttonSpacingFactor == value) return;
    state = state.copyWith(buttonSpacingFactor: value);
    await _persist();
  }

  Future<void> setIconSizeFactor(double value) async {
    if (state.iconSizeFactor == value) return;
    state = state.copyWith(iconSizeFactor: value);
    await _persist();
  }

  Future<void> setShowLabels(bool value) async {
    if (state.showLabels == value) return;
    state = state.copyWith(showLabels: value);
    await _persist();
  }

  bool _buttonsEqual(List<NavBarButton> a, List<NavBarButton> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final navBarConfigProvider =
    NotifierProvider<NavBarConfigNotifier, NavBarConfig>(
      NavBarConfigNotifier.new,
    );
