import 'package:flutter/foundation.dart';

import 'profile.dart';

/// How recently someone must have been active to count as "active now".
const Duration activeNowWindow = Duration(minutes: 10);

/// A mutual match. There is at most one per person: [id] is derived from the
/// profile id by the repository, so the same pair can never appear twice.
@immutable
class Match {
  const Match({
    required this.id,
    required this.profile,
    required this.matchedAt,
    this.isNew = false,
    this.lastActiveAt,
    this.conversationId,
  });

  final String id;
  final Profile profile;
  final DateTime matchedAt;

  /// Not opened yet.
  final bool isNew;

  /// When the person was last seen in the app (mock data), if they share it.
  final DateTime? lastActiveAt;

  /// Live API conversation id (the match id). Mock chats keep [chatIdFor].
  final String? conversationId;

  /// The conversation for this match. Chat and matches share this id, so a
  /// match and its conversation can never drift apart.
  String get chatId => conversationId ?? chatIdFor(profile.id);

  static String chatIdFor(String profileId) => 'chat-$profileId';

  bool isActiveNow(DateTime now) =>
      lastActiveAt != null && now.difference(lastActiveAt!) <= activeNowWindow;

  Match copyWith({bool? isNew, DateTime? lastActiveAt}) => Match(
    id: id,
    profile: profile,
    matchedAt: matchedAt,
    isNew: isNew ?? this.isNew,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    conversationId: conversationId,
  );

  @override
  bool operator ==(Object other) =>
      other is Match &&
      other.id == id &&
      other.profile == profile &&
      other.matchedAt == matchedAt &&
      other.isNew == isNew &&
      other.lastActiveAt == lastActiveAt &&
      other.conversationId == conversationId;

  @override
  int get hashCode =>
      Object.hash(id, profile, matchedAt, isNew, lastActiveAt, conversationId);
}
