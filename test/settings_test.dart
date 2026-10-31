import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/constants/settings_rules.dart';
import 'package:social_dating/core/routing/app_routes.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/menu_tile.dart';
import 'package:social_dating/data/repositories/mock_matching_repository.dart';
import 'package:social_dating/data/repositories/repository_providers.dart';
import 'package:social_dating/data/services/service_providers.dart';
import 'package:social_dating/features/auth/providers/session_provider.dart';
import 'package:social_dating/features/matches/providers/matches_providers.dart';
import 'package:social_dating/features/onboarding/presentation/welcome_screen.dart';
import 'package:social_dating/features/settings/providers/user_preferences_provider.dart';

import 'helpers/pump_app.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Finder prefSwitch(String title) => find.descendant(
  of: find.widgetWithText(MenuTile, title),
  matching: find.byType(Switch),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('notification settings', () {
    testWidgets(
      'push, 3–5 day reminder and quiet hours are mock device prefs',
      (tester) async {
        usePhoneScreen(tester);
        await pumpApp(
          tester,
          location: AppRoutes.notificationPreferences,
          session: AuthStatus.loggedIn,
        );
        await pumpFrames(tester);

        expect(find.textContaining('3–5 days'), findsWidgets);
        expect(find.textContaining('Saved on this device'), findsWidgets);
        expect(find.text(SettingsRules.quietHoursNote), findsOneWidget);

        await tapVisible(
          tester,
          find.widgetWithText(MenuTile, 'Push notifications'),
        );
        await pumpFrames(tester);
        expect(
          tester.widget<Switch>(prefSwitch('Push notifications')).value,
          isFalse,
        );

        await tapVisible(tester, find.text('3 days'));
        await pumpFrames(tester);

        await tapVisible(tester, find.widgetWithText(MenuTile, 'Quiet hours'));
        await pumpFrames(tester);
        expect(tester.widget<Switch>(prefSwitch('Quiet hours')).value, isTrue);

        final prefs = containerOf(tester).read(userPreferencesProvider);
        expect(prefs.pushEnabled, isFalse);
        expect(prefs.profileReminderDays, 3);
        expect(prefs.quietHoursEnabled, isTrue);

        final stored = containerOf(
          tester,
        ).read(localPreferencesServiceProvider).userPreferences;
        expect(stored.pushEnabled, isFalse);
        expect(stored.profileReminderDays, 3);
        expect(stored.quietHoursEnabled, isTrue);
      },
    );
  });

  group('block lists', () {
    testWidgets('empty blocked list, then unblock needs confirmation', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.blockedUsers,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);
      expect(find.text('No blocked users'), findsOneWidget);

      final matching =
          containerOf(tester).read(matchingRepositoryProvider)
              as MockMatchingRepository;
      await matching.block('mock-6');
      containerOf(tester).read(matchingRevisionProvider.notifier).bump();
      await pumpFrames(tester);

      expect(find.text('Casey Stub'), findsOneWidget);
      expect(find.text('Mockville'), findsOneWidget);
      expect(find.textContaining('+977'), findsNothing);

      await tapVisible(tester, find.text('Unblock'));
      await pumpFrames(tester);
      expect(find.text('Unblock Casey Stub?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(find.text('Casey Stub'), findsOneWidget);

      await tapVisible(tester, find.text('Unblock'));
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Unblock'),
        ),
      );
      await pumpFrames(tester);
      expect(find.text('Casey Stub'), findsNothing);
      expect(find.text('No blocked users'), findsOneWidget);
    });
  });

  group('report validation', () {
    testWidgets('category is required and confirmation is mock-only', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.report,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tapVisible(tester, find.widgetWithText(AppButton, 'Submit report'));
      await pumpFrames(tester);
      expect(find.text('Choose a reason to continue.'), findsOneWidget);

      await tapVisible(tester, find.text('Harassment'));
      await pumpFrames(tester);
      await tapVisible(tester, find.widgetWithText(AppButton, 'Submit report'));
      await pumpFrames(tester);

      expect(find.text(SettingsRules.reportSubmittedTitle), findsWidgets);
      expect(find.text(SettingsRules.reportSubmittedBody), findsOneWidget);
      expect(find.text('Submit report'), findsNothing);
    });
  });

  group('privacy preferences', () {
    testWidgets(
      'shows public vs private fields and persists discovery toggle',
      (tester) async {
        usePhoneScreen(tester);
        await pumpApp(
          tester,
          location: AppRoutes.privacy,
          session: AuthStatus.loggedIn,
        );
        await pumpFrames(tester);

        expect(find.text('Shown on your profile'), findsOneWidget);
        expect(find.text('Kept private'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('Phone number'), findsOneWidget);
        expect(find.text('Exact location'), findsOneWidget);
        expect(find.textContaining('City-level'), findsWidgets);
        expect(find.textContaining('+977'), findsNothing);

        expect(
          tester.widget<Switch>(prefSwitch('Show me in discovery')).value,
          isTrue,
        );
        await tapVisible(tester, find.text('Show me in discovery'));
        await pumpFrames(tester);
        expect(
          tester.widget<Switch>(prefSwitch('Show me in discovery')).value,
          isFalse,
        );
        expect(
          containerOf(tester).read(userPreferencesProvider).showInDiscovery,
          isFalse,
        );
        expect(find.textContaining('device only'), findsWidgets);
      },
    );
  });

  group('logout', () {
    testWidgets('sign out asks first, cancel keeps the session', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.account,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      await tapVisible(tester, find.text('Sign out'));
      await pumpFrames(tester);
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isTrue);

      await tapVisible(tester, find.text('Sign out'));
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Sign out'),
        ),
      );
      await pumpFrames(tester);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isFalse);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('deletion confirmation', () {
    testWidgets('requires acknowledgement, then a confirm dialog', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await pumpApp(
        tester,
        location: AppRoutes.deleteAccount,
        session: AuthStatus.loggedIn,
      );
      await pumpFrames(tester);

      expect(find.textContaining('retention policy'), findsWidgets);

      final continueButton = find.widgetWithText(AppButton, 'Continue');
      expect(tester.widget<AppButton>(continueButton).onPressed, isNull);

      await tapVisible(
        tester,
        find.text('I understand what deletion means'),
      );
      await pumpFrames(tester);
      expect(tester.widget<AppButton>(continueButton).onPressed, isNotNull);

      await tapVisible(tester, continueButton);
      await pumpFrames(tester);
      expect(find.text('Delete your account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isTrue);

      await tapVisible(tester, continueButton);
      await pumpFrames(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Delete account'),
        ),
      );
      await pumpFrames(tester);
      expect(containerOf(tester).read(sessionProvider).isLoggedIn, isFalse);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        find.text('Your account details were deleted from this device.'),
        findsOneWidget,
      );
    });
  });
}
