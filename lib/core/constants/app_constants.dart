/// App-wide constants. No secrets or environment-specific URLs live here.
abstract final class AppConstants {
  static const String appName = 'Social Dating';
  static const String tagline = 'Meet people worth meeting.';

  /// Integer build used with remote `minClientBuild` (Phase 10 client ops).
  static const int buildNumber = 1;

  /// Lockup line under the wordmark on branded entry screens.
  static const String lockupTagline = 'Real people · Real connections';

  /// Line under the lockup on the splash screen.
  static const String splashTagline =
      'Find meaningful connections,\nnot just matches.';

  /// Minimum time the branded splash is shown.
  static const Duration splashDuration = Duration(milliseconds: 1800);

  /// Interest tags offered during profile completion.
  static const List<String> interestOptions = [
    'Coffee',
    'Hiking',
    'Film',
    'Cooking',
    'Travel',
    'Music',
    'Books',
    'Climbing',
    'Art',
    'Dogs',
    'Yoga',
    'Running',
    'Photography',
    'Gaming',
  ];

  static const int minInterests = 3;
  static const int maxInterests = 8;

  /// Cities offered during profile completion. Discovery has no geo yet, so
  /// this is the city label only.
  static const List<String> cityOptions = [
    'Kathmandu',
    'Lalitpur',
    'Bhaktapur',
    'Pokhara',
    'Biratnagar',
    'Bharatpur',
    'Dharan',
    'Nepalgunj',
  ];

  /// Length of the one-time verification code.
  static const int otpLength = 6;

  /// How long before a code can be requested again.
  static const Duration resendCooldown = Duration(seconds: 30);

  /// Mock session lifetime. After this, a restored session shows the
  /// session-expired state. A real backend decides this with token expiry.
  static const Duration sessionMaxAge = Duration(days: 30);

  /// Number of onboarding steps shown by the progress indicator:
  /// phone, code, terms, birth date, profile.
  static const int onboardingSteps = 5;
}

/// Keys for non-sensitive values stored in SharedPreferences.
/// Tokens and other secrets must never be stored here.
abstract final class StorageKeys {
  static const String themeMode = 'pref.theme_mode';

  /// Non-sensitive session state used to restore the UI after a restart. It
  /// never contains a token, a phone number or a birth date.
  static const String sessionSnapshot = 'pref.session_snapshot';

  /// Notification, privacy and accessibility choices. Device-only mock
  /// persistence; never a push token or remote profile flag.
  static const String userPreferences = 'pref.user_preferences';

  /// Invite code typed before verify. Not a secret; cleared after sign-in.
  static const String pendingReferralCode = 'pref.pending_referral_code';

  /// Extended personal-information draft on this device. Never a phone or token.
  static const String personalProfile = 'pref.personal_profile';
}
