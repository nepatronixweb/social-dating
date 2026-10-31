import 'package:flutter/material.dart';

import '../../data/models/subscription_plan.dart';
import '../theme/app_elevation.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'app_pill.dart';

/// Selectable subscription plan: name, price, perks, and "Most popular".
/// Selection is shown by border, check indicator and semantics (not colour
/// alone).
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      label:
          '${plan.name} plan, ${plan.priceLabel} ${plan.periodLabel}'
          '${plan.isPopular ? ', most popular' : ''}'
          '. Includes ${plan.features.join(', ')}',
      child: AnimatedContainer(
        duration: AppMotion.resolve(context, AppMotion.fast),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.borderLg,
          border: Border.all(
            color: selected ? colors.primary : palette.outlineSoft,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? AppElevation.medium(context.theme.brightness)
              : AppElevation.low(context.theme.brightness),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadii.borderLg,
          child: InkWell(
            borderRadius: AppRadii.borderLg,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Wrap so the badge drops below the name instead of
                      // overflowing on narrow screens or at large text sizes.
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(plan.name, style: context.text.headlineSmall),
                            if (plan.isPopular)
                              const AppPill(label: 'Most popular'),
                          ],
                        ),
                      ),
                      AppSpacing.gapMd,
                      _SelectionIndicator(selected: selected),
                    ],
                  ),
                  AppSpacing.gapMd,
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(plan.priceLabel, style: context.text.displaySmall),
                      Text(plan.periodLabel, style: context.text.bodySmall),
                    ],
                  ),
                  if (plan.savingsLabel != null) ...[
                    AppSpacing.gapSm,
                    AppPill(
                      label: plan.savingsLabel!,
                      tone: AppPillTone.neutral,
                    ),
                  ],
                  AppSpacing.gapLg,
                  for (final feature in plan.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            AppIcons.check,
                            size: AppSizes.iconMd,
                            color: colors.primary,
                          ),
                          AppSpacing.gapSm,
                          Expanded(
                            child: Text(
                              feature,
                              style: context.text.bodyMedium,
                            ),
                          ),
                        ],
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

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      width: AppSizes.iconLg,
      height: AppSizes.iconLg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? colors.primary : context.palette.textMuted,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(AppIcons.check, size: AppSizes.iconSm, color: colors.onPrimary)
          : null,
    );
  }
}
