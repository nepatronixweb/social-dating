import 'package:flutter/foundation.dart';

import '../../core/constants/subscription_rules.dart';
import '../../core/utils/money.dart';

@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.periodLabel,
    required this.features,
    this.isPopular = false,
    this.savingsLabel,
    this.pricePaisa = 0,
    this.isRecurring = false,
  });

  final String id;
  final String name;

  /// Preformatted display price. Real prices must come from the store/backend.
  final String priceLabel;
  final String periodLabel;
  final List<String> features;
  final bool isPopular;
  final String? savingsLabel;

  /// Integer paisa for quotes. Zero on sample cards that only have a label.
  final int pricePaisa;

  /// When true, the active-state UI may offer renewal or cancellation.
  final bool isRecurring;

  SubscriptionPlan pricedAt(int amountPaisa) {
    final monthly = isRecurring;
    return SubscriptionPlan(
      id: id,
      name: name,
      priceLabel: formatNpr(amountPaisa),
      periodLabel: periodLabel,
      features: monthly
          ? SubscriptionRules.monthlyFeaturesFor(amountPaisa)
          : SubscriptionRules.standardFeaturesFor(amountPaisa),
      isPopular: isPopular,
      savingsLabel: savingsLabel,
      pricePaisa: amountPaisa,
      isRecurring: isRecurring,
    );
  }
}

/// Illustrative payment option. Not connected to a gateway.
@immutable
class PaymentMethodOption {
  const PaymentMethodOption({
    required this.id,
    required this.name,
    required this.subtitle,
  });

  final String id;
  final String name;
  final String subtitle;
}

enum PaymentOutcome { pending, succeeded, failed, cancelled }

@immutable
class PurchaseRecord {
  const PurchaseRecord({
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

  final String id;
  final SubscriptionPlan plan;
  final int amountPaisa;
  final PaymentOutcome outcome;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final bool referralLinked;
  final String methodId;
  final String methodName;

  bool get isPending => outcome == PaymentOutcome.pending;

  PurchaseRecord copyWith({PaymentOutcome? outcome, DateTime? resolvedAt}) =>
      PurchaseRecord(
        id: id,
        plan: plan,
        amountPaisa: amountPaisa,
        outcome: outcome ?? this.outcome,
        createdAt: createdAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        referralLinked: referralLinked,
        methodId: methodId,
        methodName: methodName,
      );
}

@immutable
class ActiveSubscription {
  const ActiveSubscription({
    required this.plan,
    required this.startedAt,
    this.renewsAt,
    this.cancelledAt,
    this.referralLinked = false,
    this.complimentary = false,
  });

  factory ActiveSubscription.complimentary({required DateTime startedAt}) =>
      ActiveSubscription(
        plan: const SubscriptionPlan(
          id: SubscriptionRules.complimentaryPlanId,
          name: SubscriptionRules.complimentaryPlanName,
          priceLabel: 'Included',
          periodLabel: SubscriptionRules.complimentaryPeriodLabel,
          features: SubscriptionRules.complimentaryFeatures,
        ),
        startedAt: startedAt,
        complimentary: true,
      );

  final SubscriptionPlan plan;
  final DateTime startedAt;
  final DateTime? renewsAt;
  final DateTime? cancelledAt;
  final bool referralLinked;
  final bool complimentary;

  bool get isRecurring => plan.isRecurring;
  bool get renewalCancelled => cancelledAt != null;

  ActiveSubscription copyWith({
    DateTime? renewsAt,
    DateTime? cancelledAt,
    bool clearRenewsAt = false,
  }) => ActiveSubscription(
    plan: plan,
    startedAt: startedAt,
    renewsAt: clearRenewsAt ? null : (renewsAt ?? this.renewsAt),
    cancelledAt: cancelledAt ?? this.cancelledAt,
    referralLinked: referralLinked,
    complimentary: complimentary,
  );
}

/// Local quote for an NPR 100-style purchase. Display preview only. When an
/// API contract exists the backend amount, tax and allocation are
/// authoritative; this object must not be charged.
@immutable
class PurchaseQuote {
  const PurchaseQuote({
    required this.plan,
    required this.referralLinked,
    required this.pricePaisa,
    required this.buyerPoints,
    required this.buyerPointsEquivalentPaisa,
    required this.referralCommissionPaisa,
    required this.companyAllocationPaisa,
    required this.taxPaisa,
    required this.fees,
    required this.amountDuePaisa,
    required this.pointsWithdrawable,
  });

  factory PurchaseQuote.of({
    required SubscriptionPlan plan,
    required bool referralLinked,
    int? amountPaisa,
  }) {
    final price = amountPaisa ?? plan.pricePaisa;
    final priced = plan.pricedAt(price);
    final fees = SubscriptionRules.extraFees;
    var feesPaisa = 0;
    for (final fee in fees) {
      feesPaisa += fee.paisa;
    }
    final tax = SubscriptionRules.taxPaisa;
    final buyer = SubscriptionRules.buyerPointsFor(price);
    return PurchaseQuote(
      plan: priced,
      referralLinked: referralLinked,
      pricePaisa: price,
      buyerPoints: buyer,
      buyerPointsEquivalentPaisa: buyer,
      referralCommissionPaisa: referralLinked
          ? SubscriptionRules.referralCommissionFor(price)
          : 0,
      companyAllocationPaisa: referralLinked
          ? SubscriptionRules.companyAllocationFor(price)
          : 0,
      taxPaisa: tax,
      fees: fees,
      amountDuePaisa: price + tax + feesPaisa,
      pointsWithdrawable: SubscriptionRules.promotionalPointsWithdrawable,
    );
  }

  final SubscriptionPlan plan;
  final bool referralLinked;
  final int pricePaisa;
  final int buyerPoints;
  final int buyerPointsEquivalentPaisa;
  final int referralCommissionPaisa;
  final int companyAllocationPaisa;
  final int taxPaisa;
  final List<ConfiguredFee> fees;
  final int amountDuePaisa;
  final bool pointsWithdrawable;

  int get feesPaisa {
    var total = 0;
    for (final fee in fees) {
      total += fee.paisa;
    }
    return total;
  }

  bool get hasProviderCharges => taxPaisa > 0 || fees.isNotEmpty;
}
