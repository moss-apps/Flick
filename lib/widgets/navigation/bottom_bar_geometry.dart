import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/utils/responsive.dart';
import 'package:flick/models/mini_player_config.dart';
import 'package:flick/models/nav_bar_config.dart';

class BottomBarGeometry {
  BottomBarGeometry._();

  static const double minWidthFraction = 0.7;
  static const double maxWidthFraction = 1.0;
  static const double _minNavigationItemWidth = 44.0;

  static double navigationInset(BuildContext context) =>
      context.scaleSize(AppConstants.spacingLg);

  static double standardNavigationWidth(
    BuildContext context, {
    double? availableWidth,
  }) {
    final width =
        availableWidth ??
        (MediaQuery.sizeOf(context).width -
            MediaQuery.paddingOf(context).horizontal);
    return math.max(0.0, width - 2 * navigationInset(context));
  }

  static double navigationWidth(
    BuildContext context,
    NavBarConfig config, {
    double? availableWidth,
  }) {
    final fullWidth = standardNavigationWidth(
      context,
      availableWidth: availableWidth,
    );
    final itemCount =
        config.orderedButtons.length +
        (config.missingEssentials.isEmpty ? 0 : 1);
    final itemPadding =
        context.scaleSize(AppConstants.spacingMd) * config.buttonSpacingFactor;
    final minimumWidth = itemCount * _minNavigationItemWidth + 2 * itemPadding;
    final fraction = config.widthFraction.clamp(
      minWidthFraction,
      maxWidthFraction,
    );
    return math.min(fullWidth, math.max(fullWidth * fraction, minimumWidth));
  }

  static double miniPlayerHeight(
    BuildContext context,
    MiniPlayerConfig config,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontFamily: 'GoogleSansFlex',
          fontSize: 14 * config.textScale,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final artist = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(
          fontFamily: 'GoogleSansFlex',
          fontSize: 12 * config.textScale,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final textHeight =
        title.height + (config.showArtist ? artist.height + 2 : 0);
    title.dispose();
    artist.dispose();
    return math.max(config.height, textHeight + 12);
  }

  static double extraClearance(
    BuildContext context,
    MiniPlayerConfig config,
    bool separated,
  ) => math.max(
    0,
    miniPlayerHeight(context, config) -
        56 +
        (separated ? config.navigationGap - 8 : 0),
  );
}
