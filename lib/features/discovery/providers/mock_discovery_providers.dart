// MOCK-ONLY providers. See the header of
// data/repositories/mock_profile_repository.dart. Production providers must
// never depend on anything in this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile.dart';
import '../../../data/repositories/mock_profile_repository.dart';

/// Which state the mock feed should simulate (used by the design preview).
class MockScenarioNotifier extends Notifier<MockScenario> {
  @override
  MockScenario build() => MockScenario.populated;

  void select(MockScenario scenario) => state = scenario;
}

final mockScenarioProvider =
    NotifierProvider<MockScenarioNotifier, MockScenario>(
      MockScenarioNotifier.new,
    );

/// Override in tests with `latency: Duration.zero`.
final mockProfileRepositoryProvider = Provider<MockProfileRepository>(
  (ref) => MockProfileRepository(scenario: ref.watch(mockScenarioProvider)),
);

final mockSuggestedProfilesProvider = FutureProvider.autoDispose<List<Profile>>(
  (ref) => ref.watch(mockProfileRepositoryProvider).fetchSuggestedProfiles(),
  // Surface failures immediately instead of silently retrying.
  retry: (_, _) => null,
);
