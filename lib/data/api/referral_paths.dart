/// Relative paths confirmed by `backend/CONTRACT.md`.
abstract final class ReferralApiPaths {
  static const info = '/v1/referrals';
  static const invites = '/v1/referrals/invites';
  static const commissions = '/v1/referrals/commissions';
  static const claim = '/v1/referrals/claim';
  static String commission(String id) => '/v1/referrals/commissions/$id';
}
