// ============================================================================
// MOCK DATA ONLY: in-memory matching "service"
//
// Likes, matches, conversations, blocks and preferences below live in memory
// and vanish when the app restarts. NOTHING here is created on a real service,
// and every person is fictional. One object is the single source of truth for
// discovery, likes, matches and chat, so they cannot disagree. A real backend
// must own all of it. Nothing outside `mock_*` files and the approved seam may
// import this file (test/mock_isolation_test.dart).
// ============================================================================

import 'dart:typed_data';

import '../../core/constants/message_rules.dart';
import '../../core/constants/swipe_rules.dart';
import '../../core/errors/app_failure.dart';
import '../models/chat.dart';
import '../models/match.dart';
import '../models/matching.dart';
import '../models/profile.dart';
import '../models/profile_photo.dart';
import 'matching_repository.dart';
import 'mock_messaging_repository.dart';
import 'mock_profile_repository.dart';
import 'repository_contracts.dart';

class _Origin {
  const _Origin({required this.matched, this.formerInbound});

  /// This like is what created the match.
  final bool matched;

  /// The received like this one answered, restored if the like is undone.
  final ReceivedLike? formerInbound;
}

class MockMatchingRepository implements MatchingRepository, ChatRepository {
  MockMatchingRepository({
    MockScenario Function()? scenario,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? now,
    ProfileGender Function()? viewerGender,
    int Function()? mockBalancePaisa,
    void Function(int)? setMockBalancePaisa,
    Set<String>? willLikeBackIds,
  }) : _scenario = scenario ?? (() => MockScenario.populated),
       _now = now ?? DateTime.now,
       _viewerGender = viewerGender ?? (() => ProfileGender.female),
       willLikeBackIds =
           willLikeBackIds ?? const {'mock-2', 'mock-3', 'mock-10', 'mock-14'} {
    messaging = MockMessagingRepository(
      scenario: () => _scenario(),
      latency: () => latency,
      now: _now,
      viewerGender: _viewerGender,
      balancePaisa: mockBalancePaisa ?? () => _standaloneBalance,
      setBalancePaisa:
          setMockBalancePaisa ?? (value) => _standaloneBalance = value,
      isChatOpen: (id) => !_closedChats.contains(id),
      matches: () => _matches,
    );
    reset();
  }

  final MockScenario Function() _scenario;
  final Duration latency;
  final DateTime Function() _now;
  final ProfileGender Function() _viewerGender;

  /// Used when this mock is constructed without a shared swipe wallet.
  int _standaloneBalance = 100;

  /// In-memory conversations. Unmatch and block close them through [close].
  late final MockMessagingRepository messaging;

  /// People who like you back when you like them in discovery, so a mutual
  /// match can be triggered from mock data.
  final Set<String> willLikeBackIds;

  final List<ReceivedLike> _inbound = [];
  final List<SentLike> _sent = [];
  final List<Match> _matches = [];
  final List<MatchHistoryEntry> _history = [];
  final Set<String> _blocked = {};
  final Map<String, Profile> _blockedPeople = {};
  final Set<String> _unmatched = {};
  final Set<String> _closedChats = {};
  final Map<String, _Origin> _origins = {};
  late MatchPreferences _preferences;
  int _counter = 0;

  // ---- Mock-only controls --------------------------------------------------

