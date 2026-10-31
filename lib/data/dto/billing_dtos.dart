import 'package:flutter/foundation.dart';

import '../models/referral_info.dart';
import '../models/subscription_plan.dart';
import '../models/wallet.dart';
import 'json_codec.dart';
import 'typed_values.dart';

@immutable
class SubscriptionPlanDto {
  const SubscriptionPlanDto({
    required this.id,
    required this.name,
    required this.pricePaisa,
    required this.periodLabel,
    required this.features,
    this.isPopular = false,
    this.savingsLabel,
    this.isRecurring = false,
    this.priceLabel,
  });

  final PlanId id;
  final String name;
  final Paisa pricePaisa;
  final String periodLabel;
  final List<String> features;
  final bool isPopular;
  final String? savingsLabel;
  final bool isRecurring;
  final String? priceLabel;

  factory SubscriptionPlanDto.fromJson(Object? json) =>
      SubscriptionPlanDto.fromMap(JsonMap.from(json));

  factory SubscriptionPlanDto.fromMap(JsonMap map) => SubscriptionPlanDto(
    id: readPlanId(map),
    name: map.string('name'),
    pricePaisa: Paisa.read(map, 'pricePaisa'),
    periodLabel: map.string('periodLabel'),
    features: map.contains('features') ? map.stringList('features') : const [],
    isPopular: map.optionalBoolean('isPopular') ?? false,
    savingsLabel: map.optionalString('savingsLabel'),
    isRecurring: map.optionalBoolean('isRecurring') ?? false,
    priceLabel: map.optionalString('priceLabel'),
  );

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'name': name,
    'pricePaisa': pricePaisa.toJson(),
    'periodLabel': periodLabel,
    'features': features,
    'isPopular': isPopular,
    'savingsLabel': savingsLabel,
    'isRecurring': isRecurring,
    'priceLabel': priceLabel,
  };

  SubscriptionPlan toDomain() => SubscriptionPlan(
    id: id.raw,
    name: name,
    priceLabel: priceLabel ?? _formatPaisaLabel(pricePaisa.paisa),
    periodLabel: periodLabel,
    features: features,
    isPopular: isPopular,
    savingsLabel: savingsLabel,
    pricePaisa: pricePaisa.paisa,
    isRecurring: isRecurring,
  );
}

String _formatPaisaLabel(int paisa) {
  final rupees = paisa ~/ 100;
  final cents = (paisa.abs() % 100).toString().padLeft(2, '0');
  return 'NPR $rupees.$cents';
}

@immutable
class ActiveSubscriptionDto {
  const ActiveSubscriptionDto({
    required this.plan,
    required this.startedAt,
    this.renewsAt,
    this.cancelledAt,
    this.referralLinked = false,
    this.complimentary = false,
  });

  final SubscriptionPlanDto plan;
  final DateTime startedAt;
  final DateTime? renewsAt;
  final DateTime? cancelledAt;
  final bool referralLinked;
  final bool complimentary;

  factory ActiveSubscriptionDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return ActiveSubscriptionDto(
      plan: SubscriptionPlanDto.fromMap(map.object('plan')),
      startedAt: map.dateTime('startedAt'),
      renewsAt: map.optionalDateTime('renewsAt'),
      cancelledAt: map.optionalDateTime('cancelledAt'),
      referralLinked: map.optionalBoolean('referralLinked') ?? false,
      complimentary: map.optionalBoolean('complimentary') ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'plan': plan.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'renewsAt': renewsAt?.toUtc().toIso8601String(),
    'cancelledAt': cancelledAt?.toUtc().toIso8601String(),
    'referralLinked': referralLinked,
    'complimentary': complimentary,
  };

  ActiveSubscription toDomain() => ActiveSubscription(
    plan: plan.toDomain(),
    startedAt: startedAt,
    renewsAt: renewsAt,
    cancelledAt: cancelledAt,
    referralLinked: referralLinked,
    complimentary: complimentary,
  );
}

