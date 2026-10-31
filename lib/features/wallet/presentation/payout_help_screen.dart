import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import '../wallet_copy.dart';
import 'widgets/wallet_amount_line.dart';

class PayoutHelpScreen extends StatelessWidget {
  const PayoutHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faq = [
      (
        'Is this a real withdrawal?',
        'Recording a request saves it on the account ledger. Nothing is '
            'submitted to a bank or payout provider, and nothing is paid.',
      ),
      (
        'What is the conversion rate?',
        '100 points = NPR 1. A displayed equivalent is not necessarily '
            'withdrawable cash.',
      ),
      (
        'What is the welcome bonus?',
        '1,000 promotional points. They are not cash and cannot be withdrawn.',
      ),
      (
        'What is the subscription reward?',
        '3,000 promotional points with a stated NPR 30 equivalent, subject to '
            'the configured redemption policy. They are not withdrawable.',
      ),
      (
        'What does a paid swipe cost?',
        'NPR 0.10, which is 10 points if it is charged to the point wallet.',
      ),
      (
        'Who can record a withdrawal?',
        'Female, LGBTQ+ and other accounts with at least 500 earned, '
            'withdrawable points (NPR 5 equivalent). Promotional points never '
            'count.',
      ),
    ];

    return AppPage(
      appBar: const AppTopBar(title: 'Payout help'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'Fees and rules',
                subtitle: 'Only configured values. No provider quotes.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSpacing.gapLg,
                    WalletAmountLine(
                      label: 'Conversion',
                      value: '${WalletRules.pointsPerNpr} points = NPR 1',
                      strong: true,
                    ),
                    WalletAmountLine(
                      label: 'Minimum earned points',
                      value:
                          '${formatPoints(WalletRules.minWithdrawalPoints)} '
                          '(${formatNpr(walletPaisaFromPoints(WalletRules.minWithdrawalPoints))} equivalent)',
                    ),
                    WalletAmountLine(
                      label: 'Configured fee',
                      value: formatPoints(WalletRules.withdrawalFeePoints),
                    ),
                    WalletAmountLine(
                      label: 'Configured tax',
                      value: formatPoints(WalletRules.taxPoints),
                    ),
                    if (WalletRules.extraFees.isEmpty)
                      Text(
                        'No extra payout fees in this configuration. A '
                        'verified provider would supply them if they apply.',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      )
                    else
                      for (final fee in WalletRules.extraFees)
                        WalletAmountLine(
                          label: fee.label,
                          value: formatPoints(fee.points),
                        ),
                    AppSpacing.gapMd,
                    Text(withdrawalProcessingNote(isLive: true)),
                    AppSpacing.gapLg,
                    const InlineMessage(
                      tone: InlineMessageTone.info,
                      icon: AppIcons.info,
                      title: 'Equivalent is not cash',
                      message: WalletRules.equivalentNotCash,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapLg,
              AppSection(
                title: 'Questions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (question, answer) in faq) ...[
                      Text(question, style: context.text.titleMedium),
                      AppSpacing.gapXs,
                      Text(
                        answer,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                      AppSpacing.gapLg,
                    ],
                  ],
                ),
              ),
              AppSection(
                title: 'Also',
                child: Column(
                  children: [
                    MenuTile(
                      icon: AppIcons.document,
                      title: 'Terms of Service',
                      onTap: () => context.push(AppRoutes.legalTerms),
                    ),
                    MenuTile(
                      icon: AppIcons.history,
                      title: 'Withdrawal history',
                      onTap: () =>
                          context.push(AppRoutes.walletWithdrawHistory),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
