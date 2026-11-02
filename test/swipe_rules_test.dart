import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/swipe_rules.dart';
import 'package:social_dating/core/utils/distance_label.dart';
import 'package:social_dating/core/utils/money.dart';
import 'package:social_dating/data/models/discovery_filters.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/swipe.dart';
import 'package:social_dating/data/models/wallet.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/repositories/mock_swipe_repository.dart';
import 'package:social_dating/data/repositories/mock_wallet_repository.dart';

// 23:59:59 and 00:00:00 in Nepal (UTC+05:45) on 14/15 October 2026.
final _lastSecondOfNepalDay = DateTime.utc(2026, 10, 14, 18, 14, 59);
final _firstSecondOfNextNepalDay = DateTime.utc(2026, 10, 14, 18, 15);

SwipeQuota _quota({
  bool complete = true,
  int preview = 0,
  int daily = 0,
  int? limit = 20,
  int balance = 100,
}) => SwipeQuota(
  profileComplete: complete,
  previewUsed: preview,
  dailyUsed: daily,
  freeDailyLimit: limit,
  balancePaisa: balance,
  dayKey: '2026-10-14',
  resetsAt: DateTime.utc(2026, 10, 14, 18, 15),
);

MockSwipeRepository _repo({
  DateTime Function()? now,
  bool complete = true,
  ProfileGender gender = ProfileGender.male,
  int balance = 100,
  Set<String>? matches,
  bool paidPremium = false,
}) => MockSwipeRepository(
  latency: Duration.zero,
  now: now ?? () => _lastSecondOfNepalDay,
  isProfileComplete: () => complete,
  viewerGender: gender,
  hasPaidPremium: () => paidPremium,
  balancePaisa: balance,
  matchOnLikeIds: matches ?? const {'mock-2'},
);

