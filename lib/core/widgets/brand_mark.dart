import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_icons.dart';
import '../utils/theme_context.dart';

/// Official Social Dating mark: two figures forming a heart.
///
/// Rendered from the brand asset so the lockup matches the supplied logo
/// exactly at every size (splash, welcome, and toolbars).
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 72,
    this.onGradient = false,
    this.glow,
  });

  static const String assetPath = 'assets/brand/logo.png';

  final double size;

  /// Tint the mark to [ColorScheme.onPrimary] when it sits on a brand wash.
  final bool onGradient;

  /// Soft halo behind the mark. Off by default so the logo stays crisp.
  final bool? glow;

  @override
  Widget build(BuildContext context) {
    final showGlow = glow ?? false;
    Widget mark = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: Icon(
          AppIcons.heart,
          size: size * 0.72,
          color: context.colors.primary,
        ),
      ),
    );

    if (onGradient) {
      mark = ColorFiltered(
        colorFilter: ColorFilter.mode(
          context.colors.onPrimary,
          BlendMode.srcATop,
        ),
        child: mark,
      );
    }

    if (showGlow) {
      mark = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.28),
              blurRadius: size * 0.22,
              spreadRadius: size * 0.02,
            ),
          ],
        ),
        child: mark,
      );
    }

    return Semantics(
      label: 'Social Dating logo',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(width: size, height: size, child: mark),
      ),
    );
  }
}

/// Wordmark with the product name accented on "Dating".
/// [find.text] still resolves to [AppConstants.appName].
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
  });

  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? context.text.headlineMedium)?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Social '),
          TextSpan(
            text: 'Dating',
            style: TextStyle(color: context.colors.primary),
          ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
