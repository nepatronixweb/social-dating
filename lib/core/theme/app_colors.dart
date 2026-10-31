import 'package:flutter/material.dart';

/// Raw colour tokens. Prefer reading colours from `Theme.of(context)`
/// (`ColorScheme` + [AppPalette]) in widgets so light and dark stay in sync.
abstract final class AppColors {
  // Brand: a warm rose-coral. `rose600` on white is 4.8:1 (WCAG AA for text);
  // gradient stops are kept >= 4.5:1 against white (verified in theme_test).
  static const Color rose300 = Color(0xFFFF9AA2);
  static const Color rose400 = Color(0xFFFF7B86);
  static const Color rose500 = Color(0xFFE5576A);
  static const Color rose600 = Color(0xFFCF3A4A);
  static const Color rose700 = Color(0xFFB02E3F);
  static const Color rose50 = Color(0xFFFFF0F1);
  static const Color rose100 = Color(0xFFFFDDE0);
  static const Color blush50 = Color(0xFFFFF6F8);

  // Ink: deep, slightly violet-tinted near-black for text.
  static const Color ink900 = Color(0xFF1B1620);
  static const Color ink700 = Color(0xFF3A3340);
  static const Color ink500 = Color(0xFF5E5763);
  static const Color ink300 = Color(0xFF9A939F);

  // Warm neutrals for light surfaces.
  static const Color sand50 = Color(0xFFFAF7F4);
  static const Color sand100 = Color(0xFFF3EEE9);
  static const Color sand200 = Color(0xFFE8E1DB);
  static const Color white = Color(0xFFFFFFFF);

  // Dark theme surfaces. Slightly magenta-shifted so branded screens feel
  // cinematic without hurting body-text contrast.
  static const Color night900 = Color(0xFF120812);
  static const Color night800 = Color(0xFF1A0E16);
  static const Color night700 = Color(0xFF26141E);
  static const Color night600 = Color(0xFF3A2430);
  static const Color moon100 = Color(0xFFF5EFF3);
  static const Color moon400 = Color(0xFFB9B0BE);

  // Violet used in the two-figure mark (paired with rose).
  static const Color violet500 = Color(0xFFB056F0);
  static const Color violet800 = Color(0xFF5A1D7A);

  // Semantic.
  static const Color success = Color(0xFF1E7F5C);
  static const Color successDark = Color(0xFF52D1A0);
  static const Color warning = Color(0xFF9A5B00);
  static const Color warningDark = Color(0xFFFFC266);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerDark = Color(0xFFFF8A80);
}

/// Brand-specific colours that don't fit Material's [ColorScheme].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brandGradient,
    required this.markGradient,
    required this.atmospherePrimary,
    required this.atmosphereSecondary,
    required this.pageBackground,
    required this.surfaceMuted,
    required this.textMuted,
    required this.outlineSoft,
    required this.success,
    required this.warning,
    required this.imageScrim,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// Subtle two-stop gradient used on primary actions and brand marks only.
  final LinearGradient brandGradient;

  /// Pink-to-violet wash for the two-figure mark. Not used as button text
  /// contrast; the mark is the colour.
  final LinearGradient markGradient;

  /// Soft orb colour for branded welcome / splash atmosphere.
  final Color atmospherePrimary;
  final Color atmosphereSecondary;
  final Color pageBackground;
  final Color surfaceMuted;
  final Color textMuted;
  final Color outlineSoft;
  final Color success;
  final Color warning;
  final Color imageScrim;
  final Color skeletonBase;
  final Color skeletonHighlight;

  static const AppPalette light = AppPalette(
    brandGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFD2404F), Color(0xFFC23446)],
    ),
    markGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.rose400, AppColors.violet500],
    ),
    atmospherePrimary: AppColors.rose100,
    atmosphereSecondary: Color(0xFFE8D4F2),
    pageBackground: AppColors.sand50,
    surfaceMuted: AppColors.sand100,
    textMuted: AppColors.ink500,
    outlineSoft: AppColors.sand200,
    success: AppColors.success,
    warning: AppColors.warning,
    imageScrim: Color(0xCC1B1620),
    skeletonBase: AppColors.sand100,
    skeletonHighlight: AppColors.sand50,
  );

  static const AppPalette dark = AppPalette(
    brandGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [AppColors.rose300, AppColors.rose400],
    ),
    markGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.rose300, AppColors.violet500],
    ),
    atmospherePrimary: Color(0xFF7A1848),
    atmosphereSecondary: AppColors.violet800,
    pageBackground: AppColors.night900,
    surfaceMuted: AppColors.night700,
    textMuted: AppColors.moon400,
    outlineSoft: AppColors.night600,
    success: AppColors.successDark,
    warning: AppColors.warningDark,
    imageScrim: Color(0xD9120812),
    skeletonBase: AppColors.night700,
    skeletonHighlight: AppColors.night600,
  );

  @override
  AppPalette copyWith({
    LinearGradient? brandGradient,
    LinearGradient? markGradient,
    Color? atmospherePrimary,
    Color? atmosphereSecondary,
    Color? pageBackground,
    Color? surfaceMuted,
    Color? textMuted,
    Color? outlineSoft,
    Color? success,
    Color? warning,
    Color? imageScrim,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return AppPalette(
      brandGradient: brandGradient ?? this.brandGradient,
      markGradient: markGradient ?? this.markGradient,
      atmospherePrimary: atmospherePrimary ?? this.atmospherePrimary,
      atmosphereSecondary: atmosphereSecondary ?? this.atmosphereSecondary,
      pageBackground: pageBackground ?? this.pageBackground,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textMuted: textMuted ?? this.textMuted,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      imageScrim: imageScrim ?? this.imageScrim,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brandGradient:
          LinearGradient.lerp(brandGradient, other.brandGradient, t) ??
          brandGradient,
      markGradient:
          LinearGradient.lerp(markGradient, other.markGradient, t) ??
          markGradient,
      atmospherePrimary: Color.lerp(
        atmospherePrimary,
        other.atmospherePrimary,
        t,
      )!,
      atmosphereSecondary: Color.lerp(
        atmosphereSecondary,
        other.atmosphereSecondary,
        t,
      )!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      imageScrim: Color.lerp(imageScrim, other.imageScrim, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(
        skeletonHighlight,
        other.skeletonHighlight,
        t,
      )!,
    );
  }
}
