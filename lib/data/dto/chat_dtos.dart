import 'package:flutter/foundation.dart';

import '../../core/constants/message_rules.dart';
import '../models/chat.dart';
import 'json_codec.dart';
import 'profile_dtos.dart';
import 'typed_values.dart';

@immutable
class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.profile,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.muted = false,
    this.isTyping = false,
  });

  final ConversationId id;
  final ProfileDto profile;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool isTyping;

  factory ConversationDto.fromJson(Object? json) =>
      ConversationDto.fromMap(JsonMap.from(json));

  factory ConversationDto.fromMap(JsonMap map) {
    return ConversationDto(
      id: readConversationId(map),
      profile: ProfileDto.fromMap(map.object('profile')),
      lastMessage: map.string('lastMessage', allowEmpty: true),
      lastMessageAt: map.dateTime('lastMessageAt'),
      unreadCount: map.optionalInteger('unreadCount') ?? 0,
      muted: map.optionalBoolean('muted') ?? false,
      isTyping: map.optionalBoolean('isTyping') ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'profile': profile.toJson(),
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt.toUtc().toIso8601String(),
    'unreadCount': unreadCount,
    'muted': muted,
    'isTyping': isTyping,
  };

  ChatPreview toDomain() => ChatPreview(
    id: id.raw,
    profile: profile.toDomain(),
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    unreadCount: unreadCount,
    muted: muted,
    isTyping: isTyping,
  );
}

@immutable
class MessageDto {
  const MessageDto({
    required this.id,
    required this.text,
    required this.isMine,
    required this.sentAt,
    this.delivery = MessageDelivery.sent,
    this.imageUrl,
    this.chargedPaisa = const Paisa(0),
    this.eligibleWordCount = 0,
  });

  final MessageId id;
  final String text;
  final bool isMine;
  final DateTime sentAt;
  final MessageDelivery delivery;
  final String? imageUrl;
  final Paisa chargedPaisa;
  final int eligibleWordCount;

  factory MessageDto.fromJson(Object? json) =>
      MessageDto.fromMap(JsonMap.from(json));

  factory MessageDto.fromMap(JsonMap map) {
    return MessageDto(
      id: readMessageId(map),
      text: map.string('text', allowEmpty: true),
      isMine: map.boolean('isMine'),
      sentAt: map.dateTime('sentAt'),
      delivery:
          map.optionalEnum('delivery', MessageDelivery.values) ??
          MessageDelivery.sent,
      imageUrl: map.optionalString('imageUrl'),
      chargedPaisa: Paisa.readOptional(map, 'chargedPaisa'),
      eligibleWordCount: map.optionalInteger('eligibleWordCount') ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'text': text,
    'isMine': isMine,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'delivery': delivery.name,
    'imageUrl': imageUrl,
    'chargedPaisa': chargedPaisa.toJson(),
    'eligibleWordCount': eligibleWordCount,
  };

  ChatMessage toDomain() => ChatMessage(
    id: id.raw,
    text: text,
    isMine: isMine,
    sentAt: sentAt,
    delivery: delivery,
    imageAsset: imageUrl,
    chargedPaisa: chargedPaisa.paisa,
    eligibleWordCount: eligibleWordCount,
  );
}

/// Server quote for a draft. Distinct from [MessageQuote], which is a local
/// display preview and must not be charged.
@immutable
class MessageQuoteDto {
  const MessageQuoteDto({
    required this.eligibleWords,
    required this.characterCount,
    required this.costPaisa,
    required this.senderPays,
  });

  final int eligibleWords;
  final int characterCount;
  final Paisa costPaisa;
  final bool senderPays;

  factory MessageQuoteDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return MessageQuoteDto(
      eligibleWords: map.integer('eligibleWords'),
      characterCount: map.integer('characterCount'),
      costPaisa: Paisa.read(map, 'costPaisa'),
      senderPays: map.boolean('senderPays'),
    );
  }

