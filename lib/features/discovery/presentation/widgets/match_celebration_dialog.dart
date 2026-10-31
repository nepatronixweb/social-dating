import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../data/models/profile.dart';

enum MatchCelebrationAction { keepSwiping, viewMatches, sayHello }

/// "It's a match" celebration. [canViewMatches] is false while the person is
/// still completing their profile, because the matches area is not open yet.
Future<MatchCelebrationAction> showMatchCelebration(
  BuildContext context, {
  required Profile profile,
  required bool canViewMatches,
  String keepLabel = 'Keep swiping',
  bool allowMessage = false,
}) async {
  final result = await showDialog<MatchCelebrationAction>(
    context: context,
    builder: (dialogContext) => MatchCelebrationDialog(
      profile: profile,
      canViewMatches: canViewMatches,
      keepLabel: keepLabel,
      allowMessage: allowMessage,
    ),
  );
  return result ?? MatchCelebrationAction.keepSwiping;
}

class MatchCelebrationDialog extends StatelessWidget {
  const MatchCelebrationDialog({
    super.key,
    required this.profile,
    required this.canViewMatches,
    this.keepLabel = 'Keep swiping',
    this.allowMessage = false,
  });

  final Profile profile;
  final bool canViewMatches;
  final String keepLabel;

  /// Offers a direct 'Say hello' action that opens the conversation.
  final bool allowMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final name = profile.displayName.split(' ').first;
    final duration = AppMotion.resolve(context, AppMotion.slow);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1),
        duration: duration,
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Opacity(
          opacity: ((scale - 0.85) / 0.15).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.borderXl,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ProfileAvatar(
                          name: 'You',
                          size: AppSizes.avatarLg,
                          showRing: true,
                        ),
                        Transform.translate(
                          offset: const Offset(-AppSpacing.md, 0),
                          child: ProfileAvatar(
                            name: profile.displayName,
                            size: AppSizes.avatarLg,
                            showRing: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      'It\'s a match!',
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'You and $name liked each other.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge,
                  ),
                  AppSpacing.gapSm,
                  Text(
                    canViewMatches
                        ? 'Say hello while the moment is fresh.'
                        : 'Finish your profile to start chatting.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  AppSpacing.gapXl,
                  if (canViewMatches && allowMessage) ...[
                    AppButton(
                      label: 'Say hello',
                      icon: AppIcons.chat,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(MatchCelebrationAction.sayHello),
                    ),
                    AppSpacing.gapSm,
                  ],
                  if (canViewMatches) ...[
                    AppButton(
                      label: 'See your matches',
                      variant: allowMessage
                          ? AppButtonVariant.secondary
                          : AppButtonVariant.primary,
                      icon: AppIcons.matches,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(MatchCelebrationAction.viewMatches),
                    ),
                    AppSpacing.gapSm,
                  ],
                  AppButton(
                    label: keepLabel,
                    variant: canViewMatches
                        ? AppButtonVariant.text
                        : AppButtonVariant.primary,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(MatchCelebrationAction.keepSwiping),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
