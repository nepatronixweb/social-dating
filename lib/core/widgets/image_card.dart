import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'photo_placeholder.dart';

/// Portrait photo card with a bottom scrim and title/subtitle overlay. When no
/// [image] is supplied a [PhotoPlaceholder] (derived from [placeholderSeed]) is
/// drawn, so the widget never needs a network image.
class ImageCard extends StatelessWidget {
  const ImageCard({
    super.key,
    required this.title,
    this.subtitle,
    this.image,
    this.badge,
    this.aspectRatio = 3 / 4,
    this.onTap,
    this.placeholderSeed = 0,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final ImageProvider? image;
  final Widget? badge;
  final double aspectRatio;
  final VoidCallback? onTap;
  final int placeholderSeed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? (subtitle == null ? title : '$title, $subtitle'),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.borderLg,
          boxShadow: AppElevation.medium(context.theme.brightness),
        ),
        child: ClipRRect(
          borderRadius: AppRadii.borderLg,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoPlaceholder(seed: placeholderSeed),
                    if (image != null)
                      Image(
                        image: image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, palette.imageScrim],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.xxxl,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleLarge?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: AppSpacing.md,
                        left: AppSpacing.md,
                        child: badge!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