  /// Restores the starting sample data.
  void reset() {
    final now = _now();
    DateTime ago(Duration d) => now.subtract(d);

    _inbound
      ..clear()
      ..addAll([
        ReceivedLike(profile: _alex, likedAt: ago(const Duration(minutes: 25))),
        ReceivedLike(profile: _charlie, likedAt: ago(const Duration(hours: 3))),
        ReceivedLike(profile: _jamie, likedAt: ago(const Duration(hours: 9))),
        ReceivedLike(profile: _kai, likedAt: ago(const Duration(days: 1))),
        ReceivedLike(profile: _noa, likedAt: ago(const Duration(days: 3))),
      ]);
    _sent
      ..clear()
      ..addAll([
        SentLike(profile: _sage, likedAt: ago(const Duration(hours: 5))),
        SentLike(profile: _remy, likedAt: ago(const Duration(days: 2))),
      ]);
    _matches
      ..clear()
      ..addAll([
        Match(
          id: matchIdFor('mock-7'),
          profile: mockLikedYou[2],
          matchedAt: ago(const Duration(hours: 2)),
          isNew: true,
          lastActiveAt: ago(const Duration(minutes: 3)),
        ),
        Match(
          id: matchIdFor('mock-6'),
          profile: mockLikedYou[1],
          matchedAt: ago(const Duration(hours: 20)),
          isNew: true,
          lastActiveAt: ago(const Duration(hours: 4)),
        ),
        Match(
          id: matchIdFor('mock-5'),
          profile: mockLikedYou[0],
          matchedAt: ago(const Duration(days: 2)),
          lastActiveAt: ago(const Duration(minutes: 5)),
        ),
        Match(
          id: matchIdFor('mock-8'),
          profile: mockLikedYou[3],
          matchedAt: ago(const Duration(days: 5)),
          lastActiveAt: ago(const Duration(hours: 3)),
        ),
        Match(
          id: matchIdFor('mock-9'),
          profile: mockLikedYou[4],
          matchedAt: ago(const Duration(days: 8)),
          lastActiveAt: ago(const Duration(days: 2)),
        ),
      ]);
    _blocked.clear();
    _blockedPeople.clear();
    _unmatched
      ..clear()
      ..add(_drew.id);
    _closedChats.clear();
    _origins.clear();
    _standaloneBalance = 100;
    messaging.reset();
    _history
      ..clear()
      ..addAll([
        for (final match in _matches)
          MatchHistoryEntry(
            id: 'h-${match.id}',
            profile: match.profile,
            kind: MatchHistoryKind.matched,
            at: match.matchedAt,
          ),
        MatchHistoryEntry(
          id: 'h-drew-matched',
          profile: _drew,
          kind: MatchHistoryKind.matched,
          at: ago(const Duration(days: 24)),
        ),
        MatchHistoryEntry(
          id: 'h-drew-unmatched',
          profile: _drew,
          kind: MatchHistoryKind.unmatched,
          at: ago(const Duration(days: 21)),
        ),
      ]);
    _preferences = MatchPreferences(
      canSetDailyPreference: false,
      newMatchesToday: _newMatchesToday(),
    );
  }

  // ---- Helpers --------------------------------------------------------------

  static String matchIdFor(String profileId) => 'match-$profileId';

  bool get _eligible => _viewerGender().canWithdrawAndSetDailyPreference;

  int _newMatchesToday() {
    final today = nepalDayKey(_now());
    return _matches.where((m) => nepalDayKey(m.matchedAt) == today).length;
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: latency,
    data: data,
    empty: empty,
  );

  /// Runs a change after the simulated latency. Fails when the failure
  /// scenario is selected.
  Future<T> _change<T>(T Function() change) async {
    await _wait();
    if (_scenario() == MockScenario.failure) throw const NetworkFailure();
    return change();
  }

  Match? _matchFor(String profileId) =>
      _matches.where((m) => m.profile.id == profileId).firstOrNull;

  Match _makeMatch(Profile profile) {
    final existing = _matchFor(profile.id);
    if (existing != null) return existing;
    final now = _now();
    final match = Match(
      id: matchIdFor(profile.id),
      profile: profile,
      matchedAt: now,
      isNew: true,
      lastActiveAt: now,
    );
    _matches.insert(0, match);
    _inbound.removeWhere((l) => l.profile.id == profile.id);
    _sent.removeWhere((l) => l.profile.id == profile.id);
    _history.add(
      MatchHistoryEntry(
        id: 'h-${++_counter}',
        profile: profile,
        kind: MatchHistoryKind.matched,
        at: now,
      ),
    );
    return match;
  }

