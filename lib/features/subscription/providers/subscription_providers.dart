import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/subscription_plan.dart';
import '../../../data/repositories/repository_providers.dart';

class SubscriptionRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final subscriptionRevisionProvider =
    NotifierProvider<SubscriptionRevision, int>(SubscriptionRevision.new);

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
      ref.watch(subscriptionRevisionProvider);
      return ref.watch(subscriptionRepositoryProvider).fetchPlans();
    }, retry: (_, _) => null);

final activeSubscriptionProvider =
    FutureProvider.autoDispose<ActiveSubscription?>((ref) {
      ref.watch(subscriptionRevisionProvider);
      return ref.watch(subscriptionRepositoryProvider).fetchActive();
    }, retry: (_, _) => null);

final purchaseHistoryProvider =
    FutureProvider.autoDispose<List<PurchaseRecord>>((ref) {
      ref.watch(subscriptionRevisionProvider);
      return ref.watch(subscriptionRepositoryProvider).fetchHistory();
    }, retry: (_, _) => null);

final purchaseProvider = FutureProvider.autoDispose
    .family<PurchaseRecord?, String>((ref, id) {
      ref.watch(subscriptionRevisionProvider);
      return ref.watch(subscriptionRepositoryProvider).fetchPurchase(id);
    }, retry: (_, _) => null);
