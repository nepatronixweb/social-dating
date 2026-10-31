import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/photo_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../notifications/presentation/notification_bell.dart';

/// The discovery categories shown as tabs. Only [forYou] is built; the others
/// are visible so the layout is final, and report "coming soon" when tapped.
enum DiscoveryCategory {
  forYou('For You'),
  doubleDate('Double Date'),
  astrology('Astrology'),
  music('Music');

  const DiscoveryCategory(this.label);
  final String label;
}

/// Header drawn over the discovery photo: brand and notifications, the category
/// tabs with the preferences button, and the photo dots. It is always styled
/// for a dark photo, in light and dark themes alike.
class DiscoveryHeader extends StatelessWidget {
  const DiscoveryHeader({
    super.key,
    required this.category,
    required this.onCategory,
    required this.onPreferences,
    this.activeFilterCount = 0,
    this.showFinishProfile = false,
    this.onFinishProfile,
  });

  final DiscoveryCategory category;
  final ValueChanged<DiscoveryCategory> onCategory;
  final VoidCallback onPreferences;
  final int activeFilterCount;
  final bool showFinishProfile;
  final VoidCallback? onFinishProfile;

  @override
  Widget build(BuildContext context) {
    final onImageButtons = IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: PhotoTokens.foreground),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const BrandMark(size: 22),
                AppSpacing.gapMd,
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      header: true,
                      child: Text(
                        AppConstants.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(
                          color: PhotoTokens.foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showFinishProfile)
                  TextButton(
                    onPressed: onFinishProfile,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.primary,
                    ),
                    child: const Text('Finish profile'),
                  ),
                Theme(
                  data: context.theme.copyWith(iconButtonTheme: onImageButtons),
                  child: const NotificationBell(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in DiscoveryCategory.values)
                        _CategoryTab(
                          category: c,
                          selected: c == category,
                          onTap: () => onCategory(c),
                        ),
                    ],
                  ),
                ),
              ),
              Theme(
                data: context.theme.copyWith(iconButtonTheme: onImageButtons),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: activeFilterCount > 0
                      ? 'Discovery preferences, $activeFilterCount active'
                      : 'Discovery preferences',
                  onPressed: onPreferences,
                  icon: Badge(
                    isLabelVisible: activeFilterCount > 0,
                    label: Text('$activeFilterCount'),
                    child: Icon(AppIcons.bolt, color: context.colors.primary),
                  ),
                ),
              ),
              AppSpacing.gapXs,
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final DiscoveryCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.borderPill,
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.fast),
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget - AppSpacing.sm,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? PhotoTokens.shade.withValues(alpha: 0.4)
                  : Colors.transparent,
              borderRadius: AppRadii.borderPill,
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.85)
                    : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  SizedBox.square(
                    dimension: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  AppSpacing.gapSm,
                ],
                Text(
                  category.label,
                  maxLines: 1,
                  style: context.text.labelMedium?.copyWith(
                    color: PhotoTokens.foreground.withValues(
                      alpha: selected ? 1 : 0.78,
                    ),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo position dots: the current one is elongated. Hidden for a single
/// photo. The photo carousel already announces its position, so these are
/// decorative.
class PhotoDots extends StatelessWidget {
  const PhotoDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    final duration = AppMotion.resolve(context, AppMotion.fast);

    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: PhotoTokens.foreground.withValues(
                  alpha: i == index ? 0.95 : 0.4,
                ),
                borderRadius: AppRadii.borderPill,
              ),
            ),
        ],
      ),
    );
  }
}
