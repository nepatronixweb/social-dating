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
import '../models/match.dart';
import '../models/profile.dart';
import '../models/swipe.dart';
import '../models/wallet.dart';
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
    int Function()? spendableBalance,
    bool Function(
      int points,
      String title,
      WalletActivityKind kind,
      String detail,
    )?
    chargeWallet,
    void Function(int points, String dayKey)? grantDailyWallet,
    void Function(int points, String title, String detail)? refundWallet,
  }) : _now = now ?? DateTime.now,
       _isProfileComplete = isProfileComplete ?? (() => true),
       _viewerGender = viewerGender,
       _viewerGenderOf = viewerGenderOf,
       _hasPaidPremium = hasPaidPremium,
       _spendableBalance = spendableBalance,
       _chargeWallet = chargeWallet,
       _grantDailyWallet = grantDailyWallet,
       _refundWallet = refundWallet;

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

  /// Standalone mock balance used when no shared wallet ledger is wired.
  int balancePaisa;

  final int Function()? _spendableBalance;
  final bool Function(
    int points,
    String title,
    WalletActivityKind kind,
    String detail,
  )?
  _chargeWallet;
  final void Function(int points, String dayKey)? _grantDailyWallet;
  final void Function(int points, String title, String detail)? _refundWallet;

  int get _effectiveBalance => _spendableBalance?.call() ?? balancePaisa;

  bool _debit(
    int points, {
    required String title,
    required WalletActivityKind kind,
    required String detail,
  }) {
    if (points <= 0) return true;
    final charge = _chargeWallet;
    if (charge != null) {
      return charge(points, title, kind, detail);
    }
    if (balancePaisa < points) return false;
    balancePaisa -= points;
    return true;
  }

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
  String? _dailyGrantDayKey;

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
    _dailyGrantDayKey = null;
  }

  bool get _mustPayPremiumActions =>
      viewerGender.needsPaidSubscription && !(_hasPaidPremium?.call() ?? false);

  void _ensureDailyGrant() {
    if (!_mustPayPremiumActions) return;
    final today = nepalDayKey(_now());
    if (_dailyGrantDayKey == today) return;
    _dailyGrantDayKey = today;
    final grant = _grantDailyWallet;
    if (grant != null) {
      grant(SwipeRules.dailyFreePointsMale, today);
    } else {
      balancePaisa += SwipeRules.dailyFreePointsMale;
    }
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
    _ensureDailyGrant();
    return SwipeQuota(
      profileComplete: _isProfileComplete(),
      previewUsed: _previewUsed,
      dailyUsed: _dailyUsed,
      freeDailyLimit: _freeDailyLimit,
      balancePaisa: _effectiveBalance,
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
    final isSuper = direction == SwipeDirection.superLike;

    SwipeOutcome reject(SwipeRejection reason) =>
        SwipeOutcome.rejected(quota: quota, rejection: reason);

    if (isSuper) {
      if (_mustPayPremiumActions) {
        final cost = quota.actionPricePaisa;
        if (quota.balancePaisa < cost) {
          return reject(SwipeRejection.insufficientFunds);
        }
        if (!confirmedPaid) return reject(SwipeRejection.paymentRequired);
      }
    } else {
      final availability = quota.next;
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
    }

    final profile = catalog.where((p) => p.id == profileId).firstOrNull;
    if (profile == null || _swipedIds.contains(profileId)) {
      // Already swiped (or unknown): treat as a no-op rather than charging.
      return SwipeOutcome.recorded(quota: quota);
    }

    var charged = 0;
    var kind = SwipeKind.free;
    if (isSuper) {
      kind = SwipeKind.paid;
      if (_mustPayPremiumActions) {
        charged = quota.actionPricePaisa;
        if (!_debit(
          charged,
          title: 'Super like',
          kind: WalletActivityKind.swipeSpend,
          detail:
              '100 points for a super like. Credited to the admin account.',
        )) {
          return reject(SwipeRejection.insufficientFunds);
        }
      }
    } else {
      final availability = quota.next;
      kind = availability.kind;
      charged = availability.kind == SwipeKind.paid ? availability.costPaisa : 0;
      final after = quota.afterSwipe();
      _previewUsed = after.previewUsed;
      _dailyUsed = after.dailyUsed;
      if (charged > 0) {
        if (!_debit(
          charged,
          title: 'Paid swipe',
          kind: WalletActivityKind.swipeSpend,
          detail: 'Points charged for an extra swipe.',
        )) {
          return reject(SwipeRejection.insufficientFunds);
        }
      } else if (_chargeWallet == null) {
        balancePaisa = after.balancePaisa;
      }
    }

    _swipedIds.add(profileId);

    final liked =
        direction == SwipeDirection.right ||
        direction == SwipeDirection.superLike;
    var matched = liked && matchOnLikeIds.contains(profileId);
    final shared = matching;
    if (shared != null) {
      if (liked) {
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
        kind: kind,
        chargedPaisa: charged,
        dayKey: quota.dayKey,
        matched: matched,
        recordedLike: shared != null && liked,
      ),
    );

    return SwipeOutcome.recorded(
      quota: _quota(),
      matchedProfile: matched ? profile : null,
      conversationId: matched
          ? (shared != null
                ? MockMatchingRepository.matchIdFor(profileId)
                : Match.chatIdFor(profileId))
          : null,
      chargedPaisa: charged,
    );
  }

  @override
  Future<UndoOutcome?> undoLast({bool confirmedPaid = false}) async {
    await _wait();
    if (!undoSupported || _history.isEmpty) return null;
    final quota = _quota();
    if (_mustPayPremiumActions) {
      final cost = quota.actionPricePaisa;
      if (quota.balancePaisa < cost) {
        return UndoOutcome(
          quota: quota,
          rejection: SwipeRejection.insufficientFunds,
        );
      }
      if (!confirmedPaid) {
        return UndoOutcome(
          quota: quota,
          rejection: SwipeRejection.paymentRequired,
        );
      }
      if (!_debit(
        cost,
        title: 'Rewind',
        kind: WalletActivityKind.swipeSpend,
        detail:
            '100 points to undo the last swipe. Credited to the admin '
            'account.',
      )) {
        return UndoOutcome(
          quota: quota,
          rejection: SwipeRejection.insufficientFunds,
        );
      }
    }

    final record = _history.removeLast();
    _swipedIds.remove(record.profile.id);
    if (record.recordedLike) matching?.revertLike(record.profile.id);
    if (record.direction != SwipeDirection.superLike) {
      switch (record.kind) {
        case SwipeKind.preview:
          _previewUsed = (_previewUsed - 1).clamp(0, 1 << 30);
        case SwipeKind.free:
        case SwipeKind.paid:
          if (record.dayKey == nepalDayKey(_now())) {
            _dailyUsed = (_dailyUsed - 1).clamp(0, 1 << 30);
          }
          _refundCharge(record.chargedPaisa);
        case SwipeKind.insufficient:
        case SwipeKind.needsProfile:
          break;
      }
    } else {
      _refundCharge(record.chargedPaisa);
    }

    return UndoOutcome(
      profile: record.profile,
      quota: _quota(),
      chargedPaisa: _mustPayPremiumActions ? quota.actionPricePaisa : 0,
    );
  }

  void _refundCharge(int points) {
    if (points <= 0) return;
    final refund = _refundWallet;
    if (refund != null) {
      refund(points, 'Swipe refund', 'Points returned after a rewind.');
      return;
    }
    balancePaisa += points;
  }

  @override
  Future<DiscoveryMessageOutcome> openDiscoveryMessage(
    String profileId, {
    required bool confirmedPaid,
  }) async {
    await _wait();
    if (scenario() == MockScenario.failure) {
      throw const NetworkFailure();
    }
    final quota = _quota();
    final profile = catalog.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) {
      return DiscoveryMessageOutcome(quota: quota);
    }

    if (_mustPayPremiumActions) {
      final cost = quota.actionPricePaisa;
      if (quota.balancePaisa < cost) {
        return DiscoveryMessageOutcome(
          quota: quota,
          rejection: SwipeRejection.insufficientFunds,
        );
      }
      if (!confirmedPaid) {
        return DiscoveryMessageOutcome(
          quota: quota,
          rejection: SwipeRejection.paymentRequired,
        );
      }
      if (!_debit(
        cost,
        title: 'Direct message',
        kind: WalletActivityKind.messageSpend,
        detail:
            '100 points to message before a match. Credited to the admin '
            'account.',
      )) {
        return DiscoveryMessageOutcome(
          quota: quota,
          rejection: SwipeRejection.insufficientFunds,
        );
      }
    }

    final shared = matching;
    String conversationId;
    if (shared != null) {
      final result = shared.recordLike(profile);
      conversationId =
          result.match?.conversationId ??
          result.match?.id ??
          MockMatchingRepository.matchIdFor(profileId);
    } else {
      conversationId = MockMatchingRepository.matchIdFor(profileId);
    }
    _swipedIds.add(profileId);

    return DiscoveryMessageOutcome(
      quota: _quota(),
      conversationId: conversationId,
      chargedPaisa: _mustPayPremiumActions ? quota.actionPricePaisa : 0,
    );
  }
}
