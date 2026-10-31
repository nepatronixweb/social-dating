import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../providers/subscription_providers.dart';

class PurchaseHistoryScreen extends ConsumerWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(purchaseHistoryProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Purchase history'),
      body: AsyncValueView<List<PurchaseRecord>>(
        value: history,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(purchaseHistoryProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.receipt,
          title: 'No purchases yet',
          message: 'Completed checkouts will show up here.',
        ),
        data: (list) => ListView(
          children: [
            const ScreenHeader(
              title: 'Purchase history',
              subtitle: 'Amount, status and when each checkout was recorded.',
            ),
            for (final item in list)
              ListTile(
                contentPadding: AppSpacing.pagePadding,
                leading: Icon(
                  _icon(item.outcome),
                  color: context.colors.primary,
                ),
                title: Text(item.plan.name),
                subtitle: Text(
                  '${formatNpr(item.amountPaisa)} · ${_label(item.outcome)} · '
                  '${relativeTime(item.createdAt)}'
                  '${item.referralLinked ? ' · referral-linked' : ''}',
                ),
                onTap: () =>
                    context.push(AppRoutes.subscriptionStatus(item.id)),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(PaymentOutcome outcome) => switch (outcome) {
    PaymentOutcome.pending => AppIcons.info,
    PaymentOutcome.succeeded => AppIcons.success,
    PaymentOutcome.failed => AppIcons.error,
    PaymentOutcome.cancelled => AppIcons.close,
  };

  static String _label(PaymentOutcome outcome) => switch (outcome) {
    PaymentOutcome.pending => 'Pending',
    PaymentOutcome.succeeded => 'Succeeded',
    PaymentOutcome.failed => 'Failed',
    PaymentOutcome.cancelled => 'Cancelled',
  };
}
