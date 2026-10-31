import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_sizes.dart';
import '../utils/theme_context.dart';

/// Round icon button for swipe-style actions (pass / like). [emphasized]
/// uses the brand gradient; otherwise a white surface with a soft border.
/// [glass] is a dark translucent style for use over photos; [glow] adds a soft
/// brand-coloured halo; [iconColor] overrides the icon tint.
/// [label] is required: icon-only buttons must have an accessible name.
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.size = 64,
    this.glass = false,
    this.glow = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;
  final double size;
  final bool glass;
  final bool glow;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              if (glow)
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.55),
                  blurRadius: 28,
                  spreadRadius: 1,
                )
              else if (!glass)
                ...AppElevation.medium(context.theme.brightness),
            ],
          ),
          child: Material(
            shape: CircleBorder(
              side: emphasized
                  ? BorderSide.none
                  : BorderSide(
                      color: glass
                          ? Colors.white.withValues(alpha: 0.14)
                          : palette.outlineSoft,
                    ),
            ),
            color: emphasized
                ? null
                : glass
                ? Colors.black.withValues(alpha: 0.5)
                : colors.surface,
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: size,
              height: size,
              decoration: emphasized
                  ? BoxDecoration(gradient: palette.brandGradient)
                  : null,
              child: InkWell(
                onTap: onPressed,
                child: Icon(
                  icon,
                  size: size < 56 ? AppSizes.iconLg : AppSizes.iconXl,
                  color:
                      iconColor ??
                      (emphasized
                          ? colors.onPrimary
                          : glass
                          ? Colors.white
                          : colors.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
