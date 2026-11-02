import '../models/discovery_filters.dart';
import '../models/profile.dart';
import '../models/swipe.dart';

/// Discovery deck and swipes.
///
/// The server must be authoritative for everything here: which profiles are
/// shown, swipe counting, the Nepal-day boundary, prices, the wallet balance
/// and matches. The UI predicts outcomes only so it feels instant, and always
/// defers to what the repository reports.
abstract interface class SwipeRepository {
  /// Profiles not yet swiped on that satisfy [filters].
  Future<List<Profile>> fetchDeck(DiscoveryFilters filters);

  Future<SwipeQuota> fetchQuota();

  /// Records a swipe. [confirmedPaid] must be true only after the person
  /// confirmed the displayed price. Rejections come back as a
  /// [SwipeOutcome.rejected]; connectivity problems throw.
  Future<SwipeOutcome> swipe(
    String profileId,
    SwipeDirection direction, {
    required bool confirmedPaid,
  });

  /// Reverts the most recent swipe. Unsubscribed males must confirm the
  /// rewind fee first.
  Future<UndoOutcome?> undoLast({bool confirmedPaid = false});

  /// Opens a chat with [profileId] (creates a match if needed). Unsubscribed
  /// males pay the premium action price.
  Future<DiscoveryMessageOutcome> openDiscoveryMessage(
    String profileId, {
    required bool confirmedPaid,
  });
}
