import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Interest tag. Static when [onTap] is null; otherwise a toggle that exposes
/// its selected state to assistive technology and has a 44dp tap target.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onImage = false,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Translucent style for use over photos.
  final bool onImage;

  /// Optional leading icon (tinted [iconColor], else the label colour).
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    final Color background;
    final Color foreground;
    final Color border;
    if (onImage) {
      background = Colors.black.withValues(alpha: 0.42);
      foreground = Colors.white;
      border = Colors.white.withValues(alpha: 0.16);
    } else if (selected) {
      background = colors.primaryContainer;
      foreground = colors.onPrimaryContainer;
      border = colors.primary;
    } else {
      background = colors.surface;
      foreground = colors.onSurface;
      border = palette.outlineSoft;
    }

    final chip = AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      constraints: BoxConstraints(
        minHeight: onImage ? 32 : AppSizes.chipHeight,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: onImage ? AppSpacing.md : AppSpacing.lg,
        vertical: onImage ? AppSpacing.xs : 0,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.borderPill,
        border: Border.all(color: border, width: selected ? 1.5 : 1),
      ),
      // Shrink-wrap: a Wrap offers the full row width, and both Flexible
      // text and a stretching container would make every chip full width.
      child: Center(
        widthFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && !onImage) ...[
              Icon(AppIcons.check, size: AppSizes.iconSm, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (icon != null) ...[
              Icon(
                icon,
                size: onImage ? AppSizes.iconSm : AppSizes.iconMd,
                color: iconColor ?? foreground,
              ),
              SizedBox(width: onImage ? AppSpacing.xs : AppSpacing.sm),
            ],
            Text(
              label,
              maxLines: 1,
              style: context.text.labelMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(child: chip),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderPill,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.chipTapHeight),
          child: Center(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}
