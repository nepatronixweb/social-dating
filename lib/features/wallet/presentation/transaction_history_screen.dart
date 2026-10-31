import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../providers/wallet_providers.dart';
import '../wallet_copy.dart';
import 'widgets/wallet_activity_tile.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  WalletActivityFilter _filter = WalletActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(walletTransactionsProvider);
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Activity'),
      body: AsyncValueView<List<WalletTransaction>>(
        value: transactions,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(walletTransactionsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.history,
          title: 'No activity yet',
          message: 'Points earned and spent on this device will show up here.',
        ),
        data: (list) {
          final filtered = applyWalletFilter(list, _filter);
          return ListView(
            children: [
              const ScreenHeader(
                title: 'Timeline',
                subtitle: 'Points earned and spent. Filters do not change balances.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final filter in WalletActivityFilter.values)
                      InterestChip(
                        label: walletFilterLabel(filter),
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
              AppSpacing.gapMd,
              if (filtered.isEmpty)
                EmptyState(
                  icon: AppIcons.filter,
                  title: 'Nothing in ${walletFilterLabel(_filter)}',
                  message:
                      'Try another filter. Promotional and earned points '
                      'stay in separate buckets.',
                )
              else
                for (final entry in _grouped(filtered, now).entries) ...[
                  Padding(
                    padding: AppSpacing.pagePadding.copyWith(
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      entry.key,
                      style: context.text.labelMedium?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                  ),
                  Padding(
                    padding: AppSpacing.pagePadding,
                    child: Column(
                      children: [
                        for (final tx in entry.value)
                          WalletActivityTile(
                            transaction: tx,
                            now: now,
                            onTap: () => context.push(
                              AppRoutes.walletTransaction(tx.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<WalletTransaction>> _grouped(
    List<WalletTransaction> items,
    DateTime now,
  ) {
    final groups = <String, List<WalletTransaction>>{};
    for (final tx in items) {
      final label = chatDayLabel(tx.occurredAt, now: now);
      groups.putIfAbsent(label, () => []).add(tx);
    }
    return groups;
  }
}
