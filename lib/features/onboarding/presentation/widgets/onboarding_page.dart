import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/brand_atmosphere.dart';
import '../../../../core/widgets/onboarding_progress.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../auth/providers/session_provider.dart';

/// Shared layout for the first-time setup screens: progress indicator, large
/// heading, content, and a pinned primary action. "Sign out" is always in the
/// top bar so nobody is trapped mid-setup.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({
    super.key,
    required this.step,
    required this.stepLabel,
    required this.title,
    required this.children,
    this.accentTitle,
    this.subtitle,
    this.primaryAction,
    this.secondaryAction,
    this.complete = false,
    this.total = 5,
    this.appBarTitle = 'Set up your account',
  });

  final int step;
  final String stepLabel;
  final String title;

  /// Second line of the title, drawn in the brand colour ("start").
  final String? accentTitle;
  final String? subtitle;
  final List<Widget> children;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final bool complete;
  final int total;
  final String appBarTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      atmosphere: BrandAtmosphereStyle.waves,
      appBar: AppTopBar(
        title: appBarTitle,
        transparent: true,
        circleBack: true,
        actions: [
          if (!complete)
            TextButton(
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
        ],
      ),
      bottomBar: primaryAction == null
          ? null
          : Padding(
              padding: AppSpacing.pagePadding.copyWith(
                top: AppSpacing.md,
                bottom: AppSpacing.xl,
              ),
              child: ConstrainedContent(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.borderPill,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.primary.withValues(
                              alpha: 0.32,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: primaryAction!,
                    ),
                    if (secondaryAction != null) ...[
                      AppSpacing.gapSm,
                      secondaryAction!,
                    ],
                  ],
                ),
              ),
            ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.sm),
                child: OnboardingProgress(
                  step: step,
                  total: total,
                  label: stepLabel,
                  complete: complete,
                ),
              ),
              ScreenHeader(
                title: title,
                accentTitle: accentTitle,
                subtitle: subtitle,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.xl,
                  AppSpacing.pageGutter,
                  AppSpacing.lg,
                ),
              ),
              Padding(
                padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