  /// Everyone discovery must not show again: matches, pending likes, people
  /// previously unmatched, and blocked people.
  Set<String> get excludedProfileIds => {
    for (final m in _matches) m.profile.id,
    for (final l in _sent) l.profile.id,
    ..._unmatched,
    ..._blocked,
  };

  // ---- Discovery hooks (called by the mock swipe repository) ---------------

  /// Records a like made in discovery. Mutual likes (an earlier received like,
  /// or a person from [willLikeBackIds]) create exactly one match.
  LikeOutcome recordLike(Profile profile) {
    if (_blocked.contains(profile.id)) return const LikeOutcome();
    final existing = _matchFor(profile.id);
    if (existing != null) return LikeOutcome(match: existing);

    final inbound = _inbound
        .where((l) => l.profile.id == profile.id)
        .firstOrNull;
    if (inbound != null || willLikeBackIds.contains(profile.id)) {
      final match = _makeMatch(profile);
      _origins[profile.id] = _Origin(matched: true, formerInbound: inbound);
      return LikeOutcome(match: match, created: true);
    }
    if (!_sent.any((l) => l.profile.id == profile.id)) {
      _sent.insert(0, SentLike(profile: profile, likedAt: _now()));
    }
    _origins[profile.id] = const _Origin(matched: false);
    return const LikeOutcome();
  }

  /// Records a pass made in discovery.
  void recordPass(Profile profile) {
    _inbound.removeWhere((l) => l.profile.id == profile.id);
  }

  /// Undoes [recordLike] (discovery's mock undo).
  void revertLike(String profileId) {
    final origin = _origins.remove(profileId);
    if (origin == null) return;
    _sent.removeWhere((l) => l.profile.id == profileId);
    if (origin.matched) {
      _matches.removeWhere((m) => m.profile.id == profileId);
      final index = _history.lastIndexWhere(
        (h) => h.profile.id == profileId && h.kind == MatchHistoryKind.matched,
      );
      if (index >= 0) _history.removeAt(index);
    }
    final former = origin.formerInbound;
    if (former != null) _inbound.insert(0, former);
  }

  // ---- MatchingRepository ----------------------------------------------------

  @override
  Future<List<ReceivedLike>> fetchLikesReceived() => _fetch(
    () => [..._inbound]..sort((a, b) => b.likedAt.compareTo(a.likedAt)),
    const [],
  );

  @override
  Future<List<SentLike>> fetchLikesSent() => _fetch(
    () => [..._sent]..sort((a, b) => b.likedAt.compareTo(a.likedAt)),
    const [],
  );

  @override
  Future<List<Match>> fetchMatches() => _fetch(
    () => [..._matches]..sort((a, b) => b.matchedAt.compareTo(a.matchedAt)),
    const [],
  );

  @override
  Future<List<MatchHistoryEntry>> fetchHistory() => _fetch(
    () => [..._history]..sort((a, b) => b.at.compareTo(a.at)),
    const [],
  );

  @override
  Future<LikeOutcome> likeBack(String profileId) => _change(() {
    final existing = _matchFor(profileId);
    if (existing != null) return LikeOutcome(match: existing);
    if (_blocked.contains(profileId)) {
      throw const NotFoundFailure('This person is no longer available.');
    }
    final inbound = _inbound
        .where((l) => l.profile.id == profileId)
        .firstOrNull;
    if (inbound == null) {
      throw const NotFoundFailure('That like is no longer available.');
    }
    final match = _makeMatch(inbound.profile);
    return LikeOutcome(match: match, created: true);
  });

  @override
  Future<void> declineLike(String profileId) => _change(() {
    _inbound.removeWhere((l) => l.profile.id == profileId);
  });

  @override
  Future<void> withdrawLike(String profileId) => _change(() {
    _sent.removeWhere((l) => l.profile.id == profileId);
    _origins.remove(profileId);
  });

  void _close(Profile profile) {
    final chatId = Match.chatIdFor(profile.id);
    _closedChats.add(chatId);
    messaging.close(chatId);
    _origins.remove(profile.id);
  }

