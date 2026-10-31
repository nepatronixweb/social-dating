import 'package:flutter/material.dart';

import '../../../../core/constants/swipe_rules.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/state_message.dart';

/// Replaces the deck once the preview swipes are used and the profile is
/// still incomplete.
class ProfileGateView extends StatelessWidget {
  const ProfileGateView({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: AppIcons.profile,
      title: 'Finish your profile to keep swiping',
      message:
          'You have used your ${SwipeRules.previewSwipes} preview swipes. '
          'Complete your profile to continue. It only takes a minute.',
      actionLabel: 'Complete profile',
      onAction: onComplete,
    );
  }
}
