import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/message_rules.dart';
import '../../core/constants/subscription_rules.dart';
import '../../core/constants/wallet_rules.dart';
import '../../core/errors/app_failure.dart';
import '../api/auth_paths.dart';
import '../api/chat_paths.dart';
import '../api/matching_paths.dart';
import '../api/notification_paths.dart';
import '../api/page.dart';
import '../api/referral_paths.dart';
import '../api/safety_paths.dart';
import '../api/subscription_paths.dart';
import '../api/wallet_paths.dart';
import '../dto/account_dtos.dart';
import '../dto/auth_dtos.dart';
import '../dto/billing_dtos.dart';
import '../dto/chat_dtos.dart';
import '../dto/match_dtos.dart';
import '../dto/photo_dtos.dart';
import '../dto/profile_dtos.dart';
import '../dto/typed_values.dart';
import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/match.dart';
import '../models/matching.dart';
import '../models/profile.dart';
import '../models/profile_photo.dart';
import '../models/referral_info.dart';
import '../models/safety_report.dart';
import '../models/subscription_plan.dart';
import '../models/user_preferences.dart';
import '../models/wallet.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'matching_repository.dart';
import 'profile_repository.dart';
import 'repository_contracts.dart';
import 'settings_repository.dart';

/// Shared refuse path. No Dio call is made; no path is invented; no fake
/// financial success is returned.
Never _unconfirmed(String operation) =>
    throw ApiContractMissingFailure(operation);

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository();

  @override
  Future<List<Profile>> fetchSuggestedProfiles() async =>
      _unconfirmed('profile.suggested');

  @override
  Future<List<Profile>> fetchLikedYou() async =>
      _unconfirmed('profile.likedYou');
}