  @override
  Future<void> unmatch(String matchId) => _change(() {
    final match = _matches.where((m) => m.id == matchId).firstOrNull;
    if (match == null) return; // Already gone: unmatching twice is harmless.
    _matches.remove(match);
    _unmatched.add(match.profile.id);
    _close(match.profile);
    _history.add(
      MatchHistoryEntry(
        id: 'h-${++_counter}',
        profile: match.profile,
        kind: MatchHistoryKind.unmatched,
        at: _now(),
      ),
    );
  });

  Profile? _knownProfile(String profileId) {
    for (final m in _matches) {
      if (m.profile.id == profileId) return m.profile;
    }
    for (final l in _inbound) {
      if (l.profile.id == profileId) return l.profile;
    }
    for (final l in _sent) {
      if (l.profile.id == profileId) return l.profile;
    }
    for (final p in mockLikedYou) {
      if (p.id == profileId) return p;
    }
    return _blockedPeople[profileId];
  }

  @override
  Future<void> block(String profileId) => _change(() {
    if (_blocked.contains(profileId)) return;
    final profile = _knownProfile(profileId);
    _matches.removeWhere((m) => m.profile.id == profileId);
    _inbound.removeWhere((l) => l.profile.id == profileId);
    _sent.removeWhere((l) => l.profile.id == profileId);
    _blocked.add(profileId);
    if (profile != null) {
      _blockedPeople[profileId] = profile;
      _close(profile);
      _history.add(
        MatchHistoryEntry(
          id: 'h-${++_counter}',
          profile: profile,
          kind: MatchHistoryKind.blocked,
          at: _now(),
        ),
      );
    }
  });

  @override
  Future<List<Profile>> fetchBlocked() =>
      _fetch(() => _blockedPeople.values.toList(growable: false), const []);

  @override
  Future<void> unblock(String profileId) => _change(() {
    _blocked.remove(profileId);
    _blockedPeople.remove(profileId);
  });

  @override
  Future<void> markMatchSeen(String matchId) => _change(() {
    final index = _matches.indexWhere((m) => m.id == matchId);
    if (index >= 0) _matches[index] = _matches[index].copyWith(isNew: false);
  });

  @override
  Future<MatchPreferences> fetchPreferences() => _change(
    () => MatchPreferences(
      canSetDailyPreference: _eligible,
      dailyMatchPreference: _preferences.dailyMatchPreference,
      pauseNewMatches: _preferences.pauseNewMatches,
      showActiveStatus: _preferences.showActiveStatus,
      newMatchesToday: _newMatchesToday(),
    ),
  );

  @override
  Future<MatchPreferences> savePreferences(MatchPreferences preferences) =>
      _change(() {
        final dailyChanged =
            preferences.dailyMatchPreference !=
            _preferences.dailyMatchPreference;
        if (dailyChanged && !_eligible) {
          throw const ValidationFailure(
            'Daily match preferences are not available for this account.',
          );
        }
        if (!MatchPreferences.dailyPreferenceOptions.contains(
          preferences.dailyMatchPreference,
        )) {
          throw const ValidationFailure('Choose one of the listed options.');
        }
        _preferences = MatchPreferences(
          canSetDailyPreference: _eligible,
          dailyMatchPreference: preferences.dailyMatchPreference,
          pauseNewMatches: preferences.pauseNewMatches,
          showActiveStatus: preferences.showActiveStatus,
          newMatchesToday: _newMatchesToday(),
        );
        return _preferences;
      });

  // ---- ChatRepository (delegates to the in-memory messaging mock) -----------

