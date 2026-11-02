import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../data/models/profile.dart';

/// Bottom sheet with a person's summary. Used from discovery, likes and
/// matches.
Future<void> showProfilePreviewSheet(BuildContext context, Profile profile) {
  return showAppBottomSheet<void>(
    context,
    builder: (sheetContext) => _ProfilePreview(profile: profile),
  );
}

class _ProfilePreview extends StatelessWidget {
  const _ProfilePreview({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ProfileAvatar(
              name: profile.displayName,
              size: AppSizes.avatarLg,
              isOnline: profile.isOnline,
              showRing: true,
            ),
            AppSpacing.gapLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${profile.displayName}, ${profile.age}',
                          style: context.text.headlineMedium,
                        ),
                      ),
                      if (profile.isVerified) ...[
                        AppSpacing.gapSm,
                        const VerifiedBadge(),
                      ],
                    ],
                  ),
                  AppSpacing.gapXs,
                  Row(
                    children: [
                      Icon(
                        AppIcons.location,
                        size: AppSizes.iconSm,
                        color: context.palette.textMuted,
                      ),
                      AppSpacing.gapXs,
                      Flexible(
                        child: Text(
                          [
                            if (profile.distanceKm != null)
                              '${profile.distanceKm} km away',
                            profile.city,
                          ].join(' · '),
                          style: context.text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (profile.occupation != null) ...[
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Icon(
                          AppIcons.work,
                          size: AppSizes.iconSm,
                          color: context.palette.textMuted,
                        ),
                        AppSpacing.gapXs,
                        Flexible(
                          child: Text(
                            profile.occupation!,
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (profile.bio.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text(profile.bio, style: context.text.bodyMedium),
        ],
        if (profile.interests.isNotEmpty) ...[
          AppSpacing.gapLg,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final i in profile.interests) InterestChip(label: i),
            ],
          ),
        ],
        AppSpacing.gapXl,
        AppButton(
          label: 'Report ${profile.displayName}',
          variant: AppButtonVariant.secondary,
          icon: AppIcons.report,
          onPressed: () {
            Navigator.of(context).pop();
            context.push(
              AppRoutes.reportUser(
                name: profile.displayName,
                accountId: profile.id,
              ),
            );
          },
        ),
        AppSpacing.gapSm,
        AppButton(
          label: 'Close',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
