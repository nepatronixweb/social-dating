import 'package:flutter/material.dart';

/// Type scale. System fonts are used on purpose: no runtime font downloads
/// (no network at startup) and native feel on both platforms. Swap in a bundled
/// font by setting `fontFamily` here once an asset is licensed and added.
abstract final class AppTypography {
  static TextTheme textTheme({required Color ink, required Color muted}) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double height = 1.35,
      double letterSpacing = 0,
      Color? color,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? ink,
    );

    return TextTheme(
      displayLarge: s(40, FontWeight.w800, height: 1.1, letterSpacing: -1.2),
      displayMedium: s(34, FontWeight.w800, height: 1.12, letterSpacing: -0.9),
      displaySmall: s(28, FontWeight.w700, height: 1.18, letterSpacing: -0.6),
      headlineLarge: s(26, FontWeight.w700, height: 1.2, letterSpacing: -0.5),
      headlineMedium: s(22, FontWeight.w700, height: 1.25, letterSpacing: -0.3),
      headlineSmall: s(20, FontWeight.w700, height: 1.3, letterSpacing: -0.2),
      titleLarge: s(18, FontWeight.w700, letterSpacing: -0.1),
      titleMedium: s(16, FontWeight.w600),
      titleSmall: s(14, FontWeight.w600),
      bodyLarge: s(17, FontWeight.w400, height: 1.5),
      bodyMedium: s(15, FontWeight.w400, height: 1.5),
      bodySmall: s(13, FontWeight.w400, height: 1.45, color: muted),
      labelLarge: s(16, FontWeight.w700, height: 1.2, letterSpacing: 0.1),
      labelMedium: s(13, FontWeight.w600, height: 1.2, letterSpacing: 0.2),
      labelSmall: s(11, FontWeight.w700, height: 1.2, letterSpacing: 0.8),
    );
  }
}
