import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../data/models/subscription_plan.dart';

/// Amount due, rewards and (when configured) tax/fees. Never invents charges.
class QuoteBreakdown extends StatelessWidget {
  const QuoteBreakdown({super.key, required this.quote});

  final PurchaseQuote quote;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(
      color: context.palette.textMuted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line(
          label: 'Amount due',
          value: formatNpr(quote.amountDuePaisa),
          strong: true,
        ),
        AppSpacing.gapSm,
        _Line(label: 'Plan price', value: formatNpr(quote.pricePaisa)),
        if (quote.hasProviderCharges) ...[
          if (quote.taxPaisa > 0) ...[
            AppSpacing.gapSm,
            _Line(label: 'Tax', value: formatNpr(quote.taxPaisa)),
          ],
          for (final fee in quote.fees) ...[
            AppSpacing.gapSm,
            _Line(label: fee.label, value: formatNpr(fee.paisa)),
          ],
        ] else ...[
          AppSpacing.gapSm,
          Text(
            'No tax or extra fees in this configuration. A verified payment '
            'provider would supply them if they apply.',
            style: muted,
          ),
        ],
        AppSpacing.gapLg,
        _Line(
          label: 'Buyer promotional points',
          value: formatPoints(quote.buyerPoints),
          strong: true,
        ),
        AppSpacing.gapSm,
        Text(
          quote.pointsWithdrawable
              ? 'Product policy currently treats these promotional points as '
                    'withdrawable.'
              : 'These promotional points are not withdrawable and are not '
                    'cash you can take out.',
          style: muted,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? context.text.titleMedium : context.text.bodyMedium;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
