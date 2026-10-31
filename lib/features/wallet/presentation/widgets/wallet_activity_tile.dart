import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../data/models/wallet.dart';
import '../../wallet_copy.dart';

class WalletActivityTile extends StatelessWidget {
  const WalletActivityTile({
    super.key,
    required this.transaction,
    this.now,
    this.onTap,
  });

  final WalletTransaction transaction;
  final DateTime? now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final credit = transaction.isCredit;
    final amount = signedPoints(transaction.credits);
    final when = relativeTime(transaction.occurredAt, now: now);
    final bucket = pointBucketLabel(transaction.bucket);

    return Semantics(
      button: onTap != null,
      container: true,
      label:
          '${transaction.title}, $bucket, ${credit ? 'added' : 'spent'} '
          '$amount, $when ago',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderMd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.menuTileMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: AppSizes.avatarXs + AppSpacing.xs,
                  height: AppSizes.avatarXs + AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: Icon(
                    credit ? AppIcons.add : AppIcons.arrowDown,
                    size: AppSizes.iconMd,
                    color: context.colors.primary,
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.title, style: context.text.titleMedium),
                      Text(
                        '$bucket · $when',
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: context.text.titleMedium?.copyWith(
                    color: credit
                        ? context.palette.success
                        : context.colors.onSurface,
                  ),
                ),
                if (onTap != null)
                  Icon(
                    AppIcons.chevronRight,
                    size: AppSizes.iconMd,
                    color: context.palette.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
