import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/referral_info.dart';
import '../../../data/repositories/repository_providers.dart';

class ReferralRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final referralRevisionProvider = NotifierProvider<ReferralRevision, int>(
  ReferralRevision.new,
);

final referralInfoProvider = FutureProvider.autoDispose<ReferralInfo>((ref) {
  ref.watch(referralRevisionProvider);
  return ref.watch(referralRepositoryProvider).fetchReferralInfo();
}, retry: (_, _) => null);

final referralInvitesProvider =
    FutureProvider.autoDispose<List<ReferralInvite>>((ref) {
      ref.watch(referralRevisionProvider);
      return ref.watch(referralRepositoryProvider).fetchInvites();
    }, retry: (_, _) => null);

final referralCommissionsProvider =
    FutureProvider.autoDispose<List<ReferralCommission>>((ref) {
      ref.watch(referralRevisionProvider);
      return ref.watch(referralRepositoryProvider).fetchCommissions();
    }, retry: (_, _) => null);

final referralCommissionProvider = FutureProvider.autoDispose
    .family<ReferralCommission?, String>((ref, id) {
      ref.watch(referralRevisionProvider);
      return ref.watch(referralRepositoryProvider).fetchCommission(id);
    }, retry: (_, _) => null);
