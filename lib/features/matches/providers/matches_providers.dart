import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/match.dart';
import '../../../data/models/matching.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_providers.dart';

/// Counts every change to likes, matches, blocks or conversations. Providers
/// that show that data watch it, so discovery, likes, matches and chat refetch
/// together and cannot disagree about what exists.
class MatchingRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final matchingRevisionProvider = NotifierProvider<MatchingRevision, int>(
  MatchingRevision.new,
);

final matchesProvider = FutureProvider.autoDispose<List<Match>>((ref) {
  ref.watch(matchingRevisionProvider);
  return ref.watch(matchingRepositoryProvider).fetchMatches();
}, retry: (_, _) => null);

final likesReceivedProvider = FutureProvider.autoDispose<List<ReceivedLike>>((
  ref,
) {
  ref.watch(matchingRevisionProvider);
  return ref.watch(matchingRepositoryProvider).fetchLikesReceived();
}, retry: (_, _) => null);

final likesSentProvider = FutureProvider.autoDispose<List<SentLike>>((ref) {
  ref.watch(matchingRevisionProvider);
  return ref.watch(matchingRepositoryProvider).fetchLikesSent();
}, retry: (_, _) => null);

final matchHistoryProvider =
    FutureProvider.autoDispose<List<MatchHistoryEntry>>((ref) {
      ref.watch(matchingRevisionProvider);
      return ref.watch(matchingRepositoryProvider).fetchHistory();
    }, retry: (_, _) => null);

final matchPreferencesProvider = FutureProvider.autoDispose<MatchPreferences>((
  ref,
) {
  ref.watch(matchingRevisionProvider);
  return ref.watch(matchingRepositoryProvider).fetchPreferences();
}, retry: (_, _) => null);

final blockedUsersProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  ref.watch(matchingRevisionProvider);
  return ref.watch(matchingRepositoryProvider).fetchBlocked();
}, retry: (_, _) => null);
