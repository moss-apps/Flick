import 'package:flick/core/constants/app_constants.dart';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppBottomSheetSurface extends StatelessWidget {
  final Widget child;
  final double? maxHeightRatio;
  final EdgeInsetsGeometry? padding;

  const AppBottomSheetSurface({
    super.key,
    required this.child,
    this.maxHeightRatio,
    this.padding,
  });

  static final BoxDecoration decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.surfaceLight.withValues(alpha: 0.98),
        AppColors.surface.withValues(alpha: 0.98),
      ],
    ),
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppConstants.radiusXl),
    ),
    border: Border.all(color: AppColors.glassBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 20,
        offset: const Offset(0, -6),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = maxHeightRatio != null
        ? mediaQuery.size.height * maxHeightRatio!
        : mediaQuery.size.height * 0.85;

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Container(
                  decoration: decoration,
                  padding:
                      padding ??
                      EdgeInsets.fromLTRB(
                        AppConstants.spacingLg,
                        AppConstants.spacingSm,
                        AppConstants.spacingLg,
                        mediaQuery.padding.bottom + AppConstants.spacingLg,
                      ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A reusable bottom sheet dialog with Product Sans font.
class GlassBottomSheet extends StatelessWidget {
  /// Title displayed at the top of the bottom sheet
  final String? title;

  /// Main content of the bottom sheet
  final Widget? content;

  /// Action buttons at the bottom
  final List<Widget>? actions;

  /// Whether to show the drag handle at the top
  final bool showDragHandle;

  /// Whether the bottom sheet can be dismissed by dragging
  final bool isDismissible;

  /// Whether the bottom sheet can be scrolled
  final bool isScrollControlled;

  /// Maximum height ratio of screen (0.0 to 1.0)
  final double? maxHeightRatio;

  /// Custom padding for the content
  final EdgeInsets? contentPadding;

  const GlassBottomSheet({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.showDragHandle = true,
    this.isDismissible = true,
    this.isScrollControlled = true,
    this.maxHeightRatio,
    this.contentPadding,
  });

  /// Shows the glass bottom sheet as a modal.
  ///
  /// Usage:
  /// ```dart
  /// GlassBottomSheet.show(
  ///   context: context,
  ///   title: 'Select Option',
  ///   content: MyContentWidget(),
  ///   actions: [
  ///     TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
  ///     ElevatedButton(onPressed: () {}, child: Text('Confirm')),
  ///   ],
  /// );
  /// ```
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? content,
    List<Widget>? actions,
    bool showDragHandle = true,
    bool isDismissible = true,
    bool isScrollControlled = true,
    double? maxHeightRatio,
    EdgeInsets? contentPadding,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => GlassBottomSheet(
        title: title,
        content: content,
        actions: actions,
        showDragHandle: showDragHandle,
        isDismissible: isDismissible,
        isScrollControlled: isScrollControlled,
        maxHeightRatio: maxHeightRatio,
        contentPadding: contentPadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return AppBottomSheetSurface(
      maxHeightRatio: maxHeightRatio,
      padding: EdgeInsets.only(
        bottom: mediaQuery.padding.bottom + AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) _buildDragHandle(),
          if (title != null) _buildTitle(context),
          if (content != null)
            Flexible(
              fit: FlexFit.loose,
              child: Padding(
                padding:
                    contentPadding ??
                    const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingLg,
                    ),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!,
                  child: RepaintBoundary(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: content!,
                    ),
                  ),
                ),
              ),
            ),
          if (actions != null && actions!.isNotEmpty) _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      padding: const EdgeInsets.only(top: AppConstants.spacingSm),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            borderRadius: BorderRadius.circular(AppConstants.radiusRound),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (isDismissible)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacingXs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingXs,
        AppConstants.spacingLg,
        AppConstants.spacingXs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions!.map((action) {
          return Padding(
            padding: const EdgeInsets.only(left: AppConstants.spacingXs),
            child: action,
          );
        }).toList(),
      ),
    );
  }
}

/// Extension methods for easily showing glass bottom sheets
extension GlassBottomSheetExtension on BuildContext {
  /// Shows a glass bottom sheet with the given configuration.
  Future<T?> showGlassBottomSheet<T>({
    String? title,
    Widget? content,
    List<Widget>? actions,
    bool showDragHandle = true,
    bool isDismissible = true,
    bool isScrollControlled = true,
    double? maxHeightRatio,
    EdgeInsets? contentPadding,
    bool enableDrag = true,
  }) {
    return GlassBottomSheet.show<T>(
      context: this,
      title: title,
      content: content,
      actions: actions,
      showDragHandle: showDragHandle,
      isDismissible: isDismissible,
      isScrollControlled: isScrollControlled,
      maxHeightRatio: maxHeightRatio,
      contentPadding: contentPadding,
      enableDrag: enableDrag,
    );
  }
}
