import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/distance_label.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/circle_action_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/image_carousel.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/swipe.dart';
import '../providers/discovery_providers.dart';

/// Full profile: scrollable page with a photo gallery, then every detail.
///
/// Photos page horizontally, the page scrolls vertically, and nothing here
/// swipes the profile away. The pass and like buttons at the bottom close the
/// screen with the chosen [SwipeDirection]; the discovery screen then runs
/// the normal swipe flow (limits, confirmation and so on).
class ProfileDetailScreen extends ConsumerWidget {
  const ProfileDetailScreen({super.key, required this.profileId, this.profile});

  final String profileId;

  /// Passed from discovery. When absent (for example a direct link) the
  /// profile is looked up in the current deck.
  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved =
        profile ??
        ref
            .read(discoveryControllerProvider)
            .deck
            .where((p) => p.id == profileId)
            .firstOrNull;

    if (resolved == null) {
      return AppPage(
        appBar: const AppTopBar(title: 'Profile'),
        body: ErrorState(
          title: 'Profile unavailable',
          message: 'This profile is no longer available.',
          retryLabel: 'Back to discovery',
          onRetry: () => context.pop(),
        ),
      );
    }

    return AppPage(
      appBar: AppTopBar(title: resolved.displayName),
      body: ProfileDetailBody(profile: resolved),
      bottomBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleActionButton(
              icon: AppIcons.pass,
              label: 'Pass on ${resolved.displayName}',
              onPressed: () => context.pop(SwipeDirection.left),
            ),
            AppSpacing.gapXxl,
            CircleActionButton(
              icon: AppIcons.heart,
              label: 'Like ${resolved.displayName}',
              emphasized: true,
              size: 76,
              onPressed: () => context.pop(SwipeDirection.right),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrollable profile content. Also used by the match detail screen,
/// which adds its own [intro] (matched and activity lines) and [footer].
class ProfileDetailBody extends StatelessWidget {
  const ProfileDetailBody({
    super.key,
    required this.profile,
    this.intro,
    this.footer,
  });

  final Profile profile;
  final Widget? intro;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final palette = context.palette;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.cardMaxWidth),
        child: SingleChildScrollView(
          key: const ValueKey('profile-detail-scroll'),
          padding: AppSpacing.pagePadding.copyWith(
            top: AppSpacing.sm,
            bottom: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadii.borderXl,
                child: AspectRatio(
                  aspectRatio: AppSizes.photoAspectRatio,
                  child: ImageCarousel(
                    photoCount: profile.photoCount < 1 ? 1 : profile.photoCount,
                    placeholderSeed: profile.photoSeed,
                    images: [
                      for (final path in profile.photos)
                        profileImageProvider(path),
                    ],
                    semanticLabel: '${profile.displayName} photo',
                  ),
                ),
              ),
              AppSpacing.gapXl,
              Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        '${profile.displayName}, ${profile.age}',
                        style: text.headlineMedium,
                      ),
                    ),
                  ),
                  if (profile.isVerified) ...[
                    AppSpacing.gapSm,
                    const VerifiedBadge(size: AppSizes.iconLg),
                  ],
                ],
              ),
              AppSpacing.gapSm,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (profile.isOnline)
                    const AppPill(label: 'Online now', tone: AppPillTone.brand),
                  if (profile.isVerified)
                    const AppPill(
                      label: 'Verified',
                      tone: AppPillTone.neutral,
                      icon: AppIcons.verified,
                    ),
                ],
              ),
              if (intro != null) ...[AppSpacing.gapMd, intro!],
              AppSpacing.gapLg,
              _InfoRow(
                icon: AppIcons.location,
                label: 'Location',
                value: [
                  profile.city,
                  if (profile.distanceKm != null)
                    approximateDistanceLabel(profile.distanceKm!),
                ].join(' \u00B7 '),
              ),
              if (profile.occupation != null)
                _InfoRow(
                  icon: AppIcons.work,
                  label: 'Work',
                  value: profile.occupation!,
                ),
              if (profile.gender != null)
                _InfoRow(
                  icon: AppIcons.profile,
                  label: 'Gender',
                  value: profile.gender!.label,
                ),
              if (profile.lookingFor != null)
                _InfoRow(
                  icon: AppIcons.heartOutline,
                  label: 'Looking for',
                  value: profile.lookingFor!,
                ),
              if (profile.bio.isNotEmpty) ...[
                AppSpacing.gapXl,
                Semantics(
                  header: true,
                  child: Text('About', style: text.titleMedium),
                ),
                AppSpacing.gapSm,
                Text(profile.bio, style: text.bodyLarge),
              ],
              if (profile.interests.isNotEmpty) ...[
                AppSpacing.gapXl,
                Semantics(
                  header: true,
                  child: Text('Interests', style: text.titleMedium),
                ),
                AppSpacing.gapSm,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final interest in profile.interests)
                      InterestChip(label: interest),
                  ],
                ),
              ],
              AppSpacing.gapXl,
              Text(
                'Distances are approximate. Exact locations are never shown.',
                style: text.bodySmall?.copyWith(color: palette.textMuted),
              ),
              if (footer != null) ...[AppSpacing.gapXl, footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        container: true,
        label: '$label: $value',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppSizes.iconMd, color: context.colors.primary),
            AppSpacing.gapMd,
            Expanded(child: Text(value, style: context.text.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
