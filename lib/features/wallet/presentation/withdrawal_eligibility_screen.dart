import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../providers/wallet_providers.dart';
import 'widgets/wallet_amount_line.dart';

class WithdrawalEligibilityScreen extends ConsumerWidget {
  const WithdrawalEligibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(walletEligibilityProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Withdrawals'),
      body: AsyncValueView<WithdrawalEligibility>(
        value: value,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(walletEligibilityProvider),
        data: (eligibility) => _EligibilityBody(eligibility: eligibility),
      ),
    );
  }
}

class _EligibilityBody extends StatelessWidget {
  const _EligibilityBody({required this.eligibility});

  final WithdrawalEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final shortfall = eligibility.minimumPoints - eligibility.earnedAvailable;

    return SingleChildScrollView(
      child: ConstrainedContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(
              title: 'Withdrawal eligibility',
              subtitle:
                  'Female, LGBTQ+ and other accounts, earned points only. '
                  'Nothing is sent to a bank.',
            ),
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WalletAmountLine(
                    label: 'Earned, withdrawable',
                    value: formatPoints(eligibility.earnedAvailable),
                    strong: true,
                  ),
                  WalletAmountLine(
                    label: 'Stated NPR equivalent',
                    value: formatNpr(
                      walletPaisaFromPoints(eligibility.earnedAvailable),
                    ),
                  ),
                  WalletAmountLine(
                    label: 'Configured minimum',
                    value:
                        '${formatPoints(eligibility.minimumPoints)} '
                        '(${formatNpr(walletPaisaFromPoints(eligibility.minimumPoints))} equivalent)',
                  ),
                  AppSpacing.gapMd,
                  InlineMessage(
                    tone: eligibility.canSubmit
                        ? InlineMessageTone.success
                        : InlineMessageTone.info,
                    icon: eligibility.canSubmit
                        ? AppIcons.success
                        : AppIcons.info,
                    title: eligibility.eligibleAccount
                        ? (eligibility.belowMinimum
                              ? 'Insufficient earned points'
                              : 'Earned points only')
                        : 'Request interface unavailable',
                    message: eligibility.explanation,
                  ),
                  if (eligibility.eligibleAccount &&
                      eligibility.belowMinimum) ...[
                    AppSpacing.gapLg,
                    EmptyState(
                      icon: AppIcons.wallet,
                      title: 'Not enough earned points',
                      message:
                          'You need ${formatPoints(shortfall < 0 ? 0 : shortfall)} more earned points '
                          'to reach the ${formatPoints(eligibility.minimumPoints)} '
                          'threshold (${formatNpr(walletPaisaFromPoints(eligibility.minimumPoints))} equivalent). '
                          'Promotional points cannot close this gap.',
                    ),
                  ],
                  if (!eligibility.eligibleAccount) ...[
                    AppSpacing.gapLg,
                    EmptyState(
                      icon: AppIcons.lock,
                      title: 'Withdrawal requests are not shown',
                      message:
                          'Withdrawal requests are available to female, '
                          'LGBTQ+ and other accounts with at least 500 '
                          'earned points. Promotional points never count.',
                    ),
                  ],
                  AppSpacing.gapLg,
                  if (eligibility.canSubmit) ...[
                    AppSpacing.gapXl,
                    AppButton(
                      label: 'Review request',
                      onPressed: () =>
                          context.push(AppRoutes.walletWithdrawRequest),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.gapLg,
            AppSection(
              title: 'History',
              child: Column(
                children: [
                  MenuTile(
                    icon: AppIcons.history,
                    title: 'Withdrawal history',
                    subtitle:
                        'Recorded, cancelled and declined. Never marked paid.',
                    onTap: () => context.push(AppRoutes.walletWithdrawHistory),
                  ),
                  MenuTile(
                    icon: AppIcons.help,
                    title: 'Payout help and fees',
                    onTap: () => context.push(AppRoutes.walletHelp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
