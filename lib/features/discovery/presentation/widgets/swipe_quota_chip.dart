import 'package:flutter/material.dart';

import '../../../../core/constants/swipe_rules.dart';
import '../../../../core/theme/photo_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../data/models/swipe.dart';

/// One-line summary of the swipe allowance, or `null` when there is nothing
/// worth showing (an account with no daily limit).
String? swipeQuotaSummary(SwipeQuota quota) {
  switch (quota.next.kind) {
    case SwipeKind.preview:
      return '${quota.previewRemaining} of ${SwipeRules.previewSwipes} '
          'preview swipes left';
    case SwipeKind.needsProfile:
      return 'Preview swipes used. Complete your profile to continue';
    case SwipeKind.free:
      final remaining = quota.freeRemaining;
      if (remaining == null) return null;
      return '$remaining of ${quota.freeDailyLimit} free swipes left today';
    case SwipeKind.paid:
    case SwipeKind.insufficient:
      return 'Free swipes used today. Extra swipes ${formatNpr(quota.pricePaisa)} each';
  }
}

/// Tappable pill above the card showing the allowance. Opens the limit sheet.
/// Labelled as mock because counting and pricing are simulated.
class SwipeQuotaChip extends StatelessWidget {
  const SwipeQuotaChip({
    super.key,
    required this.quota,
    required this.onTap,
    this.onImage = false,
  });

  final SwipeQuota quota;
  final VoidCallback onTap;

  /// Compact dark-glass style for use over a photo.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final summary = swipeQuotaSummary(quota);
    if (summary == null) return const SizedBox.shrink();
    final colors = context.colors;
    final palette = context.palette;
    final warn =
        quota.next.kind == SwipeKind.paid ||
        quota.next.kind == SwipeKind.insufficient ||
        quota.next.kind == SwipeKind.needsProfile;

    return Semantics(
      button: true,
      label: '$summary. Double tap for details.',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: onImage
            ? PhotoTokens.shade.withValues(alpha: 0.5)
            : warn
            ? colors.primaryContainer
            : palette.surfaceMuted,
        shape: onImage
            ? StadiumBorder(
                side: BorderSide(
                  color: warn
                      ? colors.primary
                      : PhotoTokens.foreground.withValues(alpha: 0.16),
                ),
              )
            : null,
        borderRadius: onImage ? null : AppRadii.borderPill,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: onImage ? 36 : AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.bolt,
                    size: AppSizes.iconMd,
                    color: warn && !onImage
                        ? colors.onPrimaryContainer
                        : colors.primary,
                  ),
                  AppSpacing.gapSm,
                  Flexible(
                    child: Text(
                      summary,
                      // Two lines at most, so large text cannot squeeze the
                      // card out. The full text is in the semantics label and
                      // the limits sheet.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: onImage
                            ? PhotoTokens.foreground
                            : warn
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Icon(
                    AppIcons.info,
                    size: AppSizes.iconMd,
                    color: onImage
                        ? PhotoTokens.foreground.withValues(alpha: 0.7)
                        : palette.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
