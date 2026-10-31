import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Slim banner shown while the app is offline. Collapses to nothing (with a
/// size animation) when [visible] is false. Announced politely to screen
/// readers when it appears.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible, this.onRetry});

  final bool visible;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.resolve(context, AppMotion.normal),
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: visible
          ? Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                width: double.infinity,
                color: context.palette.warning.withValues(alpha: 0.16),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.wifiOff,
                      size: AppSizes.iconMd,
                      color: context.colors.onSurface,
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Text(
                        'You\'re offline. Some things may not load.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                    if (onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
