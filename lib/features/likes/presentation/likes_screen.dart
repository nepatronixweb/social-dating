import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_sizes.dart';
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
import '../../../core/widgets/person_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/matching.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../../discovery/presentation/widgets/match_celebration_dialog.dart';
import '../../matches/providers/matches_providers.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../profile/presentation/profile_preview_sheet.dart';
import '../../subscription/providers/subscription_providers.dart';

enum _LikesTab { received, sent }

/// Likes tab: people who liked you (respond to them) and the likes you sent
/// (withdraw them). A mutual like becomes exactly one match.
class LikesScreen extends ConsumerStatefulWidget {
  const LikesScreen({super.key});

  @override
  ConsumerState<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends ConsumerState<LikesScreen> {
  _LikesTab _tab = _LikesTab.received;

  /// Profiles with a change in flight, so their buttons show progress and
  /// cannot be pressed twice.
  final Set<String> _busy = {};

  Future<void> _run(String profileId, Future<void> Function() action) async {
    if (_busy.contains(profileId)) return;
    final revision = ref.read(matchingRevisionProvider.notifier);
    setState(() => _busy.add(profileId));
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy.remove(profileId));
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
      // The list is out of date when the like is gone.
      if (AppFailure.from(error) is NotFoundFailure) revision.bump();
      return;
    }
    if (mounted) setState(() => _busy.remove(profileId));
  }

  Future<void> _likeBack(ReceivedLike like) async {
    final revision = ref.read(matchingRevisionProvider.notifier);
    LikeOutcome? outcome;
    await _run(like.profile.id, () async {
      outcome = await ref
          .read(matchingRepositoryProvider)
          .likeBack(like.profile.id);
      revision.bump();
    });
    final result = outcome;
    if (!mounted || result == null) return;
    final match = result.match;
    if (match == null) return;
    if (!result.created) {
      showAppSnackBar(
        context,
        'You are already matched with ${match.profile.displayName}.',
      );
      return;
    }
    final action = await showMatchCelebration(
      context,
      profile: match.profile,
      canViewMatches: true,
      keepLabel: 'Maybe later',
      allowMessage: true,
    );
    if (!mounted) return;
    switch (action) {
      case MatchCelebrationAction.sayHello:
        context.push(AppRoutes.chatConversation(match.chatId));
      case MatchCelebrationAction.viewMatches:
        context.go(AppRoutes.matches);
      case MatchCelebrationAction.keepSwiping:
        break;
    }
  }

  Future<void> _decline(ReceivedLike like) async {
    final revision = ref.read(matchingRevisionProvider.notifier);
    await _run(like.profile.id, () async {
      await ref.read(matchingRepositoryProvider).declineLike(like.profile.id);
      revision.bump();
    });
  }

  Future<void> _withdraw(SentLike like) async {
    final revision = ref.read(matchingRevisionProvider.notifier);
    await _run(like.profile.id, () async {
      await ref.read(matchingRepositoryProvider).withdrawLike(like.profile.id);
      revision.bump();
    });
    if (mounted) {
      showAppSnackBar(context, 'Like withdrawn.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: const AppTopBar(showBrand: true, actions: [NotificationBell()]),
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Likes',
            subtitle: 'Who likes you, and who you liked',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              0,
              AppSpacing.pageGutter,
              AppSpacing.lg,
            ),
            child: SegmentedButton<_LikesTab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _LikesTab.received,
                  label: Text('Received'),
                ),
                ButtonSegment(value: _LikesTab.sent, label: Text('Sent')),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: switch (_tab) {
              _LikesTab.received => _ReceivedView(
                busy: _busy,
                onLikeBack: _likeBack,
                onDecline: _decline,
              ),
              _LikesTab.sent => _SentView(busy: _busy, onWithdraw: _withdraw),
            },
          ),
        ],
      ),
    );
  }
}

class _ReceivedView extends ConsumerWidget {
  const _ReceivedView({
    required this.busy,
    required this.onLikeBack,
    required this.onDecline,
  });

  final Set<String> busy;
  final ValueChanged<ReceivedLike> onLikeBack;
  final ValueChanged<ReceivedLike> onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(likesReceivedProvider);
    final now = ref.watch(clockProvider)();
    final needsPaywall =
        (ref.watch(sessionProvider).gender ?? ProfileGender.male)
            .needsPaidSubscription &&
        ref.watch(activeSubscriptionProvider).value == null;

