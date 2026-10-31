import 'package:flutter/material.dart';

import '../../../../core/constants/swipe_rules.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/models/swipe.dart';

/// "5h 12m" style countdown used for the daily reset.
String formatResetIn(Duration remaining) {
  final minutes = remaining.inMinutes.clamp(0, 24 * 60);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return '${hours}h ${rest}m';
}

/// Explains the swipe rules and the person's current allowance.
Future<void> showSwipeLimitSheet(
  BuildContext context, {
  required SwipeQuota quota,
  required DateTime now,
}) {
  return showAppBottomSheet<void>(
    context,
    title: 'Swipe limits',
    builder: (sheetContext) => SwipeLimitSheet(quota: quota, now: now),
  );
}

class SwipeLimitSheet extends StatelessWidget {
  const SwipeLimitSheet({super.key, required this.quota, required this.now});

  final SwipeQuota quota;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final price = formatNpr(quota.pricePaisa);
    final limit = quota.freeDailyLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!quota.profileComplete) ...[
          _Row(
            label: 'Preview swipes left',
            value: '${quota.previewRemaining} of ${SwipeRules.previewSwipes}',
          ),
          AppSpacing.gapLg,
          Text(
            'You can swipe on ${SwipeRules.previewSwipes} profiles while you '
            'explore. After that, complete your profile to keep going.',
            style: context.text.bodyMedium,
          ),
        ] else if (limit == null) ...[
          Text(
            'There is no daily swipe limit on your account.',
            style: context.text.bodyMedium,
          ),
        ] else ...[
          _Row(
            label: 'Free swipes left today',
            value: '${quota.freeRemaining} of $limit',
          ),
          AppSpacing.gapMd,
          _Row(label: 'Swipes made today', value: '${quota.dailyUsed}'),
          AppSpacing.gapMd,
          _Row(
            label: 'Resets in',
            value: formatResetIn(quota.resetsAt.difference(now)),
          ),
          AppSpacing.gapMd,
          _Row(
            label: 'Wallet balance',
            value: formatNpr(quota.balancePaisa),
          ),
          AppSpacing.gapXl,
          const _Bullet(
            text:
                'Left and right swipes share one count. Passing uses a '
                'swipe just like liking.',
          ),
          _Bullet(text: 'You get $limit free swipes each day.'),
          _Bullet(
            text:
                'The day resets at midnight in ${SwipeRules.quotaTimeZoneLabel}, '
                'wherever you are.',
          ),
          _Bullet(
            text:
                'After that, each extra swipe costs $price. You always see '
                'the cost and confirm before it is charged.',
          ),
        ],
        AppSpacing.gapXl,
        AppButton(
          label: 'Got it',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        children: [
          Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          Text(value, style: context.text.titleSmall),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              AppIcons.check,
              size: AppSizes.iconMd,
              color: context.colors.primary,
            ),
          ),
          AppSpacing.gapMd,
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
