import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/utils/time_format.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/confirmation_dialog.dart';
import 'package:social_dating/core/widgets/skeleton_layouts.dart';
import 'package:social_dating/data/models/discovery_filters.dart';
import 'package:social_dating/data/models/match.dart';
import 'package:social_dating/data/models/matching.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/swipe.dart';
import 'package:social_dating/data/repositories/mock_matching_repository.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/repositories/mock_repository_providers.dart';
import 'package:social_dating/data/repositories/mock_swipe_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/providers/mock_discovery_providers.dart';
import 'package:social_dating/features/matches/presentation/match_detail_screen.dart';
import 'package:social_dating/features/matches/presentation/matches_screen.dart';
import 'package:social_dating/features/matches/providers/matches_providers.dart';

import 'helpers/pump_app.dart';

class _FixedScenario extends MockScenarioNotifier {
  _FixedScenario(this.initial);
  final MockScenario initial;

  @override
  MockScenario build() => initial;
}

MockMatchingRepository _repo({
  ProfileGender gender = ProfileGender.female,
  MockScenario scenario = MockScenario.populated,
}) => MockMatchingRepository(
  latency: Duration.zero,
  now: () => testNow,
  scenario: () => scenario,
  viewerGender: () => gender,
);

final _avery = mockProfiles[0]; // not a mutual like
final _jordan = mockProfiles[1]; // likes back (mutual)
final _riley = mockProfiles[2]; // likes back (mutual), shown to male viewers

Future<List<String>> _matchIds(MockMatchingRepository repo) async => [
  for (final m in await repo.fetchMatches()) m.id,
];

/// Opens the app signed in at [location] with the shared zero-latency mock.
Future<GoRouter> openApp(
  WidgetTester tester, {
  String location = AppRoutes.likes,
  MockScenario scenario = MockScenario.populated,
}) async {
  usePhoneScreen(tester);
  final router = await pumpApp(
    tester,
    location: location,
    session: AuthStatus.loggedIn,
    overrides: [
      mockScenarioProvider.overrideWith(() => _FixedScenario(scenario)),
    ],
  );
  await pumpFrames(tester);
  return router;
}

MockMatchingRepository _appRepo(WidgetTester tester) =>
    containerOf(tester).read(mockMatchingRepositoryProvider);

/// Scrolls [finder] into view, then taps (sheets and lists scroll in tests).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