    return AsyncValueView<List<ReceivedLike>>(
      value: likes,
      keepDataWhileReloading: true,
      loading: const SkeletonList(),
      onRetry: () => ref.invalidate(likesReceivedProvider),
      isEmpty: (list) => list.isEmpty,
      empty: EmptyState(
        icon: AppIcons.heartOutline,
        title: 'No likes yet',
        message: 'Keep your profile fresh and they will come.',
        actionLabel: 'Go to Discover',
        onAction: () => context.go(AppRoutes.discover),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(likesReceivedProvider);
          try {
            await ref.read(likesReceivedProvider.future);
          } catch (_) {
            // The error state renders itself.
          }
        },
        child: ListView(
          padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xl),
          children: [
            if (needsPaywall) ...[
              _PremiumBanner(onTap: () => context.push(AppRoutes.subscription)),
              AppSpacing.gapLg,
            ],
            for (final like in list) ...[
              PersonCard(
                key: ValueKey('received-${like.profile.id}'),
                profile: like.profile,
                timestamp: timestampLabel('Liked you', like.likedAt, now: now),
                onTap: () => showProfilePreviewSheet(context, like.profile),
                actions: _Actions(
                  primary: AppButton(
                    label: 'Like back',
                    icon: AppIcons.heart,
                    isLoading: busy.contains(like.profile.id),
                    onPressed: busy.contains(like.profile.id)
                        ? null
                        : () => onLikeBack(like),
                  ),
                  secondary: AppButton(
                    label: 'Not now',
                    variant: AppButtonVariant.secondary,
                    onPressed: busy.contains(like.profile.id)
                        ? null
                        : () => onDecline(like),
                  ),
                ),
              ),
              AppSpacing.gapMd,
            ],
          ],
        ),
      ),
    );
  }
}

class _SentView extends ConsumerWidget {
  const _SentView({required this.busy, required this.onWithdraw});

  final Set<String> busy;
  final ValueChanged<SentLike> onWithdraw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(likesSentProvider);
    final now = ref.watch(clockProvider)();

    return AsyncValueView<List<SentLike>>(
      value: likes,
      keepDataWhileReloading: true,
      loading: const SkeletonList(),
      onRetry: () => ref.invalidate(likesSentProvider),
      isEmpty: (list) => list.isEmpty,
      empty: EmptyState(
        icon: AppIcons.heartOutline,
        title: 'No likes sent',
        message:
            'Like someone in Discover and they will wait here until they '
            'respond.',
        actionLabel: 'Go to Discover',
        onAction: () => context.go(AppRoutes.discover),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(likesSentProvider);
          try {
            await ref.read(likesSentProvider.future);
          } catch (_) {
            // The error state renders itself.
          }
        },
        child: ListView(
          padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xl),
          children: [
            for (final like in list) ...[
              PersonCard(
                key: ValueKey('sent-${like.profile.id}'),
                profile: like.profile,
                timestamp: timestampLabel('You liked', like.likedAt, now: now),
                status: 'Waiting for a reply',
                onTap: () => showProfilePreviewSheet(context, like.profile),
                actions: _Actions(
                  primary: AppButton(
                    label: 'Withdraw like',
                    variant: AppButtonVariant.secondary,
                    isLoading: busy.contains(like.profile.id),
                    onPressed: busy.contains(like.profile.id)
                        ? null
                        : () => onWithdraw(like),
                  ),
                ),
              ),
              AppSpacing.gapMd,
            ],
          ],
        ),
      ),
    );
  }
}

/// One or two buttons: side by side when there is room, stacked otherwise.
class _Actions extends StatelessWidget {
  const _Actions({required this.primary, this.secondary});

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final other = secondary;
    if (other == null) return primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 280 || textScale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, AppSpacing.gapSm, other],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: primary),
            AppSpacing.gapSm,
            Expanded(flex: 2, child: other),
          ],
        );
      },
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'See everyone who likes you with Premium',
      onTap: onTap,
      child: Material(
        color: colors.primaryContainer,
        borderRadius: AppRadii.borderLg,
        child: InkWell(
          borderRadius: AppRadii.borderLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  AppIcons.premium,
                  color: colors.onPrimaryContainer,
                  size: AppSizes.iconXl,
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'See everyone who likes you',
                        style: context.text.titleMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'Explore Premium',
                        style: context.text.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight, color: colors.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
