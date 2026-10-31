// MOCK-ONLY providers for the non-profile mock repositories. Production code
// must not import this file; see repository_providers.dart for the one
// approved seam.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/clock_provider.dart';
import '../../features/discovery/providers/mock_discovery_providers.dart';
import '../../features/auth/providers/session_provider.dart';
import '../models/profile.dart';
import '../services/service_providers.dart';
import 'mock_auth_repository.dart';
import 'mock_matching_repository.dart';
import 'mock_notification_repository.dart';
import 'mock_settings_repository.dart';
import 'mock_subscription_repository.dart';
import 'mock_swipe_repository.dart';
import 'mock_referral_repository.dart';
import 'mock_wallet_repository.dart';
import 'mock_photo_repository.dart';

/// In-memory notification inbox. Created once so mark-read survives
/// navigating away. Override in tests with `latency: Duration.zero`.
final mockNotificationRepositoryProvider = Provider<MockNotificationRepository>(
  (ref) => MockNotificationRepository(
    scenario: () => ref.read(mockScenarioProvider),
    now: () => ref.read(clockProvider)(),
  ),
);

/// Device preferences, mock reports and mock deletion requests. Created once
/// so a submitted report is still there on the confirmation screen.
final mockSettingsRepositoryProvider = Provider<MockSettingsRepository>(
  (ref) => MockSettingsRepository(
    preferences: ref.watch(localPreferencesServiceProvider),
    scenario: () => ref.read(mockScenarioProvider),
    now: () => ref.read(clockProvider)(),
  ),
);

/// In-memory subscription catalog, checkout and prototype payment outcomes.
/// Created once so pending purchases survive navigating between screens.
final mockSubscriptionRepositoryProvider = Provider<MockSubscriptionRepository>(
  (ref) => MockSubscriptionRepository(
    scenario: () => ref.read(mockScenarioProvider),
    now: () => ref.read(clockProvider)(),
    viewerGender: () => ref.read(sessionProvider).gender ?? ProfileGender.male,
  ),
);

/// In-memory referral invites and commissions. Created once so a confirmed
/// mock purchase still shows after navigating away.
final mockReferralRepositoryProvider = Provider<MockReferralRepository>(
  (ref) => MockReferralRepository(
    scenario: () => ref.read(mockScenarioProvider),
    now: () => ref.read(clockProvider)(),
  ),
);

/// In-memory point balances and mock withdrawals. Created once so recorded
/// requests survive navigating between screens. Viewer gender is read lazily
/// from the swipe mock (everyone except male can request).
final mockPhotoRepositoryProvider = Provider<MockPhotoRepository>(
  (ref) => MockPhotoRepository(),
);

final mockWalletRepositoryProvider = Provider<MockWalletRepository>(
  (ref) => MockWalletRepository(
    scenario: () => ref.read(mockScenarioProvider),
    now: () => ref.read(clockProvider)(),
    viewerGender: () => ref.read(mockSwipeRepositoryProvider).viewerGender,
  ),
);

/// The mock "server" for sign-in and onboarding. It is seeded with the account
/// from the saved session snapshot, so a restarted app can continue the same
/// mock account. Override in tests with `latency: Duration.zero`.
final mockAuthRepositoryProvider = Provider<MockAuthRepository>((ref) {
  final snapshot = ref.read(localPreferencesServiceProvider).sessionSnapshot;
  return MockAuthRepository(
    now: ref.watch(clockProvider),
    seed: [if (snapshot?.account != null) snapshot!.account!],
  );
});

/// The in-memory matching "server": likes, matches, blocks, preferences and
/// conversations. One instance serves discovery, likes, matches and chat, so
/// they always agree. Created once; scenario, clock and account type are read
/// lazily so its state is not lost. Override in tests with zero latency.
final Provider<MockMatchingRepository> mockMatchingRepositoryProvider =
    Provider<MockMatchingRepository>(
      (ref) => MockMatchingRepository(
        scenario: () => ref.read(mockScenarioProvider),
        now: () => ref.read(clockProvider)(),
        viewerGender: () => ref.read(mockSwipeRepositoryProvider).viewerGender,
        mockBalancePaisa: () =>
            ref.read(mockSwipeRepositoryProvider).balancePaisa,
        setMockBalancePaisa: (value) =>
            ref.read(mockSwipeRepositoryProvider).balancePaisa = value,
      ),
    );

/// The in-memory swipe "server". It is created once and keeps its counters for
/// the life of the app, so the scenario, clock and session are read lazily
/// instead of watched (watching would rebuild it and lose the counters).
/// Override in tests with latency: Duration.zero.
final mockSwipeRepositoryProvider = Provider<MockSwipeRepository>(
  (ref) => MockSwipeRepository(
    scenario: () => ref.read(mockScenarioProvider),
    now: () => ref.read(clockProvider)(),
    isProfileComplete: () => ref.read(sessionProvider).hasCompletedProfile,
    viewerGenderOf: () =>
        ref.read(sessionProvider).gender ?? ProfileGender.male,
    hasPaidPremium: () =>
        ref.read(mockSubscriptionRepositoryProvider).hasPaidPremium,
    matching: ref.read(mockMatchingRepositoryProvider),
  ),
);
