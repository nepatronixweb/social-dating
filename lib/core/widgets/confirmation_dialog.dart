import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'app_button.dart';

/// Shows a modal confirmation dialog. Resolves to `true` only when the user
/// explicitly confirms; dismissing resolves to `false`.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return result ?? false;
}

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: context.text.headlineSmall),
              ),
              AppSpacing.gapMd,
              Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: confirmLabel,
                variant: isDestructive
                    ? AppButtonVariant.destructive
                    : AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              AppSpacing.gapSm,
              AppButton(
                label: cancelLabel,
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