Finder _inDialog(String text) => find.descendant(
  of: find.byType(AppConfirmationDialog),
  matching: find.text(text),
);

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  group('repository: mutual likes and duplicate prevention', () {
    test(
      'a mutual like creates exactly one match, however often it runs',
      () async {
        final repo = _repo();
        final first = repo.recordLike(_jordan);
        final second = repo.recordLike(_jordan);

        expect(first.created, isTrue);
        expect(first.match!.id, 'match-mock-2');
        expect(second.created, isFalse);
        expect(second.match!.id, first.match!.id);
        final ids = await _matchIds(repo);
        expect(ids.where((id) => id == 'match-mock-2'), hasLength(1));
        expect(ids.toSet(), hasLength(ids.length));
        final history = await repo.fetchHistory();
        expect(
          history.where(
            (h) =>
                h.profile.id == 'mock-2' && h.kind == MatchHistoryKind.matched,
          ),
          hasLength(1),
        );
      },
    );

    test(
      'a one-sided like waits in "sent" once and creates no match',
      () async {
        final repo = _repo();
        repo.recordLike(_avery);
        repo.recordLike(_avery);

        expect(await _matchIds(repo), isNot(contains('match-mock-1')));
        final sent = await repo.fetchLikesSent();
        expect(sent.where((l) => l.profile.id == 'mock-1'), hasLength(1));
      },
    );

    test('liking someone who liked you matches and clears the like', () async {
      final repo = _repo();
      final received = (await repo.fetchLikesReceived()).first;

      final outcome = repo.recordLike(received.profile);

      expect(outcome.created, isTrue);
      expect(
        (await repo.fetchLikesReceived()).map((l) => l.profile.id),
        isNot(contains(received.profile.id)),
      );
      expect(await _matchIds(repo), contains(outcome.match!.id));
    });

    test('likeBack twice does not create a second match', () async {
      final repo = _repo();
      final profile = (await repo.fetchLikesReceived()).first.profile;
      final before = (await repo.fetchMatches()).length;

      final first = await repo.likeBack(profile.id);
      final second = await repo.likeBack(profile.id);

      expect(first.created, isTrue);
      expect(second.created, isFalse);
      expect(second.match!.id, first.match!.id);
      expect((await repo.fetchMatches()).length, before + 1);
    });

    test('likeBack for a like that no longer exists is refused', () async {
      final repo = _repo();
      await expectLater(
        repo.likeBack('mock-999'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test(
      'undoing a like removes the match and restores the received like',
      () async {
        final repo = _repo();
        final received = (await repo.fetchLikesReceived()).first;
        repo.recordLike(received.profile);
        repo.recordLike(_jordan);

        repo.revertLike(received.profile.id);
        repo.revertLike(_jordan.id);

        final ids = await _matchIds(repo);
        expect(ids, isNot(contains('match-${received.profile.id}')));
        expect(ids, isNot(contains('match-mock-2')));
        expect(
          (await repo.fetchLikesReceived()).map((l) => l.profile.id),
          contains(received.profile.id),
        );
        expect(
          (await repo.fetchHistory()).where(
            (h) =>
                h.profile.id == 'mock-2' && h.kind == MatchHistoryKind.matched,
          ),
          isEmpty,
        );
      },
    );

    test('declining and withdrawing remove only that like', () async {
      final repo = _repo();
      final received = await repo.fetchLikesReceived();
      final sent = await repo.fetchLikesSent();

      await repo.declineLike(received.first.profile.id);
      await repo.withdrawLike(sent.first.profile.id);

      expect((await repo.fetchLikesReceived()).length, received.length - 1);
      expect((await repo.fetchLikesSent()).length, sent.length - 1);
    });

    test('a failing service changes nothing', () async {
      var scenario = MockScenario.populated;
      final repo = MockMatchingRepository(
        latency: Duration.zero,
        now: () => testNow,
        scenario: () => scenario,
      );
      final before = await repo.fetchLikesReceived();
      final matchesBefore = await _matchIds(repo);

      scenario = MockScenario.failure;
      await expectLater(
        repo.likeBack(before.first.profile.id),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        repo.unmatch('match-mock-5'),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(repo.block('mock-6'), throwsA(isA<NetworkFailure>()));

      scenario = MockScenario.populated;
      expect((await repo.fetchLikesReceived()).length, before.length);
      expect(await _matchIds(repo), matchesBefore);
    });

    test('the empty scenario returns empty lists', () async {
      final repo = _repo(scenario: MockScenario.empty);
      expect(await repo.fetchLikesReceived(), isEmpty);
      expect(await repo.fetchLikesSent(), isEmpty);
      expect(await repo.fetchMatches(), isEmpty);
      expect(await repo.fetchHistory(), isEmpty);
    });
  });

  group('repository: unmatch and block', () {
    test(
      'unmatch removes the match, closes the chat and records history',
      () async {
        final repo = _repo();
        expect(
          (await repo.fetchPreviews()).map((p) => p.id),
          contains('chat-mock-5'),
        );

        await repo.unmatch('match-mock-5');
        await repo.unmatch('match-mock-5'); // harmless the second time

        expect(await _matchIds(repo), isNot(contains('match-mock-5')));
        expect(
          (await repo.fetchPreviews()).map((p) => p.id),
          isNot(contains('chat-mock-5')),
        );
        await expectLater(
          repo.fetchMessages('chat-mock-5'),
          throwsA(isA<NotFoundFailure>()),
        );
        await expectLater(
          repo.sendMessage('chat-mock-5', 'hello?'),
          throwsA(isA<NotFoundFailure>()),
        );
        expect(repo.excludedProfileIds, contains('mock-5'));
        final history = await repo.fetchHistory();
        expect(
          history.where(
            (h) =>
                h.profile.id == 'mock-5' &&
                h.kind == MatchHistoryKind.unmatched,
          ),
          hasLength(1),
        );
      },
    );

    test(
      'block removes every trace of the person and stays idempotent',
      () async {
        final repo = _repo();
        final inbound = (await repo.fetchLikesReceived()).first.profile;

        await repo.block(inbound.id);
        await repo.block('mock-6'); // a match
        await repo.block('mock-6');

        expect(
          (await repo.fetchLikesReceived()).map((l) => l.profile.id),
          isNot(contains(inbound.id)),
        );
        expect(await _matchIds(repo), isNot(contains('match-mock-6')));
        expect(repo.excludedProfileIds, containsAll([inbound.id, 'mock-6']));
        final blocked = (await repo.fetchHistory()).where(
          (h) => h.kind == MatchHistoryKind.blocked,
        );
        expect(blocked.where((h) => h.profile.id == 'mock-6'), hasLength(1));
        // Blocked people cannot be liked back or matched.
        await expectLater(
          repo.likeBack(inbound.id),
          throwsA(isA<NotFoundFailure>()),
        );
        expect(repo.recordLike(inbound).match, isNull);
      },
    );
  });

  group('repository: match preferences', () {
    test('only eligible accounts may change the daily preference', () async {
      for (final gender in ProfileGender.values) {
        final repo = _repo(gender: gender);
        final prefs = await repo.fetchPreferences();
        final eligible = gender.canWithdrawAndSetDailyPreference;
        expect(prefs.canSetDailyPreference, eligible, reason: '$gender');

        final change = repo.savePreferences(
          prefs.copyWith(dailyMatchPreference: 3),
        );
        if (eligible) {
          expect((await change).dailyMatchPreference, 3);
          expect((await repo.fetchPreferences()).dailyMatchPreference, 3);
        } else {
          await expectLater(change, throwsA(isA<ValidationFailure>()));
          expect(
            (await repo.fetchPreferences()).dailyMatchPreference,
            MatchPreferences.defaultDailyPreference,
          );
        }
      }
    });

    test(
      'other settings can be saved by anyone, bad options are refused',
      () async {
        final repo = _repo(gender: ProfileGender.male);
        final prefs = await repo.fetchPreferences();
        final saved = await repo.savePreferences(
          prefs.copyWith(pauseNewMatches: true, showActiveStatus: false),
        );
        expect(saved.pauseNewMatches, isTrue);
        expect(saved.showActiveStatus, isFalse);

        final woman = _repo();
        await expectLater(
          woman.savePreferences(
            (await woman.fetchPreferences()).copyWith(dailyMatchPreference: 7),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      },
    );

    test('the daily count is information only', () async {
      final repo = _repo();
      final before = (await repo.fetchPreferences()).newMatchesToday;
      repo.recordLike(_jordan);
      final after = await repo.fetchPreferences();
      expect(after.newMatchesToday, before + 1);
      // Choosing a smaller preference never blocks a match.
      await repo.savePreferences(after.copyWith(dailyMatchPreference: 1));
      final blair = mockProfiles.firstWhere((p) => p.id == 'mock-14');
      expect(repo.recordLike(blair).created, isTrue);
    });
  });

  group('swipe repository shares the matching source of truth', () {
    MockSwipeRepository swipeRepo(MockMatchingRepository matching) =>
        MockSwipeRepository(
          latency: Duration.zero,
          now: () => testNow,
          matching: matching,
        );

    test(
      'likes, matches and the deck stay consistent, and undo reverts',
      () async {
        final matching = _repo();
        final swipes = swipeRepo(matching);

        final matched = await swipes.swipe(
          _jordan.id,
          SwipeDirection.right,
          confirmedPaid: false,
        );
        await swipes.swipe(
          _avery.id,
          SwipeDirection.right,
          confirmedPaid: false,
        );

        expect(matched.matchedProfile, _jordan);
        expect(await _matchIds(matching), contains('match-mock-2'));
        expect(
          (await matching.fetchLikesSent()).map((l) => l.profile.id),
          contains('mock-1'),
        );
        final deck = await swipes.fetchDeck(DiscoveryFilters.defaults);
        expect(deck.map((p) => p.id), isNot(contains('mock-1')));
        expect(deck.map((p) => p.id), isNot(contains('mock-2')));

        await swipes.undoLast(confirmedPaid: true); // Avery
        expect(
          (await matching.fetchLikesSent()).map((l) => l.profile.id),
          isNot(contains('mock-1')),
        );
        await swipes.undoLast(confirmedPaid: true); // Jordan
        expect(await _matchIds(matching), isNot(contains('match-mock-2')));
      },
    );

    test('swiping right on someone who liked you creates one match', () async {
      final matching = _repo();
      final profile = (await matching.fetchLikesReceived()).first.profile;
      final swipes = MockSwipeRepository(
        latency: Duration.zero,
        now: () => testNow,
        catalog: [profile, _avery],
        matching: matching,
      );

      final outcome = await swipes.swipe(
        profile.id,
        SwipeDirection.right,
        confirmedPaid: false,
      );

      expect(outcome.matchedProfile, profile);
      expect(
        (await _matchIds(matching)).where((id) => id == 'match-${profile.id}'),
        hasLength(1),
      );
    });

    test('blocked and matched people never return to the deck', () async {
      final matching = _repo();
      final swipes = swipeRepo(matching);
      await matching.block(mockProfiles[2].id); // Riley
      final deck = await swipes.fetchDeck(DiscoveryFilters.defaults);
      expect(deck.map((p) => p.id), isNot(contains('mock-3')));
    });

    test('passing removes a received like', () async {
      final matching = _repo();
      final profile = (await matching.fetchLikesReceived()).first.profile;
      matching.recordPass(profile);
      expect(
        (await matching.fetchLikesReceived()).map((l) => l.profile.id),
        isNot(contains(profile.id)),
      );
    });
  });

  group('time labels', () {
    test('timestamps and activity read naturally', () {
      final now = testNow;
      expect(
        timestampLabel(
          'Liked',
          now.subtract(const Duration(minutes: 25)),
          now: now,
        ),
        'Liked 25m ago',
      );
      expect(timestampLabel('Liked', now, now: now), 'Liked just now');
      expect(
        timestampLabel(
          'Matched',
          now.subtract(const Duration(hours: 30)),
          now: now,
        ),
        'Matched yesterday',
      );
      expect(activityLabel(null, now: now), isNull);
      expect(
        activityLabel(now.subtract(const Duration(minutes: 3)), now: now),
        'Active now',
      );
      expect(
        activityLabel(now.subtract(const Duration(hours: 3)), now: now),
        'Active 3h ago',
      );
    });

    test('Match exposes a stable chat id and activity', () {
      final match = Match(
        id: 'match-x',
        profile: _avery,
        matchedAt: testNow,
        lastActiveAt: testNow.subtract(const Duration(minutes: 2)),
      );
      expect(match.chatId, 'chat-mock-1');
      expect(match.isActiveNow(testNow), isTrue);
      expect(match.isActiveNow(testNow.add(const Duration(hours: 1))), isFalse);
    });
  });

  group('empty states', () {
    testWidgets('no likes received and none sent', (tester) async {
      await openApp(tester, scenario: MockScenario.empty);

      expect(find.text('No likes yet'), findsOneWidget);
      expect(find.text('Go to Discover'), findsOneWidget);

      await tester.tap(find.text('Sent'));
      await pumpFrames(tester);
      expect(find.text('No likes sent'), findsOneWidget);
    });

    testWidgets('no matches', (tester) async {
      await openApp(
        tester,
        location: AppRoutes.matches,
        scenario: MockScenario.empty,
      );

      expect(find.text('No matches yet'), findsOneWidget);
      expect(find.text('See who likes you'), findsOneWidget);
    });

    testWidgets('no history', (tester) async {
      await openApp(
        tester,
        location: AppRoutes.matchHistory,
        scenario: MockScenario.empty,
      );
      expect(find.text('No history yet'), findsOneWidget);
    });

    testWidgets('the empty state action leads somewhere useful', (
      tester,
    ) async {
      final router = await openApp(
        tester,
        location: AppRoutes.matches,
        scenario: MockScenario.empty,
      );
      await tester.tap(find.text('See who likes you'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.likes);
    });
  });

  group('pending, loading and error states', () {
    testWidgets('shows a skeleton while loading, then the matches', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.matches,
        session: AuthStatus.loggedIn,
        matchingLatency: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.text('Morgan Fake, 29'), findsNothing);

      await pumpFrames(tester, const Duration(seconds: 2));
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Morgan Fake, 29'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry that works', (tester) async {
      await openApp(
        tester,
        location: AppRoutes.matches,
        scenario: MockScenario.failure,
      );
      expect(find.text('Try again'), findsOneWidget);

      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.populated);
      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);

      expect(find.text('Try again'), findsNothing);
      expect(find.text('Morgan Fake, 29'), findsOneWidget);
    });

    testWidgets('a failed like back keeps the like and explains', (
      tester,
    ) async {
      await openApp(tester);
      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.failure);

      await tester.tap(find.text('Like back').first);
      await pumpFrames(tester);

      expect(find.text('It\'s a match!'), findsNothing);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
    });
  });

  group('mutual-match flow', () {
    testWidgets('like back creates one match and celebrates honestly', (
      tester,
    ) async {
      final router = await openApp(tester);
      expect(find.text('Alex Imaginary, 27'), findsOneWidget);
      expect(find.textContaining('Liked you 25m ago'), findsOneWidget);

      await tester.tap(find.text('Like back').first);
      await pumpFrames(tester);

      expect(find.text('It\'s a match!'), findsOneWidget);
      expect(find.text('You and Alex liked each other.'), findsOneWidget);

      await tapVisible(tester, find.text('Maybe later'));
      expect(find.text('It\'s a match!'), findsNothing);
      expect(find.text('Alex Imaginary, 27'), findsNothing);

      router.go(AppRoutes.matches);
      await pumpFrames(tester);
      expect(_key('match-card-match-mock-21'), findsOneWidget);
    });

    testWidgets('"Say hello" opens the new conversation', (tester) async {
      final router = await openApp(tester);
      await tester.tap(find.text('Like back').first);
      await pumpFrames(tester);

      await tapVisible(tester, find.text('Say hello'));

      expect(currentPath(router), AppRoutes.chatConversation('chat-mock-21'));
      expect(find.text('Alex Imaginary'), findsOneWidget);
      expect(find.text('Say hello'), findsOneWidget); // empty conversation
    });

    testWidgets('a mutual right swipe in discovery shows up everywhere', (
      tester,
    ) async {
      final router = await openApp(tester, location: AppRoutes.discover);

      await tester.tap(find.byTooltip('Pass on ${_avery.displayName}'));
      await pumpFrames(tester);
      await tester.tap(find.byTooltip('Like ${_riley.displayName}'));
      await pumpFrames(tester);
      expect(find.text('It\'s a match!'), findsOneWidget);
      await tapVisible(tester, find.text('Keep swiping'));

      router.go(AppRoutes.matches);
      await pumpFrames(tester);
      expect(_key('match-card-match-mock-3'), findsOneWidget);

      router.go(AppRoutes.likes);
      await pumpFrames(tester);
      await tester.tap(find.text('Sent'));
      await pumpFrames(tester);
      expect(_key('sent-mock-2'), findsNothing);
    });

    testWidgets('a one-sided like waits in Sent and can be withdrawn', (
      tester,
    ) async {
      final router = await openApp(tester, location: AppRoutes.discover);
      await tester.tap(find.byTooltip('Like ${_avery.displayName}'));
      await pumpFrames(tester);

      router.go(AppRoutes.likes);
      await pumpFrames(tester);
      await tester.tap(find.text('Sent'));
      await pumpFrames(tester);
      expect(_key('sent-mock-1'), findsOneWidget);
      expect(find.text('Waiting for a reply'), findsWidgets);

      await tapVisible(
        tester,
        find.descendant(
          of: _key('sent-mock-1'),
          matching: find.text('Withdraw like'),
        ),
      );

      expect(_key('sent-mock-1'), findsNothing);
      expect(find.textContaining('Like withdrawn'), findsOneWidget);
      expect(
        (await _appRepo(tester).fetchLikesSent()).map((l) => l.profile.id),
        isNot(contains('mock-1')),
      );
    });

    testWidgets('"Not now" removes a received like', (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Not now').first);
      await pumpFrames(tester);

      expect(find.text('Alex Imaginary, 27'), findsNothing);
      expect(find.text('Charlie Fiction, 30'), findsOneWidget);
    });
  });

  group('duplicate prevention in the interface', () {
    testWidgets('a person is never shown twice across matches', (tester) async {
      final router = await openApp(tester);
      await tester.tap(find.text('Like back').first);
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Maybe later'));

      // Matching them again through the service changes nothing.
      final repo = _appRepo(tester);
      final again = await repo.likeBack('mock-21');
      expect(again.created, isFalse);
      containerOf(tester).read(matchingRevisionProvider.notifier).bump();

      router.go(AppRoutes.matches);
      await pumpFrames(tester);
      expect(_key('match-card-match-mock-21'), findsOneWidget);
      expect(find.text('Alex Imaginary'), findsOneWidget);
      expect(
        (await repo.fetchMatches()).where((m) => m.profile.id == 'mock-21'),
        hasLength(1),
      );
    });

    testWidgets('new matches appear once: in the strip or the list, not both', (
      tester,
    ) async {
      await openApp(tester, location: AppRoutes.matches);

      // Taylor and Casey are new (strip), the rest are earlier (list).
      expect(find.text('New matches'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      for (final id in ['mock-5', 'mock-6', 'mock-7', 'mock-8', 'mock-9']) {
        expect(_key('match-card-match-$id'), findsOneWidget, reason: id);
      }
    });
  });

  group('matches, activity and history', () {
    testWidgets('shows readable names, timestamps and recently-active hints', (
      tester,
    ) async {
      await openApp(tester, location: AppRoutes.matches);

      expect(find.text('Morgan Fake, 29'), findsOneWidget);
      expect(find.text('Matched 2d ago'), findsOneWidget);
      expect(find.textContaining('Active now'), findsWidgets);
      expect(find.text('Active 3h ago'), findsOneWidget);
    });

    testWidgets('history lists matches and unmatches with timestamps', (
      tester,
    ) async {
      await openApp(tester, location: AppRoutes.matchHistory);

      await tester.scrollUntilVisible(
        _key('history-h-drew-unmatched'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Unmatched 21d ago'), findsOneWidget);
      expect(find.text('Matched'), findsWidgets);
    });

    testWidgets('header actions open preferences and history', (tester) async {
      final router = await openApp(tester, location: AppRoutes.matches);

      await tester.tap(find.byTooltip('Match history'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.matchHistory);
      await tester.tap(find.byTooltip('Back'));
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Match preferences'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.matchPreferences);
    });

    testWidgets('a match opens its detail with the message action', (
      tester,
    ) async {
      final router = await openApp(tester, location: AppRoutes.matches);
      await tapVisible(tester, _key('match-card-match-mock-5'));

      expect(find.byType(MatchDetailScreen), findsOneWidget);
      expect(find.text('Morgan Fake, 29'), findsOneWidget);
      expect(find.text('Send a message'), findsOneWidget);

      await tester.tap(find.text('Send a message'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.chatConversation('chat-mock-5'));
    });

    testWidgets('opening a new match marks it as seen', (tester) async {
      await openApp(tester, location: AppRoutes.matches);
      expect(find.text('New matches'), findsOneWidget);

      await tapVisible(tester, _key('match-card-match-mock-7'));
      await pumpFrames(tester);
      await tester.tap(find.byTooltip('Back'));
      await pumpFrames(tester);

      final match = (await _appRepo(
        tester,
      ).fetchMatches()).firstWhere((m) => m.id == 'match-mock-7');
      expect(match.isNew, isFalse);
    });

    testWidgets('a match that is gone says so plainly', (tester) async {
      await openApp(tester, location: AppRoutes.matchDetail('match-nobody'));
      expect(find.text('This match is no longer available'), findsOneWidget);
      expect(find.text('Back to matches'), findsOneWidget);
    });
  });

  group('match preferences', () {
    Future<GoRouter> openPrefs(
      WidgetTester tester, {
      required ProfileGender gender,
    }) async {
      final router = await openApp(tester, location: AppRoutes.discover);
      containerOf(tester).read(mockSwipeRepositoryProvider).viewerGender =
          gender;
      router.go(AppRoutes.matchPreferences);
      await pumpFrames(tester);
      return router;
    }

    AppButton saveButton(WidgetTester tester) => tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Save preferences'),
    );

    testWidgets('eligible accounts choose a preference and save it', (
      tester,
    ) async {
      await openPrefs(tester, gender: ProfileGender.female);

      expect(find.text('Daily match preference'), findsOneWidget);
      expect(find.text('5 per day'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull); // nothing changed yet

      await tapVisible(tester, find.text('3 per day'));
      expect(saveButton(tester).onPressed, isNotNull);

      await tapVisible(tester, find.text('Save preferences'));

      expect(find.text('Preferences saved'), findsOneWidget);
      expect(find.textContaining('Your match preferences have been saved.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
      expect(
        (await _appRepo(tester).fetchPreferences()).dailyMatchPreference,
        3,
      );
    });

    testWidgets('LGBTQ+ accounts are eligible too', (tester) async {
      await openPrefs(tester, gender: ProfileGender.lgbtq);
      expect(find.text('10 per day'), findsOneWidget);
    });

    testWidgets('the preference is clearly not a guaranteed count', (
      tester,
    ) async {
      await openPrefs(tester, gender: ProfileGender.female);

      expect(find.text('A preference, not a promise'), findsOneWidget);
      expect(
        find.textContaining('no number of matches is guaranteed'),
        findsOneWidget,
      );
      // Today's count is a separate, labelled sample figure.
      expect(find.text('Today (sample data)'), findsOneWidget);
      expect(find.textContaining('New matches today:'), findsOneWidget);
      expect(
        find.textContaining('Your preference: up to 5 per day'),
        findsOneWidget,
      );
    });

    testWidgets('changing the preference updates the "up to" line', (
      tester,
    ) async {
      await openPrefs(tester, gender: ProfileGender.female);
      await tapVisible(tester, find.text('10 per day'));
      expect(
        find.textContaining('Your preference: up to 10 per day'),
        findsOneWidget,
      );
    });

    testWidgets('other accounts see an explanation and no daily choices', (
      tester,
    ) async {
      await openPrefs(tester, gender: ProfileGender.male);

      expect(find.text('Not available for this account'), findsOneWidget);
      expect(find.text('3 per day'), findsNothing);
      // Everything else can still be changed and saved.
      await tapVisible(tester, find.text('Pause new matches'));
      expect(saveButton(tester).onPressed, isNotNull);
      await tapVisible(tester, find.text('Save preferences'));
      expect(find.text('Preferences saved'), findsOneWidget);
      expect(
        (await _appRepo(tester).fetchPreferences()).pauseNewMatches,
        isTrue,
      );
    });

    testWidgets('a failed save explains and keeps the change', (tester) async {
      await openPrefs(tester, gender: ProfileGender.female);
      await tapVisible(tester, find.text('1 per day'));
      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.failure);

      await tapVisible(tester, find.text('Save preferences'));

      expect(find.text('Could not save'), findsOneWidget);
      expect(find.text('Preferences saved'), findsNothing);
      expect(saveButton(tester).onPressed, isNotNull); // can try again
    });

    testWidgets('settings links to match preferences', (tester) async {
      final router = await openApp(tester, location: AppRoutes.settings);
      await tapVisible(tester, find.text('Match preferences'));
      expect(currentPath(router), AppRoutes.matchPreferences);
    });
  });

  group('unmatch', () {
    Future<GoRouter> openMorgan(WidgetTester tester) async {
      final router = await openApp(tester, location: AppRoutes.matches);
      await tapVisible(tester, _key('match-card-match-mock-5'));
      expect(find.byType(MatchDetailScreen), findsOneWidget);
      return router;
    }

    testWidgets('asks first, and cancelling changes nothing', (tester) async {
      await openMorgan(tester);

      await tapVisible(tester, find.text('Unmatch'));
      expect(find.text('Unmatch with Morgan?'), findsOneWidget);
      expect(find.textContaining('conversation will close'), findsOneWidget);

      await tapVisible(tester, find.text('Keep match'));

      expect(find.text('Unmatch with Morgan?'), findsNothing);
      expect(find.byType(MatchDetailScreen), findsOneWidget);
      expect(await _matchIds(_appRepo(tester)), contains('match-mock-5'));
    });

    testWidgets('confirming removes the match everywhere', (tester) async {
      final router = await openMorgan(tester);

      await tapVisible(tester, find.text('Unmatch'));
      await tapVisible(tester, _inDialog('Unmatch'));

      expect(find.byType(MatchesScreen), findsOneWidget);
      expect(_key('match-card-match-mock-5'), findsNothing);
      expect(find.textContaining('You unmatched Morgan'), findsOneWidget);
      expect(
        await _matchIds(_appRepo(tester)),
        isNot(contains('match-mock-5')),
      );

      // The conversation is gone from the chat list and closed if reopened.
      router.go(AppRoutes.chat);
      await pumpFrames(tester);
      expect(find.text('Morgan Fake'), findsNothing);

      router.go(AppRoutes.chatConversation('chat-mock-5'));
      await pumpFrames(tester);
      expect(find.text('Conversation closed'), findsOneWidget);
      expect(find.byTooltip('Send message'), findsNothing);

      // And it is recorded in the history.
      router.go(AppRoutes.matchHistory);
      await pumpFrames(tester);
      expect(find.text('Unmatched'), findsWidgets);
    });

    testWidgets('a failure keeps the match and offers another try', (
      tester,
    ) async {
      await openMorgan(tester);
      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.failure);

      await tapVisible(tester, find.text('Unmatch'));
      await tapVisible(tester, _inDialog('Unmatch'));

      expect(find.byType(MatchDetailScreen), findsOneWidget);
      expect(find.text('That did not work'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.populated);
      expect(await _matchIds(_appRepo(tester)), contains('match-mock-5'));
    });
  });

  group('block', () {
    Future<GoRouter> openMorgan(WidgetTester tester) async {
      final router = await openApp(tester, location: AppRoutes.matches);
      await tapVisible(tester, _key('match-card-match-mock-5'));
      return router;
    }

    testWidgets('asks first, and cancelling blocks nobody', (tester) async {
      await openMorgan(tester);

      await tapVisible(tester, find.text('Block'));
      expect(find.text('Block Morgan?'), findsOneWidget);
      expect(find.textContaining('not appear in discovery'), findsOneWidget);

      await tapVisible(tester, find.text('Cancel'));

      expect(find.text('Block Morgan?'), findsNothing);
      expect(find.byType(MatchDetailScreen), findsOneWidget);
      final repo = _appRepo(tester);
      expect(await _matchIds(repo), contains('match-mock-5'));
      expect(
        (await repo.fetchHistory()).where(
          (h) => h.kind == MatchHistoryKind.blocked,
        ),
        isEmpty,
      );
    });

    testWidgets('confirming removes them from matches, chat and history', (
      tester,
    ) async {
      final router = await openMorgan(tester);

      await tapVisible(tester, find.text('Block'));
      await tapVisible(tester, _inDialog('Block'));

      expect(find.byType(MatchesScreen), findsOneWidget);
      expect(_key('match-card-match-mock-5'), findsNothing);
      expect(find.textContaining('Morgan is blocked'), findsOneWidget);

      router.go(AppRoutes.chat);
      await pumpFrames(tester);
      expect(find.text('Morgan Fake'), findsNothing);

      router.go(AppRoutes.matchHistory);
      await pumpFrames(tester);
      expect(find.text('Blocked'), findsWidgets);
    });
  });

  group('chat stays consistent with matches', () {
    testWidgets('a sent message shows in the conversation and the chat list', (
      tester,
    ) async {
      final router = await openApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
      );
      expect(find.text('Morgan Fake'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'See you Friday');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await pumpFrames(tester);
      expect(find.text('See you Friday'), findsOneWidget);

      router.go(AppRoutes.chat);
      await pumpFrames(tester);
      expect(find.text('See you Friday'), findsOneWidget);
    });

    testWidgets('the conversation links to the match details', (tester) async {
      final router = await openApp(
        tester,
        location: AppRoutes.chatConversation('chat-mock-5'),
      );
      await tester.tap(find.byTooltip('Match details'));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.matchDetail('match-mock-5'));
    });

    testWidgets('a brand new match has an open, empty conversation', (
      tester,
    ) async {
      final router = await openApp(tester);
      await tester.tap(find.text('Like back').first);
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Maybe later'));

      router.go(AppRoutes.chatConversation('chat-mock-21'));
      await pumpFrames(tester);
      expect(find.text('Alex Imaginary'), findsOneWidget);
      expect(find.byTooltip('Send message'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every Phase 5 screen fits a small phone at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final router = await pumpApp(
          tester,
          location: AppRoutes.likes,
          session: AuthStatus.loggedIn,
        );
        await pumpFrames(tester);
        expect(tester.takeException(), isNull, reason: 'likes received');

        await tester.tap(find.text('Sent'));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull, reason: 'likes sent');

        containerOf(tester).read(mockSwipeRepositoryProvider).viewerGender =
            ProfileGender.female;
        for (final route in [
          AppRoutes.matches,
          AppRoutes.matchDetail('match-mock-5'),
          AppRoutes.matchPreferences,
          AppRoutes.matchHistory,
          AppRoutes.chatConversation('chat-mock-5'),
        ]) {
          router.go(route);
          await pumpFrames(tester);
          expect(tester.takeException(), isNull, reason: route);
        }

        // Dialogs too.
        router.go(AppRoutes.matchDetail('match-mock-5'));
        await pumpFrames(tester);
        await tapVisible(tester, find.text('Unmatch'));
        expect(tester.takeException(), isNull, reason: 'unmatch dialog');
        await tapVisible(tester, find.text('Keep match'));
        await tapVisible(tester, find.text('Block'));
        expect(tester.takeException(), isNull, reason: 'block dialog');
      });
    }
  });
}
