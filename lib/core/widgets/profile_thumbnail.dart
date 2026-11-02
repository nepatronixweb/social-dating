import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/models/profile.dart';
import '../utils/media_url.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../utils/theme_context.dart';
import 'photo_placeholder.dart';

/// Square, rounded profile photo used in list-style cards (likes, matches,
/// history). Shows a small "online" dot and a verified mark when relevant.
/// Falls back to the placeholder wash when there is no [image].
class ProfileThumbnail extends StatelessWidget {
  const ProfileThumbnail({
    super.key,
    required this.profile,
    this.size = 72,
    this.showOnline = true,
    this.dimmed = false,
    this.blurred = false,
  });

  final Profile profile;
  final double size;

  /// Draws the "online" dot (when the person is online).
  final bool showOnline;

  /// Faded look for people who are no longer connected (history).
  final bool dimmed;

  /// Heavy blur for Premium-gated likes (identity hidden until subscribed).
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = size * 0.22;
    final image =
        profileImageProvider(profile.photos.firstOrNull) == null
        ? PhotoPlaceholder(seed: profile.photoSeed)
        : Image(
            image: profileImageProvider(profile.photos.first)!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                PhotoPlaceholder(seed: profile.photoSeed),
          );

    Widget photo = ClipRRect(
      borderRadius: AppRadii.borderMd,
      child: blurred
          ? ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: image,
            )
          : image,
    );

    if (dimmed) {
      photo = Opacity(opacity: 0.5, child: photo);
    }

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: photo),
            if (showOnline && profile.isOnline && !dimmed && !blurred)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: context.palette.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            if (profile.isVerified && !dimmed && !blurred)
              Positioned(
                left: -4,
                top: -4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.verified,
                    size: size * 0.28,
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
