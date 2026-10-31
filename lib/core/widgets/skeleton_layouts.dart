import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import 'loading_indicator.dart';

/// Skeleton row mirroring a [ChatPreviewTile]: avatar plus two text lines.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            borderRadius: AppRadii.borderPill,
          ),
          AppSpacing.gapLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 16),
                AppSpacing.gapSm,
                SkeletonBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-scrolling list of [SkeletonListTile]s. Announced once as "Loading".
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading',
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, _) => const SkeletonListTile(),
      ),
    );
  }
}

/// Non-scrolling grid of portrait card skeletons.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading',
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.pagePadding,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: AppSizes.gridTileMaxWidth,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: AppSizes.photoAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) => const SkeletonBox(
          borderRadius: AppRadii.borderLg,
          height: double.infinity,
        ),
      ),
    );
  }
}

/// A single large card skeleton (e.g. the discovery card).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: AppSpacing.pagePadding,
      child: SkeletonBox(
        borderRadius: AppRadii.borderXl,
        height: double.infinity,
      ),
    );
  }
}
