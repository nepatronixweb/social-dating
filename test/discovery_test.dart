import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/config/feature_flags.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/theme/app_icons.dart';
import 'package:social_dating/core/widgets/app_bottom_nav.dart';
import 'package:social_dating/core/widgets/circle_action_button.dart';
import 'package:social_dating/core/widgets/image_carousel.dart';
import 'package:social_dating/core/widgets/profile_card.dart';
import 'package:social_dating/core/widgets/skeleton_layouts.dart';
import 'package:social_dating/core/widgets/swipe_card.dart';
import 'package:social_dating/data/models/discovery_filters.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/models/swipe.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/data/repositories/mock_swipe_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/presentation/discovery_screen.dart';
import 'package:social_dating/features/discovery/presentation/profile_detail_screen.dart';
import 'package:social_dating/features/discovery/providers/discovery_providers.dart';
import 'package:social_dating/features/discovery/providers/mock_discovery_providers.dart';
import 'package:social_dating/features/matches/presentation/matches_screen.dart';
import 'package:social_dating/features/onboarding/presentation/signup_name_screen.dart';
import 'package:social_dating/features/wallet/presentation/wallet_screen.dart';

import 'helpers/pump_app.dart';

/// The mock swipe "server" behind the app under test.
late MockSwipeRepository repo;

/// Opens discovery with a zero-latency mock swipe server.
Future<void> openDiscover(
  WidgetTester tester, {
  AuthStatus session = AuthStatus.loggedIn,
  String location = AppRoutes.discover,
  DateTime Function()? clock,
  ProfileGender gender = ProfileGender.male,
  int balance = 100,
  int dailyUsed = 0,
  int previewUsed = 0,
  List<Profile>? catalog,
  Duration latency = Duration.zero,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  usePhoneScreen(tester);
  await pumpApp(
    tester,
    location: location,
    session: session,
    clock: clock,
    swipeRepository:
        ({required now, required isProfileComplete, required scenario}) {
          repo = MockSwipeRepository(
            latency: latency,
            now: now,
            isProfileComplete: isProfileComplete,
            scenario: scenario,
            viewerGender: gender,
            balancePaisa: balance,
            catalog: catalog ?? mockProfiles,
          )..seedCounters(dailyUsed: dailyUsed, previewUsed: previewUsed);
          return repo;
        },
    overrides: overrides,
  );
  if (settle) await pumpFrames(tester);
}

Finder _tooltip(String message) => find.byTooltip(message);
Finder _anyTooltipStarting(String prefix) => find.byWidgetPredicate(
  (w) => w is Tooltip && (w.message ?? '').startsWith(prefix),
);

/// Scrolls [finder] into view (sheets scroll in tall test fonts), then taps.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await pumpFrames(tester);
}

Future<void> like(WidgetTester tester, String name) async {
  await tester.tap(_tooltip('Like $name'));
  await pumpFrames(tester);
}

Future<void> pass(WidgetTester tester, String name) async {
  await tester.tap(_tooltip('Pass on $name'));
  await pumpFrames(tester);
}

/// Name and age line as shown on the card.
Finder card(Profile p) => find.text('${p.displayName}, ${p.age}');

final _avery = mockProfiles[0];
final _jordan = mockProfiles[1];
final _riley = mockProfiles[2];
final _sam = mockProfiles[3];

Finder get _quotaText => find.textContaining('free swipes left today');
Finder get _extraSwipesText =>
    find.textContaining('Extra swipes NPR 0.10 each');

class _FixedScenario extends MockScenarioNotifier {
  _FixedScenario(this.initial);
  final MockScenario initial;

  @override
  MockScenario build() => initial;
}

bool _undoEnabled(WidgetTester tester) =>
    tester
        .widget<CircleActionButton>(
          find.byWidgetPredicate(
            (w) => w is CircleActionButton && w.icon == AppIcons.undo,
          ),
        )
        .onPressed !=
    null;