  @override
  Future<List<ChatPreview>> fetchPreviews() => messaging.fetchPreviews();

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) =>
      messaging.fetchMessages(chatId);

  @override
  Future<SendOutcome> sendMessage(
    String chatId,
    String text, {
    bool confirmedPaid = false,
    String? imageAsset,
    String? retryOfId,
  }) => messaging.sendMessage(
    chatId,
    text,
    confirmedPaid: confirmedPaid,
    imageAsset: imageAsset,
    retryOfId: retryOfId,
  );

  @override
  Future<void> markRead(String chatId) => messaging.markRead(chatId);

  @override
  Future<void> setMuted(String chatId, {required bool muted}) =>
      messaging.setMuted(chatId, muted: muted);

  @override
  Future<void> hideConversation(String chatId) =>
      messaging.hideConversation(chatId);

  @override
  bool get attachFromDevice => messaging.attachFromDevice;

  @override
  Future<ProfilePhoto> uploadChatPhoto(
    String chatId, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
  }) => messaging.uploadChatPhoto(
    chatId,
    bytes: bytes,
    filename: filename,
    contentType: contentType,
  );

  @override
  MessageQuote quote(String text) => messaging.quote(text);

  @override
  int get mockBalancePaisa => messaging.mockBalancePaisa;
}

// ---- Fictional people only seen through likes and matches -------------------

const Profile _alex = Profile(
  id: 'mock-21',
  displayName: 'Alex Imaginary',
  age: 27,
  city: 'Mockville',
  bio: 'Placeholder bio. Bakes bread, loses at chess, gracefully.',
  interests: ['Cooking', 'Books', 'Coffee'],
  isVerified: true,
  isOnline: true,
  photoCount: 4,
  distanceKm: 4,
  occupation: 'Baker',
  gender: ProfileGender.male,
);

const Profile _charlie = Profile(
  id: 'mock-22',
  displayName: 'Charlie Fiction',
  age: 30,
  city: 'Testburg',
  bio: 'Placeholder bio. Weekend cyclist, weekday spreadsheet wrangler.',
  interests: ['Running', 'Travel'],
  photoCount: 3,
  distanceKm: 9,
  occupation: 'Analyst',
  gender: ProfileGender.lgbtq,
);

const Profile _jamie = Profile(
  id: 'mock-23',
  displayName: 'Jamie Standin',
  age: 25,
  city: 'Sampleton',
  bio: 'Placeholder bio. Plays bass badly and with enthusiasm.',
  interests: ['Music', 'Film', 'Art'],
  isVerified: true,
  photoCount: 5,
  distanceKm: 3,
  occupation: 'Sound engineer',
  gender: ProfileGender.female,
);

const Profile _kai = Profile(
  id: 'mock-24',
  displayName: 'Kai Hypothetical',
  age: 33,
  city: 'Mockville',
  bio: 'Placeholder bio. Mountains first, opinions second.',
  interests: ['Hiking', 'Photography', 'Dogs'],
  photoCount: 3,
  distanceKm: 14,
  occupation: 'Guide',
  gender: ProfileGender.lgbtq,
);

const Profile _noa = Profile(
  id: 'mock-25',
  displayName: 'Noa Fabricated',
  age: 29,
  city: 'Testburg',
  bio: 'Placeholder bio. Always knows a good tea shop.',
  interests: ['Yoga', 'Books'],
  isVerified: true,
  photoCount: 4,
  distanceKm: 6,
  occupation: 'Librarian',
  gender: ProfileGender.female,
);

const Profile _sage = Profile(
  id: 'mock-26',
  displayName: 'Sage Mockingbird',
  age: 28,
  city: 'Sampleton',
  bio: 'Placeholder bio. Plant parent and amateur potter.',
  interests: ['Art', 'Yoga'],
  isVerified: true,
  photoCount: 3,
  distanceKm: 8,
  occupation: 'Potter',
  gender: ProfileGender.female,
);

const Profile _remy = Profile(
  id: 'mock-27',
  displayName: 'Remy Standby',
  age: 31,
  city: 'Mockville',
  bio: 'Placeholder bio. Cooks for one, shares for two.',
  interests: ['Cooking', 'Film'],
  photoCount: 2,
  distanceKm: 11,
  occupation: 'Pharmacist',
  gender: ProfileGender.male,
);

const Profile _drew = Profile(
  id: 'mock-28',
  displayName: 'Drew Faux',
  age: 32,
  city: 'Testburg',
  interests: ['Gaming'],
  photoCount: 2,
  distanceKm: 20,
  gender: ProfileGender.male,
);
