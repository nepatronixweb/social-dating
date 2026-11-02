import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/photo_tokens.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../providers/wallet_providers.dart';

/// Compact spendable points readout for app bars. Opens the wallet on tap.
class PointsBalanceChip extends ConsumerWidget {
  const PointsBalanceChip({super.key, this.onImage = false});

  /// Light-on-dark styling when drawn over a discovery photo.
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);
    final points = summary.asData?.value.totalPoints;
    final label = points == null ? '... pts' : formatPointsDecimal(points);
    final foreground = onImage
        ? PhotoTokens.foreground
        : context.colors.onSurface;
    final border = onImage
        ? PhotoTokens.foreground.withValues(alpha: 0.35)
        : context.palette.outlineSoft;
    final fill = onImage
        ? PhotoTokens.shade.withValues(alpha: 0.45)
        : context.colors.surfaceContainerHighest.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        button: true,
        label: points == null
            ? 'Points balance loading'
            : 'Available points, $label',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(AppRoutes.wallet),
            borderRadius: AppRadii.borderPill,
            child: Ink(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: AppRadii.borderPill,
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.wallet, size: 16, color: foreground),
                      AppSpacing.gapXs,
                      Text(
                        label,
                        style: context.text.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
