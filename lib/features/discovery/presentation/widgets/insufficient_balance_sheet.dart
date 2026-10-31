import 'package:flutter/material.dart';

import '../../../../core/constants/swipe_rules.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_message.dart';
import '../../../../data/models/swipe.dart';
import 'swipe_limit_sheet.dart';

/// What the person chose in the insufficient-balance sheet.
enum InsufficientBalanceAction { openWallet, dismiss }

/// Shown instead of the price confirmation when the mock balance cannot cover
/// the next swipe. Nothing is charged and the card stays where it is.
Future<InsufficientBalanceAction> showInsufficientBalanceSheet(
  BuildContext context, {
  required SwipeQuota quota,
  required DateTime now,
}) async {
  final result = await showAppBottomSheet<InsufficientBalanceAction>(
    context,
    title: 'Not enough balance',
    builder: (sheetContext) => InsufficientBalanceSheet(quota: quota, now: now),
  );
  return result ?? InsufficientBalanceAction.dismiss;
}

class InsufficientBalanceSheet extends StatelessWidget {
  const InsufficientBalanceSheet({
    super.key,
    required this.quota,
    required this.now,
  });

  final SwipeQuota quota;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cost = formatNpr(quota.pricePaisa);
    final balance = formatNpr(quota.balancePaisa);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineMessage(
          tone: InlineMessageTone.error,
          icon: AppIcons.wallet,
          title: 'Swipe not sent',
          message:
              'Your free swipes for today are used. The next swipe costs '
              '$cost and your wallet balance is $balance.',
        ),
        AppSpacing.gapLg,
        Text(
          'Your free swipes come back in '
          '${formatResetIn(quota.resetsAt.difference(now))} '
          '(midnight, ${SwipeRules.quotaTimeZoneLabel}).',
          style: context.text.bodyMedium?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
        AppSpacing.gapXl,
        AppButton(
          label: 'Open wallet',
          icon: AppIcons.wallet,
          onPressed: () =>
              Navigator.of(context).pop(InsufficientBalanceAction.openWallet),
        ),
        AppSpacing.gapSm,
        AppButton(
          label: 'Not now',
          variant: AppButtonVariant.text,
          onPressed: () =>
              Navigator.of(context).pop(InsufficientBalanceAction.dismiss),
        ),
      ],
    );
  }
}