class ApiMatchingRepository implements MatchingRepository, ChatRepository {
  ApiMatchingRepository({
    required ApiClient client,
    required TokenStorage tokens,
  }) : _dio = client.dio,
       _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<List<ReceivedLike>> fetchLikesReceived() {
    return _withSession(
      () => _dio.get<dynamic>(MatchingApiPaths.received),
      (response) => Page.fromJson(
        response.data,
        (item) => ReceivedLikeDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<List<SentLike>> fetchLikesSent() {
    return _withSession(
      () => _dio.get<dynamic>(MatchingApiPaths.sent),
      (response) => Page.fromJson(
        response.data,
        (item) => SentLikeDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<List<Match>> fetchMatches() {
    return _withSession(
      () => _dio.get<dynamic>(MatchingApiPaths.matches),
      (response) => Page.fromJson(
        response.data,
        (item) => MatchDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<List<MatchHistoryEntry>> fetchHistory() async =>
      _unconfirmed('matches.history');

  @override
  Future<LikeOutcome> likeBack(String profileId) {
    return _withSession(
      () => _dio.post<dynamic>(MatchingApiPaths.likeBack(profileId)),
      (response) => LikeOutcomeDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<void> declineLike(String profileId) {
    return _withSession(
      () => _dio.post<dynamic>(MatchingApiPaths.decline(profileId)),
      _readEmpty,
    );
  }

  @override
  Future<void> withdrawLike(String profileId) {
    return _withSession(
      () => _dio.delete<dynamic>(MatchingApiPaths.withdraw(profileId)),
      _readEmpty,
    );
  }

  @override
  Future<void> unmatch(String matchId) {
    return _withSession(
      () => _dio.delete<dynamic>(MatchingApiPaths.unmatch(matchId)),
      _readEmpty,
    );
  }

  @override
  Future<void> block(String profileId) {
    return _withSession(
      () => _dio.post<dynamic>(MatchingApiPaths.block(profileId)),
      _readEmpty,
    );
  }

  @override
  Future<List<Profile>> fetchBlocked() {
    return _withSession(
      () => _dio.get<dynamic>(MatchingApiPaths.blocks),
      (response) => Page.fromJson(
        response.data,
        (item) => ProfileDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<void> unblock(String profileId) {
    return _withSession(
      () => _dio.delete<dynamic>(MatchingApiPaths.block(profileId)),
      _readEmpty,
    );
  }

  @override
  Future<void> markMatchSeen(String matchId) {
    return _withSession(
      () => _dio.post<dynamic>(MatchingApiPaths.matchSeen(matchId)),
      _readEmpty,
    );
  }

  @override
  Future<MatchPreferences> fetchPreferences() async =>
      _unconfirmed('matches.preferences');

  @override
  Future<MatchPreferences> savePreferences(
    MatchPreferences preferences,
  ) async => _unconfirmed('matches.savePreferences');

  @override
  Future<List<ChatPreview>> fetchPreviews() {
    return _withSession(
      () => _dio.get<dynamic>(ChatApiPaths.list),
      (response) => Page.fromJson(
        response.data,
        (item) => ConversationDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) {
    return _withSession(
      () => _dio.get<dynamic>(ChatApiPaths.messages(chatId)),
      (response) => Page.fromJson(
        response.data,
        (item) => MessageDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  static final _chatPhotoId = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  String? _asChatPhotoId(String? value) {
    if (value == null || !_chatPhotoId.hasMatch(value)) return null;
    return value;
  }

  @override
  Future<SendOutcome> sendMessage(
    String chatId,
    String text, {
    bool confirmedPaid = false,
    String? imageAsset,
    String? retryOfId,
  }) {
    final imageId = _asChatPhotoId(imageAsset);
    if (text.trim().isEmpty && imageId == null) {
      return Future.value(
        const SendOutcome.rejected(rejection: MessageRejection.empty),
      );
    }
    return _withSession(
      () => _dio.post<dynamic>(
        ChatApiPaths.messages(chatId),
        data: SendMessageRequestDto(
          conversationId: ConversationId(chatId),
          text: text,
          confirmedPaid: confirmedPaid,
          imageId: imageId,
          retryOfId: retryOfId == null ? null : MessageId(retryOfId),
        ).toJson(),
      ),
      (response) => SendOutcomeDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<void> markRead(String chatId) {
    return _withSession(
      () => _dio.post<dynamic>(ChatApiPaths.read(chatId)),
      _readEmpty,
    );
  }

  @override
  Future<void> setMuted(String chatId, {required bool muted}) {
    return _withSession(
      () =>
          _dio.post<dynamic>(ChatApiPaths.mute(chatId), data: {'muted': muted}),
      _readEmpty,
    );
  }

  @override
  Future<void> hideConversation(String chatId) {
    return _withSession(
      () => _dio.post<dynamic>(ChatApiPaths.hide(chatId)),
      _readEmpty,
    );
  }

  @override
  bool get attachFromDevice => true;

  @override
  Future<ProfilePhoto> uploadChatPhoto(
    String chatId, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) {
    final data = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _withSession(
      () => _dio.post<dynamic>(ChatApiPaths.photos(chatId), data: data),
      (response) => PhotoDto.fromJson(response.data).toDomain(),
    );
  }

  /// Local display preview only. Not a charge. The send response quote is
  /// authoritative; men still get `paymentRequired` / `insufficientFunds`
  /// from the server because the wallet is not wired (balance 0).
  @override
  MessageQuote quote(String text) =>
      MessageQuote.fromText(text, senderPays: false);

  @override
  int get mockBalancePaisa => 0;

  void _readEmpty(Response<dynamic> _) {}

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}

/// Wallet API. Summary, ledger and withdrawal requests are confirmed.
/// Payouts stay disabled so a recorded request cannot look paid.
class ApiWalletRepository implements WalletRepository {
  ApiWalletRepository({required ApiClient client, required TokenStorage tokens})
    : _dio = client.dio,
      _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<WalletSummary> fetchSummary() {
    return _withSession(
      () => _dio.get<dynamic>(WalletApiPaths.summary),
      (response) => PointBalanceDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<List<WalletTransaction>> fetchTransactions() {
    return _withSession(
      () => _dio.get<dynamic>(WalletApiPaths.transactions),
      (response) => Page.fromJson(
        response.data,
        (item) => WalletTransactionDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<WalletTransaction?> fetchTransaction(String id) async {
    try {
      return await _withSession(
        () => _dio.get<dynamic>(WalletApiPaths.transaction(id)),
        (response) => WalletTransactionDto.fromJson(response.data).toDomain(),
      );
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<List<WithdrawalRequest>> fetchWithdrawals() {
    return _withSession(
      () => _dio.get<dynamic>(WalletApiPaths.withdrawals),
      (response) => Page.fromJson(
        response.data,
        (item) => WithdrawalRequestDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<WithdrawalRequest?> fetchWithdrawal(String id) async {
    try {
      return await _withSession(
        () => _dio.get<dynamic>(WalletApiPaths.withdrawal(id)),
        (response) => WithdrawalRequestDto.fromJson(response.data).toDomain(),
      );
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  WithdrawalEligibility eligibility() => const WithdrawalEligibility(
    eligibleAccount: false,
    earnedAvailable: 0,
    minimumPoints: WalletRules.minWithdrawalPoints,
    canSubmit: false,
    explanation:
        'Load eligibility from the account ledger before recording a request.',
  );

  @override
  Future<WithdrawalEligibility> fetchEligibility() {
    return _withSession(
      () => _dio.get<dynamic>(WalletApiPaths.eligibility),
      (response) => WithdrawalEligibilityDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<WithdrawalRequest> submitWithdrawal({
    required int points,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw const ValidationFailure(
        'Confirm that this request will not be paid first. Nothing is sent '
        'to a bank.',
      );
    }
    return _withSession(
      () => _dio.post<dynamic>(
        WalletApiPaths.withdrawals,
        data: {'points': points, 'confirmed': true},
      ),
      (response) => WithdrawalRequestDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<WithdrawalRequest> cancelWithdrawal(String id) {
    return _withSession(
      () => _dio.post<dynamic>(WalletApiPaths.cancelWithdrawal(id)),
      (response) => WithdrawalRequestDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<({int points, String bucket, int spendablePoints})> redeemPromo(
    String code,
  ) {
    return _withSession(
      () => _dio.post<dynamic>(
        WalletApiPaths.redeemPromo,
        data: {'code': code.trim()},
      ),
      (response) {
        final map = response.data;
        if (map is! Map) {
          throw const ValidationFailure('Unexpected promo response.');
        }
        return (
          points: (map['points'] as num?)?.toInt() ?? 0,
          bucket: map['bucket'] as String? ?? 'promotional',
          spendablePoints: (map['spendablePoints'] as num?)?.toInt() ?? 0,
        );
      },
    );
  }

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}

/// Subscription API. Entitlement and catalog are confirmed. Checkout never
/// returns [PaymentOutcome.succeeded]: non-male accounts are refused, and
/// male checkout is refused until a payment provider exists.
class ApiSubscriptionRepository implements SubscriptionRepository {
  ApiSubscriptionRepository({
    required ApiClient client,
    required TokenStorage tokens,
  }) : _dio = client.dio,
       _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<List<SubscriptionPlan>> fetchPlans() {
    return _withSession(
      () => _dio.get<dynamic>(SubscriptionApiPaths.plans),
      (response) => Page.fromJson(
        response.data,
        (item) => SubscriptionPlanDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<ActiveSubscription?> fetchActive() {
    return _withSession(
      () => _dio.get<dynamic>(SubscriptionApiPaths.overview),
      (response) =>
          SubscriptionOverviewDto.fromJson(response.data).active?.toDomain(),
    );
  }

  @override
  Future<List<PurchaseRecord>> fetchHistory() {
    return _withSession(
      () => _dio.get<dynamic>(SubscriptionApiPaths.history),
      (response) => Page.fromJson(
        response.data,
        (item) => PurchaseRecordDto.fromJson(item.asMap()).toDomain(),
      ).items,
    );
  }

  @override
  Future<PurchaseRecord?> fetchPurchase(String id) async =>
      _unconfirmed('subscription.purchase');

  @override
  PurchaseQuote quote({
    required String planId,
    required bool referralLinked,
    int? amountPaisa,
  }) {
    final plan = _paidPlan(planId);
    final price = amountPaisa ?? plan.pricePaisa;
    if (!SubscriptionRules.isValidAmount(price)) {
      throw const ValidationFailure(
        'Enter at least NPR 10.00.',
      );
    }
    return PurchaseQuote.of(
      plan: plan,
      referralLinked: referralLinked,
      amountPaisa: price,
    );
  }

  @override
  List<PaymentMethodOption> get illustrativeMethods =>
      _unconfirmed('subscription.methods');

  @override
  Future<PurchaseRecord> submitCheckout({
    required String planId,
    required bool referralLinked,
    required String methodId,
    required bool confirmed,
    int? amountPaisa,
  }) async {
    if (!confirmed) {
      throw const ValidationFailure(
        'Confirm this purchase before continuing.',
      );
    }
    return _withSession(
      () => _dio.post<dynamic>(
        SubscriptionApiPaths.checkout,
        data: {
          'planId': planId,
          'referralLinked': referralLinked,
          'methodId': methodId,
          'confirmed': true,
          'amountPaisa': amountPaisa,
        },
      ),
      (response) => PurchaseRecordDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<PurchaseRecord> resolvePurchase(
    String id,
    PaymentOutcome outcome,
  ) async => _unconfirmed('subscription.resolvePurchase');

  @override
  Future<ActiveSubscription> cancelRenewal() async =>
      _unconfirmed('subscription.cancelRenewal');

  @override
  Future<ActiveSubscription> resumeRenewal() async =>
      _unconfirmed('subscription.resumeRenewal');

  SubscriptionPlan _paidPlan(String id) {
    if (id == SubscriptionRules.standardPlanId) {
      return SubscriptionPlan(
        id: id,
        name: SubscriptionRules.standardPlanName,
        priceLabel: 'NPR 100.00',
        periodLabel: 'custom amount',
        features: SubscriptionRules.standardFeatures,
        pricePaisa: SubscriptionRules.suggestedPricePaisa,
        isRecurring: SubscriptionRules.standardPlanRecurring,
      );
    }
    throw const NotFoundFailure('That plan is no longer available.');
  }

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository({
    required ApiClient client,
    required TokenStorage tokens,
  }) : _dio = client.dio,
       _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  Future<List<AppNotification>> fetchNotifications() {
    return _withSession(
      () => _dio.get<dynamic>(NotificationApiPaths.list),
      (response) => Page.fromJson(
        response.data,
        (item) => NotificationDto.fromMap(item).toDomain(),
      ).items,
    );
  }

  @override
  Future<void> markRead(String id) {
    return _withSession(
      () => _dio.post<dynamic>(NotificationApiPaths.read(id)),
      (_) {},
    );
  }

  @override
  Future<void> markAllRead() {
    return _withSession(
      () => _dio.post<dynamic>(NotificationApiPaths.readAll),
      (_) {},
    );
  }

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}

/// Referral codes, attribution and pending commissions. Confirming a
/// qualifying purchase still refuses until payments exist, so a client
/// cannot mint an approved commission.
class ApiReferralRepository implements ReferralRepository {
  ApiReferralRepository({
    required ApiClient client,
    required TokenStorage tokens,
  }) : _dio = client.dio,
       _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  ReferralAllocation get allocation => ReferralAllocation.qualifyingNpr100();

  @override
  Future<ReferralInfo> fetchReferralInfo() {
    return _withSession(
      () => _dio.get<dynamic>(ReferralApiPaths.info),
      (response) => ReferralInfoDto.fromJson(response.data).toDomain(),
    );
  }

  @override
  Future<List<ReferralInvite>> fetchInvites() {
    return _withSession(
      () => _dio.get<dynamic>(ReferralApiPaths.invites),
      (response) => Page.fromJson(
        response.data,
        ReferralInviteDto.fromMap,
      ).items.map((item) => item.toDomain()).toList(),
    );
  }

  @override
  Future<List<ReferralCommission>> fetchCommissions() {
    return _withSession(
      () => _dio.get<dynamic>(ReferralApiPaths.commissions),
      (response) => Page.fromJson(
        response.data,
        ReferralCommissionDto.fromMap,
      ).items.map((item) => item.toDomain()).toList(),
    );
  }

  @override
  Future<ReferralCommission?> fetchCommission(String id) async {
    try {
      return await _withSession(
        () => _dio.get<dynamic>(ReferralApiPaths.commission(id)),
        (response) => ReferralCommissionDto.fromJson(response.data).toDomain(),
      );
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<void> claimCode(String code) {
    return _withSession(
      () => _dio.post<dynamic>(ReferralApiPaths.claim, data: {'code': code}),
      (_) {},
    );
  }

  @override
  Future<ReferralCommission> confirmQualifyingPurchase(String inviteId) async =>
      _unconfirmed('referrals.confirmPurchase');

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}

class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository({
    required ApiClient client,
    required TokenStorage tokens,
  }) : _dio = client.dio,
       _tokens = tokens;

  final Dio _dio;
  final TokenStorage _tokens;
  SafetyReport? _lastReport;

  @override
  Future<UserPreferences> fetchPreferences() async =>
      _unconfirmed('settings.preferences');

  @override
  Future<UserPreferences> savePreferences(UserPreferences preferences) async =>
      _unconfirmed('settings.savePreferences');

  @override
  Future<SafetyReport> submitReport({
    required String category,
    String details = '',
    String? attachmentAsset,
    String? subjectName,
    String? reportedAccountId,
  }) {
    final targetId = reportedAccountId?.trim();
    if (targetId == null || targetId.isEmpty) {
      throw const ValidationFailure(
        'Pick someone to report from their profile or chat.',
      );
    }
    return _withSession(
      () => _dio.post<dynamic>(
        SafetyApiPaths.reports,
        data: {
          'reportedAccountId': targetId,
          'category': category,
          'details': details.trim(),
        },
      ),
      (response) {
        final report = SafetyReportDto.fromJson(response.data).toDomain();
        _lastReport = report;
        return report;
      },
    );
  }

  @override
  Future<SafetyReport?> lastReport() async => _lastReport;

  @override
  Future<void> requestAccountDeletion() async =>
      _unconfirmed('account.requestDeletion');

  Future<T> _withSession<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Response<dynamic> response) read,
  ) async {
    try {
      return read(await send());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw AppFailure.from(error);
      }
      await _refresh();
      try {
        return read(await send());
      } catch (retryError) {
        throw AppFailure.from(retryError);
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> _refresh() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const UnauthorizedFailure();
    }
    try {
      final response = await _dio.post<dynamic>(
        AuthApiPaths.refresh,
        data: RefreshRequestDto(refreshToken: refresh).toJson(),
      );
      final dto = AuthVerifyResponseDto.fromJson(response.data);
      final access = dto.accessToken;
      final next = dto.refreshToken;
      if (access == null || next == null) {
        throw const UnauthorizedFailure();
      }
      await _tokens.writeSession(accessToken: access, refreshToken: next);
    } catch (error) {
      await _tokens.clear();
      throw AppFailure.from(error);
    }
  }
}
