import 'package:flutter/widgets.dart';

/// Spacing scale (4pt base grid).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Default horizontal page gutter.
  static const double pageGutter = 24;

  /// Minimum interactive target (Material & iOS HIG both recommend >= 44-48).
  static const double minTouchTarget = 48;

  /// Max content width so layouts stay readable on tablets / landscape.
  static const double maxContentWidth = 520;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: pageGutter,
  );

  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);
}
