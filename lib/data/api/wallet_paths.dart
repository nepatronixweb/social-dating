/// Relative paths confirmed by `backend/CONTRACT.md`.
abstract final class WalletApiPaths {
  static const summary = '/v1/wallet';
  static const transactions = '/v1/wallet/transactions';
  static String transaction(String id) => '/v1/wallet/transactions/$id';
  static const eligibility = '/v1/wallet/withdrawals/eligibility';
  static const withdrawals = '/v1/wallet/withdrawals';
  static String withdrawal(String id) => '/v1/wallet/withdrawals/$id';
  static String cancelWithdrawal(String id) =>
      '/v1/wallet/withdrawals/$id/cancel';
}
