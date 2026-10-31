import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_sizes.dart';
import '../utils/theme_context.dart';

/// Indicator for a verified profile. Announced as "Verified profile".
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = AppSizes.iconMd,
    this.onImage = false,
    this.color,
  });

  final double size;

  /// Use over photos: renders white instead of the brand colour.
  final bool onImage;

  /// Overrides the tint (for example the brand colour over a dark photo).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified profile',
      image: true,
      child: ExcludeSemantics(
        child: Icon(
          AppIcons.verified,
          size: size,
          color: color ?? (onImage ? Colors.white : context.colors.primary),
        ),
      ),
    );
  }
}
