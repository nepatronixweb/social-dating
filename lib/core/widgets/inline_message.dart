import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

enum InlineMessageTone { info, success, warning, error }

/// A tinted, in-flow message with an icon, optional title and optional action.
///
/// Announced to screen readers when it appears (live region). The icon and
/// text carry the meaning; the tint is reinforcement only.
///
/// Set [bringIntoView] for messages that appear as the result of something the
/// person just did (such as an error after submitting), so they are scrolled
/// into view instead of appearing below the fold.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.title,
    this.tone = InlineMessageTone.info,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.bringIntoView = false,
  });

  final String message;
  final String? title;
  final InlineMessageTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides the tone's default icon.
  final IconData? icon;
  final bool bringIntoView;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    final (accent, defaultIcon) = switch (tone) {
      InlineMessageTone.info => (colors.primary, AppIcons.info),
      InlineMessageTone.success => (palette.success, AppIcons.success),
      InlineMessageTone.warning => (palette.warning, AppIcons.warning),
      InlineMessageTone.error => (colors.error, AppIcons.error),
    };

    final content = Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: AppRadii.borderMd,
          border: Border.all(color: accent.withValues(alpha: 0.40)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon ?? defaultIcon, size: AppSizes.iconLg, color: accent),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: context.text.titleSmall?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    Text(
                      message,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    if (actionLabel != null && onAction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size(
                              AppSpacing.minTouchTarget,
                              AppSpacing.minTouchTarget,
                            ),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return bringIntoView ? _BringIntoView(child: content) : content;
  }
}

/// Scrolls its child into view once, when first shown.
class _BringIntoView extends StatefulWidget {
  const _BringIntoView({required this.child});

  final Widget child;

  @override
  State<_BringIntoView> createState() => _BringIntoViewState();
}

class _BringIntoViewState extends State<_BringIntoView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        duration: AppMotion.resolve(context, AppMotion.fast),
        curve: AppMotion.standard,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
