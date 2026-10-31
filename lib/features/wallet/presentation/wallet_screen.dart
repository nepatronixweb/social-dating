import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../providers/wallet_providers.dart';
import 'widgets/point_balance_card.dart';
import 'widgets/wallet_activity_tile.dart';

/// Wallet overview: promotional vs earned balances and activity.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);
    final transactions = ref.watch(walletTransactionsProvider);
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Wallet'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'Points',
                subtitle:
                    'Promotional points are not cash and cannot be withdrawn.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: AsyncValueView<WalletSummary>(
                  value: summary,
                  loading: const SizedBox(
                    height: 200,
                    child: AppLoadingIndicator(),
                  ),
                  onRetry: () => ref.invalidate(walletSummaryProvider),
                  data: (s) => _OverviewBalances(summary: s),
                ),
              ),
              AppSpacing.gapLg,
              AppSection(
                title: 'Activity',
                actionLabel: 'See all',
                onAction: () => context.push(AppRoutes.walletActivity),
                child: AsyncValueView<List<WalletTransaction>>(
                  value: transactions,
                  loading: const SizedBox(
                    height: 120,
                    child: AppLoadingIndicator(),
                  ),
                  onRetry: () => ref.invalidate(walletTransactionsProvider),
                  isEmpty: (list) => list.isEmpty,
                  empty: const SizedBox(
                    height: 220,
                    child: EmptyState(
                      icon: AppIcons.wallet,
                      title: 'No activity yet',
                      message:
                          'Welcome bonus, messages and swipes show up here.',
                    ),
                  ),
                  data: (list) => Column(
                    children: [
                      for (final t in list.take(4))
                        WalletActivityTile(
                          transaction: t,
                          now: now,
                          onTap: () =>
                              context.push(AppRoutes.walletTransaction(t.id)),
                        ),
                    ],
                  ),
                ),
              ),
              AppSection(
                title: 'More',
                child: Column(
                  children: [
                    MenuTile(
                      icon: AppIcons.referral,
                      title: 'Welcome bonus',
                      subtitle: '1,000 promotional points, not cash',
                      onTap: () => context.push(AppRoutes.walletWelcome),
                    ),
                    MenuTile(
                      icon: AppIcons.wallet,
                      title: 'Withdrawals',
                      subtitle: 'Eligibility. Nothing is sent to a bank.',
                      onTap: () => context.push(AppRoutes.walletWithdraw),
                    ),
                    MenuTile(
                      icon: AppIcons.help,
                      title: 'Payout help and fees',
                      subtitle: 'Configured minimums only. Nothing is paid.',
                      onTap: () => context.push(AppRoutes.walletHelp),
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

class _OverviewBalances extends StatelessWidget {
  const _OverviewBalances({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final totalEquivalent = formatNpr(
      walletPaisaFromPoints(summary.totalPoints),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PointBalanceCard(
          title: 'Promotional points',
          points: summary.promotionalPoints,
          icon: AppIcons.star,
          footnote:
              'Non-cash and non-withdrawable. Welcome bonus and subscription '
              'rewards live here.',
        ),
        AppSpacing.gapMd,
        PointBalanceCard(
          title: 'Earned points',
          points: summary.availableEarnedPoints,
          icon: AppIcons.bolt,
          heldPoints: summary.pendingWithdrawalPoints,
          footnote:
              'From eligible messaging. Only this balance could count toward '
              'a withdrawal.',
        ),
        AppSpacing.gapLg,
        Text(
          'Stated total equivalent $totalEquivalent',
          style: context.text.titleMedium,
        ),
        AppSpacing.gapSm,
        Text(
          WalletRules.equivalentNotCash,
          style: context.text.bodyMedium?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
        AppSpacing.gapLg,
      ],
    );
  }
}
