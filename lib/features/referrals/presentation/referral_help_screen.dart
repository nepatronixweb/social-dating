import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/referral_rules.dart';
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
    'What is the invite link?',
    'It is the link returned for your unique code. Friends can also type '
        'the code when they create an account.',
  ),
  (
    'When does a commission leave pending?',
    'Only after a qualifying NPR 100 purchase is confirmed. Joining with '
        'the code is not enough.',
  ),
  (
    'What if a purchase is refunded?',
    'The related commission is reversed. Reversed amounts are not earnings '
        'and are not paid.',
  ),
  (
    'Are there multi-level commissions?',
    'No. Only a direct referrer commission exists. There is no downstream '
        'or second-level share.',
  ),
];

class ReferralHelpScreen extends StatelessWidget {
  const ReferralHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: const AppTopBar(title: 'Referral help'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'Eligibility and reversals',
                subtitle: 'Direct referrals only. Payouts wait on a provider.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ReferralRules.eligibilityNote,
                      style: context.text.bodyMedium,
                    ),
                    AppSpacing.gapMd,
                    Text(
                      ReferralRules.pendingUntilConfirmed,
                      style: context.text.bodyMedium,
                    ),
                    AppSpacing.gapMd,
                    Text(
                      ReferralRules.reversalNote,
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
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
                      icon: AppIcons.history,
                      title: 'Referral history',
                      onTap: () => context.push(AppRoutes.referralHistory),
                    ),
                    MenuTile(
                      icon: AppIcons.wallet,
                      title: 'Commission earnings',
                      onTap: () => context.push(AppRoutes.referralEarnings),
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
