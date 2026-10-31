import 'package:flutter/foundation.dart';

import 'match.dart';
import 'profile.dart';

/// Someone who liked the signed-in person and is waiting for a response.
@immutable
class ReceivedLike {
  const ReceivedLike({required this.profile, required this.likedAt});

  final Profile profile;
  final DateTime likedAt;
}

/// A like the signed-in person sent that has not become a match (yet).
@immutable
class SentLike {
  const SentLike({required this.profile, required this.likedAt});

  final Profile profile;
  final DateTime likedAt;
}

enum MatchHistoryKind { matched, unmatched, blocked }

/// One line of the match history.
@immutable
class MatchHistoryEntry {
  const MatchHistoryEntry({
    required this.id,
    required this.profile,
    required this.kind,
    required this.at,
  });

  final String id;
  final Profile profile;
  final MatchHistoryKind kind;
  final DateTime at;
}

/// Result of liking someone.
@immutable
class LikeOutcome {
  const LikeOutcome({this.match, this.created = false});

  /// The match, when the like was mutual (or one already existed).
  final Match? match;

  /// True only when this like created the match. False when the match already
  /// existed, so no second card is made and no second celebration is shown.
  final bool created;
}

/// The person's match preferences.
///
/// [dailyMatchPreference] is what the person would LIKE to receive. It is a
/// preference, never a promise: actual matches depend on who is available and
/// who likes back. The UI must never present it as a guaranteed number.
@immutable
class MatchPreferences {
  const MatchPreferences({
    required this.canSetDailyPreference,
    this.dailyMatchPreference = defaultDailyPreference,
    this.pauseNewMatches = false,
    this.showActiveStatus = true,
    this.newMatchesToday = 0,
  });

  static const int defaultDailyPreference = 5;

  /// The choices offered for the daily preference.
  static const List<int> dailyPreferenceOptions = [1, 3, 5, 10];

  /// Whether this account may choose a daily preference. The server decides
  /// eligibility; the mock bases it on the mock account type.
  final bool canSetDailyPreference;

  /// Preferred maximum of new matches per day.
  final int dailyMatchPreference;

  /// Temporarily stop receiving new matches.
  final bool pauseNewMatches;

  /// Share "active now" / "active 2h ago" with matches.
  final bool showActiveStatus;

  /// New matches made today. Information only, and mock data.
  final int newMatchesToday;

  MatchPreferences copyWith({
    int? dailyMatchPreference,
    bool? pauseNewMatches,
    bool? showActiveStatus,
  }) => MatchPreferences(
    canSetDailyPreference: canSetDailyPreference,
    dailyMatchPreference: dailyMatchPreference ?? this.dailyMatchPreference,
    pauseNewMatches: pauseNewMatches ?? this.pauseNewMatches,
    showActiveStatus: showActiveStatus ?? this.showActiveStatus,
    newMatchesToday: newMatchesToday,
  );

  @override
  bool operator ==(Object other) =>
      other is MatchPreferences &&
      other.canSetDailyPreference == canSetDailyPreference &&
      other.dailyMatchPreference == dailyMatchPreference &&
      other.pauseNewMatches == pauseNewMatches &&
      other.showActiveStatus == showActiveStatus &&
      other.newMatchesToday == newMatchesToday;

  @override
  int get hashCode => Object.hash(
    canSetDailyPreference,
    dailyMatchPreference,
    pauseNewMatches,
    showActiveStatus,
    newMatchesToday,
  );
}
