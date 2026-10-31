import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_dating/app/app.dart';
import 'package:social_dating/core/constants/app_constants.dart';
import 'package:social_dating/core/routing/app_router.dart';
import 'package:social_dating/core/utils/clock_provider.dart';
import 'package:social_dating/core/theme/app_theme.dart';
import 'package:social_dating/data/models/account_state.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/session_snapshot.dart';
import 'package:social_dating/data/repositories/mock_auth_repository.dart';
import 'package:social_dating/data/repositories/mock_matching_repository.dart';
import 'package:social_dating/data/repositories/mock_notification_repository.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/repositories/mock_repository_providers.dart';
import 'package:social_dating/data/repositories/mock_settings_repository.dart';
import 'package:social_dating/data/repositories/mock_subscription_repository.dart';
import 'package:social_dating/data/repositories/mock_swipe_repository.dart';
import 'package:social_dating/data/repositories/mock_referral_repository.dart';
import 'package:social_dating/data/repositories/mock_photo_repository.dart';
import 'package:social_dating/data/repositories/mock_wallet_repository.dart';
import 'package:social_dating/data/services/service_providers.dart';
import 'package:social_dating/data/services/share_port.dart';
import 'package:social_dating/features/auth/providers/auth_session_notifier.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/providers/mock_discovery_providers.dart';

/// The session a test starts with.
AuthSession sessionFor(AuthStatus status, {ProfileGender? gender}) =>
    switch (status) {
      AuthStatus.loggedOut => const AuthSession.loggedOut(),
      AuthStatus.loggedIn || AuthStatus.onboardingComplete => AuthSession(
        status: status,
        phone: '+9779841234567',
        phoneLabel: '+977 \u2022\u2022\u2022\u2022\u2022\u20224567',
        displayName: 'Mock User',
        gender: gender,
      ),
      _ => AuthSession(
        status: status,
        phone: '+9779841234567',
        phoneLabel: '+977 \u2022\u2022\u2022\u2022\u2022\u20224567',
        gender: gender,
      ),
    };

/// The fixed "today" used by tests, so age checks never depend on the real
/// date.
final DateTime testNow = DateTime(2026, 10, 14, 12);

