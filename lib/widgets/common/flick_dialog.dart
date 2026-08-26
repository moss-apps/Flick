import 'package:flick/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flick/core/theme/app_colors.dart';

/// Flick's standard dialog entrance: fade + scale-up with a slight
/// overshoot, on top of the shared scrim.
Future<T?> showFlickDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Dialog',
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor:
        barrierColor ?? Colors.black.withValues(alpha: 0.5),
    transitionDuration: AppConstants.animationDialog,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: builder(context),
        ),
      );
    },
  );
}

enum FlickDialogButtonStyle { primary, secondary, destructive }

class FlickDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final FlickDialogButtonStyle style;

  const FlickDialogButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = FlickDialogButtonStyle.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Border? border;
    final Color foreground;
    switch (style) {
      case FlickDialogButtonStyle.primary:
        background = AppColors.textPrimary;
        border = null;
        foreground = AppColors.background;
      case FlickDialogButtonStyle.secondary:
        background = AppColors.glassBackgroundStrong;
        border = Border.all(color: AppColors.glassBorder);
        foreground = AppColors.textPrimary;
      case FlickDialogButtonStyle.destructive:
        background = AppColors.error;
        border = null;
        foreground = AppColors.backgroundDark;
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: border,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            // Size factors keep the button intrinsic inside a Wrap, but let
            // it stretch and center the label under tight width (Expanded).
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass-styled text field used inside dialogs.
class FlickTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool enabled;

  const FlickTextField({
    super.key,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onSubmitted,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBackgroundStrong,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary),
          counterText: '',
          contentPadding: const EdgeInsets.all(AppConstants.spacingMd),
          border: InputBorder.none,
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// The shared Flick dialog surface: near-opaque dark gradient, radius 24,
/// glass border, soft shadow. Use directly for custom popup content
/// (celebration cards etc.) or through [FlickDialog].
class FlickDialogSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? maxHeight;

  const FlickDialogSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppConstants.spacingLg),
    this.width,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: width ?? 400,
        maxHeight: maxHeight ?? double.infinity,
      ),
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceLight.withValues(alpha: 0.98),
            AppColors.surface.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The standard Flick dialog: title, optional icon, scrollable content and
/// actions on the shared [FlickDialogSurface].
class FlickDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool destructive;
  final Color? iconColor;
  final Widget? content;
  final List<Widget> actions;
  final double? width;

  const FlickDialog({
    super.key,
    required this.title,
    this.icon,
    this.destructive = false,
    this.iconColor,
    this.content,
    this.actions = const [],
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingXl,
      ),
      alignment: Alignment.center,
      child: FlickDialogSurface(
        maxHeight: maxHeight,
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: iconColor ?? _iconColor),
                  const SizedBox(width: AppConstants.spacingSm),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (content != null) ...[
              const SizedBox(height: AppConstants.spacingMd),
              Flexible(
                child: SingleChildScrollView(
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyMedium!,
                    child: content!,
                  ),
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingLg),
              if (actions.length == 2)
                Row(
                  children: [
                    Expanded(child: actions[0]),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(child: actions[1]),
                  ],
                )
              else if (actions.length == 3)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: double.infinity, child: actions[0]),
                    const SizedBox(height: AppConstants.spacingSm),
                    SizedBox(width: double.infinity, child: actions[1]),
                    const SizedBox(height: AppConstants.spacingSm),
                    SizedBox(width: double.infinity, child: actions[2]),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppConstants.spacingSm,
                  runSpacing: AppConstants.spacingXs,
                  children: actions,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color get _iconColor => destructive ? AppColors.error : AppColors.textSecondary;
}

/// One-call helpers for the two most common dialog shapes.
class FlickDialogs {
  FlickDialogs._();

  /// Confirmation dialog. Returns true only when [confirmLabel] was tapped.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
    Color? iconColor,
  }) {
    final effectiveIcon =
        icon ?? (destructive ? Icons.warning_amber_rounded : null);
    return showFlickDialog<bool>(
      context: context,
      barrierLabel: title,
      builder: (dialogContext) => FlickDialog(
        title: title,
        icon: effectiveIcon,
        destructive: destructive,
        iconColor: iconColor,
        content: message == null
            ? null
            : Text(
                message,
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
        actions: [
          FlickDialogButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          FlickDialogButton(
            label: confirmLabel,
            style: destructive
                ? FlickDialogButtonStyle.destructive
                : FlickDialogButtonStyle.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    ).then((result) => result ?? false);
  }

  /// Text input dialog. Returns the trimmed value, or null when dismissed.
  /// Empty submits stay open unless [validator] allows them.
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? message,
    String? hintText,
    String? initialValue,
    String confirmLabel = 'Save',
    String cancelLabel = 'Cancel',
    IconData? icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    String? Function(String value)? validator,
  }) {
    return showFlickDialog<String>(
      context: context,
      barrierLabel: title,
      builder: (_) => _FlickInputDialog(
        title: title,
        message: message,
        hintText: hintText,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLength: maxLength,
        validator: validator,
      ),
    );
  }
}

class _FlickInputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String? hintText;
  final String? initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? Function(String value)? validator;

  const _FlickInputDialog({
    required this.title,
    this.message,
    this.hintText,
    this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.validator,
  });

  @override
  State<_FlickInputDialog> createState() => _FlickInputDialogState();
}

class _FlickInputDialogState extends State<_FlickInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  String? _error;

  void _submit() {
    final value = _controller.text.trim();
    if (widget.validator != null) {
      final error = widget.validator!(value);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    } else if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return FlickDialog(
      title: widget.title,
      icon: widget.icon,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(
              widget.message!,
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],
          FlickTextField(
            controller: _controller,
            hint: widget.hintText,
            autofocus: true,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            maxLength: widget.maxLength,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppConstants.spacingXs),
            Text(_error!, style: TextStyle(color: AppColors.error)),
          ],
        ],
      ),
      actions: [
        FlickDialogButton(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        FlickDialogButton(
          label: widget.confirmLabel,
          style: FlickDialogButtonStyle.primary,
          onPressed: _submit,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
