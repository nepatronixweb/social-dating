import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/errors/app_failure.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/repositories/repository_providers.dart';
import '../providers/subscription_providers.dart';

class PaymentStatusScreen extends ConsumerStatefulWidget {
  const PaymentStatusScreen({super.key, required this.purchaseId});

  final String purchaseId;

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  bool _busy = false;

  Future<void> _resolve(PaymentOutcome outcome) async {
    if (_busy) return;
    _busy = true;
    setState(() {});
    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .resolvePurchase(widget.purchaseId, outcome);
      if (!mounted) return;
      ref.read(subscriptionRevisionProvider.notifier).bump();
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
    final purchase = ref.watch(purchaseProvider(widget.purchaseId));

    return AppPage(
      appBar: const AppTopBar(title: 'Payment'),
      body: AsyncValueView<PurchaseRecord?>(
        value: purchase,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(purchaseProvider(widget.purchaseId)),
        data: (record) {
          if (record == null) {
            return const EmptyState(
              icon: AppIcons.wallet,
              title: 'Purchase not found',
              message: 'That checkout is no longer available.',
            );
          }
          return SingleChildScrollView(
            child: ConstrainedContent(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: switch (record.outcome) {
                  PaymentOutcome.pending => _Pending(
                    record: record,
                    busy: _busy,
                    onSuccess: () => _resolve(PaymentOutcome.succeeded),
                    onFailure: () => _resolve(PaymentOutcome.failed),
                    onCancel: () => _resolve(PaymentOutcome.cancelled),
                  ),
                  PaymentOutcome.succeeded => _Done(
                    record: record,
                    icon: AppIcons.success,
                    tone: InlineMessageTone.success,
                    title: 'Purchase succeeded',
                    message:
                        'Your membership is active. Promotional points are '
                        'credited according to product policy.',
                    actionLabel: 'View membership',
                    onAction: () => context.go(AppRoutes.subscription),
                  ),
                  PaymentOutcome.failed => _Done(
                    record: record,
                    icon: AppIcons.error,
                    tone: InlineMessageTone.error,
                    title: 'Purchase failed',
                    message:
                        'Nothing was charged. You can review the plan again.',
                    actionLabel: 'Back to plans',
                    onAction: () => context.go(AppRoutes.subscription),
                  ),
                  PaymentOutcome.cancelled => _Done(
                    record: record,
                    icon: AppIcons.close,
                    tone: InlineMessageTone.warning,
                    title: 'Purchase cancelled',
                    message:
                        'You stopped checkout. Nothing was charged.',
                    actionLabel: 'Back to plans',
                    onAction: () => context.go(AppRoutes.subscription),
                  ),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending({
    required this.record,
    required this.busy,
    required this.onSuccess,
    required this.onFailure,
    required this.onCancel,
  });

  final PurchaseRecord record;
  final bool busy;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Waiting on payment',
          subtitle:
              'Complete or cancel this checkout when you are ready.',
        ),
        Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InlineMessage(
                tone: InlineMessageTone.info,
                icon: AppIcons.info,
                title: 'Amount due ${formatNpr(record.amountPaisa)}',
                message:
                    '${record.plan.name} via ${record.methodName}.',
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Mark as succeeded',
                isLoading: busy,
                onPressed: busy ? null : onSuccess,
              ),
              AppSpacing.gapMd,
              AppButton(
                label: 'Mark as failed',
                variant: AppButtonVariant.secondary,
                onPressed: busy ? null : onFailure,
              ),
              AppSpacing.gapMd,
              AppButton(
                label: 'Cancel payment',
                variant: AppButtonVariant.text,
                onPressed: busy ? null : onCancel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.record,
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final PurchaseRecord record;
  final IconData icon;
  final InlineMessageTone tone;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: title),
        Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InlineMessage(
                tone: tone,
                icon: icon,
                title: '${record.plan.name} · ${formatNpr(record.amountPaisa)}',
                message: message,
              ),
              AppSpacing.gapXl,
              AppButton(label: actionLabel, onPressed: onAction),
              AppSpacing.gapMd,
              AppButton(
                label: 'Purchase history',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(AppRoutes.subscriptionHistory),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
