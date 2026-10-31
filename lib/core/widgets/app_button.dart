import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// - [primary]: the single main action on a screen (brand gradient).
/// - [secondary]: a neutral filled-outline action on a white surface.
/// - [outlined]: a brand-coloured outline for an alternative strong action.
/// - [text]: low-emphasis, no container.
/// - [destructive]: irreversible or risky actions.
enum AppButtonVariant { primary, secondary, outlined, text, destructive }

/// The app's single button. Minimum height 52 (grows with text scale), never
/// smaller than the 48dp touch target.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.pill = false,
    this.iconOnEnd = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Fill the available width.
  final bool expand;

  /// Fully rounded ends. Used on branded entry actions; other screens keep
  /// the standard corner radius.
  final bool pill;

  /// Places [icon] after the label (Verify →). Default is before it.
  final bool iconOnEnd;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    final Color foreground;
    final Color? background;
    final Gradient? gradient;
    final BorderSide? border;

    switch (variant) {
      case AppButtonVariant.primary:
        foreground = colors.onPrimary;
        background = null;
        gradient = palette.brandGradient;
        border = null;
      case AppButtonVariant.secondary:
        foreground = colors.onSurface;
        background = colors.surface;
        gradient = null;
        border = BorderSide(color: palette.outlineSoft, width: 1.5);
      case AppButtonVariant.outlined:
        foreground = colors.primary;
        background = null;
        gradient = null;
        border = BorderSide(color: colors.primary, width: 1.5);
      case AppButtonVariant.text:
        foreground = colors.primary;
        background = null;
        gradient = null;
        border = null;
      case AppButtonVariant.destructive:
        foreground = colors.onError;
        background = colors.error;
        gradient = null;
        border = null;
    }

    final effectiveForeground = _enabled
        ? foreground
        : foreground.withValues(alpha: 0.6);

    final content = AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.fast),
      child: isLoading
          ? SizedBox.square(
              key: const ValueKey('loading'),
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: effectiveForeground,
                backgroundColor: Colors.transparent,
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null && !iconOnEnd) ...[
                  Icon(icon, size: 20, color: effectiveForeground),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      color: effectiveForeground,
                    ),
                  ),
                ),
                if (icon != null && iconOnEnd) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(icon, size: 20, color: effectiveForeground),
                ],
              ],
            ),
    );

    final disabledTint = !_enabled && !isLoading;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      onTap: _enabled ? onPressed : null,
      child: Opacity(
        opacity: disabledTint ? 0.55 : 1,
        child: Material(
          color: background ?? Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: pill ? AppRadii.borderPill : AppRadii.borderMd,
            side: border ?? BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: gradient == null
                ? null
                : BoxDecoration(
                    gradient: gradient,
                    borderRadius: pill
                        ? AppRadii.borderPill
                        : AppRadii.borderMd,
                  ),
            child: InkWell(
              onTap: _enabled ? onPressed : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 52,
                  minWidth: AppSpacing.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  child: Center(widthFactor: expand ? null : 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
