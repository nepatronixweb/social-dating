// ============================================================================
// MOCK DATA ONLY
//
// Everything in this file is fabricated sample data for UI development and
// tests. It must never be wired into production providers, and nothing outside
// `mock_*` files and the approved seams may import it (enforced by
// test/mock_isolation_test.dart). All people below are fictional.
// ============================================================================

import '../../core/errors/app_failure.dart';
import '../models/profile.dart';
import 'profile_repository.dart';

/// Which state the mock repositories should simulate.
enum MockScenario { populated, empty, failure }

/// Shared behaviour for every mock repository: honour [latency], then return
/// [data], an empty value, or throw, depending on [scenario].
Future<T> simulateMockCall<T>({
  required MockScenario scenario,
  required Duration latency,
  required T Function() data,
  required T empty,
}) async {
  if (latency > Duration.zero) await Future<void>.delayed(latency);
  switch (scenario) {
    case MockScenario.populated:
      return data();
    case MockScenario.empty:
      return empty;
    case MockScenario.failure:
      throw const NetworkFailure();
  }
}

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository({
    this.scenario = MockScenario.populated,
    this.latency = const Duration(milliseconds: 700),
  });

  final MockScenario scenario;

  /// Simulated latency so loading states are visible. Use [Duration.zero] in
  /// tests.
  final Duration latency;

  @override
  Future<List<Profile>> fetchSuggestedProfiles() => simulateMockCall(
    scenario: scenario,
    latency: latency,
    data: () => mockProfiles,
    empty: const [],
  );

  @override
  Future<List<Profile>> fetchLikedYou() => simulateMockCall(
    scenario: scenario,
    latency: latency,
    data: () => mockLikedYou,
    empty: const [],
  );
}

/// Clearly fictional sample people (ids are prefixed `mock-`).
const List<Profile> mockProfiles = [
  Profile(
    id: 'mock-1',
    displayName: 'Avery Sample',
    age: 28,
    city: 'Mockville',
    bio: 'Placeholder bio. Sunday markets and slow mornings.',
    interests: ['Coffee', 'Hiking', 'Film'],
    isVerified: true,
    isOnline: true,
    photoCount: 4,
    distanceKm: 3,
    occupation: 'Product designer',
    gender: ProfileGender.female,
    lookingFor: 'Something long-term, taken slowly',
    photoAssets: ['assets/portraits/avery.jpg'],
  ),
  Profile(
    id: 'mock-2',
    displayName: 'Jordan Example',
    age: 31,
    city: 'Testburg',
    bio: 'Placeholder bio. Cooking for friends, badly.',
    interests: ['Cooking', 'Vinyl'],
    isVerified: true,
    photoCount: 3,
    distanceKm: 7,
    occupation: 'Architect',
    gender: ProfileGender.male,
    lookingFor: 'Good conversation first',
    photoAssets: ['assets/portraits/jordan.jpg'],
  ),
  Profile(
    id: 'mock-3',
    displayName: 'Riley Demo',
    age: 26,
    city: 'Sampleton',
    bio: 'Placeholder bio. Climbing gym regular.',
    interests: ['Climbing', 'Travel', 'Dogs'],
    isOnline: true,
    photoCount: 5,
    distanceKm: 12,
    occupation: 'Nurse',
    gender: ProfileGender.female,
    lookingFor: 'A partner for weekend adventures',
    photoAssets: ['assets/portraits/riley.jpg'],
  ),
  Profile(
    id: 'mock-4',
    displayName: 'Sam Placeholder',
    age: 34,
    city: 'Mockville',
    bio: 'Placeholder bio. Bookshops and bike rides.',
    interests: ['Books', 'Cycling'],
    photoCount: 2,
    distanceKm: 5,
    occupation: 'Editor',
    gender: ProfileGender.lgbtq,
    lookingFor: 'Open to seeing where it goes',
    photoAssets: ['assets/portraits/sam.jpg'],
  ),
  ..._moreMockProfiles,
];

