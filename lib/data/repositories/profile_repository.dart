import '../models/profile.dart';

/// Contract for profile data. Phase 1 ships no production implementation
/// (there is no backend); the only implementation is the mock-only one in
/// `mock_profile_repository.dart`.
abstract interface class ProfileRepository {
  Future<List<Profile>> fetchSuggestedProfiles();

  /// People who have liked the signed-in user.
  Future<List<Profile>> fetchLikedYou();
}
