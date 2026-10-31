import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/repository_providers.dart';
import '../providers/wallet_providers.dart';
import '../wallet_copy.dart';
import 'widgets/wallet_amount_line.dart';

class WithdrawalDetailScreen extends ConsumerStatefulWidget {
  const WithdrawalDetailScreen({super.key, required this.withdrawalId});

  final String withdrawalId;

  @override
  ConsumerState<WithdrawalDetailScreen> createState() =>
      _WithdrawalDetailScreenState();
}

class _WithdrawalDetailScreenState
    extends ConsumerState<WithdrawalDetailScreen> {
  bool _busy = false;

  Future<void> _cancel(bool isLive) async {
    if (_busy) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Release this hold?',
      message:
          'The earned points return to the account ledger. Nothing was '
          'sent to a bank, so nothing will be reversed at a provider.',
      confirmLabel: 'Release hold',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(walletRepositoryProvider)
          .cancelWithdrawal(widget.withdrawalId);
      ref.read(walletRevisionProvider.notifier).bump();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(walletWithdrawalProvider(widget.withdrawalId));
    final now = ref.watch(clockProvider)();
    final live =
        value.asData?.value?.isLive ??
        ref.watch(walletEligibilityProvider).asData?.value?.isLive ??
        false;

    return AppPage(
      appBar: const AppTopBar(title: 'Withdrawal'),
      body: AsyncValueView<WithdrawalRequest?>(
        value: value,
        loading: const AppLoadingIndicator(),
        onRetry: () =>
            ref.invalidate(walletWithdrawalProvider(widget.withdrawalId)),
        isEmpty: (item) => item == null,
        empty: const EmptyState(
          icon: AppIcons.wallet,
          title: 'Request not found',
          message:
              'That withdrawal record is no longer on the account ledger.',
        ),
        data: (item) {
          final request = item!;
          final isLive = request.isLive || live;
          return SingleChildScrollView(
            child: ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: withdrawalStatusLabel(
                      request.status,
                      isLive: isLive,
                    ),
                    subtitle: withdrawalStatusDetail(
                      request.status,
                      isLive: isLive,
                    ),
                  ),
                  Padding(
                    padding: AppSpacing.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WalletAmountLine(
                          label: 'Points',
                          value: formatPoints(request.points),
                          strong: true,
                        ),
                        WalletAmountLine(
                          label: 'Configured fee',
                          value: formatPoints(request.feePoints),
                        ),
                        WalletAmountLine(
                          label: 'Net points',
                          value: formatPoints(request.netPoints),
                          strong: true,
                        ),
                        WalletAmountLine(
                          label: 'Stated NPR equivalent',
                          value: formatNpr(
                            walletPaisaFromPoints(request.netPoints),
                          ),
                        ),
                        WalletAmountLine(
                          label: 'Recorded',
                          value: chatDayLabel(request.createdAt, now: now),
                        ),
                        if (request.resolvedAt != null)
                          WalletAmountLine(
                            label: 'Updated',
                            value: chatDayLabel(request.resolvedAt!, now: now),
                          ),
                        AppSpacing.gapMd,
                        Text(withdrawalProcessingNote(isLive: isLive)),
                        AppSpacing.gapLg,
                        InlineMessage(
                          tone: InlineMessageTone.warning,
                          icon: AppIcons.warning,
                          title: withdrawalDisclosureTitle(isLive: isLive),
                          message: withdrawalRequestNote(isLive: isLive),
                        ),
                        if (request.isOpen) ...[
                          AppSpacing.gapXl,
                          AppButton(
                            label: 'Release hold',
                            variant: AppButtonVariant.secondary,
                            isLoading: _busy,
                            onPressed: _busy ? null : () => _cancel(isLive),
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
