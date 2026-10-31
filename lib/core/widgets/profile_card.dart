import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../utils/media_url.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/distance_label.dart';
import '../utils/theme_context.dart';
import 'image_carousel.dart';
import 'interest_chip.dart';
import 'verified_badge.dart';

/// Discovery card: a photo with the name, age, verified badge, activity,
/// distance band and top interests over a bottom scrim. Fills its parent; give
/// it an `AspectRatio` or `Expanded`.
///
/// With [fullBleed] the card has no rounded corners or shadow so it can run
/// edge to edge behind a header and an action row; [bottomInset] then keeps the
/// text clear of the overlay at the bottom.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.onOpenProfile,
    this.onPageChanged,
    this.placeholderSeed = 0,
    this.maxInterests = 3,
    this.showBio = false,
    this.allowPhotoSwipe = true,
    this.fullBleed = false,
    this.showPhotoIndicator = true,
    this.bottomInset = 0,
  });

  final Profile profile;

  /// Tapping the info area (e.g. to open the full profile).
  final VoidCallback? onTap;

  /// Shows an arrow button beside the name that opens the full profile.
  final VoidCallback? onOpenProfile;

  /// Reports the visible photo, for screens that draw their own indicator.
  final ValueChanged<int>? onPageChanged;
  final int placeholderSeed;
  final int maxInterests;

  /// Shows up to two lines of the bio under the location.
  final bool showBio;

  /// Whether dragging horizontally pages photos. Turn off inside a swipe card.
  final bool allowPhotoSwipe;

  /// Edge-to-edge: no rounded corners or shadow.
  final bool fullBleed;

  /// Draws the built-in photo indicator over the top of the photo.
  final bool showPhotoIndicator;

  /// Space reserved at the bottom for controls drawn over the card.
  final double bottomInset;

  String _semanticLabel({required bool active}) => [
    '${profile.displayName}, ${profile.age}',
    if (profile.isVerified) 'verified',
    if (active) 'active now',
    if (profile.distanceKm != null)
      approximateDistanceLabel(profile.distanceKm!),
    profile.city,
  ].join(', ');

  String _interestsLabel(int count) =>
      'interests: ${profile.interests.take(count).join(', ')}';

  @override
  Widget build(BuildContext context) {
    final location = [
      if (profile.distanceKm != null)
        approximateDistanceLabel(profile.distanceKm!),
      profile.city,
    ].join(' \u00B7 ');

    return LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints, location),
    );
  }

  Widget _build(
    BuildContext context,
    BoxConstraints constraints,
    String location,
  ) {
    final colors = context.colors;
    final text = context.text;

    // Large text or a short card: drop the optional lines first so the name and
    // location always fit. The full profile shows everything.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : 1e6;
    final room = height - bottomInset;
    final showBioNow = showBio && profile.bio.isNotEmpty && room >= 340 * scale;
    final interestsNow = room >= 380 * scale ? maxInterests : 0;
    final showInterests = interestsNow > 0 && profile.interests.isNotEmpty;
    final showActive = profile.isOnline && room >= 300 * scale;
    final white70 = Colors.white.withValues(alpha: 0.85);

    final content = Stack(
      fit: StackFit.expand,
      children: [
        ImageCarousel(
          photoCount: profile.photoCount < 1 ? 1 : profile.photoCount,
          placeholderSeed: placeholderSeed,
          images: [
            for (final path in profile.photos) profileImageProvider(path),
          ],
          semanticLabel: '${profile.displayName} photo',
          allowPageSwipe: allowPhotoSwipe,
          showIndicator: showPhotoIndicator,
          onPageChanged: onPageChanged,
        ),
        // Top scrim keeps the header legible on bright photos.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 240,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Bottom scrim sits under the info block and the action row.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: height.isFinite ? height * 0.62 : 400,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxxl,
              AppSpacing.xl,
              bottomInset + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        container: true,
                        button: onTap != null,
                        label: _semanticLabel(active: showActive),
                        excludeSemantics: true,
                        onTap: onTap,
                        child: InkWell(
                          onTap: onTap,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showActive) ...[
                                const _ActivePill(),
                                AppSpacing.gapSm,
                              ],
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${profile.displayName}, ${profile.age}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.displaySmall?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (profile.isVerified) ...[
                                    AppSpacing.gapSm,
                                    VerifiedBadge(
                                      size: AppSizes.iconLg,
                                      color: colors.primary,
                                    ),
                                  ],
                                ],
                              ),
                              AppSpacing.gapXs,
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.location,
                                    size: AppSizes.iconSm,
                                    color: colors.primary,
                                  ),
                                  AppSpacing.gapXs,
                                  Flexible(
                                    child: Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodyMedium?.copyWith(
                                        color: white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (showBioNow) ...[
                                AppSpacing.gapMd,
                                Text(
                                  profile.bio,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (onOpenProfile != null) ...[
                      AppSpacing.gapMd,
                      _OpenProfileButton(
                        label: "Open ${profile.displayName}'s profile",
                        onPressed: onOpenProfile!,
                      ),
                    ],
                  ],
                ),
                if (showInterests) ...[
                  AppSpacing.gapMd,
                  Semantics(
                    container: true,
                    label: _interestsLabel(interestsNow),
                    excludeSemantics: true,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final interest in profile.interests.take(
                            interestsNow,
                          ))
                            InterestChip(
                              label: interest,
                              onImage: true,
                              icon: AppIcons.forInterest(interest),
                              iconColor: colors.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (fullBleed) return content;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.borderXl,
        boxShadow: AppElevation.high(context.theme.brightness),
      ),
      child: ClipRRect(borderRadius: AppRadii.borderXl, child: content),
    );
  }
}

/// Green "Active" status pill.
class _ActivePill extends StatelessWidget {
  const _ActivePill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.55),
        borderRadius: AppRadii.borderPill,
        border: Border.all(
          color: AppColors.successDark.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.successDark,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            AppSpacing.gapSm,
            Text(
              'Active',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.successDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round arrow button that opens the full profile.
class _OpenProfileButton extends StatelessWidget {
  const _OpenProfileButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.black.withValues(alpha: 0.5),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: AppSpacing.minTouchTarget,
              child: Icon(
                AppIcons.arrowUp,
                size: AppSizes.iconLg,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
