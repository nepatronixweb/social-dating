import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/match_card.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../discovery/presentation/profile_detail_screen.dart';
import '../providers/matches_providers.dart';
import 'match_dialogs.dart';

/// A match: the person's full profile, a clear "Send a message" action, and
/// the safety actions (report, unmatch, block) kept below the profile.
class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  bool _busy = false;
  String _busyLabel = '';
  String? _error;
  bool _leaving = false;
  bool _markedSeen = false;
  Match? _lastMatch;

  Match? _find(List<Match> list) =>
      list.where((m) => m.id == widget.matchId).firstOrNull;

  void _markSeenOnce(Match match) {
    if (_markedSeen || !match.isNew) return;
    _markedSeen = true;
    final repository = ref.read(matchingRepositoryProvider);
    final revision = ref.read(matchingRevisionProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await repository.markMatchSeen(match.id);
        revision.bump();
      } catch (_) {
        // Not being marked as seen is harmless; the "New" label stays.
      }
    });
  }

  Future<void> _perform({
    required String busyLabel,
    required Future<void> Function() action,
    required String doneMessage,
  }) async {
    final revision = ref.read(matchingRevisionProvider.notifier);
    setState(() {
      _busy = true;
      _busyLabel = busyLabel;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppFailure.from(error).message;
      });
      return;
    }
    if (!mounted) {
      revision.bump();
      return;
    }
    // Keep showing the person while the screen animates away.
    _leaving = true;
    showAppSnackBar(context, doneMessage, type: AppSnackType.success);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.matches);
    }
    revision.bump();
  }

  Future<void> _unmatch(Match match) async {
    if (!await confirmUnmatch(context, match.profile) || !mounted) return;
    final name = match.profile.displayName.split(' ').first;
    await _perform(
      busyLabel: 'Unmatching...',
      action: () => ref.read(matchingRepositoryProvider).unmatch(match.id),
      doneMessage: 'You unmatched $name.',
    );
  }

  Future<void> _block(Match match) async {
    if (!await confirmBlock(context, match.profile) || !mounted) return;
    final name = match.profile.displayName.split(' ').first;
    await _perform(
      busyLabel: 'Blocking...',
      action: () =>
          ref.read(matchingRepositoryProvider).block(match.profile.id),
      doneMessage: '$name is blocked.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(matchesProvider);
    final now = ref.watch(clockProvider)();
    var match = matches.value == null ? null : _find(matches.requireValue);
    if (match != null) _lastMatch = match;
    if (match == null && _leaving) match = _lastMatch;
    if (match != null) _markSeenOnce(match);
    final current = match;

    return AppPage(
      appBar: AppTopBar(
        title: current?.profile.displayName ?? 'Match',
        actions: [
          IconButton(
            tooltip: 'Safety center',
            icon: const Icon(AppIcons.safety),
            onPressed: () => context.push(AppRoutes.safety),
          ),
        ],
      ),
      bottomBar: current == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
                vertical: AppSpacing.md,
              ),
              child: AppButton(
                label: 'Send a message',
                icon: AppIcons.chat,
                onPressed: _busy
                    ? null
                    : () => context.push(
                        AppRoutes.chatConversation(current.chatId),
                      ),
              ),
            ),
      body: AsyncValueView<List<Match>>(
        value: matches,
        keepDataWhileReloading: true,
        loading: const SkeletonList(itemCount: 3),
        onRetry: () => ref.invalidate(matchesProvider),
        data: (list) {
          if (current == null) {
            return EmptyState(
              icon: AppIcons.matches,
              title: 'This match is no longer available',
              message:
                  'They may have been unmatched or blocked. Your other matches '
                  'are still here.',
              actionLabel: 'Back to matches',
              onAction: () => context.go(AppRoutes.matches),
            );
          }
          return Column(
            children: [
              if (_busy) ...[
                const LinearProgressIndicator(),
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      _busyLabel,
                      style: context.text.bodySmall?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    AppSpacing.sm,
                    AppSpacing.pageGutter,
                    0,
                  ),
                  child: InlineMessage(
                    tone: InlineMessageTone.error,
                    title: 'That did not work',
                    message: _error!,
                    bringIntoView: true,
                  ),
                ),
              Expanded(
                child: ProfileDetailBody(
                  profile: current.profile,
                  intro: _MatchMeta(match: current, now: now),
                  footer: _ManageSection(
                    enabled: !_busy,
                    onReport: () => context.push(
                      AppRoutes.reportUser(
                        name: current.profile.displayName,
                        accountId: current.profile.id,
                      ),
                    ),
                    onUnmatch: () => _unmatch(current),
                    onBlock: () => _block(current),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MatchMeta extends StatelessWidget {
  const _MatchMeta({required this.match, required this.now});

  final Match match;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final activity = activityLabel(match.lastActiveAt, now: now);
    final active = match.isActiveNow(now);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          MatchCard.matchedLabel(match.matchedAt, now: now),
          style: context.text.bodyMedium?.copyWith(color: palette.textMuted),
        ),
        if (activity != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.success,
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpacing.gapXs,
              ],
              Flexible(
                child: Text(
                  activity,
                  style: context.text.bodyMedium?.copyWith(
                    color: active ? palette.success : palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Safety and match management, below the profile so it is easy to find
/// without competing with the main "Send a message" action.
class _ManageSection extends StatelessWidget {
  const _ManageSection({
    required this.enabled,
    required this.onReport,
    required this.onUnmatch,
    required this.onBlock,
  });

  final bool enabled;
  final VoidCallback onReport;
  final VoidCallback onUnmatch;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Manage this match', style: context.text.titleMedium),
        ),
        AppSpacing.gapSm,
        MenuTile(
          icon: AppIcons.report,
          title: 'Report or get help',
          onTap: enabled ? onReport : null,
        ),
        MenuTile(
          icon: AppIcons.close,
          title: 'Unmatch',
          subtitle: 'End this match and close the chat',
          destructive: true,
          onTap: enabled ? onUnmatch : null,
        ),
        MenuTile(
          icon: AppIcons.block,
          title: 'Block',
          subtitle: 'Remove them from everything and hide you both',
          destructive: true,
          onTap: enabled ? onBlock : null,
        ),
      ],
    );
  }
}
