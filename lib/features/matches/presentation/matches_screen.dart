import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/match_card.dart';
import '../../../core/widgets/person_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/match.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../providers/matches_providers.dart';

/// Matches tab: new matches in a horizontal strip, everyone else in a list.
/// Each person appears once. Match preferences and history are one tap away.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: AppTopBar(
        showBrand: true,
        actions: [
          IconButton(
            tooltip: 'Match history',
            icon: const Icon(AppIcons.history),
            onPressed: () => context.push(AppRoutes.matchHistory),
          ),
          IconButton(
            tooltip: 'Match preferences',
            icon: const Icon(AppIcons.filter),
            onPressed: () => context.push(AppRoutes.matchPreferences),
          ),
          const NotificationBell(),
        ],
      ),
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Matches',
            subtitle: 'People you\'ve connected with',
          ),
          Expanded(
            child: AsyncValueView<List<Match>>(
              value: matches,
              keepDataWhileReloading: true,
              loading: const SkeletonList(),
              onRetry: () => ref.invalidate(matchesProvider),
              isEmpty: (list) => list.isEmpty,
              empty: EmptyState(
                icon: AppIcons.matches,
                title: 'No matches yet',
                message:
                    'When you and someone like each other, they show up '
                    'here.',
                actionLabel: 'See who likes you',
                onAction: () => context.go(AppRoutes.likes),
              ),
              data: (list) => _MatchList(matches: list, now: now),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({required this.matches, required this.now});

  final List<Match> matches;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final fresh = matches.where((m) => m.isNew).toList();
    final earlier = matches.where((m) => !m.isNew).toList();

    // Larger text needs larger cards, otherwise the name and status lines
    // would not fit over the photo.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final cardWidth = 156 * scale;
    final stripHeight = cardWidth / AppSizes.photoAspectRatio + AppSpacing.xl;

    void open(Match match) => context.push(AppRoutes.matchDetail(match.id));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        if (fresh.isNotEmpty)
          AppSection(
            title: 'New matches',
            padded: false,
            child: SizedBox(
              height: stripHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageGutter,
                  vertical: AppSpacing.sm,
                ),
                itemCount: fresh.length,
                separatorBuilder: (_, _) => AppSpacing.gapMd,
                itemBuilder: (context, i) => SizedBox(
                  width: cardWidth,
                  child: MatchCard(
                    key: ValueKey('match-card-${fresh[i].id}'),
                    match: fresh[i],
                    now: now,
                    activity: activityLabel(fresh[i].lastActiveAt, now: now),
                    placeholderSeed: fresh[i].profile.photoSeed,
                    onTap: () => open(fresh[i]),
                  ),
                ),
              ),
            ),
          ),
        if (earlier.isNotEmpty)
          AppSection(
            title: fresh.isEmpty ? 'Your matches' : 'Earlier',
            child: Column(
              children: [
                for (final match in earlier) ...[
                  PersonCard(
                    key: ValueKey('match-card-${match.id}'),
                    profile: match.profile,
                    timestamp: MatchCard.matchedLabel(
                      match.matchedAt,
                      now: now,
                    ),
                    status: activityLabel(match.lastActiveAt, now: now),
                    statusIsActive: match.isActiveNow(now),
                    trailing: const Icon(AppIcons.chevronRight),
                    onTap: () => open(match),
                  ),
                  AppSpacing.gapMd,
                ],
              ],
            ),
          ),
        if (fresh.isNotEmpty && earlier.isEmpty)
          const Padding(
            padding: AppSpacing.pagePadding,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppPill(label: 'Tap a match to say hello'),
            ),
          ),
      ],
    );
  }
}
