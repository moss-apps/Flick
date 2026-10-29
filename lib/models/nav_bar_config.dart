import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum NavBarButton {
  menu(0, LucideIcons.layoutGrid),
  songs(1, LucideIcons.music),
  settings(2, LucideIcons.settings),
  albums(3, LucideIcons.disc),
  artists(4, LucideIcons.users),
  folders(5, LucideIcons.folder),
  playlists(6, LucideIcons.listMusic),
  favorites(7, LucideIcons.heart),
  search(8, LucideIcons.search);

  const NavBarButton(this.pageIndex, this.icon);

  final int pageIndex;
  final IconData icon;
}

class NavBarConfig {
  final List<NavBarButton> enabledButtons;
  final Set<NavBarButton> hidden;
  final double barSizeFactor;
  final double buttonSpacingFactor;
  final double iconSizeFactor;
  final bool showLabels;
  final double widthFraction;

  static const allButtons = [
    NavBarButton.menu,
    NavBarButton.songs,
    NavBarButton.settings,
  ];

  const NavBarConfig({
    this.enabledButtons = allButtons,
    this.hidden = const {},
    this.barSizeFactor = 1.0,
    this.buttonSpacingFactor = 1.0,
    this.iconSizeFactor = 1.0,
    this.showLabels = true,
    this.widthFraction = 1.0,
  });

  static const defaultConfig = NavBarConfig();

  List<NavBarButton> get orderedButtons => enabledButtons;

  bool get hasAllEssential =>
      enabledButtons.contains(NavBarButton.menu) &&
      enabledButtons.contains(NavBarButton.songs) &&
      enabledButtons.contains(NavBarButton.settings);

  List<NavBarButton> get missingEssentials {
    const essential = {NavBarButton.menu, NavBarButton.songs, NavBarButton.settings};
    return essential
        .where((b) => !enabledButtons.contains(b) && !hidden.contains(b))
        .toList()
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  }

  NavBarConfig reorder(int oldIndex, int newIndex) {
    final list = List<NavBarButton>.from(enabledButtons);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return copyWith(enabledButtons: list);
  }

  NavBarConfig copyWith({
    List<NavBarButton>? enabledButtons,
    Set<NavBarButton>? hidden,
    double? barSizeFactor,
    double? buttonSpacingFactor,
    double? iconSizeFactor,
    bool? showLabels,
    double? widthFraction,
  }) {
    return NavBarConfig(
      enabledButtons: enabledButtons ?? this.enabledButtons,
      hidden: hidden ?? this.hidden,
      barSizeFactor: barSizeFactor ?? this.barSizeFactor,
      buttonSpacingFactor: buttonSpacingFactor ?? this.buttonSpacingFactor,
      iconSizeFactor: iconSizeFactor ?? this.iconSizeFactor,
      showLabels: showLabels ?? this.showLabels,
      widthFraction: widthFraction ?? this.widthFraction,
    );
  }
}
