import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/referral_info.dart';
import '../providers/referrals_providers.dart';
import '../referral_copy.dart';

class ReferralHistoryScreen extends ConsumerWidget {
  const ReferralHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(referralInvitesProvider);
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Referral history'),
      body: AsyncValueView<List<ReferralInvite>>(
        value: invites,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(referralInvitesProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.referral,
          title: 'No invites yet',
          message:
              'Friends appear here after they create an account with your code.',
        ),
        data: (list) => ListView(
          children: [
            const ScreenHeader(
              title: 'People who used your code',
              subtitle:
                  'A purchase is shown only after a qualifying payment is confirmed.',
            ),
            AppSpacing.gapMd,
            for (final item in list)
              ListTile(
                isThreeLine: true,
                contentPadding: AppSpacing.pagePadding,
                leading: Icon(AppIcons.referral, color: context.colors.primary),
                title: Text(item.displayName),
                subtitle: Text(
                  '${inviteStatusLabel(item.status)} · '
                  '${relativeTime(item.createdAt, now: now)}\n'
                  '${item.detail}',
                  maxLines: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
