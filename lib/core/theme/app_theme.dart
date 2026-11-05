import 'package:flutter/material.dart';
import 'package:flick/core/constants/app_constants.dart';
import 'app_colors.dart';

/// App theme configuration with Google Sans Flex font and dark theme.
class AppTheme {
  AppTheme._();

  /// Google Sans Flex font family name
  static const String _fontFamily = 'GoogleSansFlex';

  /// Families tried, in order, for every style in [darkTheme].
  ///
  /// Google Sans Flex has no CJK glyphs, so Chinese comes from the bundled
  /// Noto Sans SC subset (see pubspec.yaml). Skia does not search bundled fonts
  /// for missing characters, so the fallback has to be declared explicitly
  /// here. The same applies to the Baybayin pilot's Noto Sans Tagalog.
  static const List<String> fontFamilyFallback = <String>[
    'NotoSansSC',
    'NotoSansTagalog',
  ];

  /// Primary text theme using Google Sans Flex
  static TextTheme get _textTheme {
    return const TextTheme(
      // Display styles
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 45,
        fontWeight: FontWeight.w300,
        color: AppColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),

      // Headline styles
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),

      // Title styles
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),

      // Body styles
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: AppColors.textTertiary,
      ),

      // Label styles
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.textTertiary,
      ),
    ).apply(fontFamilyFallback: fontFamilyFallback);
  }

  /// Dark theme for the app
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textPrimary,
        onPrimary: AppColors.background,
        secondary: AppColors.accent,
        onSecondary: AppColors.background,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.background,
      ),

      // Text theme
      textTheme: _textTheme,

      // Let the app's sheet surfaces use the available window, rather than
      // Material 3's fixed 640dp modal-route cap on landscape/tablets.
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(maxWidth: double.infinity),
      ),

      // Shared transient feedback: a quiet surface with native Material motion.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: _textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.accentLight,
        closeIconColor: AppColors.textSecondary,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: const BorderSide(color: AppColors.glassBorderStrong),
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.glassBackgroundStrong,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.glassBorder, width: 1),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
        space: 1,
      ),

      // Monochrome chips (format pickers, filters)
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.glassBackgroundStrong,
        selectedColor: Color(0x1AE0E0E0), // 10% accent
        checkmarkColor: AppColors.textPrimary,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        side: BorderSide(color: AppColors.glassBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppConstants.radiusSm)),
        ),
      ),

      // Dialog theme — safety net so any stray Material dialog still reads
      // as Flick. Prefer FlickDialog for new code.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.98),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        titleTextStyle: _textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: _textTheme.bodyMedium,
      ),
    );
  }
}
