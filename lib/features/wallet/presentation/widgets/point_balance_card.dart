import 'package:flutter/material.dart';

import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';

/// Accessible promotional or earned balance card.
class PointBalanceCard extends StatelessWidget {
  const PointBalanceCard({
    super.key,
    required this.title,
    required this.points,
    required this.footnote,
    required this.icon,
    this.heldPoints = 0,
  });

  final String title;
  final int points;
  final String footnote;
  final IconData icon;
  final int heldPoints;

  @override
  Widget build(BuildContext context) {
    final held = heldPoints > 0
        ? ', ${formatPoints(heldPoints)} held for a withdrawal request'
        : '';

    return Semantics(
      container: true,
      label: '$title, ${formatPoints(points)}. $footnote$held',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: AppRadii.borderLg,
          boxShadow: AppElevation.low(context.theme.brightness),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: AppSizes.iconMd,
                      color: context.colors.primary,
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(title, style: context.text.labelMedium),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
              ExcludeSemantics(
                child: Text(
                  formatPoints(points),
                  style: context.text.headlineSmall,
                ),
              ),
              if (heldPoints > 0) ...[
                AppSpacing.gapXs,
                ExcludeSemantics(
                  child: Text(
                    '${formatPoints(heldPoints)} held for a withdrawal request',
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
                ),
              ],
              AppSpacing.gapSm,
              ExcludeSemantics(
                child: Text(
                  footnote,
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
