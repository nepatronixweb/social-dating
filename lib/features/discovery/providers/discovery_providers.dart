import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/constants/swipe_rules.dart';
import '../../../data/models/discovery_filters.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/swipe.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../../matches/providers/matches_providers.dart';
import '../../wallet/providers/wallet_providers.dart';

/// The person's discovery preferences. Changing them reloads the deck.
class DiscoveryFiltersNotifier extends Notifier<DiscoveryFilters> {
  @override
  DiscoveryFilters build() => DiscoveryFilters.defaults;

  void apply(DiscoveryFilters filters) => state = filters;

  void reset() => state = DiscoveryFilters.defaults;
}

final discoveryFiltersProvider =
    NotifierProvider<DiscoveryFiltersNotifier, DiscoveryFilters>(
      DiscoveryFiltersNotifier.new,
    );

/// The swipe allowance as the repository last reported it. Used by screens
/// that only need to read it (for example the profile-completion screen).
final swipeQuotaProvider = FutureProvider.autoDispose<SwipeQuota>(
  (ref) => ref.watch(swipeRepositoryProvider).fetchQuota(),
  retry: (_, _) => null,
);

enum DiscoveryPhase { loading, ready, failed }

/// What to do before the next swipe, decided from the current quota.
enum SwipeGateKind {
  /// Go ahead.
  allowed,

  /// A paid swipe: ask the person to confirm the cost first.
  confirmPayment,

  /// Beyond the free allowance and the mock balance is too low.
  insufficientBalance,

  /// Preview swipes are used up: complete the profile.
  profileRequired,

  /// Nothing to swipe on, or the quota is not known yet.
  unavailable,
}

@immutable
class SwipeGate {
  const SwipeGate(this.kind, {this.costPaisa = 0});

  final SwipeGateKind kind;
  final int costPaisa;

  bool get isAllowed => kind == SwipeGateKind.allowed;
}

@immutable
class DiscoveryState {
  const DiscoveryState({
    this.phase = DiscoveryPhase.loading,
    this.deck = const [],
    this.quota,
    this.loadedCount = 0,
    this.lastSwiped,
    this.newMatch,
    this.error,
    this.message,
  });

  final DiscoveryPhase phase;

  /// Profiles still to swipe on. The first one is the top card.
  final List<Profile> deck;
  final SwipeQuota? quota;

  /// How many profiles the last load returned (tells "no results" apart from
  /// "you have seen everyone").
  final int loadedCount;
  final Profile? lastSwiped;

  /// Set when a swipe produced a match; the screen shows the celebration and
  /// then clears it.
  final Profile? newMatch;
  final Object? error;

  /// A one-off notice for the screen to show (for example a failed swipe).
  final String? message;

  Profile? get top => deck.isEmpty ? null : deck.first;
  Profile? get next => deck.length < 2 ? null : deck[1];

