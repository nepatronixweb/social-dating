import '../../core/errors/api_error_mapper.dart';
import 'json_codec.dart';

/// Integer Nepalese paisa. 100 paisa = NPR 1.00. Never a floating-point rupee.
extension type const Paisa(int value) {
  int get paisa => value;

  factory Paisa.read(JsonMap json, String key) {
    return Paisa(json.integer(key));
  }

  factory Paisa.readOptional(JsonMap json, String key, {int fallback = 0}) {
    final raw = json.optionalInteger(key);
    return Paisa(raw ?? fallback);
  }

  Object toJson() => value;
}

/// Loyalty points. In the mock, 1 point = 1 paisa; the backend may differ and
/// is authoritative when a contract exists.
extension type const Points(int value) {
  int get points => value;

  factory Points.read(JsonMap json, String key) {
    return Points(json.integer(key));
  }

  factory Points.readOptional(JsonMap json, String key, {int fallback = 0}) {
    final raw = json.optionalInteger(key);
    return Points(raw ?? fallback);
  }

  Object toJson() => value;
}

/// Opaque string identifier. Empty values are rejected.
extension type const EntityId(String value) {
  String get raw => value;

  factory EntityId.read(JsonMap json, String key) {
    final raw = json.string(key);
    if (raw.trim() != raw) {
      throw JsonFormatException('Identifier at ${json.path}.$key has padding.');
    }
    return EntityId(raw);
  }

  Object toJson() => value;
}

extension type const AccountId(String value) implements EntityId {}
extension type const ProfileId(String value) implements EntityId {}
extension type const MatchId(String value) implements EntityId {}
extension type const ConversationId(String value) implements EntityId {}
extension type const MessageId(String value) implements EntityId {}
extension type const PurchaseId(String value) implements EntityId {}
extension type const TransactionId(String value) implements EntityId {}
extension type const WithdrawalId(String value) implements EntityId {}
extension type const ReferralInviteId(String value) implements EntityId {}
extension type const CommissionId(String value) implements EntityId {}
extension type const NotificationId(String value) implements EntityId {}
extension type const ReportId(String value) implements EntityId {}
extension type const PlanId(String value) implements EntityId {}

AccountId readAccountId(JsonMap json, [String key = 'id']) =>
    AccountId(EntityId.read(json, key).raw);

ProfileId readProfileId(JsonMap json, [String key = 'id']) =>
    ProfileId(EntityId.read(json, key).raw);

MatchId readMatchId(JsonMap json, [String key = 'id']) =>
    MatchId(EntityId.read(json, key).raw);

ConversationId readConversationId(JsonMap json, [String key = 'id']) =>
    ConversationId(EntityId.read(json, key).raw);

MessageId readMessageId(JsonMap json, [String key = 'id']) =>
    MessageId(EntityId.read(json, key).raw);

PurchaseId readPurchaseId(JsonMap json, [String key = 'id']) =>
    PurchaseId(EntityId.read(json, key).raw);

TransactionId readTransactionId(JsonMap json, [String key = 'id']) =>
    TransactionId(EntityId.read(json, key).raw);

WithdrawalId readWithdrawalId(JsonMap json, [String key = 'id']) =>
    WithdrawalId(EntityId.read(json, key).raw);

ReferralInviteId readReferralInviteId(JsonMap json, [String key = 'id']) =>
    ReferralInviteId(EntityId.read(json, key).raw);

CommissionId readCommissionId(JsonMap json, [String key = 'id']) =>
    CommissionId(EntityId.read(json, key).raw);

NotificationId readNotificationId(JsonMap json, [String key = 'id']) =>
    NotificationId(EntityId.read(json, key).raw);

ReportId readReportId(JsonMap json, [String key = 'id']) =>
    ReportId(EntityId.read(json, key).raw);

PlanId readPlanId(JsonMap json, [String key = 'id']) =>
    PlanId(EntityId.read(json, key).raw);
