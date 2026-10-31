import 'package:flutter/material.dart';

import '../../../../core/constants/message_rules.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_button.dart';

/// Asks the person to confirm the word fee before sending. Resolves to
/// `true` only after an explicit tap on the pay button. Closing any other way
/// resolves to `false` and nothing is deducted.
Future<bool> showPaidMessageDialog(
  BuildContext context, {
  required MessageQuote quote,
  required int balancePaisa,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        PaidMessageDialog(quote: quote, balancePaisa: balancePaisa),
  );
  return result ?? false;
}

class PaidMessageDialog extends StatelessWidget {
  const PaidMessageDialog({
    super.key,
    required this.quote,
    required this.balancePaisa,
  });

  final MessageQuote quote;
  final int balancePaisa;

  @override
  Widget build(BuildContext context) {
    final cost = formatNpr(quote.costPaisa);
    final points = formatPoints(quote.costPoints);
    final words = quote.eligibleWords;
    final wordLabel = words == 1 ? '1 eligible word' : '$words eligible words';

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Send this paid message?',
                  style: context.text.headlineSmall,
                ),
              ),
              AppSpacing.gapSm,
              Text(
                'NPR 0.10 per eligible word for male accounts.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
              AppSpacing.gapLg,
              _Line(label: 'Eligible words', value: wordLabel),
              AppSpacing.gapSm,
              _Line(
                label: 'Estimated deduction',
                value: '$cost · $points',
                strong: true,
              ),
              AppSpacing.gapSm,
              _Line(
                label: 'Wallet balance',
                value: formatNpr(balancePaisa),
              ),
              AppSpacing.gapSm,
              _Line(
                label: 'Balance after',
                value: formatNpr(balancePaisa - quote.costPaisa),
              ),
              AppSpacing.gapSm,
              _Line(
                label: 'Recipient / platform (80/20)',
                value:
                    '${formatNpr(quote.recipientSharePaisa)} / '
                    '${formatNpr(quote.platformSharePaisa)}',
              ),
              AppSpacing.gapMd,
              Text(
                MessageRules.allocationExplainer,
                style: context.text.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: 'Pay $cost and send',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
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
