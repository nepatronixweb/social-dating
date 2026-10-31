import 'package:flutter/material.dart';

import '../utils/theme_context.dart';

/// Tasteful stand-in for a profile photo: a soft two-tone wash with an
/// abstract head-and-shoulders silhouette. Deterministic per [seed], needs no
/// asset or network, and is purely decorative (hidden from screen readers).
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key, this.seed = 0});

  final int seed;

  static const List<double> _hues = [350, 12, 28, 330, 8, 305];

  @override
  Widget build(BuildContext context) {
    final hue = _hues[seed.abs() % _hues.length];
    final dark = context.isDark;

    Color tone(double hueShift, double s, double l) =>
        HSLColor.fromAHSL(1, (hue + hueShift) % 360, s, l).toColor();

    return ExcludeSemantics(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _PlaceholderPainter(
            top: tone(0, dark ? 0.26 : 0.58, dark ? 0.26 : 0.9),
            bottom: tone(14, dark ? 0.3 : 0.5, dark ? 0.17 : 0.78),
            figure: tone(-6, dark ? 0.3 : 0.4, dark ? 0.36 : 0.68),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter({
    required this.top,
    required this.bottom,
    required this.figure,
  });

  final Color top;
  final Color bottom;
  final Color figure;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    final w = size.width;
    final h = size.height;
    // Soft vignette instead of a cartoon silhouette, so missing photos still
    // read as a photograph rather than a blob.
    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.15),
        radius: 0.9,
        colors: [
          figure.withValues(alpha: 0.28),
          figure.withValues(alpha: 0.04),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, wash);

    final paint = Paint()..color = figure.withValues(alpha: 0.22);
    canvas.drawCircle(Offset(w / 2, h * 0.36), w * 0.16, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.9),
        width: w * 0.72,
        height: h * 0.42,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PlaceholderPainter old) =>
      old.top != top || old.bottom != bottom || old.figure != figure;
}
