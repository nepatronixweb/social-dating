import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/person_card.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/matching.dart';
import '../providers/matches_providers.dart';

/// Everything that happened with matches: new matches, unmatches and blocks,
/// newest first. Mock data only.
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  static String kindLabel(MatchHistoryKind kind) => switch (kind) {
    MatchHistoryKind.matched => 'Matched',
    MatchHistoryKind.unmatched => 'Unmatched',
    MatchHistoryKind.blocked => 'Blocked',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider);
    final now = ref.watch(clockProvider)();

    return AppPage(
      appBar: const AppTopBar(title: 'Match history'),
      body: AsyncValueView<List<MatchHistoryEntry>>(
        value: history,
        keepDataWhileReloading: true,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(matchHistoryProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.history,
          title: 'No history yet',
          message: 'New matches, unmatches and blocks will be listed here.',
        ),
        data: (list) => ListView(
          padding: AppSpacing.pagePadding.copyWith(
            top: AppSpacing.sm,
            bottom: AppSpacing.xl,
          ),
          children: [
            const InlineMessage(
              message:
                  'Sample history for this preview. It is kept on this device '
                  'only and resets when the app restarts.',
            ),
            AppSpacing.gapLg,
            for (final entry in list) ...[
              PersonCard(
                key: ValueKey('history-${entry.id}'),
                profile: entry.profile,
                timestamp: timestampLabel(
                  kindLabel(entry.kind),
                  entry.at,
                  now: now,
                ),
                dimmed: entry.kind != MatchHistoryKind.matched,
                badges: [
                  AppPill(
                    label: kindLabel(entry.kind),
                    tone: entry.kind == MatchHistoryKind.matched
                        ? AppPillTone.brand
                        : AppPillTone.neutral,
                  ),
                ],
              ),
              AppSpacing.gapMd,
            ],
          ],
        ),
      ),
    );
  }
}