@immutable
class SubscriptionOverviewDto {
  const SubscriptionOverviewDto({
    required this.needsPaidSubscription,
    required this.complimentary,
    required this.hasPremiumAccess,
    this.paymentsEnabled = false,
    this.isLive = false,
    this.active,
  });

  final bool needsPaidSubscription;
  final bool complimentary;
  final bool hasPremiumAccess;
  final bool paymentsEnabled;
  final bool isLive;
  final ActiveSubscriptionDto? active;

  factory SubscriptionOverviewDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    final nested = map.optionalObject('active');
    return SubscriptionOverviewDto(
      needsPaidSubscription: map.boolean('needsPaidSubscription'),
      complimentary: map.boolean('complimentary'),
      hasPremiumAccess: map.boolean('hasPremiumAccess'),
      paymentsEnabled: map.optionalBoolean('paymentsEnabled') ?? false,
      isLive: map.optionalBoolean('isLive') ?? false,
      active: nested == null ? null : ActiveSubscriptionDto.fromJson(nested.asMap()),
    );
  }
}

@immutable
class PaymentStatusDto {
  const PaymentStatusDto({
    required this.id,
    required this.outcome,
    required this.amountPaisa,
    required this.createdAt,
    this.resolvedAt,
  });

  final PurchaseId id;
  final PaymentOutcome outcome;
  final Paisa amountPaisa;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory PaymentStatusDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return PaymentStatusDto(
      id: readPurchaseId(map),
      outcome: map.enumValue('outcome', PaymentOutcome.values),
      amountPaisa: Paisa.read(map, 'amountPaisa'),
      createdAt: map.dateTime('createdAt'),
      resolvedAt: map.optionalDateTime('resolvedAt'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'outcome': outcome.name,
    'amountPaisa': amountPaisa.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
  };
}

@immutable
class PurchaseRecordDto {
  const PurchaseRecordDto({
    required this.id,
    required this.plan,
    required this.amountPaisa,
    required this.outcome,
    required this.createdAt,
    required this.referralLinked,
    required this.methodId,
    required this.methodName,
    this.resolvedAt,
  });

  final PurchaseId id;
  final SubscriptionPlanDto plan;
  final Paisa amountPaisa;
  final PaymentOutcome outcome;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool referralLinked;
  final String methodId;
  final String methodName;

  factory PurchaseRecordDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return PurchaseRecordDto(
      id: readPurchaseId(map),
      plan: SubscriptionPlanDto.fromMap(map.object('plan')),
      amountPaisa: Paisa.read(map, 'amountPaisa'),
      outcome: map.enumValue('outcome', PaymentOutcome.values),
      createdAt: map.dateTime('createdAt'),
      resolvedAt: map.optionalDateTime('resolvedAt'),
      referralLinked: map.boolean('referralLinked'),
      methodId: map.string('methodId'),
      methodName: map.string('methodName'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'plan': plan.toJson(),
    'amountPaisa': amountPaisa.toJson(),
    'outcome': outcome.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
    'referralLinked': referralLinked,
    'methodId': methodId,
    'methodName': methodName,
  };

  PurchaseRecord toDomain() => PurchaseRecord(
    id: id.raw,
    plan: plan.toDomain(),
    amountPaisa: amountPaisa.paisa,
    outcome: outcome,
    createdAt: createdAt,
    resolvedAt: resolvedAt,
    referralLinked: referralLinked,
    methodId: methodId,
    methodName: methodName,
  );
}

@immutable
class PointBalanceDto {
  const PointBalanceDto({
    required this.promotionalPoints,
    required this.earnedPoints,
    this.pendingWithdrawalPoints = const Points(0),
  });

  final Points promotionalPoints;
  final Points earnedPoints;
  final Points pendingWithdrawalPoints;

