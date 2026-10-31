// ============================================================================
// MOCK DATA ONLY: in-memory swipe "server"
//
// Counters, prices, the wallet balance and matches below are simulated in
// memory and vanish when the app restarts. NONE of this is authoritative or
// secure. A real backend must own swipe counting, the Nepal-day boundary,
// pricing, balances and matching. Nothing outside `mock_*` files and the
// approved seam may import this file (test/mock_isolation_test.dart).
// ============================================================================

import '../../core/constants/swipe_rules.dart';
import '../../core/errors/app_failure.dart';
import '../models/discovery_filters.dart';
import '../models/profile.dart';
import '../models/swipe.dart';
import 'mock_matching_repository.dart';
import 'mock_profile_repository.dart';
import 'swipe_repository.dart';

/// A recorded mock swipe, kept so the last one can be undone.
class _SwipeRecord {
  const _SwipeRecord({
    required this.profile,
    required this.direction,
    required this.kind,
    required this.chargedPaisa,
    required this.dayKey,
    required this.matched,
    required this.recordedLike,
  });

  final Profile profile;
  final SwipeDirection direction;
  final SwipeKind kind;
  final int chargedPaisa;
  final String dayKey;
  final bool matched;

  /// A like that was handed to the matching repository (so undo can revert it).
  final bool recordedLike;
}

class MockSwipeRepository implements SwipeRepository {
  MockSwipeRepository({
    this.catalog = mockProfiles,
    this.scenario = _populated,
    this.latency = const Duration(milliseconds: 500),
    DateTime Function()? now,
    bool Function()? isProfileComplete,
    ProfileGender viewerGender = ProfileGender.male,
    ProfileGender Function()? viewerGenderOf,
    bool Function()? hasPaidPremium,
    this.balancePaisa = 100,
    this.matchOnLikeIds = const {'mock-2', 'mock-3', 'mock-10', 'mock-14'},
    this.undoSupported = true,
    this.matching,
  }) : _now = now ?? DateTime.now,
       _isProfileComplete = isProfileComplete ?? (() => true),
       _viewerGender = viewerGender,
       _viewerGenderOf = viewerGenderOf,
       _hasPaidPremium = hasPaidPremium;

  static MockScenario _populated() => MockScenario.populated;

  /// Everyone who can appear in the deck, in order.
  final List<Profile> catalog;
  final MockScenario Function() scenario;
  final Duration latency;
  final DateTime Function() _now;
  final bool Function() _isProfileComplete;
  final ProfileGender Function()? _viewerGenderOf;
  final ProfileGender _viewerGender;
  final bool Function()? _hasPaidPremium;
  ProfileGender? _viewerGenderOverride;

  /// Mock viewer. Only male accounts have the free daily limit in this
  /// simulation, mirroring the product rule; others are unlimited here.
  /// Discovery also uses this to decide who appears in the deck.
  ProfileGender get viewerGender =>
      _viewerGenderOverride ?? _viewerGenderOf?.call() ?? _viewerGender;
  set viewerGender(ProfileGender value) => _viewerGenderOverride = value;

  /// Mock wallet balance in paisa (100 = NPR 1.00).
  int balancePaisa;

  /// Right-swiping any of these produces a match, so the celebration can be
  /// triggered from mock data.
  final Set<String> matchOnLikeIds;

  /// Whether this mock honours [undoLast]. The UI additionally requires the
  /// local feature flag before it offers undo.
  final bool undoSupported;

  /// The shared matching mock. When set, likes and passes are recorded there,
  /// so discovery, likes, matches and chat agree, and matches come from
  /// mutual likes. When null, [matchOnLikeIds] alone decides (unit tests).
  final MockMatchingRepository? matching;

  final Set<String> _swipedIds = {};
  final List<_SwipeRecord> _history = [];
  int _previewUsed = 0;
  int _dailyUsed = 0;
  String? _dailyDayKey;

  // ---- Mock-only controls (used by the debug gallery and tests) ------------

  /// Every swipe the mock has recorded, oldest first.
  List<({String profileId, SwipeDirection direction, SwipeKind kind})>
  get swipeLog => [
    for (final record in _history)
      (
        profileId: record.profile.id,
        direction: record.direction,
        kind: record.kind,
      ),
  ];

  /// Forgets every swipe and counter.
  void reset() {
    _swipedIds.clear();
    _history.clear();
    _previewUsed = 0;
    _dailyUsed = 0;
    _dailyDayKey = null;
  }

  /// Sets the counters directly so boundaries are easy to reach.
  void seedCounters({int? previewUsed, int? dailyUsed}) {
    if (previewUsed != null) _previewUsed = previewUsed;
    if (dailyUsed != null) {
      _dailyUsed = dailyUsed;
      _dailyDayKey = nepalDayKey(_now());
    }
  }

