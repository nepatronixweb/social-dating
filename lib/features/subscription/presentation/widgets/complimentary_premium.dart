import 'package:flutter/material.dart';

import '../../../../core/constants/subscription_rules.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/models/profile.dart';
import '../../../auth/providers/session_provider.dart';

bool sessionHasComplimentaryPremium(AuthSession session) =>
    (session.gender ?? ProfileGender.male).hasComplimentaryPremium;

class ComplimentaryPremiumNotice extends StatelessWidget {
  const ComplimentaryPremiumNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: AppIcons.premium,
      title: SubscriptionRules.complimentaryHeadline,
      message: SubscriptionRules.complimentaryBody,
    );
  }
}
