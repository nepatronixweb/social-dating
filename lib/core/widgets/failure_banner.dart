import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../theme/app_icons.dart';
import 'inline_message.dart';

/// Shows an [AppFailure] inline, with a "Try again" action when retrying can
/// help (network, server and sign-in failures; not wrong or expired codes,
/// which have their own fixes).
class FailureBanner extends StatelessWidget {
  const FailureBanner({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  static bool isRetryable(AppFailure failure) =>
      failure is! ValidationFailure && failure is! CodeExpiredFailure;

  @override
  Widget build(BuildContext context) {
    final retry = isRetryable(failure) ? onRetry : null;
    return InlineMessage(
      bringIntoView: true,
      tone: failure is NetworkFailure
          ? InlineMessageTone.warning
          : InlineMessageTone.error,
      icon: failure is NetworkFailure ? AppIcons.wifiOff : null,
      title: failure.title,
      message: failure.message,
      actionLabel: retry == null ? null : 'Try again',
      onAction: retry,
    );
  }
}
