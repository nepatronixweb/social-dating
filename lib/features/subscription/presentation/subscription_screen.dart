import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/subscription_rules.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../providers/subscription_providers.dart';
import 'widgets/complimentary_premium.dart';

/// Subscription overview: active benefits when subscribed, otherwise a custom
/// amount checkout. Plan cards are not offered. Checkout is a mock.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _busy = false;
  late final TextEditingController _amount = TextEditingController(
    text: '${SubscriptionRules.suggestedPricePaisa ~/ 100}',
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _rupees {
    final parsed = int.tryParse(_amount.text.trim());
    return parsed;
  }

  int? get _paisa {
    final rupees = _rupees;
    if (rupees == null) return null;
    return SubscriptionRules.nprToPaisa(rupees);
  }

  bool get _amountOk {
    final paisa = _paisa;
    return paisa != null && SubscriptionRules.isValidAmount(paisa);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    setState(() {});
    try {
      await action();
      if (mounted) ref.read(subscriptionRevisionProvider.notifier).bump();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSubscriptionProvider);
    final complimentary = sessionHasComplimentaryPremium(
      ref.watch(sessionProvider),
    );
    final current = complimentary
        ? (active.value ??
              ActiveSubscription.complimentary(
                startedAt: ref.watch(clockProvider)(),
              ))
        : active.value;

    return AppPage(
      appBar: AppTopBar(
        title: 'Premium',
        actions: [
          IconButton(
            tooltip: 'Purchase history',
            icon: const Icon(AppIcons.receipt),
            onPressed: () => context.push(AppRoutes.subscriptionHistory),
          ),
          IconButton(
            tooltip: 'Billing help',
            icon: const Icon(AppIcons.help),
            onPressed: () => context.push(AppRoutes.subscriptionHelp),
          ),
        ],
      ),
      bottomBar: current != null
          ? null
          : Padding(
              padding: AppSpacing.pagePadding.copyWith(
                top: AppSpacing.md,
                bottom: AppSpacing.lg,
              ),
              child: ConstrainedContent(
                child: AppButton(
                  label: 'Review purchase',
                  onPressed: _amountOk
                      ? () => context.push(
                          AppRoutes.subscriptionPlan(
                            SubscriptionRules.standardPlanId,
                            paisa: _paisa,
                          ),
                        )
                      : null,
                ),
              ),
            ),
      body: current != null
          ? _ActiveBody(
              active: current,
              busy: _busy,
              onCancel: () async {
                final confirmed = await showConfirmationDialog(
                  context,
                  title: 'Cancel renewal?',
                  message:
                      'You keep access until the current period ends. '
                      'Nothing is billed. This is not a store cancellation.',
                  confirmLabel: 'Cancel renewal',
                  cancelLabel: 'Keep renewing',
                  isDestructive: true,
                );
                if (!confirmed || !mounted) return;
                await _run(
                  () =>
                      ref.read(subscriptionRepositoryProvider).cancelRenewal(),
                );
              },
              onResume: () => _run(() async {
                await ref.read(subscriptionRepositoryProvider).resumeRenewal();
              }),
            )
          : SingleChildScrollView(
              child: ConstrainedContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'Go Premium',
                      subtitle: _amountOk
                          ? 'You will get '
                                '${formatPoints(SubscriptionRules.buyerPointsFor(_paisa!))}.'
                          : 'Choose an amount of at least NPR 10.',
                    ),
                    Padding(
                      padding: AppSpacing.pagePadding,
                      child: AppTextField(
                        label: 'Amount (NPR)',
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        errorText: _amount.text.isEmpty
                            ? 'Enter how much you want to pay.'
                            : (_amountOk
                                  ? null
                                  : 'Enter at least NPR '
                                        '${SubscriptionRules.minPricePaisa ~/ 100}.'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    AppSpacing.gapLg,
                    AppSection(
                      title: 'Included',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final feature
                              in SubscriptionRules.standardFeatures)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                '• $feature',
                                style: context.text.bodyMedium,
                              ),
                            ),
                          if (_amountOk)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                '• ${formatPoints(SubscriptionRules.buyerPointsFor(_paisa!))} '
                                'with this purchase '
                                '(stated ${formatNpr(SubscriptionRules.buyerPointsFor(_paisa!))})',
                                style: context.text.bodyMedium,
                              ),
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

class _ActiveBody extends StatelessWidget {
  const _ActiveBody({
    required this.active,
    required this.busy,
    required this.onCancel,
    required this.onResume,
  });

  final ActiveSubscription active;
  final bool busy;
  final Future<void> Function() onCancel;
  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: active.complimentary
                  ? SubscriptionRules.complimentaryHeadline
                  : 'Your membership',
              subtitle: active.complimentary
                  ? SubscriptionRules.complimentaryBody
                  : 'Your membership details and renewal settings.',
            ),
            Padding(
              padding: AppSpacing.pagePadding,
              child: InlineMessage(
                tone: InlineMessageTone.success,
                icon: AppIcons.success,
                title: active.complimentary
                    ? '${active.plan.name} with your account'
                    : '${active.plan.name} is active',
                message: active.complimentary
                    ? 'You already have every Premium feature. You do not '
                          'need to pay.'
                    : 'Started ${relativeTime(active.startedAt)}.',
              ),
            ),
            AppSpacing.gapLg,
            AppSection(
              title: 'Benefits',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final feature in active.plan.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text('• $feature', style: context.text.bodyMedium),
                    ),
                  if (!active.complimentary)
                    Text(
                      'Promotional points from this purchase: '
                      '${formatPoints(SubscriptionRules.buyerPointsFor(active.plan.pricePaisa))} '
                      '(stated ${formatNpr(SubscriptionRules.buyerPointsFor(active.plan.pricePaisa))}). '
                      '${SubscriptionRules.promotionalPointsWithdrawable ? '' : 'Not withdrawable.'}',
                      style: context.text.bodyMedium,
                    ),
                ],
              ),
            ),
            if (active.isRecurring)
              AppSection(
                title: 'Renewal',
                subtitle: 'Shown because this plan is configured as recurring.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      active.renewalCancelled
                          ? 'Renewal is cancelled. Access continues until the '
                                'current period ends.'
                          : active.renewsAt == null
                          ? 'This plan renews automatically until you cancel.'
                          : 'Next renewal on ${chatDayLabel(active.renewsAt!)}.',
                      style: context.text.bodyMedium,
                    ),
                    AppSpacing.gapLg,
                    AppButton(
                      label: active.renewalCancelled
                          ? 'Resume renewal'
                          : 'Cancel renewal',
                      variant: active.renewalCancelled
                          ? AppButtonVariant.secondary
                          : AppButtonVariant.destructive,
                      isLoading: busy,
                      onPressed: busy
                          ? null
                          : (active.renewalCancelled ? onResume : onCancel),
                    ),
                  ],
                ),
              ),
            AppSection(
              title: 'More',
              child: Column(
                children: [
                  MenuTile(
                    icon: AppIcons.receipt,
                    title: 'Purchase history',
                    onTap: () => context.push(AppRoutes.subscriptionHistory),
                  ),
                  MenuTile(
                    icon: AppIcons.help,
                    title: 'FAQ and billing help',
                    onTap: () => context.push(AppRoutes.subscriptionHelp),
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
