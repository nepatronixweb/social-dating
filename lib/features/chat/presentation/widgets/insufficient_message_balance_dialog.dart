import 'package:flutter/material.dart';

import '../../../../core/constants/message_rules.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inline_message.dart';

/// Shown when the mock wallet cannot cover a paid message. Nothing is deducted
/// and the draft stays in the composer.
Future<bool> showInsufficientMessageBalanceDialog(
  BuildContext context, {
  required MessageQuote quote,
  required int balancePaisa,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => InsufficientMessageBalanceDialog(
      quote: quote,
      balancePaisa: balancePaisa,
    ),
  );
  return result ?? false;
}

class InsufficientMessageBalanceDialog extends StatelessWidget {
  const InsufficientMessageBalanceDialog({
    super.key,
    required this.quote,
    required this.balancePaisa,
  });

  final MessageQuote quote;
  final int balancePaisa;

  @override
  Widget build(BuildContext context) {
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
                  'Not enough balance',
                  style: context.text.headlineSmall,
                ),
              ),
              AppSpacing.gapMd,
              InlineMessage(
                tone: InlineMessageTone.error,
                icon: AppIcons.wallet,
                title: 'Message not sent',
                message:
                    'This draft would cost ${formatNpr(quote.costPaisa)} '
                    '(${formatPoints(quote.costPoints)}). Your wallet '
                    'balance is ${formatNpr(balancePaisa)}.',
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Open wallet',
                icon: AppIcons.wallet,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Not now',
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
