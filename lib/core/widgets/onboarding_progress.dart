import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// "Step 3 of 5" with a segmented progress bar, for the first-time setup
/// flow. [step] is 1-based; when [complete] every segment is filled.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.step,
    this.total = AppConstants.onboardingSteps,
    this.complete = false,
    this.label,
  }) : assert(step >= 1 && step <= total, 'step must be within 1..total');

  final int step;
  final int total;
  final bool complete;

  /// Name of the current step, shown after the counter ("Step 3 of 5 · Terms").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final filled = complete ? total : step;
    final summary = complete
        ? 'Setup complete'
        : 'Step $step of $total${label == null ? '' : ' · $label'}';

    return Semantics(
      container: true,
      label: summary,
      value: '${(filled / total * 100).round()} percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) AppSpacing.gapXs,
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.resolve(context, AppMotion.normal),
                    curve: AppMotion.standard,
                    height: AppSizes.indicatorHeight + 3,
                    decoration: BoxDecoration(
                      color: i < filled
                          ? context.colors.primary
                          : context.palette.outlineSoft,
                      borderRadius: AppRadii.borderPill,
                      boxShadow: i < filled
                          ? [
                              BoxShadow(
                                color: context.colors.primary.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.gapSm,
          Text(
            summary,
            style: context.text.labelMedium?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
