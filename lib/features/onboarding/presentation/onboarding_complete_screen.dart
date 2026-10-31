import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/state_message.dart';
import '../../auth/providers/session_provider.dart';
import 'widgets/onboarding_page.dart';

/// The completion state of first-time setup. "Start exploring" leaves
/// onboarding and enters the app.
class OnboardingCompleteScreen extends ConsumerWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider.select((s) => s.displayName));
    final greeting = (name == null || name.isEmpty)
        ? 'You\'re all set'
        : 'You\'re all set, $name';

    return OnboardingPage(
      step: 5,
      stepLabel: 'Profile',
      complete: true,
      title: greeting,
      subtitle: 'Your account is ready.',
      primaryAction: AppButton(
        label: 'Start exploring',
        icon: AppIcons.forward,
        iconOnEnd: true,
        pill: true,
        onPressed: () => ref.read(sessionProvider.notifier).finishOnboarding(),
      ),
      children: [
        AppSpacing.gapLg,
        StateMessage(
          icon: AppIcons.success,
          title: 'Welcome to ${AppConstants.appName}',
          message:
              'Discover people, send likes and start conversations whenever '
              'you\'re ready.',
        ),
      ],
    );
  }
}
