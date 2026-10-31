import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/wallet.dart';
import '../../../data/repositories/repository_providers.dart';

class WalletRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final walletRevisionProvider = NotifierProvider<WalletRevision, int>(
  WalletRevision.new,
);

final walletSummaryProvider = FutureProvider.autoDispose<WalletSummary>((ref) {
  ref.watch(walletRevisionProvider);
  return ref.watch(walletRepositoryProvider).fetchSummary();
}, retry: (_, _) => null);

final walletTransactionsProvider =
    FutureProvider.autoDispose<List<WalletTransaction>>((ref) {
      ref.watch(walletRevisionProvider);
      return ref.watch(walletRepositoryProvider).fetchTransactions();
    }, retry: (_, _) => null);

final walletTransactionProvider = FutureProvider.autoDispose
    .family<WalletTransaction?, String>((ref, id) {
      ref.watch(walletRevisionProvider);
      return ref.watch(walletRepositoryProvider).fetchTransaction(id);
    }, retry: (_, _) => null);

final walletWithdrawalsProvider =
    FutureProvider.autoDispose<List<WithdrawalRequest>>((ref) {
      ref.watch(walletRevisionProvider);
      return ref.watch(walletRepositoryProvider).fetchWithdrawals();
    }, retry: (_, _) => null);

final walletWithdrawalProvider = FutureProvider.autoDispose
    .family<WithdrawalRequest?, String>((ref, id) {
      ref.watch(walletRevisionProvider);
      return ref.watch(walletRepositoryProvider).fetchWithdrawal(id);
    }, retry: (_, _) => null);

final walletEligibilityProvider =
    FutureProvider.autoDispose<WithdrawalEligibility>((ref) {
      ref.watch(walletRevisionProvider);
      return ref.watch(walletRepositoryProvider).fetchEligibility();
    }, retry: (_, _) => null);
