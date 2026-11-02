// ============================================================================
// MOCK DATA ONLY: in-memory wallet and points "ledger"
//
// Balances, NPR equivalents and withdrawal requests live in memory and vanish
// when the app restarts. NOTHING is sent to a bank, payment gateway, payout
// provider or backend ledger. Statuses are mock-recorded, cancelled or
// declined — never paid. Nothing outside `mock_*` files and the approved
// seam may import this file (test/mock_isolation_test.dart).
// ============================================================================

import '../../core/constants/wallet_rules.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/money.dart';
import '../models/profile.dart';
import '../models/wallet.dart';
import 'mock_profile_repository.dart';
import 'repository_contracts.dart';

class MockWalletRepository implements WalletRepository {
  MockWalletRepository({
    MockScenario Function()? scenario,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? now,
    ProfileGender Function()? viewerGender,
  }) : _scenario = scenario ?? (() => MockScenario.populated),
       _now = now ?? DateTime.now,
       _viewerGender = viewerGender ?? (() => ProfileGender.male) {
    reset();
  }

  final MockScenario Function() _scenario;
  final Duration latency;
  final DateTime Function() _now;
  final ProfileGender Function() _viewerGender;

  final List<WalletTransaction> _transactions = [];
  final List<WithdrawalRequest> _withdrawals = [];
  int _counter = 0;
  bool _inFlight = false;

  void reset() {
    _transactions
      ..clear()
      ..addAll(_seedTransactions());
    _withdrawals.clear();
    _counter = 0;
    _inFlight = false;
  }

  /// A declined mock request that does not hold earned points.
  void seedDeclinedHistory() {
    _withdrawals.add(
      WithdrawalRequest(
        id: 'mock-wd-declined',
        points: WalletRules.minWithdrawalPoints,
        feePoints: WalletRules.withdrawalFeePoints,
        netPoints:
            WalletRules.minWithdrawalPoints - WalletRules.withdrawalFeePoints,
        status: WithdrawalStatus.declined,
        createdAt: _now().subtract(const Duration(days: 10)),
        resolvedAt: _now().subtract(const Duration(days: 9)),
      ),
    );
  }

