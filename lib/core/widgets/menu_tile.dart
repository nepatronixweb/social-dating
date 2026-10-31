import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Settings-style row: tinted icon, title/subtitle and a trailing chevron (or a
/// custom [trailing] such as a Switch). Merges into a single accessible item.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = destructive ? colors.error : colors.primary;
    final titleColor = destructive ? colors.error : colors.onSurface;

    return Semantics(
      button: onTap != null,
      container: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderMd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.menuTileMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: AppSizes.avatarXs + AppSpacing.xs,
                  height: AppSizes.avatarXs + AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: ExcludeSemantics(
                    child: Icon(icon, size: AppSizes.iconMd, color: accent),
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleMedium?.copyWith(
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: context.text.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  ExcludeSemantics(
                    child: Icon(
                      AppIcons.chevronRight,
                      color: context.palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
