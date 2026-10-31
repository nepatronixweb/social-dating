import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../theme/app_icons.dart';
import '../utils/theme_context.dart';
import 'state_message.dart';

/// Shown when loading fails. Offers a retry action when [onRetry] is given.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'An unexpected error occurred. Please try again.',
    this.icon = AppIcons.error,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  /// Builds an [ErrorState] from any thrown object, using safe user messages.
  factory ErrorState.fromError(
    Object error, {
    Key? key,
    VoidCallback? onRetry,
  }) {
    final failure = AppFailure.from(error);
    return ErrorState(
      key: key,
      title: failure.title,
      message: failure.message,
      icon: failure is NetworkFailure ? AppIcons.wifiOff : AppIcons.error,
      onRetry: onRetry,
    );
  }

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: icon,
      iconColor: context.colors.error,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
    );
  }
}
