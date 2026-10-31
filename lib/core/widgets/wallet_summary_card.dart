import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/number_format.dart';
import '../utils/theme_context.dart';

/// Credits balance card on an inverse (ink) surface, with up to two quick
/// actions. Colours come from the theme's inverse scheme so it adapts to
/// light and dark.
class WalletSummaryCard extends StatelessWidget {
  const WalletSummaryCard({
    super.key,
    required this.credits,
    this.pendingCredits = 0,
    this.onAddCredits,
    this.onViewHistory,
  });

  final int credits;
  final int pendingCredits;
  final VoidCallback? onAddCredits;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onInverse = colors.onInverseSurface;

    return Semantics(
      container: true,
      label:
          '${formatThousands(credits)} credits available'
          '${pendingCredits > 0 ? ', ${formatThousands(pendingCredits)} pending' : ''}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: AppRadii.borderXl,
          boxShadow: AppElevation.medium(context.theme.brightness),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(
                      AppIcons.wallet,
                      size: AppSizes.iconMd,
                      color: onInverse.withValues(alpha: 0.8),
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'Available credits',
                        style: context.text.labelMedium?.copyWith(
                          color: onInverse.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapMd,
              ExcludeSemantics(
                child: Text(
                  formatThousands(credits),
                  style: context.text.displayMedium?.copyWith(color: onInverse),
                ),
              ),
              if (pendingCredits > 0) ...[
                AppSpacing.gapXs,
                ExcludeSemantics(
                  child: Text(
                    '+${formatThousands(pendingCredits)} pending',
                    style: context.text.bodyMedium?.copyWith(
                      color: onInverse.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
              if (onAddCredits != null || onViewHistory != null) ...[
                AppSpacing.gapXl,
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    if (onAddCredits != null)
                      _CardAction(
                        label: 'Add credits',
                        icon: AppIcons.add,
                        filled: true,
                        onTap: onAddCredits!,
                      ),
                    if (onViewHistory != null)
                      _CardAction(label: 'History', onTap: onViewHistory!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = filled ? colors.inverseSurface : colors.onInverseSurface;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: filled ? colors.onInverseSurface : Colors.transparent,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(
                  color: colors.onInverseSurface.withValues(alpha: 0.4),
                ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizes.iconMd, color: foreground),
                    AppSpacing.gapSm,
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: context.text.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