/// Pumps the full app at [location] with in-memory preferences, a zero
/// latency mock backend and a session in [session] state. Returns the router
/// for assertions.
Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String location = '/splash',
  Map<String, Object> prefs = const {},
  AuthStatus? session = AuthStatus.loggedOut,
  ProfileGender? gender,
  DateTime Function()? clock,
  MockAuthRepository Function(DateTime Function() now, AccountState? saved)?
  authRepository,
  MockSwipeRepository Function({
    required DateTime Function() now,
    required bool Function() isProfileComplete,
    required MockScenario Function() scenario,
  })?
  swipeRepository,
  MockWalletRepository Function({
    required DateTime Function() now,
    required MockScenario Function() scenario,
    required ProfileGender Function() viewerGender,
  })?
  walletRepository,
  MockReferralRepository Function({
    required DateTime Function() now,
    required MockScenario Function() scenario,
  })?
  referralRepository,
  SharePort? sharePort,
  Duration matchingLatency = Duration.zero,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        initialLocationProvider.overrideWithValue(location),
        clockProvider.overrideWithValue(clock ?? () => testNow),
        // `session: null` restores from the saved snapshot, as on app start.
        sessionProvider.overrideWith(
          () => AuthSessionNotifier(
            initial: session == null
                ? null
                : sessionFor(session, gender: gender),
          ),
        ),
        mockAuthRepositoryProvider.overrideWith((ref) {
          final saved = ref
              .read(localPreferencesServiceProvider)
              .sessionSnapshot
              ?.account;
          final now = ref.watch(clockProvider);
          return authRepository?.call(now, saved) ??
              MockAuthRepository(
                latency: Duration.zero,
                now: now,
                seed: [?saved],
              );
        }),
        mockProfileRepositoryProvider.overrideWith(
          (ref) => MockProfileRepository(
            scenario: ref.watch(mockScenarioProvider),
            latency: Duration.zero,
          ),
        ),
        mockNotificationRepositoryProvider.overrideWith(
          (ref) => MockNotificationRepository(
            scenario: () => ref.read(mockScenarioProvider),
            latency: Duration.zero,
            now: () => ref.read(clockProvider)(),
          ),
        ),
        mockSettingsRepositoryProvider.overrideWith(
          (ref) => MockSettingsRepository(
            preferences: ref.watch(localPreferencesServiceProvider),
            scenario: () => ref.read(mockScenarioProvider),
            latency: Duration.zero,
            now: () => ref.read(clockProvider)(),
          ),
        ),
        mockSubscriptionRepositoryProvider.overrideWith(
          (ref) => MockSubscriptionRepository(
            latency: Duration.zero,
            now: () => ref.read(clockProvider)(),
            scenario: () => ref.read(mockScenarioProvider),
            viewerGender: () =>
                ref.read(sessionProvider).gender ?? ProfileGender.male,
          ),
        ),
        mockReferralRepositoryProvider.overrideWith((ref) {
          DateTime now() => ref.read(clockProvider)();
          MockScenario scenario() => ref.read(mockScenarioProvider);
          return referralRepository?.call(now: now, scenario: scenario) ??
              MockReferralRepository(
                latency: Duration.zero,
                now: now,
                scenario: scenario,
              );
        }),
        if (sharePort != null) sharePortProvider.overrideWithValue(sharePort),
        mockPhotoRepositoryProvider.overrideWith(
          (ref) => MockPhotoRepository(latency: Duration.zero),
        ),
        mockWalletRepositoryProvider.overrideWith((ref) {
          DateTime now() => ref.read(clockProvider)();
          MockScenario scenario() => ref.read(mockScenarioProvider);
          ProfileGender viewerGender() =>
              ref.read(mockSwipeRepositoryProvider).viewerGender;
          return walletRepository?.call(
                now: now,
                scenario: scenario,
                viewerGender: viewerGender,
              ) ??
              MockWalletRepository(
                latency: Duration.zero,
                now: now,
                scenario: scenario,
                viewerGender: viewerGender,
              );
        }),
        // Likes, matches, blocks and chat: one shared zero-latency mock.
        mockMatchingRepositoryProvider.overrideWith(
          (ref) => MockMatchingRepository(
            latency: matchingLatency,
            now: () => ref.read(clockProvider)(),
            scenario: () => ref.read(mockScenarioProvider),
            viewerGender: () =>
                ref.read(mockSwipeRepositoryProvider).viewerGender,
            mockBalancePaisa: () =>
                ref.read(mockSwipeRepositoryProvider).balancePaisa,
            setMockBalancePaisa: (value) =>
                ref.read(mockSwipeRepositoryProvider).balancePaisa = value,
          ),
        ),
        mockSwipeRepositoryProvider.overrideWith((ref) {
          DateTime now() => ref.read(clockProvider)();
          bool complete() => ref.read(sessionProvider).hasCompletedProfile;
          MockScenario scenario() => ref.read(mockScenarioProvider);
          return swipeRepository?.call(
                now: now,
                isProfileComplete: complete,
                scenario: scenario,
              ) ??
              MockSwipeRepository(
                latency: Duration.zero,
                now: now,
                isProfileComplete: complete,
                scenario: scenario,
                viewerGenderOf: () =>
                    ref.read(sessionProvider).gender ?? ProfileGender.male,
                hasPaidPremium: () => ref
                    .read(mockSubscriptionRepositoryProvider)
                    .hasPaidPremium,
                matching: ref.read(mockMatchingRepositoryProvider),
              );
        }),
        ...overrides,
      ],
      child: const SocialDatingApp(),
    ),
  );

  final container = ProviderScope.containerOf(
    tester.element(find.byType(SocialDatingApp)),
  );
  return container.read(routerProvider);
}

/// Uses a typical phone-sized surface (390x844 logical pixels) for the test.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Advances time in small steps (default 1s total). Use instead of
/// `pumpAndSettle` on screens with endless animations such as skeletons.
Future<void> pumpFrames(
  WidgetTester tester, [
  Duration total = const Duration(seconds: 1),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// The path currently on screen. Unlike `currentConfiguration.uri`, this also
/// reflects routes added with `push`.
String currentPath(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

/// The provider container behind a pumped app (read or drive providers).
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SocialDatingApp)));

/// Pumps a single widget inside the app theme (no router).
Future<void> pumpWidgetInTheme(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  List<Override> overrides = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: SafeArea(child: child)),
      ),
    ),
  );
}

/// A [ProviderContainer] (no widgets) with the session wired to the zero
/// latency mock repository and fixed clock, using [prefs]. Creating a second
/// container from the same [prefs] simulates an app restart.
ProviderContainer makeSessionContainer(
  SharedPreferences prefs, {
  DateTime Function()? clock,
  MockAuthRepository Function(DateTime Function() now, AccountState? saved)?
  repository,
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock ?? () => testNow),
      mockAuthRepositoryProvider.overrideWith((ref) {
        final saved = ref
            .read(localPreferencesServiceProvider)
            .sessionSnapshot
            ?.account;
        final now = ref.watch(clockProvider);
        return repository?.call(now, saved) ??
            MockAuthRepository(
              latency: Duration.zero,
              now: now,
              seed: [?saved],
            );
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Preference values that make an app start with a saved mock session.
Map<String, Object> savedSession({
  required AuthStatus status,
  DateTime? savedAt,
  AccountState? account,
  String? displayName,
}) => {
  StorageKeys.sessionSnapshot: SessionSnapshot(
    statusName: status.name,
    savedAt: savedAt ?? testNow,
    phoneLabel: '+977 \u2022\u2022\u2022\u2022\u2022\u20224567',
    displayName: displayName,
    account: account,
  ).encode(),
};
