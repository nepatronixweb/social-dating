import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/theme_context.dart';

enum BrandAtmosphereStyle {
  /// Soft corner orbs (welcome).
  orbs,

  /// Flowing corner waves (splash).
  waves,
}

/// Decorative branded backdrop. Not interactive. Colours come from
/// [AppPalette] / [ColorScheme] so light and dark both work.
class BrandAtmosphere extends StatelessWidget {
  const BrandAtmosphere({super.key, this.style = BrandAtmosphereStyle.orbs});

  final BrandAtmosphereStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDark;
    return IgnorePointer(
      child: CustomPaint(
        painter: style == BrandAtmosphereStyle.waves
            ? _WavePainter(
                canvasColor: isDark
                    ? palette.pageBackground
                    : AppColors.blush50,
                top: isDark ? AppColors.rose400 : AppColors.rose300,
                bottomStart: isDark ? AppColors.rose400 : AppColors.rose400,
                bottomEnd: isDark
                    ? palette.atmosphereSecondary
                    : AppColors.violet800,
              )
            : _AtmospherePainter(
                primary: palette.atmospherePrimary,
                secondary: palette.atmosphereSecondary,
                page: palette.pageBackground,
              ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter({
    required this.primary,
    required this.secondary,
    required this.page,
  });

  final Color primary;
  final Color secondary;
  final Color page;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = page);

    void orb({
      required Offset center,
      required double radius,
      required Color color,
    }) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.72), color.withValues(alpha: 0.0)],
        ).createShader(rect);
      canvas.drawRect(rect.inflate(4), paint);
    }

    orb(
      center: Offset(size.width * -0.05, size.height * -0.02),
      radius: size.width * 0.72,
      color: primary,
    );
    orb(
      center: Offset(size.width * 1.05, size.height * 0.08),
      radius: size.width * 0.62,
      color: secondary,
    );
    orb(
      center: Offset(size.width * 0.12, size.height * 1.05),
      radius: size.width * 0.78,
      color: primary,
    );
    orb(
      center: Offset(size.width * 1.02, size.height * 0.92),
      radius: size.width * 0.70,
      color: secondary,
    );
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.primary != primary || old.secondary != secondary || old.page != page;
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.canvasColor,
    required this.top,
    required this.bottomStart,
    required this.bottomEnd,
  });

  final Color canvasColor;
  final Color top;
  final Color bottomStart;
  final Color bottomEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = canvasColor);

    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.62, 0)
      ..cubicTo(w * 0.48, h * 0.04, w * 0.40, h * 0.10, w * 0.22, h * 0.14)
      ..cubicTo(w * 0.08, h * 0.17, 0, h * 0.12, 0, h * 0.06)
      ..close();
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, top.withValues(alpha: 0.35)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.22)),
    );

    final mid = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.86)
      ..cubicTo(w * 0.22, h * 0.78, w * 0.48, h * 0.92, w * 0.78, h * 0.84)
      ..cubicTo(w * 0.94, h * 0.80, w, h * 0.74, w, h * 0.68)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      mid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bottomStart.withValues(alpha: 0.45),
            bottomEnd.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.38)),
    );

    final bottom = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.90)
      ..cubicTo(w * 0.28, h * 0.82, w * 0.52, h * 0.96, w * 0.82, h * 0.88)
      ..cubicTo(w * 0.96, h * 0.84, w, h * 0.78, w, h * 0.72)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      bottom,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.bottomRight,
          colors: [bottomStart, bottomEnd],
        ).createShader(Rect.fromLTWH(0, h * 0.70, w, h * 0.30)),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.canvasColor != canvasColor ||
      old.top != top ||
      old.bottomStart != bottomStart ||
      old.bottomEnd != bottomEnd;
}