  // ---- SwipeRepository -----------------------------------------------------

  int? get _freeDailyLimit {
    if (!viewerGender.paysForExtraSwipesAndWords) return null;
    if (_hasPaidPremium?.call() ?? false) return null;
    return SwipeRules.freeDailySwipesMale;
  }

  SwipeQuota _quota() {
    final instant = _now();
    final today = nepalDayKey(instant);
    if (_dailyDayKey != today) {
      // New Nepal day: the daily counter starts again.
      _dailyDayKey = today;
      _dailyUsed = 0;
    }
    return SwipeQuota(
      profileComplete: _isProfileComplete(),
      previewUsed: _previewUsed,
      dailyUsed: _dailyUsed,
      freeDailyLimit: _freeDailyLimit,
      balancePaisa: balancePaisa,
      dayKey: today,
      resetsAt: nextNepalMidnight(instant),
    );
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<List<Profile>> fetchDeck(DiscoveryFilters filters) {
    return simulateMockCall(
      scenario: scenario(),
      latency: latency,
      data: () => [
        for (final profile in catalog)
          if (!_swipedIds.contains(profile.id) &&
              !(matching?.excludedProfileIds.contains(profile.id) ?? false) &&
              viewerGender.sees(profile.gender) &&
              filters.matches(profile))
            profile,
      ],
      empty: const [],
    );
  }

  @override
  Future<SwipeQuota> fetchQuota() async {
    await _wait();
    return _quota();
  }

  @override
  Future<SwipeOutcome> swipe(
    String profileId,
    SwipeDirection direction, {
    required bool confirmedPaid,
  }) async {
    await _wait();
    if (scenario() == MockScenario.failure) {
      throw const NetworkFailure();
    }
    final quota = _quota();
    final availability = quota.next;

    SwipeOutcome reject(SwipeRejection reason) =>
        SwipeOutcome.rejected(quota: quota, rejection: reason);

    switch (availability.kind) {
      case SwipeKind.needsProfile:
        return reject(SwipeRejection.profileIncomplete);
      case SwipeKind.insufficient:
        return reject(SwipeRejection.insufficientFunds);
      case SwipeKind.paid when !confirmedPaid:
        return reject(SwipeRejection.paymentRequired);
      case SwipeKind.paid:
      case SwipeKind.free:
      case SwipeKind.preview:
        break;
    }

    final profile = catalog.where((p) => p.id == profileId).firstOrNull;
    if (profile == null || _swipedIds.contains(profileId)) {
      // Already swiped (or unknown): treat as a no-op rather than charging.
      return SwipeOutcome.recorded(quota: quota);
    }

    final after = quota.afterSwipe();
    _previewUsed = after.previewUsed;
    _dailyUsed = after.dailyUsed;
    balancePaisa = after.balancePaisa;
    _swipedIds.add(profileId);

    final liked = direction == SwipeDirection.right;
    var matched = liked && matchOnLikeIds.contains(profileId);
    final shared = matching;
    if (shared != null) {
      if (liked) {
        // Matches come from mutual likes in the shared mock.
        matched = shared.recordLike(profile).created;
      } else {
        shared.recordPass(profile);
        matched = false;
      }
    }
    _history.add(
      _SwipeRecord(
        profile: profile,
        direction: direction,
        kind: availability.kind,
        chargedPaisa: availability.costPaisa,
        dayKey: quota.dayKey,
        matched: matched,
        recordedLike: shared != null && liked,
      ),
    );

    return SwipeOutcome.recorded(
      quota: _quota(),
      matchedProfile: matched ? profile : null,
      chargedPaisa: availability.costPaisa,
    );
  }

  @override
  Future<UndoOutcome?> undoLast() async {
    await _wait();
    if (!undoSupported || _history.isEmpty) return null;
    final record = _history.removeLast();
    _swipedIds.remove(record.profile.id);
    if (record.recordedLike) matching?.revertLike(record.profile.id);
    switch (record.kind) {
      case SwipeKind.preview:
        _previewUsed = (_previewUsed - 1).clamp(0, 1 << 30);
      case SwipeKind.free:
      case SwipeKind.paid:
        // Only the same Nepal day's counter can be rolled back.
        if (record.dayKey == nepalDayKey(_now())) {
          _dailyUsed = (_dailyUsed - 1).clamp(0, 1 << 30);
        }
        balancePaisa += record.chargedPaisa;
      case SwipeKind.insufficient:
      case SwipeKind.needsProfile:
        break;
    }
    return UndoOutcome(profile: record.profile, quota: _quota());
  }
}