  Map<String, Object?> toJson() => {
    'eligibleWords': eligibleWords,
    'characterCount': characterCount,
    'costPaisa': costPaisa.toJson(),
    'senderPays': senderPays,
  };

  MessageQuote toDomain() => MessageQuote(
    eligibleWords: eligibleWords,
    characterCount: characterCount,
    costPaisa: costPaisa.paisa,
    senderPays: senderPays,
  );
}

@immutable
class SendMessageRequestDto {
  const SendMessageRequestDto({
    required this.conversationId,
    required this.text,
    required this.confirmedPaid,
    this.imageId,
    this.retryOfId,
  });

  final ConversationId conversationId;
  final String text;
  final bool confirmedPaid;
  final String? imageId;
  final MessageId? retryOfId;

  factory SendMessageRequestDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    final retry = map.optionalString('retryOfId');
    return SendMessageRequestDto(
      conversationId: readConversationId(map, 'conversationId'),
      text: map.string('text', allowEmpty: true),
      confirmedPaid: map.boolean('confirmedPaid'),
      imageId: map.optionalString('imageId'),
      retryOfId: retry == null ? null : MessageId(retry),
    );
  }

  Map<String, Object?> toJson() => {
    'conversationId': conversationId.raw,
    'text': text,
    'confirmedPaid': confirmedPaid,
    'imageId': imageId,
    'retryOfId': retryOfId?.raw,
  };
}

@immutable
class SendOutcomeDto {
  const SendOutcomeDto({
    this.message,
    this.rejection,
    this.quote,
    this.chargedPaisa = const Paisa(0),
    this.balancePaisa = const Paisa(0),
  });

  final MessageDto? message;
  final MessageRejection? rejection;
  final MessageQuoteDto? quote;
  final Paisa chargedPaisa;
  final Paisa balancePaisa;

  factory SendOutcomeDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    final messageJson = map.optionalObject('message');
    final quoteJson = map.optionalObject('quote');
    return SendOutcomeDto(
      message: messageJson == null
          ? null
          : MessageDto.fromJson(messageJson.asMap()),
      rejection: map.optionalEnum('rejection', MessageRejection.values),
      quote: quoteJson == null
          ? null
          : MessageQuoteDto.fromJson(quoteJson.asMap()),
      chargedPaisa: Paisa.readOptional(map, 'chargedPaisa'),
      balancePaisa: Paisa.readOptional(map, 'balancePaisa'),
    );
  }

  Map<String, Object?> toJson() => {
    'message': message?.toJson(),
    'rejection': rejection?.name,
    'quote': quote?.toJson(),
    'chargedPaisa': chargedPaisa.toJson(),
    'balancePaisa': balancePaisa.toJson(),
  };

  SendOutcome toDomain() {
    final rejected = rejection;
    if (rejected != null) {
      return SendOutcome.rejected(
        rejection: rejected,
        quote: quote?.toDomain(),
        balancePaisa: balancePaisa.paisa,
      );
    }
    final recorded = message;
    if (recorded == null) {
      return SendOutcome.rejected(
        rejection: MessageRejection.empty,
        balancePaisa: balancePaisa.paisa,
      );
    }
    return SendOutcome.recorded(
      message: recorded.toDomain(),
      chargedPaisa: chargedPaisa.paisa,
      balancePaisa: balancePaisa.paisa,
    );
  }
}

@immutable
class ChatPushDto {
  const ChatPushDto({
    required this.type,
    required this.conversationId,
    this.message,
    this.typing,
  });

  final String type;
  final String conversationId;
  final MessageDto? message;
  final bool? typing;

  factory ChatPushDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    final message = map.optionalObject('message');
    return ChatPushDto(
      type: map.string('type'),
      conversationId: map.string('conversationId'),
      message: message == null ? null : MessageDto.fromMap(message),
      typing: map.optionalBoolean('typing'),
    );
  }
}
