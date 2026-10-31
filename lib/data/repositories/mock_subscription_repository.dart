// ============================================================================
// MOCK DATA ONLY: in-memory subscription and checkout "service"
//
// Plans, quotes, pending/success/failure/cancelled outcomes and purchase
// history live in memory and vanish when the app restarts. NOTHING is charged
// by a payment gateway, app store or backend. Outcomes are prototype
// demonstrations the person chooses. Nothing outside `mock_*` files and the
// approved seam may import this file (test/mock_isolation_test.dart).
// ============================================================================

import '../../core/constants/subscription_rules.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/money.dart';
import '../models/profile.dart';
import '../models/subscription_plan.dart';
import 'mock_profile_repository.dart';
import 'repository_contracts.dart';

class MockSubscriptionRepository implements SubscriptionRepository {
  MockSubscriptionRepository({
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

  final List<PurchaseRecord> _history = [];
  ActiveSubscription? _active;
  int _counter = 0;
  bool _inFlight = false;

  /// Shown on the Premium screen. Empty: purchase is amount-only.
  static const List<SubscriptionPlan> catalog = [];

  /// Used for quotes and checkout. Not listed as selectable plan cards.
  static final SubscriptionPlan checkoutPlan = SubscriptionPlan(
    id: SubscriptionRules.standardPlanId,
    name: SubscriptionRules.standardPlanName,
    priceLabel: formatNpr(SubscriptionRules.pricePaisa),
    periodLabel: 'custom amount',
    features: SubscriptionRules.standardFeatures,
    pricePaisa: SubscriptionRules.pricePaisa,
    isRecurring: SubscriptionRules.standardPlanRecurring,
  );

  static const List<PaymentMethodOption> methods = [
    PaymentMethodOption(
      id: 'esewa',
      name: 'eSewa',
      subtitle: 'Illustrative only. Not connected.',
    ),
    PaymentMethodOption(
      id: 'khalti',
      name: 'Khalti',
      subtitle: 'Illustrative only. Not connected.',
    ),
    PaymentMethodOption(
      id: 'card',
      name: 'Card',
      subtitle: 'Illustrative only. Not connected.',
    ),
  ];

  void reset() {
    _history.clear();
    _active = null;
    _counter = 0;
    _inFlight = false;
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: latency,
    data: data,
    empty: empty,
  );

  Future<T> _change<T>(T Function() change) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    return change();
  }

  SubscriptionPlan _plan(String id) {
    if (id == checkoutPlan.id) return checkoutPlan;
    throw const NotFoundFailure('That plan is no longer available.');
  }

  @override
  Future<List<SubscriptionPlan>> fetchPlans() =>
      _fetch(() => [...catalog], const []);

  bool get hasPaidPremium => _active != null;

  ActiveSubscription _complimentary() =>
      ActiveSubscription.complimentary(startedAt: _now());

  void _requirePaidBuyer() {
    if (_viewerGender().hasComplimentaryPremium) {
      throw const ValidationFailure(
        SubscriptionRules.complimentaryCheckoutRefused,
      );
    }
  }

  @override
  Future<ActiveSubscription?> fetchActive() => _fetch(() {
    if (_viewerGender().hasComplimentaryPremium) return _complimentary();
    return _active;
  }, null);

  @override
  Future<List<PurchaseRecord>> fetchHistory() => _fetch(
    () => [..._history]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    const [],
  );

  @override
  Future<PurchaseRecord?> fetchPurchase(String id) =>
      _fetch(() => _history.where((p) => p.id == id).firstOrNull, null);

  @override
  PurchaseQuote quote({
    required String planId,
    required bool referralLinked,
    int? amountPaisa,
  }) {
    _requirePaidBuyer();
    final plan = _plan(planId);
    final price = amountPaisa ?? plan.pricePaisa;
    if (!SubscriptionRules.isValidAmount(price)) {
      throw ValidationFailure(
        'Enter at least ${formatNpr(SubscriptionRules.minPricePaisa)}.',
      );
    }
    return PurchaseQuote.of(
      plan: plan,
      referralLinked: referralLinked,
      amountPaisa: price,
    );
  }

  @override
  List<PaymentMethodOption> get illustrativeMethods => methods;

  @override
  Future<PurchaseRecord> submitCheckout({
    required String planId,
    required bool referralLinked,
    required String methodId,
    required bool confirmed,
    int? amountPaisa,
  }) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    _requirePaidBuyer();
    if (!confirmed) {
      throw const ValidationFailure(
        'Confirm this purchase before continuing.',
      );
    }
    if (_inFlight) {
      final pending = _history.where((p) => p.isPending).firstOrNull;
      if (pending != null) return pending;
    }
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    if (method == null) {
      throw const ValidationFailure('Choose an illustrative payment method.');
    }
    final priced = quote(
      planId: planId,
      referralLinked: referralLinked,
      amountPaisa: amountPaisa,
    );
    _inFlight = true;
    try {
      final record = PurchaseRecord(
        id: 'mock-pay-${++_counter}',
        plan: priced.plan,
        amountPaisa: priced.amountDuePaisa,
        outcome: PaymentOutcome.pending,
        createdAt: _now(),
        referralLinked: referralLinked,
        methodId: method.id,
        methodName: method.name,
      );
      _history.insert(0, record);
      return record;
    } finally {
      _inFlight = false;
    }
  }

  @override
  Future<PurchaseRecord> resolvePurchase(String id, PaymentOutcome outcome) =>
      _change(() {
        if (outcome == PaymentOutcome.pending) {
          throw const ValidationFailure('Choose a payment outcome.');
        }
        final index = _history.indexWhere((p) => p.id == id);
        if (index < 0) {
          throw const NotFoundFailure('That purchase is no longer here.');
        }
        final current = _history[index];
        if (!current.isPending) return current;
        final resolved = current.copyWith(outcome: outcome, resolvedAt: _now());
        _history[index] = resolved;
        if (outcome == PaymentOutcome.succeeded) {
          final now = _now();
          _active = ActiveSubscription(
            plan: current.plan,
            startedAt: now,
            renewsAt: current.plan.isRecurring
                ? now.add(const Duration(days: 30))
                : null,
            referralLinked: current.referralLinked,
          );
        }
        return resolved;
      });

  @override
  Future<ActiveSubscription> cancelRenewal() => _change(() {
    final active = _active;
    if (active == null || !active.isRecurring) {
      throw const ValidationFailure(
        'Cancellation is only available on a recurring plan.',
      );
    }
    _active = active.copyWith(cancelledAt: _now(), clearRenewsAt: true);
    return _active!;
  });

  @override
  Future<ActiveSubscription> resumeRenewal() => _change(() {
    final active = _active;
    if (active == null || !active.isRecurring) {
      throw const ValidationFailure(
        'Renewal is only available on a recurring plan.',
      );
    }
    _active = ActiveSubscription(
      plan: active.plan,
      startedAt: active.startedAt,
      renewsAt: _now().add(const Duration(days: 30)),
      referralLinked: active.referralLinked,
    );
    return _active!;
  });
}
