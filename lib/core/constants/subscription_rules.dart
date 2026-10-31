/// Subscription prices, points and allocation, as the UI presents them.
///
/// MOCK BEHAVIOUR: these numbers describe what the client displays and what
/// the in-memory mock repository enforces. They are NOT a real charge, store
/// purchase, payout or tax calculation. A payment provider and backend must
/// later own prices, taxes, entitlements and allocation. Change values here
/// only. Do not invent fees or a successful payment.
abstract final class SubscriptionRules {
  static const String standardPlanId = 'npr-100';
  static const String monthlyPlanId = 'npr-100-monthly';
  static const String complimentaryPlanId = 'included';

  /// Lowest amount the person can enter. NPR 10.00 = 1,000 paisa.
  static const int minPricePaisa = 1000;

  /// Suggested starting amount in the amount field. NPR 100.00.
  static const int suggestedPricePaisa = 10000;

  /// Suggested NPR 100.00 held as integer paisa. Custom checkouts may differ.
  static const int pricePaisa = suggestedPricePaisa;

  /// Buyer promotional share of a purchase (30%).
  static const int buyerSharePercent = 30;

  /// Direct referrer share of a referral-linked purchase (10%).
  static const int referralSharePercent = 10;

  /// Promotional points granted to the buyer with the suggested NPR 100 amount.
  static const int buyerPoints = 3000;

  /// Stated NPR equivalent of [buyerPoints] (100 points = NPR 1).
  static const int buyerPointsEquivalentPaisa = 3000;

  /// Direct referral commission on a referral-linked suggested NPR 100 purchase.
  static const int referralCommissionPaisa = 1000;

  /// Company allocation on a referral-linked suggested NPR 100 purchase.
  static const int companyAllocationPaisa = 6000;

  static int nprToPaisa(int rupees) => rupees * 100;

  static int buyerPointsFor(int pricePaisa) =>
      (pricePaisa * buyerSharePercent) ~/ 100;

  static int referralCommissionFor(int pricePaisa) =>
      (pricePaisa * referralSharePercent) ~/ 100;

  /// Remainder so 30% + 10% + company always equals the price.
  static int companyAllocationFor(int pricePaisa) =>
      pricePaisa -
      buyerPointsFor(pricePaisa) -
      referralCommissionFor(pricePaisa);

  static bool isValidAmount(int pricePaisa) => pricePaisa >= minPricePaisa;

  static List<String> standardFeaturesFor(int _) => [...standardFeatures];

  static List<String> monthlyFeaturesFor(int _) => [
    'Everything in Premium',
    'Renews each month until you cancel',
    'Cancel any time; access lasts until the period ends',
  ];

  /// 100 points = NPR 1.00 = 100 paisa.
  static const int pointsPerNpr = 100;

  /// Promotional purchase points are not cash-convertible unless product
  /// policy is changed here.
  static const bool promotionalPointsWithdrawable = false;

  /// Whether the NPR 100 one-time plan auto-renews. Leave false so the
  /// cancellation UI stays hidden for that plan.
  static const bool standardPlanRecurring = false;

  /// Whether the monthly comparison plan auto-renews.
  static const bool monthlyPlanRecurring = true;

  /// Extra fees from an explicit configuration or a verified provider.
  /// Empty on purpose: the UI must not invent processing fees.
  static const List<ConfiguredFee> extraFees = [];

  /// Tax in paisa. Zero until a verified provider or config supplies it.
  static const int taxPaisa = 0;

  static const String mockReferralCode = 'MOCK-0000';

  static const String mockLabel = 'Mock';

  static const String mockDisclosure =
      'Mock behaviour: prices, points, referral commission and the company '
      'allocation are simulated on this device. No payment provider, app '
      'store or bank is contacted. The server will be authoritative later.';

  static const String prototypeCompletionNote =
      'Prototype demonstration: this outcome was chosen in the mock. It is '
      'not a real payment result.';

  static const String pointsPolicy =
      'Promotional points come with a purchase and have a stated NPR '
      'equivalent for display. They are not withdrawable unless product '
      'policy says so. Earned points come from in-app activity. '
      'Cash-convertible rewards (such as a referral commission) are a '
      'separate balance and are not the same as promotional points.';

  static const String standardPlanName = 'Premium';
  static const String monthlyPlanName = 'Premium Monthly';
  static const String complimentaryPlanName = 'Included';
  static const String complimentaryPeriodLabel = 'with your account';
  static const String complimentaryHeadline = 'Included with your account';
  static const String complimentaryBody =
      'Female, LGBTQ+ and other accounts have every Premium feature at no '
      'charge. Only male accounts buy a membership.';
  static const String complimentaryCheckoutRefused =
      'Premium is included with your account. You do not need to buy a '
      'subscription.';
  static const String malePaymentsNotEnabled =
      'Payments are not enabled yet. Premium is not charged from this server.';

  static const List<String> standardFeatures = [
    'See who likes you',
    'Unlimited likes',
    'Priority in discovery',
    'No daily swipe limit',
  ];

  static const List<String> monthlyFeatures = [
    'Everything in Premium',
    'Renews each month until you cancel',
    'Cancel any time; access lasts until the period ends',
  ];

  static const List<String> complimentaryFeatures = [
    'See who likes you',
    'Unlimited likes',
    'Priority in discovery',
    'No daily swipe limit',
  ];
}

/// An extra fee that is only shown when configuration or a provider supplies
/// it. Never invent one in the UI.
class ConfiguredFee {
  const ConfiguredFee({required this.label, required this.paisa});

  final String label;
  final int paisa;
}
