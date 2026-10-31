import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/settings_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/acknowledgement_tile.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _understood = false;
  bool _busy = false;

  Future<void> _continue() async {
    if (!_understood || _busy) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete your account?',
      message:
          'Your profile information may be removed, subject to the retention '
          'policy. This ends your session on this device. This cannot be '
          'undone on this device.',
      confirmLabel: 'Delete account',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).requestAccountDeletion();
      await ref.read(sessionProvider.notifier).deleteAccount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
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
      appBar: const AppTopBar(title: 'Delete account'),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: ConstrainedContent(
          child: AppButton(
            label: 'Continue',
            variant: AppButtonVariant.destructive,
            isLoading: _busy,
            onPressed: _understood && !_busy ? _continue : null,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: 'What this would mean',
                subtitle: 'Read the consequences, then confirm.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSpacing.gapXl,
                    for (final (title, body)
                        in SettingsRules.deletionConsequences) ...[
                      Text(title, style: context.text.titleMedium),
                      AppSpacing.gapXs,
                      Text(
                        body,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                      AppSpacing.gapLg,
                    ],
                    AcknowledgementTile(
                      value: _understood,
                      onChanged: (v) => setState(() => _understood = v),
                      title: 'I understand what deletion means',
                      subtitle:
                          'Your session on this device will end. This cannot '
                          'be undone on this device.',
                    ),
                    AppSpacing.gapXl,
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
