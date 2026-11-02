// THE SINGLE SEAM between feature code and data sources.
//
// Features depend only on the repository *interfaces* exposed here. Debug
// builds default to mock implementations. Release builds default to API
// implementations that refuse unconfirmed contracts — they never silently
// record fake payments. This is the only non-`mock_*` file (besides
// session_provider.dart and the debug preview) allowed to import mock sources.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/integration_config.dart';
import '../../features/discovery/providers/mock_discovery_providers.dart';
import '../services/service_providers.dart';
import 'api_auth_repository.dart';
import 'api_photo_repository.dart';
import 'api_repositories.dart';
import 'api_swipe_repository.dart';
import 'auth_repository.dart';
import 'matching_repository.dart';
import 'mock_repository_providers.dart';
import 'photo_repository.dart';
import 'profile_repository.dart';
import 'repository_contracts.dart';
import 'settings_repository.dart';
import 'swipe_repository.dart';

final apiMatchingRepositoryProvider = Provider<ApiMatchingRepository>(
  (ref) => ApiMatchingRepository(
    client: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStorageProvider),
  ),
);

/// Authentication and onboarding. Debug default: labelled mock (no SMS).
/// API mode: confirmed `/v1` auth contract.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockAuthRepositoryProvider)
      : ApiAuthRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockProfileRepositoryProvider)
      : const ApiProfileRepository(),
);

/// Discovery deck, swipes and the swipe allowance.
final swipeRepositoryProvider = Provider<SwipeRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockSwipeRepositoryProvider)
      : ApiSwipeRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

/// Likes, matches, preferences and match management.
final matchingRepositoryProvider = Provider<MatchingRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockMatchingRepositoryProvider)
      : ref.watch(apiMatchingRepositoryProvider),
);

/// Conversations belong to matches, so chat reads from the same source.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockMatchingRepositoryProvider)
      : ref.watch(apiMatchingRepositoryProvider),
);

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockPhotoRepositoryProvider)
      : ApiPhotoRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockWalletRepositoryProvider)
      : ApiWalletRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockSubscriptionRepositoryProvider)
      : ApiSubscriptionRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockNotificationRepositoryProvider)
      : ApiNotificationRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockSettingsRepositoryProvider)
      : ApiSettingsRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);

final referralRepositoryProvider = Provider<ReferralRepository>(
  (ref) => IntegrationConfig.useMockRepositories
      ? ref.watch(mockReferralRepositoryProvider)
      : ApiReferralRepository(
          client: ref.watch(apiClientProvider),
          tokens: ref.watch(tokenStorageProvider),
        ),
);
