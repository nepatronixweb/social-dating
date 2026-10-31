import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/theme/app_colors.dart';
import 'package:social_dating/core/theme/app_spacing.dart';
import 'package:social_dating/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('AppTheme', () {
    test('light and dark themes use Material 3 and correct brightness', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.dark.useMaterial3, isTrue);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('both themes register the AppPalette extension', () {
      expect(AppTheme.light.extension<AppPalette>(), isNotNull);
      expect(AppTheme.dark.extension<AppPalette>(), isNotNull);
      expect(
        AppTheme.light.extension<AppPalette>()!.pageBackground,
        isNot(AppTheme.dark.extension<AppPalette>()!.pageBackground),
      );
    });

    test('dark theme is consistent with light (same type scale & shapes)', () {
      final l = AppTheme.light.textTheme;
      final d = AppTheme.dark.textTheme;
      for (final pair in [
        (l.displayLarge, d.displayLarge),
        (l.titleMedium, d.titleMedium),
        (l.bodyMedium, d.bodyMedium),
        (l.labelLarge, d.labelLarge),
      ]) {
        expect(pair.$1!.fontSize, pair.$2!.fontSize);
        expect(pair.$1!.fontWeight, pair.$2!.fontWeight);
      }
      final lb =
          AppTheme.light.inputDecorationTheme.border as OutlineInputBorder;
      final db =
          AppTheme.dark.inputDecorationTheme.border as OutlineInputBorder;
      expect(lb.borderRadius, db.borderRadius);
    });

    for (final entry in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      test('${entry.key}: key text/background pairs meet WCAG AA (4.5:1)', () {
        final s = entry.value.colorScheme;
        final p = entry.value.extension<AppPalette>()!;
        expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        expect(_contrast(s.onSurface, s.surface), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(s.onSurface, p.pageBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(p.textMuted, p.pageBackground),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(s.onError, s.error), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(s.primary, p.pageBackground),
          greaterThanOrEqualTo(3.0),
          reason: 'primary used for large text / icons needs 3:1',
        );
      });

      test('${entry.key}: gradient stops keep white/on-primary legible', () {
        final s = entry.value.colorScheme;
        final g = entry.value.extension<AppPalette>()!.brandGradient;
        for (final c in g.colors) {
          expect(_contrast(s.onPrimary, c), greaterThanOrEqualTo(4.5));
        }
      });
    }

    test('minimum touch target token is at least 48dp', () {
      expect(AppSpacing.minTouchTarget, greaterThanOrEqualTo(48));
      expect(
        AppTheme.light.textButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(48),
      );
    });

    test('AppPalette.lerp interpolates and handles foreign extensions', () {
      final mid = AppPalette.light.lerp(AppPalette.dark, 0.5);
      expect(mid.pageBackground, isNot(AppPalette.light.pageBackground));
      expect(AppPalette.light.lerp(null, 0.5), AppPalette.light);
    });
  });
}
