import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_button.dart';

/// Asks the person to confirm the price of a swipe beyond the free limit.
/// Resolves to `true` only after an explicit tap on the pay button; closing
/// the dialog any other way resolves to `false` and nothing is charged.
Future<bool> showPaidSwipeDialog(
  BuildContext context, {
  required int costPaisa,
  required int balancePaisa,
  required int freeLimit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => PaidSwipeDialog(
      costPaisa: costPaisa,
      balancePaisa: balancePaisa,
      freeLimit: freeLimit,
    ),
  );
  return result ?? false;
}

class PaidSwipeDialog extends StatelessWidget {
  const PaidSwipeDialog({
    super.key,
    required this.costPaisa,
    required this.balancePaisa,
    required this.freeLimit,
  });

  final int costPaisa;
  final int balancePaisa;
  final int freeLimit;

  @override
  Widget build(BuildContext context) {
    final cost = formatNpr(costPaisa);

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
                  'Pay for this swipe?',
                  style: context.text.headlineSmall,
                ),
              ),
              AppSpacing.gapMd,
              Text(
                'You have used all $freeLimit free swipes for today. Left and '
                'right swipes both count.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
              AppSpacing.gapLg,
              _Line(label: 'Cost of this swipe', value: cost, strong: true),
              AppSpacing.gapSm,
              _Line(
                label: 'Wallet balance',
                value: formatNpr(balancePaisa),
              ),
              AppSpacing.gapSm,
              _Line(
                label: 'Balance after',
                value: formatNpr(balancePaisa - costPaisa),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Pay $cost and swipe',
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
      // A Wrap, so at large text the value drops under its label instead of
      // squeezing it.
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
