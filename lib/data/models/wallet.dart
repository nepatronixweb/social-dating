import 'package:flutter/foundation.dart';

enum PointBucket { promotional, earned }

enum WalletActivityKind {
  welcomeBonus,
  subscriptionReward,
  messageReceived,
  swipeSpend,
  messageSpend,
  withdrawalHold,
  withdrawalRelease,
  other,
}

enum WithdrawalStatus { recorded, cancelled, declined }

enum WalletActivityFilter { all, promotional, earned, added, spent }

@immutable
class WalletSummary {
  const WalletSummary({
    this.credits = 0,
    this.pendingCredits = 0,
    this.promotionalPoints = 0,
    this.earnedPoints = 0,
    this.pendingWithdrawalPoints = 0,
  });

  /// Total points (promotional + earned). Kept for older summary cards.
  final int credits;
  final int pendingCredits;
  final int promotionalPoints;
  final int earnedPoints;

  /// Earned points held for a mock withdrawal that is still recorded.
  /// Informational only; [earnedPoints] is already net of holds.
  final int pendingWithdrawalPoints;

  /// Withdrawable earned points. Promotional points are never included.
  int get availableEarnedPoints => earnedPoints < 0 ? 0 : earnedPoints;

  int get totalPoints => promotionalPoints + earnedPoints;
}

List<WalletTransaction> applyWalletFilter(
  List<WalletTransaction> items,
  WalletActivityFilter filter,
) => items
    .where(
      (tx) => switch (filter) {
        WalletActivityFilter.all => true,
        WalletActivityFilter.promotional =>
          tx.bucket == PointBucket.promotional,
        WalletActivityFilter.earned => tx.bucket == PointBucket.earned,
        WalletActivityFilter.added => tx.isCredit,
        WalletActivityFilter.spent => !tx.isCredit,
      },
    )
    .toList();

@immutable
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.title,
    required this.credits,
    required this.occurredAt,
    this.bucket = PointBucket.earned,
    this.kind = WalletActivityKind.other,
    this.detail = '',
  });

  final String id;
  final String title;

  /// Signed points. Positive is a credit, negative is a spend.
  final int credits;
  final DateTime occurredAt;
  final PointBucket bucket;
  final WalletActivityKind kind;
  final String detail;

  int get points => credits;
  bool get isCredit => credits >= 0;
}

@immutable
class WithdrawalRequest {
  const WithdrawalRequest({
    required this.id,
    required this.points,
    required this.feePoints,
    required this.netPoints,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.isLive = false,
    this.payoutsEnabled = false,
  });

  final String id;
  final int points;
  final int feePoints;
  final int netPoints;
  final WithdrawalStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool isLive;
  final bool payoutsEnabled;

  bool get isOpen => status == WithdrawalStatus.recorded;

  WithdrawalRequest copyWith({
    WithdrawalStatus? status,
    DateTime? resolvedAt,
  }) => WithdrawalRequest(
    id: id,
    points: points,
    feePoints: feePoints,
    netPoints: netPoints,
    status: status ?? this.status,
    createdAt: createdAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    isLive: isLive,
    payoutsEnabled: payoutsEnabled,
  );
}

@immutable
class WithdrawalEligibility {
  const WithdrawalEligibility({
    required this.eligibleAccount,
    required this.earnedAvailable,
    required this.minimumPoints,
    required this.canSubmit,
    required this.explanation,
    this.isLive = false,
    this.payoutsEnabled = false,
    this.feePoints = 0,
  });

  /// Female, LGBTQ+ and other accounts.
  final bool eligibleAccount;
  final int earnedAvailable;
  final int minimumPoints;
  final bool canSubmit;
  final String explanation;
  final bool isLive;
  final bool payoutsEnabled;
  final int feePoints;

  bool get belowMinimum => earnedAvailable < minimumPoints;
}
