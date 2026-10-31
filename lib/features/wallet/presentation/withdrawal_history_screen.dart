import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../providers/wallet_providers.dart';
import '../wallet_copy.dart';

class WithdrawalHistoryScreen extends ConsumerWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(walletWithdrawalsProvider);
    final eligibility = ref.watch(walletEligibilityProvider).asData?.value;
    final live = eligibility?.isLive ?? false;
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Withdrawal history'),
      body: AsyncValueView<List<WithdrawalRequest>>(
        value: history,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(walletWithdrawalsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.history,
          title: 'No withdrawals yet',
          message:
              'Recorded, cancelled and declined requests show up here.',
        ),
        data: (list) => ListView(
          children: [
            const ScreenHeader(
              title: 'Your requests',
              subtitle:
                  'Statuses from the account ledger. A recorded request is '
                  'not a payout.',
            ),
            for (final item in list)
              ListTile(
                contentPadding: AppSpacing.pagePadding,
                leading: Icon(
                  _icon(item.status),
                  color: context.colors.primary,
                ),
                title: Text(formatPoints(item.points)),
                subtitle: Text(
                  '${withdrawalStatusLabel(item.status, isLive: item.isLive || live)} · '
                  '${relativeTime(item.createdAt, now: now)}',
                ),
                onTap: () => context.push(AppRoutes.walletWithdrawal(item.id)),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(WithdrawalStatus status) => switch (status) {
    WithdrawalStatus.recorded => AppIcons.info,
    WithdrawalStatus.cancelled => AppIcons.close,
    WithdrawalStatus.declined => AppIcons.error,
  };
}
