import 'package:flutter/foundation.dart';

import '../../core/constants/referral_rules.dart';

enum ReferralInviteStatus { invited, joined, purchased, refunded }

enum CommissionStatus { pending, approved, reversed, paid }

@immutable
class ReferralAllocation {
  const ReferralAllocation({
    required this.purchasePaisa,
    required this.companyPaisa,
    required this.buyerRewardEquivalentPaisa,
    required this.referrerCommissionPaisa,
  });

  factory ReferralAllocation.qualifyingNpr100() => const ReferralAllocation(
    purchasePaisa: ReferralRules.qualifyingPurchasePaisa,
    companyPaisa: ReferralRules.companyAllocationPaisa,
    buyerRewardEquivalentPaisa: ReferralRules.buyerRewardEquivalentPaisa,
    referrerCommissionPaisa: ReferralRules.referrerCommissionPaisa,
  );

  final int purchasePaisa;
  final int companyPaisa;
  final int buyerRewardEquivalentPaisa;
  final int referrerCommissionPaisa;

  int get allocatedPaisa =>
      companyPaisa + buyerRewardEquivalentPaisa + referrerCommissionPaisa;
}

@immutable
class ReferralInfo {
  const ReferralInfo({
    required this.code,
    this.inviteLink = '',
    this.shareMessage = '',
    this.isLive = false,
    this.payoutsEnabled = false,
    this.invitesSent = 0,
    this.friendsJoined = 0,
    this.creditsEarned = 0,
    this.qualifyingPurchases = 0,
    this.pendingCommissionPaisa = 0,
    this.approvedCommissionPaisa = 0,
    this.paidCommissionPaisa = 0,
    this.reversedCommissionPaisa = 0,
  });

  final String code;
  final String inviteLink;
  final String shareMessage;

  /// True when codes and joins are stored on the API. Payouts still need a
  /// provider; see [payoutsEnabled].
  final bool isLive;
  final bool payoutsEnabled;
  final int invitesSent;
  final int friendsJoined;

  /// Legacy display field. Prefer commission paisa totals.
  final int creditsEarned;
  final int qualifyingPurchases;
  final int pendingCommissionPaisa;
  final int approvedCommissionPaisa;
  final int paidCommissionPaisa;
  final int reversedCommissionPaisa;

  String get link =>
      inviteLink.isEmpty ? ReferralRules.inviteLink(code) : inviteLink;

  String get shareText =>
      shareMessage.isEmpty ? ReferralRules.shareMessage(code) : shareMessage;

  String get mockLink => link;
}

@immutable
class ReferralInvite {
  const ReferralInvite({
    required this.id,
    required this.displayName,
    required this.status,
    required this.createdAt,
    this.detail = '',
  });

  final String id;
  final String displayName;
  final ReferralInviteStatus status;
  final DateTime createdAt;
  final String detail;
}

@immutable
class ReferralCommission {
  const ReferralCommission({
    required this.id,
    required this.inviteId,
    required this.personName,
    required this.amountPaisa,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.detail = '',
  });

  final String id;
  final String inviteId;
  final String personName;
  final int amountPaisa;
  final CommissionStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String detail;

  ReferralCommission copyWith({
    CommissionStatus? status,
    DateTime? resolvedAt,
    String? detail,
  }) => ReferralCommission(
    id: id,
    inviteId: inviteId,
    personName: personName,
    amountPaisa: amountPaisa,
    status: status ?? this.status,
    createdAt: createdAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    detail: detail ?? this.detail,
  );
}

int commissionTotal(List<ReferralCommission> items, CommissionStatus status) =>
    items
        .where((item) => item.status == status)
        .fold<int>(0, (sum, item) => sum + item.amountPaisa);
