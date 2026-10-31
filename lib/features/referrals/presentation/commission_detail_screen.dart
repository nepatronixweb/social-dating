import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/referral_rules.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/referral_info.dart';
import '../providers/referrals_providers.dart';
import '../referral_copy.dart';

class CommissionDetailScreen extends ConsumerWidget {
  const CommissionDetailScreen({super.key, required this.commissionId});

  final String commissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(referralCommissionProvider(commissionId));
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Commission'),
      body: AsyncValueView<ReferralCommission?>(
        value: value,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(referralCommissionProvider(commissionId)),
        isEmpty: (item) => item == null,
        empty: const EmptyState(
          icon: AppIcons.wallet,
          title: 'Commission not found',
          message: 'That record is no longer available.',
        ),
        data: (item) {
          final commission = item!;
          return SingleChildScrollView(
            child: ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: commission.personName,
                    subtitle: formatNpr(commission.amountPaisa),
                  ),
                  Padding(
                    padding: AppSpacing.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppPill(
                          label: commissionStatusLabel(commission.status),
                          tone: AppPillTone.neutral,
                        ),
                        AppSpacing.gapLg,
                        Text(
                          'Recorded ${chatDayLabel(commission.createdAt, now: now)}',
                          style: context.text.bodyMedium,
                        ),
                        if (commission.resolvedAt != null) ...[
                          AppSpacing.gapXs,
                          Text(
                            'Updated ${chatDayLabel(commission.resolvedAt!, now: now)}',
                            style: context.text.bodyMedium,
                          ),
                        ],
                        AppSpacing.gapLg,
                        Text(
                          commission.detail,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.palette.textMuted,
                          ),
                        ),
                        if (commission.status == CommissionStatus.pending) ...[
                          AppSpacing.gapLg,
                          const InlineMessage(
                            tone: InlineMessageTone.info,
                            icon: AppIcons.info,
                            title: 'Waiting on a qualifying purchase',
                            message: ReferralRules.pendingUntilConfirmed,
                          ),
                        ],
                        if (commission.status == CommissionStatus.reversed) ...[
                          AppSpacing.gapLg,
                          const InlineMessage(
                            tone: InlineMessageTone.warning,
                            icon: AppIcons.undo,
                            title: 'Reversed after a refund',
                            message: ReferralRules.reversalNote,
                          ),
                        ],
                        if (commission.status == CommissionStatus.paid) ...[
                          AppSpacing.gapLg,
                          const InlineMessage(
                            tone: InlineMessageTone.info,
                            icon: AppIcons.info,
                            title: 'Paid is not a bank transfer',
                            message:
                                'Nothing was sent to a bank or payout provider.',
                          ),
                        ],
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
