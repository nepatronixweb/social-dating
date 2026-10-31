import 'package:flutter/foundation.dart';

import '../models/match.dart';
import '../models/matching.dart';
import 'json_codec.dart';
import 'profile_dtos.dart';
import 'typed_values.dart';

@immutable
class ReceivedLikeDto {
  const ReceivedLikeDto({required this.profile, required this.likedAt});

  final ProfileDto profile;
  final DateTime likedAt;

  factory ReceivedLikeDto.fromJson(Object? json) =>
      ReceivedLikeDto.fromMap(JsonMap.from(json));

  factory ReceivedLikeDto.fromMap(JsonMap map) => ReceivedLikeDto(
    profile: ProfileDto.fromMap(map.object('profile')),
    likedAt: map.dateTime('likedAt'),
  );

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'likedAt': likedAt.toUtc().toIso8601String(),
  };

  ReceivedLike toDomain() =>
      ReceivedLike(profile: profile.toDomain(), likedAt: likedAt);
}

@immutable
class SentLikeDto {
  const SentLikeDto({required this.profile, required this.likedAt});

  final ProfileDto profile;
  final DateTime likedAt;

  factory SentLikeDto.fromJson(Object? json) =>
      SentLikeDto.fromMap(JsonMap.from(json));

  factory SentLikeDto.fromMap(JsonMap map) => SentLikeDto(
    profile: ProfileDto.fromMap(map.object('profile')),
    likedAt: map.dateTime('likedAt'),
  );

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'likedAt': likedAt.toUtc().toIso8601String(),
  };

  SentLike toDomain() =>
      SentLike(profile: profile.toDomain(), likedAt: likedAt);
}

@immutable
class MatchDto {
  const MatchDto({
    required this.id,
    required this.profile,
    required this.matchedAt,
    this.isNew = false,
    this.lastActiveAt,
    this.conversationId,
  });

  final MatchId id;
  final ProfileDto profile;
  final DateTime matchedAt;
  final bool isNew;
  final DateTime? lastActiveAt;
  final String? conversationId;

  factory MatchDto.fromJson(Object? json) =>
      MatchDto.fromMap(JsonMap.from(json));

  factory MatchDto.fromMap(JsonMap map) => MatchDto(
    id: readMatchId(map),
    profile: ProfileDto.fromMap(map.object('profile')),
    matchedAt: map.dateTime('matchedAt'),
    isNew: map.optionalBoolean('isNew') ?? false,
    lastActiveAt: map.optionalDateTime('lastActiveAt'),
    conversationId: map.optionalString('conversationId'),
  );

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'profile': profile.toJson(),
    'matchedAt': matchedAt.toUtc().toIso8601String(),
    'isNew': isNew,
    'lastActiveAt': lastActiveAt?.toUtc().toIso8601String(),
    'conversationId': conversationId,
  };

  Match toDomain() => Match(
    id: id.raw,
    profile: profile.toDomain(),
    matchedAt: matchedAt,
    isNew: isNew,
    lastActiveAt: lastActiveAt,
    conversationId: conversationId,
  );
}

@immutable
class LikeOutcomeDto {
  const LikeOutcomeDto({this.match, this.created = false});

  final MatchDto? match;
  final bool created;

  factory LikeOutcomeDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    final nested = map.optionalObject('match');
    return LikeOutcomeDto(
      match: nested == null ? null : MatchDto.fromMap(nested),
      created: map.optionalBoolean('created') ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'match': match?.toJson(),
    'created': created,
  };

  LikeOutcome toDomain() =>
      LikeOutcome(match: match?.toDomain(), created: created);
}

@immutable
class MatchHistoryEntryDto {
  const MatchHistoryEntryDto({
    required this.id,
    required this.profile,
    required this.kind,
    required this.at,
  });

  final EntityId id;
  final ProfileDto profile;
  final MatchHistoryKind kind;
  final DateTime at;

  factory MatchHistoryEntryDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return MatchHistoryEntryDto(
      id: EntityId.read(map, 'id'),
      profile: ProfileDto.fromMap(map.object('profile')),
      kind: map.enumValue('kind', MatchHistoryKind.values),
      at: map.dateTime('at'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id.raw,
    'profile': profile.toJson(),
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
  };

  MatchHistoryEntry toDomain() => MatchHistoryEntry(
    id: id.raw,
    profile: profile.toDomain(),
    kind: kind,
    at: at,
  );
}

@immutable
class MatchPreferencesDto {
  const MatchPreferencesDto({required this.preferences});

  final MatchPreferences preferences;

  factory MatchPreferencesDto.fromJson(Object? json) {
    final map = JsonMap.from(json);
    return MatchPreferencesDto(
      preferences: MatchPreferences(
        canSetDailyPreference: map.boolean('canSetDailyPreference'),
        dailyMatchPreference:
            map.optionalInteger('dailyMatchPreference') ??
            MatchPreferences.defaultDailyPreference,
        pauseNewMatches: map.optionalBoolean('pauseNewMatches') ?? false,
        showActiveStatus: map.optionalBoolean('showActiveStatus') ?? true,
        newMatchesToday: map.optionalInteger('newMatchesToday') ?? 0,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'canSetDailyPreference': preferences.canSetDailyPreference,
    'dailyMatchPreference': preferences.dailyMatchPreference,
    'pauseNewMatches': preferences.pauseNewMatches,
    'showActiveStatus': preferences.showActiveStatus,
    'newMatchesToday': preferences.newMatchesToday,
  };

  MatchPreferences toDomain() => preferences;
}
