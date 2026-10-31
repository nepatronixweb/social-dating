import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/referral_info.dart';
import '../providers/referrals_providers.dart';
import '../referral_copy.dart';

class ReferralEarningsScreen extends ConsumerWidget {
  const ReferralEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(referralInfoProvider);
    final commissions = ref.watch(referralCommissionsProvider);
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Commission earnings'),
      body: AsyncValueView<List<ReferralCommission>>(
        value: commissions,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(referralCommissionsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.wallet,
          title: 'No commissions yet',
          message:
              'A commission appears when a friend joins with your code. '
              'It stays pending until a qualifying purchase is confirmed.',
        ),
        data: (list) => ListView(
          children: [
            const ScreenHeader(
              title: 'Commission balances',
              subtitle:
                  'Pending until a qualifying purchase is confirmed. '
                  'Reversed amounts are not earnings.',
            ),
            info.when(
              skipLoadingOnReload: true,
              data: (summary) => Padding(
                padding: AppSpacing.pagePadding,
                child: _BalanceGrid(summary: summary),
              ),
              loading: () =>
                  const SizedBox(height: 120, child: AppLoadingIndicator()),
              error: (error, _) => const SizedBox.shrink(),
            ),
            Padding(
              padding: AppSpacing.pagePadding,
              child: Text('Commission list', style: context.text.titleMedium),
            ),
            for (final item in list)
              ListTile(
                contentPadding: AppSpacing.pagePadding,
                leading: Icon(
                  _icon(item.status),
                  color: context.colors.primary,
                ),
                title: Text(item.personName),
                subtitle: Text(
                  '${formatNpr(item.amountPaisa)} · '
                  '${relativeTime(item.createdAt, now: now)}',
                ),
                trailing: AppPill(
                  label: commissionStatusLabel(item.status),
                  tone: AppPillTone.neutral,
                ),
                onTap: () =>
                    context.push(AppRoutes.referralCommission(item.id)),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(CommissionStatus status) => switch (status) {
    CommissionStatus.pending => AppIcons.info,
    CommissionStatus.approved => AppIcons.check,
    CommissionStatus.reversed => AppIcons.undo,
    CommissionStatus.paid => AppIcons.success,
  };
}

class _BalanceGrid extends StatelessWidget {
  const _BalanceGrid({required this.summary});

  final ReferralInfo summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BalanceCard(
                label: commissionStatusLabel(CommissionStatus.pending),
                value: formatNpr(summary.pendingCommissionPaisa),
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: _BalanceCard(
                label: commissionStatusLabel(CommissionStatus.approved),
                value: formatNpr(summary.approvedCommissionPaisa),
              ),
            ),
          ],
        ),
        AppSpacing.gapMd,
        Row(
          children: [
            Expanded(
              child: _BalanceCard(
                label: commissionStatusLabel(CommissionStatus.paid),
                value: formatNpr(summary.paidCommissionPaisa),
              ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: _BalanceCard(
                label: commissionStatusLabel(CommissionStatus.reversed),
                value: formatNpr(summary.reversedCommissionPaisa),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.surfaceMuted,
          borderRadius: AppRadii.borderMd,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelMedium),
              AppSpacing.gapXs,
              Text(value, style: context.text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
