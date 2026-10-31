/// Route paths. Keep every path here so navigation is greppable and typo-proof.
abstract final class AppRoutes {
  // Public
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String authPhone = '/auth/phone';
  static const String authVerify = '/auth/verify';

  /// Shown when a previously signed-in session is no longer valid.
  static const String sessionExpired = '/session-expired';

  // Legal documents: readable in every session state.
  static const String legalTerms = '/legal/terms';
  static const String legalPrivacy = '/legal/privacy';

  // First-time onboarding, in order.
  static const String onboardingTerms = '/onboarding/terms';
  static const String onboardingBirthDate = '/onboarding/birthdate';
  static const String onboardingIneligible = '/onboarding/ineligible';
  static const String onboardingGender = '/onboarding/gender';
  static const String profileCompletion = '/profile-completion';
  static const String onboardingComplete = '/onboarding/complete';

  // Tabs (bottom navigation)
  static const String discover = '/discover';
  static const String likes = '/likes';
  static const String matches = '/matches';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String personalInfo = '/profile/personal-info';
  static const String profilePhotos = '/profile/photos';

  static String personalInfoSection(String section) =>
      '$personalInfo/$section';

  // Full-screen destinations
  static const String subscription = '/subscription';
  static const String subscriptionHistory = '/subscription/history';
  static const String subscriptionHelp = '/subscription/help';

  static String subscriptionPlan(String id, {int? paisa}) => Uri(
    path: '$subscription/plan/$id',
    queryParameters: {if (paisa != null) 'paisa': '$paisa'},
  ).toString();

  static Map<String, String> _subscriptionQuery({
    required String planId,
    bool referral = false,
    int? paisa,
  }) => {
    'plan': planId,
    if (referral) 'referral': '1',
    if (paisa != null) 'paisa': '$paisa',
  };

  static String subscriptionCheckout({
    required String planId,
    bool referral = false,
    int? paisa,
  }) => Uri(
    path: '$subscription/checkout',
    queryParameters: _subscriptionQuery(
      planId: planId,
      referral: referral,
      paisa: paisa,
    ),
  ).toString();

  static String subscriptionPay({
    required String planId,
    bool referral = false,
    int? paisa,
  }) => Uri(
    path: '$subscription/pay',
    queryParameters: _subscriptionQuery(
      planId: planId,
      referral: referral,
      paisa: paisa,
    ),
  ).toString();

  static String subscriptionStatus(String id) => '$subscription/status/$id';

  static int? paisaFromQuery(Map<String, String> query) {
    final parsed = int.tryParse(query['paisa'] ?? '');
    return parsed;
  }

  static const String wallet = '/wallet';
  static const String walletActivity = '/wallet/activity';
  static const String walletWelcome = '/wallet/welcome';
  static const String walletWithdraw = '/wallet/withdraw';
  static const String walletWithdrawRequest = '/wallet/withdraw/request';
  static const String walletWithdrawHistory = '/wallet/withdraw/history';
  static const String walletHelp = '/wallet/help';

  static String walletTransaction(String id) => '$walletActivity/$id';

  static String walletWithdrawal(String id) => '$walletWithdraw/$id';
  static const String referrals = '/referrals';
  static const String referralHistory = '/referrals/history';
  static const String referralEarnings = '/referrals/earnings';
  static const String referralHelp = '/referrals/help';

  static String referralCommission(String id) => '$referralEarnings/$id';
  static const String notifications = '/notifications';
  static const String notificationPreferences = '/notifications/preferences';
  static const String settings = '/settings';
  static const String privacy = '/settings/privacy';
  static const String accessibility = '/settings/accessibility';
  static const String help = '/settings/help';
  static const String safety = '/safety';
  static const String blockedUsers = '/safety/blocked';
  static const String report = '/safety/report';
  static const String reportSubmitted = '/safety/report/submitted';
  static const String account = '/account';
  static const String changePhone = '/account/phone';
  static const String deleteAccount = '/account/delete';

  static String reportUser({String? name}) => Uri(
    path: report,
    queryParameters: {if (name != null && name.isNotEmpty) 'name': name},
  ).toString();

  /// Debug-only design system gallery (registered only in debug builds).
  static const String designPreview = '/dev/design-system';

  static const String matchPreferences = '/matches/preferences';
  static const String matchHistory = '/matches/history';

  static String matchDetail(String id) => '$matches/$id';

  static String chatConversation(String id) => '$chat/$id';

  /// Full profile opened from discovery (above the bottom navigation).
  static String discoverProfile(String id) => '$discover/profile/$id';

  /// The phone screen. [login] is the returning-user path (number, code,
  /// then the app). Create-account omits the query and continues to setup.
  static String phone({bool login = false}) =>
      login ? '$authPhone?mode=login' : authPhone;

  static String verifyWithPhone(String phone, {bool login = false}) => Uri(
    path: authVerify,
    queryParameters: {'phone': phone, if (login) 'mode': 'login'},
  ).toString();

  /// Routes that require a fully set-up session.
  static const List<String> protectedPrefixes = [
    discover,
    likes,
    matches,
    chat,
    profile,
    subscription,
    wallet,
    referrals,
    notifications,
    settings,
    safety,
    account,
  ];

  /// Screens that belong to first-time onboarding.
  static const List<String> onboardingPaths = [
    onboardingTerms,
    onboardingBirthDate,
    onboardingIneligible,
    onboardingGender,
    profileCompletion,
    onboardingComplete,
  ];
}