  DiscoveryState copyWith({
    DiscoveryPhase? phase,
    List<Profile>? deck,
    SwipeQuota? quota,
    int? loadedCount,
    Profile? lastSwiped,
    bool clearLastSwiped = false,
    Profile? newMatch,
    bool clearMatch = false,
    Object? error,
    bool clearError = false,
    String? message,
    bool clearMessage = false,
  }) => DiscoveryState(
    phase: phase ?? this.phase,
    deck: deck ?? this.deck,
    quota: quota ?? this.quota,
    loadedCount: loadedCount ?? this.loadedCount,
    lastSwiped: clearLastSwiped ? null : (lastSwiped ?? this.lastSwiped),
    newMatch: clearMatch ? null : (newMatch ?? this.newMatch),
    error: clearError ? null : (error ?? this.error),
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// Owns the deck, the swipe allowance and the optimistic swipe flow.
///
/// A swipe removes the card immediately and is then sent to the repository,
/// one at a time and in order. If the repository disagrees (or the call
/// fails) the card comes back and the quota snaps to the repository's.
class DiscoveryController extends Notifier<DiscoveryState> {
  int _loadToken = 0;
  Future<void> _queue = Future.value();

  @override
  DiscoveryState build() {
    // Preferences changed: fetch a new deck.
    ref.listen(discoveryFiltersProvider, (_, _) => reload());
    // Completing the profile changes what the next swipe means.
    ref.listen(
      sessionProvider.select((s) => s.hasCompletedProfile),
      (_, _) => unawaited(refreshQuota()),
    );
    // Signing out ends this person's deck.
    ref.listen(sessionProvider.select((s) => s.status), (previous, next) {
      if (next == AuthStatus.loggedOut) ref.invalidateSelf();
    });
    unawaited(load());
    return const DiscoveryState();
  }

  Future<void> load() async {
    final token = ++_loadToken;
    try {
      final repository = ref.read(swipeRepositoryProvider);
      final filters = ref.read(discoveryFiltersProvider);
      final results = await Future.wait<Object>([
        repository.fetchDeck(filters),
        repository.fetchQuota(),
      ]);
      if (!ref.mounted || token != _loadToken) return;
      final deck = results[0] as List<Profile>;
      state = DiscoveryState(
        phase: DiscoveryPhase.ready,
        deck: deck,
        quota: results[1] as SwipeQuota,
        loadedCount: deck.length,
      );
    } catch (error) {
      if (!ref.mounted || token != _loadToken) return;
      state = state.copyWith(phase: DiscoveryPhase.failed, error: error);
    }
  }

  /// Shows the loading state and fetches the deck again.
  void reload() {
    state = state.copyWith(phase: DiscoveryPhase.loading, clearError: true);
    unawaited(load());
  }

  Future<void> refreshQuota() async {
    try {
      final quota = await ref.read(swipeRepositoryProvider).fetchQuota();
      if (!ref.mounted) return;
      state = state.copyWith(quota: quota);
    } catch (_) {
      // Keep the last known quota; the next swipe re-checks with the server.
    }
  }

  /// Decides, from the quota alone, what must happen before a swipe.
  ///
  /// If the Nepal day rolled over since the quota was fetched, the counters
  /// are stale, so they are refreshed first.
  Future<SwipeGate> checkSwipe() async {
    if (state.top == null) return const SwipeGate(SwipeGateKind.unavailable);
    var quota = state.quota;
    if (quota != null) {
      final today = nepalDayKey(ref.read(clockProvider)());
      if (quota.dayKey != today) {
        await refreshQuota();
        if (!ref.mounted) return const SwipeGate(SwipeGateKind.unavailable);
        quota = state.quota;
      }
    }
    if (quota == null) return const SwipeGate(SwipeGateKind.unavailable);
    final availability = quota.next;
    return switch (availability.kind) {
      SwipeKind.preview ||
      SwipeKind.free => const SwipeGate(SwipeGateKind.allowed),
      SwipeKind.paid => SwipeGate(
        SwipeGateKind.confirmPayment,
        costPaisa: availability.costPaisa,
      ),
      SwipeKind.insufficient => SwipeGate(
        SwipeGateKind.insufficientBalance,
        costPaisa: availability.costPaisa,
      ),
      SwipeKind.needsProfile => const SwipeGate(SwipeGateKind.profileRequired),
    };
  }

  /// Records a swipe on the top card. Call after [checkSwipe] allowed it (and,
  /// for paid swipes, after the person confirmed the price).
  Future<void> commit(SwipeDirection direction, {bool confirmedPaid = false}) {
    final profile = state.top;
    final quota = state.quota;
    if (profile == null || quota == null) return Future.value();

    // Optimistic update: the card is gone and the counters move right away.
    state = state.copyWith(
      deck: state.deck.sublist(1),
      quota: quota.afterSwipe(),
      lastSwiped: profile,
      clearMessage: true,
    );

    final job = _queue.then((_) async {
      if (!ref.mounted) return;
      try {
        final outcome = await ref
            .read(swipeRepositoryProvider)
            .swipe(profile.id, direction, confirmedPaid: confirmedPaid);
        if (!ref.mounted) return;
        if (outcome.recorded) {
          state = state.copyWith(
            quota: outcome.quota,
            newMatch: outcome.matchedProfile,
          );
          // Likes, matches, chat and wallet must reflect this swipe.
          ref.read(matchingRevisionProvider.notifier).bump();
          ref.read(walletRevisionProvider.notifier).bump();
        } else {
          _restore(
            profile,
            outcome.quota,
            'That swipe was not counted. Your allowance has been refreshed.',
          );
        }
      } catch (_) {
        if (!ref.mounted) return;
        _restore(
          profile,
          null,
          'Could not record that swipe. Check your connection and try again.',
        );
      }
    });
    _queue = job;
    return job;
  }

  void _restore(Profile profile, SwipeQuota? quota, String message) {
    state = state.copyWith(
      deck: [profile, ...state.deck],
      quota: quota,
      clearLastSwiped: true,
      message: message,
    );
    if (quota == null) unawaited(refreshQuota());
  }

  /// Whether the undo control can act right now.
  bool get canUndo =>
      ref.read(featureFlagsProvider).undoSwipe && state.lastSwiped != null;

  /// Brings the last card back. Mock-only, and only when the local flag is on.
  Future<void> undo() async {
    if (!canUndo) return;
    final job = _queue.then((_) async {
      if (!ref.mounted) return;
      try {
        final outcome = await ref.read(swipeRepositoryProvider).undoLast();
        if (!ref.mounted) return;
        if (outcome == null) {
          state = state.copyWith(
            clearLastSwiped: true,
            message: 'Nothing to undo.',
          );
          return;
        }
        state = state.copyWith(
          deck: [outcome.profile, ...state.deck],
          quota: outcome.quota,
          clearLastSwiped: true,
          clearMatch: true,
        );
        ref.read(matchingRevisionProvider.notifier).bump();
        ref.read(walletRevisionProvider.notifier).bump();
      } catch (_) {
        if (!ref.mounted) return;
        state = state.copyWith(message: 'Could not undo that swipe.');
      }
    });
    _queue = job;
    await job;
  }

  void clearMatch() => state = state.copyWith(clearMatch: true);

  void clearMessage() => state = state.copyWith(clearMessage: true);
}

final discoveryControllerProvider =
    NotifierProvider<DiscoveryController, DiscoveryState>(
      DiscoveryController.new,
    );
