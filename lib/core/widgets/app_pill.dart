import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

enum AppPillTone { brand, neutral, onImage }

/// Small non-interactive label ("New", "Most popular", "Verified").
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.tone = AppPillTone.brand,
    this.icon,
  });

  final String label;
  final AppPillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      AppPillTone.brand => (colors.primaryContainer, colors.onPrimaryContainer),
      AppPillTone.neutral => (context.palette.surfaceMuted, colors.onSurface),
      AppPillTone.onImage => (colors.surface, colors.onSurface),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.borderPill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconSm, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
