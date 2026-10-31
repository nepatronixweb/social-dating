import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/theme/app_icons.dart';
import 'package:social_dating/core/widgets/brand_mark.dart';
import 'package:social_dating/core/widgets/circle_action_button.dart';
import 'package:social_dating/core/widgets/profile_card.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/discovery/presentation/widgets/discovery_header.dart';
import 'package:social_dating/features/discovery/providers/discovery_providers.dart';

import 'helpers/pump_app.dart';

final _avery = mockProfiles[0];

Future<GoRouter> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness? platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  if (platform != null) {
    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  final router = await pumpApp(
    tester,
    location: AppRoutes.discover,
    session: AuthStatus.loggedIn,
  );
  await pumpFrames(tester);
  return router;
}

String? _topId(WidgetTester tester) =>
    containerOf(tester).read(discoveryControllerProvider).top?.id;

List<Rect> _actionRects(WidgetTester tester) => [
  for (final tip in [
    'Undo last swipe (not available yet)',
    'Pass on ${_avery.displayName}',
    'Super like ${_avery.displayName} (coming soon)',
    'Like ${_avery.displayName}',
    'Message ${_avery.displayName} (coming soon)',
  ])
    tester.getRect(find.byTooltip(tip)),
];

void main() {
  group('header', () {
    testWidgets('shows the brand, the bell, four tabs and the bolt', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('Social Dating'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('Notifications'),
        ),
        findsOneWidget,
      );
      for (final tab in DiscoveryCategory.values) {
        expect(find.text(tab.label), findsOneWidget);
      }
      expect(find.byTooltip('Discovery preferences'), findsOneWidget);
      expect(find.byIcon(AppIcons.bolt), findsWidgets);
    });

    testWidgets('For You is the selected tab', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester);
      expect(
        tester.getSemantics(find.bySemanticsLabel('For You')),
        matchesSemantics(
          label: 'For You',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
          hasEnabledState: false,
          isFocusable: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the other tabs say they are coming soon and change nothing', (
      tester,
    ) async {
      await _open(tester);
      for (final tab in [
        DiscoveryCategory.doubleDate,
        DiscoveryCategory.astrology,
        DiscoveryCategory.music,
      ]) {
        // The test font is wide, so the row may need to scroll.
        await tester.ensureVisible(find.text(tab.label));
        await tester.pump();
        await tester.tap(find.text(tab.label));
        await pumpFrames(tester);
        expect(find.text('${tab.label} is coming soon'), findsOneWidget);
      }
      expect(_topId(tester), _avery.id, reason: 'still the same deck');
      expect(find.text('${_avery.displayName}, ${_avery.age}'), findsOneWidget);
    });

    testWidgets('the bolt opens the discovery preferences', (tester) async {
      await _open(tester);
      await tester.tap(find.byTooltip('Discovery preferences'));
      await pumpFrames(tester);
      expect(find.text('Discovery preferences'), findsOneWidget);
    });

    testWidgets('shows one dot per photo and follows the photo', (
      tester,
    ) async {
      await _open(tester);
      PhotoDots dots() => tester.widget<PhotoDots>(find.byType(PhotoDots));
      expect(dots().count, _avery.photoCount);
      expect(dots().index, 0);

      final rect = tester.getRect(find.byType(ProfileCard));
      await tester.tapAt(Offset(rect.right - 12, rect.top + 300));
      await pumpFrames(tester);
      expect(dots().index, 1);
    });
  });

  group('info block', () {
    testWidgets('shows Active, the verified mark and the distance band', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('${_avery.displayName}, ${_avery.age}'), findsOneWidget);
      expect(find.byIcon(AppIcons.verified), findsOneWidget);
      expect(find.text('Within 5 km \u00B7 Mockville'), findsOneWidget);
      expect(find.textContaining('3 km'), findsNothing);
    });

    testWidgets('each interest has its own icon', (tester) async {
      await _open(tester);
      for (final interest in _avery.interests) {
        expect(find.text(interest), findsOneWidget);
        expect(find.byIcon(AppIcons.forInterest(interest)), findsOneWidget);
      }
    });

    testWidgets('interest chips sit in a compact row, not full width', (
      tester,
    ) async {
      await _open(tester);
      final card = tester.getRect(find.byType(ProfileCard));
      final coffee = tester.getRect(find.text('Coffee'));
      final hiking = tester.getRect(find.text('Hiking'));
      expect(coffee.width, lessThan(card.width * 0.45));
      expect(hiking.width, lessThan(card.width * 0.45));
      expect((coffee.center.dy - hiking.center.dy).abs(), lessThan(24));
      expect(hiking.left, greaterThan(coffee.right));
    });

    testWidgets('the arrow opens the full profile', (tester) async {
      final router = await _open(tester);
      await tester.tap(find.byTooltip("Open ${_avery.displayName}'s profile"));
      await pumpFrames(tester);
      expect(currentPath(router), AppRoutes.discoverProfile(_avery.id));
    });

    testWidgets('the Active pill only shows for people who are active', (
      tester,
    ) async {
      Profile person({required bool online}) => Profile(
        id: 'x',
        displayName: 'Sam',
        age: 30,
        city: 'Mockville',
        isOnline: online,
        distanceKm: 2,
        interests: const ['Coffee'],
      );
      await pumpWidgetInTheme(
        tester,
        SizedBox(
          height: 700,
          child: ProfileCard(profile: person(online: false), fullBleed: true),
        ),
      );
      expect(find.text('Active'), findsNothing);

      await pumpWidgetInTheme(
        tester,
        SizedBox(
          height: 700,
          child: ProfileCard(profile: person(online: true), fullBleed: true),
        ),
      );
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('optional lines drop out of a short card, not the name', (
      tester,
    ) async {
      await pumpWidgetInTheme(
        tester,
        SizedBox(
          height: 300,
          child: ProfileCard(
            profile: _avery,
            fullBleed: true,
            bottomInset: 120,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('${_avery.displayName}, ${_avery.age}'), findsOneWidget);
      expect(find.text('Coffee'), findsNothing);
    });
  });

  group('action row', () {
    testWidgets('has the five actions in order, with like the largest', (
      tester,
    ) async {
      await _open(tester);
      final rects = _actionRects(tester);
      for (var i = 1; i < rects.length; i++) {
        expect(
          rects[i].left,
          greaterThanOrEqualTo(rects[i - 1].right),
          reason: 'button $i follows button ${i - 1} without overlap',
        );
      }
      final like = rects[3];
      for (final other in [rects[0], rects[1], rects[2], rects[4]]) {
        expect(like.width, greaterThan(other.width));
      }
      // Pass is the second largest; undo, star and send are the small ones.
      expect(rects[1].width, greaterThan(rects[0].width));
      expect(rects[0].width, rects[2].width);
      expect(rects[0].width, rects[4].width);
    });

    testWidgets('every button is a comfortable touch target', (tester) async {
      await _open(tester);
      for (final rect in _actionRects(tester)) {
        expect(rect.shortestSide, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('star and send are not built, and say so', (tester) async {
      await _open(tester);

      CircleActionButton button(IconData icon) =>
          tester.widget<CircleActionButton>(
            find.byWidgetPredicate(
              (w) => w is CircleActionButton && w.icon == icon,
            ),
          );

      button(AppIcons.star).onPressed!();
      await pumpFrames(tester);
      expect(find.text('Super like is coming soon'), findsOneWidget);

      button(AppIcons.send).onPressed!();
      await pumpFrames(tester);
      expect(
        find.text('Messaging before a match is coming soon'),
        findsOneWidget,
      );
      expect(_topId(tester), _avery.id, reason: 'nothing was swiped');
    });

    testWidgets('the heart still likes and the X still passes', (tester) async {
      await _open(tester);
      await tester.tap(find.byTooltip('Like Avery Sample'));
      await pumpFrames(tester);
      expect(_topId(tester), mockProfiles[1].id);

      await tester.tap(
        find.byTooltip('Pass on ${mockProfiles[1].displayName}'),
      );
      await pumpFrames(tester);
      expect(_topId(tester), mockProfiles[2].id);
    });
  });

  group('navigation bar', () {
    testWidgets(
      'uses the brand logo for Discover and outlined icons elsewhere',
      (tester) async {
        await _open(tester);
        final destinations = tester
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .toList();
        Widget childOf(Widget badged) => (badged as Badge).child!;
        IconData iconOf(Widget badged) => (childOf(badged) as Icon).icon!;

        expect(destinations.map((d) => d.label), [
          'Discover',
          'Likes',
          'Matches',
          'Chat',
          'Profile',
        ]);
        expect(childOf(destinations[0].icon), isA<BrandMark>());
        expect((childOf(destinations[0].icon) as BrandMark).size, 24);
        expect(childOf(destinations[0].selectedIcon!), isA<BrandMark>());
        expect((childOf(destinations[0].selectedIcon!) as BrandMark).size, 24);
        expect(iconOf(destinations[1].icon), AppIcons.heartOutline);
        expect(iconOf(destinations[2].icon), AppIcons.matchesOutline);
        expect(iconOf(destinations[3].icon), AppIcons.chatOutline);
        expect(iconOf(destinations[4].icon), AppIcons.profileOutline);
      },
    );

    testWidgets('Discover is dark and the other tabs follow the theme', (
      tester,
    ) async {
      await _open(tester, platform: Brightness.light);
      Brightness navBrightness() =>
          Theme.of(tester.element(find.byType(NavigationBar))).brightness;

      expect(navBrightness(), Brightness.dark);
      expect(
        Theme.of(tester.element(find.byType(ProfileCard))).brightness,
        Brightness.dark,
        reason: 'the screen is dark in a light theme too',
      );

      await tester.tap(find.text('Likes'));
      await pumpFrames(tester);
      expect(navBrightness(), Brightness.light);
    });

    testWidgets('the selected tab is marked by colour and an underline', (
      tester,
    ) async {
      await _open(tester);
      final theme = Theme.of(
        tester.element(find.byType(NavigationBar)),
      ).navigationBarTheme;
      final selected = theme.labelTextStyle!.resolve({WidgetState.selected})!;
      final idle = theme.labelTextStyle!.resolve({})!;
      expect(selected.decoration, TextDecoration.underline);
      expect(idle.decoration, isNot(TextDecoration.underline));
      expect(selected.color, isNot(idle.color));
      expect(theme.indicatorColor, Colors.transparent);
    });
  });

  group('layout', () {
    for (final (name, size, scale) in [
      ('phone', const Size(390, 844), 1.0),
      ('small phone', const Size(320, 568), 1.0),
      ('small phone at 2x text', const Size(320, 568), 2.0),
      ('large text on a phone', const Size(390, 844), 1.5),
    ]) {
      for (final platform in [Brightness.light, Brightness.dark]) {
        testWidgets('fits on a $name in ${platform.name} mode', (tester) async {
          await _open(tester, size: size, textScale: scale, platform: platform);
          expect(tester.takeException(), isNull);
          expect(find.textContaining(_avery.displayName), findsWidgets);

          // The action row stays on screen and in order.
          final rects = _actionRects(tester);
          for (final rect in rects) {
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
          }
          for (var i = 1; i < rects.length; i++) {
            expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
          }

          // The heart still likes at this size.
          await tester.tap(find.byTooltip('Like Avery Sample'));
          await pumpFrames(tester);
          expect(_topId(tester), mockProfiles[1].id);
        });
      }
    }
  });

  group('icons', () {
    test('known interests have their own icon', () {
      expect(AppIcons.forInterest('Coffee'), isNot(AppIcons.interestFallback));
      expect(AppIcons.forInterest('Hiking'), isNot(AppIcons.interestFallback));
      expect(AppIcons.forInterest('Film'), isNot(AppIcons.interestFallback));
      expect(
        AppIcons.forInterest('Coffee'),
        isNot(AppIcons.forInterest('Hiking')),
      );
    });

    test('lookups ignore case and padding, and unknowns fall back', () {
      expect(AppIcons.forInterest('  COFFEE '), AppIcons.forInterest('coffee'));
      expect(
        AppIcons.forInterest('Underwater basket weaving'),
        AppIcons.interestFallback,
      );
    });
  });
}
