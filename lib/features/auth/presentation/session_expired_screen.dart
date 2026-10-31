import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/state_message.dart';
import '../providers/session_provider.dart';

/// Shown when a previous session can no longer be used (older than the mock
/// session lifetime, or rejected by the backend later on).
class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(sessionProvider.select((s) => s.phoneLabel));

    return AppPage(
      appBar: const AppTopBar(title: 'Social Dating'),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedContent(
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StateMessage(
                    icon: AppIcons.sessionExpired,
                    title: 'Your session expired',
                    message: label == null
                        ? 'Please log in again to continue.'
                        : 'Please log in again to continue as $label.',
                  ),
                  AppSpacing.gapLg,
                  AppButton(
                    label: 'Log in again',
                    onPressed: () => context.push(AppRoutes.phone(login: true)),
                  ),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Back to start',
                    variant: AppButtonVariant.text,
                    onPressed: () =>
                        ref.read(sessionProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