void main() {
  group('money', () {
    test('formats integer paisa as NPR', () {
      expect(formatNpr(SwipeRules.extraSwipePricePaisa), 'NPR 0.10');
      expect(formatNpr(0), 'NPR 0.00');
      expect(formatNpr(5), 'NPR 0.05');
      expect(formatNpr(100), 'NPR 1.00');
      expect(formatNpr(125050), 'NPR 1,250.50');
      expect(formatNpr(-10), '-NPR 0.10');
    });

    test('formats points with 100 pts = NPR 1', () {
      expect(formatPoints(0), '0 pts');
      expect(formatPoints(1), '1 pt');
      expect(formatPoints(30), '30 pts');
      expect(formatPoints(100), '100 pts');
      expect(formatPointsDecimal(0), '0.00 pts');
      expect(formatPointsDecimal(30), '0.30 pts');
      expect(formatPointsDecimal(100), '1.00 pts');
      expect(formatPointsDecimal(4610), '46.10 pts');
    });

    test('the price is ten paisa', () {
      expect(SwipeRules.extraSwipePricePaisa, 10);
      expect(SwipeRules.freeDailySwipesMale, 20);
      expect(SwipeRules.previewSwipes, 5);
    });
  });

  group('Nepal calendar day', () {
    test('rolls over at Nepal midnight, not UTC midnight', () {
      expect(nepalDayKey(_lastSecondOfNepalDay), '2026-10-14');
      expect(nepalDayKey(_firstSecondOfNextNepalDay), '2026-10-15');
      // 23:59 UTC is already the next morning in Nepal.
      expect(nepalDayKey(DateTime.utc(2026, 10, 14, 23, 59)), '2026-10-15');
      // 00:30 UTC is still the same Nepal day (06:15).
      expect(nepalDayKey(DateTime.utc(2026, 10, 14, 0, 30)), '2026-10-14');
    });

    test('is independent of the device time zone representation', () {
      final utc = DateTime.utc(2026, 10, 14, 18, 15);
      final local = utc.toLocal();
      expect(nepalDayKey(local), nepalDayKey(utc));
    });

    test('handles month and year ends', () {
      expect(nepalDayKey(DateTime.utc(2026, 12, 31, 18, 15)), '2027-01-01');
      expect(nepalDayKey(DateTime.utc(2026, 12, 31, 18, 14)), '2026-12-31');
    });

    test('next midnight is the reset instant', () {
      expect(
        nextNepalMidnight(_lastSecondOfNepalDay),
        DateTime.utc(2026, 10, 14, 18, 15),
      );
      expect(
        nextNepalMidnight(_firstSecondOfNextNepalDay),
        DateTime.utc(2026, 10, 15, 18, 15),
      );
    });
  });

  group('SwipeQuota.next', () {
    test('preview swipes are allowed until five are used', () {
      for (var used = 0; used < 5; used++) {
        expect(
          _quota(complete: false, preview: used).next.kind,
          SwipeKind.preview,
          reason: 'used $used',
        );
      }
      expect(
        _quota(complete: false, preview: 5).next.kind,
        SwipeKind.needsProfile,
      );
      expect(
        _quota(complete: false, preview: 5).previewRemaining,
        0,
        reason: 'never negative',
      );
    });

    test('daily boundary: 19 used -> free, 20 used -> paid', () {
      expect(_quota(daily: 0).next.kind, SwipeKind.free);
      expect(_quota(daily: 19).next.kind, SwipeKind.free);
      expect(_quota(daily: 19).freeRemaining, 1);
      expect(_quota(daily: 20).next.kind, SwipeKind.paid);
      expect(_quota(daily: 20).freeRemaining, 0);
      expect(_quota(daily: 21).next.kind, SwipeKind.paid);
      expect(_quota(daily: 20).next.costPaisa, 10);
    });

    test('paid needs enough balance: 10 paisa is enough, 9 is not', () {
      expect(_quota(daily: 20, balance: 10).next.kind, SwipeKind.paid);
      expect(_quota(daily: 20, balance: 9).next.kind, SwipeKind.insufficient);
      expect(_quota(daily: 20, balance: 0).next.kind, SwipeKind.insufficient);
      expect(_quota(daily: 20, balance: 9).next.costPaisa, 10);
    });

    test('accounts without a daily limit are never charged', () {
      expect(_quota(daily: 500, limit: null).next.kind, SwipeKind.free);
      expect(_quota(limit: null).freeRemaining, isNull);
    });

    test('afterSwipe moves the right counter and balance', () {
      expect(_quota(complete: false, preview: 2).afterSwipe().previewUsed, 3);
      expect(_quota(daily: 3).afterSwipe().dailyUsed, 4);
      final paid = _quota(daily: 20, balance: 100).afterSwipe();
      expect(paid.dailyUsed, 21);
      expect(paid.balancePaisa, 90);
      // Blocked swipes change nothing.
      final blocked = _quota(daily: 20, balance: 5);
      expect(blocked.afterSwipe(), blocked);
      final gated = _quota(complete: false, preview: 5);
      expect(gated.afterSwipe(), gated);
    });
  });

  group('MockSwipeRepository (mock server)', () {
    test('left and right swipes share one daily count', () async {
      final repo = _repo();
      await repo.swipe('mock-1', SwipeDirection.left, confirmedPaid: false);
      await repo.swipe('mock-3', SwipeDirection.right, confirmedPaid: false);
      await repo.swipe('mock-4', SwipeDirection.left, confirmedPaid: false);
      final quota = await repo.fetchQuota();
      expect(quota.dailyUsed, 3);
      expect(quota.freeRemaining, 17);
      expect(repo.swipeLog.map((e) => e.direction), [
        SwipeDirection.left,
        SwipeDirection.right,
        SwipeDirection.left,
      ]);
    });

    test(
      'the 21st swipe needs confirmation and then charges 10 paisa',
      () async {
        final repo = _repo()..seedCounters(dailyUsed: 20);
        final unconfirmed = await repo.swipe(
          'mock-1',
          SwipeDirection.right,
          confirmedPaid: false,
        );
        expect(unconfirmed.recorded, isFalse);
        expect(unconfirmed.rejection, SwipeRejection.paymentRequired);
        // Constructor balance + daily free grant; nothing charged yet.
        expect(
          repo.balancePaisa,
          100 + SwipeRules.dailyFreePointsMale,
          reason: 'nothing charged',
        );
        expect(repo.swipeLog, isEmpty);

        final confirmed = await repo.swipe(
          'mock-1',
          SwipeDirection.right,
          confirmedPaid: true,
        );
        expect(confirmed.recorded, isTrue);
        expect(confirmed.chargedPaisa, 10);
        expect(repo.balancePaisa, 100 + SwipeRules.dailyFreePointsMale - 10);
        expect((await repo.fetchQuota()).dailyUsed, 21);
      },
    );

    test('insufficient funds are rejected and never go negative', () async {
      // After the daily grant the spendable balance must still be below 10.
      final repo = _repo(balance: 9 - SwipeRules.dailyFreePointsMale)
        ..seedCounters(dailyUsed: 20);
      final outcome = await repo.swipe(
        'mock-1',
        SwipeDirection.left,
        confirmedPaid: true,
      );
      expect(outcome.rejection, SwipeRejection.insufficientFunds);
      expect(repo.balancePaisa, 9);
      expect(repo.swipeLog, isEmpty);
    });

    test('the daily count resets at Nepal midnight', () async {
      var now = _lastSecondOfNepalDay;
      final repo = _repo(now: () => now)..seedCounters(dailyUsed: 20);
      expect((await repo.fetchQuota()).next.kind, SwipeKind.paid);

      now = _firstSecondOfNextNepalDay;
      final quota = await repo.fetchQuota();
      expect(quota.dailyUsed, 0);
      expect(quota.next.kind, SwipeKind.free);
      expect(quota.dayKey, '2026-10-15');
    });

    test('preview swipes stop at five, then the profile is required', () async {
      final repo = _repo(complete: false);
      final ids = ['mock-1', 'mock-2', 'mock-3', 'mock-4', 'mock-10'];
      for (final id in ids) {
        final outcome = await repo.swipe(
          id,
          SwipeDirection.left,
          confirmedPaid: false,
        );
        expect(outcome.recorded, isTrue, reason: id);
      }
      final sixth = await repo.swipe(
        'mock-11',
        SwipeDirection.left,
        confirmedPaid: false,
      );
      expect(sixth.rejection, SwipeRejection.profileIncomplete);
      final quota = await repo.fetchQuota();
      expect(quota.previewUsed, 5);
      expect(quota.dailyUsed, 0, reason: 'preview swipes are not daily swipes');
    });

    test('only male accounts have the free limit in this simulation', () async {
      final repo = _repo(gender: ProfileGender.female)
        ..seedCounters(dailyUsed: 100);
      final quota = await repo.fetchQuota();
      expect(quota.freeDailyLimit, isNull);
      final outcome = await repo.swipe(
        'mock-1',
        SwipeDirection.left,
        confirmedPaid: false,
      );
      expect(outcome.recorded, isTrue);
      expect(outcome.chargedPaisa, 0);
    });

    test('a male Premium membership removes the daily swipe limit', () async {
      final repo = _repo(paidPremium: true)..seedCounters(dailyUsed: 100);
      final quota = await repo.fetchQuota();
      expect(quota.freeDailyLimit, isNull);
      final outcome = await repo.swipe(
        'mock-1',
        SwipeDirection.left,
        confirmedPaid: false,
      );
      expect(outcome.recorded, isTrue);
      expect(outcome.chargedPaisa, 0);
    });

    test('right swipes can produce a match from mock data', () async {
      final repo = _repo();
      final liked = await repo.swipe(
        'mock-2',
        SwipeDirection.right,
        confirmedPaid: false,
      );
      expect(liked.matchedProfile?.id, 'mock-2');
      final passed = await _repo().swipe(
        'mock-2',
        SwipeDirection.left,
        confirmedPaid: false,
      );
      expect(passed.matchedProfile, isNull);
    });

    test('male accounts see female and LGBTQ+ profiles only', () async {
      final deck = await _repo().fetchDeck(DiscoveryFilters.defaults);
      expect(deck, isNotEmpty);
      expect(
        deck.every(
          (p) =>
              p.gender == ProfileGender.female ||
              p.gender == ProfileGender.lgbtq,
        ),
        isTrue,
      );
      expect(deck.any((p) => p.id == 'mock-1'), isTrue);
      expect(deck.any((p) => p.id == 'mock-4'), isTrue);
      expect(deck.any((p) => p.id == 'mock-2'), isFalse);
    });

    test('female, LGBTQ+ and other accounts see men only', () async {
      for (final gender in [
        ProfileGender.female,
        ProfileGender.lgbtq,
        ProfileGender.other,
      ]) {
        final deck = await _repo(
          gender: gender,
        ).fetchDeck(DiscoveryFilters.defaults);
        expect(deck, isNotEmpty, reason: '$gender');
        expect(
          deck.every((p) => p.gender == ProfileGender.male),
          isTrue,
          reason: '$gender',
        );
        expect(deck.any((p) => p.id == 'mock-2'), isTrue, reason: '$gender');
        expect(deck.any((p) => p.id == 'mock-1'), isFalse, reason: '$gender');
      }
    });

    test(
      'a swiped profile leaves the deck and swiping twice is a no-op',
      () async {
        final repo = _repo();
        await repo.swipe('mock-1', SwipeDirection.left, confirmedPaid: false);
        final deck = await repo.fetchDeck(DiscoveryFilters.defaults);
        expect(deck.any((p) => p.id == 'mock-1'), isFalse);
        await repo.swipe('mock-1', SwipeDirection.left, confirmedPaid: false);
        expect((await repo.fetchQuota()).dailyUsed, 1);
      },
    );

    test(
      'undo restores the card, the count and a paid swipe\'s cost',
      () async {
        final repo = _repo()..seedCounters(dailyUsed: 20);
        await repo.swipe('mock-1', SwipeDirection.right, confirmedPaid: true);
        // Constructor 100 + daily grant 100 - paid swipe 10.
        expect(repo.balancePaisa, 190);

        final undone = await repo.undoLast(confirmedPaid: true);
        expect(undone?.profile?.id, 'mock-1');
        // Rewind fee 100, then refund of the paid swipe 10 → 100.
        expect(repo.balancePaisa, 100);
        expect((await repo.fetchQuota()).dailyUsed, 20);
        expect(await repo.undoLast(confirmedPaid: true), isNull);
      },
    );

    test('failure scenario throws for swipes and the deck', () async {
      final repo = MockSwipeRepository(
        latency: Duration.zero,
        scenario: () => MockScenario.failure,
      );
      await expectLater(
        repo.fetchDeck(DiscoveryFilters.defaults),
        throwsA(anything),
      );
      await expectLater(
        repo.swipe('mock-1', SwipeDirection.left, confirmedPaid: false),
        throwsA(anything),
      );
    });

    test(
      'super like, rewind and discovery DM debit a shared wallet ledger',
      () async {
        final wallet = MockWalletRepository(latency: Duration.zero);
        final starting = wallet.spendable;
        final repo = MockSwipeRepository(
          latency: Duration.zero,
          spendableBalance: () => wallet.spendable,
          chargeWallet: (points, title, kind, detail) => wallet.tryCharge(
            points: points,
            title: title,
            kind: kind,
            detail: detail,
          ),
          grantDailyWallet: (points, dayKey) => wallet.creditPromotional(
            points: points,
            title: 'Daily free points',
            kind: WalletActivityKind.other,
            detail: 'daily',
            id: 'mock-tx-daily-$dayKey',
          ),
          refundWallet: (points, title, detail) => wallet.creditPromotional(
            points: points,
            title: title,
            kind: WalletActivityKind.other,
            detail: detail,
          ),
        );

        await repo.fetchQuota();
        final afterGrant = wallet.spendable;
        expect(afterGrant, starting + SwipeRules.dailyFreePointsMale);

        final superLike = await repo.swipe(
          'mock-1',
          SwipeDirection.superLike,
          confirmedPaid: true,
        );
        expect(superLike.recorded, isTrue);
        expect(wallet.spendable, afterGrant - SwipeRules.premiumActionPricePoints);

        final undone = await repo.undoLast(confirmedPaid: true);
        expect(undone?.rejection, isNull);
        // Rewind costs 100; original super-like charge is refunded.
        expect(wallet.spendable, afterGrant - SwipeRules.premiumActionPricePoints);

        final dm = await repo.openDiscoveryMessage(
          'mock-2',
          confirmedPaid: true,
        );
        expect(dm.conversationId, isNotNull);
        expect(
          wallet.spendable,
          afterGrant - (2 * SwipeRules.premiumActionPricePoints),
        );
      },
    );
  });

  group('DiscoveryFilters', () {
    Profile only(String id) => mockProfiles.firstWhere((p) => p.id == id);

    test('defaults match everyone', () {
      expect(DiscoveryFilters.defaults.isDefault, isTrue);
      expect(DiscoveryFilters.defaults.activeCount, 0);
      expect(mockProfiles.every(DiscoveryFilters.defaults.matches), isTrue);
    });

    test('age range is inclusive', () {
      const filters = DiscoveryFilters(minAge: 28, maxAge: 31);
      expect(filters.matches(only('mock-1')), isTrue, reason: 'age 28');
      expect(filters.matches(only('mock-2')), isTrue, reason: 'age 31');
      expect(filters.matches(only('mock-3')), isFalse, reason: 'age 26');
      expect(filters.matches(only('mock-4')), isFalse, reason: 'age 34');
    });

    test('distance is approximate and inclusive; null means any', () {
      const near = DiscoveryFilters(maxDistanceKm: 5);
      expect(near.matches(only('mock-1')), isTrue, reason: '3 km');
      expect(near.matches(only('mock-4')), isTrue, reason: '5 km');
      expect(near.matches(only('mock-2')), isFalse, reason: '7 km');
      expect(DiscoveryFilters.defaults.matches(only('mock-13')), isTrue);
    });

    test('show me, verified and interests', () {
      const women = DiscoveryFilters(showMe: ShowMe.women);
      expect(women.matches(only('mock-1')), isTrue);
      expect(women.matches(only('mock-2')), isFalse);
      expect(women.matches(only('mock-4')), isFalse, reason: 'LGBTQ+');

      const verified = DiscoveryFilters(verifiedOnly: true);
      expect(verified.matches(only('mock-3')), isFalse);
      expect(verified.matches(only('mock-1')), isTrue);

      const gaming = DiscoveryFilters(interests: {'Gaming'});
      expect(gaming.matches(only('mock-12')), isTrue);
      expect(gaming.matches(only('mock-1')), isFalse);
    });

    test('equality and activeCount', () {
      const a = DiscoveryFilters(
        interests: {'Art', 'Dogs'},
        verifiedOnly: true,
      );
      const b = DiscoveryFilters(
        interests: {'Dogs', 'Art'},
        verifiedOnly: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.activeCount, 2);
      expect(a.copyWith(clearDistance: true).maxDistanceKm, isNull);
    });
  });

  test('distances are only ever shown as coarse bands', () {
    expect(approximateDistanceLabel(0), 'Less than 1 km away');
    expect(approximateDistanceLabel(1), 'Less than 1 km away');
    expect(approximateDistanceLabel(3), 'Within 5 km');
    expect(approximateDistanceLabel(5), 'Within 5 km');
    expect(approximateDistanceLabel(7), 'Within 10 km');
    expect(approximateDistanceLabel(12), 'Within 15 km');
    expect(approximateDistanceLabel(35), 'Within 35 km');
  });
}
