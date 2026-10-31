import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../providers/wallet_providers.dart';
import '../wallet_copy.dart';
import 'widgets/wallet_amount_line.dart';

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(walletTransactionProvider(transactionId));
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Transaction'),
      body: AsyncValueView<WalletTransaction?>(
        value: value,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(walletTransactionProvider(transactionId)),
        isEmpty: (tx) => tx == null,
        empty: const EmptyState(
          icon: AppIcons.receipt,
          title: 'Record not found',
          message: 'That activity is no longer available.',
        ),
        data: (tx) {
          final item = tx!;
          return SingleChildScrollView(
            child: ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: item.title,
                    subtitle:
                        '${pointBucketLabel(item.bucket)} · '
                        '${activityKindLabel(item.kind)}',
                  ),
                  Padding(
                    padding: AppSpacing.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WalletAmountLine(
                          label: 'Points',
                          value: signedPoints(item.credits),
                          strong: true,
                        ),
                        WalletAmountLine(
                          label: 'Stated NPR equivalent',
                          value: formatNpr(
                            walletPaisaFromPoints(item.credits.abs()),
                          ),
                        ),
                        WalletAmountLine(
                          label: 'Bucket',
                          value: pointBucketLabel(item.bucket),
                        ),
                        WalletAmountLine(
                          label: 'When',
                          value: chatDayLabel(item.occurredAt, now: now),
                        ),
                        AppSpacing.gapMd,
                        Text(
                          item.detail,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.palette.textMuted,
                          ),
                        ),
                        AppSpacing.gapLg,
                        const InlineMessage(
                          tone: InlineMessageTone.info,
                          icon: AppIcons.info,
                          title: 'Equivalent is not cash',
                          message: WalletRules.equivalentNotCash,
                        ),
                        AppSpacing.gapXl,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
