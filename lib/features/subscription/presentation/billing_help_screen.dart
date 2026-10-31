import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';

const _faq = [
  (
    'Who needs to buy Premium?',
    'Only male accounts. Female, LGBTQ+ and other accounts already have '
        'every Premium feature at no charge and cannot start checkout.',
  ),
  (
    'What do I pay for Premium?',
    'You choose the amount. The minimum is NPR 10. Taxes and extra fees '
        'appear only if a verified provider or explicit configuration '
        'supplies them.',
  ),
  (
    'What are the promotional points?',
    'They are 30% of the amount you pay, with a stated NPR equivalent. They '
        'are not withdrawable unless product policy is changed. They are not '
        'earned points and not cash-convertible rewards.',
  ),
  (
    'What is a referral-linked purchase?',
    'If you apply a valid referral code, the review also shows a direct '
        'referral commission and a company allocation. That split is '
        'explanatory.',
  ),
  (
    'Will this renew?',
    'Only plans configured as recurring show renewal or cancellation. The '
        'standard NPR 100 plan does not auto-renew unless configured.',
  ),
  (
    'How do I get help with a charge?',
    'When a provider is connected, billing help will point to that provider '
        'and to support.',
  ),
];

class BillingHelpScreen extends StatelessWidget {
  const BillingHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: const AppTopBar(title: 'Billing help'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'FAQ',
                subtitle: 'Billing, points and renewal.',
              ),
              AppSpacing.gapLg,
              AppSection(
                title: 'Questions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (question, answer) in _faq) ...[
                      Text(question, style: context.text.titleMedium),
                      AppSpacing.gapXs,
                      Text(
                        answer,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                      AppSpacing.gapLg,
                    ],
                  ],
                ),
              ),
              AppSection(
                title: 'Also',
                child: Column(
                  children: [
                    MenuTile(
                      icon: AppIcons.document,
                      title: 'Terms of Service',
                      onTap: () => context.push(AppRoutes.legalTerms),
                    ),
                    MenuTile(
                      icon: AppIcons.receipt,
                      title: 'Purchase history',
                      onTap: () => context.push(AppRoutes.subscriptionHistory),
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
