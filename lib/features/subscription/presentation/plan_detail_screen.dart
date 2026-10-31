import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/complimentary_premium.dart';
import 'widgets/quote_breakdown.dart';

/// Amount review for the custom Premium purchase path into checkout.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId, this.amountPaisa});

  final String planId;
  final int? amountPaisa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessionHasComplimentaryPremium(ref.watch(sessionProvider))) {
      return const AppPage(
        appBar: AppTopBar(title: 'Plan'),
        body: ComplimentaryPremiumNotice(),
      );
    }
    final repo = ref.watch(subscriptionRepositoryProvider);

    PurchaseQuote? quote;
    Object? quoteError;
    try {
      quote = repo.quote(
        planId: planId,
        referralLinked: false,
        amountPaisa: amountPaisa,
      );
    } catch (error) {
      quoteError = error;
    }

    if (quote == null) {
      return AppPage(
        appBar: const AppTopBar(title: 'Plan'),
        body: EmptyState(
          icon: AppIcons.premium,
          title: 'Cannot review this amount',
          message: AppFailure.from(quoteError ?? 'Unknown error').message,
        ),
      );
    }

    final reviewed = quote;
    return AppPage(
      appBar: const AppTopBar(title: 'Plan'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: reviewed.plan.name,
                subtitle: reviewed.plan.isRecurring
                    ? '${reviewed.plan.priceLabel} ${reviewed.plan.periodLabel}. Recurring until you cancel.'
                    : '${reviewed.plan.priceLabel} ${reviewed.plan.periodLabel}. Does not auto-renew.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: QuoteBreakdown(quote: reviewed),
              ),
              Padding(
                padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Review standard purchase',
                      onPressed: () => context.push(
                        AppRoutes.subscriptionCheckout(
                          planId: planId,
                          paisa: amountPaisa,
                        ),
                      ),
                    ),
                    AppSpacing.gapMd,
                    AppButton(
                      label: 'Review referral-linked purchase',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.push(
                        AppRoutes.subscriptionCheckout(
                          planId: planId,
                          referral: true,
                          paisa: amountPaisa,
                        ),
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
