import 'dart:typed_data';

import '../../core/constants/message_rules.dart';
import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/profile_photo.dart';
import '../models/referral_info.dart';
import '../models/subscription_plan.dart';
import '../models/wallet.dart';

/// Repository contracts. Mock implementations live in `mock_*_repository.dart`.
/// API implementations in `api_repositories.dart` refuse every call until a
/// confirmed endpoint contract exists. Selection happens only in
/// `repository_providers.dart`.

abstract interface class ChatRepository {
  Future<List<ChatPreview>> fetchPreviews();
  Future<List<ChatMessage>> fetchMessages(String chatId);

  /// Records a send in the conversation. Throws [NotFoundFailure] when the
  /// conversation has been closed (unmatched or blocked).
  ///
  /// [confirmedPaid] must be true only after the person confirmed a paid
  /// quote. Failed mock sends never deduct. Pass [retryOfId] to retry a
  /// failed outgoing message instead of creating a second one.
  Future<SendOutcome> sendMessage(
    String chatId,
    String text, {
    bool confirmedPaid = false,
    String? imageAsset,
    String? retryOfId,
  });

  Future<void> markRead(String chatId);
  Future<void> setMuted(String chatId, {required bool muted});
  Future<void> hideConversation(String chatId);

  /// True when attach should open the device gallery instead of sample assets.
  bool get attachFromDevice;

  /// Stores a chat image. Mock returns a sample portrait; API uploads to
  /// `/v1/chats/{id}/photos` and does not count toward the profile album.
  Future<ProfilePhoto> uploadChatPhoto(
    String chatId, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
  });

  /// Local quote for [text] using the mock account type. Not a charge.
  MessageQuote quote(String text);

  /// Current mock wallet balance in paisa. Display only.
  int get mockBalancePaisa;
}

abstract interface class WalletRepository {
  Future<WalletSummary> fetchSummary();
  Future<List<WalletTransaction>> fetchTransactions();
  Future<WalletTransaction?> fetchTransaction(String id);
  Future<List<WithdrawalRequest>> fetchWithdrawals();
  Future<WithdrawalRequest?> fetchWithdrawal(String id);

  /// Current eligibility. Promotional points never count.
  WithdrawalEligibility eligibility();

  Future<WithdrawalEligibility> fetchEligibility();

  /// Records a withdrawal request. Throws if [confirmed] is false.
  /// Never contacts a bank or payout provider. Never marks the request paid.
  Future<WithdrawalRequest> submitWithdrawal({
    required int points,
    required bool confirmed,
  });

  Future<WithdrawalRequest> cancelWithdrawal(String id);
}

abstract interface class SubscriptionRepository {
  Future<List<SubscriptionPlan>> fetchPlans();
  Future<ActiveSubscription?> fetchActive();
  Future<List<PurchaseRecord>> fetchHistory();
  Future<PurchaseRecord?> fetchPurchase(String id);

  PurchaseQuote quote({
    required String planId,
    required bool referralLinked,
    int? amountPaisa,
  });

  List<PaymentMethodOption> get illustrativeMethods;

  /// Starts a mock checkout. Throws if [confirmed] is false. The record is
  /// always [PaymentOutcome.pending]; nothing is taken from a gateway.
  Future<PurchaseRecord> submitCheckout({
    required String planId,
    required bool referralLinked,
    required String methodId,
    required bool confirmed,
    int? amountPaisa,
  });

  /// Resolves a pending mock purchase. Prototype only — not a provider result.
  Future<PurchaseRecord> resolvePurchase(String id, PaymentOutcome outcome);

  Future<ActiveSubscription> cancelRenewal();
  Future<ActiveSubscription> resumeRenewal();
}

abstract interface class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();
}

abstract interface class ReferralRepository {
  Future<ReferralInfo> fetchReferralInfo();
  Future<List<ReferralInvite>> fetchInvites();
  Future<List<ReferralCommission>> fetchCommissions();
  Future<ReferralCommission?> fetchCommission(String id);

  ReferralAllocation get allocation;

  /// Applies an invite code to this account. One use per account.
  Future<void> claimCode(String code);

  /// Moves a pending commission to approved after a mock qualifying purchase
  /// is confirmed on this device. Does not contact a payment processor.
  Future<ReferralCommission> confirmQualifyingPurchase(String inviteId);
}
