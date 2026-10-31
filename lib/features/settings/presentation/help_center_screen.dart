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
    'Are notifications real?',
    'The inbox shows recent activity. Push and reminder preferences are stored '
        'on this device until a delivery service is connected.',
  ),
  (
    'What is public on my profile?',
    'Name, age, city, photos, bio and interests can appear on your card. '
        'Occupation is optional. Your phone number, exact location and date '
        'of birth stay private.',
  ),
  (
    'How do I report someone?',
    'Open Safety center, then Report a person. You pick a category, optional '
        'details and an optional photo attachment.',
  ),
  (
    'How do I block someone?',
    'Block from a match or chat. Blocked people are listed under Safety. '
        'Unblocking needs confirmation. Changes stay on this device.',
  ),
  (
    'What happens if I delete my account?',
    'Your session on this device ends. Profile information may be removed '
        'subject to the retention policy. Some records may be kept for safety '
        'or legal reasons.',
  ),
  (
    'Are the Terms and Privacy Policy final?',
    'They are the current policy documents. Read them for the latest wording.',
  ),
];

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: const AppTopBar(title: 'Help center'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'Questions',
                subtitle: 'Common answers about the app.',
              ),
              AppSpacing.gapLg,
              AppSection(
                title: 'Frequently asked',
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
                      icon: AppIcons.safety,
                      title: 'Safety center',
                      onTap: () => context.push(AppRoutes.safety),
                    ),
                    MenuTile(
                      icon: AppIcons.document,
                      title: 'Terms of Service',
                      onTap: () => context.push(AppRoutes.legalTerms),
                    ),
                    MenuTile(
                      icon: AppIcons.shield,
                      title: 'Privacy Policy',
                      onTap: () => context.push(AppRoutes.legalPrivacy),
                    ),
                    MenuTile(
                      icon: AppIcons.account,
                      title: 'Account',
                      onTap: () => context.push(AppRoutes.account),
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
