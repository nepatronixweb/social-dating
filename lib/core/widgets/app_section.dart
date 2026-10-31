import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'section_header.dart';

/// A titled block of content: [SectionHeader] followed by [child], with
/// consistent gutters and spacing. The standard way to lay out screen
/// sections.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padded = true,
    this.bottomSpacing = AppSpacing.xl,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  /// Applies the page gutter to the header (and to [child] when false you
  /// handle your own horizontal padding, e.g. for edge-to-edge carousels).
  final bool padded;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            actionLabel: actionLabel,
            onAction: onAction,
            padding: padded
                ? const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter)
                : EdgeInsets.zero,
          ),
          AppSpacing.gapMd,
          if (padded)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
              ),
              child: child,
            )
          else
            child,
        ],
      ),
    );
  }
}
