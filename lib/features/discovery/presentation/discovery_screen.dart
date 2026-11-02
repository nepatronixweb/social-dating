import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/profile_card.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../core/widgets/state_message.dart';
import '../../../core/widgets/swipe_card.dart';
import '../../../data/models/discovery_filters.dart';
import '../../../data/models/match.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/swipe.dart';
import '../../auth/providers/session_provider.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../providers/discovery_providers.dart';
import 'widgets/discovery_header.dart';
import 'widgets/filters_sheet.dart';
import 'widgets/insufficient_balance_sheet.dart';
import 'widgets/match_celebration_dialog.dart';
import 'widgets/paid_swipe_dialog.dart';
import 'widgets/profile_gate_view.dart';
import 'widgets/swipe_action_row.dart';

/// Discovery tab: one large profile card at a time. Swipe it, or use the
/// pass and like buttons. Swipe counting and pricing are mock behaviour (see
/// `SwipeRules`); the server must be authoritative later.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final Map<String, GlobalKey<SwipeCardState>> _cardKeys = {};

  /// Set when the person confirmed the price for the swipe in progress.
  bool _paidConfirmed = false;
  bool _showingMatch = false;

  static const DiscoveryCategory _category = DiscoveryCategory.forYou;

  /// The photo showing on the top card, for the dots in the header. Tied to a
  /// profile id so a new card starts at its first photo.
  String? _photoProfileId;
  int _photoIndex = 0;

  GlobalKey<SwipeCardState> _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, GlobalKey<SwipeCardState>.new);

  DiscoveryController get _controller =>
      ref.read(discoveryControllerProvider.notifier);

  /// Runs before a card leaves: applies the profile gate, the limit and the
  /// price confirmation. Returns whether the swipe may go ahead.
  Future<bool> _willSwipe(SwipeDirection direction) async {
    _paidConfirmed = false;
    final gate = await _controller.checkSwipe();
    if (!mounted) return false;
    final quota = ref.read(discoveryControllerProvider).quota;

    switch (gate.kind) {
      case SwipeGateKind.allowed:
        return true;
      case SwipeGateKind.confirmPayment:
        if (quota == null) return false;
        final confirmed = await showPaidSwipeDialog(
          context,
          costPaisa: gate.costPaisa,
          balancePaisa: quota.balancePaisa,
          freeLimit: quota.freeDailyLimit ?? 0,
        );
        _paidConfirmed = confirmed;
        return confirmed;
      case SwipeGateKind.insufficientBalance:
        if (quota == null) return false;
        final action = await showInsufficientBalanceSheet(
          context,
          quota: quota,
          now: ref.read(clockProvider)(),
        );
        if (action == InsufficientBalanceAction.openWallet && mounted) {
          await context.push(AppRoutes.wallet);
        }
        return false;
      case SwipeGateKind.profileRequired:
      case SwipeGateKind.unavailable:
        return false;
    }
  }

  void _onSwiped(SwipeDirection direction) {
    final paid = _paidConfirmed;
    _paidConfirmed = false;
    HapticFeedback.lightImpact();
    _controller.commit(direction, confirmedPaid: paid);
  }

  Future<void> _openDetail(Profile profile) async {
    final direction = await context.push<SwipeDirection>(
      AppRoutes.discoverProfile(profile.id),
      extra: profile,
    );
    if (!mounted || direction == null) return;
    if (ref.read(discoveryControllerProvider).top?.id != profile.id) return;
    await _cardKeys[profile.id]?.currentState?.swipe(direction);
  }

  void _onPhotoChanged(String profileId, int page) => setState(() {
    _photoProfileId = profileId;
    _photoIndex = page;
  });

  /// Ensures the wallet can cover a premium action. No confirmation sheet —
  /// points are deducted when the action is sent.
  Future<bool> _ensurePremiumFunds() async {
    final quota = ref.read(discoveryControllerProvider).quota;
    if (quota == null) return false;
    final cost = _controller.premiumActionCostPaisa;
    if (!_controller.mustPayPremiumActions) return true;
    if (quota.balancePaisa >= cost) return true;
    final action = await showInsufficientBalanceSheet(
      context,
      quota: quota,
      now: ref.read(clockProvider)(),
    );
    if (action == InsufficientBalanceAction.openWallet && mounted) {
      await context.push(AppRoutes.wallet);
    }
    return false;
  }

  Future<void> _onSuperLike() async {
    final top = ref.read(discoveryControllerProvider).top;
    if (top == null) return;
    if (!await _ensurePremiumFunds() || !mounted) return;
    final rejection = await _controller.superLike(confirmedPaid: true);
    if (!mounted) return;
    if (rejection == SwipeRejection.insufficientFunds) {
      final quota = ref.read(discoveryControllerProvider).quota;
      if (quota != null) {
        await showInsufficientBalanceSheet(
          context,
          quota: quota,
          now: ref.read(clockProvider)(),
        );
      }
    } else if (rejection != null) {
      showAppSnackBar(context, 'That super like was not sent.');
    }
  }

  Future<void> _onDiscoveryMessage() async {
    final top = ref.read(discoveryControllerProvider).top;
    if (top == null) return;
    if (!await _ensurePremiumFunds() || !mounted) return;
    final result = await _controller.openDiscoveryMessage(confirmedPaid: true);
    if (!mounted) return;
    if (result.rejection == SwipeRejection.insufficientFunds) {
      final quota = ref.read(discoveryControllerProvider).quota;
      if (quota != null) {
        await showInsufficientBalanceSheet(
          context,
          quota: quota,
          now: ref.read(clockProvider)(),
        );
      }
      return;
    }
    final conversationId = result.conversationId;
    if (conversationId == null) {
      showAppSnackBar(context, 'Could not open that chat.');
      return;
    }
    await context.push(AppRoutes.chatConversation(conversationId));
  }

  Future<void> _onUndo() async {
    if (!_controller.canUndo) return;
    if (!await _ensurePremiumFunds() || !mounted) return;
    final rejection = await _controller.undo(confirmedPaid: true);
    if (!mounted) return;
    if (rejection == SwipeRejection.insufficientFunds) {
      final quota = ref.read(discoveryControllerProvider).quota;
      if (quota != null) {
        await showInsufficientBalanceSheet(
          context,
          quota: quota,
          now: ref.read(clockProvider)(),
        );
      }
    } else if (rejection != null) {
      showAppSnackBar(context, 'Could not rewind that swipe.');
    }
  }

  Future<void> _openFilters() async {
    final chosen = await showDiscoveryFiltersSheet(
      context,
      current: ref.read(discoveryFiltersProvider),
    );
    if (chosen != null) {
      ref.read(discoveryFiltersProvider.notifier).apply(chosen);
    }
  }

  Future<void> _celebrate(Profile match) async {
    if (_showingMatch) return;
    _showingMatch = true;
    final canView = ref.read(sessionProvider).isLoggedIn;
    final conversationId =
        ref.read(discoveryControllerProvider).matchConversationId ??
        Match.chatIdFor(match.id);
    final action = await showMatchCelebration(
      context,
      profile: match,
      canViewMatches: canView,
      allowMessage: canView,
    );
    _showingMatch = false;
    if (!mounted) return;
    _controller.clearMatch();
    switch (action) {
      case MatchCelebrationAction.sayHello:
        if (canView) {
          await context.push(AppRoutes.chatConversation(conversationId));
        }
      case MatchCelebrationAction.viewMatches:
        if (canView) context.go(AppRoutes.matches);
      case MatchCelebrationAction.keepSwiping:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Profile?>(
      discoveryControllerProvider.select((s) => s.newMatch),
      (_, match) {
        if (match != null) _celebrate(match);
      },
    );
    ref.listen<String?>(discoveryControllerProvider.select((s) => s.message), (
      _,
      message,
    ) {
      if (message == null) return;
      showAppSnackBar(context, message, type: AppSnackType.error);
      _controller.clearMessage();
    });

    final state = ref.watch(discoveryControllerProvider);
    final filters = ref.watch(discoveryFiltersProvider);
    final status = ref.watch(sessionProvider.select((s) => s.status));

    final quota = state.quota;
    final gated = quota != null && quota.next.kind == SwipeKind.needsProfile;
    final top = state.top;
    final showStage =
        state.phase == DiscoveryPhase.ready && !gated && top != null;

    // Discovery is a dark, photo-first screen in every theme.
    return Theme(
      data: AppTheme.dark,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: showStage
            ? AppPage(
                edgeToEdge: true,
                body: _buildStage(
                  state,
                  top,
                  filters,
                  incomplete: status == AuthStatus.incompleteProfile,
                ),
              )
            : AppPage(
                appBar: AppTopBar(
                  showBrand: true,
                  showPoints: false,
                  actions: [
                    if (status == AuthStatus.incompleteProfile)
                      TextButton(
                        onPressed: () =>
                            context.go(AppRoutes.profileCompletion),
                        child: const Text('Finish profile'),
                      ),
                    IconButton(
                      tooltip: filters.activeCount > 0
                          ? 'Discovery preferences, ${filters.activeCount} active'
                          : 'Discovery preferences',
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: filters.activeCount > 0,
                        label: Text('${filters.activeCount}'),
                        child: const Icon(AppIcons.filter),
                      ),
                    ),
                    const NotificationBell(),
                  ],
                ),
                body: _buildBody(state, filters),
              ),
      ),
    );
  }

  /// Loading, failed, gated and empty states. The card stage is
  /// [_buildStage].
  Widget _buildBody(DiscoveryState state, DiscoveryFilters filters) {
    switch (state.phase) {
      case DiscoveryPhase.loading:
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.xl),
          child: SkeletonCard(),
        );
      case DiscoveryPhase.failed:
        return ErrorState.fromError(
          state.error ?? Exception('discovery'),
          onRetry: _controller.reload,
        );
      case DiscoveryPhase.ready:
        break;
    }

    final quota = state.quota;
    if (quota != null && quota.next.kind == SwipeKind.needsProfile) {
      return ProfileGateView(
        onComplete: () => context.go(AppRoutes.profileCompletion),
      );
    }
    return _buildEmpty(state, filters);
  }

  /// The card edge to edge, the header over its top, and the action row over
  /// its bottom.
  Widget _buildStage(
    DiscoveryState state,
    Profile top,
    DiscoveryFilters filters, {
    required bool incomplete,
  }) {
    final flags = ref.watch(featureFlagsProvider);
    final canUndo = flags.undoSwipe && state.lastSwiped != null;
    final undoLabel = !flags.undoSwipe
        ? 'Undo last swipe (not available yet)'
        : 'Undo last swipe';
    final cardKey = _keyFor(top.id);
    final photoIndex = _photoProfileId == top.id ? _photoIndex : 0;
    final photoCount = top.photoCount < 1 ? 1 : top.photoCount;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.cardMaxWidth),
        child: Stack(
          children: [
            if (state.next != null)
              Positioned.fill(
                child: SwipeCardBackdrop(seed: state.next!.photoSeed, lift: 1),
              ),
            Positioned.fill(
              child: SwipeCard(
                key: cardKey,
                onWillSwipe: _willSwipe,
                onSwiped: _onSwiped,
                child: ProfileCard(
                  profile: top,
                  placeholderSeed: top.photoSeed,
                  fullBleed: true,
                  showPhotoIndicator: false,
                  maxInterests: 3,
                  allowPhotoSwipe: false,
                  bottomInset: _actionRowHeight,
                  onPageChanged: (page) => _onPhotoChanged(top.id, page),
                  onTap: () => _openDetail(top),
                  onOpenProfile: () => _openDetail(top),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DiscoveryHeader(
                      category: _category,
                      onPreferences: _openFilters,
                      activeFilterCount: filters.activeCount,
                      showFinishProfile: incomplete,
                      onFinishProfile: () =>
                          context.go(AppRoutes.profileCompletion),
                    ),
                    AppSpacing.gapSm,
                    PhotoDots(count: photoCount, index: photoIndex),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SwipeActionRow(
                passLabel: 'Pass on ${top.displayName}',
                likeLabel: 'Like ${top.displayName}',
                undoLabel: undoLabel,
                superLikeLabel: 'Super like ${top.displayName}',
                messageLabel: 'Message ${top.displayName}',
                onPass: () => cardKey.currentState?.swipe(SwipeDirection.left),
                onLike: () => cardKey.currentState?.swipe(SwipeDirection.right),
                onUndo: canUndo ? _onUndo : null,
                onSuperLike: _onSuperLike,
                onMessage: _onDiscoveryMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Room the action row takes at the bottom of the card, so the name and
  /// interests clear it. Kept tight so the info block sits a bit lower.
  static const double _actionRowHeight = 96;
  Widget _buildEmpty(DiscoveryState state, DiscoveryFilters filters) {
    final hasFilters = !filters.isDefault;

    if (state.loadedCount > 0) {
      // Everyone in the deck has been swiped on.
      return _EmptyWithActions(
        state: StateMessage(
          icon: AppIcons.heartOutline,
          title: 'You\'re all caught up',
          message:
              'You have seen everyone for now. New people appear every day, '
              'so check back later.',
          actionLabel: 'Refresh',
          onAction: _controller.reload,
        ),
        secondaryLabel: 'Adjust preferences',
        onSecondary: _openFilters,
      );
    }
    if (hasFilters) {
      return _EmptyWithActions(
        state: StateMessage(
          icon: AppIcons.search,
          title: 'No results',
          message:
              'No one matches your current preferences. Try widening the age '
              'range or distance.',
          actionLabel: 'Adjust preferences',
          onAction: _openFilters,
        ),
        secondaryLabel: 'Reset preferences',
        onSecondary: ref.read(discoveryFiltersProvider.notifier).reset,
      );
    }
    return EmptyState(
      icon: AppIcons.discover,
      title: 'No one new right now',
      message: 'Check back soon, or widen your preferences.',
      actionLabel: 'Refresh',
      onAction: _controller.reload,
    );
  }
}

class _EmptyWithActions extends StatelessWidget {
  const _EmptyWithActions({
    required this.state,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final Widget state;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: state),
        Padding(
          padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xl),
          child: AppButton(
            label: secondaryLabel,
            variant: AppButtonVariant.text,
            onPressed: onSecondary,
          ),
        ),
      ],
    );
  }
}
