/// Relative paths confirmed by `backend/CONTRACT.md`.
abstract final class MatchingApiPaths {
  static const received = '/v1/likes/received';
  static const sent = '/v1/likes/sent';
  static String likeBack(String profileId) => '/v1/likes/$profileId/back';
  static String decline(String profileId) => '/v1/likes/$profileId/decline';
  static String withdraw(String profileId) => '/v1/likes/sent/$profileId';
  static const matches = '/v1/matches';
  static String unmatch(String matchId) => '/v1/matches/$matchId';
  static String matchSeen(String matchId) => '/v1/matches/$matchId/seen';
  static const blocks = '/v1/blocks';
  static String block(String profileId) => '/v1/blocks/$profileId';
}
