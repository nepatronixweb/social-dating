import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Compact "STEP 1 OF 3" row with connected dots, for the cinematic
/// create-account flow. Separate from [OnboardingProgress], which stays on
/// the five-step post-verify setup and keeps its existing copy.
class AuthStepIndicator extends StatelessWidget {
  const AuthStepIndicator({super.key, required this.step, this.total = 3})
    : assert(step >= 1 && step <= total, 'step must be within 1..total');

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final caption = 'STEP $step OF $total';

    return Semantics(
      container: true,
      label: 'Step $step of $total',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            caption,
            style: context.text.labelSmall?.copyWith(
              color: palette.textMuted,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.gapMd,
          for (var i = 0; i < total; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: SizedBox(
                  width: AppSpacing.lg,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i < step ? colors.primary : palette.outlineSoft,
                      borderRadius: AppRadii.borderPill,
                    ),
                  ),
                ),
              ),
            _Dot(active: i < step),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.primary : context.palette.outlineSoft;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
      child: const SizedBox(width: 8, height: 8),
    );
  }
}