  factory PointBalanceDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return PointBalanceDto(
      promotionalPoints: Points.read(map, 'promotionalPoints'),
      earnedPoints: Points.read(map, 'earnedPoints'),
      pendingWithdrawalPoints: Points.readOptional(
        map,
        'pendingWithdrawalPoints',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'promotionalPoints': promotionalPoints.toJson(),
    'earnedPoints': earnedPoints.toJson(),
    'pendingWithdrawalPoints': pendingWithdrawalPoints.toJson(),
  };

  WalletSummary toDomain() {
    final promotional = promotionalPoints.points;
    final earned = earnedPoints.points;
    return WalletSummary(
      credits: promotional + earned,
      pendingCredits: pendingWithdrawalPoints.points,
      promotionalPoints: promotional,
      earnedPoints: earned,
      pendingWithdrawalPoints: pendingWithdrawalPoints.points,
    );
  }
}

@immutable
class WalletTransactionDto {
  const WalletTransactionDto({
    required this.id,
    required this.title,
    required this.points,
    required this.occurredAt,
    required this.bucket,
    this.kind = WalletActivityKind.other,
    this.detail = '',
  });

  final TransactionId id;
  final String title;
  final Points points;
  final DateTime occurredAt;
  final PointBucket bucket;
  final WalletActivityKind kind;
  final String detail;

  factory WalletTransactionDto.fromJson(Object? json) =>
      WalletTransactionDto.fromMap(JsonMap.from(json));

  factory WalletTransactionDto.fromMap(JsonMap map) => WalletTransactionDto(
    id: readTransactionId(map),
    title: map.string('title'),
    points: Points.read(map, 'points'),
    occurredAt: map.dateTime('occurredAt'),
    bucket: map.enumValue('bucket', PointBucket.values),
    kind:
        map.optionalEnum('kind', WalletActivityKind.values) ??
        WalletActivityKind.other,
    detail: map.optionalString('detail', allowEmpty: true) ?? '',
  );

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'title': title,
    'points': points.toJson(),
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'bucket': bucket.name,
    'kind': kind.name,
    'detail': detail,
  };

