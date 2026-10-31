import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Large page title with optional subtitle and trailing widget. Used at the
/// top of scrolling tab content, beneath the [AppTopBar].
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.accentTitle,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageGutter,
      AppSpacing.sm,
      AppSpacing.pageGutter,
      AppSpacing.lg,
    ),
  });

  final String title;

  /// Second line of the title, drawn in the brand colour ("number?").
  final String? accentTitle;
  final String? subtitle;

  /// Small label above the title (step indicator on create-account).
  final Widget? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final accent = accentTitle;
    final spokenTitle = accent == null ? title : '$title $accent';
    final headline = accent == null
        ? Text(title, style: context.text.displaySmall)
        : Text.rich(
            TextSpan(
              style: context.text.displayMedium,
              children: [
                TextSpan(text: '$title\n'),
                TextSpan(
                  text: accent,
                  style: TextStyle(color: context.colors.primary),
                ),
              ],
            ),
          );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[eyebrow!, AppSpacing.gapLg],
                Semantics(
                  header: true,
                  label: spokenTitle,
                  excludeSemantics: true,
                  child: headline,
                ),
                if (subtitle != null) ...[
                  AppSpacing.gapSm,
                  Text(
                    subtitle!,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[AppSpacing.gapMd, trailing!],
        ],
      ),
    );
  }
}
