import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/routing/route_guards.dart';
import 'package:social_dating/core/theme/app_icons.dart';
import 'package:social_dating/core/widgets/app_page.dart';
import 'package:social_dating/core/widgets/chat_bubble.dart';
import 'package:social_dating/core/widgets/chat_preview_tile.dart';
import 'package:social_dating/data/repositories/mock_profile_repository.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/chat/presentation/chat_conversation_screen.dart';
import 'package:social_dating/features/chat/presentation/chat_list_screen.dart';
import 'package:social_dating/features/discovery/presentation/discovery_screen.dart';
import 'package:social_dating/features/likes/presentation/likes_screen.dart';
import 'package:social_dating/features/matches/presentation/matches_screen.dart';
import 'package:social_dating/features/notifications/presentation/notification_bell.dart';
import 'package:social_dating/features/notifications/presentation/notifications_screen.dart';
import 'package:social_dating/features/profile/presentation/personal_information_screen.dart';
import 'package:social_dating/features/profile/presentation/profile_photos_screen.dart';
import 'package:social_dating/features/profile/presentation/profile_screen.dart';
import 'package:social_dating/features/safety/presentation/safety_screen.dart';
import 'package:social_dating/features/settings/presentation/account_screen.dart';
import 'package:social_dating/features/settings/presentation/settings_screen.dart';
import 'package:social_dating/features/subscription/presentation/subscription_screen.dart';

import 'helpers/pump_app.dart';

Finder _navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back'));
  await pumpFrames(tester);
}

