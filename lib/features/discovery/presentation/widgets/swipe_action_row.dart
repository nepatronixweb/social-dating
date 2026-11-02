import 'package:flutter/material.dart';

import '../../../../core/theme/photo_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/circle_action_button.dart';

/// The five discovery actions over the card: undo, pass, super like, like and
/// message. Pass and like run exactly the same flow as dragging, so the gesture
/// is never required.
///
/// Undo is always visible so its place is stable, but it is disabled unless
/// [onUndo] is provided (the local flag is on and there is something to undo).
/// Super like and message charge premium points for unsubscribed males.
class SwipeActionRow extends StatelessWidget {
  const SwipeActionRow({
    super.key,
    required this.passLabel,
    required this.likeLabel,
    required this.onPass,
    required this.onLike,
    required this.onUndo,
    required this.undoLabel,
    required this.superLikeLabel,
    required this.messageLabel,
    required this.onSuperLike,
    required this.onMessage,
  });

  final String passLabel;
  final String likeLabel;
  final VoidCallback? onPass;
  final VoidCallback? onLike;
  final VoidCallback? onUndo;
  final String undoLabel;
  final String superLikeLabel;
  final String messageLabel;
  final VoidCallback? onSuperLike;
  final VoidCallback? onMessage;

  static const double _small = 46;
  static const double _large = 62;
  static const double _hero = 72;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: AppSpacing.md + 2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      // Narrow phones shrink the row as a whole instead of overflowing.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleActionButton(
              icon: AppIcons.undo,
              label: undoLabel,
              size: _small,
              glass: true,
              onPressed: onUndo,
            ),
            gap,
            CircleActionButton(
              icon: AppIcons.pass,
              label: passLabel,
              size: _large,
              glass: true,
              onPressed: onPass,
            ),
            gap,
            CircleActionButton(
              icon: AppIcons.star,
              label: superLikeLabel,
              size: _small,
              glass: true,
              iconColor: PhotoTokens.actionBlue,
              onPressed: onSuperLike,
            ),
            gap,
            CircleActionButton(
              icon: AppIcons.heart,
              label: likeLabel,
              emphasized: true,
              glow: true,
              size: _hero,
              onPressed: onLike,
            ),
            gap,
            CircleActionButton(
              icon: AppIcons.send,
              label: messageLabel,
              size: _small,
              glass: true,
              iconColor: PhotoTokens.actionBlue,
              onPressed: onMessage,
            ),
          ],
        ),
      ),
    );
  }
}
