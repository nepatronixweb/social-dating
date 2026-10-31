import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] for the app.
abstract final class AppTheme {
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.rose600,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.rose100,
    onPrimaryContainer: AppColors.rose700,
    secondary: AppColors.ink900,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.sand100,
    onSecondaryContainer: AppColors.ink900,
    tertiary: AppColors.success,
    onTertiary: AppColors.white,
    error: AppColors.danger,
    onError: AppColors.white,
    errorContainer: Color(0xFFFCE4E2),
    onErrorContainer: Color(0xFF7A1812),
    surface: AppColors.white,
    onSurface: AppColors.ink900,
    onSurfaceVariant: AppColors.ink500,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.sand50,
    surfaceContainer: AppColors.sand100,
    surfaceContainerHigh: AppColors.sand100,
    surfaceContainerHighest: AppColors.sand200,
    outline: AppColors.ink300,
    outlineVariant: AppColors.sand200,
    shadow: AppColors.ink900,
    scrim: AppColors.ink900,
    inverseSurface: AppColors.ink900,
    onInverseSurface: AppColors.sand50,
    inversePrimary: AppColors.rose300,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.rose400,
    onPrimary: Color(0xFF2A0A10),
    primaryContainer: Color(0xFF5C1D28),
    onPrimaryContainer: AppColors.rose100,
    secondary: AppColors.moon100,
    onSecondary: AppColors.night900,
    secondaryContainer: AppColors.night600,
    onSecondaryContainer: AppColors.moon100,
    tertiary: AppColors.successDark,
    onTertiary: AppColors.night900,
    error: AppColors.dangerDark,
    onError: Color(0xFF3B0A07),
    errorContainer: Color(0xFF5C1D18),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.night800,
    onSurface: AppColors.moon100,
    onSurfaceVariant: AppColors.moon400,
    surfaceContainerLowest: AppColors.night900,
    surfaceContainerLow: AppColors.night800,
    surfaceContainer: AppColors.night700,
    surfaceContainerHigh: AppColors.night700,
    surfaceContainerHighest: AppColors.night600,
    outline: Color(0xFF8A8190),
    outlineVariant: AppColors.night600,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.moon100,
    onInverseSurface: AppColors.night900,
    inversePrimary: AppColors.rose600,
  );

  static ThemeData get light => _build(_lightScheme, AppPalette.light);
  static ThemeData get dark => _build(_darkScheme, AppPalette.dark);

  static ThemeData _build(ColorScheme scheme, AppPalette palette) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = AppTypography.textTheme(
      ink: scheme.onSurface,
      muted: palette.textMuted,
    );

    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.pageBackground,
      canvasColor: palette.pageBackground,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerTheme: DividerThemeData(
        color: palette.outlineSoft,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.pageBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.outline),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: border(palette.outlineSoft),
        enabledBorder: border(palette.outlineSoft),
        focusedBorder: border(scheme.primary, width: 2),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, width: 2),
        disabledBorder: border(palette.outlineSoft),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderXl),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: palette.outlineSoft,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: palette.outlineSoft)),
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouchTarget, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
          side: BorderSide(color: palette.outlineSoft),
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // The selected tab is marked by colour and an underline rather than a
        // filled pill.
        indicatorColor: Colors.transparent,
        height: 68,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : palette.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.primary,
                  decorationThickness: 2,
                )
              : textTheme.labelMedium?.copyWith(color: palette.textMuted),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : palette.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        textStyle: textTheme.labelSmall?.copyWith(letterSpacing: 0),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