  WalletTransaction toDomain() => WalletTransaction(
    id: id.raw,
    title: title,
    credits: points.points,
    occurredAt: occurredAt,
    bucket: bucket,
    kind: kind,
    detail: detail,
  );
}

@immutable
class WithdrawalRequestDto {
  const WithdrawalRequestDto({
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

  final WithdrawalId id;
  final Points points;
  final Points feePoints;
  final Points netPoints;
  final WithdrawalStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool isLive;
  final bool payoutsEnabled;

  factory WithdrawalRequestDto.fromJson(Object? json) =>
      WithdrawalRequestDto.fromMap(JsonMap.from(json));

  factory WithdrawalRequestDto.fromMap(JsonMap map) => WithdrawalRequestDto(
    id: readWithdrawalId(map),
    points: Points.read(map, 'points'),
    feePoints: Points.read(map, 'feePoints'),
    netPoints: Points.read(map, 'netPoints'),
    status: map.enumValue('status', WithdrawalStatus.values),
    createdAt: map.dateTime('createdAt'),
    resolvedAt: map.optionalDateTime('resolvedAt'),
    isLive: map.optionalBoolean('isLive') ?? false,
    payoutsEnabled: map.optionalBoolean('payoutsEnabled') ?? false,
  );

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'points': points.toJson(),
    'feePoints': feePoints.toJson(),
    'netPoints': netPoints.toJson(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
    'isLive': isLive,
    'payoutsEnabled': payoutsEnabled,
  };

  WithdrawalRequest toDomain() => WithdrawalRequest(
    id: id.raw,
    points: points.points,
    feePoints: feePoints.points,
    netPoints: netPoints.points,
    status: status,
    createdAt: createdAt,
    resolvedAt: resolvedAt,
    isLive: isLive,
    payoutsEnabled: payoutsEnabled,
  );
}

@immutable
class WithdrawalEligibilityDto {
  const WithdrawalEligibilityDto({
    required this.eligibleAccount,
    required this.earnedAvailable,
    required this.minimumPoints,
    required this.canSubmit,
    required this.explanation,
    this.feePoints = const Points(0),
    this.isLive = false,
    this.payoutsEnabled = false,
  });

  final bool eligibleAccount;
  final Points earnedAvailable;
  final Points minimumPoints;
  final bool canSubmit;
  final String explanation;
  final Points feePoints;
  final bool isLive;
  final bool payoutsEnabled;

  factory WithdrawalEligibilityDto.fromJson(Object? json) =>
      WithdrawalEligibilityDto.fromMap(JsonMap.from(json));

  factory WithdrawalEligibilityDto.fromMap(JsonMap map) =>
      WithdrawalEligibilityDto(
        eligibleAccount: map.boolean('eligibleAccount'),
        earnedAvailable: Points.read(map, 'earnedAvailable'),
        minimumPoints: Points.read(map, 'minimumPoints'),
        canSubmit: map.boolean('canSubmit'),
        explanation: map.string('explanation'),
        feePoints: Points.readOptional(map, 'feePoints'),
        isLive: map.optionalBoolean('isLive') ?? false,
        payoutsEnabled: map.optionalBoolean('payoutsEnabled') ?? false,
      );

  Map<String, Object?> toJson() => {
    'eligibleAccount': eligibleAccount,
    'earnedAvailable': earnedAvailable.toJson(),
    'minimumPoints': minimumPoints.toJson(),
    'feePoints': feePoints.toJson(),
    'canSubmit': canSubmit,
    'explanation': explanation,
    'isLive': isLive,
    'payoutsEnabled': payoutsEnabled,
  };

  WithdrawalEligibility toDomain() => WithdrawalEligibility(
    eligibleAccount: eligibleAccount,
    earnedAvailable: earnedAvailable.points,
    minimumPoints: minimumPoints.points,
    canSubmit: canSubmit,
    explanation: explanation,
    isLive: isLive,
    payoutsEnabled: payoutsEnabled,
    feePoints: feePoints.points,
  );
}

@immutable
class ReferralInfoDto {
  const ReferralInfoDto({
    required this.code,
    this.inviteLink = '',
    this.shareMessage = '',
    this.isLive = false,
    this.payoutsEnabled = false,
    this.invitesSent = 0,
    this.friendsJoined = 0,
    this.qualifyingPurchases = 0,
    this.pendingCommissionPaisa = const Paisa(0),
    this.approvedCommissionPaisa = const Paisa(0),
    this.paidCommissionPaisa = const Paisa(0),
    this.reversedCommissionPaisa = const Paisa(0),
  });

  final String code;
  final String inviteLink;
  final String shareMessage;
  final bool isLive;
  final bool payoutsEnabled;
  final int invitesSent;
  final int friendsJoined;
  final int qualifyingPurchases;
  final Paisa pendingCommissionPaisa;
  final Paisa approvedCommissionPaisa;
  final Paisa paidCommissionPaisa;
  final Paisa reversedCommissionPaisa;

  factory ReferralInfoDto.fromJson(Object? json) =>
      ReferralInfoDto.fromMap(JsonMap.from(json));

  factory ReferralInfoDto.fromMap(JsonMap map) {
    return ReferralInfoDto(
      code: map.string('code'),
      inviteLink: map.optionalString('inviteLink', allowEmpty: true) ?? '',
      shareMessage: map.optionalString('shareMessage', allowEmpty: true) ?? '',
      isLive: map.optionalBoolean('isLive') ?? false,
      payoutsEnabled: map.optionalBoolean('payoutsEnabled') ?? false,
      invitesSent: map.optionalInteger('invitesSent') ?? 0,
      friendsJoined: map.optionalInteger('friendsJoined') ?? 0,
      qualifyingPurchases: map.optionalInteger('qualifyingPurchases') ?? 0,
      pendingCommissionPaisa: Paisa.readOptional(map, 'pendingCommissionPaisa'),
      approvedCommissionPaisa: Paisa.readOptional(
        map,
        'approvedCommissionPaisa',
      ),
      paidCommissionPaisa: Paisa.readOptional(map, 'paidCommissionPaisa'),
      reversedCommissionPaisa: Paisa.readOptional(
        map,
        'reversedCommissionPaisa',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'code': code,
    'inviteLink': inviteLink,
    'shareMessage': shareMessage,
    'isLive': isLive,
    'payoutsEnabled': payoutsEnabled,
    'invitesSent': invitesSent,
    'friendsJoined': friendsJoined,
    'qualifyingPurchases': qualifyingPurchases,
    'pendingCommissionPaisa': pendingCommissionPaisa.toJson(),
    'approvedCommissionPaisa': approvedCommissionPaisa.toJson(),
    'paidCommissionPaisa': paidCommissionPaisa.toJson(),
    'reversedCommissionPaisa': reversedCommissionPaisa.toJson(),
  };

  ReferralInfo toDomain() => ReferralInfo(
    code: code,
    inviteLink: inviteLink,
    shareMessage: shareMessage,
    isLive: isLive,
    payoutsEnabled: payoutsEnabled,
    invitesSent: invitesSent,
    friendsJoined: friendsJoined,
    qualifyingPurchases: qualifyingPurchases,
    pendingCommissionPaisa: pendingCommissionPaisa.paisa,
    approvedCommissionPaisa: approvedCommissionPaisa.paisa,
    paidCommissionPaisa: paidCommissionPaisa.paisa,
    reversedCommissionPaisa: reversedCommissionPaisa.paisa,
    creditsEarned:
        (approvedCommissionPaisa.paisa + paidCommissionPaisa.paisa) ~/ 10,
  );
}

@immutable
class ReferralInviteDto {
  const ReferralInviteDto({
    required this.id,
    required this.displayName,
    required this.status,
    required this.createdAt,
    this.detail = '',
  });

  final ReferralInviteId id;
  final String displayName;
  final ReferralInviteStatus status;
  final DateTime createdAt;
  final String detail;

  factory ReferralInviteDto.fromJson(Object? json) =>
      ReferralInviteDto.fromMap(JsonMap.from(json));

  factory ReferralInviteDto.fromMap(JsonMap map) => ReferralInviteDto(
    id: readReferralInviteId(map),
    displayName: map.string('displayName'),
    status: map.enumValue('status', ReferralInviteStatus.values),
    createdAt: map.dateTime('createdAt'),
    detail: map.optionalString('detail', allowEmpty: true) ?? '',
  );

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'displayName': displayName,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'detail': detail,
  };

  ReferralInvite toDomain() => ReferralInvite(
    id: id.raw,
    displayName: displayName,
    status: status,
    createdAt: createdAt,
    detail: detail,
  );
}

@immutable
class ReferralCommissionDto {
  const ReferralCommissionDto({
    required this.id,
    required this.inviteId,
    required this.personName,
    required this.amountPaisa,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.detail = '',
  });

  final CommissionId id;
  final ReferralInviteId inviteId;
  final String personName;
  final Paisa amountPaisa;
  final CommissionStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String detail;

  factory ReferralCommissionDto.fromJson(Object? json) =>
      ReferralCommissionDto.fromMap(JsonMap.from(json));

  factory ReferralCommissionDto.fromMap(JsonMap map) => ReferralCommissionDto(
    id: readCommissionId(map),
    inviteId: readReferralInviteId(map, 'inviteId'),
    personName: map.string('personName'),
    amountPaisa: Paisa.read(map, 'amountPaisa'),
    status: map.enumValue('status', CommissionStatus.values),
    createdAt: map.dateTime('createdAt'),
    resolvedAt: map.optionalDateTime('resolvedAt'),
    detail: map.optionalString('detail', allowEmpty: true) ?? '',
  );

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'inviteId': inviteId.raw,
    'personName': personName,
    'amountPaisa': amountPaisa.toJson(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
    'detail': detail,
  };

  ReferralCommission toDomain() => ReferralCommission(
    id: id.raw,
    inviteId: inviteId.raw,
    personName: personName,
    amountPaisa: amountPaisa.paisa,
    status: status,
    createdAt: createdAt,
    resolvedAt: resolvedAt,
    detail: detail,
  );
}
