import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';

enum AppSnackType { info, success, error }

/// Shows a floating snackbar, replacing any one already visible. The icon (not
/// just colour) distinguishes the [type].
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackType type = AppSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final scheme = Theme.of(context).colorScheme;
  final icon = switch (type) {
    AppSnackType.info => AppIcons.info,
    AppSnackType.success => AppIcons.success,
    AppSnackType.error => AppIcons.error,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        margin: const EdgeInsets.all(AppSpacing.lg),
        content: Row(
          children: [
            Icon(icon, size: AppSizes.iconMd, color: scheme.onInverseSurface),
            AppSpacing.gapMd,
            Expanded(child: Text(message)),
          ],
        ),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: scheme.inversePrimary,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
