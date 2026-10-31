import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/subscription_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/complimentary_premium.dart';
import 'widgets/quote_breakdown.dart';

/// Checkout review for a standard or referral-linked NPR 100 purchase.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.planId,
    required this.referralLinked,
    this.amountPaisa,
  });

  final String planId;
  final bool referralLinked;
  final int? amountPaisa;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final _code = TextEditingController(
    text: widget.referralLinked ? SubscriptionRules.mockReferralCode : '',
  );
  late bool _referral = widget.referralLinked;
  String? _codeError;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _applyCode() {
    final value = _code.text.trim().toUpperCase();
    if (value.isEmpty) {
      setState(() {
        _referral = false;
        _codeError = null;
      });
      return;
    }
    if (value != SubscriptionRules.mockReferralCode) {
      setState(() {
        _referral = false;
        _codeError = 'That code is not recognised.';
      });
      return;
    }
    setState(() {
      _referral = true;
      _codeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (sessionHasComplimentaryPremium(ref.watch(sessionProvider))) {
      return const AppPage(
        appBar: AppTopBar(title: 'Checkout'),
        body: ComplimentaryPremiumNotice(),
      );
    }
    final repo = ref.watch(subscriptionRepositoryProvider);
    late final PurchaseQuote quote;
    try {
      quote = repo.quote(
        planId: widget.planId,
        referralLinked: _referral,
        amountPaisa: widget.amountPaisa,
      );
    } catch (error) {
      return AppPage(
        appBar: const AppTopBar(title: 'Checkout'),
        body: EmptyState(
          icon: AppIcons.premium,
          title: 'Cannot review this plan',
          message: AppFailure.from(error).message,
        ),
      );
    }

    return AppPage(
      appBar: AppTopBar(
        title: _referral ? 'Referral-linked review' : 'Checkout review',
      ),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: ConstrainedContent(
          child: AppButton(
            label: 'Choose a payment method',
            onPressed: () => context.push(
                    AppRoutes.subscriptionPay(
                      planId: widget.planId,
                      referral: _referral,
                      paisa: widget.amountPaisa,
                    ),
                  ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: quote.plan.name,
                subtitle: _referral
                    ? 'Referral-linked purchase'
                    : 'Standard purchase',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Text(
                  'Amount due ${formatNpr(quote.amountDuePaisa)}',
                  style: context.text.headlineSmall,
                ),
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QuoteBreakdown(quote: quote),
                    AppSpacing.gapXl,
                    Text(
                      'Referral code (optional)',
                      style: context.text.titleMedium,
                    ),
                    AppSpacing.gapSm,
                    AppTextField(
                      label: 'Referral code',
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      errorText: _codeError,
                      onChanged: (_) {
                        if (_codeError != null) {
                          setState(() => _codeError = null);
                        }
                      },
                    ),
                    AppSpacing.gapSm,
                    AppButton(
                      label: 'Apply code',
                      variant: AppButtonVariant.secondary,
                      onPressed: _applyCode,
                    ),
                    AppSpacing.gapXl,
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