const List<Profile> _moreMockProfiles = [
  Profile(
    id: 'mock-10',
    displayName: 'Devon Mockup',
    age: 24,
    city: 'Sampleton',
    bio: 'Placeholder bio. Street photography and late-night noodles.',
    interests: ['Photography', 'Travel', 'Music'],
    isVerified: true,
    photoCount: 4,
    distanceKm: 2,
    occupation: 'Photographer',
    gender: ProfileGender.male,
    lookingFor: 'Someone curious',
  ),
  Profile(
    id: 'mock-11',
    displayName: 'Harper Faux',
    age: 38,
    city: 'Testburg',
    bio: 'Placeholder bio. Marathon training and strong opinions on tea.',
    interests: ['Running', 'Books', 'Coffee'],
    photoCount: 3,
    distanceKm: 18,
    occupation: 'Teacher',
    gender: ProfileGender.female,
    lookingFor: 'A calm, kind partner',
  ),
  Profile(
    id: 'mock-12',
    displayName: 'Emery Specimen',
    age: 22,
    city: 'Mockville',
    bio: 'Placeholder bio. Game nights and board-game cafes.',
    interests: ['Gaming', 'Art', 'Film'],
    isOnline: true,
    photoCount: 2,
    distanceKm: 4,
    occupation: 'Student',
    gender: ProfileGender.lgbtq,
    lookingFor: 'New friends, maybe more',
  ),
  Profile(
    id: 'mock-13',
    displayName: 'Skyler Sandbox',
    age: 41,
    city: 'Sampleton',
    bio: 'Placeholder bio. Chef by day, terrible singer by night.',
    interests: ['Cooking', 'Music', 'Travel'],
    isVerified: true,
    photoCount: 5,
    distanceKm: 35,
    occupation: 'Chef',
    gender: ProfileGender.male,
    lookingFor: 'A long-term partner',
  ),
  Profile(
    id: 'mock-14',
    displayName: 'Blair Fiction',
    age: 29,
    city: 'Testburg',
    bio: 'Placeholder bio. Yoga at sunrise, dogs at all hours.',
    interests: ['Yoga', 'Dogs', 'Hiking'],
    isVerified: true,
    isOnline: true,
    photoCount: 4,
    distanceKm: 9,
    occupation: 'Physiotherapist',
    gender: ProfileGender.female,
    lookingFor: 'Someone active and kind',
  ),
  Profile(
    id: 'mock-15',
    displayName: 'Reese Pretend',
    age: 33,
    city: 'Mockville',
    bio: 'Placeholder bio. Building small boats and bad puns.',
    interests: ['Climbing', 'Cooking', 'Books'],
    photoCount: 3,
    distanceKm: 6,
    occupation: 'Carpenter',
    gender: ProfileGender.male,
    lookingFor: 'A relationship with room to laugh',
  ),
  Profile(
    id: 'mock-16',
    displayName: 'Lane Imaginary',
    age: 45,
    city: 'Sampleton',
    bio: 'Placeholder bio. Slow travel and long lunches.',
    interests: ['Travel', 'Art', 'Books'],
    photoCount: 3,
    distanceKm: 60,
    occupation: 'Curator',
    gender: ProfileGender.female,
    lookingFor: 'A thoughtful companion',
  ),
  Profile(
    id: 'mock-17',
    displayName: 'Ari Notreal',
    age: 27,
    city: 'Testburg',
    bio: 'Placeholder bio. Trail runner, coffee snob, cat person.',
    interests: ['Running', 'Coffee', 'Hiking'],
    isVerified: true,
    photoCount: 4,
    distanceKm: 11,
    occupation: 'Software tester',
    gender: ProfileGender.male,
    lookingFor: 'Someone to explore with',
  ),
];

/// Fictional people who have "liked" the signed-in user.
/// Default mock matches are men so female / LGBTQ+ viewers see them in chat.
const List<Profile> mockLikedYou = [
  Profile(
    id: 'mock-5',
    displayName: 'Morgan Fake',
    age: 29,
    city: 'Testburg',
    interests: ['Yoga', 'Travel'],
    isVerified: true,
    distanceKm: 4,
    gender: ProfileGender.male,
    photoAssets: ['assets/portraits/avery.jpg'],
    spendablePoints: 3200,
  ),
  Profile(
    id: 'mock-6',
    displayName: 'Casey Stub',
    age: 32,
    city: 'Mockville',
    interests: ['Music', 'Coffee'],
    distanceKm: 9,
    gender: ProfileGender.male,
    photoAssets: ['assets/portraits/jordan.jpg'],
    spendablePoints: 4100,
  ),
  Profile(
    id: 'mock-7',
    displayName: 'Taylor Dummy',
    age: 27,
    city: 'Sampleton',
    interests: ['Art', 'Dogs'],
    isVerified: true,
    isOnline: true,
    distanceKm: 2,
    gender: ProfileGender.male,
    photoAssets: ['assets/portraits/riley.jpg'],
    spendablePoints: 2800,
  ),
  Profile(
    id: 'mock-8',
    displayName: 'Quinn Sample',
    age: 30,
    city: 'Testburg',
    interests: ['Food', 'Running'],
    distanceKm: 15,
    gender: ProfileGender.male,
    photoAssets: ['assets/portraits/sam.jpg'],
    spendablePoints: 4610,
  ),
  Profile(
    id: 'mock-9',
    displayName: 'Rowan Test',
    age: 35,
    city: 'Mockville',
    interests: ['Film', 'Books'],
    distanceKm: 6,
    gender: ProfileGender.male,
    photoAssets: ['assets/portraits/avery.jpg'],
    spendablePoints: 1900,
  ),
];
