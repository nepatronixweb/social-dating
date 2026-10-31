import 'package:flutter/foundation.dart';

import '../../core/constants/message_rules.dart';
import 'profile.dart';

/// Delivery of an outgoing mock message. Incoming messages are always [sent].
enum MessageDelivery { sending, sent, failed }

/// Why the mock messaging repository refused to record a send.
enum MessageRejection { paymentRequired, insufficientFunds, empty, tooLong }

@immutable
class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.profile,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.muted = false,
    this.isTyping = false,
    this.hidden = false,
  });

  final String id;
  final Profile profile;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool isTyping;
  final bool hidden;

  bool get hasUnread => unreadCount > 0;

  ChatPreview copyWith({bool? isTyping, int? unreadCount}) => ChatPreview(
    id: id,
    profile: profile,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    muted: muted,
    isTyping: isTyping ?? this.isTyping,
    hidden: hidden,
  );
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMine,
    required this.sentAt,
    this.delivery = MessageDelivery.sent,
    this.imageAsset,
    this.chargedPaisa = 0,
    this.eligibleWordCount = 0,
  });

  final String id;
  final String text;
  final bool isMine;
  final DateTime sentAt;
  final MessageDelivery delivery;
  final String? imageAsset;

  /// Paisa deducted for this mock send. Always 0 for failed messages.
  final int chargedPaisa;
  final int eligibleWordCount;

  bool get hasImage => imageAsset != null;
  bool get isSending => delivery == MessageDelivery.sending;
  bool get isFailed => delivery == MessageDelivery.failed;

  ChatMessage copyWith({
    MessageDelivery? delivery,
    int? chargedPaisa,
    DateTime? sentAt,
  }) => ChatMessage(
    id: id,
    text: text,
    isMine: isMine,
    sentAt: sentAt ?? this.sentAt,
    delivery: delivery ?? this.delivery,
    imageAsset: imageAsset,
    chargedPaisa: chargedPaisa ?? this.chargedPaisa,
    eligibleWordCount: eligibleWordCount,
  );
}

/// Result of asking the mock messaging repository to record a send.
@immutable
class SendOutcome {
  const SendOutcome.recorded({
    required this.message,
    required this.chargedPaisa,
    required this.balancePaisa,
  }) : rejection = null,
       quote = null;

  const SendOutcome.rejected({
    required this.rejection,
    this.quote,
    this.balancePaisa = 0,
  }) : message = null,
       chargedPaisa = 0;

  final ChatMessage? message;
  final MessageRejection? rejection;
  final MessageQuote? quote;
  final int chargedPaisa;
  final int balancePaisa;

  bool get recorded => rejection == null && message != null;
}