void main() {
  group('bottom navigation', () {
    testWidgets('shows the five tabs and starts on Discover', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      for (final label in ['Discover', 'Likes', 'Matches', 'Chat', 'Profile']) {
        expect(_navLabel(label), findsOneWidget, reason: label);
      }
      expect(_selectedTab(tester), 0);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
    });

    testWidgets('each tab opens its screen', (tester) async {
      final router = await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      final tabs = <(String, Type, String)>[
        ('Likes', LikesScreen, AppRoutes.likes),
        ('Matches', MatchesScreen, AppRoutes.matches),
        ('Chat', ChatListScreen, AppRoutes.chat),
        ('Profile', ProfileScreen, AppRoutes.profile),
        ('Discover', DiscoveryScreen, AppRoutes.discover),
      ];
      for (final (i, (label, type, path)) in tabs.indexed) {
        await tester.tap(_navLabel(label));
        await pumpFrames(tester);
        expect(find.byType(type), findsOneWidget, reason: label);
        expect(currentPath(router), path, reason: label);
        expect(_selectedTab(tester), i == 4 ? 0 : i + 1, reason: label);
      }
    });

    testWidgets('chat tab shows an unread badge', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      final badges = tester.widgetList<Badge>(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(Badge),
        ),
      );
      // Five destinations; only Chat has unread messages in the sample data.
      expect(badges, hasLength(5));
      expect(badges.where((b) => b.isLabelVisible), hasLength(1));
    });
  });

  group('discovery', () {
    testWidgets('liking a profile moves to the next one', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.textContaining(mockProfiles[0].displayName), findsWidgets);
      await tester.tap(find.byTooltip('Like ${mockProfiles[0].displayName}'));
      await pumpFrames(tester);

      expect(find.textContaining(mockProfiles[2].displayName), findsWidgets);
    });

    testWidgets('the notification bell opens notifications', (tester) async {
      final router = await pumpApp(
        tester,
        location: AppRoutes.discover,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.byType(NotificationBell));
      await pumpFrames(tester);

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(currentPath(router), AppRoutes.notifications);

      await _back(tester);
      expect(find.byType(DiscoveryScreen), findsOneWidget);
    });
  });

  group('chat', () {
    testWidgets('opens a conversation above the tab bar and sends locally', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.chat,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.byType(ChatPreviewTile).first);
      await pumpFrames(tester);

      expect(find.byType(ChatConversationScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      final before = find.byType(ChatBubble).evaluate().length;
      await tester.enterText(find.byType(TextField), 'See you Friday');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await pumpFrames(tester);

      expect(find.text('See you Friday'), findsOneWidget);
      expect(find.byType(ChatBubble).evaluate().length, before + 1);
      // The composer clears after sending.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );

      await _back(tester);
      expect(find.byType(ChatListScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('send is disabled until there is text', (tester) async {
      await pumpApp(
        tester,
        location: '/chat/anything',
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      final send = find.widgetWithIcon(IconButton, AppIcons.send);
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    });
  });

  group('profile hub', () {
    testWidgets('links lead to their screens and back', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.profile,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      final links = <(String, Type)>[
        ('Your details', PersonalInformationScreen),
        ('Premium', SubscriptionScreen),
        ('Notifications', NotificationsScreen),
        ('Settings', SettingsScreen),
        ('Account', AccountScreen),
      ];
      for (final (title, type) in links) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await pumpFrames(tester);
        expect(find.byType(type), findsOneWidget, reason: title);

        await _back(tester);
        expect(find.byType(ProfileScreen), findsOneWidget, reason: title);
      }
    });

    testWidgets('settings links to safety and account', (tester) async {
      await pumpApp(
        tester,
        location: AppRoutes.settings,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Safety center'));
      await pumpFrames(tester);
      expect(find.byType(SafetyScreen), findsOneWidget);
    });
  });

  group('secondary screens', () {
    testWidgets('subscription: reviewing purchase opens the NPR 100 detail', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: AppRoutes.subscription,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Review purchase'));
      await pumpFrames(tester);
      expect(find.text('Review standard purchase'), findsOneWidget);
    });

    testWidgets('referrals: copy puts the code on the clipboard', (
      tester,
    ) async {
      usePhoneScreen(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpApp(
        tester,
        location: AppRoutes.referrals,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Copy link'));
      await pumpFrames(tester);
      expect(find.text('Invite link copied.'), findsOneWidget);
      expect(copied, 'mock://socialdating.invite/MOCK-0000');
    });

    testWidgets('safety: report needs a reason before it can be sent', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.safety,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tester.ensureVisible(find.text('Report a person'));
      await tester.tap(find.text('Report a person'));
      await pumpFrames(tester);

      await tester.tap(find.text('Submit report'));
      await pumpFrames(tester);
      expect(find.text('Choose a reason to continue.'), findsOneWidget);

      await tester.tap(find.text('Harassment'));
      await pumpFrames(tester);
      await tester.tap(find.text('Submit report'));
      await pumpFrames(tester);
      expect(find.text('Report saved'), findsWidgets);
      expect(find.text('Submit report'), findsNothing);
    });

    testWidgets('unknown routes show the not-found screen when signed in', (
      tester,
    ) async {
      await pumpApp(tester, location: '/nope', session: AuthStatus.loggedIn);
      await pumpFrames(tester);
      expect(find.text('Page not found'), findsOneWidget);
    });
  });

  group('every screen renders without layout errors', () {
    final signedInPaths = [
      AppRoutes.discover,
      AppRoutes.likes,
      AppRoutes.matches,
      AppRoutes.chat,
      '/chat/anything',
      AppRoutes.profile,
      AppRoutes.profilePhotos,
      AppRoutes.subscription,
      AppRoutes.subscriptionHistory,
      AppRoutes.subscriptionHelp,
      AppRoutes.subscriptionPlan('npr-100'),
      AppRoutes.wallet,
      AppRoutes.walletActivity,
      AppRoutes.walletWelcome,
      AppRoutes.walletWithdraw,
      AppRoutes.walletWithdrawRequest,
      AppRoutes.walletWithdrawHistory,
      AppRoutes.walletHelp,
      AppRoutes.walletTransaction('mock-tx-welcome'),
      AppRoutes.walletWithdrawal('missing'),
      AppRoutes.referrals,
      AppRoutes.referralHistory,
      AppRoutes.referralEarnings,
      AppRoutes.referralHelp,
      AppRoutes.referralCommission('mock-cm-quinn'),
      AppRoutes.notifications,
      AppRoutes.notificationPreferences,
      AppRoutes.settings,
      AppRoutes.privacy,
      AppRoutes.accessibility,
      AppRoutes.help,
      AppRoutes.safety,
      AppRoutes.blockedUsers,
      AppRoutes.report,
      AppRoutes.reportSubmitted,
      AppRoutes.account,
      AppRoutes.changePhone,
      AppRoutes.deleteAccount,
    ];
    final publicPaths = [
      AppRoutes.welcome,
      AppRoutes.authPhone,
      '/auth/phone?mode=login',
      '/auth/verify?phone=%2B9779841234567',
      AppRoutes.legalTerms,
      AppRoutes.legalPrivacy,
    ];

    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.5]) {
        final name =
            '${dark ? 'dark' : 'light'} theme, ${scale}x text, 360x740';

        testWidgets('signed in, $name', (tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          for (final path in signedInPaths) {
            await pumpApp(
              tester,
              location: path,
              session: AuthStatus.loggedIn,
              prefs: {if (dark) 'pref.theme_mode': 'dark'},
            );
            await pumpFrames(tester);
            expect(find.byType(AppPage), findsWidgets, reason: path);
            expect(tester.takeException(), isNull, reason: path);
            await tester.pumpWidget(const SizedBox());
          }
        });

        testWidgets('signed out, $name', (tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          for (final path in publicPaths) {
            await pumpApp(
              tester,
              location: path,
              prefs: {if (dark) 'pref.theme_mode': 'dark'},
            );
            await pumpFrames(tester);
            expect(tester.takeException(), isNull, reason: path);
            await tester.pumpWidget(const SizedBox());
          }

          // Every onboarding and session screen, in its own session state.
          for (final status in [
            AuthStatus.needsTerms,
            AuthStatus.needsBirthDate,
            AuthStatus.needsGender,
            AuthStatus.ineligible,
            AuthStatus.incompleteProfile,
            AuthStatus.onboardingComplete,
            AuthStatus.sessionExpired,
          ]) {
            await pumpApp(
              tester,
              location: homeFor(status),
              session: status,
              prefs: {if (dark) 'pref.theme_mode': 'dark'},
            );
            await pumpFrames(tester);
            expect(tester.takeException(), isNull, reason: '$status');
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }
  });
}
