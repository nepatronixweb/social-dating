import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_atmosphere.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/inline_message.dart';
import '../../auth/providers/session_provider.dart';

/// First screen after the splash. Phone sign-in is the only entry: number,
/// code, then the app.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(sessionNoticeProvider);

    void open(String route) {
      ref.read(sessionNoticeProvider.notifier).clear();
      context.push(route);
    }

    return Scaffold(
      backgroundColor: context.palette.pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BrandAtmosphere(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final markSize = (constraints.maxHeight * 0.14).clamp(
                  64.0,
                  108.0,
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: ConstrainedContent(
                      child: Padding(
                        padding: AppSpacing.pagePadding.copyWith(
                          top: AppSpacing.xxl,
                          bottom: AppSpacing.xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (notice != null) ...[
                              InlineMessage(
                                tone: InlineMessageTone.success,
                                message: switch (notice) {
                                  SessionNotice.signedOut =>
                                    'You\'ve been signed out.',
                                  SessionNotice.accountDeleted =>
                                    'Your account details were deleted from this '
                                        'device.',
                                },
                                actionLabel: 'Dismiss',
                                onAction: () => ref
                                    .read(sessionNoticeProvider.notifier)
                                    .clear(),
                              ),
                              AppSpacing.gapLg,
                            ],
                            Center(
                              child: BrandMark(size: markSize, glow: true),
                            ),
                            AppSpacing.gapXxl,
                            Semantics(
                              header: true,
                              child: Text.rich(
                                TextSpan(
                                  style: context.text.displayMedium,
                                  children: [
                                    const TextSpan(text: 'Dating with\n'),
                                    TextSpan(
                                      text: 'intention.',
                                      style: TextStyle(
                                        color: context.colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            AppSpacing.gapMd,
                            Text(
                              'Thoughtful introductions, real conversations, and '
                              'people who are here for the same reason you are.',
                              textAlign: TextAlign.center,
                              style: context.text.bodyLarge?.copyWith(
                                color: context.palette.textMuted,
                              ),
                            ),
                            AppSpacing.gapXl,
                            AppButton(
                              label: 'Log in',
                              icon: AppIcons.forward,
                              pill: true,
                              onPressed: () =>
                                  open(AppRoutes.phone(login: true)),
                            ),
                            AppSpacing.gapMd,
                            Text(
                              'By continuing you agree to our',
                              style: context.text.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      context.push(AppRoutes.legalTerms),
                                  child: const Text('Terms of Service'),
                                ),
                                Text('and', style: context.text.bodySmall),
                                TextButton(
                                  onPressed: () =>
                                      context.push(AppRoutes.legalPrivacy),
                                  child: const Text('Privacy Policy'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
