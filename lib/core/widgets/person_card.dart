import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'profile_thumbnail.dart';

/// The standard list card for a person in likes, matches and history:
/// thumbnail, name and age, a timestamp line, an optional status line and
/// optional actions underneath. Tapping the card opens the person.
///
/// Every line is capped, so large text and narrow phones wrap or truncate
/// instead of overflowing.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.profile,
    required this.timestamp,
    this.status,
    this.statusIsActive = false,
    this.badges = const [],
    this.actions,
    this.trailing,
    this.onTap,
    this.dimmed = false,
    this.semanticLabel,
  });

  final Profile profile;

  /// For example "Liked 25m ago".
  final String timestamp;

  /// Optional second muted line, for example "Active now".
  final String? status;
  final bool statusIsActive;

  /// Small pills shown beside the name (for example "New").
  final List<Widget> badges;

  /// Buttons shown below the details, inside the card.
  final Widget? actions;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${profile.displayName}, ${profile.age}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        if (badges.isNotEmpty) ...[
          AppSpacing.gapXs,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: badges,
          ),
        ],
        AppSpacing.gapXs,
        Text(
          timestamp,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: palette.textMuted),
        ),
        if (status != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (statusIsActive) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.success,
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpacing.gapXs,
              ],
              Flexible(
                child: Text(
                  status!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: statusIsActive ? palette.success : palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
      ],
    );

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ProfileThumbnail(profile: profile, dimmed: dimmed),
        AppSpacing.gapMd,
        Expanded(child: details),
        if (trailing != null) ...[AppSpacing.gapSm, trailing!],
      ],
    );

    return Semantics(
      container: true,
      label:
          semanticLabel ??
          [
            '${profile.displayName}, ${profile.age}',
            timestamp,
            ?status,
          ].join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.borderLg,
          border: Border.all(color: palette.outlineSoft),
          boxShadow: AppElevation.low(context.theme.brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: AppRadii.borderLg,
              child: InkWell(
                borderRadius: AppRadii.borderLg,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: header,
                ),
              ),
            ),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: actions,
              ),
          ],
        ),
      ),
    );
  }
}
