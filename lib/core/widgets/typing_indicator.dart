import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Static mock typing bubble. No ticker, so tests that pump-and-settle do
/// not hang.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final label = name == null ? 'Typing' : '$name is typing';
    return Semantics(
      liveRegion: true,
      label: label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadii.lg),
              topRight: Radius.circular(AppRadii.lg),
              bottomLeft: Radius.circular(AppRadii.xs),
              bottomRight: Radius.circular(AppRadii.lg),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(
              'Typing...',
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
