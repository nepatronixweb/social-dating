import 'subscription_rules.dart';

/// Direct referral sharing and commission display, as the UI presents them.
///
/// MOCK BEHAVIOUR: codes, invite links and commissions are simulated on this
/// device. There is no referral attribution, payment processing or commission
/// payout. Allocation figures match [SubscriptionRules] for an NPR 100
/// referral-linked purchase. Do not invent multi-level commissions or claim
/// a purchase happened unless the mock repository returns that state.
abstract final class ReferralRules {
  static const int qualifyingPurchasePaisa = SubscriptionRules.pricePaisa;

  static const int companyAllocationPaisa =
      SubscriptionRules.companyAllocationPaisa;

  static const int buyerRewardEquivalentPaisa =
      SubscriptionRules.buyerPointsEquivalentPaisa;

  static const int referrerCommissionPaisa =
      SubscriptionRules.referralCommissionPaisa;

  static const String mockCode = SubscriptionRules.mockReferralCode;

  /// Clearly identified mock invite. Not an http(s) URL and not live.
  static const String mockLinkHost = 'socialdating.invite';

  static const String mockLabel = 'Mock';

  static const String mockDisclosure =
      'Mock behaviour: referral codes, invite links and commissions are '
      'demonstration data on this device. No attribution service, payment '
      'processor or payout provider is contacted. Sharing does not create '
      'a real referral.';

  static const String liveDisclosure =
      'Joining with your code is stored. A commission stays pending until a '
      'qualifying NPR 100 purchase is confirmed. Payouts wait until a payout '
      'provider is connected.';

  static const String allocationNote =
      'For a qualifying NPR 100 referral-linked purchase, the proposed split '
      'is NPR 60 to the company, NPR 30 as the buyer reward equivalent, and '
      'NPR 10 as a direct referrer commission. This is an explanation, not '
      'guaranteed income.';

  static const String pendingUntilConfirmed =
      'A referrer commission stays pending until a qualifying purchase is '
      'confirmed. Pending is not approved earnings.';

  static const String reversalNote =
      'If a qualifying purchase is later refunded, the related commission is '
      'reversed. Reversed amounts are not earnings and are not paid.';

  static const String eligibilityNote =
      'Only a direct referral-linked NPR 100 purchase can create a commission. '
      'There is no multi-level or downstream commission. The buyer reward is '
      'promotional points for the purchaser, not cash the referrer can take '
      'out.';

  static const String noIncomeClaim =
      'Figures here are demonstration data. They are not a promise of income.';

  static String inviteLink(String code) =>
      'mock://$mockLinkHost/${Uri.encodeComponent(code)}';

  static String shareMessage(String code) {
    final link = inviteLink(code);
    return 'Join me on Social Dating.\n'
        '$link\n'
        'Code $code.';
  }
}
