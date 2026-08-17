import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/adaptive_color_provider.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/core/utils/responsive.dart';

/// Icon button on a solid surface gradient. Cheaper to paint than a
/// translucent glass background over the ambient artwork.
class SurfaceIconButton extends StatelessWidget {
  const SurfaceIconButton({super.key, required this.child, this.compact = false})
      : icon = null,
        onPressed = null,
        iconColor = null;

  const SurfaceIconButton.icon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.compact = false,
  }) : child = null;

  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Widget? child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.75),
            AppColors.surface.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: icon != null
          ? IconButton(
              onPressed: onPressed,
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              constraints: compact
                  ? const BoxConstraints(minWidth: 36, minHeight: 36)
                  : const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: compact
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.all(8),
              icon: Icon(
                icon,
                color: iconColor ?? context.adaptiveTextSecondary,
                size: context.responsiveIcon(AppConstants.iconSizeMd),
              ),
            )
          : child!,
    );
  }
}