void main() {
  group('the card', () {
    testWidgets('shows name, age, coarse location and interests', (
      tester,
    ) async {
      await openDiscover(tester);

      expect(card(_avery), findsOneWidget);
      expect(find.textContaining('Mockville'), findsOneWidget);
      // Distance is a band, never the exact 3 km.
      expect(find.textContaining('Within 5 km'), findsOneWidget);
      expect(find.textContaining('3 km'), findsNothing);
      // The bio is on the full profile, not on the card.
      expect(find.text(_avery.bio), findsNothing);
      for (final interest in _avery.interests) {
        expect(find.text(interest), findsOneWidget);
      }
      expect(find.byType(ProfileCard), findsOneWidget);
    });

    testWidgets('a female account is shown men', (tester) async {
      await openDiscover(tester, gender: ProfileGender.female);
      expect(card(_jordan), findsOneWidget);
      expect(card(_avery), findsNothing);
    });

    testWidgets('photo pagination uses the edge tap zones', (tester) async {
      final semantics = tester.ensureSemantics();
      await openDiscover(tester);
      expect(
        find.bySemanticsLabel('Avery Sample photo 1 of 4'),
        findsOneWidget,
      );

      final rect = tester.getRect(find.byType(ProfileCard));
      // Right edge, in the upper middle: clear of the header and the info.
      await tester.tapAt(Offset(rect.right - 12, rect.top + 300));
      await pumpFrames(tester);
      expect(
        find.bySemanticsLabel('Avery Sample photo 2 of 4'),
        findsOneWidget,
      );

      // Left edge goes back.
      await tester.tapAt(Offset(rect.left + 12, rect.top + 300));
      await pumpFrames(tester);
      expect(
        find.bySemanticsLabel('Avery Sample photo 1 of 4'),
        findsOneWidget,
      );

      // Photo taps never swipe the card.
      expect(repo.swipeLog, isEmpty);
      semantics.dispose();
    });

    testWidgets('the pass and like buttons have accessible names', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openDiscover(tester);
      expect(find.bySemanticsLabel('Pass on Avery Sample'), findsOneWidget);
      expect(find.bySemanticsLabel('Like Avery Sample'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('swipe directions', () {
    testWidgets('the like button swipes right and shows the next card', (
      tester,
    ) async {
      await openDiscover(tester);
      await like(tester, _avery.displayName);

      expect(repo.swipeLog.single.profileId, _avery.id);
      expect(repo.swipeLog.single.direction, SwipeDirection.right);
      expect(card(_riley), findsOneWidget);
      expect(card(_avery), findsNothing);
    });

    testWidgets('the pass button swipes left and shows the next card', (
      tester,
    ) async {
      await openDiscover(tester);
      await pass(tester, _avery.displayName);

      expect(repo.swipeLog.single.direction, SwipeDirection.left);
      expect(card(_riley), findsOneWidget);
    });

    testWidgets('dragging right likes, dragging left passes', (tester) async {
      await openDiscover(tester);

      await tester.drag(find.byType(SwipeCard), const Offset(260, 0));
      await pumpFrames(tester);
      expect(repo.swipeLog.last.profileId, _avery.id);
      expect(repo.swipeLog.last.direction, SwipeDirection.right);
      expect(card(_riley), findsOneWidget);

      await tester.drag(find.byType(SwipeCard), const Offset(-260, 0));
      await pumpFrames(tester);
      expect(repo.swipeLog.last.profileId, _riley.id);
      expect(repo.swipeLog.last.direction, SwipeDirection.left);
      expect(card(_sam), findsOneWidget);
    });

    testWidgets('a fast fling counts even if it is short', (tester) async {
      await openDiscover(tester);
      await tester.fling(find.byType(SwipeCard), const Offset(90, 0), 2500);
      await pumpFrames(tester);
      expect(repo.swipeLog.single.direction, SwipeDirection.right);
    });

    testWidgets('a short drag springs back and counts nothing', (tester) async {
      await openDiscover(tester);
      await tester.drag(find.byType(SwipeCard), const Offset(60, 0));
      await pumpFrames(tester);

      expect(card(_avery), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
      expect(
        find.textContaining('20 of 20 free swipes left today'),
        findsOneWidget,
      );
      // The card is back in place.
      final swipeCard = tester.state<SwipeCardState>(find.byType(SwipeCard));
      expect(swipeCard.offset, 0);
    });

    testWidgets('vertical drags never swipe', (tester) async {
      await openDiscover(tester);
      await tester.drag(find.byType(SwipeCard), const Offset(0, -300));
      await tester.drag(find.byType(SwipeCard), const Offset(0, 300));
      await pumpFrames(tester);
      expect(card(_avery), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
    });

    testWidgets('LIKE and NOPE stamps follow the drag direction', (
      tester,
    ) async {
      await openDiscover(tester);
      expect(find.text('LIKE'), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwipeCard)),
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(find.text('LIKE'), findsOneWidget);
      expect(find.text('NOPE'), findsNothing);

      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();
      expect(find.text('NOPE'), findsOneWidget);
      expect(find.text('LIKE'), findsNothing);

      // Back to the middle and release: nothing is swiped.
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await pumpFrames(tester);
      expect(repo.swipeLog, isEmpty);
      expect(find.text('NOPE'), findsNothing);
      expect(find.text('LIKE'), findsNothing);
    });

    testWidgets('the card tilts and fades while it is dragged', (tester) async {
      await openDiscover(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SwipeCard)),
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      final rotation = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(SwipeCard),
              matching: find.byType(Transform),
            )
            .at(1),
      );
      expect(rotation.transform.getRotation().entry(0, 1), isNot(0));
      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(SwipeCard),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, lessThan(1));

      await gesture.up();
      await pumpFrames(tester);
    });
  });

  group('counters', () {
    testWidgets('left and right swipes both use the free allowance', (
      tester,
    ) async {
      await openDiscover(tester);
      expect(find.text('20 of 20 free swipes left today'), findsOneWidget);

      await like(tester, _avery.displayName);
      expect(find.text('19 of 20 free swipes left today'), findsOneWidget);

      await pass(tester, _riley.displayName);
      expect(find.text('18 of 20 free swipes left today'), findsOneWidget);
    });

    testWidgets('the counter shows remaining free swipes', (tester) async {
      await openDiscover(tester);
      expect(find.text('20 of 20 free swipes left today'), findsOneWidget);
    });

    testWidgets('accounts without a limit see no counter and are not charged', (
      tester,
    ) async {
      await openDiscover(tester, gender: ProfileGender.female, dailyUsed: 100);
      expect(_quotaText, findsNothing);
      await like(tester, _jordan.displayName);
      expect(find.text('Pay for this swipe?'), findsNothing);
      expect(repo.swipeLog.single.kind, SwipeKind.free);
      expect(repo.balancePaisa, 100);
    });
  });

  group('daily limit boundary', () {
    testWidgets('swipe 20 is free, swipe 21 asks for payment', (tester) async {
      await openDiscover(tester, dailyUsed: 19);
      expect(find.text('1 of 20 free swipes left today'), findsOneWidget);

      await like(tester, _avery.displayName);
      expect(find.text('Pay for this swipe?'), findsNothing);
      expect(repo.swipeLog.single.kind, SwipeKind.free);
      expect(_extraSwipesText, findsOneWidget);

      await like(tester, _riley.displayName);
      expect(find.text('Pay for this swipe?'), findsOneWidget);
      // Not swiped until the person confirms.
      expect(repo.swipeLog, hasLength(1));
    });

    testWidgets('the free count resets at Nepal midnight', (tester) async {
      // 23:59:59 Nepal time, 14 October.
      var now = DateTime.utc(2026, 10, 14, 18, 14, 59);
      await openDiscover(tester, dailyUsed: 20, clock: () => now);
      expect(_extraSwipesText, findsOneWidget);

      // One second later it is the next Nepal day.
      now = DateTime.utc(2026, 10, 14, 18, 15);
      await like(tester, _avery.displayName);

      expect(find.text('Pay for this swipe?'), findsNothing);
      expect(repo.swipeLog.single.kind, SwipeKind.free);
      expect(find.text('19 of 20 free swipes left today'), findsOneWidget);
    });

    testWidgets('still charged one second before Nepal midnight', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 14, 18, 14, 59);
      await openDiscover(tester, dailyUsed: 20, clock: () => now);
      await like(tester, _avery.displayName);
      expect(find.text('Pay for this swipe?'), findsOneWidget);
    });
  });

  group('profile completion gate', () {
    testWidgets('five preview swipes work, then the gate appears', (
      tester,
    ) async {
      await openDiscover(tester, session: AuthStatus.incompleteProfile);
      expect(find.text('5 of 5 preview swipes left'), findsOneWidget);
      // Only discovery is open: no tab bar yet.
      expect(find.byType(AppBottomNav), findsNothing);
      expect(find.text('Finish profile'), findsOneWidget);

      for (var swiped = 1; swiped <= 5; swiped++) {
        expect(find.text('Finish your profile to keep swiping'), findsNothing);
        await tester.tap(_anyTooltipStarting('Pass on'));
        await pumpFrames(tester);
        expect(repo.swipeLog, hasLength(swiped));
      }

      expect(find.text('Finish your profile to keep swiping'), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);
      expect(_anyTooltipStarting('Like '), findsNothing);
      // The sixth swipe never reaches the server.
      expect(repo.swipeLog, hasLength(5));
    });

    testWidgets('the counter counts down during the preview', (tester) async {
      await openDiscover(tester, session: AuthStatus.incompleteProfile);
      await pass(tester, _avery.displayName);
      expect(find.text('4 of 5 preview swipes left'), findsOneWidget);
      await like(tester, _riley.displayName);
      expect(find.text('3 of 5 preview swipes left'), findsOneWidget);
    });

    testWidgets('the gate leads to profile completion', (tester) async {
      await openDiscover(
        tester,
        session: AuthStatus.incompleteProfile,
        previewUsed: 5,
      );
      expect(find.text('Finish your profile to keep swiping'), findsOneWidget);
      await tapVisible(tester, find.text('Complete profile'));
      await pumpFrames(tester);
      expect(find.byType(SignupNameScreen), findsOneWidget);
    });

    testWidgets('preview swipes do not use up the daily allowance', (
      tester,
    ) async {
      await openDiscover(
        tester,
        session: AuthStatus.incompleteProfile,
        previewUsed: 5,
      );
      expect(find.text('Finish your profile to keep swiping'), findsOneWidget);

      // Finish the profile: the person is let into the app.
      containerOf(
        tester,
      ).read(sessionProvider.notifier).debugSimulate(AuthStatus.loggedIn);
      await pumpFrames(tester);

      expect(find.byType(DiscoveryScreen), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
      expect(find.text('20 of 20 free swipes left today'), findsOneWidget);
      expect(find.text('Finish your profile to keep swiping'), findsNothing);
    });

    testWidgets('the name step does not offer an explore shortcut', (
      tester,
    ) async {
      await openDiscover(
        tester,
        session: AuthStatus.incompleteProfile,
        location: AppRoutes.profileCompletion,
        previewUsed: 2,
      );
      expect(find.byType(SignupNameScreen), findsOneWidget);
      expect(find.textContaining('Explore first'), findsNothing);
    });

    testWidgets('no explore option once the preview is used up', (
      tester,
    ) async {
      await openDiscover(
        tester,
        session: AuthStatus.incompleteProfile,
        location: AppRoutes.profileCompletion,
        previewUsed: 5,
      );
      expect(find.byType(SignupNameScreen), findsOneWidget);
      expect(find.textContaining('Explore first'), findsNothing);
    });
  });

  group('paid swipes', () {
    testWidgets('the dialog shows the cost and the balance', (tester) async {
      await openDiscover(tester, dailyUsed: 20, balance: 40);
      await like(tester, _avery.displayName);

      expect(find.text('Pay for this swipe?'), findsOneWidget);
      expect(find.text('NPR 0.10'), findsOneWidget);
      expect(find.text('NPR 0.40'), findsOneWidget, reason: 'balance');
      expect(find.text('NPR 0.30'), findsOneWidget, reason: 'after');
      expect(find.text('Pay NPR 0.10 and swipe'), findsOneWidget);
    });

    testWidgets('confirming charges 10 paisa and swipes', (tester) async {
      await openDiscover(tester, dailyUsed: 20);
      await like(tester, _avery.displayName);
      await tapVisible(tester, find.text('Pay NPR 0.10 and swipe'));
      await pumpFrames(tester);

      expect(repo.swipeLog.single.kind, SwipeKind.paid);
      expect(repo.swipeLog.single.direction, SwipeDirection.right);
      expect(repo.balancePaisa, 90);
      expect(card(_riley), findsOneWidget);
    });

    testWidgets('passes cost the same as likes', (tester) async {
      await openDiscover(tester, dailyUsed: 20);
      await pass(tester, _avery.displayName);
      await tapVisible(tester, find.text('Pay NPR 0.10 and swipe'));
      await pumpFrames(tester);
      expect(repo.swipeLog.single.direction, SwipeDirection.left);
      expect(repo.balancePaisa, 90);
    });

    testWidgets('cancelling charges nothing and keeps the card', (
      tester,
    ) async {
      await openDiscover(tester, dailyUsed: 20);
      await like(tester, _avery.displayName);
      await tapVisible(tester, find.text('Cancel'));
      await pumpFrames(tester);

      expect(find.text('Pay for this swipe?'), findsNothing);
      expect(card(_avery), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
      expect(repo.balancePaisa, 100);
      // The card is back in the middle.
      expect(tester.state<SwipeCardState>(find.byType(SwipeCard)).offset, 0);
    });

    testWidgets('dragging a card asks too, and cancelling springs it back', (
      tester,
    ) async {
      await openDiscover(tester, dailyUsed: 20);
      await tester.drag(find.byType(SwipeCard), const Offset(-260, 0));
      await pumpFrames(tester);
      expect(find.text('Pay for this swipe?'), findsOneWidget);

      await tapVisible(tester, find.text('Cancel'));
      await pumpFrames(tester);
      expect(card(_avery), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
      expect(tester.state<SwipeCardState>(find.byType(SwipeCard)).offset, 0);
    });

    testWidgets('each paid swipe asks again', (tester) async {
      await openDiscover(tester, dailyUsed: 20);
      await like(tester, _avery.displayName);
      await tapVisible(tester, find.text('Pay NPR 0.10 and swipe'));
      await pumpFrames(tester);

      await like(tester, _riley.displayName);
      expect(find.text('Pay for this swipe?'), findsOneWidget);
      expect(find.text('NPR 0.90'), findsOneWidget, reason: 'new balance');
    });
  });

  group('insufficient balance', () {
    testWidgets('shows the state and does not swipe', (tester) async {
      await openDiscover(tester, dailyUsed: 20, balance: 5);
      await like(tester, _avery.displayName);

      expect(find.text('Not enough balance'), findsOneWidget);
      expect(find.text('Swipe not sent'), findsOneWidget);
      expect(find.textContaining('NPR 0.05'), findsOneWidget);
      expect(find.text('Pay for this swipe?'), findsNothing);
      expect(repo.swipeLog, isEmpty);
      expect(repo.balancePaisa, 5);
    });

    testWidgets('exactly 10 paisa is enough, 9 is not', (tester) async {
      await openDiscover(tester, dailyUsed: 20, balance: 10);
      await like(tester, _avery.displayName);
      expect(find.text('Pay for this swipe?'), findsOneWidget);
      expect(find.text('Not enough balance'), findsNothing);
    });

    testWidgets('dismissing keeps the card', (tester) async {
      await openDiscover(tester, dailyUsed: 20, balance: 0);
      await like(tester, _avery.displayName);
      await tapVisible(tester, find.text('Not now'));
      await pumpFrames(tester);

      expect(find.text('Not enough balance'), findsNothing);
      expect(card(_avery), findsOneWidget);
      expect(tester.state<SwipeCardState>(find.byType(SwipeCard)).offset, 0);
    });

    testWidgets('can open the wallet', (tester) async {
      await openDiscover(tester, dailyUsed: 20, balance: 0);
      await like(tester, _avery.displayName);
      await tapVisible(tester, find.text('Open wallet'));
      await pumpFrames(tester);
      expect(find.byType(WalletScreen), findsOneWidget);
    });

    testWidgets('shows the remaining wallet balance', (tester) async {
      await openDiscover(tester, dailyUsed: 20, balance: 0);
      await like(tester, _avery.displayName);
      expect(find.text('Not enough balance'), findsOneWidget);
    });
  });

  group('swipe limit sheet', () {
    testWidgets('explains the rules', (tester) async {
      await openDiscover(tester, dailyUsed: 6);
      await tester.tap(_quotaText);
      await pumpFrames(tester);

      expect(find.text('Swipe limits'), findsOneWidget);
      expect(find.text('14 of 20'), findsOneWidget);
      expect(find.text('NPR 1.00'), findsOneWidget, reason: 'wallet balance');
      expect(
        find.textContaining('Left and right swipes share one count'),
        findsOneWidget,
      );
      expect(find.textContaining('NPR 0.10'), findsOneWidget);
      expect(find.textContaining('Nepal time (UTC+5:45)'), findsOneWidget);
      expect(find.text('Resets in'), findsOneWidget);

      await tapVisible(tester, find.text('Got it'));
      await pumpFrames(tester);
      expect(find.text('Swipe limits'), findsNothing);
    });

    testWidgets('during the preview it explains the five swipes', (
      tester,
    ) async {
      await openDiscover(tester, session: AuthStatus.incompleteProfile);
      await tester.tap(find.textContaining('preview swipes left'));
      await pumpFrames(tester);
      expect(find.text('Swipe limits'), findsOneWidget);
      expect(
        find.textContaining('5 profiles while you explore'),
        findsOneWidget,
      );
    });
  });

  group('matches', () {
    testWidgets('a mutual like shows the celebration', (tester) async {
      await openDiscover(tester);
      await pass(tester, _avery.displayName);
      expect(find.text('It\'s a match!'), findsNothing);

      await like(tester, _riley.displayName); // mock-3 is a mock match
      expect(find.text('It\'s a match!'), findsOneWidget);
      expect(find.text('You and Riley liked each other.'), findsOneWidget);
    });

    testWidgets('passing on a would-be match shows nothing', (tester) async {
      await openDiscover(tester);
      await pass(tester, _avery.displayName);
      await pass(tester, _riley.displayName);
      expect(find.text('It\'s a match!'), findsNothing);
    });

    testWidgets('a dragged right swipe can match too', (tester) async {
      await openDiscover(tester);
      await pass(tester, _avery.displayName);
      await tester.drag(find.byType(SwipeCard), const Offset(260, 0));
      await pumpFrames(tester);
      expect(find.text('It\'s a match!'), findsOneWidget);
    });

    testWidgets('keep swiping closes it and shows the next card', (
      tester,
    ) async {
      await openDiscover(tester);
      await pass(tester, _avery.displayName);
      await like(tester, _riley.displayName);
      await tapVisible(tester, find.text('Keep swiping'));
      await pumpFrames(tester);

      expect(find.text('It\'s a match!'), findsNothing);
      expect(card(_sam), findsOneWidget);
      expect(
        containerOf(tester).read(discoveryControllerProvider).newMatch,
        isNull,
      );
    });

    testWidgets('see your matches opens the matches tab', (tester) async {
      await openDiscover(tester);
      await pass(tester, _avery.displayName);
      await like(tester, _riley.displayName);
      await tapVisible(tester, find.text('See your matches'));
      await pumpFrames(tester);
      expect(find.byType(MatchesScreen), findsOneWidget);
    });

    testWidgets('during onboarding it does not link to the matches tab', (
      tester,
    ) async {
      await openDiscover(tester, session: AuthStatus.incompleteProfile);
      await pass(tester, _avery.displayName);
      await like(tester, _riley.displayName);

      expect(find.text('It\'s a match!'), findsOneWidget);
      expect(find.text('See your matches'), findsNothing);
      expect(
        find.text('Finish your profile to start chatting.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Keep swiping'));
      await pumpFrames(tester);
      expect(find.text('It\'s a match!'), findsNothing);
    });
  });

  group('profile detail', () {
    testWidgets('opens from the card with the complete profile', (
      tester,
    ) async {
      await openDiscover(tester);
      await tester.tap(card(_avery));
      await pumpFrames(tester);

      expect(find.byType(ProfileDetailScreen), findsOneWidget);
      // The detail has its own header; the swipe card is not on screen.
      expect(card(_avery), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);
      expect(find.text(_avery.bio), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Interests'), findsOneWidget);
      expect(find.text('Product designer'), findsOneWidget);
      expect(find.text(_avery.lookingFor!), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.textContaining('Within 5 km'), findsOneWidget);
      expect(find.byType(ImageCarousel), findsOneWidget);
    });

    testWidgets('scrolling the details never swipes the profile', (
      tester,
    ) async {
      await openDiscover(tester);
      await tester.tap(card(_avery));
      await pumpFrames(tester);

      final scroll = find.byKey(const ValueKey('profile-detail-scroll'));
      await tester.drag(scroll, const Offset(0, -400));
      await pumpFrames(tester);
      await tester.drag(scroll, const Offset(0, 400));
      await pumpFrames(tester);
      // A sideways drag on the details is not a swipe either.
      await tester.drag(scroll, const Offset(-300, 0));
      await pumpFrames(tester);

      expect(find.byType(ProfileDetailScreen), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
    });

    testWidgets('liking from the detail swipes the card', (tester) async {
      await openDiscover(tester);
      await tester.tap(card(_avery));
      await pumpFrames(tester);
      await tester.tap(_tooltip('Like Avery Sample'));
      await pumpFrames(tester);

      expect(find.byType(ProfileDetailScreen), findsNothing);
      expect(repo.swipeLog.single.profileId, _avery.id);
      expect(repo.swipeLog.single.direction, SwipeDirection.right);
      expect(card(_riley), findsOneWidget);
    });

    testWidgets('passing from the detail swipes left', (tester) async {
      await openDiscover(tester);
      await tester.tap(card(_avery));
      await pumpFrames(tester);
      await tester.tap(_tooltip('Pass on Avery Sample'));
      await pumpFrames(tester);
      expect(repo.swipeLog.single.direction, SwipeDirection.left);
    });

    testWidgets('going back keeps the card and counts nothing', (tester) async {
      await openDiscover(tester);
      await tester.tap(card(_avery));
      await pumpFrames(tester);
      await tester.tap(_tooltip('Back'));
      await pumpFrames(tester);

      expect(card(_avery), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
    });

    testWidgets('a liked-from-detail swipe still respects the paid flow', (
      tester,
    ) async {
      await openDiscover(tester, dailyUsed: 20);
      await tester.tap(card(_avery));
      await pumpFrames(tester);
      await tester.tap(_tooltip('Like Avery Sample'));
      await pumpFrames(tester);

      expect(find.text('Pay for this swipe?'), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
    });
  });

  group('filters', () {
    testWidgets('verified only narrows the deck and shows a count', (
      tester,
    ) async {
      await openDiscover(tester);
      await tester.tap(_tooltip('Discovery preferences'));
      await pumpFrames(tester);
      expect(find.text('Discovery preferences'), findsOneWidget);

      await tapVisible(tester, find.text('Verified profiles only'));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Show results'));
      await pumpFrames(tester);

      final deck = containerOf(tester).read(discoveryControllerProvider).deck;
      expect(deck, isNotEmpty);
      expect(deck.every((p) => p.isVerified), isTrue);
      expect(_tooltip('Discovery preferences, 1 active'), findsOneWidget);
    });

    testWidgets('age and distance preferences filter the deck', (tester) async {
      await openDiscover(tester);
      containerOf(tester)
          .read(discoveryFiltersProvider.notifier)
          .apply(
            const DiscoveryFilters(minAge: 30, maxAge: 35, maxDistanceKm: 10),
          );
      await pumpFrames(tester);

      final deck = containerOf(tester).read(discoveryControllerProvider).deck;
      expect(deck.map((p) => p.displayName), ['Sam Placeholder']);
      expect(card(_sam), findsOneWidget);
    });

    testWidgets('no matching profiles shows the no-results state', (
      tester,
    ) async {
      await openDiscover(tester);
      await tester.tap(_tooltip('Discovery preferences'));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Verified profiles only'));
      final gaming = find.text('Gaming');
      await tester.ensureVisible(gaming);
      await tester.tap(gaming);
      await pumpFrames(tester);
      final apply = find.text('Show results');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await pumpFrames(tester);

      expect(find.text('No results'), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);
      expect(find.text('Adjust preferences'), findsOneWidget);
      expect(find.text('Reset preferences'), findsOneWidget);

      await tapVisible(tester, find.text('Reset preferences'));
      await pumpFrames(tester);
      expect(find.text('No results'), findsNothing);
      expect(card(_avery), findsOneWidget);
    });

    testWidgets('reset to defaults inside the sheet', (tester) async {
      await openDiscover(tester);
      containerOf(tester)
          .read(discoveryFiltersProvider.notifier)
          .apply(const DiscoveryFilters(verifiedOnly: true));
      await pumpFrames(tester);

      await tester.tap(_tooltip('Discovery preferences, 1 active'));
      await pumpFrames(tester);
      final reset = find.text('Reset to defaults');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await pumpFrames(tester);
      final apply = find.text('Show results');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await pumpFrames(tester);

      expect(
        containerOf(tester).read(discoveryFiltersProvider).isDefault,
        isTrue,
      );
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      await openDiscover(tester);
      await tester.tap(_tooltip('Discovery preferences'));
      await pumpFrames(tester);
      await tapVisible(tester, find.text('Verified profiles only'));
      await pumpFrames(tester);
      await tester.tapAt(const Offset(195, 20)); // barrier
      await pumpFrames(tester);

      expect(
        containerOf(tester).read(discoveryFiltersProvider).isDefault,
        isTrue,
      );
    });
  });

  group('loading, empty, error and finished states', () {
    testWidgets('shows a skeleton while loading', (tester) async {
      await openDiscover(
        tester,
        latency: const Duration(milliseconds: 300),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await pumpFrames(tester);
      expect(find.byType(SkeletonCard), findsNothing);
      expect(card(_avery), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await openDiscover(
        tester,
        overrides: [
          mockScenarioProvider.overrideWith(
            () => _FixedScenario(MockScenario.failure),
          ),
        ],
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);

      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.populated);
      await tapVisible(tester, find.text('Try again'));
      await pumpFrames(tester);

      expect(find.text('Try again'), findsNothing);
      expect(card(_avery), findsOneWidget);
    });

    testWidgets('an empty feed explains and can refresh', (tester) async {
      await openDiscover(
        tester,
        overrides: [
          mockScenarioProvider.overrideWith(
            () => _FixedScenario(MockScenario.empty),
          ),
        ],
      );
      expect(find.text('No one new right now'), findsOneWidget);

      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.populated);
      await tapVisible(tester, find.text('Refresh'));
      await pumpFrames(tester);
      expect(card(_avery), findsOneWidget);
    });

    testWidgets('swiping everyone shows the no-more-profiles state', (
      tester,
    ) async {
      await openDiscover(tester, catalog: [_avery, _riley]);
      await pass(tester, _avery.displayName);
      await pass(tester, _riley.displayName);

      expect(find.text('You\'re all caught up'), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Adjust preferences'), findsOneWidget);
    });

    testWidgets('a swipe that cannot be saved brings the card back', (
      tester,
    ) async {
      await openDiscover(tester);
      containerOf(
        tester,
      ).read(mockScenarioProvider.notifier).select(MockScenario.failure);
      await like(tester, _avery.displayName);

      expect(card(_avery), findsOneWidget);
      expect(
        find.textContaining('Could not record that swipe'),
        findsOneWidget,
      );
      expect(find.text('20 of 20 free swipes left today'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'discovery and its dialogs fit a small phone at ${scale}x text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpApp(
            tester,
            location: AppRoutes.discover,
            session: AuthStatus.loggedIn,
            swipeRepository:
                ({
                  required now,
                  required isProfileComplete,
                  required scenario,
                }) {
                  repo = MockSwipeRepository(
                    latency: Duration.zero,
                    now: now,
                    isProfileComplete: isProfileComplete,
                    scenario: scenario,
                  )..seedCounters(dailyUsed: 20);
                  return repo;
                },
          );
          await pumpFrames(tester);
          expect(tester.takeException(), isNull);

          // Paid dialog.
          await tester.tap(_tooltip('Like Avery Sample'));
          await pumpFrames(tester);
          expect(find.text('Pay for this swipe?'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tapVisible(tester, find.text('Cancel'));

          // Limit sheet.
          await tester.tap(find.textContaining('Extra swipes'));
          await pumpFrames(tester);
          expect(find.text('Swipe limits'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the swipe card does not overflow in the dark theme', (
      tester,
    ) async {
      await openDiscover(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
      expect(card(_avery), findsOneWidget);
    });
  });

  group('shared widgets', () {
    testWidgets('photos only page by taps when sideways paging is off', (
      tester,
    ) async {
      var page = 0;
      await pumpWidgetInTheme(
        tester,
        SizedBox(
          height: 400,
          child: ImageCarousel(
            photoCount: 3,
            allowPageSwipe: false,
            onPageChanged: (p) => page = p,
          ),
        ),
      );
      await tester.drag(find.byType(ImageCarousel), const Offset(-300, 0));
      await pumpFrames(tester);
      expect(page, 0, reason: 'a drag does not page');

      final rect = tester.getRect(find.byType(ImageCarousel));
      await tester.tapAt(Offset(rect.right - 10, rect.center.dy));
      await pumpFrames(tester);
      expect(page, 1, reason: 'the edge tap zone pages');
    });
  });

  group('undo', () {
    testWidgets('is disabled by default, with a clear label', (tester) async {
      await openDiscover(tester);
      expect(_undoEnabled(tester), isFalse);
      expect(_tooltip('Undo last swipe (not available yet)'), findsOneWidget);

      await like(tester, _avery.displayName);
      expect(_undoEnabled(tester), isFalse);
    });

    testWidgets('works as a labelled mock when the local flag is on', (
      tester,
    ) async {
      await openDiscover(
        tester,
        overrides: [
          featureFlagsProvider.overrideWithValue(
            const FeatureFlags(undoSwipe: true),
          ),
        ],
      );
      expect(_tooltip('Undo last swipe'), findsOneWidget);
      expect(_undoEnabled(tester), isFalse, reason: 'nothing to undo yet');

      await like(tester, _avery.displayName);
      expect(_undoEnabled(tester), isTrue);
      expect(find.text('19 of 20 free swipes left today'), findsOneWidget);

      await tester.tap(_tooltip('Undo last swipe'));
      await pumpFrames(tester);

      expect(card(_avery), findsOneWidget);
      expect(repo.swipeLog, isEmpty);
      expect(find.text('20 of 20 free swipes left today'), findsOneWidget);
      expect(_undoEnabled(tester), isFalse, reason: 'only the last swipe');
    });
  });
}