  /// Replace earned ledger rows with exactly [points] earned points.
  void seedEarnedPoints(int points) {
    reset();
    _transactions.removeWhere((tx) => tx.bucket == PointBucket.earned);
    if (points == 0) return;
    _transactions.add(
      WalletTransaction(
        id: 'mock-tx-earned-seed',
        title: 'Eligible messaging',
        credits: points,
        occurredAt: _now().subtract(const Duration(days: 1)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.messageReceived,
        detail:
            'Seeded earned points. Stated NPR equivalent is not cash.',
      ),
    );
  }

  /// Seed with earned points below the 500-point withdrawal threshold.
  void seedInsufficientEarned() {
    reset();
    _transactions.removeWhere((tx) => tx.bucket == PointBucket.earned);
    _transactions.addAll([
      WalletTransaction(
        id: 'mock-tx-msg-low',
        title: 'Eligible messaging',
        credits: 120,
        occurredAt: _now().subtract(const Duration(days: 1)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.messageReceived,
        detail:
            'Points from an eligible paid message. Stated NPR equivalent is '
            'not cash.',
      ),
      WalletTransaction(
        id: 'mock-tx-swipe-low',
        title: 'Paid swipe',
        credits: -WalletRules.swipeSpendPoints,
        occurredAt: _now().subtract(const Duration(hours: 3)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.swipeSpend,
        detail:
            'NPR 0.10 charged to the point wallet as 10 points.',
      ),
    ]);
  }

  List<WalletTransaction> _seedTransactions() {
    final now = _now();
    return [
      WalletTransaction(
        id: 'mock-tx-welcome',
        title: 'Welcome bonus',
        credits: WalletRules.welcomeBonusPoints,
        occurredAt: now.subtract(const Duration(days: 14)),
        bucket: PointBucket.promotional,
        kind: WalletActivityKind.welcomeBonus,
        detail: WalletRules.welcomeBonusExplainer,
      ),
      WalletTransaction(
        id: 'mock-tx-subscription',
        title: 'Subscription reward',
        credits: WalletRules.subscriptionRewardPoints,
        occurredAt: now.subtract(const Duration(days: 8)),
        bucket: PointBucket.promotional,
        kind: WalletActivityKind.subscriptionReward,
        detail:
            '3,000 promotional points from an NPR 100 purchase. Stated '
            'equivalent ${formatNpr(walletPaisaFromPoints(WalletRules.subscriptionRewardPoints))}. '
            'Not withdrawable under the configured redemption policy.',
      ),
      WalletTransaction(
        id: 'mock-tx-msg-1',
        title: 'Eligible messaging',
        credits: 80,
        occurredAt: now.subtract(const Duration(days: 2)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.messageReceived,
        detail:
            'Earned from an eligible paid message. Promotional '
            'points are not included.',
      ),
      WalletTransaction(
        id: 'mock-tx-msg-2',
        title: 'Eligible messaging',
        credits: 420,
        occurredAt: now.subtract(const Duration(days: 1)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.messageReceived,
        detail:
            'Earned from an eligible paid message. Promotional '
            'points are not included.',
      ),
      WalletTransaction(
        id: 'mock-tx-msg-3',
        title: 'Eligible messaging',
        credits: 150,
        occurredAt: now.subtract(const Duration(hours: 5)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.messageReceived,
        detail:
            'Earned from an eligible paid message. Promotional '
            'points are not included.',
      ),
      WalletTransaction(
        id: 'mock-tx-swipe',
        title: 'Paid swipe',
        credits: -WalletRules.swipeSpendPoints,
        occurredAt: now.subtract(const Duration(hours: 3)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.swipeSpend,
        detail:
            'NPR 0.10 charged to the point wallet as 10 points.',
      ),
      WalletTransaction(
        id: 'mock-tx-msg-spend',
        title: 'Paid message',
        credits: -30,
        occurredAt: now.subtract(const Duration(hours: 1)),
        bucket: PointBucket.earned,
        kind: WalletActivityKind.messageSpend,
        detail:
            'Points spent on a paid message charged to the point wallet.',
      ),
    ];
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: latency,
    data: data,
    empty: empty,
  );

  WalletSummary _summary() {
    var promotional = 0;
    var earned = 0;
    for (final tx in _transactions) {
      switch (tx.bucket) {
        case PointBucket.promotional:
          promotional += tx.credits;
        case PointBucket.earned:
          earned += tx.credits;
      }
    }
    final pending = _withdrawals
        .where((item) => item.isOpen)
        .fold<int>(0, (sum, item) => sum + item.points);
    return WalletSummary(
      credits: promotional + earned,
      pendingCredits: pending,
      promotionalPoints: promotional,
      earnedPoints: earned,
      pendingWithdrawalPoints: pending,
    );
  }

  /// Spendable promotional + earned points (same total the header chip shows).
  int get spendable {
    final summary = _summary();
    return summary.promotionalPoints + summary.earnedPoints;
  }

  /// Debits promotional first, then earned. Returns false when funds are short.
  bool tryCharge({
    required int points,
    required String title,
    required WalletActivityKind kind,
    String detail = '',
  }) {
    if (points <= 0) return true;
    final summary = _summary();
    if (summary.promotionalPoints + summary.earnedPoints < points) {
      return false;
    }

    var remaining = points;
    final fromPromo = summary.promotionalPoints < remaining
        ? summary.promotionalPoints
        : remaining;
    if (fromPromo > 0) {
      _counter += 1;
      _transactions.add(
        WalletTransaction(
          id: 'mock-tx-$_counter',
          title: title,
          credits: -fromPromo,
          occurredAt: _now(),
          bucket: PointBucket.promotional,
          kind: kind,
          detail: detail,
        ),
      );
      remaining -= fromPromo;
    }
    if (remaining > 0) {
      _counter += 1;
      _transactions.add(
        WalletTransaction(
          id: 'mock-tx-$_counter',
          title: title,
          credits: -remaining,
          occurredAt: _now(),
          bucket: PointBucket.earned,
          kind: kind,
          detail: detail,
        ),
      );
    }
    return true;
  }

  /// Credits promotional points (daily free grant, refunds, etc.).
  void creditPromotional({
    required int points,
    required String title,
    required WalletActivityKind kind,
    String detail = '',
    String? id,
  }) {
    if (points <= 0) return;
    if (id != null && _transactions.any((tx) => tx.id == id)) return;
    _counter += 1;
    _transactions.add(
      WalletTransaction(
        id: id ?? 'mock-tx-$_counter',
        title: title,
        credits: points,
        occurredAt: _now(),
        bucket: PointBucket.promotional,
        kind: kind,
        detail: detail,
      ),
    );
  }

  /// Credits earned points (refund of a prior earned spend).
  void creditEarned({
    required int points,
    required String title,
    required WalletActivityKind kind,
    String detail = '',
  }) {
    if (points <= 0) return;
    _counter += 1;
    _transactions.add(
      WalletTransaction(
        id: 'mock-tx-$_counter',
        title: title,
        credits: points,
        occurredAt: _now(),
        bucket: PointBucket.earned,
        kind: kind,
        detail: detail,
      ),
    );
  }

  bool get _eligibleAccount {
    final gender = _viewerGender();
    return gender.canWithdrawAndSetDailyPreference;
  }

  @override
  WithdrawalEligibility eligibility() {
    final summary = _summary();
    final earnedAvailable = summary.availableEarnedPoints;
    final eligibleAccount = _eligibleAccount;
    final belowMinimum = earnedAvailable < WalletRules.minWithdrawalPoints;
    final hasOpen = _withdrawals.any((item) => item.isOpen);
    final canSubmit =
        eligibleAccount && !belowMinimum && !hasOpen && earnedAvailable > 0;

    final explanation = !eligibleAccount
        ? 'Withdrawals are only available to female, LGBTQ+ and other '
              'accounts. Promotional points never count.'
        : belowMinimum
        ? 'You need at least ${WalletRules.minWithdrawalPoints} earned, '
              'withdrawable points (${formatNpr(walletPaisaFromPoints(WalletRules.minWithdrawalPoints))} '
              'equivalent). You have $earnedAvailable earned points. '
              'Promotional points never count toward this threshold.'
        : hasOpen
        ? 'A withdrawal is already recorded. Cancel it before recording '
              'another.'
        : 'You can record a withdrawal of earned points. Promotional '
              'points are excluded. A displayed equivalent is not cash.';

    return WithdrawalEligibility(
      eligibleAccount: eligibleAccount,
      earnedAvailable: earnedAvailable,
      minimumPoints: WalletRules.minWithdrawalPoints,
      canSubmit: canSubmit,
      explanation: explanation,
    );
  }

  @override
  Future<WithdrawalEligibility> fetchEligibility() => _fetch(
    eligibility,
    const WithdrawalEligibility(
      eligibleAccount: false,
      earnedAvailable: 0,
      minimumPoints: WalletRules.minWithdrawalPoints,
      canSubmit: false,
      explanation: '',
    ),
  );

  @override
  Future<WalletSummary> fetchSummary() =>
      _fetch(_summary, const WalletSummary());

  @override
  Future<List<WalletTransaction>> fetchTransactions() => _fetch(() {
    final items = [..._transactions]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }, const []);

  @override
  Future<WalletTransaction?> fetchTransaction(String id) => _fetch(() {
    for (final tx in _transactions) {
      if (tx.id == id) return tx;
    }
    return null;
  }, null);

  @override
  Future<List<WithdrawalRequest>> fetchWithdrawals() => _fetch(() {
    final items = [..._withdrawals]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }, const []);

  @override
  Future<WithdrawalRequest?> fetchWithdrawal(String id) => _fetch(() {
    for (final item in _withdrawals) {
      if (item.id == id) return item;
    }
    return null;
  }, null);

  @override
  Future<WithdrawalRequest> submitWithdrawal({
    required int points,
    required bool confirmed,
  }) async {
    if (_inFlight) {
      throw const ValidationFailure(
        'A withdrawal is already being recorded.',
      );
    }
    if (!confirmed) {
      throw const ValidationFailure(
        'Confirm this request first.',
      );
    }
    final current = eligibility();
    if (!current.eligibleAccount) {
      throw ValidationFailure(current.explanation);
    }
    if (points < WalletRules.minWithdrawalPoints) {
      throw ValidationFailure(
        'The configured minimum is ${WalletRules.minWithdrawalPoints} earned '
        'points (${formatNpr(walletPaisaFromPoints(WalletRules.minWithdrawalPoints))} '
        'equivalent). Promotional points do not count.',
      );
    }
    if (points > current.earnedAvailable) {
      throw const ValidationFailure(
        'There are not enough earned, withdrawable points for this '
        'request. Promotional points cannot be used.',
      );
    }
    if (_withdrawals.any((item) => item.isOpen)) {
      throw const ValidationFailure(
        'A withdrawal is already recorded.',
      );
    }

    _inFlight = true;
    try {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      if (_scenario() == MockScenario.failure) {
        throw const NetworkFailure();
      }
      _counter += 1;
      final fee = WalletRules.withdrawalFeePoints;
      final request = WithdrawalRequest(
        id: 'mock-wd-$_counter',
        points: points,
        feePoints: fee,
        netPoints: points - fee,
        status: WithdrawalStatus.recorded,
        createdAt: _now(),
      );
      _withdrawals.insert(0, request);
      _transactions.add(
        WalletTransaction(
          id: 'mock-tx-hold-${request.id}',
          title: 'Withdrawal hold',
          credits: -points,
          occurredAt: request.createdAt,
          bucket: PointBucket.earned,
          kind: WalletActivityKind.withdrawalHold,
          detail: WalletRules.mockRequestNote,
        ),
      );
      return request;
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<WithdrawalRequest> cancelWithdrawal(String id) async {
    if (_inFlight) {
      throw const ValidationFailure(
        'A withdrawal is already being updated.',
      );
    }
    final index = _withdrawals.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const NotFoundFailure('That withdrawal is no longer here.');
    }
    final current = _withdrawals[index];
    if (!current.isOpen) {
      throw const ValidationFailure(
        'That withdrawal is no longer recorded as open.',
      );
    }

    _inFlight = true;
    try {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      if (_scenario() == MockScenario.failure) {
        throw const NetworkFailure();
      }
      final updated = current.copyWith(
        status: WithdrawalStatus.cancelled,
        resolvedAt: _now(),
      );
      _withdrawals[index] = updated;
      _transactions.add(
        WalletTransaction(
          id: 'mock-tx-release-${updated.id}',
          title: 'Withdrawal released',
          credits: updated.points,
          occurredAt: updated.resolvedAt!,
          bucket: PointBucket.earned,
          kind: WalletActivityKind.withdrawalRelease,
          detail:
              'The hold was released. Nothing was sent to a bank or payout '
              'provider.',
        ),
      );
      return updated;
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<({int points, String bucket, int spendablePoints})> redeemPromo(
    String code,
  ) async {
    final trimmed = code.trim();
    if (trimmed.length < 3) {
      throw const ValidationFailure('Enter a promo code.');
    }
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (_scenario() == MockScenario.failure) {
      throw const NetworkFailure();
    }
    const points = 100;
    creditPromotional(
      points: points,
      title: 'Promo code',
      kind: WalletActivityKind.other,
      detail: 'Mock redeem of $trimmed',
    );
    return (
      points: points,
      bucket: 'promotional',
      spendablePoints: spendable,
    );
  }
}
