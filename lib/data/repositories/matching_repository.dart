import '../models/match.dart';
import '../models/matching.dart';
import '../models/profile.dart';

/// Likes, mutual matches, match preferences and match management.
///
/// The service must be authoritative for all of this: whether a like is mutual,
/// that a pair gets exactly one match, unmatching, blocking and eligibility for
/// daily match preferences. The UI never claims a match exists until the
/// repository says so.
abstract interface class MatchingRepository {
  Future<List<ReceivedLike>> fetchLikesReceived();

  Future<List<SentLike>> fetchLikesSent();

  Future<List<Match>> fetchMatches();

  Future<List<MatchHistoryEntry>> fetchHistory();

  /// Likes someone who already liked the signed-in person. Creates the match
  /// unless one already exists (then returns it with `created: false`).
  Future<LikeOutcome> likeBack(String profileId);

  /// Dismisses a received like without responding.
  Future<void> declineLike(String profileId);

  /// Takes back a like that has not become a match.
  Future<void> withdrawLike(String profileId);

  /// Ends a match and closes its conversation.
  Future<void> unmatch(String matchId);

  /// Blocks a person: removes any match, like and conversation with them.
  Future<void> block(String profileId);

  /// People currently blocked. Public profile fields only.
  Future<List<Profile>> fetchBlocked();

  /// Removes a block. The person may appear in discovery again.
  Future<void> unblock(String profileId);

  /// Marks a new match as opened.
  Future<void> markMatchSeen(String matchId);

  Future<MatchPreferences> fetchPreferences();

  /// Saves preferences. Rejects a daily preference change for accounts that
  /// may not set one.
  Future<MatchPreferences> savePreferences(MatchPreferences preferences);
}
