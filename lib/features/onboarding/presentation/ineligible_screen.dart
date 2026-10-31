import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/age.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/state_message.dart';
import '../../auth/providers/session_provider.dart';

/// Shown instead of the app when the entered birth date is under the minimum
/// age. In the mock flow this state is remembered on this device, and the
/// router keeps it away from every dating screen.
///
/// UX only: a real backend must enforce the age requirement itself.
class IneligibleScreen extends ConsumerStatefulWidget {
  const IneligibleScreen({super.key});

  @override
  ConsumerState<IneligibleScreen> createState() => _IneligibleScreenState();
}

class _IneligibleScreenState extends ConsumerState<IneligibleScreen> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete your data?',
      message:
          'This removes your account details from this device and signs you '
          'out.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    icon: AppIcons.block,
                    iconColor: context.colors.error,
                    title: 'You can\'t use Social Dating yet',
                    message:
                        'Social Dating is for people aged '
                        '${AgeEligibility.minimumAge} and older. We\'re sorry '
                        'we can\'t let you in right now.',
                  ),
                  AppSpacing.gapLg,
                  AppButton(
                    label: 'Sign out',
                    onPressed: _deleting
                        ? null
                        : () => ref.read(sessionProvider.notifier).signOut(),
                  ),
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'Delete my data',
                    variant: AppButtonVariant.destructive,
                    isLoading: _deleting,
                    onPressed: _delete,
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
