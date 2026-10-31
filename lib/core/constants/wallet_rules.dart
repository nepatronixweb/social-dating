/// Wallet balances, conversion and withdrawal, as the UI presents them.
///
/// These numbers match the API ledger when the app is wired to it. They are
/// NOT a bank payout or provider quote. Payouts stay disabled until a
/// provider exists. Change values here only. Do not invent fees or claim a
/// real withdrawal was sent.
abstract final class WalletRules {
  /// 100 points = NPR 1.00 = 100 paisa, so 1 point = 1 paisa in this mock.
  static const int pointsPerNpr = 100;

  /// Welcome grant. Promotional, non-cash, never withdrawable.
  static const int welcomeBonusPoints = 1000;

  static const bool welcomeBonusWithdrawable = false;

  /// Buyer reward from the NPR 100 subscription. Stated NPR 30 equivalent.
  /// Redemption follows [subscriptionRewardWithdrawable].
  static const int subscriptionRewardPoints = 3000;

  static const int subscriptionRewardEquivalentPaisa = 3000;

  /// Subject to product policy. False: not cash, not withdrawable.
  static const bool subscriptionRewardWithdrawable = false;

  /// Paid swipe charged to the point wallet: NPR 0.10 = 10 points.
  static const int swipeSpendPoints = 10;

  /// Minimum earned, withdrawable points to request a mock withdrawal.
  static const int minWithdrawalPoints = 500;

  /// Payout fee in points. Zero until a provider or config supplies one.
  static const int withdrawalFeePoints = 0;

  /// Extra payout fees. Empty on purpose: the UI must not invent them.
  static const List<({String label, int points})> extraFees = [];

  /// Tax in points. Zero until a verified provider or config supplies it.
  static const int taxPoints = 0;

  /// Copy-only estimate. Not a payout-provider guarantee.
  static const String processingTimeNote =
      'Configured estimate: 3–5 business days. This is not a guarantee '
      'from a payout provider.';

  static const String processingTimeNoteLive =
      'Configured estimate: 3–5 business days after payouts are enabled. '
      'This is not a guarantee from a payout provider.';

  static const String mockLabel = 'Mock';

  static const String liveLabel = 'Not paid';

  static const String mockDisclosure =
      'Mock behaviour: balances, points, NPR equivalents and withdrawal '
      'requests are simulated on this device. No bank, payment gateway or '
      'payout provider is contacted. The ledger will be authoritative later.';

  static const String liveDisclosure =
      'Requests are stored on the account ledger. No bank, payment gateway '
      'or payout provider is contacted. Payouts are not enabled, so a '
      'recorded request is never paid.';

  static const String equivalentNotCash =
      'A displayed NPR equivalent is not necessarily withdrawable cash. '
      'Promotional points never count toward withdrawal.';

  static const String welcomeBonusExplainer =
      'New accounts receive 1,000 promotional points as a welcome bonus. '
      'They are not cash and cannot be withdrawn. They can be spent in-app '
      'when a feature charges the point wallet.';

  static const String mockRequestNote =
      'This request is saved. It is not submitted to a bank or payout '
      'provider, and it will not be paid.';

  static const String liveRequestNote =
      'This request is saved on the account ledger. It is not submitted to '
      'a bank or payout provider, and it will not be paid.';
}

/// 100 points = NPR 1, so the mock treats 1 point as 1 paisa.
int walletPaisaFromPoints(int points) => points;
