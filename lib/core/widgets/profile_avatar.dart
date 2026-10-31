import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../utils/theme_context.dart';

/// Circular avatar. Falls back to initials on a tinted background when there
/// is no [image] (or while it fails to load).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.image,
    this.size = 56,
    this.showRing = false,
    this.isOnline = false,
    this.isVerified = false,
  });

  final String name;
  final ImageProvider? image;
  final double size;

  /// Gradient ring, e.g. for new matches or premium members.
  final bool showRing;
  final bool isOnline;
  final bool isVerified;

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ringWidth = showRing ? 3.0 : 0.0;
    final gap = showRing ? 2.0 : 0.0;
    final inner = size - 2 * (ringWidth + gap);

    final initials = Center(
      child: Text(
        initialsOf(name),
        style: context.text.titleMedium?.copyWith(
          fontSize: inner * 0.36,
          color: colors.onPrimaryContainer,
        ),
      ),
    );

    Widget face = ClipOval(
      child: SizedBox.square(
        dimension: inner,
        child: ColoredBox(
          color: colors.primaryContainer,
          child: image == null
              ? initials
              : Image(
                  image: image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initials,
                ),
        ),
      ),
    );

    if (showRing) {
      face = Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(ringWidth + gap),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: context.palette.brandGradient,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.surface, width: gap),
          ),
          child: face,
        ),
      );
    }

    final badge = size * 0.28;

    return Semantics(
      label: [
        name,
        if (isVerified) 'verified',
        if (isOnline) 'online',
      ].join(', '),
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              face,
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: badge,
                    height: badge,
                    decoration: BoxDecoration(
                      color: context.palette.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                  ),
                ),
              if (isVerified)
                Positioned(
                  right: -badge * 0.1,
                  top: -badge * 0.1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.verified,
                      size: badge * 1.1,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
