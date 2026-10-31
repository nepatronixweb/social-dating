import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import '../utils/time_format.dart';

/// Centred day label between groups of messages.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.at, this.now});

  final DateTime at;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final label = chatDayLabel(at, now: now);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
