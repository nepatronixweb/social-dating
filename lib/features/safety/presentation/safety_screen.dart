import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';

const List<(IconData, String, String)> _tips = [
  (
    AppIcons.location,
    'Meet in public',
    'Choose a busy place for a first meeting and tell a friend where you are.',
  ),
  (
    AppIcons.lock,
    'Protect your details',
    'Keep your address, workplace and finances private until you trust them.',
  ),
  (
    AppIcons.verified,
    'Look for verified profiles',
    'A verified badge means the person completed an identity check.',
  ),
  (
    AppIcons.report,
    'Trust your instincts',
    'If something feels off, stop replying and report it.',
  ),
];

/// Safety center: tips, blocked list and a mock report flow.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: const AppTopBar(title: 'Safety center'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ScreenHeader(
                  title: 'Stay safe',
                  subtitle: 'Simple habits that make dating safer.',
                ),
                AppSection(
                  title: 'Tips',
                  child: Column(
                    children: [
                      for (final (icon, title, body) in _tips)
                        _TipCard(icon: icon, title: title, body: body),
                    ],
                  ),
                ),
                AppSection(
                  title: 'People you have blocked',
                  child: MenuTile(
                    icon: AppIcons.block,
                    title: 'Blocked users',
                    subtitle: 'Unblock with confirmation',
                    onTap: () => context.push(AppRoutes.blockedUsers),
                  ),
                ),
                AppSection(
                  title: 'Need to report someone?',
                  child: AppButton(
                    label: 'Report a person',
                    icon: AppIcons.report,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => context.push(AppRoutes.report),
                  ),
                ),
                AppSection(
                  title: 'Help',
                  child: MenuTile(
                    icon: AppIcons.help,
                    title: 'Help center',
                    onTap: () => context.push(AppRoutes.help),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.borderLg,
          border: Border.all(color: context.palette.outlineSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppSizes.iconLg, color: context.colors.primary),
              AppSpacing.gapLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    AppSpacing.gapXs,
                    Text(
                      body,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textMuted,
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
