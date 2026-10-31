import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'app_button.dart';

/// Shared layout for empty / error states: icon, title, message, action.
///
/// In a bounded area it centres itself and scrolls if the content is taller
/// than the viewport (large text, landscape). Inside an already-scrolling
/// parent (unbounded height) it simply sizes to its content.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.colors.primary;

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: ExcludeSemantics(
                  child: Icon(icon, size: 32, color: color),
                ),
              ),
              AppSpacing.gapXl,
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              AppSpacing.gapSm,
              Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: context.palette.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                AppSpacing.gapXl,
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return content;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}
